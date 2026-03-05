// RetroPS13DMetalScene — PS1-era low-poly night cabin with fireflies.
// Dark forest clearing, wooden cabin with pyramid roof and glowing window,
// pine trees, tiny star cubes, drifting firefly particles.
// Tap to burst extra fireflies.
// Rendered in Metal (MTKView) — no SceneKit. Seed 7777.

import SwiftUI
import MetalKit

struct RetroPS13DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        RetroPS13DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct RetroPS13DMetalRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator: NSObject, MTKViewDelegate {

        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

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

        // Firefly positions and orbital data
        var fireflyPos:   [SIMD3<Float>] = []
        var fireflyPhase: [Float]        = []
        var fireflySpeed: [Float]        = []
        var fireflyRadius: [Float]       = []

        // Star cube positions
        var starPos: [SIMD3<Float>] = []

        // Tap burst
        var burstT: Float = -100

        // Cabin center for reference
        let cabinCenter: SIMD3<Float> = [0, 0, -4]

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("RetroPS13DMetal pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count,
                                        model: model, emissiveCol: emissive, emissiveMix: mix))
        }

        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, mix: Float = 1.0, opacity: Float) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count,
                                      model: model, emissiveCol: emissive,
                                      emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 7777)

            // ── Dark sky sphere ──
            addOpaque(buildSphere(radius: 60, rings: 8, segments: 12,
                                  color: [0.01, 0.01, 0.03, 1]),
                      model: matrix_identity_float4x4)

            // ── Dark green floor ──
            addOpaque(buildPlane(w: 40, d: 40, color: [0.06, 0.12, 0.05, 1]),
                      model: matrix_identity_float4x4)

            // ── Cabin body (brown box) ──
            let cx: Float = 0, cz: Float = -4
            addOpaque(buildBox(w: 2.4, h: 1.8, d: 2.0, color: [0.35, 0.22, 0.10, 1]),
                      model: m4Translation(cx, 0.9, cz))

            // ── Cabin roof (dark brown pyramid) ──
            addOpaque(buildPyramid(bw: 3.0, bd: 2.6, h: 1.2,
                                   color: [0.25, 0.15, 0.08, 1]),
                      model: m4Translation(cx, 1.8, cz))

            // ── Chimney ──
            addOpaque(buildBox(w: 0.3, h: 0.8, d: 0.3, color: [0.30, 0.18, 0.10, 1]),
                      model: m4Translation(cx + 0.7, 2.6, cz - 0.3))

            // ── Window (orange emissive quad on front face) ──
            addGlow(buildQuad(w: 0.6, h: 0.5, color: [1.0, 0.75, 0.35, 1],
                              normal: [0, 0, 1]),
                    model: m4Translation(cx, 1.1, cz + 1.01),
                    emissive: [1.0, 0.65, 0.25], mix: 1.0, opacity: 0.85)

            // ── Warm light glow on ground in front of cabin ──
            addGlow(buildBox(w: 2.0, h: 0.02, d: 1.5, color: [1.0, 0.80, 0.45, 1]),
                    model: m4Translation(cx, 0.01, cz + 1.8),
                    emissive: [0.80, 0.55, 0.20], mix: 0.6, opacity: 0.12)

            // ── Door ──
            addOpaque(buildQuad(w: 0.5, h: 0.8, color: [0.28, 0.16, 0.08, 1],
                                normal: [0, 0, 1]),
                      model: m4Translation(cx, 0.42, cz + 1.01))

            // ── Doorknob ──
            addGlow(buildSphere(radius: 0.03, rings: 3, segments: 4,
                                color: [0.80, 0.70, 0.30, 1]),
                    model: m4Translation(cx + 0.15, 0.42, cz + 1.03),
                    emissive: [0.60, 0.50, 0.20], mix: 0.5, opacity: 0.6)

            // ── 6 pine trees ──
            for _ in 0..<6 {
                let tx = Float(Double.random(in: -8.0...8.0, using: &rng))
                let tz = Float(Double.random(in: -10.0...2.0, using: &rng))
                // Avoid cabin area
                if abs(tx - cx) < 2.5 && abs(tz - cz) < 2.5 { continue }
                let treeH = Float(2.0 + Double.random(in: 0...1.5, using: &rng))
                let trunkH: Float = 0.8

                // Trunk
                addOpaque(buildBox(w: 0.25, h: trunkH, d: 0.25,
                                   color: [0.30, 0.18, 0.08, 1]),
                          model: m4Translation(tx, trunkH * 0.5, tz))
                // Foliage pyramid
                addOpaque(buildPyramid(bw: 1.4, bd: 1.4, h: treeH,
                                       color: [0.05, 0.18, 0.06, 1]),
                          model: m4Translation(tx, trunkH, tz))
                // Second tier (smaller pyramid on top)
                addOpaque(buildPyramid(bw: 0.9, bd: 0.9, h: treeH * 0.6,
                                       color: [0.06, 0.20, 0.07, 1]),
                          model: m4Translation(tx, trunkH + treeH * 0.5, tz))
            }

            // ── 50 star cubes in the sky ──
            var starRng = SplitMix64(seed: 9999)
            for _ in 0..<50 {
                let sx = Float(Double.random(in: -25.0...25.0, using: &starRng))
                let sy = Float(10.0 + Double.random(in: 0...20.0, using: &starRng))
                let sz = Float(Double.random(in: -25.0...5.0, using: &starRng))
                starPos.append([sx, sy, sz])
                addGlow(buildBox(w: 0.08, h: 0.08, d: 0.08,
                                 color: [0.95, 0.95, 1.0, 1]),
                        model: m4Translation(sx, sy, sz),
                        emissive: [0.90, 0.90, 1.0], mix: 1.0, opacity: 0.6)
            }

            // ── Moon ──
            addGlow(buildSphere(radius: 0.8, rings: 5, segments: 6,
                                color: [0.90, 0.88, 0.75, 1]),
                    model: m4Translation(-8, 18, -15),
                    emissive: [0.80, 0.78, 0.65], mix: 0.7, opacity: 0.5)

            // ── Pre-compute firefly orbital data ──
            for _ in 0..<50 {
                let fx = Float(Double.random(in: -5.0...5.0, using: &rng))
                let fy = Float(0.3 + Double.random(in: 0...2.5, using: &rng))
                let fz = Float(-1.0 + Double.random(in: -5.0...3.0, using: &rng))
                fireflyPos.append([fx, fy, fz])
                fireflyPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
                fireflySpeed.append(Float(0.3 + Double.random(in: 0...0.6, using: &rng)))
                fireflyRadius.append(Float(0.3 + Double.random(in: 0...0.8, using: &rng)))
            }
        }

        func handleTap() {
            burstT = Float(CACurrentMediaTime() - startTime)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpDesc   = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let encoder  = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)
            let burstFade = max(0, 1 - (t - burstT) / 3.0)

            // Camera — slow orbit around cabin
            let orbitAngle = t * (2 * Float.pi / 120.0)
            let camR: Float = 9.0
            let eye: SIMD3<Float> = [camR * sin(orbitAngle),
                                      2.5 + 0.2 * sin(t * 0.12),
                                      cabinCenter.z + camR * cos(orbitAngle)]
            let center: SIMD3<Float> = cabinCenter + [0, 0.8, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            // Very dim moonlight
            let sunDir: SIMD3<Float> = simd_normalize([-0.4, -0.6, 0.3])
            let sunCol: SIMD3<Float> = [0.12, 0.12, 0.18]
            let ambCol: SIMD3<Float> = [0.03, 0.03, 0.05]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(8, 20, 0, 0),
                fogColor:       SIMD4<Float>(0.02, 0.02, 0.05, 0),
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

            // Glow pass — window, stars, moon, doorknob, ground glow
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for (i, call) in glowCalls.enumerated() {
                    var em = call.emissiveCol
                    var op = call.opacity
                    // Stars twinkle
                    if i >= 2 && i < 2 + starPos.count {
                        let si = i - 2
                        let twinkle = 0.4 + 0.6 * abs(sin(t * 0.5 + Float(si) * 0.78))
                        op = call.opacity * twinkle
                    }
                    // Window flickers gently
                    if i == 0 {
                        let flick = 0.9 + 0.1 * sin(t * 3.0 + 2.0 * sin(t * 0.7))
                        em = em * flick
                    }
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: em, emissiveMix: call.emissiveMix,
                               opacity: min(1, op))
                }
            }

            // Particle pass — fireflies
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Ambient fireflies
                for i in fireflyPos.indices {
                    let ph = fireflyPhase[i]
                    let sp = fireflySpeed[i]
                    let r  = fireflyRadius[i]
                    let base = fireflyPos[i]
                    let wx = base.x + r * sin(t * sp + ph)
                    let wy = base.y + 0.15 * sin(t * sp * 1.3 + ph * 0.7)
                    let wz = base.z + r * cos(t * sp * 0.8 + ph)
                    // Pulse on and off
                    let pulse = max(0, sin(t * (1.5 + sp) + ph))
                    let alpha = 0.2 + 0.6 * pulse
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [0.55, 0.85, 0.20, alpha], size: 5))
                }

                // Tap burst — extra fireflies near cabin
                if burstFade > 0 {
                    var burstRng = SplitMix64(seed: UInt64(burstT * 1000))
                    let age = t - burstT
                    for _ in 0..<30 {
                        let dx = Float(Double.random(in: -3.0...3.0, using: &burstRng))
                        let dy = Float(0.3 + Double.random(in: 0...2.0, using: &burstRng))
                        let dz = Float(Double.random(in: -3.0...3.0, using: &burstRng))
                        let spread = 1.0 + age * 0.5
                        let pulse = max(0, sin(t * 2.0 + Float(dx * 3)))
                        particles.append(ParticleVertex3D(
                            position: [cabinCenter.x + dx * spread,
                                       dy + age * 0.3,
                                       cabinCenter.z + dz * spread],
                            color: [0.55, 0.90, 0.25, burstFade * 0.6 * pulse], size: 6))
                    }
                }

                // Chimney smoke particles
                for i in 0..<8 {
                    let ph = Float(i) * 0.8
                    let cycle = fmod(t * 0.3 + ph, 4.0)
                    let sx = cabinCenter.x + 0.7 + 0.15 * sin(t * 0.2 + ph)
                    let sy: Float = 3.0 + cycle * 0.8
                    let sz = cabinCenter.z - 0.3 + 0.1 * cos(t * 0.15 + ph)
                    let alpha = max(0, 0.15 - cycle * 0.035)
                    particles.append(ParticleVertex3D(
                        position: [sx, sy, sz],
                        color: [0.30, 0.28, 0.25, alpha], size: 8))
                }

                if let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.clearColor               = MTLClearColor(red: 0.01, green: 0.01, blue: 0.03, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.handleTap()
    }
}
