// GouraudSolarSystem3DMetalScene — Retro Gouraud-shaded solar system orrery.
// Camera locked to Earth's orbit facing the sun. Six planets on circular paths,
// a glowing star at centre, 150 background star particles.
// Tap to pulse all planets with a gentle glow shimmer.
// No SceneKit — geometry built via Metal3DHelpers.

import SwiftUI
import MetalKit

struct GouraudSolarSystem3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        GouraudSolarSystem3DMetalRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct GouraudSolarSystem3DMetalRepresentable: NSViewRepresentable {
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

        // Static geometry
        var starCall: DrawCall?
        var starHaloCall: DrawCall?

        struct PlanetSpec {
            var call: DrawCall
            var orbitRadius: Float
            var orbitSpeed: Float    // radians per second
            var selfRotSpeed: Float
            var startAngle: Float
            var ringCall: DrawCall?
            var ringTiltX: Float
            var ringTiltZ: Float
        }
        var planets: [PlanetSpec] = []

        // Background star particles (static positions)
        var bgStarPos: [SIMD3<Float>] = []
        var bgStarBright: [Float] = []
        var bgStarPhase: [Float] = []

        // Earth index for camera lock
        let earthIndex = 2

        var glowBoostT: Float = -100
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
                print("GouraudSolarSystem3DMetal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build

        private func buildScene() {
            // Central star — fully emissive warm sphere
            let starVerts = buildSphere(radius: 1.2, rings: 10, segments: 14,
                                        color: [1.0, 0.82, 0.30, 1])
            if let buf = makeVertexBuffer(starVerts, device: device) {
                starCall = DrawCall(buffer: buf, count: starVerts.count,
                                    model: matrix_identity_float4x4,
                                    emissiveCol: [1.2, 0.70, 0.20], emissiveMix: 1.0)
            }

            // Star halo — large translucent glow
            let haloVerts = buildSphere(radius: 2.8, rings: 6, segments: 10,
                                        color: [1.0, 0.70, 0.25, 1])
            if let buf = makeVertexBuffer(haloVerts, device: device) {
                starHaloCall = DrawCall(buffer: buf, count: haloVerts.count,
                                        model: matrix_identity_float4x4,
                                        emissiveCol: [1.0, 0.55, 0.15], emissiveMix: 0.9,
                                        opacity: 0.10)
            }

            // Planet configs: radius, color, orbitRadius, orbitPeriod, hasRing
            struct PlanetCfg {
                let radius: Float; let color: SIMD4<Float>
                let orbitR: Float; let period: Float
                let hasRing: Bool; let ringScale: Float
            }
            let configs: [PlanetCfg] = [
                PlanetCfg(radius: 0.35, color: [0.50, 0.55, 0.65, 1],
                          orbitR: 3.5,  period: 18,  hasRing: false, ringScale: 0),
                PlanetCfg(radius: 0.55, color: [0.65, 0.30, 0.20, 1],
                          orbitR: 5.5,  period: 28,  hasRing: false, ringScale: 0),
                // Earth (index 2) — camera will follow this
                PlanetCfg(radius: 0.45, color: [0.20, 0.50, 0.55, 1],
                          orbitR: 7.5,  period: 40,  hasRing: false, ringScale: 0),
                PlanetCfg(radius: 0.70, color: [0.75, 0.65, 0.38, 1],
                          orbitR: 10.0, period: 55,  hasRing: true,  ringScale: 1.8),
                PlanetCfg(radius: 0.30, color: [0.60, 0.78, 0.95, 1],
                          orbitR: 13.0, period: 75,  hasRing: false, ringScale: 0),
                PlanetCfg(radius: 0.25, color: [0.50, 0.40, 0.60, 1],
                          orbitR: 16.0, period: 100, hasRing: false, ringScale: 0),
            ]

            var rng = SplitMix64(seed: 2222)

            for cfg in configs {
                let verts = buildSphere(radius: cfg.radius, rings: 6, segments: 8,
                                        color: cfg.color)
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }

                let startAngle = Float(Double.random(in: 0...(2 * .pi), using: &rng))
                let orbitSpeed = (2 * Float.pi) / cfg.period

                // Build ring as a flattened cylinder (torus approximation)
                var ringCall: DrawCall? = nil
                if cfg.hasRing {
                    let ringVerts = buildCylinder(radius: cfg.radius * cfg.ringScale,
                                                  height: cfg.radius * 0.08,
                                                  segments: 16,
                                                  color: [cfg.color.x * 0.8,
                                                          cfg.color.y * 0.8,
                                                          cfg.color.z * 0.7, 0.6])
                    if let rbuf = makeVertexBuffer(ringVerts, device: device) {
                        ringCall = DrawCall(buffer: rbuf, count: ringVerts.count,
                                            model: matrix_identity_float4x4,
                                            emissiveCol: .zero, emissiveMix: 0, opacity: 0.6)
                    }
                }

                planets.append(PlanetSpec(
                    call: DrawCall(buffer: buf, count: verts.count,
                                   model: matrix_identity_float4x4,
                                   emissiveCol: .zero, emissiveMix: 0),
                    orbitRadius: cfg.orbitR,
                    orbitSpeed: orbitSpeed,
                    selfRotSpeed: Float(Double.random(in: 0.8...2.0, using: &rng)),
                    startAngle: startAngle,
                    ringCall: ringCall,
                    ringTiltX: Float.pi / 6,
                    ringTiltZ: Float.pi / 10
                ))
            }

            // Background stars
            for _ in 0..<150 {
                let x = Float(Double.random(in: -50...50, using: &rng))
                let y = Float(Double.random(in: -30...30, using: &rng))
                let z = Float(Double.random(in: -60 ... -15, using: &rng))
                bgStarPos.append([x, y, z])
                bgStarBright.append(Float(Double.random(in: 0.5...1.0, using: &rng)))
                bgStarPhase.append(Float(Double.random(in: 0...6.28, using: &rng)))
            }
        }

