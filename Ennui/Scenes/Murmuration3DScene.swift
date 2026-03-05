// Murmuration3DScene.swift — Metal 3D boid murmuration.
//
// 500 boids in three dimensions, each rendered as a small oriented triangle
// catching a warm directional light. The camera orbits slowly.
// The same three rules — separation, alignment, cohesion — produce an
// emergent organism that breathes and turns through dark space.
//
// Tap to send a gentle scare pulse through the flock.

import SwiftUI
import MetalKit

struct Murmuration3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        Murmuration3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable + Coordinator

private struct Murmuration3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {

        // MARK: Metal state
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:   MTLDepthStencilState?
        var depthROState: MTLDepthStencilState?

        // MARK: Boid data
        struct Boid3D {
            var pos: SIMD3<Float>
            var vel: SIMD3<Float>
        }

        let boidCount  = 500
        let trailLen   = 4
        var boids: [Boid3D] = []
        var trails: [[SIMD3<Float>]] = []
        var trailTick  = 0

        // MARK: Scare
        var scareT:   Float = -100
        var scarePos: SIMD3<Float> = .zero

        // MARK: Timing
        var lastTapCount = 0
        var startTime    = CACurrentMediaTime()
        var lastStepTime = CACurrentMediaTime()
        var aspect: Float = 1

        // MARK: Boid parameters — tuned for a beautiful 3D murmuration
        let visualRange     : Float = 6
        let protectedRange  : Float = 1.5
        let matchingFactor  : Float = 0.05
        let centeringFactor : Float = 0.003
        let avoidFactor     : Float = 0.08
        let maxSpeed        : Float = 10
        let minSpeed        : Float = 4
        let boundaryRadius  : Float = 22
        let turnFactor      : Float = 0.3

        // MARK: Init

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("Murmuration3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            initBoids()
        }

        private func initBoids() {
            var rng = SplitMix64(seed: 2026)
            boids = (0..<boidCount).map { _ in
                let theta = Float.random(in: 0...(2 * .pi), using: &rng)
                let phi   = Float.random(in: 0...Float.pi, using: &rng)
                let r     = Float.random(in: 0...15, using: &rng)
                let pos   = SIMD3<Float>(r * sin(phi) * cos(theta),
                                         r * cos(phi),
                                         r * sin(phi) * sin(theta))
                let speed  = Float.random(in: 4...8, using: &rng)
                let vtheta = Float.random(in: 0...(2 * .pi), using: &rng)
                let vphi   = Float.random(in: 0.3...(Float.pi - 0.3), using: &rng)
                let vel    = speed * SIMD3<Float>(sin(vphi) * cos(vtheta),
                                                  cos(vphi),
                                                  sin(vphi) * sin(vtheta))
                return Boid3D(pos: pos, vel: vel)
            }
            trails = Array(repeating: [], count: boidCount)
        }

        // MARK: Boid simulation step

        private func stepBoids(t: Float) {
            let now = CACurrentMediaTime()
            let dt  = min(Float(now - lastStepTime), 1.0 / 30.0)
            lastStepTime = now
            guard dt > 0.0005 else { return }

            let scareDt  = t - scareT
            let scareStr: Float = scareDt < 3 ? 15 * max(0, 1 - scareDt / 2) : 0

            // Slow rotating wind — creates gentle global sweeps
            let windA = t * 0.12
            let wind  = SIMD3<Float>(cos(windA), sin(windA * 0.7) * 0.3, sin(windA)) * 0.5

            let vr2 = visualRange * visualRange
            let pr2 = protectedRange * protectedRange

            for i in 0..<boidCount {
                var close  = SIMD3<Float>.zero
                var avgVel = SIMD3<Float>.zero
                var avgPos = SIMD3<Float>.zero
                var neighbors = 0

                for j in 0..<boidCount where j != i {
                    let diff = boids[j].pos - boids[i].pos
                    let d2   = simd_length_squared(diff)

                    if d2 < pr2 && d2 > 0 {
                        close -= diff
                    }
                    if d2 < vr2 {
                        avgVel += boids[j].vel
                        avgPos += boids[j].pos
                        neighbors += 1
                    }
                }

                if neighbors > 0 {
                    let n = Float(neighbors)
                    avgVel /= n
                    avgPos /= n
                    boids[i].vel += (avgVel - boids[i].vel) * matchingFactor
                    boids[i].vel += (avgPos - boids[i].pos) * centeringFactor
                }

                boids[i].vel += close * avoidFactor

                // Boundary
                let dist = simd_length(boids[i].pos)
                if dist > boundaryRadius {
                    let excess = (dist - boundaryRadius) / boundaryRadius
                    boids[i].vel -= simd_normalize(boids[i].pos) * turnFactor * (1 + excess * 3)
                }

                // Wind
                boids[i].vel += wind * dt

                // Scare
                if scareStr > 0 {
                    let diff = boids[i].pos - scarePos
                    let sd   = max(simd_length(diff), 0.1)
                    boids[i].vel += (diff / sd) * scareStr / (sd + 5) * dt
                }

                // Speed limits
                let speed = simd_length(boids[i].vel)
                if speed > maxSpeed {
                    boids[i].vel = simd_normalize(boids[i].vel) * maxSpeed
                } else if speed < minSpeed && speed > 0 {
                    boids[i].vel = simd_normalize(boids[i].vel) * minSpeed
                }

                boids[i].pos += boids[i].vel * dt
            }

            // Trail update every 2 frames
            trailTick += 1
            if trailTick % 2 == 0 {
                for i in 0..<boidCount {
                    trails[i].append(boids[i].pos)
                    if trails[i].count > trailLen { trails[i].removeFirst() }
                }
            }
        }

