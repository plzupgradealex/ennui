// ShimizuEvening3DScene — Metal 3D Japanese neighbourhood on a rainy evening.
// House, block wall, corner shop with striped awning, utility poles, sodium lamp, rain, puddles.
// Tap to send a splash rippling through a puddle.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct ShimizuEvening3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        ShimizuEvening3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct ShimizuEvening3DRepresentable: NSViewRepresentable {
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
            var buffer: MTLBuffer; var count: Int
            var model: simd_float4x4
            var emissiveCol: SIMD3<Float>; var emissiveMix: Float; var opacity: Float = 1
        }
        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        // Rain
        struct RainDrop { var x, y, z: Float; var speed: Float }
        var rainDrops: [RainDrop] = []

        // Splash state
        var splashTime: Float = -999

        // Puddle positions
        let puddlePositions: [(Float, Float)] = [(-2, -0.8), (1.5, -0.5)]

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
            } catch { print("ShimizuEvening3D pipeline error: \(error)") }
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
            // Wet pavement
            addOpaque(buildPlane(w: 30, d: 20, color: [0.14, 0.14, 0.16, 1]),
                      model: matrix_identity_float4x4)

            // House body
            addOpaque(buildBox(w: 3, h: 2, d: 2.5, color: [0.70, 0.68, 0.62, 1]),
                      model: m4Translation(-3, 1.0, -2))
            // House roof
            addOpaque(buildPyramid(bw: 3.3, bd: 2.8, h: 1.2, color: [0.22, 0.22, 0.22, 1]),
                      model: m4Translation(-3, 2.6, -2))
            // House windows
            for wp: (Float, Float, Float) in [(-4.2, 1.1, -0.74), (-3, 1.1, -0.74), (-1.8, 1.1, -0.74)] {
                addGlow(buildQuad(w: 0.45, h: 0.5, color: [1,1,1,1], normal: [0,0,1]),
                        model: m4Translation(wp.0, wp.1, wp.2),
                        emissive: [0.95, 0.82, 0.45], opacity: 0.8)
            }

            // Block wall (concrete segments)
            for k in 0..<12 {
                addOpaque(buildBox(w: 0.38, h: 0.28, d: 0.05, color: [0.44, 0.44, 0.44, 1]),
                          model: m4Translation(Float(k) * 0.42 - 4.5, 0.15, -1.5))
            }

            // Corner shop
            addOpaque(buildBox(w: 2, h: 1.8, d: 1.5, color: [0.54, 0.54, 0.54, 1]),
                      model: m4Translation(3, 0.9, -2))
            // Awning
            addOpaque(buildBox(w: 2.2, h: 0.10, d: 0.8, color: [0.85, 0.20, 0.20, 1]),
                      model: m4Translation(3, 1.85, -1.35))
            // Shop window
            addGlow(buildQuad(w: 0.6, h: 0.5, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(3, 0.85, -1.23),
                    emissive: [1.0, 0.90, 0.60], opacity: 0.8)

            // Utility poles
            for px: Float in [-5, 0, 5] {
                addOpaque(buildCylinder(radius: 0.04, height: 4, segments: 6,
                                        color: [0.20, 0.20, 0.20, 1]),
                          model: m4Translation(px, 2.0, -3.5))
            }

            // Sodium street lamp pole + housing
            addOpaque(buildCylinder(radius: 0.04, height: 3, segments: 6,
                                    color: [0.28, 0.28, 0.28, 1]),
                      model: m4Translation(1, 1.5, -1))
            addOpaque(buildBox(w: 0.3, h: 0.14, d: 0.20, color: [0.48, 0.48, 0.48, 1]),
                      model: m4Translation(1, 3.1, -1))
            // Lamp glow
            addGlow(buildSphere(radius: 0.10, rings: 4, segments: 8, color: [1,1,1,1]),
                    model: m4Translation(1, 3.0, -1),
                    emissive: [1.0, 0.78, 0.30], opacity: 0.9)

            // Puddles
            for (px, pz) in puddlePositions {
                addOpaque(buildBox(w: 0.7, h: 0.005, d: 0.45, color: [0.06, 0.07, 0.10, 1]),
                          model: m4Translation(px, 0.003, pz))
            }

            // Seed rain
            var rrng = SplitMix64(seed: 5501)
            for _ in 0..<200 {
                rainDrops.append(RainDrop(
                    x:     Float(Double.random(in: -10...10, using: &rrng)),
                    y:     Float(Double.random(in: 0...10, using: &rrng)),
                    z:     Float(Double.random(in: -10...3, using: &rrng)),
                    speed: Float(Double.random(in: 6...9, using: &rrng))
                ))
            }
        }

        func triggerSplash(time: Float) { splashTime = time }

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

            // Camera drift
            let camX = sin(t * Float.pi * 2 / 20) * 0.8
            let eye: SIMD3<Float>    = [camX, 2.0, 4.0]
            let center: SIMD3<Float> = [camX * 0.3, 1.5, -3.0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 58 * .pi / 180, aspect: aspect, near: 0.02, far: 60)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([0.2, 0.8, 0.3]), 0),
                sunColor:       SIMD4<Float>([0.30, 0.30, 0.40], 0),
                ambientColor:   SIMD4<Float>([0.05, 0.06, 0.16], t),
                fogParams:      SIMD4<Float>(12, 50, 0, 0),
                fogColor:       SIMD4<Float>([0.03, 0.04, 0.07], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }
            }

            // Rain particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Rain streaks
                for drop in rainDrops {
                    let elapsed = t * drop.speed
                    let dy = elapsed.truncatingRemainder(dividingBy: 12.0)
                    let py = drop.y - dy
                    let wrappedY = py < -1.0 ? py + 12.0 : py
                    particles.append(ParticleVertex3D(
                        position: [drop.x, wrappedY, drop.z],
                        color: [0.5, 0.55, 0.7, 0.4], size: 2))
                }

                // Splash burst
                let splashAge = t - splashTime
                if splashAge >= 0 && splashAge < 0.8 {
                    let intensity = max(0, 1.0 - splashAge / 0.8)
                    let (px, pz) = puddlePositions[0]
                    for i in 0..<40 {
                        let ang = Float(i) * Float.pi * 2 / 40
                        let speed = Float(1.0 + Double(i % 3) * 0.5) * splashAge * 1.5
                        let sx = px + cos(ang) * speed * 0.4
                        let sz = pz + sin(ang) * speed * 0.3
                        let sy: Float = 0.05 + splashAge * 0.8 - splashAge * splashAge * 2.0
                        particles.append(ParticleVertex3D(
                            position: [sx, max(0.005, sy), sz],
                            color: [0.5, 0.55, 0.7, intensity * 0.7], size: 3))
                    }
                }

                if !particles.isEmpty, let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.delegate                = context.coordinator
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor              = MTLClearColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerSplash(time: t)
    }
}
