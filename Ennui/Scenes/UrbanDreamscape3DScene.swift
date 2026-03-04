// UrbanDreamscape3DScene — Metal 3D dreamy cel-shaded city at night.
// Wet streets, tall buildings with glowing windows, neon signs, rain, puddles.
// Tap to send a ripple through puddles.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct UrbanDreamscape3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        UrbanDreamscape3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct UrbanDreamscape3DRepresentable: NSViewRepresentable {
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

        // Puddles: base model matrices
        let puddlePositions: [(Float, Float)] = [(-1,-1), (1.5,-2), (-2.5,-3), (0.5,-4), (2,-1.5)]

        // Ripple animation
        var rippleTime: Float = -999

        // Rain
        struct RainDrop { var x, y, z: Float; var speed: Float }
        var rainDrops: [RainDrop] = []

        // Stars
        struct StarPt { var pos: SIMD3<Float>; var brightness: Float; var phase: Float }
        var stars: [StarPt] = []

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
            } catch { print("UrbanDreamscape3D pipeline error: \(error)") }
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
            // Wet street floor
            addOpaque(buildPlane(w: 30, d: 25, color: [0.10, 0.10, 0.12, 1]),
                      model: matrix_identity_float4x4)

            // Buildings
            var brng = SplitMix64(seed: 7001)
            let buildingData: [(Float, Float, Float, Float, Float)] = [
                (-6, 0, -5, 1.8, 7),
                ( 5, 0, -4, 2.0, 5),
                (-3, 0, -7, 1.4, 9),
                ( 3, 0, -8, 1.6, 6),
                (-7, 0, -9, 2.2, 4),
                ( 7, 0, -6, 1.5, 8),
                ( 0, 0,-10, 2.0, 5),
                (-1, 0, -5, 1.2, 3)
            ]
            let windowColPairs: [(SIMD3<Float>, Float)] = [
                ([0.95, 0.85, 0.50], 0.85),
                ([0.70, 0.40, 0.90], 0.80)
            ]
            for (bx, _, bz, bw, bh) in buildingData {
                let grey = Float(Double.random(in: 0.12...0.22, using: &brng))
                addOpaque(buildBox(w: bw, h: bh, d: bw * 0.7, color: [grey, grey, grey+0.02, 1]),
                          model: m4Translation(bx, bh/2, bz))
                // Windows on front face
                let winCount = Int(Double.random(in: 3...6, using: &brng))
                for _ in 0..<winCount {
                    let wy = Float(Double.random(in: -bh*0.4...bh*0.4, using: &brng))
                    let wx = Float(Double.random(in: -bw*0.3...bw*0.3, using: &brng))
                    let cidx = Int(Double.random(in: 0...1.99, using: &brng))
                    let (wec, wop) = windowColPairs[cidx]
                    addGlow(buildQuad(w: 0.18, h: 0.14, color: [1,1,1,1], normal: [0,0,1]),
                            model: m4Translation(bx + wx, bh/2 + wy, bz + bw*0.36),
                            emissive: wec, opacity: wop)
                }
            }

            // Neon signs
            let neonData: [(Float, Float, Float, SIMD3<Float>)] = [
                (-4, 3.0, -2.6, [1.0, 0.15, 0.60]),
                ( 2, 2.5, -3.6, [0.2, 0.90, 0.90]),
                (-1, 4.0, -5.0, [1.0, 0.90, 0.10])
            ]
            for (nx, ny, nz, nc) in neonData {
                addGlow(buildQuad(w: 0.8, h: 0.20, color: [1,1,1,1], normal: [0,0,1]),
                        model: m4Translation(nx, ny, nz),
                        emissive: nc, opacity: 0.95)
            }

            // Puddles
            for (px, pz) in puddlePositions {
                addOpaque(buildBox(w: 0.8, h: 0.005, d: 0.5, color: [0.04, 0.05, 0.08, 1]),
                          model: m4Translation(px, 0.003, pz))
            }

            // Seed rain
            var rrng = SplitMix64(seed: 7101)
            for _ in 0..<250 {
                rainDrops.append(RainDrop(
                    x:     Float(Double.random(in: -12...12, using: &rrng)),
                    y:     Float(Double.random(in: 0...14, using: &rrng)),
                    z:     Float(Double.random(in: -12...3, using: &rrng)),
                    speed: Float(Double.random(in: 7...10, using: &rrng))
                ))
            }

            // Stars
            var srng = SplitMix64(seed: 7002)
            for _ in 0..<60 {
                let sx = Float(Double.random(in: -20...20, using: &srng))
                let sy = Float(Double.random(in: 10...25, using: &srng))
                let sz = Float(Double.random(in: -25 ... -5, using: &srng))
                let br = Float(Double.random(in: 0.4...0.8, using: &srng))
                let ph = Float(Double.random(in: 0...Float.pi*2, using: &srng))
                stars.append(StarPt(pos: [sx, sy, sz], brightness: br, phase: ph))
            }
        }

        func triggerRipple(time: Float) { rippleTime = time }

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

            // Ripple scale for puddles
            let rippleAge = t - rippleTime
            let rippleScale: Float
            if rippleAge < 0.25 { rippleScale = 1.0 + rippleAge / 0.25 * 0.3 }
            else if rippleAge < 0.5 { rippleScale = 1.3 - (rippleAge - 0.25) / 0.25 * 0.3 }
            else { rippleScale = 1.0 }

            // Camera orbits city center
            let orbitAngle = t * Float.pi * 2 / 80
            let orbitR: Float = 6
            let eyeX = sin(orbitAngle) * orbitR
            let eyeZ = cos(orbitAngle) * orbitR - 5
            let eye: SIMD3<Float>    = [eyeX, 3.0, eyeZ]
            let center: SIMD3<Float> = [0, 2.0, -5.0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.05, far: 80)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([-0.2, 0.8, 0.4]), 0),
                sunColor:       SIMD4<Float>([0.50, 0.50, 0.70], 0),
                ambientColor:   SIMD4<Float>([0.06, 0.04, 0.14], t),
                fogParams:      SIMD4<Float>(20, 65, 0, 0),
                fogColor:       SIMD4<Float>([0.03, 0.02, 0.06], 0),
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

            // Puddles with ripple scale
            if rippleScale != 1.0 {
                let puddleVerts = buildBox(w: 0.8, h: 0.005, d: 0.5, color: [0.08, 0.10, 0.18, 1])
                if let pbuf = makeVertexBuffer(puddleVerts, device: device) {
                    for (px, pz) in puddlePositions {
                        let model = m4Translation(px, 0.004, pz) * m4Scale(rippleScale, 1, rippleScale)
                        encodeDraw(encoder: encoder, vertexBuffer: pbuf, vertexCount: puddleVerts.count,
                                   model: model,
                                   emissiveColor: [0.1, 0.15, 0.3] * (rippleScale - 1.0) * 3,
                                   emissiveMix: (rippleScale - 1.0) * 3)
                    }
                }
            }

            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model, emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }
            }

            // Rain + stars
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                for drop in rainDrops {
                    let elapsed = t * drop.speed
                    let dy = elapsed.truncatingRemainder(dividingBy: 15.0)
                    let py = drop.y - dy
                    let wrappedY = py < -1.5 ? py + 15.0 : py
                    particles.append(ParticleVertex3D(
                        position: [drop.x, wrappedY, drop.z],
                        color: [0.6, 0.7, 0.9, 0.4], size: 2))
                }

                for s in stars {
                    let tw = 0.6 + 0.4 * sin(t * 1.2 + s.phase)
                    let a = s.brightness * tw
                    particles.append(ParticleVertex3D(position: s.pos,
                                                      color: [a, a, a, a], size: 2))
                }

                if !particles.isEmpty, let rbuf = makeParticleBuffer(particles, device: device) {
                    encoder.setRenderPipelineState(ppipe)
                    encoder.setDepthStencilState(depthROState)
                    encoder.setVertexBuffer(rbuf, offset: 0, index: 0)
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
        view.clearColor              = MTLClearColor(red: 0.03, green: 0.02, blue: 0.06, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerRipple(time: t)
    }
}
