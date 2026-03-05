// MinnesotaSmallTown3DScene — Metal 3D Minnesota prairie town on summer evening.
// Church with steeple, water tower, grain elevator, diner with neon, stars, fireflies.
// Tap to burst fireflies.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct MinnesotaSmallTown3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        MinnesotaSmallTown3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct MinnesotaSmallTown3DRepresentable: NSViewRepresentable {
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

        // Stars
        struct StarPt { var pos: SIMD3<Float>; var brightness: Float; var phase: Float }
        var stars: [StarPt] = []

        // Fireflies
        struct Firefly {
            var pos: SIMD3<Float>; var vel: SIMD3<Float>
            var phase: Float; var lifespan: Float; var born: Float
        }
        var fireflies: [Firefly] = []
        var fireflyBurstTime: Float = -999
        var rng = SplitMix64(seed: 9101)

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
            } catch { print("MinnesotaSmallTown3D pipeline error: \(error)") }
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
            // Ground
            addOpaque(buildPlane(w: 40, d: 40, color: [0.28, 0.25, 0.20, 1]),
                      model: matrix_identity_float4x4)

            // Church body
            addOpaque(buildBox(w: 2, h: 2.5, d: 2, color: [0.90, 0.89, 0.87, 1]),
                      model: m4Translation(-6, 1.25, -3))
            // Steeple
            addOpaque(buildCylinder(radius: 0.15, height: 3, segments: 8,
                                    color: [0.88, 0.87, 0.86, 1]),
                      model: m4Translation(-6, 4.0, -3))
            addOpaque(buildCone(radius: 0.25, height: 0.8, segments: 8,
                                color: [0.72, 0.71, 0.70, 1]),
                      model: m4Translation(-6, 5.85, -3))
            // Church window
            addGlow(buildQuad(w: 0.4, h: 0.7, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(-6, 1.4, -1.98),
                    emissive: [1.0, 0.88, 0.50], opacity: 0.85)

            // Water tower tank
            addOpaque(buildCylinder(radius: 0.8, height: 1.2, segments: 10,
                                    color: [0.52, 0.50, 0.47, 1]),
                      model: m4Translation(3, 2.6, -5))
            // Water tower legs
            for k in 0..<6 {
                let ang = Float(k) * Float.pi * 2 / 6
                addOpaque(buildCylinder(radius: 0.05, height: 2, segments: 6,
                                        color: [0.38, 0.36, 0.34, 1]),
                          model: m4Translation(3 + cos(ang)*0.6, 1.0, -5 + sin(ang)*0.6))
            }

            // Grain elevator
            addOpaque(buildBox(w: 1.5, h: 5, d: 1.5, color: [0.70, 0.68, 0.65, 1]),
                      model: m4Translation(6, 2.5, -4))
            addOpaque(buildPyramid(bw: 1.7, bd: 1.7, h: 0.7, color: [0.48, 0.46, 0.44, 1]),
                      model: m4Translation(6, 5.35, -4))

            // Diner body
            addOpaque(buildBox(w: 2.5, h: 1.5, d: 1.5, color: [0.94, 0.91, 0.80, 1]),
                      model: m4Translation(-2, 0.75, -3))
            // Diner window
            addGlow(buildQuad(w: 0.7, h: 0.5, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(-2, 0.75, -2.23),
                    emissive: [1.0, 0.90, 0.60], opacity: 0.8)
            // Neon sign (flickering handled in draw)
            addGlow(buildQuad(w: 1.0, h: 0.22, color: [1,1,1,1], normal: [0,0,1]),
                    model: m4Translation(-2, 1.65, -2.23),
                    emissive: [1.0, 0.10, 0.10], opacity: 0.9)

            // Stars
            var srng = SplitMix64(seed: 9001)
            for _ in 0..<100 {
                let sx = Float(Double.random(in: -30...30, using: &srng))
                let sy = Float(Double.random(in: 8...28, using: &srng))
                let sz = Float(Double.random(in: -35 ... -5, using: &srng))
                let br = Float(Double.random(in: 0.5...1.0, using: &srng))
                let ph = Float(Double.random(in: 0...Double.pi*2, using: &srng))
                stars.append(StarPt(pos: [sx, sy, sz], brightness: br, phase: ph))
            }

            // Seed initial fireflies
            for _ in 0..<30 {
                spawnFirefly(born: Float(Double.random(in: -9...0, using: &rng)))
            }
        }

        private func spawnFirefly(born: Float) {
            let x = Float(Double.random(in: -7...7, using: &rng))
            let y = Float(Double.random(in: 0.5...2.5, using: &rng))
            let z = Float(Double.random(in: -8 ... -0.5, using: &rng))
            let vx = Float(Double.random(in: -0.25...0.25, using: &rng))
            let vy = Float(Double.random(in: 0.0...0.2, using: &rng))
            let vz = Float(Double.random(in: -0.1...0.1, using: &rng))
            let ph = Float(Double.random(in: 0...Double.pi*2, using: &rng))
            let ls = Float(Double.random(in: 5...12, using: &rng))
            fireflies.append(Firefly(pos: [x, y, z], vel: [vx, vy, vz],
                                     phase: ph, lifespan: ls, born: born))
        }

        func triggerBurst(time: Float) {
            fireflyBurstTime = time
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

            // Drift camera down Main Street
            let camZ = 6.0 - (t.truncatingRemainder(dividingBy: 28.0) / 28.0) * 14.0
            let eye: SIMD3<Float>    = [0, 2.0, camZ]
            let center: SIMD3<Float> = [0, 1.6, camZ - 8]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.05, far: 80)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([0.5, 0.7, 0.3]), 0),
                sunColor:       SIMD4<Float>([0.95, 0.75, 0.45], 0),
                ambientColor:   SIMD4<Float>([0.05, 0.06, 0.15], t),
                fogParams:      SIMD4<Float>(30, 70, 0, 0),
                fogColor:       SIMD4<Float>([0.04, 0.05, 0.10], 0),
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

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for (i, call) in glowCalls.enumerated() {
                    var ecol = call.emissiveCol
                    // Neon flicker (index 2 = neon sign)
                    if i == 2 {
                        let flicker = sin(t * 12) + sin(t * 17)
                        let on: Float = flicker > 0 ? 1.0 : 0.15
                        ecol = ecol * on
                    }
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: ecol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }

                // Stars
                var starbuf: [ParticleVertex3D] = []
                for s in stars {
                    let twinkle = 0.7 + 0.3 * sin(t * 1.5 + s.phase)
                    let a = s.brightness * twinkle
                    starbuf.append(ParticleVertex3D(position: s.pos,
                                                    color: [a, a, a * 0.95, a], size: 3))
                }
                if let sbuf = makeParticleBuffer(starbuf, device: device) {
                    if let ppipe = particlePipeline {
                        encoder.setRenderPipelineState(ppipe)
                        encoder.setDepthStencilState(depthROState)
                        encoder.setVertexBuffer(sbuf, offset: 0, index: 0)
                        encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                        encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: starbuf.count)
                    }
                }
            }

            // Firefly particles
            if let ppipe = particlePipeline {
                let burstActive = t - fireflyBurstTime < 1.5
                // Spawn extras during burst
                if burstActive {
                    for _ in 0..<3 { spawnFirefly(born: t) }
                } else if Float.random(in: 0...1) < 0.1 {
                    spawnFirefly(born: t)
                }
                // Remove expired
                fireflies.removeAll { t - $0.born > $0.lifespan }

                var particles: [ParticleVertex3D] = []
                for ff in fireflies {
                    let age = t - ff.born
                    let fade: Float = age < 1.0 ? age : (age > ff.lifespan - 1.5 ? (ff.lifespan - age) / 1.5 : 1.0)
                    let blink = max(0, sin(t * 3 + ff.phase))
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
        view.clearColor              = MTLClearColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)
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
