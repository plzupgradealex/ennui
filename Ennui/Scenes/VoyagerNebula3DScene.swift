// VoyagerNebula3DScene — Metal 3D nebula: gas clouds, drifting probe, stellar cores.
// Tap to pulse central light.

import SwiftUI
import MetalKit

struct VoyagerNebula3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        VoyagerNebula3DRepresentable(interaction: interaction)
    }
}

private struct VoyagerNebula3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {

        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:   MTLDepthStencilState?
        var depthROState: MTLDepthStencilState?

        struct DrawCall {
            var buffer: MTLBuffer; var count: Int
            var model: simd_float4x4
            var emissiveCol: SIMD3<Float>; var emissiveMix: Float; var opacity: Float = 1
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // Nebula cloud data
        struct CloudData {
            var buffer: MTLBuffer; var count: Int
            var basePos: SIMD3<Float>; var radius: Float
            var emissiveCol: SIMD3<Float>
            var opacity: Float
            var phase: Float; var driftSpeed: SIMD3<Float>
        }
        var clouds: [CloudData] = []

        // Stellar cores: (buffer, vertexCount, worldPos, emissiveColor, animPhase)
        var coreBuffers: [(MTLBuffer, Int, SIMD3<Float>, SIMD3<Float>, Float)] = []

        // Stars — precomputed per-star properties
        var starPositions:  [SIMD3<Float>] = []
        var starPhases:     [Float] = []
        var starBrightness: [Float] = []
        var starSizes:      [Float] = []
        var starWarmth:     [Float] = []

        // Tap
        var pulseT:      Float = -999
        var lastTapCount = 0
        var startTime:   CFTimeInterval = CACurrentMediaTime()
        var aspect:      Float = 1

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("VoyagerNebula3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                        emissiveCol: emissive, emissiveMix: mix))
        }

        private func buildScene() {
            // Sky sphere
            addOpaque(buildSphere(radius: 45, rings: 8, segments: 16,
                                  color: [0.006, 0.005, 0.025, 1]),
                      model: matrix_identity_float4x4)

            // Voyager probe — body + solar panels + antenna
            addOpaque(buildBox(w: 0.15, h: 0.08, d: 0.35, color: [0.55, 0.52, 0.48, 1]),
                      model: m4Translation(4, 1.5, -6),
                      emissive: [0.10, 0.08, 0.05], mix: 0.2)
            addOpaque(buildBox(w: 1.2, h: 0.04, d: 0.12, color: [0.35, 0.38, 0.42, 1]),
                      model: m4Translation(4, 1.5, -6),
                      emissive: [0.05, 0.08, 0.12], mix: 0.15)
            addOpaque(buildCylinder(radius: 0.05, height: 0.5, segments: 6,
                                    color: [0.45, 0.45, 0.50, 1]),
                      model: m4Translation(4, 1.7, -5.75) * m4RotX(.pi / 2),
                      emissive: [0.08, 0.08, 0.10], mix: 0.1)

            // Nebula clouds
            let palette: [(SIMD3<Float>, Float)] = [
                ([0.85, 0.42, 0.10], 1.4), ([0.72, 0.28, 0.06], 1.2),
                ([0.12, 0.52, 0.68], 1.5), ([0.08, 0.40, 0.60], 1.3),
                ([0.88, 0.52, 0.14], 1.1), ([0.62, 0.22, 0.08], 1.0),
                ([0.10, 0.45, 0.52], 1.2), ([0.75, 0.55, 0.18], 1.0),
            ]
            var rng = SplitMix64(seed: 4747)
            for i in 0..<18 {
                let (em, _) = palette[i % palette.count]
                let r  = Float(Double.random(in: 2.5...7.0,       using: &rng))
                let bx = Float(Double.random(in: -8...8,           using: &rng))
                let by = Float(Double.random(in: -4...4,           using: &rng))
                let bz = Float(Double.random(in: -8...8,           using: &rng))
                let op = Float(Double.random(in: 0.06...0.18,      using: &rng))
                let ph = Float(Double.random(in: 0...(2 * .pi),    using: &rng))
                let dx = Float(Double.random(in: -0.03...0.03,     using: &rng))
                let dy = Float(Double.random(in: -0.02...0.02,     using: &rng))
                let dz = Float(Double.random(in: -0.02...0.02,     using: &rng))
                let col = SIMD4<Float>(em.x * 0.6, em.y * 0.6, em.z * 0.6, 1)
                let verts = buildSphere(radius: 1, rings: 5, segments: 10, color: col)
                if let buf = makeVertexBuffer(verts, device: device) {
                    clouds.append(CloudData(buffer: buf, count: verts.count,
                                            basePos: [bx, by, bz], radius: r,
                                            emissiveCol: em, opacity: op, phase: ph,
                                            driftSpeed: [dx, dy, dz]))
                }
            }

            // Stellar cores
            let coreColors: [SIMD3<Float>] = [
                [1.2, 0.9, 0.4], [0.4, 1.1, 0.9], [1.0, 0.5, 0.8]
            ]
            let corePositions: [SIMD3<Float>] = [
                [0, 0, 0], [-3.5, 2, -2], [4, -1.5, -4]
            ]
            for (j, cpos) in corePositions.enumerated() {
                let col   = coreColors[j]
                let verts = buildSphere(radius: 0.15, rings: 6, segments: 10,
                                        color: SIMD4<Float>(col, 1))
                if let buf = makeVertexBuffer(verts, device: device) {
                    coreBuffers.append((buf, verts.count, cpos, col, Float(j) * 1.2))
                }
            }

            // Stars
            var rng2 = SplitMix64(seed: 4748)
            for _ in 0..<300 {
                let theta = Float(Double.random(in: 0...(2 * .pi), using: &rng2))
                let phi   = Float(Double.random(in: 0...(.pi),     using: &rng2))
                let r2    = Float(Double.random(in: 32...44,       using: &rng2))
                starPositions .append([r2*sin(phi)*cos(theta), r2*cos(phi), r2*sin(phi)*sin(theta)])
                starPhases    .append(Float(Double.random(in: 0...(2 * .pi), using: &rng2)))
                starBrightness.append(Float(Double.random(in: 0.08...0.65,   using: &rng2)))
                starSizes     .append(Float(Double.random(in: 1.5...5.5,     using: &rng2)))
                starWarmth    .append(Float(Double.random(in: 0...1,         using: &rng2)))
            }
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)
            let pulseAge = t - pulseT
            let pulseBoost: Float = pulseAge < 4 ? 2.0 * max(0, 1 - pulseAge / 1.5) : 0

