// Mystify3DMetalScene — Metal 3D Windows 95 Mystify screensaver homage.
// Bouncing emissive flat shapes on a black void. Pure color and motion.
// Tap to shift the palette to a new set of warm hues.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct Mystify3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        Mystify3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct Mystify3DMetalRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator: NSObject, MTKViewDelegate {

        let device:         MTLDevice
        let commandQueue:   MTLCommandQueue
        var glowPipeline:   MTLRenderPipelineState?
        var depthState:     MTLDepthStencilState?
        var depthROState:   MTLDepthStencilState?

        struct DrawCall {
            var buffer:      MTLBuffer
            var count:       Int
            var emissiveCol: SIMD3<Float>
            var opacity:     Float
        }

        struct ShapeAnim {
            var drawCallIdx: Int
            var freq:        Float
            var phaseX:      Float
            var phaseY:      Float
            var phaseZ:      Float
        }

        var glowCalls: [DrawCall] = []
        var anims:     [ShapeAnim] = []

        // Palette cycling
        let palettes: [[SIMD3<Float>]] = [
            [[0.0, 0.9, 0.9], [0.9, 0.0, 0.9], [0.3, 1.0, 0.3], [0.1, 0.3, 1.0]],
            [[1.0, 0.4, 0.1], [1.0, 0.9, 0.0], [0.8, 0.0, 0.3], [0.0, 1.0, 0.5]],
            [[0.95, 0.6, 0.8], [0.4, 0.8, 1.0], [1.0, 1.0, 0.4], [0.6, 0.3, 1.0]],
        ]
        var currentPalette = 0

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect:    Float = 1

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                glowPipeline = try makeAlphaBlendPipeline(device: device)
            } catch { print("Mystify3DMetal pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func buildScene() {
            let colors   = palettes[0]
            let freqs:   [Float] = [0.6, 0.5, 0.7, 0.45]
            let phasesX: [Float] = [0.0, 1.1, 2.2, 3.3]
            let phasesY: [Float] = [0.5, 1.6, 2.7, 3.8]
            let phasesZ: [Float] = [1.0, 2.1, 3.2, 0.4]

            for i in 0..<4 {
                let verts: [Vertex3D]
                if i % 2 == 0 {
                    // Thin box (like the SceneKit flat rectangles)
                    verts = buildBox(w: 1.5, h: 1.1, d: 0.08, color: [1, 1, 1, 1])
                } else {
                    // Thin pyramid
                    verts = buildPyramid(bw: 1.2, bd: 0.08, h: 1.4, color: [1, 1, 1, 1])
                }
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                let idx = glowCalls.count
                glowCalls.append(DrawCall(
                    buffer: buf, count: verts.count,
                    emissiveCol: colors[i], opacity: 0.85
                ))
                anims.append(ShapeAnim(
                    drawCallIdx: idx,
                    freq: freqs[i],
                    phaseX: phasesX[i], phaseY: phasesY[i], phaseZ: phasesZ[i]
                ))
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let gp       = glowPipeline,
                  let drawable = view.currentDrawable,
                  let rpDesc   = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let encoder  = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            let eye:    SIMD3<Float> = [0, 0, 8]
            let center: SIMD3<Float> = [0, 0, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.02, far: 40)
            let vp    = proj4 * view4

            // Minimal lighting — shapes are fully emissive
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>([0, 1, 0], 0),
                sunColor:       SIMD4<Float>([0.0, 0.0, 0.0], 0),
                ambientColor:   SIMD4<Float>([0.01, 0.01, 0.01], t),
                fogParams:      SIMD4<Float>(30, 60, 0, 0),
                fogColor:       SIMD4<Float>([0, 0, 0], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(gp)
            encoder.setDepthStencilState(depthROState)
            encoder.setCullMode(.none)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for anim in anims {
                let call = glowCalls[anim.drawCallIdx]
                let f = anim.freq
                let x = sin(t * f + anim.phaseX) * 5.5
                let y = cos(t * f * 0.7 + anim.phaseY) * 3.5
                let z = sin(t * f * 0.5 + anim.phaseZ) * 1.8
                let model = m4Translation(x, y, z) *
                            m4RotX(t * 0.25) * m4RotY(t * 0.4) * m4RotZ(t * 0.15)

                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: model, emissiveColor: call.emissiveCol,
                           emissiveMix: 1.0, opacity: call.opacity)
            }

            encoder.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }

        func cyclePalette() {
            currentPalette = (currentPalette + 1) % palettes.count
            let pal = palettes[currentPalette]
            for (i, anim) in anims.enumerated() {
                glowCalls[anim.drawCallIdx].emissiveCol = pal[i % pal.count]
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate                = context.coordinator
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor              = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.cyclePalette()
    }
}
