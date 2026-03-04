// OntarioCountryside3DScene — Metal 3D Ontario countryside at dusk.
// Red barn, gravel road, fence, trees, fireflies, stars.
// Tap to send a gust of wind through the wheat (firefly burst).
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct OntarioCountryside3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        OntarioCountryside3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct OntarioCountryside3DRepresentable: NSViewRepresentable {
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

        struct StarPt { var pos: SIMD3<Float>; var brightness: Float; var phase: Float }
        var stars: [StarPt] = []

        struct Firefly {
            var pos: SIMD3<Float>; var vel: SIMD3<Float>
            var phase: Float; var lifespan: Float; var born: Float
        }
        var fireflies: [Firefly] = []
        var fireflyBurstTime: Float = -999
        var rng = SplitMix64(seed: 8201)

        // Wheat stalks for wind gust
        var gustTime: Float = -999

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
            } catch { print("OntarioCountryside3D pipeline error: \(error)") }
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
            // Wheat-gold ground
            addOpaque(buildPlane(w: 40, d: 40, color: [0.60, 0.50, 0.22, 1]),
                      model: matrix_identity_float4x4)

            // Red barn body
            addOpaque(buildBox(w: 3, h: 2.5, d: 2, color: [0.65, 0.10, 0.08, 1]),
                      model: m4Translation(-5, 1.25, -5))
            addOpaque(buildPyramid(bw: 3.2, bd: 2.2, h: 1.5, color: [0.40, 0.06, 0.05, 1]),
                      model: m4Translation(-5, 3.25, -5))
            // Barn window
            addGlow(buildQuad(w: 0.8, h: 0.6, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(-5, 1.5, -3.98),
                    emissive: [0.90, 0.70, 0.30], opacity: 0.8)

            // Gravel road
            addOpaque(buildBox(w: 1.2, h: 0.012, d: 22, color: [0.68, 0.62, 0.50, 1]),
                      model: m4Translation(0, 0.006, -5))

            // Fence posts
            for k in 0..<8 {
                addOpaque(buildCylinder(radius: 0.04, height: 0.8, segments: 6,
                                        color: [0.35, 0.22, 0.12, 1]),
                          model: m4Translation(1.0, 0.4, Float(k) * -1.5 - 1))
            }
            // Fence rails
            for r in 0..<3 {
                addOpaque(buildBox(w: 0.04, h: 0.04, d: 8, color: [0.40, 0.26, 0.14, 1]),
                          model: m4Translation(1.0, Float(r) * 0.25 + 0.15, -5))
            }

            // Trees
            var trng = SplitMix64(seed: 8001)
            let treePos: [(Float, Float)] = [
                (Float(Double.random(in: 3...5, using: &trng)), Float(Double.random(in: -3 ... -1, using: &trng))),
                (Float(Double.random(in: 3...6, using: &trng)), Float(Double.random(in: -7 ... -5, using: &trng))),
                (Float(Double.random(in: -8 ... -6, using: &trng)), Float(Double.random(in: -3 ... -1, using: &trng))),
                (Float(Double.random(in: -8 ... -6, using: &trng)), Float(Double.random(in: -8 ... -6, using: &trng)))
            ]
            for (tx, tz) in treePos {
                addOpaque(buildCylinder(radius: 0.12, height: 2, segments: 7,
                                        color: [0.35, 0.22, 0.10, 1]),
                          model: m4Translation(tx, 1.0, tz))
                addOpaque(buildSphere(radius: 0.9, rings: 5, segments: 10,
                                      color: [0.12, 0.28, 0.10, 1]),
                          model: m4Translation(tx, 2.7, tz))
            }

            // Stars
            var srng = SplitMix64(seed: 8002)
            for _ in 0..<80 {
                let sx = Float(Double.random(in: -25...25, using: &srng))
                let sy = Float(Double.random(in: 8...25, using: &srng))
                let sz = Float(Double.random(in: -30 ... -5, using: &srng))
                let br = Float(Double.random(in: 0.6...1.0, using: &srng))
                let ph = Float(Double.random(in: 0...Float.pi*2, using: &srng))
                stars.append(StarPt(pos: [sx, sy, sz], brightness: br, phase: ph))
            }

            // Seed initial fireflies
            for _ in 0..<28 {
                spawnFirefly(born: Float(Double.random(in: -8...0, using: &rng)))
            }
        }

        private func spawnFirefly(born: Float) {
            let x = Float(Double.random(in: -6...6, using: &rng))
            let y = Float(Double.random(in: 0.5...2.0, using: &rng))
            let z = Float(Double.random(in: -8 ... -0.5, using: &rng))
            let vx = Float(Double.random(in: -0.3...0.3, using: &rng))
            let vy = Float(Double.random(in: 0.0...0.25, using: &rng))
            let vz = Float(Double.random(in: -0.15...0.15, using: &rng))
            let ph = Float(Double.random(in: 0...Float.pi*2, using: &rng))
            let ls = Float(Double.random(in: 5...11, using: &rng))
            fireflies.append(Firefly(pos: [x, y, z], vel: [vx, vy, vz],
                                     phase: ph, lifespan: ls, born: born))
        }

        func triggerBurst(time: Float) {
            fireflyBurstTime = time
            gustTime = time
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opPipe  = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpDesc   = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let encoder  = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Camera slow pan
            let panY = sin(t * Float.pi * 2 / 24) * 0.3
            let eye: SIMD3<Float>    = [0, 2.0, 5.0]
            let center: SIMD3<Float> = [sin(panY) * 8, 1.5, -5]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 62 * .pi / 180, aspect: aspect, near: 0.05, far: 80)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([0.4, 0.6, -0.3]), 0),
                sunColor:       SIMD4<Float>([1.0, 0.75, 0.35], 0),
                ambientColor:   SIMD4<Float>([0.10, 0.08, 0.06], t),
                fogParams:      SIMD4<Float>(30, 75, 0, 0),
                fogColor:       SIMD4<Float>([0.05, 0.06, 0.12], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }

                // Stars via particle pass
                if let ppipe = particlePipeline {
                    var sbuf: [ParticleVertex3D] = []
                    for s in stars {
                        let tw = 0.7 + 0.3 * sin(t * 1.4 + s.phase)
                        let a = s.brightness * tw
                        sbuf.append(ParticleVertex3D(position: s.pos,
                                                     color: [a, a, a*0.95, a], size: 3))
                    }
                    if let pb = makeParticleBuffer(sbuf, device: device) {
                        encoder.setRenderPipelineState(ppipe)
                        encoder.setDepthStencilState(depthROState)
                        encoder.setVertexBuffer(pb, offset: 0, index: 0)
                        encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: sbuf.count)
                    }
                }
            }

            // Fireflies + wind particles
            if let ppipe = particlePipeline {
                let burstActive = t - fireflyBurstTime < 1.5
                if burstActive {
                    for _ in 0..<4 { spawnFirefly(born: t) }
                } else if Float.random(in: 0...1) < 0.08 {
                    spawnFirefly(born: t)
                }
                fireflies.removeAll { t - $0.born > $0.lifespan }

                var particles: [ParticleVertex3D] = []

                // Wind wheat particles during gust
                let gustAge = t - gustTime
                if gustAge >= 0 && gustAge < 2.5 {
                    let gustStr = sin(gustAge * Float.pi / 2.5)
                    for i in 0..<30 {
                        let wx = Float(i) * 0.8 - 12.0 + gustAge * 3.0
                        let wy = Float(0.3 + 0.2 * sin(Float(i) * 1.3 + t * 4))
                        particles.append(ParticleVertex3D(
                            position: [wx, wy, -3],
                            color: [0.72, 0.60, 0.22, gustStr * 0.5], size: 3))
                    }
                }

                for ff in fireflies {
                    let age = t - ff.born
                    let fade: Float = age < 1.0 ? age : (age > ff.lifespan - 1.5 ? (ff.lifespan - age)/1.5 : 1.0)
                    let blink = max(0, sin(t * 2.8 + ff.phase))
                    let alpha = fade * blink * 0.9
                    if alpha > 0.01 {
                        let px = ff.pos.x + ff.vel.x * age
                        let py = ff.pos.y + ff.vel.y * age
                        let pz = ff.pos.z + ff.vel.z * age
                        particles.append(ParticleVertex3D(position: [px, py, pz],
                                                          color: [0.8, 1.0, 0.3, alpha], size: 5))
                    }
                }
                if !particles.isEmpty, let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.delegate                = context.coordinator
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor              = MTLClearColor(red: 0.05, green: 0.06, blue: 0.12, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerBurst(time: t)
    }
}
