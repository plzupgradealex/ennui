// GreetingTheDay3DMetalScene — Metal 3D sunrise city with buildings, rising sun, golden dust.
// Light gradually brightens. Windows glow amber. Tap to add a gentle golden burst.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct GreetingTheDay3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        GreetingTheDay3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct GreetingTheDay3DMetalRepresentable: NSViewRepresentable {
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

        // Window glow data: (glowCallIndex, delaySeconds)
        var windowDelays: [(Int, Float)] = []

        // Sun glow call index
        var sunGlowIdx: Int = 0

        // Golden dust
        struct Mote { var x, z, speedY, phase: Float }
        var motes: [Mote] = []

        // Tap burst
        var burstTapTime: Float = -999

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
            } catch { print("GreetingTheDay3DMetal pipeline error: \(error)") }
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
            var rng = SplitMix64(seed: 3333)

            // Dark ground
            addOpaque(buildPlane(w: 24, d: 24, color: [0.12, 0.10, 0.15, 1]),
                      model: matrix_identity_float4x4)

            // 10 City buildings
            for _ in 0..<10 {
                let bw = Float(Double.random(in: 1.0...2.5, using: &rng))
                let bh = Float(Double.random(in: 2...9, using: &rng))
                let bx = Float(Double.random(in: -8...8, using: &rng))
                let bz = Float(Double.random(in: -10 ... -3, using: &rng))
                let grey = Float(Double.random(in: 0.28...0.45, using: &rng))

                addOpaque(buildBox(w: bw, h: bh, d: bw * 0.8,
                                   color: [grey * 0.75, grey * 0.82, grey, 1]),
                          model: m4Translation(bx, bh / 2, bz))

                // 2–4 windows per building
                let winCount = Int(Double.random(in: 2...4.99, using: &rng))
                for w in 0..<winCount {
                    let halfH = bh / 2.0
                    let halfW = bw / 2.0
                    let wy = Float(Double.random(in: Double(-halfH + 0.3)...Double(halfH - 0.3), using: &rng))
                    let wx = Float(Double.random(in: Double(-halfW + 0.2)...Double(halfW - 0.2), using: &rng))
                    let wz = bz + bw * 0.4 + 0.02
                    let delay = Float(w) * Float(Double.random(in: 2...10, using: &rng))
                    let idx = glowCalls.count
                    // Start dark, will light up after delay
                    addGlow(buildQuad(w: 0.20, h: 0.15, color: [1, 1, 1, 1], normal: [0, 0, 1]),
                            model: m4Translation(bx + wx, bh / 2 + wy, wz),
                            emissive: [0.02, 0.02, 0.02], opacity: 0.7)
                    windowDelays.append((idx, delay))
                }
            }

            // Sun sphere (emissive glow) — starts below horizon, rises
            sunGlowIdx = glowCalls.count
            addGlow(buildSphere(radius: 1.0, rings: 6, segments: 8, color: [1, 0.9, 0.6, 1]),
                    model: m4Translation(-8, -2, -15),
                    emissive: [1.0, 0.70, 0.20], opacity: 0.95)

            // Golden dust motes
            var mrng = SplitMix64(seed: 5555)
            for _ in 0..<80 {
                motes.append(Mote(
                    x: Float(Double.random(in: -9...9, using: &mrng)),
                    z: Float(Double.random(in: -12 ... -1, using: &mrng)),
                    speedY: Float(Double.random(in: 0.15...0.45, using: &mrng)),
                    phase: Float(Double.random(in: 0...6, using: &mrng))
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

            // Sunrise progress (0→1 over 60 seconds, repeats)
            let sunrise = min(fmod(t, 60.0) / 60.0, 1.0)

            // Camera tilts gently upward as sunrise progresses
            let camPitch: Float = -0.15 - sunrise * 0.15
            let eye:    SIMD3<Float> = [0, 3, 10]
            let center: SIMD3<Float> = [0, 3 + tan(camPitch) * 10, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 70 * .pi / 180, aspect: aspect, near: 0.02, far: 50)
            let vp    = proj4 * view4

            // Light brightens with sunrise
            let sunIntensity = 0.08 + sunrise * 0.85
            let sunR = 0.4 + sunrise * 0.5
            let sunG = 0.45 + sunrise * 0.35
            let sunB = 0.7 - sunrise * 0.35
            let ambI = 0.02 + sunrise * 0.10

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(-0.4, 0.5, -0.3)), 0),
                sunColor:       SIMD4<Float>([sunR * sunIntensity, sunG * sunIntensity, sunB * sunIntensity], 0),
                ambientColor:   SIMD4<Float>([ambI, ambI * 0.8, ambI * 1.5], t),
                fogParams:      SIMD4<Float>(15, 45, 0, 0),
                fogColor:       SIMD4<Float>([0.06 + sunrise * 0.15, 0.04 + sunrise * 0.10, 0.12 - sunrise * 0.06], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                // Animate sun position: rises from y=-2 to y=5
                let sunY: Float = -2.0 + sunrise * 7.0
                glowCalls[sunGlowIdx].model = m4Translation(-8, sunY, -15)

                // Light up windows based on delay
                let windowAmber: SIMD3<Float> = [1.0, 0.75, 0.30]
                for (idx, delay) in windowDelays {
                    if t > delay {
                        glowCalls[idx].emissiveCol = windowAmber
                    }
                }

                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }
            }

            // Golden dust particles
            if let pp = particlePipeline {
                encoder.setRenderPipelineState(pp)
                encoder.setDepthStencilState(depthROState)

                var particles: [ParticleVertex3D] = []
                let dustAlpha = min(sunrise * 2.0, 0.7)
                for mote in motes {
                    let y = fmod(t * mote.speedY + mote.phase, 8.0)
                    let wobbleX = sin(t * 0.4 + mote.phase) * 0.3
                    let alpha = dustAlpha * (1.0 - abs(y - 4.0) / 4.0)
                    particles.append(ParticleVertex3D(
                        position: [mote.x + wobbleX, y, mote.z],
                        color: [1.0, 0.85, 0.40, alpha],
                        size: 4.0
                    ))
                }

                // Tap burst — extra bright particles radiating out
                let burstAge = t - burstTapTime
                if burstAge < 2.0 {
                    let burstAlpha = max(0, 1.0 - burstAge / 2.0) * 0.8
                    for i in 0..<24 {
                        let ang = Float(i) * Float.pi * 2.0 / 24.0
                        let r = burstAge * 2.5
                        particles.append(ParticleVertex3D(
                            position: [cos(ang) * r, 3.0 + sin(ang * 3.0) * burstAge, sin(ang) * r - 5],
                            color: [1.0, 0.90, 0.35, burstAlpha],
                            size: 6.0
                        ))
                    }
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
        view.clearColor              = MTLClearColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.burstTapTime = t
    }
}
