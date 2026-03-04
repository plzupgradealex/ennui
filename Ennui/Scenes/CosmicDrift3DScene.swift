// CosmicDrift3DScene — Metal 3D deep-space: central star, orbiting planets, star-field particles.
// Tap to flash the central star.

import SwiftUI
import MetalKit

struct CosmicDrift3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        CosmicDrift3DRepresentable(interaction: interaction)
    }
}

private struct CosmicDrift3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {

        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:   MTLDepthStencilState?
        var depthROState: MTLDepthStencilState?

        struct DrawCall {
            var buffer: MTLBuffer; var count: Int
            var model: simd_float4x4
            var emissiveCol: SIMD3<Float>; var emissiveMix: Float; var opacity: Float = 1
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        struct PlanetData {
            var buffer: MTLBuffer; var count: Int
            var orbitRadius: Float; var period: Float
            var tiltX: Float; var tiltZ: Float
            var emissiveCol: SIMD3<Float>
        }
        var planets: [PlanetData] = []

        // Star particles — precomputed to avoid RNG in draw loop
        var starPositions:   [SIMD3<Float>] = []
        var starPhases:      [Float] = []
        var starBrightness:  [Float] = []
        var starSizes:       [Float] = []
        var starWarmth:      [Float] = []

        // Tap
        var starFlashT:  Float = -999
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
            } catch { print("CosmicDrift3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                        emissiveCol: emissive, emissiveMix: mix))
        }
        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, opacity: Float = 0.9) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            transparentCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                             emissiveCol: emissive, emissiveMix: 1.0,
                                             opacity: opacity))
        }

        private func buildScene() {
            // Sky sphere (opaqueCalls[0])
            addOpaque(buildSphere(radius: 42, rings: 8, segments: 16,
                                  color: [0.008, 0.008, 0.03, 1]),
                      model: matrix_identity_float4x4)

            // Central star (opaqueCalls[1]) — emissive boosted on tap
            addOpaque(buildSphere(radius: 0.85, rings: 10, segments: 18,
                                  color: [1.0, 0.95, 0.7, 1]),
                      model: matrix_identity_float4x4,
                      emissive: [1.0, 0.9, 0.5], mix: 1.0)

            // Outer star halo (transparentCalls[0])
            addGlow(buildSphere(radius: 1.4, rings: 6, segments: 12,
                                color: [1, 0.8, 0.4, 0.25]),
                    model: matrix_identity_float4x4,
                    emissive: [1.0, 0.7, 0.3], opacity: 0.25)

            // Planets: (orbitR, size, period, tiltX, tiltZ, color, emissive)
            let cfgs: [(Float,Float,Float,Float,Float,SIMD4<Float>,SIMD3<Float>)] = [
                (3,  0.30, 20, 0.00, 0.00, [0.20, 0.40, 0.90, 1], [0.10, 0.18, 0.55]),
                (5,  0.50, 35, 0.15, 0.08, [0.80, 0.35, 0.15, 1], [0.45, 0.12, 0.04]),
                (7,  0.40, 50, 0.25, 0.15, [0.10, 0.60, 0.55, 1], [0.04, 0.28, 0.28]),
                (9,  0.55, 42, 0.10, 0.20, [0.55, 0.20, 0.75, 1], [0.28, 0.05, 0.48]),
                (11, 0.45, 60, 0.20, 0.10, [0.80, 0.70, 0.45, 1], [0.38, 0.28, 0.10]),
            ]
            for cfg in cfgs {
                let verts = buildSphere(radius: cfg.1, rings: 8, segments: 14, color: cfg.5)
                if let buf = makeVertexBuffer(verts, device: device) {
                    planets.append(PlanetData(buffer: buf, count: verts.count,
                                              orbitRadius: cfg.0, period: cfg.2,
                                              tiltX: cfg.3, tiltZ: cfg.4,
                                              emissiveCol: cfg.6))
                }
            }

            // Star field — precompute all per-star properties
            var rng = SplitMix64(seed: 1001)
            for _ in 0..<220 {
                let theta = Float(Double.random(in: 0...(2 * .pi), using: &rng))
                let phi   = Float(Double.random(in: 0...(.pi),     using: &rng))
                let r     = Float(Double.random(in: 30...40,       using: &rng))
                starPositions .append([r * sin(phi)*cos(theta), r * cos(phi), r * sin(phi)*sin(theta)])
                starPhases    .append(Float(Double.random(in: 0...(2 * .pi), using: &rng)))
                starBrightness.append(Float(Double.random(in: 0.4...1.0,    using: &rng)))
                starSizes     .append(Float(Double.random(in: 2.5...8.0,    using: &rng)))
                starWarmth    .append(Float(Double.random(in: 0...1,        using: &rng)))
            }
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Star flash: spike then decay
            let flashAge = t - starFlashT
            let flashBoost: Float = flashAge < 4 ? 1.5 * max(0, 1 - flashAge / 0.9) : 0

            // Camera slow orbit (80 s period)
            let camA = t * (2 * .pi / 80.0)
            let eye: SIMD3<Float> = [13 * sin(camA), 7, 13 * cos(camA)]
            let vp = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.1, far: 120) *
                     m4LookAt(eye: eye, center: .zero, up: [0, 1, 0])

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(-0.3, -0.5, -0.8)), 0),
                sunColor:       SIMD4<Float>(0.9, 0.82, 0.55, 0),
                ambientColor:   SIMD4<Float>(0.06, 0.05, 0.12, t),
                fogParams:      SIMD4<Float>(35, 70, 0, 0),
                fogColor:       SIMD4<Float>(0.008, 0.008, 0.03, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(opaque)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque calls — opaqueCalls[1] is the star, gets flash boost
            for (i, dc) in opaqueCalls.enumerated() {
                let emCol = i == 1 ? dc.emissiveCol * (1 + flashBoost) : dc.emissiveCol
                encodeDraw(encoder: enc, vertexBuffer: dc.buffer, vertexCount: dc.count,
                           model: dc.model, emissiveColor: emCol, emissiveMix: dc.emissiveMix,
                           opacity: dc.opacity)
            }

            // Orbiting planets — model matrix recomputed each frame
            for p in planets {
                let angle = t * (2 * .pi / p.period)
                let model = m4RotX(p.tiltX) * m4RotZ(p.tiltZ) *
                            m4RotY(angle) * m4Translation(p.orbitRadius, 0, 0)
                encodeDraw(encoder: enc, vertexBuffer: p.buffer, vertexCount: p.count,
                           model: model, emissiveColor: p.emissiveCol, emissiveMix: 0.35,
                           opacity: 1, specularPower: 64)
            }

            // Transparent halo pass
            if let glow = glowPipeline {
                enc.setRenderPipelineState(glow)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                for dc in transparentCalls {
                    let factor: Float = 1 + flashBoost * 0.5
                    encodeDraw(encoder: enc, vertexBuffer: dc.buffer, vertexCount: dc.count,
                               model: dc.model,
                               emissiveColor: dc.emissiveCol * factor, emissiveMix: 1.0,
                               opacity: dc.opacity * factor)
                }
            }

            // Star field particles
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []
                for i in starPositions.indices {
                    let tw    = 0.65 + 0.35 * sin(t * 0.7 + starPhases[i])
                    let alpha = starBrightness[i] * tw
                    let w     = starWarmth[i]
                    pv.append(ParticleVertex3D(position: starPositions[i],
                                               color: [0.85 + w * 0.15, 0.85, 1.0 - w * 0.3, alpha],
                                               size: starSizes[i] * tw))
                }
                if let pbuf = makeParticleBuffer(pv, device: device) {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pv.count)
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
        v.delegate = context.coordinator
        v.colorPixelFormat = .bgra8Unorm
        v.depthStencilPixelFormat = .depth32Float
        v.clearColor = MTLClearColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.starFlashT = Float(CACurrentMediaTime() - c.startTime)
    }
}
