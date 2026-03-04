// SaltLamp3DScene — Himalayan salt lamp in a warm room rendered in Metal (MTKView).
// Tap to briefly intensify the lamp's warm glow.
// No SceneKit — geometry built via Metal3DHelpers, glow animated each frame.

import SwiftUI
import MetalKit

struct SaltLamp3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        SaltLamp3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct SaltLamp3DRepresentable: NSViewRepresentable {
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

        // Index of lamp halo in transparentCalls
        var lampHaloIndex: Int = 0

        // Dust mote data (pre-computed)
        var dustPos:   [SIMD3<Float>] = []
        var dustPhase: [Float]        = []

        // Tap interaction
        var glowBoostT:  Float = -100
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
                print("SaltLamp3D pipeline error: \(error)")
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
            // Floor — dark wood
            addOpaque(buildPlane(w: 20, d: 20, color: [0.14, 0.08, 0.04, 1]),
                      model: matrix_identity_float4x4)

            // Back wall
            addOpaque(buildBox(w: 20, h: 12, d: 0.1, color: [0.10, 0.06, 0.03, 1]),
                      model: m4Translation(0, 6, -9))

            // Side walls
            addOpaque(buildBox(w: 0.1, h: 12, d: 20, color: [0.10, 0.06, 0.03, 1]),
                      model: m4Translation(-9, 6, 0))
            addOpaque(buildBox(w: 0.1, h: 12, d: 20, color: [0.10, 0.06, 0.03, 1]),
                      model: m4Translation( 9, 6, 0))

            // ── Salt lamp at (3.5, 0, -3) ──
            // Lamp base (small dark wood cylinder)
            addOpaque(buildCylinder(radius: 0.4, height: 0.25, segments: 10,
                                    color: [0.15, 0.08, 0.03, 1]),
                      model: m4Translation(3.5, 0.125, -3))
            // Lamp body (warm orange sphere — fully emissive)
            addOpaque(buildSphere(radius: 0.55, rings: 8, segments: 12,
                                  color: [0.95, 0.45, 0.18, 1]),
                      model: m4Translation(3.5, 1.0, -3),
                      emissive: [1.2, 0.5, 0.15], mix: 1.0)
            // Lamp halo (large translucent warm sphere — opacity updated in draw)
            lampHaloIndex = transparentCalls.count
            addTransparent(buildSphere(radius: 2.0, rings: 6, segments: 10,
                                       color: [1.0, 0.55, 0.20, 1]),
                            model: m4Translation(3.5, 1.0, -3),
                            emissive: [1.0, 0.45, 0.10], mix: 0.8, opacity: 0.12)

            // ── Bookshelf at (-5, 0, -8) ──
            addOpaque(buildBox(w: 3.0, h: 2.5, d: 0.5, color: [0.22, 0.14, 0.07, 1]),
                      model: m4Translation(-5, 1.25, -8))
            let bookCols: [SIMD4<Float>] = [
                [0.55, 0.12, 0.10, 1], [0.12, 0.22, 0.55, 1],
                [0.20, 0.45, 0.18, 1], [0.55, 0.45, 0.10, 1],
                [0.40, 0.12, 0.40, 1]
            ]
            for i in 0..<5 {
                let bx  = Float(i) * 0.45 - 0.9
                let bh: Float = (i % 3 == 0) ? 0.8 : ((i % 3 == 1) ? 1.1 : 0.9)
                addOpaque(buildBox(w: 0.18, h: bh, d: 0.22, color: bookCols[i]),
                          model: m4Translation(-5 + bx, bh * 0.5, -7.74))
            }

            // ── Armchair at (-2, 0, 1) ──
            let chairCol: SIMD4<Float> = [0.30, 0.18, 0.10, 1]
            addOpaque(buildBox(w: 1.2, h: 0.4, d: 1.0, color: chairCol),
                      model: m4Translation(-2, 0.4, 1))
            addOpaque(buildBox(w: 1.2, h: 1.0, d: 0.15, color: chairCol),
                      model: m4Translation(-2, 1.1, 0.52))
            addOpaque(buildBox(w: 0.15, h: 0.55, d: 1.0, color: chairCol),
                      model: m4Translation(-2.52, 0.67, 1))
            addOpaque(buildBox(w: 0.15, h: 0.55, d: 1.0, color: chairCol),
                      model: m4Translation(-1.48, 0.67, 1))

