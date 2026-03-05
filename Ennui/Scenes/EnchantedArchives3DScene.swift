// EnchantedArchives3DScene — Magical flying library.
// Bookshelf walls, 8 orbiting books, 6 paper birds, golden sparkles.
// Tap to scatter sparkle burst.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct EnchantedArchives3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        EnchantedArchives3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct EnchantedArchives3DRepresentable: NSViewRepresentable {
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

        // Books
        struct OrbitBook {
            var radius: Float; var y: Float; var period: Float; var startAngle: Float
            var buffer: MTLBuffer; var count: Int; var color: SIMD3<Float>
        }
        var orbitBooks: [OrbitBook] = []

        // Paper birds
        struct PaperBird {
            var radius: Float; var y: Float; var period: Float; var startAngle: Float
            var buffer: MTLBuffer; var count: Int
        }
        var paperBirds: [PaperBird] = []

        // Sparkles
        struct Sparkle {
            var basePos: SIMD3<Float>; var phase: Float; var dir: SIMD3<Float>
        }
        var sparkles: [Sparkle] = []

        var burstT: Float = -999
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
            } catch { print("EnchantedArchives3D pipeline error: \(error)") }
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
            var rng = SplitMix64(seed: 1337)

            // Floor
            addOpaque(buildPlane(w: 12, d: 14, color: [0.14, 0.12, 0.10, 1]),
                      model: matrix_identity_float4x4)

            // Bookshelf walls
            addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: [0.20, 0.13, 0.07, 1]),
                      model: m4Translation(-5.5, 1.5, 0))
            addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: [0.20, 0.13, 0.07, 1]),
                      model: m4Translation(5.5, 1.5, 0))
            addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: [0.20, 0.13, 0.07, 1]),
                      model: m4Translation(0, 1.5, -6.5) * m4RotY(.pi / 2))
            addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: [0.20, 0.13, 0.07, 1]),
                      model: m4Translation(0, 1.5, 6.5) * m4RotY(.pi / 2))
            addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: [0.18, 0.11, 0.06, 1]),
                      model: m4Translation(0, 4.5, -6.5))

            // Colorful book spines on walls
            let bookColors: [SIMD4<Float>] = [
                [0.6, 0.15, 0.10, 1], [0.15, 0.35, 0.60, 1], [0.20, 0.50, 0.20, 1],
                [0.60, 0.50, 0.10, 1], [0.45, 0.15, 0.50, 1], [0.60, 0.35, 0.10, 1],
                [0.25, 0.40, 0.55, 1], [0.60, 0.22, 0.22, 1]
            ]
            // Left wall books
            for i in 0..<8 {
                let bw: Float = 0.07 + Float(rng.nextDouble()) * 0.05
                let bh: Float = 0.25 + Float(rng.nextDouble()) * 0.10
                let ci = i % bookColors.count
                let bx: Float = -5.35
                let by = 0.8 + Float(i) * 0.32
                addOpaque(buildBox(w: 0.25, h: bh, d: bw, color: bookColors[ci]),
                          model: m4Translation(bx, by, Float(rng.nextDouble()) * 0.8 - 0.4))
            }
            // Right wall books
            for i in 0..<8 {
                let bh: Float = 0.25 + Float(rng.nextDouble()) * 0.10
                let ci = (i + 3) % bookColors.count
                let bx: Float = 5.35
                let by = 0.8 + Float(i) * 0.32
                addOpaque(buildBox(w: 0.25, h: bh, d: Float(rng.nextDouble()) * 0.05 + 0.07, color: bookColors[ci]),
                          model: m4Translation(bx, by, Float(rng.nextDouble()) * 0.8 - 0.4))
            }

            // Ambient glow spheres
            addGlow(buildSphere(radius: 0.08, rings: 8, segments: 8, color: [1.0, 0.8, 0.5, 1]),
                    model: m4Translation(-3, 3, 0), emissive: [1.0, 0.8, 0.5], opacity: 1.0)
            addGlow(buildSphere(radius: 0.08, rings: 8, segments: 8, color: [1.0, 0.8, 0.5, 1]),
                    model: m4Translation(3, 3, 0), emissive: [1.0, 0.8, 0.5], opacity: 1.0)

            // 8 Orbiting books
            let bookDefs: [(Float, Float, Float, Float, SIMD3<Float>)] = [
                (1.5, 1.5, 6, 0,        [0.7, 0.15, 0.10]),
                (2.0, 2.0, 8, 0.8,      [0.15, 0.35, 0.70]),
                (2.5, 2.5, 10, 1.6,     [0.20, 0.55, 0.20]),
                (3.0, 3.0, 12, 2.4,     [0.70, 0.55, 0.10]),
                (3.5, 1.8, 14, 3.2,     [0.50, 0.15, 0.55]),
                (2.2, 3.5, 7,  4.0,     [0.65, 0.40, 0.10]),
                (1.8, 2.8, 9,  4.8,     [0.25, 0.45, 0.55]),
                (2.8, 1.5, 11, 5.5,     [0.50, 0.50, 0.50]),
            ]
            for (rad, y, period, startA, col) in bookDefs {
                let verts = buildBox(w: 0.3, h: 0.4, d: 0.05, color: SIMD4<Float>(col, 1))
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                orbitBooks.append(OrbitBook(radius: rad, y: y, period: period,
                                             startAngle: startA, buffer: buf,
                                             count: verts.count, color: col))
            }

            // 6 Paper birds
            let birdDefs: [(Float, Float, Float, Float)] = [
                (2.0, 2.0, 14, 0.3),
                (3.0, 3.0, 18, 1.5),
                (4.0, 2.5, 20, 2.7),
                (2.5, 4.0, 16, 3.9),
                (3.5, 3.5, 22, 5.1),
                (4.0, 2.0, 24, 6.3),
            ]
            for (rad, y, period, startA) in birdDefs {
                let br = Float(rng.nextDouble()) * 0.10 + 0.88
                let verts = buildBox(w: 0.2, h: 0.12, d: 0.02,
                                     color: SIMD4<Float>(br, br, br - 0.03, 1))
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                paperBirds.append(PaperBird(radius: rad, y: y, period: period,
                                             startAngle: startA, buffer: buf, count: verts.count))
            }

            // Sparkles: 80 positions in a radius-3 sphere
            var srng = SplitMix64(seed: 9988)
            for _ in 0..<80 {
                let theta = Float(srng.nextDouble()) * Float.pi * 2
                let phi   = Float(srng.nextDouble()) * Float.pi
                let r     = Float(srng.nextDouble()) * 3
                let pos   = SIMD3<Float>(r * sin(phi) * cos(theta),
                                        r * sin(phi) * sin(theta) + 2,
                                        r * cos(phi))
                let phase = Float(srng.nextDouble()) * Float.pi * 2
                let dir   = simd_normalize(pos - SIMD3<Float>(0, 2, 0))
                sparkles.append(Sparkle(basePos: pos, phase: phase, dir: dir))
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
            let twoPi = Float.pi * 2

            // Camera orbits around (0,2,0)
            let camAngle = t * twoPi / 60.0
            let eye = SIMD3<Float>(9 * sin(camAngle), 3, 9 * cos(camAngle))
            let center3 = SIMD3<Float>(0, 2, 0)
            let view3D = m4LookAt(eye: eye, center: center3, up: [0, 1, 0])
            let proj   = m4Perspective(fovyRad: 1.0, aspect: aspect, near: 0.1, far: 40)

            var su = SceneUniforms3D(
                viewProjection:  proj * view3D,
                sunDirection:    SIMD4<Float>(simd_normalize([0.3, -0.8, 0.5]), 0),
                sunColor:        SIMD4<Float>([0.85, 0.75, 1.0], 0),
                ambientColor:    SIMD4<Float>([0.06, 0.04, 0.10], t),
                fogParams:       SIMD4<Float>(12, 25, 0, 0),
                fogColor:        SIMD4<Float>([0.04, 0.02, 0.07], 0),
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

            // Orbiting books
            for book in orbitBooks {
                let angle = book.startAngle + t * twoPi / book.period
                let bx = book.radius * cos(angle)
                let bz = book.radius * sin(angle)
                let model = m4Translation(bx, book.y, bz) * m4RotY(-angle) * m4RotZ(t * 0.5)
                encodeDraw(encoder: enc, vertexBuffer: book.buffer, vertexCount: book.count,
                           model: model, emissiveColor: book.color, emissiveMix: 0.25)
            }

            // Paper birds
            for bird in paperBirds {
                let angle = bird.startAngle + t * twoPi / bird.period
                let bx = bird.radius * cos(angle)
                let bz = bird.radius * sin(angle)
                let model = m4Translation(bx, bird.y, bz) * m4RotY(-angle) * m4RotZ(sin(t * 2 + bird.startAngle) * 0.3)
                encodeDraw(encoder: enc, vertexBuffer: bird.buffer, vertexCount: bird.count,
                           model: model)
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
                let burstAge = t - burstT
                let isBursting = burstAge >= 0 && burstAge < 1.2
                let sparkleCount = isBursting ? 80 : 8
                var pv: [ParticleVertex3D] = []

                for i in 0..<sparkleCount {
                    let sp = sparkles[i]
                    if isBursting {
                        let fade = max(0, 1 - burstAge / 1.2)
                        let pos = sp.basePos + sp.dir * burstAge * 3
                        let a = fade * max(0, sin(t * 3 + sp.phase))
                        pv.append(ParticleVertex3D(position: pos, color: [1.0, 0.9, 0.4, a], size: 5))
                    } else {
                        let a = max(0, Float(0.8) * sin(t * 2 + sp.phase))
                        pv.append(ParticleVertex3D(position: sp.basePos,
                                                   color: [1.0, 0.9, 0.4, a], size: 5))
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
        v.clearColor               = MTLClearColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.burstT = Float(CACurrentMediaTime() - c.startTime)
    }
}
