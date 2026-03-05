// ForgottenLibrary3DMetalScene — Infinite twilight library with floating golden letters.
// Bookshelves, stone columns, amber lamp pools, arched window, drifting golden motes.
// Tap to burst golden letter fragments.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct ForgottenLibrary3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        ForgottenLibrary3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct ForgottenLibrary3DMetalRepresentable: NSViewRepresentable {
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

        // Floating letter positions and phases
        var letterPos:   [SIMD3<Float>] = []
        var letterPhase: [Float]        = []

        // Lamp glow indices in glowCalls
        var lampIndices: [Int] = []

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
            } catch { print("ForgottenLibrary3DMetal pipeline error: \(error)") }
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
            let floorCol: SIMD4<Float> = [0.15, 0.14, 0.13, 1]
            let shelfCol: SIMD4<Float> = [0.22, 0.14, 0.08, 1]
            let stoneCol: SIMD4<Float> = [0.35, 0.33, 0.30, 1]

            // ── Floor — worn stone ──
            addOpaque(buildPlane(w: 12, d: 20, color: floorCol),
                      model: matrix_identity_float4x4)

            // ── Ceiling ──
            addOpaque(buildBox(w: 12, h: 0.06, d: 20, color: [0.10, 0.08, 0.07, 1]),
                      model: m4Translation(0, 5.0, -6))

            // ── Back wall ──
            addOpaque(buildBox(w: 12, h: 5, d: 0.1, color: [0.08, 0.06, 0.05, 1]),
                      model: m4Translation(0, 2.5, -10))

            // ── Bookshelves at various X positions ──
            let shelfXPositions: [Float] = [-5.0, -2.5, 2.5, 5.0]
            var shelfRng = SplitMix64(seed: 3344)
            let bookColors: [SIMD4<Float>] = [
                [0.55, 0.25, 0.10, 1], [0.40, 0.15, 0.10, 1],
                [0.15, 0.30, 0.15, 1], [0.10, 0.15, 0.35, 1],
                [0.45, 0.35, 0.12, 1]
            ]
            for x in shelfXPositions {
                // Shelf body
                addOpaque(buildBox(w: 0.4, h: 4, d: 1.5, color: shelfCol),
                          model: m4Translation(x, 2.0, -3.0))
                // Book spines on shelves
                for i in 0..<20 {
                    let bh = Float(0.25 + Double.random(in: 0...0.3, using: &shelfRng))
                    let bw = Float(0.04 + Double.random(in: 0...0.04, using: &shelfRng))
                    let row = i / 5
                    let col = i % 5
                    let bx = Float(col) * 0.055 - 0.11
                    let by = Float(row) * 0.35 - 0.6
                    addOpaque(buildBox(w: bw, h: bh, d: 0.15, color: bookColors[i % bookColors.count]),
                              model: m4Translation(x + bx, 2.0 + by, -3.0 + 0.83))
                }
            }

            // ── Stone columns ──
            let colPositions: [(Float, Float)] = [(-1.0, -3.0), (1.0, -3.0),
                                                   (-1.0, -6.0), (1.0, -6.0)]
            for (cx, cz) in colPositions {
                addOpaque(buildCylinder(radius: 0.12, height: 5, segments: 10, color: stoneCol),
                          model: m4Translation(cx, 2.5, cz))
            }

            // ── Arched window on back wall ──
            addGlow(buildQuad(w: 2.0, h: 3.0, color: [0.30, 0.40, 0.55, 1], normal: [0, 0, 1]),
                    model: m4Translation(0, 2.0, -9.9),
                    emissive: [0.25, 0.35, 0.55], mix: 0.8, opacity: 0.55)

            // ── Amber lamp pools ──
            let lampPositions: [(Float, Float, Float)] = [
                (-2.5, 1.5, -2.0), (0.0, 1.5, -4.5), (2.5, 1.5, -7.0)
            ]
            for (lx, ly, lz) in lampPositions {
                lampIndices.append(glowCalls.count)
                addGlow(buildSphere(radius: 0.12, rings: 4, segments: 6,
                                    color: [1.0, 0.72, 0.35, 1]),
                        model: m4Translation(lx, ly, lz),
                        emissive: [1.0, 0.72, 0.35], mix: 1.0, opacity: 0.45)
                // Warm glow halo
                addGlow(buildSphere(radius: 0.6, rings: 4, segments: 6,
                                    color: [1.0, 0.65, 0.25, 1]),
                        model: m4Translation(lx, ly, lz),
                        emissive: [0.80, 0.50, 0.15], mix: 0.6, opacity: 0.12)
            }

            // ── Pre-compute floating golden letter particles ──
            var letterRng = SplitMix64(seed: 7777)
            for _ in 0..<25 {
                let x = Float(Double.random(in: -4.0...4.0, using: &letterRng))
                let y = Float(Double.random(in: 0.5...3.5, using: &letterRng))
                let z = Float(Double.random(in: -9.0...(-1.0), using: &letterRng))
                letterPos.append([x, y, z])
                letterPhase.append(Float(Double.random(in: 0...6.28, using: &letterRng)))
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

            // Camera — very slow drift down the corridor, wrapping every 30s
            let driftCycle = fmod(t, 30.0)
            let camZ = 2.0 - (driftCycle / 30.0) * 10.0
            let eye: SIMD3<Float> = [0.3 * sin(t * 0.08), 1.7, camZ]
            let center: SIMD3<Float> = [0, 1.5, camZ - 5.0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 70 * .pi / 180, aspect: aspect, near: 0.1, far: 40)
            let vp    = proj4 * view4

            // Dim purple ambient with moonlight from the window
            let sunDir: SIMD3<Float> = simd_normalize([0, -0.6, -0.8])
            let sunCol: SIMD3<Float> = [0.35, 0.40, 0.55]
            let ambCol: SIMD3<Float> = [0.05, 0.03, 0.08]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(12, 28, 0, 0),
                fogColor:       SIMD4<Float>(0.03, 0.02, 0.06, 0),
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

            // Glow pass — window, lamps, halos
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                for (i, call) in glowCalls.enumerated() {
                    var em = call.emissiveCol
                    var op = call.opacity
                    if lampIndices.contains(i) {
                        let flicker = 1.0 + 0.12 * sin(t * 1.5 + Float(i) * 0.7)
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

            // Particle pass — floating golden letters
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Floating letters — rise, drift, cycle
                for i in letterPos.indices {
                    let ph   = letterPhase[i]
                    let base = letterPos[i]
                    let riseCycle = fmod(t * 0.1 + ph, 6.28)
                    let wx = base.x + 0.25 * sin(t * 0.08 + ph)
                    let wy = base.y + 1.0 * (sin(riseCycle) * 0.5 + 0.5)
                    let wz = base.z + 0.15 * cos(t * 0.06 + ph)
                    // Fade in/out as they rise
                    let fadePhase = sin(riseCycle)
                    let alpha = max(0, 0.4 + 0.45 * fadePhase)
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [1.0, 0.85, 0.25, alpha], size: 6))
                }

                // Tap burst — golden fragments from centre
                if burstFade > 0 {
                    var burstRng = SplitMix64(seed: UInt64(burstT * 1000))
                    let burstAge = t - burstT
                    for _ in 0..<50 {
                        let dx = Float(Double.random(in: -1.5...1.5, using: &burstRng))
                        let dy = Float(Double.random(in: 0.5...2.5, using: &burstRng))
                        let dz = Float(Double.random(in: -3.0...(-1.0), using: &burstRng))
                        let gravity = burstAge * burstAge * 0.4
                        let spread = 1.0 + burstAge * 1.5
                        particles.append(ParticleVertex3D(
                            position: [dx * spread, dy + burstAge * 1.0 - gravity, dz],
                            color: [1.0, 0.85, 0.20, burstFade * 0.9], size: 5))
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
        view.clearColor               = MTLClearColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 1)
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