            // Camera very slow orbit (180 s period)
            let camA = t * (2 * .pi / 180.0)
            let eye: SIMD3<Float> = [14 * sin(camA), 5, 14 * cos(camA)]
            let vp = m4Perspective(fovyRad: 58 * .pi / 180, aspect: aspect, near: 0.1, far: 130) *
                     m4LookAt(eye: eye, center: .zero, up: [0, 1, 0])

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(-0.4, -0.3, -0.7)), 0),
                sunColor:       SIMD4<Float>(0.7, 0.55, 0.35, 0),
                ambientColor:   SIMD4<Float>(0.05, 0.04, 0.10, t),
                fogParams:      SIMD4<Float>(40, 80, 0, 0),
                fogColor:       SIMD4<Float>(0.005, 0.004, 0.02, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(opaque)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque objects (sky sphere + probe parts)
            for dc in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: dc.buffer, vertexCount: dc.count,
                           model: dc.model, emissiveColor: dc.emissiveCol,
                           emissiveMix: dc.emissiveMix, opacity: dc.opacity)
            }

            // Alpha-blended pass: nebula clouds + stellar cores
            if let glow = glowPipeline {
                enc.setRenderPipelineState(glow)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

                // Nebula clouds — position, breathe, and drift animated
                for cloud in clouds {
                    let drift = cloud.driftSpeed * t
                    let breathe: Float = 1.0 + 0.05 * sin(t * 0.12 + cloud.phase)
                    let sway = SIMD3<Float>(0.3 * sin(t * 0.03 + cloud.phase),
                                           0.2 * cos(t * 0.025 + cloud.phase), 0)
                    let pos = cloud.basePos + drift + sway
                    let s   = cloud.radius * breathe
                    let model = m4Translation(pos.x, pos.y, pos.z) * m4Scale(s, s, s)
                    let em    = cloud.emissiveCol * (1 + pulseBoost * 0.3)
                    let op    = cloud.opacity * (1 + pulseBoost * 0.2)
                    encodeDraw(encoder: enc, vertexBuffer: cloud.buffer, vertexCount: cloud.count,
                               model: model, emissiveColor: em, emissiveMix: 0.85, opacity: op)
                }

                // Stellar cores + halos — pulse on tap
                for (buf, cnt, pos, col, ph) in coreBuffers {
                    let pulse: Float = 1.0 + 0.15 * sin(t * 0.12 + ph) + pulseBoost * 0.8
                    let coreModel = m4Translation(pos.x, pos.y, pos.z) *
                                    m4Scale(pulse, pulse, pulse)
                    let haloS: Float = pulse * 5
                    let haloModel = m4Translation(pos.x, pos.y, pos.z) *
                                    m4Scale(haloS, haloS, haloS)
                    let em = col * (1.2 + pulseBoost)
                    encodeDraw(encoder: enc, vertexBuffer: buf, vertexCount: cnt,
                               model: coreModel, emissiveColor: em, emissiveMix: 1.0, opacity: 0.95)
                    encodeDraw(encoder: enc, vertexBuffer: buf, vertexCount: cnt,
                               model: haloModel, emissiveColor: em * 0.5, emissiveMix: 1.0,
                               opacity: 0.08)
                }
            }

            // Star field particles
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []
                for i in starPositions.indices {
                    let tw    = 0.7 + 0.3 * sin(t * 0.5 + starPhases[i])
                    let alpha = starBrightness[i] * tw
                    let w     = starWarmth[i]
                    pv.append(ParticleVertex3D(
                        position: starPositions[i],
                        color: [0.85 + w * 0.15, 0.82 + w * 0.08, 1.0 - w * 0.2, alpha],
                        size: starSizes[i] * tw))
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
        v.clearColor = MTLClearColor(red: 0.006, green: 0.005, blue: 0.025, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.pulseT = Float(CACurrentMediaTime() - c.startTime)
    }
}