            // ── Side table next to lamp ──
            let tableWood: SIMD4<Float> = [0.25, 0.16, 0.08, 1]
            struct LegOffset { let x: Float; let z: Float }
            let legOffsets: [LegOffset] = [
                LegOffset(x: -0.3, z: -0.2), LegOffset(x:  0.3, z: -0.2),
                LegOffset(x: -0.3, z:  0.2), LegOffset(x:  0.3, z:  0.2)
            ]
            for lo in legOffsets {
                addOpaque(buildCylinder(radius: 0.04, height: 0.7, segments: 6, color: tableWood),
                          model: m4Translation(3.5 + lo.x, 0.35, -3 + lo.z))
            }
            addOpaque(buildPlane(w: 0.8, d: 0.6, color: tableWood),
                      model: m4Translation(3.5, 0.7, -3))

            // ── Plant pot at (2, 0, 2) ──
            addOpaque(buildCylinder(radius: 0.22, height: 0.45, segments: 8,
                                    color: [0.50, 0.28, 0.14, 1]),
                      model: m4Translation(2, 0.225, 2))
            addOpaque(buildSphere(radius: 0.6, rings: 5, segments: 8,
                                  color: [0.06, 0.22, 0.05, 1]),
                      model: m4Translation(2, 0.8, 2))

            // ── Round mirror on back wall at (-2, 5, -8.9) ──
            addOpaque(buildCylinder(radius: 0.65, height: 0.08, segments: 16,
                                    color: [0.55, 0.42, 0.18, 1]),
                      model: m4Translation(-2, 5, -8.9) * m4RotX(Float.pi / 2))
            addTransparent(buildQuad(w: 1.1, h: 1.1, color: [0.80, 0.85, 0.90, 1]),
                            model: m4Translation(-2, 5, -8.88),
                            emissive: [0.30, 0.25, 0.20], mix: 0.5, opacity: 0.85)

            // Pre-compute dust motes (35) near lamp area
            var rng = SplitMix64(seed: 9100)
            for _ in 0..<35 {
                let dx = Float(Double.random(in:  1.0...6.0, using: &rng))
                let dy = Float(Double.random(in:  0.3...3.5, using: &rng))
                let dz = Float(Double.random(in: -6.0...0.0, using: &rng))
                dustPos.append([dx, dy, dz])
                dustPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
            }
        }

        func handleTap() {
            glowBoostT = Float(CACurrentMediaTime() - startTime)
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

            let glowBoost = max(0, 1 - (t - glowBoostT) / 3.0) * 1.5
            let pulse     = 1.0 + 0.12 * sin(t * 1.4)

            // Camera — very slow bob, period 300 s
            let bobAngle = t * (2 * Float.pi / 300.0)
            let eye: SIMD3<Float> = [0.8 * sin(bobAngle), 4 + 0.2 * sin(t * 0.3), 8]
            let center: SIMD3<Float> = [0, 1.5, -2]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 48 * .pi / 180, aspect: aspect, near: 0.1, far: 60)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([0.3, -0.9, -0.4])
            let sunCol: SIMD3<Float> = SIMD3<Float>(0.70, 0.50, 0.30) * pulse
            let ambMult: Float = 0.22 + 0.18 * (glowBoost + pulse - 1)
            let ambCol: SIMD3<Float>  = SIMD3<Float>(0.28, 0.16, 0.06) * ambMult

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(8, 28, 0, 0),
                fogColor:       SIMD4<Float>(0.06, 0.03, 0.01, 0),
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
                for (i, call) in transparentCalls.enumerated() {
                    var op = call.opacity
                    var em = call.emissiveCol
                    if i == lampHaloIndex {
                        op = 0.12 * (1 + glowBoost) * pulse
                        em = call.emissiveCol * (1 + glowBoost * 0.5)
                    }
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: em, emissiveMix: call.emissiveMix,
                               opacity: op)
                }
            }

            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for i in dustPos.indices {
                    let ph   = dustPhase[i]
                    let base = dustPos[i]
                    let wx = base.x + 0.6 * sin(t * 0.18 + ph)
                    let wy = base.y + 0.25 * sin(t * 0.30 + ph * 1.3)
                    let wz = base.z + 0.5 * cos(t * 0.22 + ph)
                    let alpha = (0.25 + 0.20 * glowBoost) * (0.6 + 0.4 * abs(sin(t * 0.5 + ph)))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [0.95, 0.60, 0.22, min(1, alpha)], size: 4))
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
        view.clearColor               = MTLClearColor(red: 0.04, green: 0.02, blue: 0.01, alpha: 1)
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
