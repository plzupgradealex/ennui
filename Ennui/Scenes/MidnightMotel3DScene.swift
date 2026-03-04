// MidnightMotel3DScene — Metal 3D motel room circa 1968.
// Dark walls, bed, bedside lamp, neon-lit window. Tap to sweep headlights across ceiling.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct MidnightMotel3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        MidnightMotel3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct MidnightMotel3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator: NSObject, MTKViewDelegate {

        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
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

        // Headlight sweep state
        var sweepStartTime: Float = -999

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect:    Float = 1

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline = try makeOpaquePipeline(device: device)
                glowPipeline   = try makeAlphaBlendPipeline(device: device)
            } catch { print("MidnightMotel3D pipeline error: \(error)") }
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
            let wallCol: SIMD4<Float>    = [0.18, 0.10, 0.06, 1]
            let floorCol: SIMD4<Float>   = [0.15, 0.10, 0.06, 1]

            // Floor
            addOpaque(buildPlane(w: 6, d: 5, color: floorCol),
                      model: matrix_identity_float4x4)
            // Ceiling
            addOpaque(buildBox(w: 6, h: 0.04, d: 5, color: [0.16, 0.09, 0.06, 1]),
                      model: m4Translation(0, 3.02, 0))
            // Back wall
            addOpaque(buildBox(w: 6, h: 3, d: 0.06, color: wallCol),
                      model: m4Translation(0, 1.5, -2.5))
            // Left wall
            addOpaque(buildBox(w: 0.06, h: 3, d: 5, color: wallCol),
                      model: m4Translation(-3.0, 1.5, 0))
            // Right wall
            addOpaque(buildBox(w: 0.06, h: 3, d: 5, color: wallCol),
                      model: m4Translation(3.0, 1.5, 0))

            // Bed frame
            addOpaque(buildBox(w: 2.0, h: 0.15, d: 2.2, color: [0.25, 0.14, 0.08, 1]),
                      model: m4Translation(0, 0.075, 0.5))
            // Mattress
            addOpaque(buildBox(w: 1.9, h: 0.2, d: 2.1, color: [0.35, 0.08, 0.10, 1]),
                      model: m4Translation(0, 0.25, 0.5))
            // Pillow
            addOpaque(buildBox(w: 0.6, h: 0.10, d: 0.35, color: [0.88, 0.85, 0.82, 1]),
                      model: m4Translation(0, 0.40, -0.45))
            // Bedside table
            addOpaque(buildBox(w: 0.4, h: 0.45, d: 0.4, color: [0.22, 0.15, 0.10, 1]),
                      model: m4Translation(1.3, 0.225, -0.55))
            // Lamp base
            addOpaque(buildCylinder(radius: 0.06, height: 0.28, segments: 8,
                                    color: [0.30, 0.22, 0.14, 1]),
                      model: m4Translation(1.3, 0.59, -0.55))
            // Lamp shade (emissive)
            addGlow(buildSphere(radius: 0.11, rings: 4, segments: 8, color: [1,1,1,1]),
                    model: m4Translation(1.3, 0.80, -0.55),
                    emissive: [0.95, 0.70, 0.35], opacity: 0.85)

            // Window on back wall
            addGlow(buildQuad(w: 1.0, h: 1.2, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(0, 1.6, -2.44),
                    emissive: [0.04, 0.04, 0.08], opacity: 0.7)
            // Curtains
            for cx: Float in [-0.78, 0.78] {
                addOpaque(buildBox(w: 0.55, h: 1.25, d: 0.03, color: [0.35, 0.07, 0.09, 1]),
                          model: m4Translation(cx, 1.6, -2.44))
            }
            // Neon glow bleeding through window (pulsing handled in draw)
            addGlow(buildQuad(w: 1.2, h: 1.4, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(0, 1.6, -2.38),
                    emissive: [0.90, 0.15, 0.30], opacity: 0.15)
        }

        func triggerSweep(time: Float) {
            sweepStartTime = time
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

            // Neon pulse factor
            let neonPulse = 0.55 + 0.25 * sin(t * Float.pi)

            // Camera: first-person from back of room toward window
            let eye: SIMD3<Float>    = [0, 0.85, 2.2]
            let center: SIMD3<Float> = [0, 1.4, -2.0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 68 * .pi / 180, aspect: aspect, near: 0.02, far: 30)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>([0, 1, 0], 0),
                sunColor:       SIMD4<Float>([0.20, 0.12, 0.08], 0),
                ambientColor:   SIMD4<Float>([0.05, 0.03, 0.03], t),
                fogParams:      SIMD4<Float>(6, 20, 0, 0),
                fogColor:       SIMD4<Float>([0.03, 0.02, 0.02], 0),
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

                for (i, call) in glowCalls.enumerated() {
                    var ecol = call.emissiveCol
                    // Pulse neon (last glow call is neon panel, index 2)
                    if i == 2 { ecol = ecol * neonPulse }
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: ecol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }

                // Headlight sweep bar — animated across ceiling on tap or auto-cycle
                let autoSweepT = t.truncatingRemainder(dividingBy: 13.0) - 10.0
                let activeSince = t - sweepStartTime < 3.1 ? t - sweepStartTime : autoSweepT
                if activeSince >= 0 && activeSince < 3.0 {
                    let progress = activeSince / 3.0
                    let intensity: Float
                    if progress < 0.15 { intensity = progress / 0.15 }
                    else if progress < 0.85 { intensity = 1.0 }
                    else { intensity = (1.0 - progress) / 0.15 }
                    let sweepX = -3.0 + progress * 6.0
                    let sweepVerts = buildBox(w: 1.2, h: 0.02, d: 2.5,
                                             color: [1, 0.96, 0.88, 1])
                    if let sbuf = makeVertexBuffer(sweepVerts, device: device) {
                        encodeDraw(encoder: encoder, vertexBuffer: sbuf,
                                   vertexCount: sweepVerts.count,
                                   model: m4Translation(sweepX, 2.96, 0),
                                   emissiveColor: [0.95, 0.90, 0.75] * intensity,
                                   emissiveMix: 1.0, opacity: intensity * 0.7)
                    }
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
        view.clearColor              = MTLClearColor(red: 0.03, green: 0.02, blue: 0.02, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerSweep(time: t)
    }
}
