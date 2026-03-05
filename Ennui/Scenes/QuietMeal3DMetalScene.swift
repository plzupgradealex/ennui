// QuietMeal3DMetalScene — Two friends having a quiet meal in a restaurant,
// seen through a rain-streaked window. Warm amber interior, dark dusk outside.
// Tap to burst extra rain on the window glass.
// Rendered in Metal (MTKView) — no SceneKit. Seed 2024.

import SwiftUI
import MetalKit

struct QuietMeal3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        QuietMeal3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct QuietMeal3DMetalRepresentable: NSViewRepresentable {
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

        // Rain drop positions and phases
        var rainPos:   [SIMD2<Float>] = []
        var rainPhase: [Float]        = []

        // Steam positions and phases (above bowls)
        var steamPos:   [SIMD3<Float>] = []
        var steamPhase: [Float]        = []

        // Tap burst
        var rainBoostT: Float = -100

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
            } catch { print("QuietMeal3DMetal pipeline error: \(error)") }
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

        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, mix: Float = 1.0, opacity: Float) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count,
                                      model: model, emissiveCol: emissive,
                                      emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 2024)

            let brickCol: SIMD4<Float>    = [0.35, 0.18, 0.12, 1]
            let darkMetal: SIMD4<Float>   = [0.12, 0.12, 0.14, 1]
            let interiorWall: SIMD4<Float> = [0.40, 0.32, 0.24, 1]
            let floorCol: SIMD4<Float>    = [0.25, 0.20, 0.16, 1]
            let ceilingCol: SIMD4<Float>  = [0.35, 0.30, 0.25, 1]
            let tableCol: SIMD4<Float>    = [0.30, 0.18, 0.10, 1]
            let chairCol: SIMD4<Float>    = [0.22, 0.14, 0.08, 1]
            let sidewalkCol: SIMD4<Float> = [0.20, 0.20, 0.22, 1]
            let awningCol: SIMD4<Float>   = [0.15, 0.08, 0.06, 1]

            // ── Exterior — dark sky backdrop ──
            addOpaque(buildSphere(radius: 50, rings: 8, segments: 12,
                                  color: [0.06, 0.07, 0.12, 1]),
                      model: matrix_identity_float4x4)

            // ── Sidewalk below ──
            addOpaque(buildBox(w: 12, h: 0.2, d: 6, color: sidewalkCol),
                      model: m4Translation(0, -2.3, 2))

            // ── Wet sidewalk reflection ──
            addGlow(buildBox(w: 12, h: 0.02, d: 6, color: [0.25, 0.22, 0.18, 1]),
                    model: m4Translation(0, -2.19, 2),
                    emissive: [0.60, 0.45, 0.20], mix: 0.15, opacity: 0.2)

            // ── Brick wall — panels around window opening ──
            // Left brick panel
            addOpaque(buildBox(w: 2.5, h: 5, d: 0.4, color: brickCol),
                      model: m4Translation(-3.25, 0.5, 0))
            // Right brick panel
            addOpaque(buildBox(w: 2.5, h: 5, d: 0.4, color: brickCol),
                      model: m4Translation(3.25, 0.5, 0))
            // Top brick panel
            addOpaque(buildBox(w: 8, h: 1.2, d: 0.4, color: brickCol),
                      model: m4Translation(0, 3.3, 0))
            // Bottom brick panel
            addOpaque(buildBox(w: 4, h: 0.6, d: 0.4, color: brickCol),
                      model: m4Translation(0, -2.0, 0))

            // ── Window frame (dark metal) ──
            addOpaque(buildBox(w: 4.1, h: 0.12, d: 0.5, color: darkMetal),
                      model: m4Translation(0, 2.7, 0))
            addOpaque(buildBox(w: 4.1, h: 0.12, d: 0.5, color: darkMetal),
                      model: m4Translation(0, -1.7, 0))
            addOpaque(buildBox(w: 0.12, h: 4.5, d: 0.5, color: darkMetal),
                      model: m4Translation(-2.0, 0.5, 0))
            addOpaque(buildBox(w: 0.12, h: 4.5, d: 0.5, color: darkMetal),
                      model: m4Translation(2.0, 0.5, 0))

            // ── Interior back wall ──
            addOpaque(buildBox(w: 6, h: 5, d: 0.3, color: interiorWall),
                      model: m4Translation(0, 0.5, -3.0),
                      emissive: [0.50, 0.35, 0.15], mix: 0.08)

            // ── Interior side walls ──
            addOpaque(buildBox(w: 0.3, h: 5, d: 3, color: interiorWall),
                      model: m4Translation(-1.85, 0.5, -1.5),
                      emissive: [0.50, 0.35, 0.15], mix: 0.06)
            addOpaque(buildBox(w: 0.3, h: 5, d: 3, color: interiorWall),
                      model: m4Translation(1.85, 0.5, -1.5),
                      emissive: [0.50, 0.35, 0.15], mix: 0.06)

            // ── Interior floor ──
            addOpaque(buildBox(w: 4, h: 0.15, d: 3, color: floorCol),
                      model: m4Translation(0, -1.7, -1.5),
                      emissive: [0.50, 0.35, 0.15], mix: 0.04)

            // ── Interior ceiling ──
            addOpaque(buildBox(w: 4, h: 0.1, d: 3, color: ceilingCol),
                      model: m4Translation(0, 2.7, -1.5))

            // ── Table with 4 legs ──
            let tableY: Float = -0.5
            addOpaque(buildBox(w: 1.6, h: 0.08, d: 0.9, color: tableCol),
                      model: m4Translation(0, tableY, -1.8))
            for (lx, lz) in [(-0.65, -2.1), (0.65, -2.1), (-0.65, -1.5), (0.65, -1.5)]
                    as [(Float, Float)] {
                addOpaque(buildBox(w: 0.06, h: 1.1, d: 0.06, color: tableCol),
                          model: m4Translation(lx, tableY - 0.6, lz))
            }

            // ── Two bowls of food on table ──
            let bowlCol: SIMD4<Float> = [0.85, 0.82, 0.78, 1]
            addOpaque(buildCylinder(radius: 0.18, height: 0.08, segments: 10, color: bowlCol),
                      model: m4Translation(-0.35, tableY + 0.08, -1.8))
            addOpaque(buildCylinder(radius: 0.18, height: 0.08, segments: 10, color: bowlCol),
                      model: m4Translation(0.35, tableY + 0.08, -1.8))
            // Food tops
            addOpaque(buildCylinder(radius: 0.14, height: 0.03, segments: 10,
                                    color: [0.70, 0.40, 0.20, 1]),
                      model: m4Translation(-0.35, tableY + 0.12, -1.8))
            addOpaque(buildCylinder(radius: 0.14, height: 0.03, segments: 10,
                                    color: [0.50, 0.30, 0.15, 1]),
                      model: m4Translation(0.35, tableY + 0.12, -1.8))

            // ── Two water glasses ──
            addGlow(buildCylinder(radius: 0.06, height: 0.2, segments: 8,
                                  color: [0.70, 0.80, 0.90, 1]),
                    model: m4Translation(-0.60, tableY + 0.14, -1.8),
                    emissive: [0.40, 0.50, 0.60], mix: 0.3, opacity: 0.35)
            addGlow(buildCylinder(radius: 0.06, height: 0.2, segments: 8,
                                  color: [0.70, 0.80, 0.90, 1]),
                    model: m4Translation(0.60, tableY + 0.14, -1.8),
                    emissive: [0.40, 0.50, 0.60], mix: 0.3, opacity: 0.35)

            // ── Two seated figures (simplified box/sphere people) ──
            for (fx, faceDir) in [(-0.5, Float.pi * 0.1), (0.5, -Float.pi * 0.1)]
                    as [(Float, Float)] {
                let baseY = tableY - 0.4
                // Chair: seat + back + legs
                addOpaque(buildBox(w: 0.45, h: 0.06, d: 0.40, color: chairCol),
                          model: m4Translation(fx, baseY, -1.8))
                addOpaque(buildBox(w: 0.45, h: 0.5, d: 0.06, color: chairCol),
                          model: m4Translation(fx, baseY + 0.28, fx < 0 ? -2.0 : -1.6))
                for (clx, clz) in [(-0.18, -0.15), (0.18, -0.15), (-0.18, 0.15), (0.18, 0.15)]
                        as [(Float, Float)] {
                    addOpaque(buildBox(w: 0.04, h: 0.5, d: 0.04, color: chairCol),
                              model: m4Translation(fx + clx, baseY - 0.3, -1.8 + clz))
                }

                // Body: torso
                addOpaque(buildBox(w: 0.30, h: 0.40, d: 0.22, color: [0.30, 0.25, 0.40, 1]),
                          model: m4Translation(fx, baseY + 0.32, -1.8) * m4RotY(faceDir))
                // Head (sphere)
                addOpaque(buildSphere(radius: 0.12, rings: 5, segments: 6,
                                      color: [0.85, 0.70, 0.58, 1]),
                          model: m4Translation(fx, baseY + 0.62, -1.8))
                // Hair cap
                addOpaque(buildSphere(radius: 0.10, rings: 4, segments: 5,
                                      color: [0.15, 0.10, 0.08, 1]),
                          model: m4Translation(fx, baseY + 0.70, -1.8))
                // Arms
                addOpaque(buildBox(w: 0.08, h: 0.30, d: 0.08, color: [0.30, 0.25, 0.40, 1]),
                          model: m4Translation(fx - 0.22, baseY + 0.18, -1.8) * m4RotY(faceDir))
                addOpaque(buildBox(w: 0.08, h: 0.30, d: 0.08, color: [0.30, 0.25, 0.40, 1]),
                          model: m4Translation(fx + 0.22, baseY + 0.18, -1.8) * m4RotY(faceDir))
            }

            // ── Hanging lamp (shade + cord + bulb) ──
            addOpaque(buildCylinder(radius: 0.20, height: 0.12, segments: 10,
                                    color: [0.25, 0.20, 0.15, 1]),
                      model: m4Translation(0, 2.2, -1.8))
            addOpaque(buildBox(w: 0.02, h: 0.5, d: 0.02, color: darkMetal),
                      model: m4Translation(0, 2.5, -1.8))
            // Bulb — warm emissive
            addGlow(buildSphere(radius: 0.06, rings: 4, segments: 6,
                                color: [1.0, 0.90, 0.60, 1]),
                    model: m4Translation(0, 2.12, -1.8),
                    emissive: [1.0, 0.80, 0.45], mix: 1.0, opacity: 0.8)

            // ── Warm light pool from lamp (floor glow) ──
            addGlow(buildBox(w: 2.0, h: 0.01, d: 1.5, color: [1.0, 0.85, 0.55, 1]),
                    model: m4Translation(0, -1.62, -1.8),
                    emissive: [0.90, 0.65, 0.30], mix: 0.6, opacity: 0.15)

            // ── OPEN neon sign (small red emissive boxes) ──
            let signY: Float = 1.8
            let signZ: Float = -0.05
            let letterSpacing: Float = 0.28
            let letters: [Float] = [-0.6, -0.32, -0.04, 0.24]   // O P E N positions
            for lx in letters {
                addGlow(buildBox(w: 0.18, h: 0.22, d: 0.04, color: [1.0, 0.20, 0.15, 1]),
                        model: m4Translation(lx, signY, signZ),
                        emissive: [1.0, 0.15, 0.10], mix: 1.0, opacity: 0.75)
            }

            // ── Awning above window ──
            addOpaque(buildBox(w: 5.0, h: 0.08, d: 1.2, color: awningCol),
                      model: m4Translation(0, 3.0, 0.6) * m4RotX(-0.15))

            // ── Glass pane (semi-transparent overlay) ──
            addGlow(buildQuad(w: 4.0, h: 4.4, color: [0.60, 0.70, 0.80, 1],
                              normal: [0, 0, 1]),
                    model: m4Translation(0, 0.5, 0.02),
                    emissive: [0.20, 0.25, 0.30], mix: 0.15, opacity: 0.08)

            // ── Pre-compute rain drop positions across glass ──
            for _ in 0..<50 {
                let rx = Float(Double.random(in: -2.0...2.0, using: &rng))
                let rPhase = Float(Double.random(in: 0...6.28, using: &rng))
                rainPos.append([rx, rPhase])
                rainPhase.append(Float(Double.random(in: 0...1.0, using: &rng)))
            }

            // ── Pre-compute steam positions above bowls ──
            for i in 0..<12 {
                let bx: Float = i < 6 ? -0.35 : 0.35
                let sx = bx + Float(Double.random(in: -0.10...0.10, using: &rng))
                let sz = Float(-1.8 + Double.random(in: -0.06...0.06, using: &rng))
                steamPos.append([sx, tableY + 0.16, sz])
                steamPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
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
            let rainBoost = max(0, 1 - (t - rainBoostT) / 3.0)

            // Camera — outside on sidewalk, looking through window, gentle breathing
            let breathX = 0.15 * sin(t * 0.3)
            let breathY = 0.08 * sin(t * 0.22)
            let eye: SIMD3<Float> = [breathX, 0.3 + breathY, 4.5]
            let center: SIMD3<Float> = [0, 0.2, -1.5]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([0.2, -0.6, 0.5])
            let sunCol: SIMD3<Float> = [0.90, 0.70, 0.40]
            let ambCol: SIMD3<Float> = [0.08, 0.08, 0.12]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(4, 10, 0, 0),
                fogColor:       SIMD4<Float>(0.06, 0.07, 0.12, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque geometry
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Glow pass — glass, water glasses, neon sign, lamp, wet sidewalk
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    // Neon sign flickers subtly
                    var em = call.emissiveCol
                    var op = call.opacity
                    if em.x > 0.8 && em.y < 0.3 {
                        let flicker = 0.85 + 0.15 * sin(t * 8.0 + 3.0 * sin(t * 1.3))
                        em = em * flicker
                        op = op * flicker
                    }
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: em, emissiveMix: call.emissiveMix,
                               opacity: min(1, op))
                }
            }

            // Particle pass — rain + steam
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Rain streaks on window glass
                let rainCount = 50 + (rainBoost > 0 ? 40 : 0)
                for i in 0..<rainCount {
                    let idx = i % rainPos.count
                    let base = rainPos[idx]
                    let ph = rainPhase[idx]
                    let extraSpeed: Float = i >= 50 ? 1.5 : 1.0
                    let cycle = fmod(t * (1.8 + ph * 0.6) * extraSpeed, 4.8)
                    let ry = 2.7 - cycle
                    let rx = base.x + 0.05 * sin(t * 0.5 + base.y)
                    let alpha: Float = (i >= 50) ? rainBoost * 0.5 : (0.3 + 0.2 * ph)
                    particles.append(ParticleVertex3D(
                        position: [rx, ry, 0.06],
                        color: [0.65, 0.75, 0.90, alpha], size: 3))
                }

                // Steam wisps above bowls
                for i in steamPos.indices {
                    let ph = steamPhase[i]
                    let base = steamPos[i]
                    let cycle = fmod(t * 0.6 + ph, 3.0)
                    let sy = base.y + cycle * 0.25
                    let sx = base.x + 0.04 * sin(t * 0.8 + ph)
                    let alpha: Float = max(0, 0.25 - cycle * 0.08)
                    particles.append(ParticleVertex3D(
                        position: [sx, sy, base.z],
                        color: [0.95, 0.90, 0.80, alpha], size: 5))
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
        view.clearColor               = MTLClearColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)
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
