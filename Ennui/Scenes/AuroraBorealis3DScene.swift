// AuroraBorealis3DScene — Aurora borealis over a frozen lake rendered in Metal (MTKView).
// Tap to trigger an aurora flare that brightens the curtains for ~4 seconds.
// No SceneKit — geometry built via Metal3DHelpers, aurora animated each frame.

import SwiftUI
import MetalKit

struct AuroraBorealis3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        AuroraBorealis3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct AuroraBorealis3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

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

        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // Aurora curtains — animated in draw()
        struct AuroraBand {
            var buffer:      MTLBuffer
            var count:       Int
            var emissiveCol: SIMD3<Float>
            var baseY:       Float
            var speed:       Float
            var freq:        Float
            var phase:       Float
            var amplitude:   Float
        }
        var auroraBands: [AuroraBand] = []

        // Particle data (pre-computed)
        var starPos:      [SIMD3<Float>] = []
        var starColor:    [SIMD4<Float>] = []
        var crystalPos:   [SIMD3<Float>] = []
        var crystalPhase: [Float]        = []

        // Tap / flare
        var flareT:      Float = -100
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
            } catch {
                print("AuroraBorealis3D pipeline error: \(error)")
            }
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

        private func addTransparent(_ v: [Vertex3D], model: simd_float4x4,
                                    emissive: SIMD3<Float>, mix: Float, opacity: Float) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            transparentCalls.append(DrawCall(buffer: buf, count: v.count,
                                              model: model, emissiveCol: emissive,
                                              emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            // Sky sphere
            addOpaque(buildSphere(radius: 42, rings: 6, segments: 14,
                                  color: [0.01, 0.02, 0.05, 1]),
                      model: matrix_identity_float4x4)

            // Frozen lake
            addOpaque(buildPlane(w: 28, d: 28, color: [0.50, 0.58, 0.70, 1]),
                      model: matrix_identity_float4x4,
                      emissive: [0.12, 0.16, 0.22], mix: 0.25)

            // Pine trees (25 trees)
            var rng = SplitMix64(seed: 8200)
            let coneCol:  SIMD4<Float> = [0.04, 0.12, 0.04, 1]
            let pTrunk:   SIMD4<Float> = [0.12, 0.08, 0.05, 1]
            for _ in 0..<25 {
                let tx = Float(Double.random(in: -14...14,   using: &rng))
                let tz = Float(Double.random(in: -12...(-5), using: &rng))
                let th = Float(Double.random(in:  2.5...5.0, using: &rng))
                addOpaque(buildCylinder(radius: 0.12, height: th * 0.35,
                                        segments: 6, color: pTrunk),
                          model: m4Translation(tx, th * 0.175, tz))
                addOpaque(buildCone(radius: th * 0.28, height: th,
                                    segments: 8, color: coneCol),
                          model: m4Translation(tx, th * 0.35, tz))
            }

            // Cabin at (-6, 0, -8)
            let wallCol: SIMD4<Float> = [0.22, 0.14, 0.08, 1]
            let roofCol: SIMD4<Float> = [0.18, 0.10, 0.06, 1]
            addOpaque(buildBox(w: 2.2, h: 1.6, d: 1.8, color: wallCol),
                      model: m4Translation(-6, 0.8, -8))
            addOpaque(buildPyramid(bw: 2.4, bd: 2.0, h: 1.0, color: roofCol),
                      model: m4Translation(-6, 1.6, -8))
            // Emissive cabin window
            let winE: SIMD3<Float> = [1.0, 0.7, 0.3]
            addTransparent(buildQuad(w: 0.35, h: 0.30, color: [1.0, 0.7, 0.3, 1]),
                            model: m4Translation(-5.0, 0.9, -7.1),
                            emissive: winE, mix: 1.0, opacity: 1.0)

            // Aurora bands — geometry built once, model recomputed in draw()
            struct BandSpec {
                let col: SIMD3<Float>
                let baseY: Float; let speed: Float; let freq: Float
                let phase: Float; let amp: Float
            }
            let bandSpecs: [BandSpec] = [
                BandSpec(col: [0.10, 0.90, 0.40], baseY: 10, speed: 0.40,
                         freq: 1.2, phase: 0.0, amp: 1.4),
                BandSpec(col: [0.45, 0.10, 0.85], baseY: 13, speed: 0.30,
                         freq: 0.8, phase: 1.6, amp: 1.8),
                BandSpec(col: [0.10, 0.70, 0.90], baseY: 16, speed: 0.55,
                         freq: 1.5, phase: 3.2, amp: 1.2),
                BandSpec(col: [0.20, 0.95, 0.60], baseY: 19, speed: 0.25,
                         freq: 0.6, phase: 4.8, amp: 2.0)
            ]
            let bandVerts = buildQuad(w: 1, h: 1, color: [1, 1, 1, 1])
            for spec in bandSpecs {
                guard let buf = makeVertexBuffer(bandVerts, device: device) else { continue }
                auroraBands.append(AuroraBand(
                    buffer: buf, count: bandVerts.count,
                    emissiveCol: spec.col,
                    baseY: spec.baseY, speed: spec.speed,
                    freq: spec.freq, phase: spec.phase, amplitude: spec.amp))
            }

            // Stars: 200 particles on sky hemisphere
            var rng2 = SplitMix64(seed: 8201)
            for _ in 0..<200 {
                let theta = Float(Double.random(in: 0...Double.pi,     using: &rng2))
                let phi   = Float(Double.random(in: 0...2*Double.pi,   using: &rng2))
                let r: Float = 38
                let sx = r * sin(theta) * cos(phi)
                let sy = r * cos(theta)
                let sz = r * sin(theta) * sin(phi)
                if sy < -2 { continue }
                let brightness = Float(Double.random(in: 0.5...1.0, using: &rng2))
                starPos.append([sx, sy, sz])
                starColor.append([brightness, brightness, brightness * 1.1, brightness])
            }

            // Ice crystal particles (30)
            var rng3 = SplitMix64(seed: 8202)
            for _ in 0..<30 {
                let cx = Float(Double.random(in: -10...10, using: &rng3))
                let cy = Float(Double.random(in:   0...3,  using: &rng3))
                let cz = Float(Double.random(in:  -8...6,  using: &rng3))
                crystalPos.append([cx, cy, cz])
                crystalPhase.append(Float(Double.random(in: 0...6.28, using: &rng3)))
            }
        }

        func handleTap() {
            flareT = Float(CACurrentMediaTime() - startTime)
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

            // Aurora flare boost
            let flareBoost = max(0, 1 - (t - flareT) / 4.0) * 2.5

            // Camera — slow orbit 160 s/rev
            let angle = t * (2 * Float.pi / 160.0)
            let eye: SIMD3<Float> = [18 * sin(angle), 6, 18 * cos(angle)]
            let center: SIMD3<Float> = [0, 4, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 52 * .pi / 180, aspect: aspect, near: 0.1, far: 100)
            let vp    = proj4 * view4

            let moonDir: SIMD3<Float> = simd_normalize([0.3, -0.8, -0.5])
            let moonCol: SIMD3<Float> = [0.35, 0.40, 0.60]
            let ambCol:  SIMD3<Float> = [0.04, 0.06, 0.12]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(moonDir, 0),
                sunColor:       SIMD4<Float>(moonCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(20, 60, 0, 0),
                fogColor:       SIMD4<Float>(0.01, 0.02, 0.04, 0),
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

            if let glow = glowPipeline {
                encoder.setRenderPipelineState(glow)
                encoder.setDepthStencilState(depthROState)

                // Static transparent calls (cabin window)
                for call in transparentCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }

                // Aurora bands — model updated each frame
                let auroraOpacity = min(1.0, 0.45 * (1 + flareBoost))
                for band in auroraBands {
                    let disp  = band.amplitude * sin(t * band.speed + band.phase)
                    let model = m4Translation(0, band.baseY + disp, -15)
                               * m4RotX(-0.3)
                               * m4Scale(30, 0.1, 1)
                    let boostedEmissive = band.emissiveCol * (1 + flareBoost * 0.6)
                    encodeDraw(encoder: encoder,
                               vertexBuffer: band.buffer, vertexCount: band.count,
                               model: model,
                               emissiveColor: boostedEmissive, emissiveMix: 0.9,
                               opacity: auroraOpacity)
                }
            }

            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Stars — twinkle
                for i in starPos.indices {
                    let twinkle = 0.6 + 0.4 * abs(sin(t * 0.8 + Float(i) * 0.37))
                    var col = starColor[i]
                    col.w *= twinkle
                    particles.append(ParticleVertex3D(position: starPos[i], color: col, size: 3))
                }

                // Ice crystals drifting
                for i in crystalPos.indices {
                    let ph   = crystalPhase[i]
                    let base = crystalPos[i]
                    let wx = base.x + 0.4 * sin(t * 0.2 + ph)
                    let wy = base.y + 0.15 * sin(t * 0.5 + ph * 1.4)
                    let wz = base.z + 0.3 * cos(t * 0.18 + ph)
                    let alpha = min(1.0, Float(0.55 + 0.15 * Double(flareBoost)))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [0.85, 0.92, 1.0, alpha], size: 5))
                }

                if !particles.isEmpty,
                   let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.clearColor               = MTLClearColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
