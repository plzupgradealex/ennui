// CelestialScrollHall3DScene — Moonlit Chinese study hall in deep twilight.
// Red lacquered columns, hanging scrolls, lattice window, silk lanterns,
// calligraphy desk, incense smoke, plum blossom petals, floating glowing characters.
// Tap to burst glowing glyph particles.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct CelestialScrollHall3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        CelestialScrollHall3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct CelestialScrollHall3DRepresentable: NSViewRepresentable {
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
            var buffer: MTLBuffer; var count: Int
            var model: simd_float4x4
            var emissiveCol: SIMD3<Float>; var emissiveMix: Float; var opacity: Float = 1
        }
        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        // Incense smoke particles
        struct SmokeParticle {
            var phase: Float; var xOff: Float
        }
        var smokeParticles: [SmokeParticle] = []

        // Petal particles
        struct Petal {
            var baseX: Float; var baseY: Float; var baseZ: Float
            var speed: Float; var phase: Float
        }
        var petals: [Petal] = []

        // Glyph motes (20 normal)
        struct GlyphMote {
            var baseX: Float; var baseY: Float; var baseZ: Float
            var phase: Float; var speed: Float
        }
        var glyphMotes: [GlyphMote] = []

        // Glyph burst directions
        var glyphBurstDirs: [SIMD3<Float>] = []
        var glyphBurstT: Float = -999

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
            } catch { print("CelestialScrollHall3D pipeline error: \(error)") }
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
                              emissive: SIMD3<Float>, opacity: Float = 0.9) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                      emissiveCol: emissive, emissiveMix: 1.0, opacity: opacity))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 5500)

            // Floor
            addOpaque(buildPlane(w: 12, d: 18, color: [0.12, 0.07, 0.04, 1]),
                      model: matrix_identity_float4x4)

            // Ceiling beams
            for zi in 0..<5 {
                let bz = Float(zi) * -2.0
                addOpaque(buildBox(w: 8, h: 0.15, d: 0.2, color: [0.10, 0.06, 0.035, 1]),
                          model: m4Translation(0, 3.7, bz))
            }

            // Back wall
            addOpaque(buildBox(w: 12, h: 4, d: 0.1, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(0, 2, -9))

            // 6 paired red lacquered columns at z = -1, -4, -7
            let colZs: [Float] = [-1, -4, -7]
            for cz in colZs {
                for cx: Float in [-3, 3] {
                    // Main column
                    addOpaque(buildCylinder(radius: 0.12, height: 3.8, segments: 10,
                                            color: [0.4, 0.1, 0.06, 1]),
                              model: m4Translation(cx, 1.9, cz))
                    // Gold bottom band
                    addOpaque(buildCylinder(radius: 0.14, height: 0.06, segments: 10,
                                            color: [0.7, 0.55, 0.2, 1]),
                              model: m4Translation(cx, 0.08, cz))
                    // Gold top band
                    addOpaque(buildCylinder(radius: 0.14, height: 0.06, segments: 10,
                                            color: [0.7, 0.55, 0.2, 1]),
                              model: m4Translation(cx, 3.72, cz))
                }
            }

            // Hanging scrolls at x = [-2, 0, 2], z = -8.8, y = 2.2
            for sx: Float in [-2, 0, 2] {
                // Scroll paper
                addOpaque(buildBox(w: 0.6, h: 1.2, d: 0.02, color: [0.88, 0.82, 0.72, 1]),
                          model: m4Translation(sx, 2.2, -8.8))
                // Dark border
                addOpaque(buildBox(w: 0.66, h: 1.26, d: 0.015, color: [0.15, 0.08, 0.04, 1]),
                          model: m4Translation(sx, 2.2, -8.82))
                // Top rod
                addOpaque(buildCylinder(radius: 0.025, height: 0.65, segments: 6,
                                        color: [0.35, 0.20, 0.08, 1]),
                          model: m4Translation(sx, 2.84, -8.8) * m4RotZ(.pi / 2))
                // Bottom rod
                addOpaque(buildCylinder(radius: 0.025, height: 0.65, segments: 6,
                                        color: [0.35, 0.20, 0.08, 1]),
                          model: m4Translation(sx, 1.56, -8.8) * m4RotZ(.pi / 2))
            }

            // Lattice window at (-4, 2, -5) area — 5 horizontal + 5 vertical bars
            let winX: Float = -4, winY: Float = 2, winZ: Float = -5
            for i in 0..<5 {
                let oy = winY - 0.8 + Float(i) * 0.4
                addOpaque(buildBox(w: 1.8, h: 0.03, d: 0.03, color: [0.35, 0.25, 0.15, 1]),
                          model: m4Translation(winX, oy, winZ))
            }
            for i in 0..<5 {
                let ox = winX - 0.8 + Float(i) * 0.4
                addOpaque(buildBox(w: 0.03, h: 1.8, d: 0.03, color: [0.35, 0.25, 0.15, 1]),
                          model: m4Translation(ox, winY, winZ))
            }
            // Window glow behind
            addGlow(buildQuad(w: 1.8, h: 1.8, color: [0.55, 0.6, 0.8, 0.5]),
                    model: m4Translation(winX, winY, winZ - 0.05),
                    emissive: [0.45, 0.55, 0.75], opacity: 0.5)

            // Silk lanterns (glow spheres) — 3 lanterns
            let lanternPos: [(Float, Float, Float)] = [(-1.8, 2.3, -1.5), (1.8, 2.3, -1.5), (0, 2.5, -3)]
            for (lx, ly, lz) in lanternPos {
                addGlow(buildSphere(radius: 0.18, rings: 8, segments: 8,
                                    color: [0.9, 0.3, 0.1, 1]),
                        model: m4Translation(lx, ly, lz),
                        emissive: [1.0, 0.5, 0.1], opacity: 0.9)
                // Hanging string
                addOpaque(buildCylinder(radius: 0.01, height: 0.4, segments: 6,
                                        color: [0.3, 0.2, 0.1, 1]),
                          model: m4Translation(lx, ly + 0.3, lz))
            }

            // Calligraphy desk
            addOpaque(buildBox(w: 1.4, h: 0.08, d: 0.7, color: [0.25, 0.12, 0.06, 1]),
                      model: m4Translation(0, 0.7, -2.5))
            // Desk legs
            for (lx, lz): (Float, Float) in [(-0.65, -2.85), (0.65, -2.85), (-0.65, -2.15), (0.65, -2.15)] {
                addOpaque(buildBox(w: 0.06, h: 0.65, d: 0.06, color: [0.22, 0.10, 0.05, 1]),
                          model: m4Translation(lx, 0.325, lz))
            }

            // Incense stick
            addOpaque(buildCylinder(radius: 0.008, height: 0.35, segments: 6,
                                    color: [0.6, 0.4, 0.2, 1]),
                      model: m4Translation(0.5, 0.9, -2.5))

            // Smoke particles: 30 rising wisps
            var srng = SplitMix64(seed: 5501)
            for _ in 0..<30 {
                let phase = Float(srng.nextDouble()) * Float.pi * 2
                let xOff  = Float(srng.nextDouble()) * 0.06 - 0.03
                smokeParticles.append(SmokeParticle(phase: phase, xOff: xOff))
            }

            // Petal particles: 40 plum blossom petals
            var prng = SplitMix64(seed: 5502)
            for _ in 0..<40 {
                let bx    = Float(prng.nextDouble()) * 8 - 4
                let by    = Float(prng.nextDouble()) * 4
                let bz    = -(Float(prng.nextDouble()) * 7 + 1)
                let speed = Float(prng.nextDouble()) * 0.10 + 0.05
                let phase = Float(prng.nextDouble()) * Float.pi * 2
                petals.append(Petal(baseX: bx, baseY: by, baseZ: bz, speed: speed, phase: phase))
            }

            // Glyph motes: 20 slow-rising gold motes
            var grng = SplitMix64(seed: 5503)
            for _ in 0..<20 {
                let bx    = Float(grng.nextDouble()) * 6 - 3
                let by    = Float(grng.nextDouble()) * 3
                let bz    = -(Float(grng.nextDouble()) * 6 + 1)
                let phase = Float(grng.nextDouble()) * Float.pi * 2
                let speed = Float(grng.nextDouble()) * 0.05 + 0.02
                glyphMotes.append(GlyphMote(baseX: bx, baseY: by, baseZ: bz,
                                             phase: phase, speed: speed))
            }

            // Glyph burst directions: 80
            var bdrng = SplitMix64(seed: 5504)
            for _ in 0..<80 {
                let theta = Float(bdrng.nextDouble()) * Float.pi * 2
                let phi   = Float(bdrng.nextDouble()) * Float.pi
                let d = SIMD3<Float>(sin(phi) * cos(theta), abs(sin(phi) * sin(theta)) + 0.2, cos(phi))
                glyphBurstDirs.append(simd_normalize(d))
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opPipe = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Camera with subtle sway and bob
            let eyeX = 0.5 * sin(t * 0.1)
            let eyeY = 2.0 + 0.1 * sin(t * 0.15)
            let eye  = SIMD3<Float>(eyeX, eyeY, 4)
            let center3 = SIMD3<Float>(eyeX * 0.3, 1.5, -2)
            let view3D = m4LookAt(eye: eye, center: center3, up: [0, 1, 0])
            let proj   = m4Perspective(fovyRad: 1.0, aspect: aspect, near: 0.1, far: 35)

            var su = SceneUniforms3D(
                viewProjection:  proj * view3D,
                sunDirection:    SIMD4<Float>(simd_normalize([0.2, -0.8, 0.3]), 0),
                sunColor:        SIMD4<Float>([0.55, 0.60, 0.75], 0),
                ambientColor:    SIMD4<Float>([0.05, 0.04, 0.07], t),
                fogParams:       SIMD4<Float>(8, 20, 0, 0),
                fogColor:        SIMD4<Float>([0.02, 0.025, 0.04], 0),
                cameraWorldPos:  SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(opPipe)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Glow pass
            if let gp = glowPipeline {
                enc.setRenderPipelineState(gp)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                for call in glowCalls {
                    encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }
            }

            // Particles
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []

                // Incense smoke: rising from (0.5, 1.05, -2.5)
                let smokeBase = SIMD3<Float>(0.5, 1.05, -2.5)
                for (i, sp) in smokeParticles.enumerated() {
                    let rise = (t * 0.25 + sp.phase).truncatingRemainder(dividingBy: 2.0)
                    let px   = smokeBase.x + sp.xOff + 0.03 * sin(t * 0.8 + sp.phase)
                    let py   = smokeBase.y + rise
                    let fade = 1.0 - rise / 2.0
                    let a    = max(0, 0.35 * fade * sin(Float(i) * 0.4 + t * 0.5))
                    pv.append(ParticleVertex3D(position: [px, py, smokeBase.z],
                                               color: [0.8, 0.8, 0.75, a], size: 3))
                }

                // Petal particles: drifting pink, falling
                for p in petals {
                    let fallY = (p.baseY - p.speed * (t + p.phase)).truncatingRemainder(dividingBy: 5.0)
                    let py    = fallY < 0 ? fallY + 5 : fallY
                    let px    = p.baseX + 0.4 * sin(t * 0.5 + p.phase)
                    let a     = 0.65 * abs(sin(t * 0.3 + p.phase))
                    pv.append(ParticleVertex3D(position: [px, py, p.baseZ],
                                               color: [0.98, 0.72, 0.80, a], size: 4))
                }

                // Glyph motes
                let burstAge = t - glyphBurstT
                let isBursting = burstAge >= 0 && burstAge < 0.8

                for m in glyphMotes {
                    let rise  = (m.baseY + m.speed * t + m.phase * 2).truncatingRemainder(dividingBy: 4.0)
                    let py    = rise < 0 ? rise + 4 : rise
                    let alpha = max(0, Float(0.7) * sin(t * 1.0 + m.phase))
                    pv.append(ParticleVertex3D(position: [m.baseX, py, m.baseZ],
                                               color: [1.0, 0.85, 0.25, alpha], size: 6))
                }

                // Burst glyphs
                if isBursting {
                    let fade = max(0, 1 - burstAge / 0.8)
                    let center3: SIMD3<Float> = [0, 0.72, -2.5]
                    for dir in glyphBurstDirs {
                        let pos = center3 + dir * burstAge * 4
                        pv.append(ParticleVertex3D(position: pos,
                                                   color: [1.0, 0.88, 0.3, fade],
                                                   size: 7))
                    }
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
        v.delegate                 = context.coordinator
        v.colorPixelFormat         = .bgra8Unorm
        v.depthStencilPixelFormat  = .depth32Float
        v.clearColor               = MTLClearColor(red: 0.02, green: 0.025, blue: 0.04, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.glyphBurstT = Float(CACurrentMediaTime() - c.startTime)
    }
}
