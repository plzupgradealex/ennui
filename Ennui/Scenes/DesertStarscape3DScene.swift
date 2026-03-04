// DesertStarscape3DScene — Metal 3D desert night: dunes, cactus, moon, stars. Tap for dust ripple.

import SwiftUI
import MetalKit

struct DesertStarscape3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { DesertStarscape3DRepresentable(interaction: interaction) }
}

// MARK: - NSViewRepresentable

private struct DesertStarscape3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // MARK: Coordinator / Renderer

    final class Coordinator: NSObject, MTKViewDelegate {

        // MARK: Metal core
        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        // MARK: Scene geometry
        struct DrawCall {
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // MARK: Star particles (precomputed)
        struct StarData {
            var pos:        SIMD3<Float>
            var phase:      Float
            var brightness: Float
            var size:       Float
            var warmth:     Float
        }
        var stars: [StarData] = []

        // MARK: Dust burst (precomputed positions & velocities)
        struct DustParticle {
            var basePos: SIMD3<Float>
            var vel:     SIMD3<Float>
            var phase:   Float
        }
        var dustParticles: [DustParticle] = []
        var dustBurstT:    Float = -999

        // MARK: Animation
        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        // MARK: - Init

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch {
                print("DesertStarscape3D pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build scene geometry

        private func buildScene() {
            // Sky sphere (dark blue-purple night, inside-out via scale trick)
            let skyCol: SIMD4<Float> = [0.02, 0.03, 0.10, 1]
            addOpaque(buildSphere(radius: 45, rings: 8, segments: 16, color: skyCol),
                      model: m4Scale(-1, 1, -1))

            // Ground plane
            let sandCol: SIMD4<Float> = [0.18, 0.13, 0.07, 1]
            addOpaque(buildPlane(w: 30, d: 30, color: sandCol),
                      model: matrix_identity_float4x4)

            // Dunes — 6 boxes at varying positions/heights
            struct DuneSpec { let x, y, z, w, h, d: Float; let col: SIMD4<Float> }
            let dunes: [DuneSpec] = [
                DuneSpec(x: -6,  y: 0.6,  z: -6,  w: 8,  h: 1.2, d: 4, col: [0.22, 0.16, 0.09, 1]),
                DuneSpec(x:  5,  y: 0.45, z: -4,  w: 7,  h: 0.9, d: 3.5, col: [0.20, 0.14, 0.08, 1]),
                DuneSpec(x: -2,  y: 0.35, z: -10, w: 9,  h: 0.7, d: 3, col: [0.24, 0.17, 0.10, 1]),
                DuneSpec(x:  8,  y: 0.55, z: -9,  w: 6,  h: 1.1, d: 3, col: [0.21, 0.15, 0.08, 1]),
                DuneSpec(x: -9,  y: 0.40, z: -2,  w: 5,  h: 0.8, d: 4, col: [0.23, 0.16, 0.09, 1]),
                DuneSpec(x:  1,  y: 0.28, z: -1,  w: 10, h: 0.55, d: 5, col: [0.19, 0.13, 0.07, 1]),
            ]
            for d in dunes {
                addOpaque(buildBox(w: d.w, h: d.h, d: d.d, color: d.col),
                          model: m4Translation(d.x, d.y, d.z))
            }

            // Cactus 1 at (-3, 0, -8)
            let cactusCol: SIMD4<Float> = [0.08, 0.18, 0.06, 1]
            let cactusCol2: SIMD4<Float> = [0.07, 0.16, 0.05, 1]
            // trunk
            addOpaque(buildCylinder(radius: 0.18, height: 2.0, segments: 8, color: cactusCol),
                      model: m4Translation(-3, 1.0, -8))
            // left arm: rotate ~60° from trunk top, pointing up-left
            addOpaque(buildCylinder(radius: 0.11, height: 0.8, segments: 6, color: cactusCol2),
                      model: m4Translation(-3, 1.5, -8) * m4Translation(-0.35, 0.2, 0) * m4RotZ(0.9))
            // right arm
            addOpaque(buildCylinder(radius: 0.11, height: 0.75, segments: 6, color: cactusCol2),
                      model: m4Translation(-3, 1.5, -8) * m4Translation(0.35, 0.15, 0) * m4RotZ(-0.8))

            // Cactus 2 at (5, 0, -12)
            addOpaque(buildCylinder(radius: 0.16, height: 1.7, segments: 8, color: cactusCol),
                      model: m4Translation(5, 0.85, -12))
            addOpaque(buildCylinder(radius: 0.10, height: 0.65, segments: 6, color: cactusCol2),
                      model: m4Translation(5, 1.2, -12) * m4Translation(-0.3, 0.1, 0) * m4RotZ(1.0))
            addOpaque(buildCylinder(radius: 0.10, height: 0.7, segments: 6, color: cactusCol2),
                      model: m4Translation(5, 1.2, -12) * m4Translation(0.3, 0.18, 0) * m4RotZ(-0.75))

            // Cactus 3 at (-8, 0, -14)
            addOpaque(buildCylinder(radius: 0.20, height: 2.3, segments: 8, color: cactusCol),
                      model: m4Translation(-8, 1.15, -14))
            addOpaque(buildCylinder(radius: 0.12, height: 0.9, segments: 6, color: cactusCol2),
                      model: m4Translation(-8, 1.6, -14) * m4Translation(-0.4, 0.25, 0) * m4RotZ(0.85))

            // Moon sphere
            let moonCol: SIMD4<Float> = [0.85, 0.88, 0.95, 1]
            if let buf = makeVertexBuffer(
                buildSphere(radius: 0.55, rings: 6, segments: 12, color: moonCol), device: device) {
                transparentCalls.append(DrawCall(
                    buffer:      buf,
                    count:       buildSphere(radius: 0.55, rings: 6, segments: 12, color: moonCol).count,
                    model:       m4Translation(8, 12, -30),
                    emissiveCol: SIMD3<Float>(0.80, 0.82, 0.88),
                    emissiveMix: 1.0,
                    opacity:     1.0
                ))
            }
            // Moon halo
            let haloCol: SIMD4<Float> = [0.60, 0.65, 0.90, 0.18]
            if let buf = makeVertexBuffer(
                buildSphere(radius: 1.2, rings: 6, segments: 12, color: haloCol), device: device) {
                transparentCalls.append(DrawCall(
                    buffer:      buf,
                    count:       buildSphere(radius: 1.2, rings: 6, segments: 12, color: haloCol).count,
                    model:       m4Translation(8, 12, -30),
                    emissiveCol: SIMD3<Float>(0.55, 0.60, 0.85),
                    emissiveMix: 0.5,
                    opacity:     0.18
                ))
            }

            // Stars (precomputed)
            var rng = SplitMix64(seed: 9901)
            for _ in 0..<300 {
                // Random point on sphere r=38..44
                let theta  = Float(Double.random(in: 0...2*Double.pi, using: &rng))
                let phi    = Float(acos(Double.random(in: -1...1, using: &rng)))
                let radius = Float(Double.random(in: 38...44, using: &rng))
                let x = radius * sin(phi) * cos(theta)
                let y = radius * sin(phi) * sin(theta)
                let z = radius * cos(phi)
                let phase  = Float(Double.random(in: 0...2*Double.pi, using: &rng))
                let bright = Float(Double.random(in: 0.4...1.0, using: &rng))
                let sz     = Float(Double.random(in: 1.5...5.0, using: &rng))
                let warm   = Float(Double.random(in: 0...1, using: &rng))
                stars.append(StarData(pos: [x, abs(y) * 0.5 + 2, z],
                                      phase: phase, brightness: bright,
                                      size: sz, warmth: warm))
            }

            // Dust burst particles (precomputed, reused per burst)
            var rng2 = SplitMix64(seed: 2023)
            for _ in 0..<50 {
                let angle  = Float(Double.random(in: 0...2*Double.pi, using: &rng2))
                let speed  = Float(Double.random(in: 0.5...2.0, using: &rng2))
                let vy     = Float(Double.random(in: 0.3...1.2, using: &rng2))
                let baseY  = Float(Double.random(in: 0.05...0.3, using: &rng2))
                let phase  = Float(Double.random(in: 0...2*Double.pi, using: &rng2))
                dustParticles.append(DustParticle(
                    basePos: [0, baseY, 0],
                    vel:     [cos(angle) * speed, vy, sin(angle) * speed],
                    phase:   phase
                ))
            }
        }

        private func addOpaque(_ verts: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: verts.count,
                                        model: model,
                                        emissiveCol: .zero, emissiveMix: 0))
        }

        // MARK: - Tap

        func handleTap() {
            dustBurstT = Float(CACurrentMediaTime() - startTime)
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable  = view.currentDrawable,
                  let rpDesc    = view.currentRenderPassDescriptor,
                  let cmdBuf    = commandQueue.makeCommandBuffer(),
                  let encoder   = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Camera: elevated, slow orbit (120 s/rev)
            let orbitA: Float = t * (2 * Float.pi / 120.0)
            let orbitR: Float = 16.0, orbitY: Float = 6.0
            let eye: SIMD3<Float> = [orbitR * sin(orbitA), orbitY, orbitR * cos(orbitA)]
            let view4 = m4LookAt(eye: eye, center: [0, 1, -5], up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 52 * Float.pi / 180, aspect: aspect, near: 0.1, far: 100)
            let vp    = proj4 * view4

            // Moonlight
            let moonDir = simd_normalize(SIMD3<Float>(-0.3, -0.8, -0.5))
            let moonLt  = SIMD3<Float>(0.30, 0.33, 0.50)
            let ambCol  = SIMD3<Float>(0.05, 0.05, 0.12)

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(moonDir, 0),
                sunColor:       SIMD4<Float>(moonLt, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(30, 80, 0, 0),
                fogColor:       SIMD4<Float>(0.01, 0.01, 0.06, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque pass
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Transparent pass (moon + halo)
            if let glowPL = glowPipeline {
                encoder.setRenderPipelineState(glowPL)
                encoder.setDepthStencilState(depthROState)
                for call in transparentCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            // Particle pass — stars + dust
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Stars
                for s in stars {
                    let blink = 0.7 + 0.3 * sin(t * 1.2 + s.phase)
                    let alpha = s.brightness * blink
                    let warm  = s.warmth
                    let col: SIMD4<Float> = [
                        0.85 + 0.15 * warm,
                        0.85 + 0.05 * warm,
                        1.0 - 0.15 * warm,
                        alpha
                    ]
                    particles.append(ParticleVertex3D(position: s.pos, color: col, size: s.size))
                }

                // Dust burst
                let burstAge = t - dustBurstT
                if burstAge >= 0 && burstAge < 4.0 {
                    let fade = max(0, 1 - burstAge / 4.0)
                    for d in dustParticles {
                        let px = d.basePos.x + d.vel.x * burstAge
                        let py = d.basePos.y + d.vel.y * burstAge - 0.5 * burstAge * burstAge * 0.4
                        let pz = d.basePos.z + d.vel.z * burstAge
                        let alpha = fade * (0.5 + 0.5 * sin(d.phase))
                        let col: SIMD4<Float> = [0.72, 0.58, 0.36, alpha]
                        particles.append(ParticleVertex3D(position: [px, max(0.02, py), pz],
                                                          color: col, size: 4))
                    }
                }

                if !particles.isEmpty,
                   let pbuf = makeParticleBuffer(particles, device: device) {
                    encoder.setRenderPipelineState(ppipe)
                    encoder.setDepthStencilState(depthROState)
                    encoder.setVertexBuffer(pbuf, offset: 0, index: 0)
                    encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles.count)
                }
            }

            encoder.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate                 = context.coordinator
        view.colorPixelFormat         = .bgra8Unorm
        view.depthStencilPixelFormat  = .depth32Float
        view.clearColor               = MTLClearColor(red: 0.005, green: 0.005, blue: 0.03, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
