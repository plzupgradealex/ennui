// ForgottenLibrary3DScene — Infinite twilight library with floating golden letters.
// Bookshelves, stone columns, amber lamp pools, arched window, drifting letters.
// Tap to burst golden letter fragments.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct ForgottenLibrary3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        ForgottenLibrary3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct ForgottenLibrary3DRepresentable: NSViewRepresentable {
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

        // Motes: 15 rising golden particles
        struct Mote {
            var baseX: Float; var baseY: Float; var baseZ: Float; var phase: Float
        }
        var motes: [Mote] = []

        // Burst
        var burstT: Float = -999
        var burstDirs: [SIMD3<Float>] = []

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
            } catch { print("ForgottenLibrary3D pipeline error: \(error)") }
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
            // Floor
            addOpaque(buildPlane(w: 12, d: 20, color: [0.15, 0.14, 0.13, 1]),
                      model: matrix_identity_float4x4)

            // Bookshelves at x = [-5, -2.5, 2.5, 5], z = -3
            let shelfXs: [Float] = [-5, -2.5, 2.5, 5]
            var brng = SplitMix64(seed: 4201)

            let bookColors: [SIMD4<Float>] = [
                [0.55, 0.18, 0.12, 1], [0.18, 0.35, 0.55, 1], [0.22, 0.48, 0.22, 1],
                [0.60, 0.50, 0.12, 1], [0.45, 0.20, 0.45, 1], [0.55, 0.35, 0.15, 1],
                [0.25, 0.40, 0.55, 1], [0.60, 0.22, 0.22, 1]
            ]

            for sx in shelfXs {
                // Main shelf body
                addOpaque(buildBox(w: 0.4, h: 4, d: 1.5, color: [0.22, 0.14, 0.08, 1]),
                          model: m4Translation(sx, 2, -3))
                // 4 rows of 4 books on the front face of each shelf
                for row in 0..<4 {
                    for col in 0..<4 {
                        let bookW: Float = 0.08 + Float(brng.nextDouble()) * 0.06
                        let bookH: Float = 0.28 + Float(brng.nextDouble()) * 0.08
                        let ci = Int(brng.nextDouble() * Double(bookColors.count)) % bookColors.count
                        let bx = sx + Float(col - 1) * 0.1 - 0.05
                        let by = 0.3 + Float(row) * 0.85
                        let bz = -3 + 0.78  // front face of shelf
                        addOpaque(buildBox(w: bookW, h: bookH, d: 0.15, color: bookColors[ci]),
                                  model: m4Translation(bx, by, bz))
                    }
                }
            }

            // Stone columns: 4 pairs at (±1, 2, -3) and (±1, 2, -6)
            let colZs: [Float] = [-3, -6]
            for cz in colZs {
                for cx: Float in [-1, 1] {
                    addOpaque(buildCylinder(radius: 0.12, height: 4, segments: 12,
                                           color: [0.35, 0.33, 0.30, 1]),
                              model: m4Translation(cx, 2, cz))
                }
            }

            // Archway window (glow)
            addGlow(buildQuad(w: 2, h: 3, color: [0.3, 0.4, 0.55, 0.7]),
                    model: m4Translation(0, 2, -9),
                    emissive: [0.25, 0.35, 0.55], opacity: 0.7)

            // 3 Lamp pool glow spheres
            let lampPositions: [SIMD3<Float>] = [[-2.5, 1.5, -2], [0, 1.5, -4.5], [2.5, 1.5, -7]]
            for lp in lampPositions {
                addGlow(buildSphere(radius: 0.06, rings: 8, segments: 8,
                                    color: [1.0, 0.72, 0.35, 1]),
                        model: m4Translation(lp.x, lp.y, lp.z),
                        emissive: [1.0, 0.72, 0.35], opacity: 1.0)
            }

            // Motes: 15 rising golden letter particles
            var mrng = SplitMix64(seed: 4202)
            for _ in 0..<15 {
                let x = Float(mrng.nextDouble()) * 8 - 4
                let y = Float(mrng.nextDouble()) * 2 + 0.5
                let z = Float(mrng.nextDouble()) * 7 + 1
                let phase = Float(mrng.nextDouble()) * Float.pi * 2
                motes.append(Mote(baseX: x, baseY: y, baseZ: -z, phase: phase))
            }

            // Burst directions: 60 precomputed random unit vectors
            var bdrng = SplitMix64(seed: 4203)
            for _ in 0..<60 {
                let theta = Float(bdrng.nextDouble()) * Float.pi * 2
                let phi   = Float(bdrng.nextDouble()) * Float.pi
                let d = SIMD3<Float>(sin(phi) * cos(theta), sin(phi) * sin(theta), cos(phi))
                burstDirs.append(simd_normalize(d))
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

            // Camera drifts forward down corridor, period=30s, then snaps back
            let tMod = t.truncatingRemainder(dividingBy: 30.0)
            let camZ = 2.0 - tMod * (10.0 / 30.0)  // z=2 to z=-8 over 30s
            let eye = SIMD3<Float>(0, 1.7, camZ)
            let center = SIMD3<Float>(0, 1.7 + sin(-0.05), camZ - 1)
            let view3D = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj   = m4Perspective(fovyRad: 1.1, aspect: aspect, near: 0.1, far: 40)

            var su = SceneUniforms3D(
                viewProjection:  proj * view3D,
                sunDirection:    SIMD4<Float>(simd_normalize([0, -1, 0]), 0),
                sunColor:        SIMD4<Float>([0.3, 0.35, 0.45], 0),
                ambientColor:    SIMD4<Float>([0.04, 0.03, 0.08], t),
                fogParams:       SIMD4<Float>(12, 28, 0, 0),
                fogColor:        SIMD4<Float>([0.03, 0.02, 0.08], 0),
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

            // Particle pass
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []

                // Rising golden motes
                for m in motes {
                    let rise = (t * 0.1 + m.phase).truncatingRemainder(dividingBy: 2.5)
                    let py   = m.baseY + rise
                    let alpha = 0.7 * pow(sin(t * 0.8 + m.phase), 2)
                    pv.append(ParticleVertex3D(position: [m.baseX, py, m.baseZ],
                                               color: [1.0, 0.85, 0.25, max(0, alpha)],
                                               size: 5))
                }

                // Burst particles
                let age = t - burstT
                if age < 0.8 {
                    let fade = max(0, 1 - age / 0.8)
                    let center3: SIMD3<Float> = [0, 1.5, -2]
                    for dir in burstDirs {
                        let pos = center3 + dir * age * 3
                        pv.append(ParticleVertex3D(position: pos,
                                                   color: [1.0, 0.85, 0.2, fade],
                                                   size: 8))
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
        v.clearColor               = MTLClearColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 1)
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
