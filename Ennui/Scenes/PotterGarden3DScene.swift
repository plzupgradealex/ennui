// PotterGarden3DScene — Metal 3D Beatrix Potter English cottage garden.
// Grass, path, wall, hedges, rabbit, flowers, watering can, gate, mushrooms, lantern.
// Tap: rabbit hops and golden sparkles scatter.

import SwiftUI
import MetalKit

struct PotterGarden3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { PotterGarden3DRepresentable(interaction: interaction) }
}

private struct PotterGarden3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

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
        var opaqueCalls:  [DrawCall] = []
        var glowCalls:    [DrawCall] = []

        struct RabbitPart {
            var buffer: MTLBuffer; var count: Int
            var baseModel: simd_float4x4
        }
        var rabbitParts: [RabbitPart] = []

        var rabbitHopT: Float = -999
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
            } catch { print("PotterGarden3D pipeline error: \(error)") }
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
                              emissive: SIMD3<Float>, mix: Float = 1.0, opacity: Float = 0.9) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                      emissiveCol: emissive, emissiveMix: mix, opacity: opacity))
        }
        private func addRabbit(_ v: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            rabbitParts.append(RabbitPart(buffer: buf, count: v.count, baseModel: model))
        }

        private func buildScene() {
            // Ground
            addOpaque(buildPlane(w: 20, d: 20, color: [0.30, 0.60, 0.20, 1]),
                      model: matrix_identity_float4x4)

            // Stone path
            addOpaque(buildBox(w: 1.2, h: 0.05, d: 8, color: [0.55, 0.52, 0.48, 1]),
                      model: m4Translation(0, 0.025, 0))

            // Stone wall at back
            addOpaque(buildBox(w: 10, h: 1.2, d: 0.4, color: [0.50, 0.48, 0.44, 1]),
                      model: m4Translation(0, 0.6, -5))

            // Hedge boxes at corners
            let hedgeCol: SIMD4<Float> = [0.20, 0.50, 0.15, 1]
            let hedgePositions: [(Float, Float)] = [(-4,-3),(4,-3),(-4,-1),(4,-1)]
            for (hx, hz) in hedgePositions {
                addOpaque(buildBox(w: 2, h: 1.5, d: 0.8, color: hedgeCol),
                          model: m4Translation(hx, 0.75, hz))
            }

            // Rabbit parts (at base position 0.8, 0, 0.5)
            let furCol: SIMD4<Float> = [0.88, 0.85, 0.80, 1]
            addRabbit(buildBox(w: 0.35, h: 0.40, d: 0.25, color: furCol),
                      model: m4Translation(0.8, 0.20, 0.5))
            addRabbit(buildSphere(radius: 0.15, rings: 6, segments: 10, color: furCol),
                      model: m4Translation(0.8, 0.55, 0.5))
            addRabbit(buildCylinder(radius: 0.03, height: 0.25, segments: 6, color: furCol),
                      model: m4Translation(0.72, 0.77, 0.5))
            addRabbit(buildCylinder(radius: 0.03, height: 0.25, segments: 6, color: furCol),
                      model: m4Translation(0.88, 0.77, 0.5))

            // Flowers (6): stem + head
            let flowerData: [(Float, Float, SIMD4<Float>, SIMD3<Float>)] = [
                (-1.5, -0.5, [0.95, 0.30, 0.40, 1], [0.95, 0.3, 0.4]),
                (-2.0,  0.5, [0.95, 0.80, 0.20, 1], [0.95, 0.8, 0.2]),
                (-1.2,  1.5, [0.80, 0.40, 0.90, 1], [0.8, 0.4, 0.9]),
                ( 2.0, -0.5, [0.95, 0.50, 0.20, 1], [0.95, 0.5, 0.2]),
                ( 2.5,  0.5, [0.30, 0.70, 0.95, 1], [0.3, 0.7, 0.95]),
                ( 1.8,  1.2, [0.95, 0.20, 0.60, 1], [0.95, 0.2, 0.6]),
            ]
            for (fx, fz, fCol, fEmissive) in flowerData {
                addOpaque(buildCylinder(radius: 0.03, height: 0.35, segments: 6,
                                        color: [0.2, 0.6, 0.1, 1]),
                          model: m4Translation(fx, 0.175, fz))
                addGlow(buildSphere(radius: 0.08, rings: 5, segments: 8, color: fCol),
                        model: m4Translation(fx, 0.38, fz),
                        emissive: fEmissive, mix: 0.3, opacity: 1.0)
            }

            // Watering can
            addOpaque(buildBox(w: 0.30, h: 0.35, d: 0.20, color: [0.30, 0.45, 0.60, 1]),
                      model: m4Translation(-1.5, 0.175, -1.0))
            addOpaque(buildCylinder(radius: 0.04, height: 0.25, segments: 6,
                                    color: [0.30, 0.45, 0.60, 1]),
                      model: m4Translation(-1.35, 0.30, -1.0) * m4RotZ(-.pi / 5))

            // Gate (two posts + horizontal bar)
            addOpaque(buildBox(w: 0.12, h: 1.5, d: 0.12, color: [0.60, 0.55, 0.45, 1]),
                      model: m4Translation(-3.9, 0.75, -1.0))
            addOpaque(buildBox(w: 0.12, h: 1.5, d: 0.12, color: [0.60, 0.55, 0.45, 1]),
                      model: m4Translation(-3.1, 0.75, -1.0))
            addOpaque(buildBox(w: 0.80, h: 0.12, d: 0.08, color: [0.60, 0.55, 0.45, 1]),
                      model: m4Translation(-3.5, 1.10, -1.0))

            // Mushrooms (2)
            let mushPositions: [(Float, Float)] = [(1.5, -1.5), (-2.5, -2.0)]
            for (mx, mz) in mushPositions {
                addOpaque(buildCylinder(radius: 0.06, height: 0.20, segments: 6,
                                        color: [0.80, 0.75, 0.65, 1]),
                          model: m4Translation(mx, 0.10, mz))
                addOpaque(buildSphere(radius: 0.15, rings: 5, segments: 8,
                                      color: [0.85, 0.25, 0.15, 1]),
                          model: m4Translation(mx, 0.25, mz) * m4Scale(1.0, 0.45, 1.0))
            }

            // Lantern: cylinder body + emissive glow sphere
            addOpaque(buildCylinder(radius: 0.12, height: 0.40, segments: 8,
                                    color: [0.80, 0.60, 0.20, 1]),
                      model: m4Translation(3.5, 0.20, -0.5))
            addGlow(buildSphere(radius: 0.14, rings: 6, segments: 10,
                                color: [1.0, 0.85, 0.40, 0.8]),
                    model: m4Translation(3.5, 0.55, -0.5),
                    emissive: [1.0, 0.85, 0.40], mix: 0.9, opacity: 0.75)
        }

        func handleTap() {
            rabbitHopT = Float(CACurrentMediaTime() - startTime)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            let orbitAngle = t * 2 * .pi / 60.0
            let eye: SIMD3<Float>    = [8 * sin(orbitAngle), 3, 8 * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 0.5, -1]
            let viewM = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.1, far: 60)
            let vp    = projM * viewM

            let sunDir: SIMD3<Float> = simd_normalize([-0.5, -0.8, -0.3])
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(1.0, 0.95, 0.80, 0),
                ambientColor:   SIMD4<Float>(0.30, 0.50, 0.25, t),
                fogParams:      SIMD4<Float>(15, 35, 0, 0),
                fogColor:       SIMD4<Float>(0.50, 0.75, 0.50, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(pipeline)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Rabbit (with optional hop offset)
            let hopAge = t - rabbitHopT
            let hopOff: Float = (hopAge >= 0 && hopAge < 0.6)
                ? 0.4 * sin(hopAge * .pi / 0.3)
                : 0
            let hopDelta = m4Translation(0, hopOff, 0)
            for part in rabbitParts {
                let model = hopDelta * part.baseModel
                encodeDraw(encoder: enc, vertexBuffer: part.buffer, vertexCount: part.count,
                           model: model, emissiveColor: .zero, emissiveMix: 0)
            }

            // Glow pass
            if let glowPL = glowPipeline {
                enc.setRenderPipelineState(glowPL)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                for call in glowCalls {
                    encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            // Sparkle particles during hop
            if let ppipe = particlePipeline, hopAge >= 0 && hopAge < 0.6 {
                var sparks: [ParticleVertex3D] = []
                var prng = SplitMix64(seed: 12345)
                for _ in 0..<30 {
                    let theta = Float(prng.nextDouble() * 2 * Double.pi)
                    let phi   = Float(prng.nextDouble() * Double.pi)
                    let speed = Float(prng.nextDouble() * 1.5 + 0.5)
                    let r     = speed * hopAge
                    let px    = Float(0.8) + r * sin(phi) * cos(theta)
                    let py    = Float(0.3) + hopOff + r * abs(cos(phi))
                    let pz    = Float(0.5) + r * sin(phi) * sin(theta)
                    let fade  = max(0, Float(1 - hopAge / 0.6))
                    let br    = fade * (0.8 + 0.2 * sin(t * 20 + r * 8))
                    let col: SIMD4<Float> = [br, br * 0.80, br * 0.10, fade]
                    sparks.append(ParticleVertex3D(position: [px, py, pz], color: col,
                                                   size: 8 * fade))
                }
                if let pbuf = makeParticleBuffer(sparks, device: device) {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: sparks.count)
                }
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
        v.clearColor               = MTLClearColor(red: 0.50, green: 0.75, blue: 0.50, alpha: 1)
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
