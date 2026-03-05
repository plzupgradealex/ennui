// FloatingKingdom3DMetalScene — Floating sky island with crystalline spires and waterfall.
// FF6 Zeal / Esper homage. Island bobs gently, spires pulse, golden motes drift, clouds below.
// Tap to pulse energy through all crystalline spires.
// Rendered in Metal (MTKView) — no SceneKit. Seed 12000.

import SwiftUI
import MetalKit

struct FloatingKingdom3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        FloatingKingdom3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct FloatingKingdom3DMetalRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

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

        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        // Spire indices in glowCalls for pulse on tap
        var spireIndices: [Int] = []

        // Rocky chunks beneath island — stored separately for bobbing
        var islandOpaqueCalls: [DrawCall] = []

        // Cloud puff positions
        var cloudPos:   [SIMD3<Float>] = []
        var cloudPhase: [Float]        = []

        // Golden mote positions
        var motePos:   [SIMD3<Float>] = []
        var motePhase: [Float]        = []

        // Waterfall drop particles
        var fallPos:   [SIMD3<Float>] = []
        var fallPhase: [Float]        = []

        // Tap pulse
        var spirePulseT: Float = -100

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
            } catch { print("FloatingKingdom3DMetal pipeline error: \(error)") }
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

        private func addIslandOpaque(_ v: [Vertex3D], model: simd_float4x4,
                                      emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            islandOpaqueCalls.append(DrawCall(buffer: buf, count: v.count,
                                              model: model, emissiveCol: emissive, emissiveMix: mix))
        }

        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, mix: Float = 1.0, opacity: Float) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count,
                                      model: model, emissiveCol: emissive,
                                      emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 12000)

            // ── Island top — green grassy surface ──
            addIslandOpaque(buildBox(w: 8, h: 1.5, d: 8, color: [0.28, 0.55, 0.22, 1]),
                            model: matrix_identity_float4x4)

            // ── Rocky underside ──
            addIslandOpaque(buildBox(w: 7, h: 2, d: 7, color: [0.40, 0.35, 0.28, 1]),
                            model: m4Translation(0, -1.8, 0))

            // Jagged chunks below
            for _ in 0..<6 {
                let w = Float(0.8 + Double.random(in: 0...1.5, using: &rng))
                let h = Float(0.5 + Double.random(in: 0...1.2, using: &rng))
                let d = Float(0.8 + Double.random(in: 0...1.5, using: &rng))
                let cx = Float(Double.random(in: -2.5...2.5, using: &rng))
                let cy = Float(-3.0 - Double.random(in: 0...1.0, using: &rng))
                let cz = Float(Double.random(in: -2.5...2.5, using: &rng))
                addIslandOpaque(buildBox(w: w, h: h, d: d, color: [0.40, 0.35, 0.28, 1]),
                                model: m4Translation(cx, cy, cz) *
                                       m4RotY(Float(Double.random(in: 0...3.14, using: &rng))))
            }

            // ── Crystalline spires ──
            let spirePositions: [(Float, Float, Float)] = [
                (-3.0, 0.75, -3.0), (3.0, 0.75, -3.0),
                (-3.0, 0.75, 3.0), (3.0, 0.75, 3.0),
                (0.0, 0.75, 0.0)
            ]
            let spireCol: SIMD4<Float> = [0.75, 0.88, 1.0, 1]
            for (sx, sy, sz) in spirePositions {
                spireIndices.append(glowCalls.count)
                addGlow(buildPyramid(bw: 0.6, bd: 0.6, h: 2.5, color: spireCol),
                        model: m4Translation(sx, sy, sz),
                        emissive: [0.40, 0.60, 0.90], mix: 0.7, opacity: 0.55)
            }

            // ── Waterfall on the side ──
            addGlow(buildQuad(w: 0.5, h: 3.0, color: [0.70, 0.85, 1.0, 1], normal: [1, 0, 0]),
                    model: m4Translation(4.0, -0.75, 0),
                    emissive: [0.40, 0.60, 0.90], mix: 0.5, opacity: 0.30)

            // ── Pre-compute golden motes above island ──
            for _ in 0..<20 {
                let mx = Float(Double.random(in: -3.5...3.5, using: &rng))
                let my = Float(Double.random(in: 0.8...3.0, using: &rng))
                let mz = Float(Double.random(in: -3.5...3.5, using: &rng))
                motePos.append([mx, my, mz])
                motePhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
            }

            // ── Pre-compute cloud puffs below island ──
            for _ in 0..<18 {
                let cx = Float(Double.random(in: -10.0...10.0, using: &rng))
                let cy = Float(-4.0 - Double.random(in: 0...3.0, using: &rng))
                let cz = Float(Double.random(in: -10.0...10.0, using: &rng))
                cloudPos.append([cx, cy, cz])
                cloudPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
            }

            // ── Pre-compute waterfall drops ──
            for _ in 0..<15 {
                let fy = Float(Double.random(in: -2.5...0.75, using: &rng))
                let fz = Float(Double.random(in: -0.3...0.3, using: &rng))
                fallPos.append([4.0, fy, fz])
                fallPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
            }
        }

        func handleTap() {
            spirePulseT = Float(CACurrentMediaTime() - startTime)
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

            let spirePulse = max(0, 1 - (t - spirePulseT) / 2.0) * 1.5

            // Island bob
            let bobY = 0.3 * sin(t * (2 * Float.pi / 8.0))
            let islandOffset = m4Translation(0, bobY, 0)

            // Camera — slow orbit looking slightly down at the island
            let orbitAngle = t * (2 * Float.pi / 80.0)
            let camR: Float = 12.0
            let eye: SIMD3<Float> = [camR * sin(orbitAngle),
                                      -2.0 + 0.5 * sin(t * 0.15),
                                      camR * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, bobY, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 70 * .pi / 180, aspect: aspect, near: 0.1, far: 60)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([-0.3, -0.8, 0.4])
            let sunCol: SIMD3<Float> = [1.0, 0.97, 0.88]
            let ambCol: SIMD3<Float> = [0.25, 0.28, 0.35]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(15, 50, 0, 0),
                fogColor:       SIMD4<Float>(0.40, 0.60, 0.85, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Static opaque geometry (none for this scene, but kept for structure)
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Island opaque geometry (bobbing)
            for call in islandOpaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: islandOffset * call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Glow pass — spires + waterfall
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                let baseGlow = 0.3 + 0.25 * sin(t * 1.2)
                for (i, call) in glowCalls.enumerated() {
                    var em = call.emissiveCol
                    var op = call.opacity
                    var model = call.model
                    if spireIndices.contains(i) {
                        // Spires bob with island
                        model = islandOffset * call.model
                        let pulse = baseGlow + spirePulse
                        em = em * (1 + pulse * 0.6)
                        op = op * (1 + spirePulse * 0.3)
                    }
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: model,
                               emissiveColor: em, emissiveMix: call.emissiveMix,
                               opacity: min(1, op))
                }
            }

            // Particle pass — golden motes, cloud puffs, waterfall drops
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Golden motes above island
                for i in motePos.indices {
                    let ph   = motePhase[i]
                    let base = motePos[i]
                    let wx = base.x + 0.4 * sin(t * 0.2 + ph)
                    let wy = base.y + bobY + 0.3 * sin(t * 0.35 + ph * 1.3)
                    let wz = base.z + 0.3 * cos(t * 0.18 + ph)
                    let alpha = 0.5 + 0.3 * abs(sin(t * 0.5 + ph))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [1.0, 0.88, 0.30, alpha], size: 5))
                }

                // Cloud puffs drifting below
                for i in cloudPos.indices {
                    let ph   = cloudPhase[i]
                    let base = cloudPos[i]
                    let wx = base.x + t * 0.1 + 0.5 * sin(ph)
                    let wrappedX = fmod(wx + 10, 20.0) - 10.0
                    let wy = base.y + 0.2 * sin(t * 0.1 + ph)
                    let wz = base.z
                    particles.append(ParticleVertex3D(
                        position: [wrappedX, wy, wz],
                        color: [0.90, 0.90, 0.95, 0.35], size: 18))
                }

                // Waterfall drops
                for i in fallPos.indices {
                    let ph = fallPhase[i]
                    let fallCycle = fmod(t * 1.2 + ph, 2.0)
                    let fy = 0.75 - fallCycle * 1.8
                    let fz = fallPos[i].z + 0.1 * sin(t * 2.0 + ph)
                    let alpha: Float = fallCycle < 1.8 ? 0.5 : 0.0
                    particles.append(ParticleVertex3D(
                        position: [4.1, fy + bobY, fz],
                        color: [0.75, 0.88, 1.0, alpha], size: 4))
                }

                if let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.clearColor               = MTLClearColor(red: 0.40, green: 0.60, blue: 0.85, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.handleTap()
    }
}
