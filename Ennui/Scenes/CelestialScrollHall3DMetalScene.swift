// CelestialScrollHall3DMetalScene — Moonlit Chinese study hall with scrolls and calligraphy.
// Lacquered columns, hanging scrolls, lattice window, silk lanterns, calligraphy desk,
// floating golden glyph particles. Tap to pulse lantern warmth.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct CelestialScrollHall3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        CelestialScrollHall3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct CelestialScrollHall3DMetalRepresentable: NSViewRepresentable {
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

        // Lantern glow indices in glowCalls for pulse on tap
        var lanternIndices: [Int] = []

        // Glyph particles — pre-computed positions and phases
        var glyphPos:   [SIMD3<Float>] = []
        var glyphPhase: [Float]        = []

        // Dust motes near the window
        var dustPos:   [SIMD3<Float>] = []
        var dustPhase: [Float]        = []

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
            } catch { print("CelestialScrollHall3DMetal pipeline error: \(error)") }
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
            let darkWood: SIMD4<Float>  = [0.12, 0.07, 0.04, 1]
            let lacquer: SIMD4<Float>   = [0.40, 0.10, 0.06, 1]
            let wallCol: SIMD4<Float>   = [0.06, 0.04, 0.03, 1]

            // ── Floor — dark polished wood ──
            addOpaque(buildPlane(w: 12, d: 16, color: darkWood),
                      model: matrix_identity_float4x4)

            // ── Ceiling ──
            addOpaque(buildBox(w: 12, h: 0.08, d: 16, color: [0.08, 0.05, 0.03, 1]),
                      model: m4Translation(0, 3.8, -4))

            // Ceiling beams
            for z in stride(from: Float(0), through: -8, by: -2) {
                addOpaque(buildBox(w: 8, h: 0.15, d: 0.2, color: [0.10, 0.06, 0.035, 1]),
                          model: m4Translation(0, 3.7, z))
            }

            // ── Back wall ──
            addOpaque(buildBox(w: 12, h: 4, d: 0.1, color: wallCol),
                      model: m4Translation(0, 2, -9))

            // ── Side walls ──
            addOpaque(buildBox(w: 0.1, h: 4, d: 16, color: wallCol),
                      model: m4Translation(-4.5, 2, -4))
            addOpaque(buildBox(w: 0.1, h: 4, d: 16, color: wallCol),
                      model: m4Translation(4.5, 2, -4))

            // ── Lacquered columns ──
            let colPositions: [(Float, Float)] = [
                (-3.0, -1.0), (3.0, -1.0),
                (-3.0, -4.0), (3.0, -4.0),
                (-3.0, -7.0), (3.0, -7.0)
            ]
            let goldBand: SIMD4<Float> = [0.70, 0.55, 0.20, 1]
            for (x, z) in colPositions {
                addOpaque(buildCylinder(radius: 0.12, height: 3.8, segments: 10, color: lacquer),
                          model: m4Translation(x, 1.9, z))
                // Gold bands
                for bandY: Float in [0.08, 3.72] {
                    addOpaque(buildCylinder(radius: 0.14, height: 0.06, segments: 10, color: goldBand),
                              model: m4Translation(x, bandY, z))
                }
                // Column capital
                addOpaque(buildBox(w: 0.35, h: 0.08, d: 0.35, color: lacquer),
                          model: m4Translation(x, 3.78, z))
            }

            // ── Scroll shelves on back wall ──
            let shelfWood: SIMD4<Float> = [0.10, 0.065, 0.04, 1]
            var rng = SplitMix64(seed: 8888)
            for sideX: Float in [-2.0, 2.0] {
                // Shelf back panel
                addOpaque(buildBox(w: 2.2, h: 3.0, d: 0.06, color: [0.07, 0.045, 0.025, 1]),
                          model: m4Translation(sideX, 1.6, -8.5))
                // Shelf planks
                for row in 0..<5 {
                    let plankY = Float(row) * 0.6 + 0.3
                    addOpaque(buildBox(w: 2.2, h: 0.04, d: 0.25, color: shelfWood),
                              model: m4Translation(sideX, plankY, -8.38))
                    // Scroll tubes on each shelf
                    var scrollX = sideX - 0.95
                    for _ in 0..<6 {
                        let sw: Float = 0.06 + Float(rng.nextDouble()) * 0.05
                        let sh: Float = 0.35 + Float(rng.nextDouble()) * 0.2
                        let tone = rng.nextDouble()
                        let scrollCol: SIMD4<Float>
                        if tone < 0.3 { scrollCol = [0.15, 0.18, 0.10, 1] }
                        else if tone < 0.55 { scrollCol = [0.25, 0.20, 0.12, 1] }
                        else if tone < 0.75 { scrollCol = [0.30, 0.08, 0.06, 1] }
                        else { scrollCol = [0.10, 0.18, 0.15, 1] }
                        addOpaque(buildCylinder(radius: sw / 2, height: sh, segments: 6, color: scrollCol),
                                  model: m4Translation(scrollX, plankY + 0.04 + sh / 2, -8.38))
                        scrollX += sw + 0.06
                        if scrollX > sideX + 0.95 { break }
                    }
                }
            }

            // ── Hanging scrolls on back wall ──
            let ivory: SIMD4<Float> = [0.88, 0.82, 0.72, 1]
            for x: Float in [-1.0, 0.0, 1.0] {
                addGlow(buildQuad(w: 0.5, h: 1.6, color: ivory, normal: [0, 0, 1]),
                        model: m4Translation(x, 2.4, -8.78),
                        emissive: [0.60, 0.50, 0.25], mix: 0.15, opacity: 0.9)
                // Scroll rod at top
                addOpaque(buildCylinder(radius: 0.02, height: 0.6, segments: 6,
                                        color: darkWood),
                          model: m4Translation(x, 3.22, -8.78) * m4RotZ(Float.pi / 2))
            }

            // ── Lattice window (left wall) with moonlight ──
            let latticeMat: SIMD4<Float> = [0.15, 0.09, 0.05, 1]
            let winX: Float = -4.35, winY: Float = 2.2, winZ: Float = -4.0
            // Window frame
            addOpaque(buildBox(w: 0.06, h: 2.0, d: 0.08, color: latticeMat),
                      model: m4Translation(winX, winY, winZ - 0.75))
            addOpaque(buildBox(w: 0.06, h: 2.0, d: 0.08, color: latticeMat),
                      model: m4Translation(winX, winY, winZ + 0.75))
            addOpaque(buildBox(w: 0.06, h: 0.06, d: 1.5, color: latticeMat),
                      model: m4Translation(winX, winY - 1.0, winZ))
            addOpaque(buildBox(w: 0.06, h: 0.06, d: 1.5, color: latticeMat),
                      model: m4Translation(winX, winY + 1.0, winZ))
            // Lattice bars
            for col in 1..<4 {
                let dz = -0.75 + Float(col) * 0.375
                addOpaque(buildBox(w: 0.02, h: 1.9, d: 0.02, color: [0.12, 0.07, 0.04, 1]),
                          model: m4Translation(winX, winY, winZ + dz))
            }
            for row in 1..<5 {
                let dy = -1.0 + Float(row) * 0.4
                addOpaque(buildBox(w: 0.02, h: 0.02, d: 1.4, color: [0.12, 0.07, 0.04, 1]),
                          model: m4Translation(winX, winY + dy, winZ))
            }
            // Moonlit glow behind window
            addGlow(buildQuad(w: 1.7, h: 2.2, color: [0.35, 0.40, 0.60, 1], normal: [1, 0, 0]),
                    model: m4Translation(winX - 0.15, winY, winZ),
                    emissive: [0.20, 0.25, 0.45], mix: 0.8, opacity: 0.35)

            // ── Silk lanterns (warm glow spheres) ──
            let lanternPositions: [(Float, Float, Float)] = [
                (-1.8, 3.0, -1.5), (1.8, 3.0, -1.5),
                (0, 3.2, -3.0), (-1.5, 2.9, -5.0), (1.5, 2.9, -5.0)
            ]
            for (x, y, z) in lanternPositions {
                // Hanging cord
                addOpaque(buildCylinder(radius: 0.005, height: 3.8 - y + 0.2, segments: 4,
                                        color: [0.30, 0.15, 0.05, 1]),
                          model: m4Translation(x, y + (3.8 - y + 0.2) / 2, z))
                // Lantern body (emissive sphere)
                lanternIndices.append(glowCalls.count)
                addGlow(buildSphere(radius: 0.18, rings: 5, segments: 8,
                                    color: [0.85, 0.45, 0.12, 1]),
                        model: m4Translation(x, y, z) * m4Scale(1, 1.4, 1),
                        emissive: [0.90, 0.55, 0.15], mix: 0.7, opacity: 0.65)
                // Tassel below
                addOpaque(buildCone(radius: 0.04, height: 0.10, segments: 6,
                                    color: [0.70, 0.35, 0.10, 1]),
                          model: m4Translation(x, y - 0.27, z))
            }

            // ── Calligraphy desk ──
            let deskY: Float = 0.7, deskZ: Float = -1.5
            addOpaque(buildBox(w: 1.6, h: 0.04, d: 0.7, color: darkWood),
                      model: m4Translation(0, deskY, deskZ))
            // Desk legs
            for (lx, lz) in [(-0.65, deskZ - 0.25), (0.65, deskZ - 0.25),
                              (-0.65, deskZ + 0.25), (0.65, deskZ + 0.25)] as [(Float, Float)] {
                addOpaque(buildBox(w: 0.05, h: deskY, d: 0.05, color: [0.10, 0.06, 0.035, 1]),
                          model: m4Translation(lx, deskY / 2, lz))
            }
            // Open scroll on desk
            addGlow(buildQuad(w: 0.6, h: 0.35, color: [0.75, 0.68, 0.52, 1], normal: [0, 1, 0]),
                    model: m4Translation(-0.1, deskY + 0.025, deskZ) * m4RotX(-Float.pi / 2),
                    emissive: [0.15, 0.12, 0.06], mix: 0.2, opacity: 0.9)
            // Ink stone
            addOpaque(buildBox(w: 0.10, h: 0.03, d: 0.08, color: [0.04, 0.035, 0.03, 1]),
                      model: m4Translation(0.45, deskY + 0.04, deskZ - 0.1))
            // Brush
            addOpaque(buildCylinder(radius: 0.008, height: 0.2, segments: 4,
                                    color: [0.25, 0.15, 0.08, 1]),
                      model: m4Translation(0.5, deskY + 0.06, deskZ + 0.1) * m4RotZ(Float.pi / 6))
            // Incense stick + glowing tip
            addOpaque(buildCylinder(radius: 0.003, height: 0.2, segments: 4,
                                    color: [0.35, 0.20, 0.10, 1]),
                      model: m4Translation(-0.55, deskY + 0.14, deskZ))
            addGlow(buildSphere(radius: 0.012, rings: 3, segments: 4,
                                color: [1.0, 0.4, 0.1, 1]),
                    model: m4Translation(-0.55, deskY + 0.24, deskZ),
                    emissive: [1.0, 0.5, 0.1], mix: 1.0, opacity: 0.85)

            // ── Pre-compute glyph particles ──
            var glyphRng = SplitMix64(seed: 9999)
            for _ in 0..<24 {
                let x = Float(Double.random(in: -3.0...3.0, using: &glyphRng))
                let y = Float(Double.random(in: 0.5...3.0, using: &glyphRng))
                let z = Float(Double.random(in: -8.0...(-1.0), using: &glyphRng))
                glyphPos.append([x, y, z])
                glyphPhase.append(Float(Double.random(in: 0...6.28, using: &glyphRng)))
            }

            // ── Pre-compute dust motes near window ──
            var dustRng = SplitMix64(seed: 7070)
            for _ in 0..<20 {
                let x = Float(Double.random(in: -4.5...(-2.0), using: &dustRng))
                let y = Float(Double.random(in: 1.0...3.5, using: &dustRng))
                let z = Float(Double.random(in: -6.0...(-2.0), using: &dustRng))
                dustPos.append([x, y, z])
                dustPhase.append(Float(Double.random(in: 0...6.28, using: &dustRng)))
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

            let glowBoost = max(0, 1 - (t - glowBoostT) / 3.0) * 1.2

            // Camera — very slow orbit around the hall centre
            let orbitAngle = t * (2 * Float.pi / 120.0)
            let camR: Float = 6.5
            let eye: SIMD3<Float> = [camR * sin(orbitAngle),
                                      2.0 + 0.15 * sin(t * 0.25),
                                      camR * cos(orbitAngle) - 3.5]
            let center: SIMD3<Float> = [0, 1.4, -3.5]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 58 * .pi / 180, aspect: aspect, near: 0.1, far: 40)
            let vp    = proj4 * view4

            // Moonlight — cool blue from upper-left
            let sunDir: SIMD3<Float> = simd_normalize([0.4, -0.8, -0.3])
            let sunCol: SIMD3<Float> = [0.35, 0.40, 0.55]
            let ambCol: SIMD3<Float> = SIMD3<Float>(0.08, 0.06, 0.05) * (1 + glowBoost * 0.3)

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(8, 20, 0, 0),
                fogColor:       SIMD4<Float>(0.03, 0.03, 0.05, 0),
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

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                let flickerBase = 1.0 + 0.08 * sin(t * 1.4)
                for (i, call) in glowCalls.enumerated() {
                    var em = call.emissiveCol
                    var op = call.opacity
                    if lanternIndices.contains(i) {
                        let lanternFlicker = flickerBase + 0.05 * sin(t * 2.3 + Float(i))
                        em = em * lanternFlicker * (1 + glowBoost * 0.4)
                        op = op * (1 + glowBoost * 0.2)
                    }
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: em, emissiveMix: call.emissiveMix,
                               opacity: op)
                }
            }

            // Particle pass — golden glyphs + dust motes
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Floating golden glyphs
                for i in glyphPos.indices {
                    let ph   = glyphPhase[i]
                    let base = glyphPos[i]
                    let riseCycle = fmod(t * 0.12 + ph, 6.28)
                    let wx = base.x + 0.3 * sin(t * 0.15 + ph)
                    let wy = base.y + 0.8 * sin(riseCycle)
                    let wz = base.z + 0.2 * cos(t * 0.1 + ph)
                    let alpha = (0.5 + 0.3 * sin(riseCycle)) * (1 + glowBoost * 0.5)
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [1.0, 0.85, 0.30, min(1, alpha)], size: 6))
                }

                // Dust motes in moonlight near the window
                for i in dustPos.indices {
                    let ph   = dustPhase[i]
                    let base = dustPos[i]
                    let wx = base.x + 0.4 * sin(t * 0.08 + ph)
                    let wy = base.y + 0.15 * sin(t * 0.12 + ph * 1.3)
                    let wz = base.z + 0.3 * cos(t * 0.1 + ph)
                    let alpha = 0.2 + 0.15 * abs(sin(t * 0.3 + ph))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [0.85, 0.80, 0.65, alpha], size: 3))
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
        view.clearColor               = MTLClearColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 1)
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
