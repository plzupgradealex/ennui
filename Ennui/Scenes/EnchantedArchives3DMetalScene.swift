// EnchantedArchives3DMetalScene — Magical library with orbiting books and paper birds.
// Bookshelf walls, orbiting book geometry, paper bird silhouettes, warm sparkle particles.
// Tap to scatter a burst of golden sparkle particles.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct EnchantedArchives3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        EnchantedArchives3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct EnchantedArchives3DMetalRepresentable: NSViewRepresentable {
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

        // Orbiting books: orbital params
        struct OrbitBook {
            var buffer: MTLBuffer; var count: Int
            var radius: Float; var y: Float; var speed: Float; var startAngle: Float
            var tiltSpeed: Float
            var emissiveCol: SIMD3<Float>
        }
        var orbitBooks: [OrbitBook] = []

        // Paper bird orbital params
        struct BirdOrbit {
            var buffer: MTLBuffer; var count: Int
            var radius: Float; var y: Float; var speed: Float; var startAngle: Float
        }
        var birds: [BirdOrbit] = []

        // Ambient sparkle positions
        var sparklePos:   [SIMD3<Float>] = []
        var sparklePhase: [Float]        = []

        // Tap burst state
        var burstT: Float = -100

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
            } catch { print("EnchantedArchives3DMetal pipeline error: \(error)") }
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
            let floorCol: SIMD4<Float> = [0.14, 0.12, 0.10, 1]
            let shelfCol: SIMD4<Float> = [0.20, 0.13, 0.07, 1]

            // ── Floor ──
            addOpaque(buildPlane(w: 14, d: 14, color: floorCol),
                      model: matrix_identity_float4x4)

            // ── Bookshelf walls ──
            // Left and right shelves
            for sx: Float in [-5.5, 5.5] {
                addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: shelfCol),
                          model: m4Translation(sx, 1.5, 0))
                // Book spines
                var rng = SplitMix64(seed: UInt64(abs(sx * 100) + 1234))
                let spineColors: [SIMD4<Float>] = [
                    [0.60, 0.20, 0.10, 1], [0.10, 0.30, 0.50, 1],
                    [0.20, 0.45, 0.20, 1], [0.50, 0.40, 0.10, 1],
                    [0.40, 0.10, 0.40, 1]
                ]
                for j in 0..<8 {
                    let bx = Float(Double.random(in: -1.0...1.0, using: &rng))
                    let by = Float(Double.random(in: -0.8...0.8, using: &rng))
                    addOpaque(buildQuad(w: 0.25, h: 0.8, color: spineColors[j % spineColors.count]),
                              model: m4Translation(sx, 1.5 + by, 0.16) *
                                     m4Translation(bx, 0, 0))
                }
            }
            // Back and far shelves
            for sz: Float in [-6.5, 6.5] {
                addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: shelfCol),
                          model: m4Translation(0, 1.5, sz) * m4RotY(Float.pi / 2))
            }
            // Upper shelf
            addOpaque(buildBox(w: 3, h: 3, d: 0.3, color: shelfCol),
                      model: m4Translation(0, 4.5, -6.5) * m4RotY(Float.pi / 2))

            // ── Warm light spheres (subtle ambient lamps) ──
            for (lx, ly, lz) in [(-3.0, 3.0, 0.0), (3.0, 3.0, 0.0)] as [(Float, Float, Float)] {
                addGlow(buildSphere(radius: 0.15, rings: 4, segments: 6,
                                    color: [1.0, 0.8, 0.5, 1]),
                        model: m4Translation(lx, ly, lz),
                        emissive: [1.0, 0.80, 0.50], mix: 1.0, opacity: 0.4)
            }

            // ── Orbiting books ──
            var bookRng = SplitMix64(seed: 5555)
            let bookColors: [SIMD4<Float>] = [
                [0.70, 0.20, 0.10, 1], [0.10, 0.30, 0.65, 1],
                [0.15, 0.50, 0.20, 1], [0.60, 0.50, 0.10, 1],
                [0.45, 0.10, 0.50, 1], [0.80, 0.40, 0.10, 1],
                [0.20, 0.60, 0.60, 1], [0.50, 0.50, 0.50, 1]
            ]
            for i in 0..<8 {
                let bookVerts = buildBox(w: 0.3, h: 0.4, d: 0.05, color: bookColors[i])
                guard let buf = makeVertexBuffer(bookVerts, device: device) else { continue }
                let orbitR = Float(1.5 + Double.random(in: 0...2.0, using: &bookRng))
                let orbitY = Float(1.5 + Double.random(in: 0...2.0, using: &bookRng))
                let dur    = Float(6.0 + Double.random(in: 0...8.0, using: &bookRng))
                let start  = Float(Double.random(in: 0...6.28, using: &bookRng))
                let tilt   = Float(2 * Float.pi) / (dur * 0.7)
                let em     = SIMD3<Float>(bookColors[i].x, bookColors[i].y, bookColors[i].z) * 0.2
                orbitBooks.append(OrbitBook(buffer: buf, count: bookVerts.count,
                                            radius: orbitR, y: orbitY, speed: (2 * Float.pi) / dur,
                                            startAngle: start, tiltSpeed: tilt, emissiveCol: em))
            }

            // ── Paper birds ──
            var birdRng = SplitMix64(seed: 6666)
            for _ in 0..<6 {
                let shade = Float(0.88 + Double.random(in: 0...0.10, using: &birdRng))
                let birdVerts = buildBox(w: 0.22, h: 0.12, d: 0.02,
                                         color: [shade, shade, shade * 0.95, 1])
                guard let buf = makeVertexBuffer(birdVerts, device: device) else { continue }
                let orbitR = Float(2.0 + Double.random(in: 0...2.0, using: &birdRng))
                let orbitY = Float(2.0 + Double.random(in: 0...2.0, using: &birdRng))
                let dur    = Float(14.0 + Double.random(in: 0...10.0, using: &birdRng))
                let start  = Float(Double.random(in: 0...6.28, using: &birdRng))
                birds.append(BirdOrbit(buffer: buf, count: birdVerts.count,
                                       radius: orbitR, y: orbitY,
                                       speed: (2 * Float.pi) / dur, startAngle: start))
            }

            // ── Pre-compute sparkle positions ──
            var sparkRng = SplitMix64(seed: 7777)
            for _ in 0..<30 {
                let x = Float(Double.random(in: -3.0...3.0, using: &sparkRng))
                let y = Float(Double.random(in: 0.5...4.0, using: &sparkRng))
                let z = Float(Double.random(in: -3.0...3.0, using: &sparkRng))
                sparklePos.append([x, y, z])
                sparklePhase.append(Float(Double.random(in: 0...6.28, using: &sparkRng)))
            }
        }

        func handleTap() {
            burstT = Float(CACurrentMediaTime() - startTime)
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
            let burstFade = max(0, 1 - (t - burstT) / 2.5)

            // Camera — gentle orbit
            let orbitAngle = t * (2 * Float.pi / 60.0)
            let camR: Float = 9.0
            let eye: SIMD3<Float> = [camR * sin(orbitAngle),
                                      2.5 + 0.3 * sin(t * 0.2),
                                      camR * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 2.0, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 70 * .pi / 180, aspect: aspect, near: 0.1, far: 40)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([0.3, -0.7, -0.4])
            let sunCol: SIMD3<Float> = [0.60, 0.45, 0.30]
            let ambCol: SIMD3<Float> = [0.10, 0.06, 0.12]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(10, 25, 0, 0),
                fogColor:       SIMD4<Float>(0.04, 0.02, 0.07, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Static opaque geometry
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Orbiting books (opaque, animated model matrices)
            for book in orbitBooks {
                let angle = t * book.speed + book.startAngle
                let bx = book.radius * cos(angle)
                let bz = book.radius * sin(angle)
                let tiltAngle = t * book.tiltSpeed
                let model = m4Translation(bx, book.y, bz) * m4RotY(-angle) * m4RotZ(tiltAngle)
                encodeDraw(encoder: encoder,
                           vertexBuffer: book.buffer, vertexCount: book.count,
                           model: model,
                           emissiveColor: book.emissiveCol, emissiveMix: 0.2)
            }

            // Paper birds (opaque, animated)
            for bird in birds {
                let angle = t * bird.speed + bird.startAngle
                let bx = bird.radius * cos(angle)
                let bz = bird.radius * sin(angle)
                let wingFlap = 0.12 * sin(t * 4.0 + bird.startAngle)
                let model = m4Translation(bx, bird.y, bz) * m4RotY(-angle) * m4RotX(wingFlap)
                encodeDraw(encoder: encoder,
                           vertexBuffer: bird.buffer, vertexCount: bird.count,
                           model: model)
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            // Particle pass — sparkles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Ambient sparkles
                for i in sparklePos.indices {
                    let ph   = sparklePhase[i]
                    let base = sparklePos[i]
                    let wx = base.x + 0.5 * sin(t * 0.15 + ph)
                    let wy = base.y + 0.3 * sin(t * 0.25 + ph * 1.2)
                    let wz = base.z + 0.4 * cos(t * 0.18 + ph)
                    let twinkle = 0.3 + 0.25 * abs(sin(t * 0.8 + ph))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [1.0, 0.90, 0.40, twinkle], size: 4))
                }

                // Tap burst — extra sparkles near centre
                if burstFade > 0 {
                    var burstRng = SplitMix64(seed: UInt64(burstT * 1000))
                    let burstAge = t - burstT
                    for _ in 0..<40 {
                        let dx = Float(Double.random(in: -2.5...2.5, using: &burstRng))
                        let dy = Float(Double.random(in: 0.5...3.5, using: &burstRng))
                        let dz = Float(Double.random(in: -2.5...2.5, using: &burstRng))
                        let spread = 1.0 + burstAge * 0.8
                        particles.append(ParticleVertex3D(
                            position: [dx * spread, dy + burstAge * 1.2, dz * spread],
                            color: [1.0, 0.85, 0.25, burstFade * 0.8], size: 5))
                    }
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
        view.clearColor               = MTLClearColor(red: 0.04, green: 0.02, blue: 0.07, alpha: 1)
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
