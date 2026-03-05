// ArtDecoLA3DScene — Art Deco LA boulevard at golden hour.
// Five paired buildings, palm trees, a red streetcar, and a sweeping searchlight.
// Tap: searchlight sweeps — sin(age * Pi) * Pi over 4 seconds.

import SwiftUI
import MetalKit

struct ArtDecoLA3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { ArtDecoLARepresentable(interaction: interaction) }
}

private struct ArtDecoLARepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?
        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1
        var searchlightT: Float = -999

        struct DrawCall {
            var buffer: MTLBuffer
            var count:  Int
            var model:  simd_float4x4
            var emissiveColor: SIMD3<Float>
            var emissiveMix: Float
            var opacity: Float
            var isGlow: Bool
        }
        var drawCalls: [DrawCall] = []

        // Streetcar buffers
        var streetcarBodyBuf:   MTLBuffer?
        var streetcarBodyCount: Int = 0
        var streetcarWinBufs:   [(MTLBuffer, Int)] = []

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("ArtDecoLA3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func add(_ verts: [Vertex3D], model: simd_float4x4,
                         emissive: SIMD3<Float> = .zero, emissiveMix: Float = 0,
                         opacity: Float = 1, isGlow: Bool = false) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            drawCalls.append(DrawCall(buffer: buf, count: verts.count, model: model,
                                      emissiveColor: emissive, emissiveMix: emissiveMix,
                                      opacity: opacity, isGlow: isGlow))
        }

        private func buildScene() {
            // Ground + road
            add(buildPlane(w: 30, d: 30, color: [0.28, 0.27, 0.25, 1]),
                model: matrix_identity_float4x4)
            add(buildBox(w: 5, h: 0.01, d: 30, color: [0.36, 0.34, 0.32, 1]),
                model: m4Translation(0, 0.01, -10))

            // Art Deco buildings — 5 pairs
            let heights: [Float] = [3, 5, 6, 4, 8]
            let widths:  [Float] = [1.5, 2.0, 1.8, 1.6, 2.2]
            let zPos:    [Float] = [-3, -6, -9, -12, -15]
            let decoStone: SIMD4<Float>  = [0.62, 0.52, 0.36, 1]
            let goldColor: SIMD4<Float>  = [0.85, 0.65, 0.10, 1]
            let winColor:  SIMD4<Float>  = [0.95, 0.75, 0.35, 1]
            let goldEmissive: SIMD3<Float> = [0.40, 0.28, 0.04]
            let winEmissive:  SIMD3<Float> = [0.90, 0.70, 0.20]

            for i in 0..<5 {
                let h = heights[i], w = widths[i], z = zPos[i]
                for side: Float in [-1, 1] {
                    let x = side * 3.5
                    // Body
                    add(buildBox(w: w, h: h, d: 1.6, color: decoStone),
                        model: m4Translation(x, h / 2, z))
                    // Gold cornice
                    add(buildBox(w: w + 0.1, h: 0.14, d: 1.7, color: goldColor),
                        model: m4Translation(x, h + 0.07, z),
                        emissive: goldEmissive, emissiveMix: 0.6, isGlow: true)
                    // Windows (3, evenly spaced vertically)
                    for row in 0..<3 {
                        let wy = h * Float(row + 1) / 4
                        add(buildBox(w: 0.25, h: 0.18, d: 0.04, color: winColor),
                            model: m4Translation(x, wy, z + 0.81),
                            emissive: winEmissive, emissiveMix: 0.9, opacity: 1, isGlow: true)
                    }
                }
            }

            // Palm trees at 4 positions
            let palmPos: [(Float, Float)] = [(-2.8, -4), (2.8, -7), (-2.8, -10), (2.8, -13)]
            let trunkColor: SIMD4<Float> = [0.52, 0.38, 0.18, 1]
            let frondColor: SIMD4<Float> = [0.20, 0.50, 0.15, 1]
            for (px, pz) in palmPos {
                // Trunk: cylinder h=3, centered at y=1.5
                add(buildCylinder(radius: 0.10, height: 3, segments: 8, color: trunkColor),
                    model: m4Translation(px, 1.5, pz))
                // 6 fronds fanning from top
                for fi in 0..<6 {
                    let angle = Float(fi) * 2 * .pi / 6
                    let tiltX = Float.pi * 0.28
                    let tiltZ = Float.pi * 0.12
                    let rot   = m4RotY(angle) * m4RotX(tiltX) * m4RotZ(tiltZ)
                    add(buildBox(w: 0.6, h: 0.05, d: 0.15, color: frondColor),
                        model: m4Translation(px + sin(angle) * 0.35,
                                             3.1,
                                             pz + cos(angle) * 0.35) * rot)
                }
            }

            // Searchlight base at (0, 0, -8)
            add(buildCylinder(radius: 0.15, height: 0.5, segments: 8,
                               color: [0.4, 0.4, 0.45, 1]),
                model: m4Translation(0, 0.25, -8))

            // Streetcar buffers (built once, used with dynamic model each frame)
            let carVerts = buildBox(w: 1.0, h: 1.2, d: 3, color: [0.80, 0.10, 0.08, 1])
            streetcarBodyBuf   = makeVertexBuffer(carVerts, device: device)
            streetcarBodyCount = carVerts.count
            for woff: Float in [-1, 0, 1] {
                let wverts = buildBox(w: 0.32, h: 0.28, d: 0.04,
                                      color: [1.0, 0.85, 0.50, 1])
                if let wb = makeVertexBuffer(wverts, device: device) {
                    streetcarWinBufs.append((wb, wverts.count))
                }
            }
        }

        func handleTap(t: Float) { searchlightT = t }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque   = opaquePipeline,
                  let glowPL   = glowPipeline,
                  let ppipe    = particlePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t        = Float(CACurrentMediaTime() - startTime)
            let tMod     = t.truncatingRemainder(dividingBy: 30)
            let eyeZ     = 5 - tMod / 30 * 18
            let eye: SIMD3<Float>    = [sin(t * 0.02) * 2, 2.5, eyeZ]
            let center: SIMD3<Float> = [0, 2, eyeZ - 8]
            let viewM = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.1, far: 100)
            let vp    = projM * viewM

            let sunDir: SIMD3<Float> = simd_normalize([-0.5, -0.6, -0.4])
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(1.0, 0.72, 0.30, 0),
                ambientColor:   SIMD4<Float>(0.15, 0.10, 0.06, t),
                fogParams:      SIMD4<Float>(25, 60, 0, 0),
                fogColor:       SIMD4<Float>(0.08, 0.04, 0.02, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(opaque)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in drawCalls where !call.isGlow {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Streetcar body (dynamic position)
            let carZ = 5 - (t.truncatingRemainder(dividingBy: 20) / 20) * 25
            if let cb = streetcarBodyBuf {
                encodeDraw(encoder: enc, vertexBuffer: cb, vertexCount: streetcarBodyCount,
                           model: m4Translation(0, 0.6, carZ))
            }

            enc.setRenderPipelineState(glowPL)
            enc.setDepthStencilState(depthROState)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in drawCalls where call.isGlow {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveColor, emissiveMix: call.emissiveMix,
                           opacity: call.opacity)
            }

            // Streetcar windows
            let winEmissive: SIMD3<Float> = [0.90, 0.70, 0.20]
            for (idx, pair) in streetcarWinBufs.enumerated() {
                let wz  = carZ + Float(idx - 1) * 0.95
                let wm  = m4Translation(0.52, 0.75, wz)
                encodeDraw(encoder: enc, vertexBuffer: pair.0, vertexCount: pair.1,
                           model: wm, emissiveColor: winEmissive, emissiveMix: 0.9)
            }

            // Searchlight beam particles
            let slAge    = t - searchlightT
            let tapSweep = slAge < 4.0 ? sin(slAge * .pi) * .pi : Float(0)
            let slAngle  = t * 0.5 + tapSweep
            var particles: [ParticleVertex3D] = []
            for i in 0..<30 {
                let dist  = Float(i) * 0.4 + 0.2
                let px    = sin(slAngle) * dist
                let py    = dist * 0.8
                let pz    = cos(slAngle) * dist - 8
                let alpha = max(0, 0.4 - dist * 0.03)
                let col: SIMD4<Float> = [0.9, 0.95, 1.0, alpha]
                let sz    = 6 + dist * 0.3
                particles.append(ParticleVertex3D(position: [px, py, pz], color: col, size: sz))
            }
            if let pbuf = makeParticleBuffer(particles, device: device) {
                enc.setRenderPipelineState(ppipe)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles.count)
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
        v.clearColor               = MTLClearColor(red: 0.08, green: 0.04, blue: 0.02, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.handleTap(t: t)
    }
}
