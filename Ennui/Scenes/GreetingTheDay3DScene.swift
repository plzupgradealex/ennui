// GreetingTheDay3DScene — Metal 3D sunrise city.
// Dark purple-blue sky brightens, 12 buildings, rising sun, golden dust motes.
// Tap to spawn a new building that grows from 0→full height over 0.6s.

import SwiftUI
import MetalKit

struct GreetingTheDay3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { GreetingTheDay3DRepresentable(interaction: interaction) }
}

private struct GreetingTheDay3DRepresentable: NSViewRepresentable {
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
            var buffer: MTLBuffer; var count: Int
            var model: simd_float4x4
            var emissiveCol: SIMD3<Float>; var emissiveMix: Float; var opacity: Float = 1
        }
        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        var sunBuffer: MTLBuffer?
        var sunCount   = 0

        struct DustMote { var x, baseY, z, speed, phase: Float }
        var dustMotes: [DustMote] = []

        struct SpawnedBuilding {
            var buf: MTLBuffer; var count: Int
            var x, z, targetH: Float; var spawnT: Float
        }
        var spawnedBuildings: [SpawnedBuilding] = []

        var rng = SplitMix64(seed: 4242)
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
            } catch { print("GreetingTheDay3D pipeline error: \(error)") }
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
                              emissive: SIMD3<Float>, opacity: Float = 0.85) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                      emissiveCol: emissive, emissiveMix: 1.0, opacity: opacity))
        }

        private func buildScene() {
            var lrng = SplitMix64(seed: 9988)

            addOpaque(buildPlane(w: 30, d: 30, color: [0.12, 0.10, 0.15, 1]),
                      model: matrix_identity_float4x4)

            let specs: [(x: Float, w: Float, z: Float, h: Float, d: Float)] = [
                (x: -7.0, w: 1.2, z:  -5.0, h: 3.0, d: 1.2),
                (x: -5.5, w: 1.5, z:  -7.0, h: 5.5, d: 1.4),
                (x: -3.5, w: 2.0, z:  -6.0, h: 7.0, d: 1.8),
                (x: -1.2, w: 1.8, z:  -5.5, h: 6.5, d: 2.0),
                (x:  1.0, w: 2.5, z:  -8.0, h: 9.0, d: 2.0),
                (x:  3.0, w: 1.3, z:  -6.0, h: 4.0, d: 1.5),
                (x:  5.0, w: 2.2, z:  -7.5, h: 8.0, d: 1.8),
                (x:  7.0, w: 1.0, z:  -5.0, h: 2.5, d: 1.2),
                (x: -4.5, w: 1.8, z: -10.0, h: 6.0, d: 2.0),
                (x:  4.5, w: 2.0, z:  -9.0, h: 7.5, d: 2.2),
                (x: -6.5, w: 1.0, z:  -9.0, h: 3.5, d: 1.5),
                (x:  0.5, w: 1.5, z: -10.0, h: 5.5, d: 1.8),
            ]
            let colA: SIMD4<Float> = [0.14, 0.15, 0.20, 1]
            let colB: SIMD4<Float> = [0.12, 0.14, 0.18, 1]
            let winEmissive: SIMD3<Float> = [1.0, 0.85, 0.50]
            for s in specs {
                let bCol: SIMD4<Float> = lrng.nextDouble() > 0.5 ? colA : colB
                addOpaque(buildBox(w: s.w, h: s.h, d: s.d, color: bCol),
                          model: m4Translation(s.x, s.h / 2, s.z))
                let numRows = max(1, Int(s.h / 1.2))
                for row in 0..<numRows {
                    let wy  = 0.5 + Float(row) * 1.1
                    let wz  = s.z + s.d / 2 + 0.01
                    let wc: SIMD4<Float> = [1, 0.9, 0.65, 1]
                    addGlow(buildQuad(w: 0.22, h: 0.28, color: wc, normal: [0, 0, 1]),
                            model: m4Translation(s.x - s.w * 0.15, wy, wz), emissive: winEmissive)
                    addGlow(buildQuad(w: 0.22, h: 0.28, color: wc, normal: [0, 0, 1]),
                            model: m4Translation(s.x + s.w * 0.15, wy, wz), emissive: winEmissive)
                }
            }

            let sv = buildSphere(radius: 1.2, rings: 8, segments: 16, color: [1.0, 0.7, 0.2, 1])
            sunBuffer = makeVertexBuffer(sv, device: device)
            sunCount  = sv.count

            var drng = SplitMix64(seed: 7654)
            for _ in 0..<60 {
                let mx = Float(drng.nextDouble() * 18 - 9)
                let my = Float(drng.nextDouble() * 9  - 1)
                let mz = Float(drng.nextDouble() * 8  - 10)
                let ms = Float(drng.nextDouble() * 0.3 + 0.2)
                let mp = Float(drng.nextDouble() * 2 * Double.pi)
                dustMotes.append(DustMote(x: mx, baseY: my, z: mz, speed: ms, phase: mp))
            }
        }

        func handleTap() {
            let t  = Float(CACurrentMediaTime() - startTime)
            let x  = Float(rng.nextDouble() * 16 - 8)
            let z  = -1 * Float(rng.nextDouble() * 7 + 3)
            let tH = Float(rng.nextDouble() * 7  + 2)
            let w  = Float(rng.nextDouble() * 1.5 + 1.0)
            let d  = Float(rng.nextDouble() * 1.0 + 0.8)
            let col: SIMD4<Float> = [0.16, 0.18, 0.24, 1]
            let verts = buildBox(w: w, h: tH, d: d, color: col)
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            spawnedBuildings.append(SpawnedBuilding(buf: buf, count: verts.count,
                                                     x: x, z: z, targetH: tH, spawnT: t))
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            let camX   = sin(t * 0.05) * 3
            let camY   = min(3 + t * 0.03, 8)
            let eye: SIMD3<Float>    = [camX, camY, 10]
            let center: SIMD3<Float> = [sin(t * 0.02) * 2, camY - 1, -5]
            let viewM  = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM  = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp     = projM * viewM

            let tc   = min(t / 60.0, 1.0)
            let ambR = Float(0.05 + tc * 0.15)
            let ambG = Float(0.04 + tc * 0.20)
            let ambB = Float(0.12 + tc * 0.10)
            let sunDir: SIMD3<Float> = simd_normalize([-0.3, -0.8, -0.5])
            let sunCol: SIMD3<Float> = [1.0, 0.85, 0.5]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambR, ambG, ambB, t),
                fogParams:      SIMD4<Float>(20, 50, 0, 0),
                fogColor:       SIMD4<Float>(0.06, 0.04, 0.12, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(pipeline)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            for sb in spawnedBuildings {
                let age  = t - sb.spawnT
                let frac = min(1, age / 0.6)
                guard frac > 0.001 else { continue }
                let h     = sb.targetH * frac
                let model = m4Translation(sb.x, h / 2, sb.z) * m4Scale(1, frac, 1)
                encodeDraw(encoder: enc, vertexBuffer: sb.buf, vertexCount: sb.count,
                           model: model, emissiveColor: .zero, emissiveMix: 0)
            }

            if let sBuf = sunBuffer {
                let sunY     = -2 + 7 * max(0, sin(t * .pi / 60.0))
                let sunModel = m4Translation(0, sunY, -15)
                encodeDraw(encoder: enc, vertexBuffer: sBuf, vertexCount: sunCount,
                           model: sunModel,
                           emissiveColor: [1.0, 0.7, 0.2], emissiveMix: 1.0)
            }

            if let glowPL = glowPipeline {
                enc.setRenderPipelineState(glowPL)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                for call in glowCalls {
                    encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for mote in dustMotes {
                    let total = mote.baseY + 1 + t * mote.speed
                    let cy    = total.truncatingRemainder(dividingBy: 10)
                    let wy    = cy - 1
                    let flick = Float(0.5 + 0.5 * sin(Double(t) * 4.0 + Double(mote.phase)))
                    let col: SIMD4<Float> = [flick, 0.75 * flick, 0.2 * flick, 0.6 * flick]
                    particles.append(ParticleVertex3D(
                        position: [mote.x, wy, mote.z], color: col, size: 4))
                }
                if let pbuf = makeParticleBuffer(particles, device: device) {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles.count)
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
        v.clearColor               = MTLClearColor(red: 0.06, green: 0.04, blue: 0.12, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
