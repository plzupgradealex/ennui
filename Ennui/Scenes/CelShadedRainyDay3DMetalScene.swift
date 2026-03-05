// CelShadedRainyDay3DMetalScene — Metal 3D bright rainy garden with flowers and puddles.
// Chunky flowers, drifting clouds, falling rain particles, reflective puddles.
// Tap to send a gentle ripple through a puddle.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct CelShadedRainyDay3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        CelShadedRainyDay3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct CelShadedRainyDay3DMetalRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator: NSObject, MTKViewDelegate {

        let device:             MTLDevice
        let commandQueue:       MTLCommandQueue
        var opaquePipeline:     MTLRenderPipelineState?
        var glowPipeline:       MTLRenderPipelineState?
        var particlePipeline:   MTLRenderPipelineState?
        var depthState:         MTLDepthStencilState?
        var depthROState:       MTLDepthStencilState?

        struct DrawCall {
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }
        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        // Flower head colors for reference
        let headColors: [SIMD3<Float>] = [
            [1.0, 0.15, 0.15], [1.0, 0.50, 0.05], [0.95, 0.90, 0.10],
            [0.90, 0.10, 0.90], [0.10, 0.40, 1.00], [1.0, 0.40, 0.70],
            [0.50, 0.10, 0.90], [1.0, 0.70, 0.00]
        ]

        // Cloud positions for drift
        struct CloudData { var baseX: Float; var baseY: Float; var z: Float; var driftAmp: Float; var driftPeriod: Float }
        var clouds: [CloudData] = []
        var cloudCallIndices: [(startOpaque: Int, count: Int)] = []

        // Puddle indices and ripple state
        var puddleGlowIndices: [Int] = []
        var rippleTapTime: Float = -999
        var ripplePuddleIdx: Int = 0

        // Rain particle data
        struct RainDrop { var x: Float; var z: Float; var speed: Float; var phase: Float }
        var rainDrops: [RainDrop] = []

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect:    Float = 1

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("CelShadedRainyDay3DMetal pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                        emissiveCol: .zero, emissiveMix: 0))
        }
        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, opacity: Float = 0.9) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                      emissiveCol: emissive, emissiveMix: 1.0, opacity: opacity))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 2222)

            // Grassy ground
            addOpaque(buildPlane(w: 20, d: 16, color: [0.35, 0.65, 0.25, 1]),
                      model: matrix_identity_float4x4)

            // 8 Chunky flowers: cylinder stem + sphere head
            let stemColors: [SIMD4<Float>] = [
                [0.20, 0.65, 0.10, 1], [0.15, 0.60, 0.08, 1]
            ]
            for i in 0..<8 {
                let fx = Float(Double.random(in: -5...5, using: &rng))
                let fz = Float(Double.random(in: -1...3, using: &rng))
                let tilt = Float(Double.random(in: -0.2...0.2, using: &rng))
                let stemModel = m4Translation(fx, 0.3, fz) * m4RotZ(tilt) * m4RotX(tilt * 0.5)
                addOpaque(buildCylinder(radius: 0.06, height: 0.6, segments: 6,
                                        color: stemColors[i % 2]),
                          model: stemModel)
                let headY: Float = 0.6 + 0.05
                let hc = headColors[i % headColors.count]
                addGlow(buildSphere(radius: 0.20, rings: 4, segments: 6,
                                    color: [hc.x, hc.y, hc.z, 1]),
                        model: m4Translation(fx + sin(tilt) * 0.3, headY, fz),
                        emissive: hc * 0.4, opacity: 0.95)
            }

            // Clouds — 3 groups of sphere puffs
            let cloudPos: [(Float, Float, Float)] = [(0, 7, -8), (-4, 5.5, -6), (5, 6, -10)]
            for (ci, (cx, cy, cz)) in cloudPos.enumerated() {
                let puffCount = Int(Double.random(in: 3...4.99, using: &rng))
                let startIdx = opaqueCalls.count
                for _ in 0..<puffCount {
                    let r = Float(Double.random(in: 0.5...1.0, using: &rng))
                    let grey = Float(Double.random(in: 0.88...1.0, using: &rng))
                    let px = Float(Double.random(in: -1.2...1.2, using: &rng))
                    let py = Float(Double.random(in: -0.3...0.3, using: &rng))
                    let pz = Float(Double.random(in: -0.5...0.5, using: &rng))
                    addOpaque(buildSphere(radius: r, rings: 4, segments: 6,
                                          color: [grey, grey, grey, 1]),
                              model: m4Translation(cx + px, cy + py, cz + pz))
                }
                let driftAmp = Float(Double.random(in: 0.4...0.8, using: &rng))
                let driftPer = Float(Double.random(in: 12...20, using: &rng))
                clouds.append(CloudData(baseX: cx, baseY: cy, z: cz,
                                        driftAmp: driftAmp, driftPeriod: driftPer))
                cloudCallIndices.append((startOpaque: startIdx, count: puffCount))
                _ = ci
            }

            // Puddles — 5 semi-transparent flat quads
            var prng = SplitMix64(seed: 4444)
            for _ in 0..<5 {
                let px = Float(Double.random(in: -4...4, using: &prng))
                let pz = Float(Double.random(in: -1...3, using: &prng))
                let pw = Float(Double.random(in: 0.4...0.8, using: &prng))
                let pd = Float(Double.random(in: 0.25...0.5, using: &prng))
                let idx = glowCalls.count
                addGlow(buildPlane(w: pw, d: pd, color: [0.65, 0.75, 0.85, 1]),
                        model: m4Translation(px, 0.005, pz),
                        emissive: [0.3, 0.4, 0.5], opacity: 0.5)
                puddleGlowIndices.append(idx)
            }

            // Pre-generate rain drops
            var rrng = SplitMix64(seed: 7777)
            for _ in 0..<120 {
                rainDrops.append(RainDrop(
                    x: Float(Double.random(in: -8...8, using: &rrng)),
                    z: Float(Double.random(in: -4...6, using: &rrng)),
                    speed: Float(Double.random(in: 6...9, using: &rrng)),
                    phase: Float(Double.random(in: 0...1.5, using: &rrng))
                ))
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opPipe  = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpDesc   = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let encoder  = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Camera: slight bob
            let bobY: Float = 2.5 + sin(t * Float.pi * 2.0 / 4.0) * 0.05
            let eye:    SIMD3<Float> = [0, bobY, 8]
            let center: SIMD3<Float> = [0, 2.0, -2]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 75 * .pi / 180, aspect: aspect, near: 0.02, far: 50)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(-0.3, 0.8, -0.2)), 0),
                sunColor:       SIMD4<Float>([0.95, 0.95, 0.90], 0),
                ambientColor:   SIMD4<Float>([0.40, 0.42, 0.48], t),
                fogParams:      SIMD4<Float>(20, 50, 0, 0),
                fogColor:       SIMD4<Float>([0.70, 0.80, 0.90], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Animate cloud drift
            for (ci, cloud) in clouds.enumerated() {
                let drift = sin(t * Float.pi * 2.0 / cloud.driftPeriod) * cloud.driftAmp
                let (startIdx, count) = cloudCallIndices[ci]
                for j in 0..<count {
                    let orig = opaqueCalls[startIdx + j].model
                    // Apply drift by adjusting the translation column
                    var m = orig
                    m.columns.3.x = orig.columns.3.x + drift
                    opaqueCalls[startIdx + j].model = m
                }
            }

            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                // Animate puddle ripple
                let rippleAge = t - rippleTapTime
                for (pi, idx) in puddleGlowIndices.enumerated() {
                    if pi == ripplePuddleIdx && rippleAge < 1.0 {
                        let pulse = 1.0 + sin(rippleAge * Float.pi) * 0.3
                        var m = glowCalls[idx].model
                        m = m * m4Scale(pulse, 1, pulse)
                        encodeDraw(encoder: encoder, vertexBuffer: glowCalls[idx].buffer,
                                   vertexCount: glowCalls[idx].count, model: m,
                                   emissiveColor: glowCalls[idx].emissiveCol * 1.5,
                                   emissiveMix: 1.0, opacity: glowCalls[idx].opacity)
                    } else {
                        let call = glowCalls[idx]
                        encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                                   model: call.model, emissiveColor: call.emissiveCol,
                                   emissiveMix: call.emissiveMix, opacity: call.opacity)
                    }
                }

                // Flower heads (non-puddle glow calls)
                for (i, call) in glowCalls.enumerated() {
                    if puddleGlowIndices.contains(i) { continue }
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }
            }

            // Rain particles
            if let pp = particlePipeline {
                encoder.setRenderPipelineState(pp)
                encoder.setDepthStencilState(depthROState)

                var particles: [ParticleVertex3D] = []
                for drop in rainDrops {
                    let lifeT = fmod(t * drop.speed * 0.15 + drop.phase, 1.5)
                    let y: Float = 10.0 - lifeT * drop.speed
                    if y < 0 { continue }
                    let alpha = min(1.0, (10.0 - y) / 3.0) * 0.6
                    particles.append(ParticleVertex3D(
                        position: [drop.x, y, drop.z],
                        color: [0.8, 0.9, 1.0, alpha],
                        size: 3.0
                    ))
                }
                if let buf = makeParticleBuffer(particles, device: device) {
                    encoder.setVertexBuffer(buf, offset: 0, index: 0)
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
        view.delegate                = context.coordinator
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor              = MTLClearColor(red: 0.70, green: 0.80, blue: 0.90, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.rippleTapTime = t
        var rng = SplitMix64(seed: UInt64(tapCount &* 997))
        c.ripplePuddleIdx = Int(Double.random(in: 0...4.99, using: &rng)) % c.puddleGlowIndices.count
    }
}
