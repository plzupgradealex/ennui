// LushRuins3DScene — Moss-covered tropical ruins rendered in Metal (MTKView).
// Tap to release a burst of colorful butterflies.
// No SceneKit — geometry built via Metal3DHelpers, animated each frame.

import SwiftUI
import MetalKit

struct LushRuins3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        LushRuins3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct LushRuins3DRepresentable: NSViewRepresentable {
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

        // Butterfly data (pre-computed)
        var butterflyPos:   [SIMD3<Float>] = []
        var butterflyPhase: [Float]        = []
        var butterflyColor: [SIMD4<Float>] = []

        // Steam data (pre-computed)
        var steamPos:   [SIMD3<Float>] = []
        var steamPhase: [Float]        = []

        // Tap interaction
        var butterflyBoostT: Float = -100
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
                print("LushRuins3D pipeline error: \(error)")
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
            // Sky/canopy sphere
            addOpaque(buildSphere(radius: 40, rings: 6, segments: 12,
                                  color: [0.01, 0.03, 0.01, 1]),
                      model: matrix_identity_float4x4)

            // Ground
            addOpaque(buildPlane(w: 24, d: 24, color: [0.06, 0.07, 0.04, 1]),
                      model: matrix_identity_float4x4)

            // Borobudur-style stepped pyramid (5 levels + stupa)
            let stoneCol: SIMD4<Float> = [0.09, 0.10, 0.08, 1]
            struct PyramidLevel { let w: Float; let y: Float }
            let levels: [PyramidLevel] = [
                PyramidLevel(w: 9.0, y: 0.4),
                PyramidLevel(w: 7.0, y: 1.2),
                PyramidLevel(w: 5.5, y: 2.0),
                PyramidLevel(w: 4.0, y: 2.8),
                PyramidLevel(w: 2.5, y: 3.6)
            ]
            for lvl in levels {
                addOpaque(buildBox(w: lvl.w, h: 0.8, d: lvl.w, color: stoneCol),
                          model: m4Translation(0, lvl.y, 0))
            }
            addOpaque(buildCylinder(radius: 0.6, height: 1.2, segments: 10,
                                    color: [0.12, 0.13, 0.10, 1]),
                      model: m4Translation(0, 4.8, 0))

            // Moss overlays on pyramid top faces
            let mossE: SIMD3<Float> = [0.05, 0.22, 0.04]
            struct MossInfo { let w: Float; let y: Float }
            let mossLayers: [MossInfo] = [
                MossInfo(w: 8.8, y: 0.81),
                MossInfo(w: 6.8, y: 1.61),
                MossInfo(w: 5.3, y: 2.41),
                MossInfo(w: 3.8, y: 3.21),
                MossInfo(w: 2.3, y: 4.01)
            ]
            for ml in mossLayers {
                addTransparent(buildPlane(w: ml.w, d: ml.w, color: [0.05, 0.22, 0.04, 0.55]),
                                model: m4Translation(0, ml.y, 0),
                                emissive: mossE, mix: 0.3, opacity: 0.55)
            }

            // 4 large trees: trunk cylinder + sphere canopy
            let trunkCol:  SIMD4<Float> = [0.08, 0.07, 0.04, 1]
            let canopyCol: SIMD4<Float> = [0.04, 0.14, 0.03, 1]
            struct TreeSpot { let x: Float; let z: Float }
            let treeSpots: [TreeSpot] = [
                TreeSpot(x: -7, z: -6), TreeSpot(x: 8, z: -8),
                TreeSpot(x: -6, z:  6), TreeSpot(x: 9, z:  5)
            ]
            for sp in treeSpots {
                addOpaque(buildCylinder(radius: 0.3, height: 4, segments: 8, color: trunkCol),
                          model: m4Translation(sp.x, 2.0, sp.z))
                addOpaque(buildSphere(radius: 2.5, rings: 5, segments: 10, color: canopyCol),
                          model: m4Translation(sp.x, 5.5, sp.z))
            }

