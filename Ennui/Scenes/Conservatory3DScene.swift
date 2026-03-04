// Conservatory3DScene — Greenhouse conservatory with rain rendered in Metal (MTKView).
// Tap to make it rain harder for ~8 seconds.
// No SceneKit — geometry built via Metal3DHelpers, rain animated each frame.

import SwiftUI
import MetalKit

struct Conservatory3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        Conservatory3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct Conservatory3DRepresentable: NSViewRepresentable {
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
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }

        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // Rain particle data (pre-computed)
        var rainX:     [Float] = []
        var rainZ:     [Float] = []
        var rainPhase: [Float] = []
        var rainSpeed: [Float] = []

        // Steam / mist data (pre-computed)
        var steamPos:   [SIMD3<Float>] = []
        var steamPhase: [Float]        = []

        // Tap interaction
        var rainBoostT:  Float = -100
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
            } catch {
                print("Conservatory3D pipeline error: \(error)")
            }
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

        private func addTransparent(_ v: [Vertex3D], model: simd_float4x4,
                                    emissive: SIMD3<Float>, mix: Float, opacity: Float) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            transparentCalls.append(DrawCall(buffer: buf, count: v.count,
                                              model: model, emissiveCol: emissive,
                                              emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            // Rainy sky sphere
            addOpaque(buildSphere(radius: 40, rings: 6, segments: 12,
                                  color: [0.05, 0.06, 0.08, 1]),
                      model: matrix_identity_float4x4)

            // Floor — dark stone tile
            addOpaque(buildPlane(w: 14, d: 10, color: [0.12, 0.10, 0.09, 1]),
                      model: matrix_identity_float4x4)

            // Iron frame ribs — 8 thin boxes fanned radially
            let ribCol: SIMD4<Float> = [0.22, 0.23, 0.24, 1]
            for i in 0..<8 {
                let a = Float(i) * Float.pi / 8.0
                addOpaque(buildBox(w: 0.08, h: 12, d: 0.08, color: ribCol),
                          model: m4RotY(a) * m4Translation(0, 5.5, 0))
            }

            // 2 horizontal iron rings (approx as arc segments)
            for ry in [3.5, 7.0] as [Float] {
                for i in 0..<16 {
                    let a = Float(i) * (2 * Float.pi) / 16.0
                    let r: Float = 6.0
                    addOpaque(buildBox(w: 0.08, h: 0.08, d: 1.2, color: ribCol),
                              model: m4Translation(r * cos(a), ry, r * sin(a)) * m4RotY(a))
                }
            }

            // Glass roof panel (semi-transparent)
            let glassE: SIMD3<Float> = [0.40, 0.55, 0.60]
            addTransparent(buildPlane(w: 14, d: 10, color: [0.55, 0.68, 0.72, 0.18]),
                            model: m4Translation(0, 11, 0),
                            emissive: glassE, mix: 0.3, opacity: 0.18)

            // Plant bench at back
            addOpaque(buildBox(w: 8, h: 0.15, d: 1.2, color: [0.28, 0.20, 0.12, 1]),
                      model: m4Translation(0, 0.9, -4))
            addOpaque(buildBox(w: 0.08, h: 0.9, d: 1.2, color: [0.25, 0.18, 0.10, 1]),
                      model: m4Translation(-3.8, 0.45, -4))
            addOpaque(buildBox(w: 0.08, h: 0.9, d: 1.2, color: [0.25, 0.18, 0.10, 1]),
                      model: m4Translation( 3.8, 0.45, -4))

            // 4 palm-like trees
            var rng = SplitMix64(seed: 6600)
            let palmTrunk: SIMD4<Float> = [0.30, 0.20, 0.08, 1]
            let palmLeaf:  SIMD4<Float> = [0.06, 0.28, 0.06, 1]
            struct PalmSpot { let x: Float; let z: Float }
            let palmSpots: [PalmSpot] = [
                PalmSpot(x: -4, z: -3), PalmSpot(x: 4, z: -3),
                PalmSpot(x: -3, z:  2), PalmSpot(x: 3, z:  2)
            ]
            for sp in palmSpots {
                let h = Float(Double.random(in: 2.5...4.0, using: &rng))
                addOpaque(buildCylinder(radius: 0.14, height: h, segments: 7, color: palmTrunk),
                          model: m4Translation(sp.x, h * 0.5, sp.z))
                addOpaque(buildSphere(radius: 0.9, rings: 5, segments: 8, color: palmLeaf),
                          model: m4Translation(sp.x, h + 0.6, sp.z))
            }

            // 6 fern clumps (small cones)
            var rng2 = SplitMix64(seed: 6601)
            let fernCol: SIMD4<Float> = [0.04, 0.18, 0.05, 1]
            for _ in 0..<6 {
                let fx = Float(Double.random(in: -5...5, using: &rng2))
                let fz = Float(Double.random(in: -3...3, using: &rng2))
                addOpaque(buildCone(radius: 0.35, height: 0.6, segments: 7, color: fernCol),
                          model: m4Translation(fx, 0.3, fz))
            }

            // Ivy strands — thin cylinders along lower frame
            let ivyCol: SIMD4<Float> = [0.05, 0.20, 0.04, 1]
            for i in 0..<10 {
                let ix = Float(i) * 1.4 - 6.3
                addOpaque(buildCylinder(radius: 0.02, height: 3.5, segments: 4, color: ivyCol),
                          model: m4Translation(ix, 1.75, -5.0))
            }

            // Pre-compute rain (120 particles)
            var rng3 = SplitMix64(seed: 6602)
            for _ in 0..<120 {
                rainX.append(Float(Double.random(in: -7...7,   using: &rng3)))
                rainZ.append(Float(Double.random(in: -5...5,   using: &rng3)))
                rainPhase.append(Float(Double.random(in: 0...12, using: &rng3)))
                rainSpeed.append(Float(Double.random(in: 5...9,  using: &rng3)))
            }

            // Pre-compute steam/mist near plants (20 particles)
            var rng4 = SplitMix64(seed: 6603)
            for _ in 0..<20 {
                let sx = Float(Double.random(in: -4...4, using: &rng4))
                let sz = Float(Double.random(in: -4...3, using: &rng4))
                steamPos.append([sx, 0.2, sz])
                steamPhase.append(Float(Double.random(in: 0...6.28, using: &rng4)))
            }
        }

        func handleTap() {
            rainBoostT = Float(CACurrentMediaTime() - startTime)
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

            // Rain intensity — spikes on tap, decays over 8 s
            let rainBoost     = max(0, 1 - (t - rainBoostT) / 8.0) * 1.5
            let rainIntensity = 1.0 + rainBoost

            // Camera — very slight slow orbit
            let orbitAngle = t * (2 * Float.pi / 120.0)
            let eye: SIMD3<Float> = [10 * sin(orbitAngle), 5, 10 * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 2, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([-0.2, -0.9, -0.3])
            let sunCol: SIMD3<Float> = [0.40, 0.45, 0.50]
            let ambCol: SIMD3<Float> = [0.08, 0.12, 0.09]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(12, 45, 0, 0),
                fogColor:       SIMD4<Float>(0.05, 0.06, 0.08, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            if let glow = glowPipeline {
                encoder.setRenderPipelineState(glow)
                encoder.setDepthStencilState(depthROState)
                for call in transparentCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Rain drops
                let startY:    Float = 10.5
                let dropRange: Float = 12.0
                for i in rainX.indices {
                    let y = startY - (t * rainSpeed[i] + rainPhase[i]).truncatingRemainder(dividingBy: dropRange)
                    let alpha = 0.45 * min(rainIntensity, 2.0)
                    let sz:   Float = 14 * rainIntensity
                    particles.append(ParticleVertex3D(
                        position: [rainX[i], y, rainZ[i]],
                        color: [0.60, 0.68, 0.82, alpha], size: sz))
                }

                // Steam / mist near plants
                for i in steamPos.indices {
                    let ph   = steamPhase[i]
                    let base = steamPos[i]
                    let rise = (t * 0.35 + ph).truncatingRemainder(dividingBy: 2.8)
                    let alpha = Float(rise < 2.0 ? rise * 0.25 : (2.8 - rise) * 1.25)
                    let pos: SIMD3<Float> = [
                        base.x + 0.3 * sin(t * 0.4 + ph),
                        base.y + rise,
                        base.z + 0.3 * cos(t * 0.35 + ph)
                    ]
                    particles.append(ParticleVertex3D(
                        position: pos,
                        color: [0.65, 0.80, 0.65, max(0, alpha) * 0.45], size: 9))
                }

                if !particles.isEmpty,
                   let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.clearColor               = MTLClearColor(red: 0.04, green: 0.05, blue: 0.06, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
