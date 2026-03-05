// FloatingKingdom3DScene — Floating sky island with crystalline spires, waterfall, golden motes.
// Blue sky, orbiting camera, bobbing island, cloud puffs below.
// Tap to pulse energy through the spires.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct FloatingKingdom3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        FloatingKingdom3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct FloatingKingdom3DRepresentable: NSViewRepresentable {
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
        // Static opaque calls (always same transform)
        var opaqueCalls: [DrawCall] = []
        // Island pieces (need islandY applied at draw time)
        struct IslandPiece {
            var buffer: MTLBuffer; var count: Int; var localModel: simd_float4x4
        }
        var islandPieces: [IslandPiece] = []
        // Spire definitions (corners + center, rendered with glow)
        struct Spire {
            var buffer: MTLBuffer; var count: Int; var localModel: simd_float4x4
            var baseEmissive: SIMD3<Float>
        }
        var spires: [Spire] = []
        // Cloud puffs
        struct Cloud {
            var buffer: MTLBuffer; var count: Int; var pos: SIMD3<Float>; var driftSpeed: Float
        }
        var clouds: [Cloud] = []
        // Waterfall plane (glow)
        var waterfallBuf: MTLBuffer?
        var waterfallCount: Int = 0

        // Waterfall drops
        struct WaterfallDrop { var speed: Float; var phase: Float; var xOff: Float }
        var waterfallDrops: [WaterfallDrop] = []

        // Golden motes
        struct GoldenMote { var baseX: Float; var baseZ: Float; var phase: Float }
        var goldenMotes: [GoldenMote] = []

        // Spire pulse
        var spirePulseT: Float = -999

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
            } catch { print("FloatingKingdom3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addStaticOpaque(_ v: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                        emissiveCol: .zero, emissiveMix: 0))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 12000)

            // Island top (bobs; drawn at runtime with islandY)
            let topV = buildBox(w: 8, h: 1.5, d: 8, color: [0.28, 0.55, 0.22, 1])
            if let b = makeVertexBuffer(topV, device: device) {
                islandPieces.append(IslandPiece(buffer: b, count: topV.count,
                                                 localModel: matrix_identity_float4x4))
            }
            // Rocky underside
            let underV = buildBox(w: 7, h: 2, d: 7, color: [0.40, 0.35, 0.28, 1])
            if let b = makeVertexBuffer(underV, device: device) {
                islandPieces.append(IslandPiece(buffer: b, count: underV.count,
                                                 localModel: m4Translation(0, -1.8, 0)))
            }
            // 6 jagged underside chunks
            let chunkOffsets: [(Float, Float, Float)] = [
                (-2, -3.2, -1.5), (2, -3.5, 1), (-1, -4, 2), (1.5, -3.8, -2),
                (-2.5, -3.4, 0.5), (2.5, -4.2, -0.5)
            ]
            for (cx, cy, cz) in chunkOffsets {
                let cw = Float(rng.nextDouble()) * 1.2 + 0.8
                let ch = Float(rng.nextDouble()) * 0.8 + 0.4
                let cd = Float(rng.nextDouble()) * 1.2 + 0.8
                let rot = Float(rng.nextDouble()) * 0.5 - 0.25
                let chunkV = buildBox(w: cw, h: ch, d: cd, color: [0.38, 0.33, 0.26, 1])
                if let b = makeVertexBuffer(chunkV, device: device) {
                    islandPieces.append(IslandPiece(buffer: b, count: chunkV.count,
                                                     localModel: m4Translation(cx, cy, cz) * m4RotY(rot)))
                }
            }

            // 5 Crystalline spires: 4 corners + 1 center
            let spireDefs: [(Float, Float, Float)] = [
                (-3, 0.75, -3), (3, 0.75, -3), (-3, 0.75, 3), (3, 0.75, 3), (0, 0.75, 0)
            ]
            for (sx, sy, sz) in spireDefs {
                let sv = buildPyramid(bw: 0.6, bd: 0.6, h: 2.5, color: [0.75, 0.88, 1.0, 1])
                if let b = makeVertexBuffer(sv, device: device) {
                    spires.append(Spire(buffer: b, count: sv.count,
                                        localModel: m4Translation(sx, sy, sz),
                                        baseEmissive: [0.4, 0.6, 0.9]))
                }
            }

            // Waterfall plane at (4, -0.75, 0), normal = [-1, 0, 0]
            let wfV = buildQuad(w: 0.5, h: 3, color: [0.7, 0.85, 1.0, 0.35], normal: [-1, 0, 0])
            if let b = makeVertexBuffer(wfV, device: device) {
                waterfallBuf   = b
                waterfallCount = wfV.count
            }

            // Waterfall drops
            var wdrng = SplitMix64(seed: 12001)
            for _ in 0..<50 {
                let speed = Float(wdrng.nextDouble()) * 1.5 + 0.8
                let phase = Float(wdrng.nextDouble()) * 3.0
                let xOff  = Float(wdrng.nextDouble()) * 0.3 - 0.15
                waterfallDrops.append(WaterfallDrop(speed: speed, phase: phase, xOff: xOff))
            }

            // Golden motes: 30 in range x=-3..3, z=-3..3
            var mrng = SplitMix64(seed: 12002)
            for _ in 0..<30 {
                let bx    = Float(mrng.nextDouble()) * 6 - 3
                let bz    = Float(mrng.nextDouble()) * 6 - 3
                let phase = Float(mrng.nextDouble()) * Float.pi * 2
                goldenMotes.append(GoldenMote(baseX: bx, baseZ: bz, phase: phase))
            }

            // Cloud puffs: 12 spheres below island
            var crng = SplitMix64(seed: 12003)
            for _ in 0..<12 {
                let cx    = Float(crng.nextDouble()) * 20 - 10
                let cy    = -(Float(crng.nextDouble()) * 3 + 4)
                let cz    = Float(crng.nextDouble()) * 20 - 10
                let cr    = Float(crng.nextDouble()) * 0.2 + 0.3
                let drift = Float(crng.nextDouble()) * 0.3 + 0.1
                let cv    = buildSphere(radius: cr, rings: 6, segments: 8,
                                        color: [1.0, 1.0, 1.0, 0.7])
                if let b = makeVertexBuffer(cv, device: device) {
                    clouds.append(Cloud(buffer: b, count: cv.count,
                                        pos: [cx, cy, cz], driftSpeed: drift))
                }
            }
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opPipe = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)
            let twoPi = Float.pi * 2

            // Island bob
            let islandY = 0.3 * sin(t * twoPi / 8.0)
            let islandTrans = m4Translation(0, islandY, 0)

            // Camera orbits at r=12, height=-3 looking up at island
            let camAngle = t * twoPi / 80.0
            let eye = SIMD3<Float>(12 * sin(camAngle), -3, 12 * cos(camAngle))
            let center3 = SIMD3<Float>(0, 0, 0)
            let view3D = m4LookAt(eye: eye, center: center3, up: [0, 1, 0])
            let proj   = m4Perspective(fovyRad: 1.0, aspect: aspect, near: 0.1, far: 60)

            var su = SceneUniforms3D(
                viewProjection:  proj * view3D,
                sunDirection:    SIMD4<Float>(simd_normalize([-0.4, -0.7, -0.3]), 0),
                sunColor:        SIMD4<Float>([1.0, 0.97, 0.88], 0),
                ambientColor:    SIMD4<Float>([0.35, 0.45, 0.55], t),
                fogParams:       SIMD4<Float>(60, 100, 0, 0),  // essentially no fog (open sky)
                fogColor:        SIMD4<Float>([0.4, 0.6, 0.85], 0),
                cameraWorldPos:  SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(opPipe)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Static opaque
            for call in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Island pieces (with bob)
            for piece in islandPieces {
                encodeDraw(encoder: enc, vertexBuffer: piece.buffer, vertexCount: piece.count,
                           model: islandTrans * piece.localModel)
            }

            // Glow pass: spires, waterfall, clouds
            if let gp = glowPipeline {
                enc.setRenderPipelineState(gp)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

                // Spires with optional pulse
                let pulseFrac: Float
                let pulseAge = t - spirePulseT
                if pulseAge >= 0 && pulseAge < 0.8 {
                    pulseFrac = max(0, 1 - pulseAge / 0.8)
                } else {
                    pulseFrac = 0
                }
                let pulseSin = pulseFrac > 0 ? max(0, sin(pulseAge * .pi / 0.4)) : 0

                for spire in spires {
                    let em = spire.baseEmissive + SIMD3<Float>(repeating: pulseFrac * 1.5)
                    let sc = 1.0 + 0.25 * pulseSin
                    let model = islandTrans * spire.localModel * m4Scale(sc, sc, sc)
                    encodeDraw(encoder: enc, vertexBuffer: spire.buffer, vertexCount: spire.count,
                               model: model, emissiveColor: em, emissiveMix: 0.65 + pulseFrac * 0.35,
                               opacity: 0.65)
                }

                // Waterfall
                if let wfBuf = waterfallBuf {
                    let wfModel = islandTrans * m4Translation(4, -0.75, 0)
                    encodeDraw(encoder: enc, vertexBuffer: wfBuf, vertexCount: waterfallCount,
                               model: wfModel, emissiveColor: [0.7, 0.85, 1.0],
                               emissiveMix: 0.5, opacity: 0.35)
                }

                // Cloud puffs (slowly drifting)
                for cloud in clouds {
                    let driftX = cloud.pos.x + cloud.driftSpeed * t
                    let wrappedX = driftX.truncatingRemainder(dividingBy: 20.0)
                    let cx = wrappedX < -10 ? wrappedX + 20 : (wrappedX > 10 ? wrappedX - 20 : wrappedX)
                    let model = m4Translation(cx, cloud.pos.y, cloud.pos.z)
                    encodeDraw(encoder: enc, vertexBuffer: cloud.buffer, vertexCount: cloud.count,
                               model: model, emissiveColor: [0.9, 0.95, 1.0],
                               emissiveMix: 0.3, opacity: 0.6)
                }
            }

            // Particles
            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []

                // Waterfall drops
                for drop in waterfallDrops {
                    let fall = (drop.speed * t + drop.phase).truncatingRemainder(dividingBy: 3.0)
                    let py   = islandY + 0.8 - fall
                    let px   = Float(4) + drop.xOff
                    let alpha = 0.5 + 0.3 * sin(t * 2 + drop.phase)
                    pv.append(ParticleVertex3D(position: [px, py, 0 + drop.xOff * 0.5],
                                               color: [0.75, 0.88, 1.0, max(0, alpha)], size: 3))
                }

                // Golden motes: slow rise in y=0..2
                for m in goldenMotes {
                    let rise = (t * 0.15 + m.phase).truncatingRemainder(dividingBy: 2.0)
                    let py   = islandY + rise
                    let alpha = max(0, 0.7 + 0.3 * sin(t + m.phase))
                    pv.append(ParticleVertex3D(position: [m.baseX, py, m.baseZ],
                                               color: [1.0, 0.88, 0.3, alpha], size: 4))
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
        v.delegate                 = context.coordinator
        v.colorPixelFormat         = .bgra8Unorm
        v.depthStencilPixelFormat  = .depth32Float
        v.clearColor               = MTLClearColor(red: 0.4, green: 0.6, blue: 0.85, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.spirePulseT = Float(CACurrentMediaTime() - c.startTime)
    }
}