            // God rays — translucent pale-yellow quads slanting from upper-left
            let rayE: SIMD3<Float> = [0.78, 0.70, 0.40]
            struct RayInfo { let x: Float; let y: Float; let z: Float; let rz: Float }
            let rays: [RayInfo] = [
                RayInfo(x: -2, y: 8.0, z: -5, rz:  0.25),
                RayInfo(x:  0, y: 9.0, z: -6, rz:  0.18),
                RayInfo(x:  2, y: 8.5, z: -4, rz: -0.20)
            ]
            for ray in rays {
                addTransparent(buildQuad(w: 2.5, h: 10, color: [0.78, 0.70, 0.40, 0.07]),
                                model: m4Translation(ray.x, ray.y, ray.z) * m4RotZ(ray.rz),
                                emissive: rayE, mix: 0.7, opacity: 0.07)
            }

            // Pre-compute butterfly data (30 butterflies)
            var rng = SplitMix64(seed: 7100)
            let palette: [SIMD4<Float>] = [
                [1.0, 0.45, 0.10, 1], [1.0, 0.80, 0.10, 1],
                [0.25, 0.55, 1.0,  1], [0.90, 0.20, 0.70, 1],
                [0.20, 0.90, 0.50, 1]
            ]
            for i in 0..<30 {
                let x = Float(Double.random(in: -8...8,   using: &rng))
                let y = Float(Double.random(in:  1.0...6, using: &rng))
                let z = Float(Double.random(in: -8...8,   using: &rng))
                butterflyPos.append([x, y, z])
                butterflyPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
                butterflyColor.append(palette[i % palette.count])
            }

            // Pre-compute steam particles (20)
            var rng2 = SplitMix64(seed: 7101)
            for _ in 0..<20 {
                let x = Float(Double.random(in: -5...5, using: &rng2))
                let z = Float(Double.random(in: -5...5, using: &rng2))
                steamPos.append([x, 0.1, z])
                steamPhase.append(Float(Double.random(in: 0...6.28, using: &rng2)))
            }
        }

        func handleTap() {
            butterflyBoostT = Float(CACurrentMediaTime() - startTime)
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

            // Slow orbit — 140 s/rev
            let orbitAngle = t * (2 * Float.pi / 140.0)
            let eye: SIMD3<Float> = [16 * sin(orbitAngle), 8, 16 * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 2, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 50 * .pi / 180, aspect: aspect, near: 0.1, far: 90)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([-0.4, -0.7, -0.5])
            let sunCol: SIMD3<Float> = [0.60, 0.70, 0.35]
            let ambCol: SIMD3<Float> = [0.06, 0.10, 0.04]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(18, 55, 0, 0),
                fogColor:       SIMD4<Float>(0.01, 0.04, 0.01, 0),
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

                // Steam
                for i in steamPos.indices {
                    let ph   = steamPhase[i]
                    let rise = (t * 0.4 + ph).truncatingRemainder(dividingBy: 2.5)
                    let alpha = Float(rise < 2.0 ? rise * 0.5 : (2.5 - rise) * 2.0)
                    let p = steamPos[i]
                    let col: SIMD4<Float> = [0.55, 0.68, 0.50, max(0, alpha) * 0.4]
                    particles.append(ParticleVertex3D(
                        position: [p.x + 0.2 * sin(t * 0.5 + ph), rise, p.z],
                        color: col, size: 10))
                }

                // Butterflies
                let boost = max(0, 1 - (t - butterflyBoostT) / 5.0)
                for i in butterflyPos.indices {
                    let ph   = butterflyPhase[i]
                    let base = butterflyPos[i]
                    let wx   = base.x + 1.5 * sin(t * 0.6 + ph)
                    let wy   = base.y + 0.5 * sin(t * 1.3 + ph * 1.2)
                    let wz   = base.z + 1.5 * cos(t * 0.5 + ph * 0.8)
                    let flutter  = max(0.1, abs(sin(t * 4.0 + ph)))
                    let baseAlpha = 0.15 + 0.85 * boost
                    var col = butterflyColor[i]
                    col.w = baseAlpha * flutter
                    let sz: Float = 5 + 8 * boost
                    particles.append(ParticleVertex3D(position: [wx, wy, wz], color: col, size: sz))
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
        view.clearColor               = MTLClearColor(red: 0.01, green: 0.03, blue: 0.01, alpha: 1)
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
