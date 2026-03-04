// PaperLanternFestival3DScene — Metal 3D lantern festival over dark lake at dusk.
// Floating paper lanterns drift upward, moon, stars. Tap to release a new lantern.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct PaperLanternFestival3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        PaperLanternFestival3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct PaperLanternFestival3DRepresentable: NSViewRepresentable {
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

        struct Lantern {
            var startX, startY, startZ: Float
            var born: Float
            var driftDuration: Float
            var swayPhase: Float
        }
        var lanterns: [Lantern] = []
        var rng = SplitMix64(seed: 9999)

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
            } catch { print("PaperLanternFestival3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                        emissiveCol: .zero, emissiveMix: 0))
        }

        private func buildScene() {
            // Dark lake floor
            addOpaque(buildPlane(w: 40, d: 30, color: [0.04, 0.06, 0.12, 1]),
                      model: matrix_identity_float4x4)
            // Lake water surface (slightly reflective dark blue)
            addOpaque(buildPlane(w: 30, d: 20, color: [0.05, 0.08, 0.18, 1]),
                      model: m4Translation(0, 0.01, -5))

            // Distant shore silhouette
            addOpaque(buildBox(w: 30, h: 1.5, d: 2, color: [0.04, 0.04, 0.06, 1]),
                      model: m4Translation(0, 0.75, -12))

            // Moon
            addOpaque(buildSphere(radius: 1.5, rings: 8, segments: 12,
                                  color: [0.92, 0.92, 0.88, 1]),
                      model: m4Translation(0, 20, -20))

            // Stars
            var srng = SplitMix64(seed: 1002)
            for _ in 0..<80 {
                let sx = Float(Double.random(in: -30...30, using: &srng))
                let sy = Float(Double.random(in: 8...30, using: &srng))
                let sz = Float(Double.random(in: -35 ... -5, using: &srng))
                let br = Float(Double.random(in: 0.5...1.0, using: &srng))
                let ph = Float(Double.random(in: 0...Float.pi*2, using: &srng))
                stars.append(StarPt(pos: [sx, sy, sz], brightness: br, phase: ph))
            }

            // Initial lanterns
            var lrng = SplitMix64(seed: 1001)
            for _ in 0..<20 {
                let lx = Float(Double.random(in: -8...8, using: &lrng))
                let lz = Float(Double.random(in: -12 ... -2, using: &lrng))
                let ly = Float(Double.random(in: 0.5...4.0, using: &lrng))
                let dur = Float(Double.random(in: 20...40, using: &lrng))
                let ph  = Float(Double.random(in: 0...Float.pi*2, using: &lrng))
                lanterns.append(Lantern(startX: lx, startY: ly, startZ: lz,
                                        born: -Float(Double.random(in: 0...dur*0.5, using: &lrng)),
                                        driftDuration: dur, swayPhase: ph))
            }
        }

        func spawnLantern(time: Float) {
            let lx = Float(Double.random(in: -6...6, using: &rng))
            let lz = Float(Double.random(in: -8 ... -2, using: &rng))
            let dur = Float(Double.random(in: 20...35, using: &rng))
            let ph  = Float(Double.random(in: 0...Float.pi*2, using: &rng))
            lanterns.append(Lantern(startX: lx, startY: 0.2, startZ: lz,
                                    born: time, driftDuration: dur, swayPhase: ph))
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

            // Remove expired lanterns
            lanterns.removeAll { t - $0.born > $0.driftDuration }

            // Camera slow pan
            let panAngle = sin(t * Float.pi * 2 / 30) * 0.35
            let camX = sin(panAngle) * 1.5
            let eye: SIMD3<Float>    = [camX, 3.0, 6.0]
            let center: SIMD3<Float> = [0, 2.0, -5.0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.05, far: 80)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([-0.3, 0.7, 0.5]), 0),
                sunColor:       SIMD4<Float>([0.55, 0.55, 0.75], 0),
                ambientColor:   SIMD4<Float>([0.06, 0.04, 0.14], t),
                fogParams:      SIMD4<Float>(25, 70, 0, 0),
                fogColor:       SIMD4<Float>([0.02, 0.03, 0.06], 0),
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

            // Lanterns + stars as glow / particles
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                let lanternVerts = buildBox(w: 0.3, h: 0.4, d: 0.3, color: [1,1,1,1])
                if let lbuf = makeVertexBuffer(lanternVerts, device: device) {
                    for ln in lanterns {
                        let age = t - ln.born
                        let progress = max(0, age / ln.driftDuration)
                        let lx = ln.startX + sin(age * 0.6 + ln.swayPhase) * 0.3
                        let ly = ln.startY + progress * 5.0
                        let lz = ln.startZ
                        let tilt = sin(age * 0.4 + ln.swayPhase) * 0.12
                        let model = m4Translation(lx, ly, lz) * m4RotZ(tilt)
                        let fadeIn: Float = age < 1.0 ? age : 1.0
                        let fadeOut: Float = progress > 0.85 ? (1.0 - progress) / 0.15 : 1.0
                        let alpha = fadeIn * fadeOut
                        encodeDraw(encoder: encoder, vertexBuffer: lbuf,
                                   vertexCount: lanternVerts.count, model: model,
                                   emissiveColor: [1.0, 0.62, 0.15] * alpha,
                                   emissiveMix: 1.0, opacity: alpha)
                    }
                }
            }

            // Stars and lantern glows as particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                for s in stars {
                    let tw = 0.7 + 0.3 * sin(t * 1.3 + s.phase)
                    let a = s.brightness * tw
                    particles.append(ParticleVertex3D(position: s.pos,
                                                      color: [a, a, a*0.95, a], size: 3))
                }
                // Lantern glow halos
                for ln in lanterns {
                    let age = t - ln.born
                    let progress = max(0, age / ln.driftDuration)
                    let lx = ln.startX + sin(age * 0.6 + ln.swayPhase) * 0.3
                    let ly = ln.startY + progress * 5.0
                    let lz = ln.startZ
                    let fadeIn: Float = age < 1.0 ? age : 1.0
                    let fadeOut: Float = progress > 0.85 ? (1.0 - progress) / 0.15 : 1.0
                    let pulse = 0.7 + 0.3 * sin(t * 2 + ln.swayPhase)
                    let a = fadeIn * fadeOut * pulse
                    particles.append(ParticleVertex3D(position: [lx, ly, lz],
                                                      color: [1.0, 0.65, 0.25, a * 0.5], size: 18))
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
        view.clearColor              = MTLClearColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.spawnLantern(time: t)
    }
}
