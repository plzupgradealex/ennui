// RetroGarden3DMetalScene — Pixel-art style low-poly garden on a bright day.
// Green grass, flowers, a windmill with rotating blades, butterflies circling.
// Tap to pulse butterfly wing size.
// Rendered in Metal (MTKView) — no SceneKit. Seed 5555.

import SwiftUI
import MetalKit

struct RetroGarden3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        RetroGarden3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct RetroGarden3DMetalRepresentable: NSViewRepresentable {
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
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }

        var opaqueCalls: [DrawCall] = []
        var glowCalls:   [DrawCall] = []

        // Windmill blade buffer (reused each frame with different rotation)
        var bladeBuffer: MTLBuffer?
        var bladeCount: Int = 0
        var windmillPos: SIMD3<Float> = [3.0, 0, -2.0]

        // Flower positions for butterfly orbits
        var flowerPositions: [SIMD3<Float>] = []

        // Butterfly data
        struct Butterfly {
            var buffer: MTLBuffer; var count: Int
            var flowerIdx: Int; var orbitR: Float; var speed: Float
            var startAngle: Float; var color: SIMD3<Float>
        }
        var butterflies: [Butterfly] = []

        // Tap pulse
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
            } catch { print("RetroGarden3DMetal pipeline error: \(error)") }
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

        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, mix: Float = 1.0, opacity: Float) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count,
                                      model: model, emissiveCol: emissive,
                                      emissiveMix: mix, opacity: opacity))
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 5555)

            // ── Sky sphere ──
            addOpaque(buildSphere(radius: 60, rings: 8, segments: 12,
                                  color: [0.50, 0.70, 0.90, 1]),
                      model: matrix_identity_float4x4,
                      emissive: [0.40, 0.55, 0.75], mix: 0.25)

            // ── Green grass floor ──
            addOpaque(buildPlane(w: 30, d: 30, color: [0.25, 0.60, 0.18, 1]),
                      model: matrix_identity_float4x4)

            // ── Two green hills in background ──
            addOpaque(buildSphere(radius: 4.0, rings: 6, segments: 10,
                                  color: [0.22, 0.55, 0.18, 1]),
                      model: m4Translation(-6, -1.5, -10) * m4Scale(1.8, 0.6, 1.2))
            addOpaque(buildSphere(radius: 3.5, rings: 6, segments: 10,
                                  color: [0.20, 0.50, 0.16, 1]),
                      model: m4Translation(5, -1.2, -12) * m4Scale(2.0, 0.5, 1.0))

            // ── 9 Flowers: green cylinder stems + colored cone heads ──
            let headColors: [SIMD4<Float>] = [
                [0.95, 0.30, 0.25, 1], [0.95, 0.85, 0.20, 1], [0.90, 0.45, 0.70, 1],
                [0.35, 0.50, 0.95, 1], [1.00, 0.55, 0.15, 1], [0.80, 0.25, 0.85, 1],
                [1.00, 0.75, 0.80, 1], [0.40, 0.85, 0.45, 1], [0.95, 0.95, 0.50, 1]
            ]
            let stemCol: SIMD4<Float> = [0.15, 0.50, 0.12, 1]

            for i in 0..<9 {
                let fx = Float(Double.random(in: -7.0...7.0, using: &rng))
                let fz = Float(Double.random(in: -6.0...4.0, using: &rng))
                let stemH: Float = Float(0.6 + Double.random(in: 0...0.5, using: &rng))
                let pos = SIMD3<Float>(fx, 0, fz)
                flowerPositions.append(pos)

                // Stem
                addOpaque(buildCylinder(radius: 0.04, height: stemH, segments: 6, color: stemCol),
                          model: m4Translation(fx, stemH * 0.5, fz))
                // Head
                let headCol = headColors[i % headColors.count]
                addOpaque(buildCone(radius: 0.18, height: 0.22, segments: 8, color: headCol),
                          model: m4Translation(fx, stemH + 0.11, fz),
                          emissive: SIMD3<Float>(headCol.x, headCol.y, headCol.z) * 0.15, mix: 0.15)
            }

            // ── Windmill body (white cylinder) ──
            let wmx = windmillPos.x, wmz = windmillPos.z
            addOpaque(buildCylinder(radius: 0.35, height: 2.5, segments: 8,
                                    color: [0.92, 0.90, 0.88, 1]),
                      model: m4Translation(wmx, 1.25, wmz))
            // Windmill roof
            addOpaque(buildCone(radius: 0.50, height: 0.5, segments: 8,
                                color: [0.50, 0.25, 0.12, 1]),
                      model: m4Translation(wmx, 2.75, wmz))
            // Windmill door
            addOpaque(buildQuad(w: 0.25, h: 0.4, color: [0.35, 0.20, 0.10, 1],
                                normal: [0, 0, 1]),
                      model: m4Translation(wmx, 0.22, wmz + 0.36))

            // Blades — pre-build geometry, animate rotation in draw()
            let bladeVerts = buildBox(w: 0.12, h: 1.2, d: 0.03,
                                      color: [0.45, 0.30, 0.15, 1])
            bladeBuffer = makeVertexBuffer(bladeVerts, device: device)
            bladeCount = bladeVerts.count

            // ── 6 Butterflies ──
            let bflyColors: [SIMD3<Float>] = [
                [0.95, 0.80, 0.20], [0.90, 0.35, 0.55], [0.40, 0.65, 0.95],
                [0.95, 0.55, 0.15], [0.70, 0.30, 0.90], [0.30, 0.85, 0.50]
            ]
            var bflyRng = SplitMix64(seed: 6789)
            for i in 0..<6 {
                let col = bflyColors[i]
                let wingVerts = buildBox(w: 0.14, h: 0.08, d: 0.02,
                                         color: [col.x, col.y, col.z, 1])
                guard let buf = makeVertexBuffer(wingVerts, device: device) else { continue }
                let fi = Int.random(in: 0..<flowerPositions.count, using: &bflyRng)
                let orbitR = Float(0.4 + Double.random(in: 0...0.6, using: &bflyRng))
                let speed = Float(1.5 + Double.random(in: 0...1.5, using: &bflyRng))
                let start = Float(Double.random(in: 0...6.28, using: &bflyRng))
                butterflies.append(Butterfly(buffer: buf, count: wingVerts.count,
                                             flowerIdx: fi, orbitR: orbitR,
                                             speed: speed, startAngle: start, color: col))
            }

            // ── Small white clouds ──
            for _ in 0..<5 {
                let cx = Float(Double.random(in: -12.0...12.0, using: &rng))
                let cy = Float(8.0 + Double.random(in: 0...3.0, using: &rng))
                let cz = Float(Double.random(in: -15.0 ... -6.0, using: &rng))
                addGlow(buildSphere(radius: 1.2, rings: 4, segments: 6,
                                    color: [0.95, 0.95, 0.98, 1]),
                        model: m4Translation(cx, cy, cz) * m4Scale(1.5, 0.5, 0.8),
                        emissive: [0.90, 0.90, 0.95], mix: 0.4, opacity: 0.5)
            }

            // ── Fence posts along the back ──
            for fx in stride(from: Float(-8), through: Float(8), by: 2.0) {
                addOpaque(buildBox(w: 0.08, h: 0.5, d: 0.08,
                                   color: [0.55, 0.35, 0.18, 1]),
                          model: m4Translation(fx, 0.25, -7))
            }
            // Fence rail
            addOpaque(buildBox(w: 16, h: 0.06, d: 0.06,
                               color: [0.55, 0.35, 0.18, 1]),
                      model: m4Translation(0, 0.40, -7))
        }

        func handleTap() {
            pulseT = Float(CACurrentMediaTime() - startTime)
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
            let pulseFade = max(0, 1 - (t - pulseT) / 2.0)

            // Camera — slow orbit
            let orbitAngle = t * (2 * Float.pi / 60.0)
            let camR: Float = 10.0
            let eye: SIMD3<Float> = [camR * sin(orbitAngle),
                                      3.0 + 0.3 * sin(t * 0.15),
                                      camR * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 0.5, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([-0.3, -0.8, 0.4])
            let sunCol: SIMD3<Float> = [1.0, 0.95, 0.80]
            let ambCol: SIMD3<Float> = [0.30, 0.32, 0.35]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(20, 55, 0, 0),
                fogColor:       SIMD4<Float>(0.50, 0.70, 0.90, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Static opaque geometry
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Windmill blades (4 blades rotating)
            if let bb = bladeBuffer {
                let wmx = windmillPos.x, wmz = windmillPos.z
                let hubY: Float = 2.5
                for i in 0..<4 {
                    let angle = t * 0.8 + Float(i) * (.pi / 2)
                    let bladeModel = m4Translation(wmx, hubY, wmz + 0.37) *
                                     m4RotZ(angle) *
                                     m4Translation(0, 0.6, 0)
                    encodeDraw(encoder: encoder,
                               vertexBuffer: bb, vertexCount: bladeCount,
                               model: bladeModel)
                }
            }

            // Butterflies (animated orbits around flowers)
            for bf in butterflies {
                guard bf.flowerIdx < flowerPositions.count else { continue }
                let center3 = flowerPositions[bf.flowerIdx]
                let angle = t * bf.speed + bf.startAngle
                let bx = center3.x + bf.orbitR * cos(angle)
                let bz = center3.z + bf.orbitR * sin(angle)
                let by: Float = 0.8 + 0.2 * sin(t * 2.0 + bf.startAngle)
                let wingFlap = (0.3 + pulseFade * 0.4) * sin(t * 8.0 + bf.startAngle)
                // Left wing
                let modelL = m4Translation(bx, by, bz) * m4RotY(-angle) *
                             m4Translation(-0.08, 0, 0) * m4RotZ(wingFlap)
                encodeDraw(encoder: encoder,
                           vertexBuffer: bf.buffer, vertexCount: bf.count,
                           model: modelL,
                           emissiveColor: bf.color * 0.2, emissiveMix: 0.2)
                // Right wing
                let modelR = m4Translation(bx, by, bz) * m4RotY(-angle) *
                             m4Translation(0.08, 0, 0) * m4RotZ(-wingFlap)
                encodeDraw(encoder: encoder,
                           vertexBuffer: bf.buffer, vertexCount: bf.count,
                           model: modelR,
                           emissiveColor: bf.color * 0.2, emissiveMix: 0.2)
            }

            // Glow pass — clouds
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in glowCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            // Particle pass — pollen motes drifting in sunlight
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                var moteRng = SplitMix64(seed: 4321)
                for i in 0..<20 {
                    let phase = Float(i) * 0.5
                    let mx = Float(Double.random(in: -6.0...6.0, using: &moteRng))
                    let mz = Float(Double.random(in: -5.0...5.0, using: &moteRng))
                    let my = Float(0.5 + Double.random(in: 0...2.0, using: &moteRng))
                    let wx = mx + 0.8 * sin(t * 0.12 + phase)
                    let wy = my + 0.4 * sin(t * 0.2 + phase * 0.7)
                    let wz = mz + 0.5 * cos(t * 0.15 + phase)
                    let alpha = 0.3 + 0.2 * abs(sin(t * 0.6 + phase))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [1.0, 0.95, 0.70, alpha], size: 3))
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
        view.clearColor               = MTLClearColor(red: 0.50, green: 0.70, blue: 0.90, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.handleTap()
    }
}