        // MARK: Build per-frame vertex geometry

        /// Each boid is a small oriented triangle — like a bird silhouette.
        private func buildBoidVertices() -> [Vertex3D] {
            let bodyLen:   Float = 0.40
            let bodyWidth: Float = 0.12
            let color = SIMD4<Float>(0.92, 0.85, 0.72, 1.0) // warm cream

            var verts: [Vertex3D] = []
            verts.reserveCapacity(boidCount * 3)

            for b in boids {
                let speed = simd_length(b.vel)
                guard speed > 0.001 else { continue }

                let fwd = b.vel / speed
                // Choose a stable "up" that isn't parallel to fwd
                var up = SIMD3<Float>(0, 1, 0)
                if abs(simd_dot(fwd, up)) > 0.99 { up = SIMD3<Float>(1, 0, 0) }
                let right  = simd_normalize(simd_cross(fwd, up))
                let normal = simd_normalize(simd_cross(right, fwd))

                let tip  = b.pos + fwd * bodyLen * 0.6
                let left = b.pos - fwd * bodyLen * 0.4 + right * bodyWidth
                let rt   = b.pos - fwd * bodyLen * 0.4 - right * bodyWidth

                verts.append(Vertex3D(position: tip,  normal: normal, color: color))
                verts.append(Vertex3D(position: left, normal: normal, color: color))
                verts.append(Vertex3D(position: rt,   normal: normal, color: color))
            }
            return verts
        }

        /// Additive glow particles trailing behind each boid.
        private func buildTrailParticles() -> [ParticleVertex3D] {
            var pv: [ParticleVertex3D] = []
            pv.reserveCapacity(boidCount * trailLen)
            for i in 0..<boidCount {
                for (j, pos) in trails[i].enumerated() {
                    let frac  = Float(j + 1) / Float(trailLen + 1)
                    let alpha = frac * 0.12
                    let size: Float = 1.5 + frac * 1.0
                    pv.append(ParticleVertex3D(
                        position: pos,
                        color: SIMD4<Float>(0.80, 0.70, 0.50, alpha),
                        size: size
                    ))
                }
            }
            return pv
        }

        // MARK: MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            let t = Float(CACurrentMediaTime() - startTime)
            stepBoids(t: t)

            guard let pipeline = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            // Camera: slow orbit at comfortable distance
            let camAngle = t * (2 * .pi / 90)
            let camR:     Float = 38
            let camY:     Float = 14
            let eye = SIMD3<Float>(camR * sin(camAngle), camY, camR * cos(camAngle))

            let vp = m4Perspective(fovyRad: 50 * .pi / 180, aspect: aspect,
                                    near: 0.1, far: 150) *
                     m4LookAt(eye: eye, center: .zero, up: [0, 1, 0])

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(0.3, -0.6, -0.5)), 0),
                sunColor:       SIMD4<Float>(0.85, 0.78, 0.60, 0),
                ambientColor:   SIMD4<Float>(0.14, 0.11, 0.09, t),
                fogParams:      SIMD4<Float>(55, 110, 0, 0),
                fogColor:       SIMD4<Float>(0.02, 0.02, 0.05, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            // --- Opaque pass: boid triangles ---
            let boidVerts = buildBoidVertices()
            if let buf = makeVertexBuffer(boidVerts, device: device), !boidVerts.isEmpty {
                enc.setRenderPipelineState(pipeline)
                enc.setDepthStencilState(depthState)
                enc.setCullMode(.none) // thin triangles visible from both sides

                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

                var du = drawUniforms(model: matrix_identity_float4x4,
                                      emissiveColor: SIMD3<Float>(0.40, 0.35, 0.25),
                                      emissiveMix: 0.3,
                                      opacity: 1,
                                      specularPower: 48)
                enc.setVertexBuffer(buf, offset: 0, index: 0)
                enc.setVertexBytes(&du, length: MemoryLayout<DrawUniforms3D>.size, index: 2)
                enc.setFragmentBytes(&du, length: MemoryLayout<DrawUniforms3D>.size, index: 2)
                enc.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: boidVerts.count)
            }

            // --- Additive pass: trail particles ---
            if let ppipe = particlePipeline {
                let trailParts = buildTrailParticles()
                if let pbuf = makeParticleBuffer(trailParts, device: device), !trailParts.isEmpty {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: trailParts.count)
                }
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    // MARK: NSViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate                  = context.coordinator
        v.colorPixelFormat          = .bgra8Unorm
        v.depthStencilPixelFormat   = .depth32Float
        v.clearColor                = MTLClearColor(red: 0.02, green: 0.02, blue: 0.05, alpha: 1)
        v.preferredFramesPerSecond  = 60
        v.autoResizeDrawable        = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount

        // Scare from near the flock center
        c.scareT = Float(CACurrentMediaTime() - c.startTime)
        var center = SIMD3<Float>.zero
        for b in c.boids { center += b.pos }
        center /= Float(c.boidCount)
        c.scarePos = center + SIMD3<Float>(
            Float.random(in: -5...5),
            Float.random(in: -3...3),
            Float.random(in: -5...5)
        )
    }
}