        func handleTap() {
            glowBoostT = Float(CACurrentMediaTime() - startTime)
        }

        // MARK: - MTKViewDelegate

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
            let glowBoost = max(0, 1 - (t - glowBoostT) / 2.5) * 1.2

            // Earth position — camera is locked behind Earth facing the sun
            let earthSpec = planets[earthIndex]
            let eAngle = earthSpec.startAngle + earthSpec.orbitSpeed * t
            let ex = earthSpec.orbitRadius * cos(eAngle)
            let ez = earthSpec.orbitRadius * sin(eAngle)

            // Camera slightly behind and above Earth, looking at origin (sun)
            let camOffset: SIMD3<Float> = [cos(eAngle) * 3.0, 3.5, sin(eAngle) * 3.0]
            let eye: SIMD3<Float> = [ex + camOffset.x, camOffset.y, ez + camOffset.z]
            let center: SIMD3<Float> = [0, 0, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect, near: 0.1, far: 120)
            let vp = proj4 * view4

            // Star is the main light source
            let sunDir: SIMD3<Float> = simd_normalize(-eye)
            let sunCol: SIMD3<Float> = [1.0, 0.85, 0.55]
            let ambCol: SIMD3<Float> = [0.06, 0.05, 0.10]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(30, 80, 0, 0),
                fogColor:       SIMD4<Float>(0.0, 0.0, 0.02, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Draw star
            if let sc = starCall {
                let pulse = 1.0 + 0.06 * sin(t * 1.2)
                let starModel = m4Scale(pulse, pulse, pulse)
                encodeDraw(encoder: encoder,
                           vertexBuffer: sc.buffer, vertexCount: sc.count,
                           model: starModel,
                           emissiveColor: sc.emissiveCol, emissiveMix: sc.emissiveMix)
            }

            // Draw planets (opaque)
            for spec in planets {
                let angle = spec.startAngle + spec.orbitSpeed * t
                let px = spec.orbitRadius * cos(angle)
                let pz = spec.orbitRadius * sin(angle)
                let selfRot = m4RotY(spec.selfRotSpeed * t)
                let shimmer = 1.0 + glowBoost * 0.15
                let planetModel = m4Translation(px, 0, pz) * selfRot * m4Scale(shimmer, shimmer, shimmer)

                encodeDraw(encoder: encoder,
                           vertexBuffer: spec.call.buffer, vertexCount: spec.call.count,
                           model: planetModel,
                           emissiveColor: spec.call.emissiveCol + [0.15, 0.10, 0.04] * glowBoost,
                           emissiveMix: glowBoost * 0.3)

                // Ring
                if let ring = spec.ringCall {
                    let ringModel = m4Translation(px, 0, pz) * m4RotX(spec.ringTiltX) * m4RotZ(spec.ringTiltZ)
                    encodeDraw(encoder: encoder,
                               vertexBuffer: ring.buffer, vertexCount: ring.count,
                               model: ringModel,
                               emissiveColor: ring.emissiveCol, emissiveMix: ring.emissiveMix,
                               opacity: ring.opacity)
                }
            }

            // Transparent: star halo
            if let glow = glowPipeline, let halo = starHaloCall {
                encoder.setRenderPipelineState(glow)
                encoder.setDepthStencilState(depthROState)
                let pulse = 0.10 + 0.04 * sin(t * 0.8)
                encodeDraw(encoder: encoder,
                           vertexBuffer: halo.buffer, vertexCount: halo.count,
                           model: halo.model,
                           emissiveColor: halo.emissiveCol, emissiveMix: halo.emissiveMix,
                           opacity: pulse)
            }

            // Background star particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for i in bgStarPos.indices {
                    let pos = bgStarPos[i]
                    let b = bgStarBright[i] * (0.7 + 0.3 * abs(sin(t * 0.3 + bgStarPhase[i])))
                    let blueShift = Float(0.05) * bgStarPhase[i].truncatingRemainder(dividingBy: 1)
                    particles.append(ParticleVertex3D(
                        position: pos,
                        color: [b, b, min(1, b + blueShift), min(1, b * 0.9)],
                        size: 3))
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
        view.clearColor               = MTLClearColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1)
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
