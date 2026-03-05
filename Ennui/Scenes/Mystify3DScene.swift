// Mystify3DScene — Metal 3D Windows 95 Mystify screensaver.
// Black background, emissive bouncing shapes. Tap to add 2 more shapes (up to 8).

import SwiftUI
import MetalKit

struct Mystify3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { Mystify3DRepresentable(interaction: interaction) }
}

private struct Mystify3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        struct ShapeData {
            var buf: MTLBuffer; var count: Int
            var freq: Float; var phX, phY, phZ: Float
            var emissive: SIMD3<Float>
        }
        var shapes: [ShapeData] = []
        var activeShapeCount = 4

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        struct ShapeSpec {
            var w, h, d: Float
            var color: SIMD4<Float>
            var freq: Float; var phX, phY, phZ: Float
            var emissive: SIMD3<Float>
        }
        let allSpecs: [ShapeSpec] = [
            ShapeSpec(w:1.5,h:1.1,d:0.1, color:[0,0.9,0.9,1],   freq:0.60, phX:0.0,phY:0.5,phZ:1.0, emissive:[0,0.9,0.9]),
            ShapeSpec(w:1.2,h:0.9,d:0.1, color:[0.9,0,0.9,1],   freq:0.50, phX:1.1,phY:1.6,phZ:2.1, emissive:[0.9,0,0.9]),
            ShapeSpec(w:1.5,h:1.1,d:0.1, color:[0.3,1.0,0.3,1], freq:0.70, phX:2.2,phY:2.7,phZ:3.2, emissive:[0.3,1,0.3]),
            ShapeSpec(w:1.0,h:1.2,d:0.1, color:[0.1,0.3,1.0,1], freq:0.45, phX:3.3,phY:3.8,phZ:0.4, emissive:[0.1,0.3,1.0]),
            ShapeSpec(w:1.3,h:1.0,d:0.1, color:[1,0.4,0.1,1],   freq:0.55, phX:0.7,phY:1.2,phZ:1.7, emissive:[1,0.4,0.1]),
            ShapeSpec(w:1.1,h:1.3,d:0.1, color:[1,0.9,0,1],     freq:0.65, phX:1.8,phY:2.3,phZ:2.8, emissive:[1,0.9,0]),
            ShapeSpec(w:1.4,h:0.8,d:0.1, color:[0.8,0,0.3,1],   freq:0.48, phX:3.0,phY:3.5,phZ:4.0, emissive:[0.8,0,0.3]),
            ShapeSpec(w:1.2,h:1.1,d:0.1, color:[0,1,0.5,1],     freq:0.72, phX:4.5,phY:5.0,phZ:5.5, emissive:[0,1,0.5]),
        ]

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("Mystify3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildAllShapes()
        }

        private func buildAllShapes() {
            for spec in allSpecs {
                let verts = buildBox(w: spec.w, h: spec.h, d: spec.d, color: spec.color)
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                shapes.append(ShapeData(buf: buf, count: verts.count,
                                        freq: spec.freq,
                                        phX: spec.phX, phY: spec.phY, phZ: spec.phZ,
                                        emissive: spec.emissive))
            }
        }

        func handleTap() {
            guard activeShapeCount < 8 else { return }
            activeShapeCount = min(8, activeShapeCount + 2)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let glowPL   = glowPipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            let eye: SIMD3<Float> = [0, 0, 9]
            let viewM = m4LookAt(eye: eye, center: [0, 0, 0], up: [0, 1, 0])
            let projM = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.1, far: 50)
            let vp    = projM * viewM

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(0, -1, 0, 0),
                sunColor:       SIMD4<Float>(1, 1, 1, 0),
                ambientColor:   SIMD4<Float>(0.1, 0.1, 0.1, t),
                fogParams:      SIMD4<Float>(100, 200, 0, 0),
                fogColor:       SIMD4<Float>(0, 0, 0, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(glowPL)
            enc.setDepthStencilState(depthROState)
            enc.setCullMode(.none)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            let rot = m4RotX(t * 0.25) * m4RotY(t * 0.4) * m4RotZ(t * 0.15)
            for i in 0..<min(activeShapeCount, shapes.count) {
                let s  = shapes[i]
                let bx = sin(t * s.freq + s.phX) * 5.5
                let by = cos(t * s.freq * 0.7 + s.phY) * 3.5
                let bz = sin(t * s.freq * 0.5 + s.phZ) * 1.5
                let model = m4Translation(bx, by, bz) * rot
                encodeDraw(encoder: enc, vertexBuffer: s.buf, vertexCount: s.count,
                           model: model,
                           emissiveColor: s.emissive, emissiveMix: 1.0, opacity: 0.85)
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate                 = context.coordinator
        v.colorPixelFormat         = .bgra8Unorm
        v.depthStencilPixelFormat  = .depth32Float
        v.clearColor               = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
