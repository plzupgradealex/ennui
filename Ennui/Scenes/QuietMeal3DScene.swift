// QuietMeal3DScene — Rainy restaurant exterior at dusk.
// Outside at night, looking through a plate-glass window at two friends at a warm table.
// Tap: heavy rain burst — rain increases from 80 to 250 drops for 1.5 seconds.

import SwiftUI
import MetalKit

struct QuietMeal3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { QuietMealRepresentable(interaction: interaction) }
}

private struct QuietMealRepresentable: NSViewRepresentable {
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
        var burstT: Float = -999

        struct DrawCall {
            var buffer: MTLBuffer
            var count:  Int
            var model:  simd_float4x4
            var emissiveColor: SIMD3<Float>
            var emissiveMix: Float
            var opacity: Float
        }
        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        // Rain data
        var rainX:     [Float] = []
        var rainZ:     [Float] = []
        var rainPhase: [Float] = []
        var rainSpeed: [Float] = []

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("QuietMeal3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ verts: [Vertex3D], at pos: SIMD3<Float>,
                                rot: simd_float4x4 = matrix_identity_float4x4) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: verts.count,
                                        model: m4Translation(pos.x, pos.y, pos.z) * rot,
                                        emissiveColor: .zero, emissiveMix: 0, opacity: 1))
        }

        private func addGlow(_ verts: [Vertex3D], at pos: SIMD3<Float>,
                              rot: simd_float4x4 = matrix_identity_float4x4,
                              emissive: SIMD3<Float>, emissiveMix: Float, opacity: Float = 1) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: verts.count,
                                      model: m4Translation(pos.x, pos.y, pos.z) * rot,
                                      emissiveColor: emissive, emissiveMix: emissiveMix,
                                      opacity: opacity))
        }

        private func buildScene() {
            let brickColor: SIMD4<Float>  = [0.18, 0.14, 0.12, 1]
            let frameColor: SIMD4<Float>  = [0.12, 0.11, 0.10, 1]
            let wallColor: SIMD4<Float>   = [0.32, 0.26, 0.21, 1]
            let floorColor: SIMD4<Float>  = [0.22, 0.18, 0.14, 1]
            let tableColor: SIMD4<Float>  = [0.40, 0.30, 0.20, 1]
            let legColor: SIMD4<Float>    = [0.35, 0.26, 0.18, 1]
            let awningColor: SIMD4<Float> = [0.15, 0.35, 0.18, 1]
            let sidewalkC: SIMD4<Float>   = [0.22, 0.22, 0.25, 1]
            let figColor: SIMD4<Float>    = [0.30, 0.22, 0.18, 1]
            let skinColor: SIMD4<Float>   = [0.70, 0.55, 0.45, 1]
            let bowlColor: SIMD4<Float>   = [0.82, 0.78, 0.72, 1]

            // -- Exterior brick panels around window opening --
            addOpaque(buildBox(w: 1.6, h: 3.5, d: 0.15, color: brickColor), at: [-2.0, 0.75, 0])
            addOpaque(buildBox(w: 1.6, h: 3.5, d: 0.15, color: brickColor), at: [2.0, 0.75, 0])
            addOpaque(buildBox(w: 2.8, h: 0.8, d: 0.15, color: brickColor), at: [0, 2.3, 0])
            addOpaque(buildBox(w: 2.8, h: 0.6, d: 0.15, color: brickColor), at: [0, -0.6, 0])

            // Window frame (thin dark metal strips)
            addOpaque(buildBox(w: 0.06, h: 2.3, d: 0.06, color: frameColor), at: [-1.26, 0.8, 0.09])
            addOpaque(buildBox(w: 0.06, h: 2.3, d: 0.06, color: frameColor), at: [ 1.26, 0.8, 0.09])
            addOpaque(buildBox(w: 2.6,  h: 0.06, d: 0.06, color: frameColor), at: [0, 1.94, 0.09])
            addOpaque(buildBox(w: 2.6,  h: 0.06, d: 0.06, color: frameColor), at: [0, -0.32, 0.09])

            // Overhead awning
            addOpaque(buildBox(w: 3.5, h: 0.1, d: 1.2, color: awningColor), at: [0, 2.6, 0.6])

            // Sidewalk
            addOpaque(buildPlane(w: 6, d: 3, color: sidewalkC), at: [0, -1.2, 1.5])

            // -- Interior (behind glass, z < 0) --
            // Back wall with warm paint
            addOpaque(buildBox(w: 3.2, h: 3.0, d: 0.1, color: wallColor), at: [0, 0.5, -2.5])
            // Side walls
            addOpaque(buildBox(w: 0.1, h: 3.0, d: 2.8, color: wallColor), at: [-1.6, 0.5, -1.2])
            addOpaque(buildBox(w: 0.1, h: 3.0, d: 2.8, color: wallColor), at: [1.6, 0.5, -1.2])
            // Floor
            addOpaque(buildBox(w: 3.2, h: 0.05, d: 2.8, color: floorColor), at: [0, -0.88, -1.2])

            // Table top
            addOpaque(buildBox(w: 1.0, h: 0.06, d: 0.55, color: tableColor), at: [0, 0.0, -1.4])
            // Table legs (4)
            for lx in [Float(-0.43), Float(0.43)] {
                for lz in [Float(-1.2), Float(-1.6)] {
                    addOpaque(buildBox(w: 0.05, h: 0.90, d: 0.05, color: legColor),
                              at: [lx, -0.48, lz])
                }
            }

            // Bowls (cylinders, warm content)
            addOpaque(buildCylinder(radius: 0.10, height: 0.07, segments: 10, color: bowlColor),
                      at: [-0.25, 0.065, -1.4])
            addOpaque(buildCylinder(radius: 0.10, height: 0.07, segments: 10, color: bowlColor),
                      at: [ 0.25, 0.065, -1.4])
            // Warm soup glow from bowls
            addGlow(buildCylinder(radius: 0.085, height: 0.01, segments: 10,
                                  color: [0.95, 0.60, 0.20, 1]),
                    at: [-0.25, 0.10, -1.4],
                    emissive: [0.95, 0.60, 0.20], emissiveMix: 0.9, opacity: 0.8)
            addGlow(buildCylinder(radius: 0.085, height: 0.01, segments: 10,
                                  color: [0.95, 0.60, 0.20, 1]),
                    at: [ 0.25, 0.10, -1.4],
                    emissive: [0.95, 0.60, 0.20], emissiveMix: 0.9, opacity: 0.8)

            // Figure A — left, facing table
            addOpaque(buildBox(w: 0.28, h: 0.55, d: 0.20, color: figColor),
                      at: [-0.35, -0.35, -1.7])
            addOpaque(buildSphere(radius: 0.11, rings: 6, segments: 8, color: skinColor),
                      at: [-0.35, 0.05, -1.7])

            // Figure B — right, facing across
            addOpaque(buildBox(w: 0.28, h: 0.55, d: 0.20, color: figColor),
                      at: [0.35, -0.35, -1.1])
            addOpaque(buildSphere(radius: 0.11, rings: 6, segments: 8, color: skinColor),
                      at: [0.35, 0.05, -1.1])

            // Hanging lamp (emissive sphere)
            addGlow(buildSphere(radius: 0.12, rings: 6, segments: 8, color: [1.0, 0.85, 0.5, 1]),
                    at: [0, 1.6, -1.4],
                    emissive: [1.0, 0.75, 0.30], emissiveMix: 1.0)

            // NEON OPEN sign (pink/red)
            addGlow(buildBox(w: 0.5, h: 0.12, d: 0.02, color: [1.0, 0.1, 0.3, 1]),
                    at: [1.0, 1.5, -2.48],
                    emissive: [1.0, 0.10, 0.30], emissiveMix: 1.0)

            // Back wall warm emissive glow (lit by lamp)
            addGlow(buildBox(w: 3.0, h: 2.6, d: 0.02, color: [0.55, 0.38, 0.22, 1]),
                    at: [0, 0.5, -2.44],
                    emissive: [0.55, 0.38, 0.22], emissiveMix: 0.35, opacity: 0.6)

            // Window glass (translucent, slight blue-warm emissive)
            addGlow(buildQuad(w: 2.5, h: 2.16, color: [0.35, 0.45, 0.55, 0.3],
                              normal: [0, 0, 1]),
                    at: [0, 0.8, 0.08],
                    emissive: [0.30, 0.35, 0.45], emissiveMix: 0.12, opacity: 0.30)

            // Rain data setup
            var rng = SplitMix64(seed: 7777)
            for _ in 0..<250 {
                rainX.append(Float(rng.nextDouble() * 7 - 3.5))
                rainZ.append(Float(rng.nextDouble() * 5 - 0.5))
                rainPhase.append(Float(rng.nextDouble() * 10))
                rainSpeed.append(Float(rng.nextDouble() * 2 + 4))
            }
        }

        func handleTap(t: Float) { burstT = t }

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

            let t         = Float(CACurrentMediaTime() - startTime)
            let sway      = 0.1 * sin(t * 0.3)
            let eye: SIMD3<Float>    = [-0.5 + sway, 0.8, 2.5]
            let center: SIMD3<Float> = [0, 0.5, -0.5]
            let viewM = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.05, far: 30)
            let vp    = projM * viewM

            let sunDir: SIMD3<Float> = simd_normalize([-0.3, -0.8, -0.5])
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(0.2, 0.15, 0.10, 0),
                ambientColor:   SIMD4<Float>(0.06, 0.05, 0.08, t),
                fogParams:      SIMD4<Float>(5, 15, 0, 0),
                fogColor:       SIMD4<Float>(0.06, 0.07, 0.12, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(opaque)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            enc.setRenderPipelineState(glowPL)
            enc.setDepthStencilState(depthROState)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in glowCalls {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveColor, emissiveMix: call.emissiveMix,
                           opacity: call.opacity)
            }

            // Rain particles
            let burstAge     = t - burstT
            let isBurst      = burstAge < 1.5
            let visibleDrops = isBurst ? 250 : 80
            var particles: [ParticleVertex3D] = []

            for i in 0..<visibleDrops {
                let rawY  = rainSpeed[i] * t + rainPhase[i]
                let y     = 8 - rawY.truncatingRemainder(dividingBy: 10)
                let alpha = Float(0.55 + 0.3 * Double(i % 7) / 7.0)
                let col: SIMD4<Float> = [0.7, 0.8, 0.95, alpha]
                let size  = Float(2 + (i % 3))
                particles.append(ParticleVertex3D(
                    position: [rainX[i], y, rainZ[i]], color: col, size: size))
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
        v.clearColor               = MTLClearColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)
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
