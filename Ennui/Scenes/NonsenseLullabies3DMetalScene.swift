// NonsenseLullabies3DMetalScene — Watercolour nursery dreamscape with floating
// cats, moons, houses and stars in gentle pastel colours.
// Tap to gently pulse a random shape.
// No SceneKit — geometry built via Metal3DHelpers.

import SwiftUI
import MetalKit

struct NonsenseLullabies3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        NonsenseLullabies3DMetalRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct NonsenseLullabies3DMetalRepresentable: NSViewRepresentable {
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

        // Shape types mirror the SceneKit version
        enum ShapeKind { case cat, moon, house, star }

        struct FloatingShape {
            var kind: ShapeKind
            var calls: [DrawCall]        // multiple draw calls for compound shapes
            var basePos: SIMD3<Float>
            var bobDuration: Float
            var bobAmp: Float
            var bobPhase: Float
        }
        var shapes: [FloatingShape] = []

        // Tap pulse state
        var pulseIndex: Int = -1
        var pulseT: Float = -100

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
                print("NonsenseLullabies3DMetal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Geometry builders

        private func makeDC(_ verts: [Vertex3D], model: simd_float4x4 = matrix_identity_float4x4,
                            em: SIMD3<Float> = [0.15, 0.12, 0.08], mix: Float = 0.25) -> DrawCall? {
            guard let buf = makeVertexBuffer(verts, device: device) else { return nil }
            return DrawCall(buffer: buf, count: verts.count, model: model,
                            emissiveCol: em, emissiveMix: mix)
        }

        private func buildCat(color: SIMD4<Float>) -> [DrawCall] {
            var calls: [DrawCall] = []
            // Body
            if let dc = makeDC(buildBox(w: 0.30, h: 0.25, d: 0.15, color: color)) { calls.append(dc) }
            // Head
            if let dc = makeDC(buildSphere(radius: 0.12, rings: 4, segments: 6, color: color),
                               model: m4Translation(0.18, 0.10, 0)) { calls.append(dc) }
            // Ears
            for side: Float in [-1, 1] {
                if let dc = makeDC(buildPyramid(bw: 0.07, bd: 0.04, h: 0.08, color: color),
                                   model: m4Translation(0.18 + side * 0.07, 0.21, 0)) {
                    calls.append(dc)
                }
            }
            return calls
        }

        private func buildMoon(color: SIMD4<Float>) -> [DrawCall] {
            var calls: [DrawCall] = []
            if let dc = makeDC(buildSphere(radius: 0.20, rings: 5, segments: 8, color: color),
                               em: [color.x * 0.3, color.y * 0.3, color.z * 0.2], mix: 0.4) {
                calls.append(dc)
            }
            return calls
        }

        private func buildHouse(wallColor: SIMD4<Float>, roofColor: SIMD4<Float>) -> [DrawCall] {
            var calls: [DrawCall] = []
            // Walls
            if let dc = makeDC(buildBox(w: 0.25, h: 0.20, d: 0.20, color: wallColor)) { calls.append(dc) }
            // Roof
            if let dc = makeDC(buildPyramid(bw: 0.28, bd: 0.22, h: 0.15, color: roofColor),
                               model: m4Translation(0, 0.175, 0)) { calls.append(dc) }
            return calls
        }

        private func buildStarShape(color: SIMD4<Float>) -> [DrawCall] {
            var calls: [DrawCall] = []
            if let dc = makeDC(buildSphere(radius: 0.08, rings: 3, segments: 4, color: color),
                               em: [color.x * 0.5, color.y * 0.5, color.z * 0.3], mix: 0.5) {
                calls.append(dc)
            }
            return calls
        }

        // MARK: - Build scene

        private func buildScene() {
            let pink:   SIMD4<Float> = [0.98, 0.72, 0.80, 1]
            let lav:    SIMD4<Float> = [0.78, 0.70, 0.95, 1]
            let yellow: SIMD4<Float> = [0.99, 0.92, 0.52, 1]
            let peach:  SIMD4<Float> = [0.99, 0.80, 0.65, 1]
            let mint:   SIMD4<Float> = [0.68, 0.95, 0.82, 1]

            let bobDurations: [Float] = [2.0, 2.5, 3.0, 3.5, 4.0, 4.5, 5.0, 2.8, 3.2, 3.8,
                                          2.2, 2.6, 3.1, 3.6, 4.2, 4.8, 2.4, 3.4, 4.6, 2.9]
            let bobAmps: [Float]      = [0.2, 0.3, 0.25, 0.35, 0.2, 0.4, 0.3, 0.25, 0.2, 0.35,
                                          0.3, 0.25, 0.4, 0.2, 0.3, 0.25, 0.35, 0.2, 0.3, 0.25]

            var rng = SplitMix64(seed: 8888)

            for i in 0..<20 {
                let x = Float(Double.random(in: -5...5, using: &rng))
                let y = Float(Double.random(in: -2...3, using: &rng))
                let z = Float(Double.random(in: -8 ... -3, using: &rng))
                let phase = Float(Double.random(in: 0...(2 * .pi), using: &rng))

                let kind: ShapeKind
                let calls: [DrawCall]
                switch i % 4 {
                case 0:
                    kind = .cat
                    calls = buildCat(color: i % 2 == 0 ? pink : lav)
                case 1:
                    kind = .moon
                    calls = buildMoon(color: i % 2 == 0 ? yellow : peach)
                case 2:
                    kind = .house
                    calls = buildHouse(wallColor: i % 2 == 0 ? mint : lav,
                                       roofColor: i % 2 == 0 ? peach : pink)
                default:
                    kind = .star
                    calls = buildStarShape(color: i % 2 == 0 ? yellow : peach)
                }

                shapes.append(FloatingShape(
                    kind: kind, calls: calls,
                    basePos: [x, y, z],
                    bobDuration: bobDurations[i % bobDurations.count],
                    bobAmp: bobAmps[i % bobAmps.count],
                    bobPhase: phase
                ))
            }
        }

        func handleTap(_ tapCount: Int) {
            var rng = SplitMix64(seed: UInt64(tapCount &* 1999))
            pulseIndex = Int(Double.random(in: 0...Double(shapes.count - 1) + 0.99, using: &rng)) % shapes.count
            pulseT = Float(CACurrentMediaTime() - startTime)
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

            // Slow camera orbit
            let orbitAngle = t * (2 * Float.pi / 120.0)
            let camR: Float = 9.0
            let eye: SIMD3<Float> = [sin(orbitAngle) * camR * 0.5, 1.5, cos(orbitAngle) * camR - 3]
            let center: SIMD3<Float> = [0, 0.5, -5]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.1, far: 40)
            let vp = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([0.3, -0.8, -0.2])
            let sunCol: SIMD3<Float> = [1.0, 0.95, 0.85]
            let ambCol: SIMD3<Float> = [0.40, 0.38, 0.32]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(10, 25, 0, 0),
                fogColor:       SIMD4<Float>(0.95, 0.90, 0.82, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for (i, shape) in shapes.enumerated() {
                // Bob animation
                let bobT = t * (2 * Float.pi / shape.bobDuration) + shape.bobPhase
                let yOff = sin(bobT) * shape.bobAmp
                let pos = shape.basePos + [0, yOff, 0]

                // Tap pulse — grow and shrink the tapped shape
                var scl: Float = 1.0
                if i == pulseIndex {
                    let elapsed = t - pulseT
                    if elapsed < 0.5 {
                        let frac = elapsed / 0.5
                        scl = frac < 0.5 ? 1.0 + 0.5 * (frac * 2) : 1.5 - 0.5 * ((frac - 0.5) * 2)
                    }
                }

                let rootModel = m4Translation(pos.x, pos.y, pos.z) * m4Scale(scl, scl, scl)

                for call in shape.calls {
                    let finalModel = rootModel * call.model
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: finalModel,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
                }
            }

            // Soft glowing motes as particles scattered among the shapes
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for shape in shapes {
                    let bobT = t * (2 * Float.pi / shape.bobDuration) + shape.bobPhase
                    let yOff = sin(bobT) * shape.bobAmp
                    let pos = shape.basePos + [0, yOff, 0]
                    let sparkle = 0.3 + 0.3 * abs(sin(t * 0.8 + shape.bobPhase))
                    particles.append(ParticleVertex3D(
                        position: pos + [0, 0.15, 0],
                        color: [1.0, 0.95, 0.80, sparkle],
                        size: 4))
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
        view.clearColor               = MTLClearColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap(interaction.tapCount)
    }
}
