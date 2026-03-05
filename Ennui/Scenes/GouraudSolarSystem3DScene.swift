// GouraudSolarSystem3DScene — Metal 3D solar system: central star, orbiting planets, star-field particles.
// Tap: shimmer pulse on all planets; every 5th tap adds a new planet.

import SwiftUI
import MetalKit

struct GouraudSolarSystem3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { GouraudSolarSystem3DRepresentable(interaction: interaction) }
}

private struct GouraudSolarSystem3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        struct PlanetData {
            var buf: MTLBuffer; var count: Int
            var orbitRadius: Float; var period: Float
            var color: SIMD4<Float>; var emissiveCol: SIMD3<Float>
            var ringBuf: MTLBuffer?; var ringCount: Int
        }

        var starBuf: MTLBuffer?
        var starCount = 0
        var planets: [PlanetData] = []

        var bgStarPositions:  [SIMD3<Float>] = []
        var bgStarBrightness: [Float] = []
        var bgStarSizes:      [Float] = []

        var shimmerT: Float = -999
        var nextOrbitRadius: Float = 18.0
        var tapMod5Count = 0
        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        override init() {
            device = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("GouraudSolarSystem3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func buildScene() {
            let starVerts = buildSphere(radius: 1.2, rings: 16, segments: 24,
                                        color: SIMD4<Float>(1.0, 0.85, 0.3, 1))
            starBuf = makeVertexBuffer(starVerts, device: device)
            starCount = starVerts.count

            let configs: [(orbitR: Float, size: Float, period: Float, color: SIMD4<Float>, ring: Bool)] = [
                (3.5,  0.35, 18,   [0.50, 0.55, 0.65, 1], false),
                (5.5,  0.55, 28,   [0.65, 0.30, 0.20, 1], false),
                (7.5,  0.45, 40,   [0.20, 0.50, 0.55, 1], true),
                (10.0, 0.70, 55,   [0.75, 0.65, 0.38, 1], true),
                (13.0, 0.30, 75,   [0.60, 0.78, 0.95, 1], false),
                (16.0, 0.25, 100,  [0.50, 0.40, 0.60, 1], false),
            ]
            for cfg in configs {
                let verts = buildSphere(radius: cfg.size, rings: 12, segments: 16, color: cfg.color)
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                let ec = SIMD3<Float>(cfg.color.x, cfg.color.y, cfg.color.z) * 0.35
                var ringBuf: MTLBuffer? = nil
                var ringCount = 0
                if cfg.ring {
                    let rc: SIMD4<Float> = [cfg.color.x * 0.85, cfg.color.y * 0.85, cfg.color.z * 0.7, 0.65]
                    let rv = buildCylinder(radius: cfg.size * 1.85, height: 0.04, segments: 24, color: rc)
                    ringBuf   = makeVertexBuffer(rv, device: device)
                    ringCount = rv.count
                }
                planets.append(PlanetData(buf: buf, count: verts.count,
                                          orbitRadius: cfg.orbitR, period: cfg.period,
                                          color: cfg.color, emissiveCol: ec,
                                          ringBuf: ringBuf, ringCount: ringCount))
            }

            var rng = SplitMix64(seed: 99)
            for _ in 0..<200 {
                let theta = Float(rng.nextDouble()) * 2 * Float.pi
                let phi   = Float(rng.nextDouble()) * Float.pi
                let r     = Float(rng.nextDouble()) * 10 + 30
                bgStarPositions.append(SIMD3<Float>(
                    r * sin(phi) * cos(theta),
                    r * sin(phi) * sin(theta),
                    r * cos(phi)
                ))
                bgStarBrightness.append(Float(rng.nextDouble()) * 0.6 + 0.4)
                bgStarSizes.append(Float(rng.nextDouble()) * 2.0 + 1.5)
            }
        }

        func addPlanet() {
            let r = nextOrbitRadius
            let period = r * 7.0
            var rng = SplitMix64(seed: UInt64(r * 137))
            let c = SIMD4<Float>(Float(rng.nextDouble()) * 0.6 + 0.35,
                                 Float(rng.nextDouble()) * 0.6 + 0.25,
                                 Float(rng.nextDouble()) * 0.6 + 0.30, 1)
            let verts = buildSphere(radius: 0.32, rings: 12, segments: 16, color: c)
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            let ec = SIMD3<Float>(c.x, c.y, c.z) * 0.25
            planets.append(PlanetData(buf: buf, count: verts.count,
                                      orbitRadius: r, period: period,
                                      color: c, emissiveCol: ec,
                                      ringBuf: nil, ringCount: 0))
            nextOrbitRadius += 2.5
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque = opaquePipeline,
                  let glow = glowPipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)
            let camAngle = t * 2 * Float.pi / 80
            let eye = SIMD3<Float>(20 * cos(camAngle), 7, 20 * sin(camAngle))
            let proj = m4Perspective(fovyRad: 0.65, aspect: aspect, near: 0.1, far: 200)
            let viewM = m4LookAt(eye: eye, center: .zero, up: SIMD3<Float>(0, 1, 0))
            let vp = proj * viewM

            let shimmerAge  = t - shimmerT
            let shimmerBoost = max(0, 1 - shimmerAge / 1.5)

            let sunDir = SIMD4<Float>(simd_normalize(SIMD3<Float>(0.4, 1.0, 0.3)), 0)
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   sunDir,
                sunColor:       SIMD4<Float>(1.0, 0.95, 0.8, 1),
                ambientColor:   SIMD4<Float>(0.03, 0.03, 0.08, t),
                fogParams:      SIMD4<Float>(60, 130, 0, 0),
                fogColor:       SIMD4<Float>(0, 0, 0.01, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setCullMode(.back)
            enc.setDepthStencilState(depthState)
            enc.setRenderPipelineState(opaque)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Central star (emissive)
            if let sb = starBuf {
                encodeDraw(encoder: enc, vertexBuffer: sb, vertexCount: starCount,
                           model: matrix_identity_float4x4,
                           emissiveColor: SIMD3<Float>(1.0, 0.65, 0.15), emissiveMix: 0.95)
            }

            // Planets
            for pd in planets {
                let angle = t * 2 * Float.pi / pd.period
                let model = m4Translation(pd.orbitRadius * cos(angle), 0, pd.orbitRadius * sin(angle))
                let emMix = 0.08 + shimmerBoost * 0.85
                encodeDraw(encoder: enc, vertexBuffer: pd.buf, vertexCount: pd.count,
                           model: model, emissiveColor: pd.emissiveCol, emissiveMix: emMix)
            }

            // Rings (alpha-blended)
            enc.setRenderPipelineState(glow)
            enc.setDepthStencilState(depthROState)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            for pd in planets {
                guard let rb = pd.ringBuf else { continue }
                let angle = t * 2 * Float.pi / pd.period
                let model = m4Translation(pd.orbitRadius * cos(angle), 0, pd.orbitRadius * sin(angle))
                            * m4RotX(0.35)
                encodeDraw(encoder: enc, vertexBuffer: rb, vertexCount: pd.ringCount,
                           model: model, opacity: 0.7)
            }

            // Background star particles
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []
                pv.reserveCapacity(bgStarPositions.count)
                for i in 0..<bgStarPositions.count {
                    let b = bgStarBrightness[i]
                    pv.append(ParticleVertex3D(
                        position: bgStarPositions[i],
                        color: SIMD4<Float>(b, b * 0.95, b * 0.85, 1),
                        size: bgStarSizes[i]
                    ))
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
        v.delegate = context.coordinator
        v.colorPixelFormat = .bgra8Unorm
        v.depthStencilPixelFormat = .depth32Float
        v.clearColor = MTLClearColor(red: 0, green: 0, blue: 0.02, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.shimmerT = Float(CACurrentMediaTime() - c.startTime)
        c.tapMod5Count += 1
        if c.tapMod5Count % 5 == 0 {
            c.addPlanet()
        }
    }
}
