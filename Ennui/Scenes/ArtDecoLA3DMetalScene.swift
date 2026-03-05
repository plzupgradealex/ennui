// ArtDecoLA3DMetalScene — Metal 3D Art Deco LA boulevard at golden hour.
// Buildings with gold cornices, palm trees, red streetcar, searchlight.
// Tap to sweep the searchlight across the buildings.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct ArtDecoLA3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        ArtDecoLA3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct ArtDecoLA3DMetalRepresentable: NSViewRepresentable {
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

        // Searchlight sweep state
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
            } catch { print("ArtDecoLA3DMetal pipeline error: \(error)") }
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
            let sidewalkCol: SIMD4<Float> = [0.32, 0.28, 0.24, 1]
            let roadCol:     SIMD4<Float> = [0.36, 0.34, 0.30, 1]
            let buildingCol: SIMD4<Float> = [0.62, 0.52, 0.36, 1]
            let corniceCol:  SIMD4<Float> = [0.85, 0.65, 0.10, 1]
            let trunkCol:    SIMD4<Float> = [0.52, 0.38, 0.18, 1]
            let frondCol:    SIMD4<Float> = [0.20, 0.50, 0.15, 1]
            let carCol:      SIMD4<Float> = [0.80, 0.10, 0.08, 1]
            let windowAmber: SIMD3<Float> = [0.95, 0.75, 0.35]

            // Floor / sidewalk
            addOpaque(buildPlane(w: 12, d: 30, color: sidewalkCol),
                      model: matrix_identity_float4x4)
            // Road
            addOpaque(buildBox(w: 5, h: 0.01, d: 30, color: roadCol),
                      model: m4Translation(0, 0.005, -10))

            // Art Deco buildings — 5 per side
            let heights: [Float] = [3, 5, 6, 4, 8]
            let widths:  [Float] = [1.5, 2.0, 1.8, 1.6, 2.2]
            let zPos:    [Float] = [-3, -6, -9, -12, -15]
            for i in 0..<5 {
                for side: Float in [-1, 1] {
                    let h = heights[i]; let w = widths[i]
                    let x = side * 3.5
                    let z = zPos[i]
                    // Building body
                    addOpaque(buildBox(w: w, h: h, d: 1.5, color: buildingCol),
                              model: m4Translation(x, h / 2, z))
                    // Gold cornice
                    addOpaque(buildBox(w: w + 0.1, h: 0.14, d: 1.6, color: corniceCol),
                              model: m4Translation(x, h + 0.07, z))
                    // Windows (emissive amber glow)
                    let winFaceZ = z + (side > 0 ? -0.76 : 0.76)
                    for row in 0..<3 {
                        addGlow(buildQuad(w: 0.25, h: 0.18, color: [1, 1, 1, 1],
                                          normal: [0, 0, side > 0 ? -1 : 1]),
                                model: m4Translation(x, Float(row) * 0.65 + 0.9, winFaceZ),
                                emissive: windowAmber, opacity: 0.85)
                    }
                }
            }

            // Palm trees — 4 along the boulevard
            let palmXZ: [(Float, Float)] = [(-2.8, -4), (2.8, -7), (-2.8, -10), (2.8, -13)]
            for (px, pz) in palmXZ {
                addOpaque(buildCylinder(radius: 0.10, height: 3, segments: 6, color: trunkCol),
                          model: m4Translation(px, 1.5, pz))
                // Fronds — 6 small angled boxes
                for j in 0..<6 {
                    let ang = Float(j) * Float.pi * 2.0 / 6.0
                    let fx = px + cos(ang) * 0.45
                    let fz = pz + sin(ang) * 0.45
                    let rot = m4Translation(fx, 3.1, fz) * m4RotY(-ang) * m4RotZ(-0.45)
                    addOpaque(buildBox(w: 0.6, h: 0.05, d: 0.15, color: frondCol),
                              model: rot)
                }
            }

            // Red streetcar body (static — animated position in draw)
            addOpaque(buildBox(w: 1.0, h: 1.2, d: 3, color: carCol),
                      model: matrix_identity_float4x4) // placeholder; repositioned in draw
            // Streetcar windows
            for k in 0..<3 {
                addGlow(buildQuad(w: 0.32, h: 0.28, color: [1, 1, 1, 1], normal: [1, 0, 0]),
                        model: matrix_identity_float4x4, // repositioned in draw
                        emissive: [1.0, 0.85, 0.50], opacity: 0.85)
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

            // Camera drifts slowly down the boulevard
            let camCycle  = fmod(t, 30.0) / 30.0
            let camZ: Float = 5.0 - camCycle * 20.0
            let eye:    SIMD3<Float> = [0, 2.5, camZ]
            let center: SIMD3<Float> = [0, 2.5, camZ - 10]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.02, far: 60)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(0.5, 0.6, -0.3)), 0),
                sunColor:       SIMD4<Float>([1.0, 0.72, 0.30], 0),
                ambientColor:   SIMD4<Float>([0.12, 0.06, 0.02], t),
                fogParams:      SIMD4<Float>(15, 50, 0, 0),
                fogColor:       SIMD4<Float>([0.08, 0.04, 0.02], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Streetcar travels along z
            let carCycle = fmod(t, 20.0) / 20.0
            let carZ: Float = 5.0 - carCycle * 25.0

            // Update streetcar body model (last opaque call before glow calls are buildings' windows)
            // Streetcar body is the last opaque call
            let carBodyIdx = opaqueCalls.count - 1
            opaqueCalls[carBodyIdx].model = m4Translation(0.5, 0.6, carZ)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                // Streetcar windows are the last 3 glow calls
                let winBaseIdx = glowCalls.count - 3
                for k in 0..<3 {
                    glowCalls[winBaseIdx + k].model = m4Translation(
                        1.02, 0.7, carZ + Float(k) * 0.85 - 0.85)
                }

                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }

                // Searchlight cone — sweeps on tap or auto every ~10s
                let autoSweepT = fmod(t, 10.0) - 7.0
                let sinceTap   = t - sweepStartTime
                let active     = sinceTap < 3.1 ? sinceTap : autoSweepT
                if active >= 0 && active < 3.0 {
                    let progress = active / 3.0
                    let intensity: Float
                    if progress < 0.15 { intensity = progress / 0.15 }
                    else if progress < 0.85 { intensity = 1.0 }
                    else { intensity = (1.0 - progress) / 0.15 }
                    let sweepAngle = progress * Float.pi * 2.0
                    let sx = sin(sweepAngle) * 4.0
                    let sz = cos(sweepAngle) * 4.0 - 10.0
                    let spotVerts = buildSphere(radius: 0.4, rings: 4, segments: 6,
                                                color: [1, 1, 1, 1])
                    if let sbuf = makeVertexBuffer(spotVerts, device: device) {
                        encodeDraw(encoder: encoder, vertexBuffer: sbuf,
                                   vertexCount: spotVerts.count,
                                   model: m4Translation(sx, 6.0, sz),
                                   emissiveColor: [1.0, 0.95, 0.85] * intensity,
                                   emissiveMix: 1.0, opacity: intensity * 0.6)
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
        view.clearColor              = MTLClearColor(red: 0.08, green: 0.04, blue: 0.02, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.sweepStartTime = t
    }
}
