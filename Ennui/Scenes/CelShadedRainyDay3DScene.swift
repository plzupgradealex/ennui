// CelShadedRainyDay3DScene — Metal 3D rainy day garden: ground, flowers, clouds, puddles, rain particles.
// Tap: pulse a random puddle (scale it up briefly).

import SwiftUI
import MetalKit

struct CelShadedRainyDay3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { CelShadedRainyDay3DRepresentable(interaction: interaction) }
}

private struct CelShadedRainyDay3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        struct DrawCall {
            var buf: MTLBuffer; var count: Int; var model: simd_float4x4
            var emissiveCol: SIMD3<Float> = .zero; var emissiveMix: Float = 0
            var opacity: Float = 1
        }

        var opaqueCalls:  [DrawCall] = []

        // Clouds: groups of sphere buffers + base positions + drift phase
        struct CloudGroup {
            var spheres: [(buf: MTLBuffer, count: Int, offset: SIMD3<Float>)]
            var basePos: SIMD3<Float>
            var driftPhase: Float
        }
        var clouds: [CloudGroup] = []

        // Puddles
        let puddlePositions: [SIMD3<Float>] = [
            [-3, 0, 1], [2, 0, 3], [0, 0, -2], [-5, 0, -3], [4, 0, -1]
        ]
        var puddleBufs:   [MTLBuffer] = []
        var puddleCounts: [Int]       = []
        var puddlePulseTimes: [Float] = Array(repeating: -999, count: 5)

        // Rain
        var rainPositions: [SIMD3<Float>] = []
        var rainPhases:    [Float]        = []
        var rainSpeeds:    [Float]        = []

        var tapPulseRng = SplitMix64(seed: 13)
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
            } catch { print("CelShadedRainyDay3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buf: buf, count: v.count, model: model,
                                        emissiveCol: emissive, emissiveMix: mix))
        }

        private func buildScene() {
            // Ground
            addOpaque(buildPlane(w: 20, d: 20, color: [0.35, 0.65, 0.25, 1]),
                      model: matrix_identity_float4x4)

            // 8 Flowers: stem + sphere head
            let flowerPositions: [SIMD3<Float>] = [
                [-3,0,0], [2,0,-1], [-1,0,3], [4,0,1], [-5,0,2],
                [0,0,-4], [3,0,-3], [-2,0,-2]
            ]
            let headColors: [SIMD4<Float>] = [
                [1.0, 0.20, 0.20, 1], [1.0, 0.55, 0.10, 1],
                [1.0, 0.92, 0.10, 1], [0.60, 0.10, 0.85, 1],
                [0.25, 0.45, 0.95, 1], [0.95, 0.40, 0.65, 1],
                [0.55, 0.10, 0.55, 1], [1.0, 0.70, 0.10, 1]
            ]
            for (i, pos) in flowerPositions.enumerated() {
                let stemV = buildCylinder(radius: 0.06, height: 0.7, segments: 8, color: [0.2, 0.65, 0.1, 1])
                addOpaque(stemV, model: m4Translation(pos.x, 0.35, pos.z))
                let headV = buildSphere(radius: 0.18, rings: 8, segments: 12, color: headColors[i])
                addOpaque(headV, model: m4Translation(pos.x, 0.78, pos.z))
            }

            // Puddles (flat boxes)
            let puddleColor: SIMD4<Float> = [0.40, 0.50, 0.65, 1]
            for _ in puddlePositions {
                let pv = buildBox(w: 0.8, h: 0.04, d: 0.55, color: puddleColor)
                guard let pb = makeVertexBuffer(pv, device: device) else { continue }
                puddleBufs.append(pb)
                puddleCounts.append(pv.count)
            }

            // Clouds
            var rng = SplitMix64(seed: 33)
            let cloudBases: [(SIMD3<Float>, Float)] = [
                (SIMD3<Float>( 0, 7, -8),  0.0),
                (SIMD3<Float>(-4, 5, -6),  1.2),
                (SIMD3<Float>( 5, 6, -10), 2.5),
            ]
            let puffOffsets: [[SIMD3<Float>]] = [
                [[-0.6,0,0], [0,0,0], [0.6,0,0], [0.3, 0.4, 0]],
                [[-0.5,0,0], [0.2,0,0], [0.7,0.2,0]],
                [[-0.7,0,0], [0,0,0], [0.6,0,0], [-0.2,0.35,0]],
            ]
            for (idx, (base, driftPhase)) in cloudBases.enumerated() {
                var spheres: [(buf: MTLBuffer, count: Int, offset: SIMD3<Float>)] = []
                let offsets = puffOffsets[idx]
                for off in offsets {
                    let r = Float(rng.nextDouble()) * 0.35 + 0.55
                    let sv = buildSphere(radius: r, rings: 8, segments: 12,
                                        color: SIMD4<Float>(0.88, 0.90, 0.95, 1))
                    if let sb = makeVertexBuffer(sv, device: device) {
                        spheres.append((buf: sb, count: sv.count, offset: off))
                    }
                }
                clouds.append(CloudGroup(spheres: spheres, basePos: base, driftPhase: driftPhase))
            }

            // Rain (250 drops)
            var rng2 = SplitMix64(seed: 77)
            for _ in 0..<250 {
                let x = Float(rng2.nextDouble()) * 18 - 9
                let z = Float(rng2.nextDouble()) * 18 - 9
                rainPositions.append(SIMD3<Float>(x, 0, z))
                rainPhases.append(Float(rng2.nextDouble()) * 9)
                rainSpeeds.append(Float(rng2.nextDouble()) * 3 + 3)
            }
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
            let driftX = sin(t * 2 * Float.pi / 30) * 1.5
            let eye = SIMD3<Float>(driftX, 2.5, 8.0)
            let proj = m4Perspective(fovyRad: 0.75, aspect: aspect, near: 0.1, far: 80)
            let viewM = m4LookAt(eye: eye, center: SIMD3<Float>(0, 1.0, 0), up: SIMD3<Float>(0, 1, 0))
            let vp = proj * viewM

            let sunDir = SIMD4<Float>(simd_normalize(SIMD3<Float>(0.2, 0.8, 0.5)), 0)
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   sunDir,
                sunColor:       SIMD4<Float>(0.85, 0.90, 0.95, 1),
                ambientColor:   SIMD4<Float>(0.45, 0.50, 0.55, t),
                fogParams:      SIMD4<Float>(18, 40, 0, 0),
                fogColor:       SIMD4<Float>(0.70, 0.80, 0.90, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setCullMode(.back)
            enc.setDepthStencilState(depthState)
            enc.setRenderPipelineState(opaque)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Static opaque geometry
            for dc in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: dc.buf, vertexCount: dc.count,
                           model: dc.model, emissiveColor: dc.emissiveCol, emissiveMix: dc.emissiveMix,
                           opacity: dc.opacity)
            }

            // Puddles with optional pulse scale
            for (i, pos) in puddlePositions.enumerated() {
                guard i < puddleBufs.count else { continue }
                let age   = t - puddlePulseTimes[i]
                let scale = 1 + 0.55 * max(0, 1 - age / 0.6)
                let model = m4Translation(pos.x, pos.y + 0.02, pos.z) * m4Scale(scale, 1, scale)
                encodeDraw(encoder: enc, vertexBuffer: puddleBufs[i], vertexCount: puddleCounts[i],
                           model: model, emissiveColor: SIMD3<Float>(0.3, 0.4, 0.6), emissiveMix: 0.15 * max(0, 1 - age / 0.6))
            }

            // Clouds (alpha-blended, drifting)
            enc.setRenderPipelineState(glow)
            enc.setDepthStencilState(depthROState)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            for cloud in clouds {
                let dx = sin(t * 0.08 + cloud.driftPhase) * 0.6
                for sphere in cloud.spheres {
                    let wp = cloud.basePos + sphere.offset + SIMD3<Float>(dx, 0, 0)
                    let model = m4Translation(wp.x, wp.y, wp.z)
                    encodeDraw(encoder: enc, vertexBuffer: sphere.buf, vertexCount: sphere.count,
                               model: model, opacity: 0.88)
                }
            }

            // Rain particles
            if let ppipe = particlePipeline {
                let fallRange: Float = 9
                var pv: [ParticleVertex3D] = []
                pv.reserveCapacity(rainPositions.count)
                for i in 0..<rainPositions.count {
                    let yOff = (t * rainSpeeds[i] + rainPhases[i]).truncatingRemainder(dividingBy: fallRange)
                    let y = 8 - yOff
                    let pos = SIMD3<Float>(rainPositions[i].x, y, rainPositions[i].z)
                    pv.append(ParticleVertex3D(
                        position: pos,
                        color: SIMD4<Float>(0.65, 0.75, 0.90, 0.55),
                        size: 2.0
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
        v.clearColor = MTLClearColor(red: 0.70, green: 0.80, blue: 0.90, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        let idx = Int(c.tapPulseRng.nextDouble() * Double(c.puddlePositions.count))
        c.puddlePulseTimes[idx] = t
    }
}
