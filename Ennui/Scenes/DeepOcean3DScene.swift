// DeepOcean3DScene — Metal 3D bioluminescent deep ocean. Tap to spike particle brightness.

import SwiftUI
import MetalKit

struct DeepOcean3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { DeepOcean3DRepresentable(interaction: interaction) }
}

// MARK: - NSViewRepresentable

private struct DeepOcean3DRepresentable: NSViewRepresentable {
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

        // MARK: Bioluminescent particles (precomputed)
        struct BioParticle {
            var pos:   SIMD3<Float>
            var vel:   SIMD3<Float>    // drift direction
            var phase: Float
            var hue:   Float           // 0.45..0.70 (cyan to blue-purple)
            var size:  Float
        }
        var bioParticles: [BioParticle] = []

        // MARK: Jellyfish geometry (3 jellyfish, bell + tentacles)
        struct Jellyfish {
            var bellBuf:  MTLBuffer
            var bellCount: Int
            var tentBufs: [(MTLBuffer, Int)]  // up to 4 tentacles
            var basePos:  SIMD3<Float>
            var bobPhase: Float
            var bobSpeed: Float
            var color:    SIMD3<Float>
        }
        var jellies: [Jellyfish] = []

        // MARK: Tap interaction
        var brightBoost:  Float = 0.0
        var boostDecayT:  Float = -999

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
                print("DeepOcean3D pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build scene geometry

        private func buildScene() {
            // Ocean sphere (dark navy-black, inside-out)
            let oceanCol: SIMD4<Float> = [0.005, 0.012, 0.04, 1]
            addOpaque(buildSphere(radius: 40, rings: 8, segments: 16, color: oceanCol),
                      model: m4Scale(-1, 1, -1))

            // Seafloor plane
            let floorCol: SIMD4<Float> = [0.03, 0.04, 0.06, 1]
            addOpaque(buildPlane(w: 30, d: 30, color: floorCol),
                      model: m4Translation(0, -6, 0))

            // Floor rock mounds
            let rockCol: SIMD4<Float> = [0.05, 0.06, 0.09, 1]
            let rockSpots: [(Float, Float, Float, Float, Float, Float)] = [
                (-4, -5.6, -5, 2.0, 0.6, 1.5),
                ( 5, -5.5, -8, 2.5, 0.8, 2.0),
                (-7, -5.7,  2, 1.5, 0.4, 1.2),
                ( 3, -5.6,  4, 1.8, 0.5, 1.4),
            ]
            for (rx, ry, rz, rw, rh, rd) in rockSpots {
                addOpaque(buildBox(w: rw, h: rh, d: rd, color: rockCol),
                          model: m4Translation(rx, ry, rz))
            }

            // Bioluminescent particles (3 layers, 160 total)
            var rng = SplitMix64(seed: 7771)
            // Layer 1 — near bottom (60 particles)
            for _ in 0..<60 {
                let x = Float(Double.random(in: -8...8, using: &rng))
                let y = Float(Double.random(in: -5.5 ... -3.0, using: &rng))
                let z = Float(Double.random(in: -10 ... 2, using: &rng))
                let vx = Float(Double.random(in: -0.2...0.2, using: &rng))
                let vy = Float(Double.random(in:  0.05...0.25, using: &rng))
                let vz = Float(Double.random(in: -0.1...0.1, using: &rng))
                let ph = Float(Double.random(in: 0...2*Double.pi, using: &rng))
                let hue = Float(Double.random(in: 0.45...0.70, using: &rng))
                let sz  = Float(Double.random(in: 3...10, using: &rng))
                bioParticles.append(BioParticle(pos: [x, y, z], vel: [vx, vy, vz],
                                                phase: ph, hue: hue, size: sz))
            }
            // Layer 2 — mid water (60 particles)
            for _ in 0..<60 {
                let x = Float(Double.random(in: -9...9, using: &rng))
                let y = Float(Double.random(in: -3.0 ...  0.0, using: &rng))
                let z = Float(Double.random(in: -12 ... 3, using: &rng))
                let vx = Float(Double.random(in: -0.3...0.3, using: &rng))
                let vy = Float(Double.random(in:  0.08...0.30, using: &rng))
                let vz = Float(Double.random(in: -0.15...0.15, using: &rng))
                let ph = Float(Double.random(in: 0...2*Double.pi, using: &rng))
                let hue = Float(Double.random(in: 0.45...0.68, using: &rng))
                let sz  = Float(Double.random(in: 4...12, using: &rng))
                bioParticles.append(BioParticle(pos: [x, y, z], vel: [vx, vy, vz],
                                                phase: ph, hue: hue, size: sz))
            }
            // Layer 3 — near surface (40 particles)
            for _ in 0..<40 {
                let x = Float(Double.random(in: -10...10, using: &rng))
                let y = Float(Double.random(in:  0.0 ...  2.5, using: &rng))
                let z = Float(Double.random(in: -12 ...  3, using: &rng))
                let vx = Float(Double.random(in: -0.4...0.4, using: &rng))
                let vy = Float(Double.random(in:  0.10...0.35, using: &rng))
                let vz = Float(Double.random(in: -0.2...0.2, using: &rng))
                let ph = Float(Double.random(in: 0...2*Double.pi, using: &rng))
                let hue = Float(Double.random(in: 0.50...0.70, using: &rng))
                let sz  = Float(Double.random(in: 3...9, using: &rng))
                bioParticles.append(BioParticle(pos: [x, y, z], vel: [vx, vy, vz],
                                                phase: ph, hue: hue, size: sz))
            }

            // Jellyfish (3)
            struct JellySpec {
                let pos: SIMD3<Float>; let color: SIMD3<Float>
                let phase: Float; let speed: Float
                let bellRadius: Float; let bellScale: Float
            }
            let jellySpecs: [JellySpec] = [
                JellySpec(pos: [-4, 0, -5],  color: [0.30, 0.60, 0.90], phase: 0.0, speed: 0.7,
                          bellRadius: 0.8, bellScale: 0.5),
                JellySpec(pos: [ 2, -2, -8], color: [0.55, 0.20, 0.85], phase: 2.1, speed: 0.5,
                          bellRadius: 0.6, bellScale: 0.45),
                JellySpec(pos: [-1,  1, -3], color: [0.10, 0.75, 0.65], phase: 4.0, speed: 0.9,
                          bellRadius: 0.7, bellScale: 0.55),
            ]

            var rng2 = SplitMix64(seed: 3344)
            for spec in jellySpecs {
                let bellColor = SIMD4<Float>(spec.color.x * 0.6, spec.color.y * 0.6,
                                             spec.color.z * 0.6, 0.75)
                let bellVerts = buildSphere(radius: spec.bellRadius, rings: 6,
                                            segments: 10, color: bellColor)
                guard let bellBuf = makeVertexBuffer(bellVerts, device: device) else { continue }

                var tentacles: [(MTLBuffer, Int)] = []
                let tentCol = SIMD4<Float>(spec.color.x * 0.5, spec.color.y * 0.5,
                                           spec.color.z * 0.5, 0.55)
                for ti in 0..<4 {
                    let tAngle = Float(ti) * Float.pi * 0.5
                    let tx = cos(tAngle) * spec.bellRadius * 0.5
                    let tz = sin(tAngle) * spec.bellRadius * 0.5
                    let tentLen = Float(0.6 + Double.random(in: 0...0.6, using: &rng2))
                    let tentVerts = buildCylinder(radius: 0.025, height: tentLen,
                                                  segments: 4, color: tentCol)
                    if let tbuf = makeVertexBuffer(tentVerts, device: device) {
                        // Store as (buffer, count); tx/tz offset baked into separate model at draw time
                        _ = tx; _ = tz  // used in draw via index
                        tentacles.append((tbuf, tentVerts.count))
                    }
                }

                jellies.append(Jellyfish(
                    bellBuf: bellBuf, bellCount: bellVerts.count,
                    tentBufs: tentacles,
                    basePos: spec.pos, bobPhase: spec.phase, bobSpeed: spec.speed,
                    color: spec.color
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
            brightBoost = 3.0
            boostDecayT = Float(CACurrentMediaTime() - startTime)
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

            // Decay bright boost
            let boostAge = t - boostDecayT
            let currentBoost: Float
            if boostAge >= 0 && boostAge < 3.0 {
                currentBoost = 1.0 + 2.0 * max(0, 1 - boostAge / 3.0)
            } else {
                currentBoost = 1.0
            }

            // Camera: slow orbit at medium depth
            let orbitA = t * (2 * Float.pi / 80.0)
            let orbitR: Float = 12.0, orbitY: Float = -1.0
            let eye: SIMD3<Float> = [orbitR * sin(orbitA), orbitY, orbitR * cos(orbitA)]
            let view4 = m4LookAt(eye: eye, center: [0, -1, -3], up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 55 * Float.pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            // Ambient deep ocean light
            let ambCol = SIMD3<Float>(0.02, 0.04, 0.08)
            let sunDir = simd_normalize(SIMD3<Float>(0, -1, 0))
            let sunCol = SIMD3<Float>(0.02, 0.06, 0.10)

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(8, 30, 0, 0),
                fogColor:       SIMD4<Float>(0.005, 0.01, 0.03, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque geometry
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Jellyfish (translucent, glow pipeline)
            if let glowPL = glowPipeline {
                encoder.setRenderPipelineState(glowPL)
                encoder.setDepthStencilState(depthROState)

                for (ji, jelly) in jellies.enumerated() {
                    let bob = 0.5 * sin(t * jelly.bobSpeed + jelly.bobPhase)
                    let pulse = 0.5 + 0.5 * sin(t * jelly.bobSpeed * 2 + jelly.bobPhase)
                    let bp = jelly.basePos
                    // Bell: scale y for flattening
                    let bellScale = simd_float4x4(diagonal: SIMD4<Float>(1, 0.5, 1, 1))
                    let bellModel = m4Translation(bp.x, bp.y + bob, bp.z) * bellScale
                    encodeDraw(encoder: encoder,
                               vertexBuffer: jelly.bellBuf, vertexCount: jelly.bellCount,
                               model: bellModel,
                               emissiveColor: jelly.color * (0.4 + 0.6 * pulse),
                               emissiveMix: 0.7,
                               opacity: 0.70)

                    // Tentacles
                    for (ti, (tbuf, tcnt)) in jelly.tentBufs.enumerated() {
                        let tAngle = Float(ti) * Float.pi * 0.5
                        let tx = cos(tAngle) * 0.35
                        let tz = sin(tAngle) * 0.35
                        let sway = 0.08 * sin(t * 1.1 + jelly.bobPhase + Float(ti))
                        let tentModel = m4Translation(bp.x + tx + sway, bp.y + bob - 0.55, bp.z + tz)
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: tbuf, vertexCount: tcnt,
                                   model: tentModel,
                                   emissiveColor: jelly.color * 0.3,
                                   emissiveMix: 0.5,
                                   opacity: 0.55)
                    }
                    _ = ji
                }
            }

            // Bioluminescent particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                let rangeMin: Float = -6.0
                let rangeMax: Float =  3.0
                let rangeSpan = rangeMax - rangeMin

                for p in bioParticles {
                    // Drift upward, wrap within y range
                    let driftY = p.vel.y * t
                    let rawY   = p.pos.y + driftY
                    let wrappedY = rangeMin + (rawY - rangeMin).truncatingRemainder(dividingBy: rangeSpan)
                    let finalY = wrappedY < rangeMin ? wrappedY + rangeSpan : wrappedY

                    let swayX = p.pos.x + p.vel.x * sin(t * 0.4 + p.phase) * 2.0
                    let swayZ = p.pos.z + p.vel.z * cos(t * 0.3 + p.phase) * 2.0

                    let pulse = 0.5 + 0.5 * sin(t * 1.5 + p.phase)
                    let brightness = pulse * currentBoost

                    // Convert hue to RGB (simple hue-based)
                    let hue = p.hue
                    let r: Float, g: Float, b: Float
                    if hue < 0.5 {
                        // cyan range
                        let f = (hue - 0.45) / 0.05
                        r = 0.0
                        g = 0.6 + 0.4 * max(0, min(1, 1 - f))
                        b = 0.8 + 0.2 * max(0, min(1, f))
                    } else {
                        // blue-purple range
                        let f = (hue - 0.50) / 0.20
                        r = 0.3 * f
                        g = 0.2 * (1 - f)
                        b = 0.9
                    }
                    let alpha = min(1, brightness * 0.85)
                    let col: SIMD4<Float> = [r * brightness, g * brightness, b * brightness, alpha]
                    particles.append(ParticleVertex3D(position: [swayX, finalY, swayZ],
                                                      color: col, size: p.size))
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
        view.clearColor               = MTLClearColor(red: 0.003, green: 0.008, blue: 0.025, alpha: 1)
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
