// CaptainStar3DScene — Metal 3D barren desert planet at edge of universe.
// Ochre floor, floating rocks, glass outpost, planetary rings, dust particles, stars.
// Tap to send a luminous pulse (flash all emissive objects).
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct CaptainStar3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        CaptainStar3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct CaptainStar3DRepresentable: NSViewRepresentable {
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

        struct Rock {
            var x, baseY, z: Float
            var bobAmp, bobSpeed, bobPhase: Float
            var rotSpeed: Float
            var size: SIMD3<Float>
            var colorIdx: Int
            var buffer: MTLBuffer
            var count: Int
        }
        var rocks: [Rock] = []

        struct StarPt { var pos: SIMD3<Float>; var brightness: Float; var phase: Float }
        var stars: [StarPt] = []

        // Dust particles
        struct DustParticle { var x, y, z: Float; var phase: Float; var speed: Float }
        var dust: [DustParticle] = []

        var pulseTime: Float = -999

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
            } catch { print("CaptainStar3D pipeline error: \(error)") }
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
            // Ochre desert floor
            addOpaque(buildPlane(w: 50, d: 50, color: [0.55, 0.35, 0.15, 1]),
                      model: matrix_identity_float4x4)

            // Distant foggy horizon bands
            addOpaque(buildBox(w: 50, h: 2, d: 1, color: [0.45, 0.30, 0.12, 1]),
                      model: m4Translation(0, 1.0, -22))

            // Floating rocks
            let rockColors: [SIMD4<Float>] = [
                [0.55, 0.48, 0.38, 1],
                [0.48, 0.42, 0.30, 1],
                [0.60, 0.50, 0.35, 1]
            ]
            var rrng = SplitMix64(seed: 1111)
            let rockData: [(Float, Float, Float, Float)] = [
                ( -3.5, 2.0, -6,  0.8),
                (  2.0, 1.5, -4,  0.6),
                ( -1.0, 2.8, -8,  1.2),
                (  4.5, 1.8, -5,  0.7),
                (  0.5, 3.0, -9,  1.0)
            ]
            for (i, (rx, ry, rz, rsize)) in rockData.enumerated() {
                let verts = buildBox(w: rsize, h: rsize * 0.85, d: rsize * 0.9,
                                     color: rockColors[i % rockColors.count])
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                rocks.append(Rock(
                    x: rx, baseY: ry, z: rz,
                    bobAmp: Float(0.15 + Double.random(in: 0...0.2, using: &rrng)),
                    bobSpeed: Float(0.5 + Double.random(in: 0...0.5, using: &rrng)),
                    bobPhase: Float(Double.random(in: 0...Float.pi*2, using: &rrng)),
                    rotSpeed: Float(0.3 + Double.random(in: 0...0.4, using: &rrng)),
                    size: [rsize, rsize * 0.85, rsize * 0.9],
                    colorIdx: i % rockColors.count,
                    buffer: buf, count: verts.count
                ))
            }

            // Glass outpost (transparent, emissive interior)
            addGlow(buildBox(w: 2, h: 2.5, d: 2, color: [0.7, 0.85, 0.9, 1]),
                    model: m4Translation(3, 1.25, -5),
                    emissive: [1.0, 0.78, 0.45], opacity: 0.35)

            // Outpost base
            addOpaque(buildBox(w: 2.2, h: 0.15, d: 2.2, color: [0.45, 0.35, 0.20, 1]),
                      model: m4Translation(3, 0.075, -5))

            // Planetary ring (large flat torus approximation using many thin boxes)
            let ringSegs = 32
            for i in 0..<ringSegs {
                let ang = Float(i) * Float.pi * 2 / Float(ringSegs)
                let r: Float = 25
                let rx2 = cos(ang) * r
                let rz2 = sin(ang) * r
                addOpaque(buildBox(w: 1.5, h: 0.25, d: 0.4,
                                   color: [0.42, 0.35, 0.25, 1]),
                          model: m4Translation(rx2, -22 + rx2 * 0.08, rz2 - 30) * m4RotY(ang))
            }

            // Stars
            var srng = SplitMix64(seed: 1112)
            for _ in 0..<100 {
                let sx = Float(Double.random(in: -30...30, using: &srng))
                let sy = Float(Double.random(in: 5...25, using: &srng))
                let sz = Float(Double.random(in: -45 ... -5, using: &srng))
                let br = Float(Double.random(in: 0.7...1.0, using: &srng))
                let ph = Float(Double.random(in: 0...Float.pi*2, using: &srng))
                stars.append(StarPt(pos: [sx, sy, sz], brightness: br, phase: ph))
            }

            // Dust
            var drng = SplitMix64(seed: 1113)
            for _ in 0..<80 {
                dust.append(DustParticle(
                    x:     Float(Double.random(in: -6...6, using: &drng)),
                    y:     Float(Double.random(in: 0.2...2.5, using: &drng)),
                    z:     Float(Double.random(in: -10...0, using: &drng)),
                    phase: Float(Double.random(in: 0...Float.pi*2, using: &drng)),
                    speed: Float(Double.random(in: 0.2...0.6, using: &drng))
                ))
            }
        }

        func triggerPulse(time: Float) { pulseTime = time }

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

            // Pulse factor
            let pulseAge = t - pulseTime
            let pulseFactor: Float = pulseAge < 1.5
                ? (1.0 + 2.0 * (1.0 - pulseAge / 1.5))
                : 1.0

            // Camera drifts forward slowly
            let camProgress = t.truncatingRemainder(dividingBy: 60.0) / 60.0
            let eye: SIMD3<Float>    = [0, 1.8, 6.0 - camProgress * 8.0]
            let center: SIMD3<Float> = [0, 1.4, eye.z - 6]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 75 * .pi / 180, aspect: aspect, near: 0.05, far: 60)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([0.4, 0.6, -0.2]), 0),
                sunColor:       SIMD4<Float>([1.0, 0.78, 0.35], 0),
                ambientColor:   SIMD4<Float>([0.20, 0.14, 0.06], t),
                fogParams:      SIMD4<Float>(18, 35, 0, 0),
                fogColor:       SIMD4<Float>([0.14, 0.10, 0.05], 0),
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

            // Floating rocks (animated in draw loop)
            for rock in rocks {
                let bobY = rock.baseY + sin(t * rock.bobSpeed + rock.bobPhase) * rock.bobAmp
                let rotY = t * rock.rotSpeed
                let model = m4Translation(rock.x, bobY, rock.z) * m4RotY(rotY) * m4RotX(rotY * 0.3)
                encodeDraw(encoder: encoder, vertexBuffer: rock.buffer, vertexCount: rock.count,
                           model: model)
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol * pulseFactor,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }
            }

            // Particles: stars + dust
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                for s in stars {
                    let tw = 0.7 + 0.3 * sin(t * 1.1 + s.phase)
                    let a = s.brightness * tw * pulseFactor
                    particles.append(ParticleVertex3D(position: s.pos,
                                                      color: [a, a, a*0.90, min(1, a)], size: 3))
                }

                for d in dust {
                    let dx = d.x + sin(t * d.speed + d.phase) * 0.4
                    let dy = d.y + cos(t * d.speed * 0.7 + d.phase) * 0.2
                    particles.append(ParticleVertex3D(
                        position: [dx, dy, d.z],
                        color: [0.75, 0.60, 0.38, 0.5], size: 4))
                }

                // Pulse ring effect
                if pulseFactor > 1.0 {
                    let ringR = (t - pulseTime) * 8.0
                    for i in 0..<48 {
                        let ang = Float(i) * Float.pi * 2 / 48
                        let rx2 = eye.x + cos(ang) * ringR
                        let rz2 = eye.z - 3 + sin(ang) * ringR
                        let alpha = (pulseFactor - 1.0) / 2.0
                        particles.append(ParticleVertex3D(
                            position: [rx2, 1.5, rz2],
                            color: [1.0, 0.8, 0.4, alpha * 0.6], size: 5))
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
        view.clearColor              = MTLClearColor(red: 0.12, green: 0.09, blue: 0.04, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerPulse(time: t)
    }
}
