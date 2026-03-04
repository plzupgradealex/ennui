// AncientRuins3DScene — Metal 3D ancient ruins at night with aurora. Tap to spike fireflies.

import SwiftUI
import MetalKit

struct AncientRuins3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { AncientRuins3DRepresentable(interaction: interaction) }
}

// MARK: - NSViewRepresentable

private struct AncientRuins3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // MARK: Coordinator / Renderer

    final class Coordinator: NSObject, MTKViewDelegate {

        // MARK: Metal core
        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        // MARK: Scene geometry
        struct DrawCall {
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []  // aurora bands

        // MARK: Aurora bands (parameters for animated draw)
        struct AuroraBand {
            var buffer:  MTLBuffer
            var count:   Int
            var yBase:   Float
            var color:   SIMD3<Float>
            var freq:    Float
            var speed:   Float
            var phase:   Float
            var opacity: Float
        }
        var auroraBands: [AuroraBand] = []

        // MARK: Firefly particles
        struct FireflyData {
            var basePos: SIMD3<Float>
            var phase:   Float
            var speed:   Float
        }
        var fireflies:    [FireflyData] = []
        var fireflyBoost: Float = 0.0
        var boostDecayT:  Float = -999

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        // MARK: - Init

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch {
                print("AncientRuins3D pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build scene geometry

        private func buildScene() {
            // Sky sphere (dark midnight blue, inside-out)
            let skyCol: SIMD4<Float> = [0.01, 0.02, 0.08, 1]
            addOpaque(buildSphere(radius: 42, rings: 8, segments: 16, color: skyCol),
                      model: m4Scale(-1, 1, -1))

            // Ground (dark stone gray)
            let stoneCol: SIMD4<Float> = [0.09, 0.09, 0.10, 1]
            addOpaque(buildPlane(w: 30, d: 30, color: stoneCol),
                      model: matrix_identity_float4x4)

            // Mountain silhouettes (dark boxes far in background)
            let mtCol: SIMD4<Float> = [0.05, 0.05, 0.07, 1]
            let mountains: [(Float, Float, Float, Float, Float, Float)] = [
                (-14,  3, -22, 10, 6, 4),
                (  0,  4, -24, 12, 8, 4),
                ( 14,  3, -22, 10, 6, 4),
                ( -8,  2, -20,  8, 4, 3),
                (  8,  2, -20,  8, 4, 3),
            ]
            for (mx, my, mz, mw, mh, md) in mountains {
                addOpaque(buildBox(w: mw, h: mh, d: md, color: mtCol),
                          model: m4Translation(mx, my, mz))
            }

            // Stone columns (7: some full, some broken)
            let colCol: SIMD4<Float> = [0.18, 0.17, 0.16, 1]
            struct ColSpec { let x, z: Float; let h: Float; let broken: Bool }
            let colSpecs: [ColSpec] = [
                ColSpec(x: -5.0, z: -6.0, h: 3.5, broken: false),
                ColSpec(x: -2.5, z: -6.0, h: 3.5, broken: false),
                ColSpec(x:  0.0, z: -6.0, h: 2.1, broken: true),
                ColSpec(x:  2.5, z: -6.0, h: 3.5, broken: false),
                ColSpec(x:  5.0, z: -6.0, h: 3.5, broken: false),
                ColSpec(x: -6.5, z: -2.0, h: 1.4, broken: true),
                ColSpec(x:  6.5, z: -2.0, h: 2.8, broken: false),
            ]
            for col in colSpecs {
                addOpaque(buildCylinder(radius: 0.28, height: col.h, segments: 10, color: colCol),
                          model: m4Translation(col.x, col.h / 2, col.z))
                if !col.broken {
                    // Capital block on top
                    addOpaque(buildBox(w: 0.65, h: 0.18, d: 0.65, color: colCol),
                              model: m4Translation(col.x, col.h + 0.09, col.z))
                }
            }

            // Stone lintel blocks across column tops (front row)
            let lintelCol: SIMD4<Float> = [0.16, 0.15, 0.14, 1]
            addOpaque(buildBox(w: 2.65, h: 0.22, d: 0.55, color: lintelCol),
                      model: m4Translation(-3.75, 3.70, -6.0))
            addOpaque(buildBox(w: 2.65, h: 0.22, d: 0.55, color: lintelCol),
                      model: m4Translation( 3.75, 3.70, -6.0))
            // Fallen lintel
            addOpaque(buildBox(w: 2.4, h: 0.22, d: 0.55, color: lintelCol),
                      model: m4Translation(-1.0, 0.11, -4.5) * m4RotY(0.4))

            // Rubble blocks scattered on ground
            let rubbleCol: SIMD4<Float> = [0.15, 0.14, 0.13, 1]
            let rubbles: [(Float, Float, Float, Float)] = [
                (-4.0, 0.15, -3.0, 0.6), (3.5, 0.12, -2.5, 0.5),
                ( 1.5, 0.18, -1.0, 0.7), (-1.5, 0.10, -4.0, 0.4),
                ( 5.5, 0.14, -4.5, 0.55),
            ]
            for (rx, ry, rz, rs) in rubbles {
                addOpaque(buildBox(w: rs, h: rs * 0.6, d: rs * 0.8, color: rubbleCol),
                          model: m4Translation(rx, ry, rz) * m4RotY(rx * 0.5))
            }

            // Aurora bands (large translucent quads, animated in draw)
            struct AuroraSpec {
                let yBase: Float; let col: SIMD3<Float>
                let freq: Float; let speed: Float; let phase: Float; let opacity: Float
            }
            let auroraSpecs: [AuroraSpec] = [
                AuroraSpec(yBase: 14, col: [0.10, 0.80, 0.30], freq: 0.18, speed: 0.35, phase: 0.0, opacity: 0.30),
                AuroraSpec(yBase: 17, col: [0.50, 0.10, 0.75], freq: 0.22, speed: 0.28, phase: 1.2, opacity: 0.25),
                AuroraSpec(yBase: 12, col: [0.05, 0.70, 0.70], freq: 0.15, speed: 0.40, phase: 2.5, opacity: 0.22),
                AuroraSpec(yBase: 20, col: [0.20, 0.60, 0.40], freq: 0.12, speed: 0.20, phase: 3.8, opacity: 0.18),
                AuroraSpec(yBase: 11, col: [0.60, 0.15, 0.55], freq: 0.25, speed: 0.45, phase: 5.1, opacity: 0.20),
            ]
            for spec in auroraSpecs {
                let quadCol = SIMD4<Float>(spec.col.x, spec.col.y, spec.col.z, spec.opacity)
                let verts = buildQuad(w: 40, h: 6, color: quadCol)
                if let buf = makeVertexBuffer(verts, device: device) {
                    auroraBands.append(AuroraBand(
                        buffer:  buf,
                        count:   verts.count,
                        yBase:   spec.yBase,
                        color:   spec.col,
                        freq:    spec.freq,
                        speed:   spec.speed,
                        phase:   spec.phase,
                        opacity: spec.opacity
                    ))
                }
            }

            // Fireflies (50, warm yellow-green, drifting)
            var rng = SplitMix64(seed: 4455)
            for _ in 0..<50 {
                let fx = Float(Double.random(in: -7...7, using: &rng))
                let fy = Float(Double.random(in: 0.3...3.5, using: &rng))
                let fz = Float(Double.random(in: -7...1, using: &rng))
                let ph = Float(Double.random(in: 0...2*Double.pi, using: &rng))
                let sp = Float(Double.random(in: 0.6...1.8, using: &rng))
                fireflies.append(FireflyData(basePos: [fx, fy, fz], phase: ph, speed: sp))
            }
        }

        private func addOpaque(_ verts: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: verts.count,
                                        model: model,
                                        emissiveCol: .zero, emissiveMix: 0))
        }

        // MARK: - Tap

        func handleTap() {
            fireflyBoost = 3.0
            boostDecayT  = Float(CACurrentMediaTime() - startTime)
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable  = view.currentDrawable,
                  let rpDesc    = view.currentRenderPassDescriptor,
                  let cmdBuf    = commandQueue.makeCommandBuffer(),
                  let encoder   = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Firefly boost decay
            let boostAge = t - boostDecayT
            let currentBoost: Float
            if boostAge >= 0 && boostAge < 5.0 {
                currentBoost = 1.0 + 2.0 * max(0, 1 - boostAge / 5.0)
            } else {
                currentBoost = 1.0
            }

            // Camera: elevated, angled at ruins, slow orbit (100 s/rev)
            let orbitA = t * (2 * Float.pi / 100.0)
            let orbitR: Float = 13.0, orbitY: Float = 7.0
            let eye: SIMD3<Float> = [orbitR * sin(orbitA), orbitY, orbitR * cos(orbitA)]
            let view4 = m4LookAt(eye: eye, center: [0, 1.5, -4], up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 50 * Float.pi / 180, aspect: aspect, near: 0.1, far: 90)
            let vp    = proj4 * view4

            // Starlight / ambient
            let starDir = simd_normalize(SIMD3<Float>(-0.4, -0.9, -0.3))
            let starCol = SIMD3<Float>(0.25, 0.28, 0.45)
            let ambCol  = SIMD3<Float>(0.06, 0.06, 0.12)

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(starDir, 0),
                sunColor:       SIMD4<Float>(starCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(15, 45, 0, 0),
                fogColor:       SIMD4<Float>(0.01, 0.01, 0.04, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque pass
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Aurora bands (translucent, animated wave displacement)
            if let glowPL = glowPipeline {
                encoder.setRenderPipelineState(glowPL)
                encoder.setDepthStencilState(depthROState)

                for band in auroraBands {
                    // Wave: y-displacement = sin(t * speed + phase), slight tilt via RotX
                    let wave  = sin(t * band.speed + band.phase) * 1.5
                    let tilt  = sin(t * band.freq  + band.phase) * 0.08
                    let model = m4Translation(0, band.yBase + wave, -20) * m4RotX(tilt)
                    let pulse = 0.7 + 0.3 * sin(t * band.speed * 1.3 + band.phase)
                    encodeDraw(encoder: encoder,
                               vertexBuffer: band.buffer, vertexCount: band.count,
                               model: model,
                               emissiveColor: band.color * pulse,
                               emissiveMix: 0.85,
                               opacity: band.opacity * pulse)
                }
            }

            // Firefly particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                for ff in fireflies {
                    let blink = max(0, sin(t * ff.speed + ff.phase))
                    if blink < 0.08 { continue }
                    let wx = ff.basePos.x + 0.5 * sin(t * ff.speed * 0.7 + ff.phase)
                    let wy = ff.basePos.y + 0.25 * sin(t * ff.speed * 1.1 + ff.phase * 1.4)
                    let wz = ff.basePos.z + 0.5 * cos(t * ff.speed * 0.6 + ff.phase * 0.8)
                    let brightness = blink * currentBoost
                    let col: SIMD4<Float> = [0.75 * brightness, 0.92 * brightness,
                                             0.35 * brightness, min(1, blink * 0.9)]
                    particles.append(ParticleVertex3D(position: [wx, wy, wz], color: col, size: 7))
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
        view.clearColor               = MTLClearColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1)
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
