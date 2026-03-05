// RetroPS13DScene — Metal 3D PS1-style night cabin: dark ground, cabin, pine trees, stars, fireflies.
// Tap: burst of fireflies (briefly increase count from 40 to 120).

import SwiftUI
import MetalKit

struct RetroPS13DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { RetroPS13DRepresentable(interaction: interaction) }
}

private struct RetroPS13DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        struct DrawCall {
            var buf: MTLBuffer; var count: Int; var model: simd_float4x4
            var emissiveCol: SIMD3<Float> = .zero; var emissiveMix: Float = 0
            var opacity: Float = 1
        }

        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // Stars (fixed, precomputed)
        var starPositions: [SIMD3<Float>] = []
        var starBrightness: [Float] = []

        // Fireflies (120 pre-computed, normally show 40, burst shows all 120)
        var fireflyPositions: [SIMD3<Float>] = []
        var fireflyPhases:    [Float] = []
        var fireflySpeeds:    [Float] = []

        var burstT: Float = -999
        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        override init() {
            device = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("RetroPS13D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0, opacity: Float = 1) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buf: buf, count: v.count, model: model,
                                        emissiveCol: emissive, emissiveMix: mix, opacity: opacity))
        }
        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, mix: Float = 0.9, opacity: Float = 1) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            transparentCalls.append(DrawCall(buf: buf, count: v.count, model: model,
                                              emissiveCol: emissive, emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            // Ground
            addOpaque(buildPlane(w: 30, d: 30, color: [0.04, 0.08, 0.04, 1]),
                      model: matrix_identity_float4x4)

            // Cabin body
            addOpaque(buildBox(w: 2.5, h: 2.0, d: 2.5, color: [0.25, 0.13, 0.06, 1]),
                      model: m4Translation(0, 1.0, -4))

            // Cabin roof
            addOpaque(buildPyramid(bw: 3.0, bd: 3.0, h: 1.2, color: [0.15, 0.08, 0.04, 1]),
                      model: m4Translation(0, 2.6, -4))

            // Emissive window
            addGlow(buildQuad(w: 0.5, h: 0.4, color: [1.0, 0.55, 0.10, 1],
                              normal: SIMD3<Float>(0, 0, 1)),
                    model: m4Translation(0, 1.1, -2.74),
                    emissive: SIMD3<Float>(1.0, 0.5, 0.1), mix: 0.95, opacity: 1.0)

            // 6 Pine trees: pyramid + box trunk
            let treePositions: [SIMD3<Float>] = [
                [-5, 0, -2], [5, 0, -3], [-4, 0, -7], [4, 0, -7],
                [-7, 0, -5], [6, 0, -6]
            ]
            for pos in treePositions {
                let trunkV = buildBox(w: 0.25, h: 0.7, d: 0.25, color: [0.22, 0.12, 0.05, 1])
                addOpaque(trunkV, model: m4Translation(pos.x, 0.35, pos.z))
                let pineV = buildPyramid(bw: 1.5, bd: 1.5, h: 3.0, color: [0.04, 0.14, 0.05, 1])
                addOpaque(pineV, model: m4Translation(pos.x, 0.7, pos.z))
            }

            // Stars (50 fixed particles)
            var rng = SplitMix64(seed: 42)
            for _ in 0..<50 {
                let theta = Float(rng.nextDouble()) * 2 * Float.pi
                let phi   = Float(rng.nextDouble()) * Float.pi * 0.7
                let r: Float = 22
                starPositions.append(SIMD3<Float>(
                    r * sin(phi) * cos(theta),
                    r * abs(cos(phi)) + 3,
                    r * sin(phi) * sin(theta) - 4
                ))
                starBrightness.append(Float(rng.nextDouble()) * 0.5 + 0.5)
            }

            // Fireflies (120 pre-computed)
            var rng2 = SplitMix64(seed: 88)
            for _ in 0..<120 {
                let x = Float(rng2.nextDouble()) * 12 - 6
                let y = Float(rng2.nextDouble()) * 2.0 + 0.3
                let z = Float(rng2.nextDouble()) * 10 - 9
                fireflyPositions.append(SIMD3<Float>(x, y, z))
                fireflyPhases.append(Float(rng2.nextDouble()) * 2 * Float.pi)
                fireflySpeeds.append(Float(rng2.nextDouble()) * 0.6 + 0.4)
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque = opaquePipeline,
                  let glow = glowPipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)
            let camAngle = t * 2 * Float.pi / 120
            let camX = 9 * cos(camAngle)
            let camZ = 9 * sin(camAngle) - 4
            let eye = SIMD3<Float>(camX, 2.5, camZ)
            let proj = m4Perspective(fovyRad: 0.7, aspect: aspect, near: 0.1, far: 80)
            let viewM = m4LookAt(eye: eye, center: SIMD3<Float>(0, 1.0, -4), up: SIMD3<Float>(0, 1, 0))
            let vp = proj * viewM

            let sunDir = SIMD4<Float>(simd_normalize(SIMD3<Float>(0.3, 0.8, 0.5)), 0)
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   sunDir,
                sunColor:       SIMD4<Float>(0.2, 0.25, 0.35, 1),
                ambientColor:   SIMD4<Float>(0.04, 0.05, 0.08, t),
                fogParams:      SIMD4<Float>(8, 25, 0, 0),
                fogColor:       SIMD4<Float>(0.01, 0.01, 0.03, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setCullMode(.back)
            enc.setDepthStencilState(depthState)
            enc.setRenderPipelineState(opaque)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for dc in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: dc.buf, vertexCount: dc.count,
                           model: dc.model, emissiveColor: dc.emissiveCol, emissiveMix: dc.emissiveMix,
                           opacity: dc.opacity)
            }

            // Transparent (window glow)
            enc.setRenderPipelineState(glow)
            enc.setDepthStencilState(depthROState)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            for dc in transparentCalls {
                encodeDraw(encoder: enc, vertexBuffer: dc.buf, vertexCount: dc.count,
                           model: dc.model, emissiveColor: dc.emissiveCol, emissiveMix: dc.emissiveMix,
                           opacity: dc.opacity)
            }

            // Stars + Fireflies as particles
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []

                // Stars
                for i in 0..<starPositions.count {
                    let b = starBrightness[i]
                    pv.append(ParticleVertex3D(
                        position: starPositions[i],
                        color: SIMD4<Float>(b, b, b * 0.9, 1),
                        size: 3.0
                    ))
                }

                // Fireflies
                let burstAge = t - burstT
                let isBurst  = burstAge < 2.0
                let ffCount  = isBurst ? 120 : 40
                for i in 0..<ffCount {
                    let phase = fireflyPhases[i]
                    let speed = fireflySpeeds[i]
                    let bob   = sin(t * speed * 2 + phase) * 0.25
                    let drift = SIMD3<Float>(
                        sin(t * speed + phase) * 0.4,
                        bob,
                        cos(t * speed * 0.7 + phase) * 0.3
                    )
                    let pos   = fireflyPositions[i] + drift
                    let alpha = 0.5 + 0.5 * sin(t * 2 + phase)
                    let sizeBoost: Float = isBurst ? 1.4 : 1.0
                    pv.append(ParticleVertex3D(
                        position: pos,
                        color: SIMD4<Float>(0.55, 1.0, 0.20, Float(alpha)),
                        size: (Float(rngSizeFor(i: i)) * 2 + 4) * sizeBoost
                    ))
                }

                if let pbuf = makeParticleBuffer(pv, device: device) {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pv.count)
                }
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }

        private func rngSizeFor(i: Int) -> Float {
            // LCG constant from Knuth MMIX for per-index deterministic sizing
            var s = SplitMix64(seed: UInt64(i) &* 6364136223846793005 &+ 1)
            return Float(s.nextDouble())
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate = context.coordinator
        v.colorPixelFormat = .bgra8Unorm
        v.depthStencilPixelFormat = .depth32Float
        v.clearColor = MTLClearColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.burstT = Float(CACurrentMediaTime() - c.startTime)
    }
}
