// JeonjuNight3DScene — Metal 3D Korean neighbourhood at night.
// Hanok houses with warm windows, a sodium street lamp, telephone wires,
// moths drifting, a cat on a wall. Camera drifts slowly down the street.
// Tap to toggle a window light. Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct JeonjuNight3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        JeonjuNight3DRepresentable(interaction: interaction,
                                    tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct JeonjuNight3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

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
            var opacity:     Float
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // MARK: Window state (tap to toggle)
        struct WindowState {
            var isLit:       Bool
            var intensity:   Float      // 0..1, animated
            var emissiveCol: SIMD3<Float>
            var drawIndex:   Int        // index into transparentCalls
        }
        var windows: [WindowState] = []

        // MARK: Moths
        var mothPositions: [SIMD3<Float>] = []
        var mothPhases:    [Float] = []

        // MARK: Stars
        var starPositions: [SIMD3<Float>] = []
        var starPhases:    [Float] = []

        // MARK: Frame state
        let startTime = CACurrentMediaTime()
        var aspect: Float = 1
        var lastTapCount  = 0

        // MARK: Init

        override init() {
            guard let dev = MTLCreateSystemDefaultDevice(),
                  let q   = dev.makeCommandQueue()
            else { fatalError("Metal not available") }
            device       = dev
            commandQueue = q
            super.init()

            opaquePipeline   = try? makeOpaquePipeline(device: dev)
            glowPipeline     = try? makeAlphaBlendPipeline(device: dev)
            particlePipeline = try? makeParticlePipeline(device: dev)
            depthState       = makeDepthState(device: dev)
            depthROState     = makeDepthReadOnlyState(device: dev)

            buildScene()
        }

        // MARK: Geometry helpers

        func addOpaque(_ verts: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: verts.count,
                                       model: model, emissiveCol: .zero,
                                       emissiveMix: 0, opacity: 1))
        }

        @discardableResult
        func addGlow(_ verts: [Vertex3D], model: simd_float4x4,
                     emissive: SIMD3<Float>, opacity: Float) -> Int {
            guard let buf = makeVertexBuffer(verts, device: device) else { return -1 }
            let idx = transparentCalls.count
            transparentCalls.append(DrawCall(buffer: buf, count: verts.count,
                                            model: model, emissiveCol: emissive,
                                            emissiveMix: 1, opacity: opacity))
            return idx
        }

        // MARK: - Build scene

        private func buildScene() {
            buildGround()
            buildMountains()
            buildMoon()
            buildHouses()
            buildConvenienceStore()
            buildStreetLamp()
            buildTelephoneWires()
            buildCat()
            buildMoths()
            buildStars()
        }

        private func buildGround() {
            // Ground plane
            addOpaque(buildPlane(w: 30, d: 30, color: [0.06, 0.05, 0.08, 1]),
                      model: matrix_identity_float4x4)
            // Road
            addOpaque(buildBox(w: 3.0, h: 0.005, d: 20, color: [0.10, 0.08, 0.12, 1]),
                      model: m4Translation(0, 0.003, 0))
            // Center dashes
            var dz: Float = -9.0
            while dz < 9.0 {
                addOpaque(buildBox(w: 0.08, h: 0.002, d: 0.4,
                                   color: [0.35, 0.30, 0.25, 0.25]),
                          model: m4Translation(0, 0.006, dz))
                dz += 1.2
            }
        }

        private func buildMountains() {
            var rng = SplitMix64(seed: 7777)
            for _ in 0..<8 {
                let mx = Float(Double.random(in: -12...12, using: &rng))
                let mh = Float(2.0 + Double.random(in: 0..<4, using: &rng))
                let mw = Float(2.0 + Double.random(in: 0..<3, using: &rng))
                addOpaque(buildBox(w: mw, h: mh, d: 2, color: [0.06, 0.05, 0.12, 1]),
                          model: m4Translation(mx, mh / 2, -12))
            }
        }

        private func buildMoon() {
            // Moon sphere (emissive)
            addGlow(buildSphere(radius: 1.2, rings: 10, segments: 16,
                                color: [1, 1, 1, 1]),
                    model: m4Translation(8, 18, -15),
                    emissive: [0.95, 0.92, 0.80], opacity: 1.0)
            // Crescent shadow
            addOpaque(buildSphere(radius: 1.15, rings: 8, segments: 12,
                                  color: [0.02, 0.015, 0.04, 1]),
                      model: m4Translation(8.6, 18.1, -14.8))
            // Halo glow
            addGlow(buildSphere(radius: 2.5, rings: 6, segments: 10,
                                color: [1, 1, 1, 1]),
                    model: m4Translation(8, 18, -15),
                    emissive: [0.75, 0.72, 0.55], opacity: 0.07)
        }

        private func buildHouses() {
            var rng = SplitMix64(seed: 1988)

            struct HouseSpec { let x, z, w, h, d: Float; let isHanok: Bool }
            let specs: [HouseSpec] = [
                HouseSpec(x: -4.5, z: -2.0, w: 1.4, h: 1.2, d: 1.0, isHanok: true),
                HouseSpec(x: -2.8, z: -2.5, w: 1.2, h: 1.0, d: 0.9, isHanok: true),
                HouseSpec(x: -1.2, z: -2.2, w: 1.3, h: 1.1, d: 1.0, isHanok: true),
                HouseSpec(x:  2.0, z: -2.3, w: 1.1, h: 1.05, d: 0.85, isHanok: false),
                HouseSpec(x:  3.5, z: -1.8, w: 1.5, h: 1.3, d: 1.1, isHanok: true),
                HouseSpec(x:  5.0, z: -2.5, w: 1.2, h: 1.0, d: 0.9, isHanok: true),
            ]

            for spec in specs {
                let wc: SIMD4<Float> = spec.isHanok
                    ? [0.2125, 0.1716, 0.13, 1]
                    : [0.125, 0.1056, 0.09, 1]
                addOpaque(buildBox(w: spec.w, h: spec.h, d: spec.d, color: wc),
                          model: m4Translation(spec.x, spec.h / 2, spec.z))

                let ov: Float = spec.isHanok ? 0.25 : 0.08
                let rh = spec.h * 0.25
                let rc: SIMD4<Float> = spec.isHanok
                    ? [0.25, 0.20, 0.18, 1] : [0.35, 0.30, 0.32, 1]
                addOpaque(buildPyramid(bw: spec.w + ov * 2, bd: spec.d + ov * 2,
                                       h: rh, color: rc),
                          model: m4Translation(spec.x, spec.h, spec.z))

                // Windows
                let winCount = 2 + Int(Double.random(in: 0..<1.5, using: &rng))
                for wi in 0..<winCount {
                    let nx = (Float(wi) + 0.5) / Float(winCount)
                    let isLit = Double.random(in: 0...1, using: &rng) > 0.35
                    let warmth = Float(0.6 + Double.random(in: 0..<0.4, using: &rng))
                    let wx = spec.x + (nx - 0.5) * spec.w
                    let wy = spec.h * 0.5
                    let wz = spec.z + spec.d / 2 + 0.01
                    let amber = SIMD3<Float>(0.95 * warmth, 0.78 * warmth,
                                             0.35 * warmth)
                    let winW = spec.w * 0.15, winH = spec.h * 0.22
                    let idx = addGlow(
                        buildQuad(w: winW, h: winH,
                                  color: [amber.x, amber.y, amber.z, 1]),
                        model: m4Translation(wx, wy, wz),
                        emissive: amber, opacity: 0.9)
                    windows.append(WindowState(isLit: isLit,
                                               intensity: isLit ? 1 : 0,
                                               emissiveCol: amber,
                                               drawIndex: idx))
                }
            }
        }

        private func buildConvenienceStore() {
            addOpaque(buildBox(w: 2.5, h: 1.4, d: 1.2, color: [0.18, 0.14, 0.10, 1]),
                      model: m4Translation(0.5, 0.7, -2.8))
            // Awning
            addOpaque(buildBox(w: 2.7, h: 0.08, d: 0.4, color: [0.7, 0.12, 0.08, 1]),
                      model: m4Translation(0.5, 1.44, -2.42))
            // Front window (warm bright interior)
            addGlow(buildQuad(w: 1.6, h: 0.9, color: [1, 1, 1, 1]),
                    model: m4Translation(0.5, 0.7, -2.21),
                    emissive: [0.90, 0.75, 0.50], opacity: 0.95)
            // Neon sign
            addGlow(buildBox(w: 0.6, h: 0.12, d: 0.03, color: [1, 1, 1, 1]),
                    model: m4Translation(0.5, 1.5, -2.20),
                    emissive: [0.2, 0.9, 1.0], opacity: 1.0)
        }

        private func buildStreetLamp() {
            // Pole
            addOpaque(buildCylinder(radius: 0.04, height: 3.5, segments: 8,
                                    color: [0.22, 0.20, 0.18, 1]),
                      model: m4Translation(-1.5, 1.75, -1.0))
            // Arm
            addOpaque(buildCylinder(radius: 0.02, height: 0.8, segments: 6,
                                    color: [0.22, 0.20, 0.18, 1]),
                      model: m4Translation(-1.5, 3.35, -1.0) * m4RotZ(.pi / 2)
                             * m4Translation(0.4, 0, 0))
            // Lamp head (sodium orange)
            addGlow(buildBox(w: 0.20, h: 0.08, d: 0.20, color: [1, 1, 1, 1]),
                    model: m4Translation(-1.1, 3.35, -1.0),
                    emissive: [1.0, 0.65, 0.10], opacity: 1.0)
            // Light cone
            addGlow(buildCone(radius: 0.9, height: 1.6, segments: 12,
                              color: [1, 0.65, 0.1, 0.07]),
                    model: m4Translation(-1.1, 2.55, -1.0),
                    emissive: [1.0, 0.65, 0.10], opacity: 0.07)
        }

        private func buildTelephoneWires() {
            for side: Float in [-1, 1] {
                let px = side * 4.5
                addOpaque(buildCylinder(radius: 0.04, height: 4, segments: 6,
                                        color: [0.18, 0.12, 0.08, 1]),
                          model: m4Translation(px, 2.0, -3.0))
                addOpaque(buildCylinder(radius: 0.025, height: 1.2, segments: 6,
                                        color: [0.18, 0.12, 0.08, 1]),
                          model: m4Translation(px, 3.85, -3.0) * m4RotZ(.pi / 2))
            }
            // Wires
            for i in 0..<3 {
                let wireY: Float = 3.9 - Float(i) * 0.15
                addOpaque(buildCylinder(radius: 0.008, height: 9, segments: 4,
                                        color: [0.10, 0.08, 0.06, 0.7]),
                          model: m4Translation(0, wireY, -3.0) * m4RotZ(.pi / 2))
            }
        }

        private func buildCat() {
            let catCol: SIMD4<Float> = [0.08, 0.06, 0.10, 1]
            addOpaque(buildBox(w: 0.25, h: 0.20, d: 0.20, color: catCol),
                      model: m4Translation(3.8, 1.0, -1.5))
            addOpaque(buildSphere(radius: 0.10, rings: 5, segments: 8, color: catCol),
                      model: m4Translation(3.8, 1.22, -1.5))
            addOpaque(buildPyramid(bw: 0.06, bd: 0.04, h: 0.08, color: catCol),
                      model: m4Translation(3.73, 1.31, -1.5))
            addOpaque(buildPyramid(bw: 0.06, bd: 0.04, h: 0.08, color: catCol),
                      model: m4Translation(3.87, 1.31, -1.5))
            addOpaque(buildCylinder(radius: 0.02, height: 0.30, segments: 6,
                                    color: catCol),
                      model: m4Translation(3.95, 0.92, -1.5) * m4RotZ(.pi / 4))
        }

        private func buildMoths() {
            var rng = SplitMix64(seed: 4444)
            for _ in 0..<20 {
                let mx = Float(Double.random(in: -3...3, using: &rng))
                let my = Float(1.5 + Double.random(in: 0...2, using: &rng))
                let mz = Float(-3 + Double.random(in: 0...1, using: &rng))
                mothPositions.append([mx, my, mz])
                mothPhases.append(Float(Double.random(in: 0...(.pi * 2), using: &rng)))
            }
        }

        private func buildStars() {
            var rng = SplitMix64(seed: 8888)
            for _ in 0..<60 {
                let sx = Float(Double.random(in: -15...15, using: &rng))
                let sy = Float(8 + Double.random(in: 0..<12, using: &rng))
                let sz = Float(-10 + Double.random(in: -5..<0, using: &rng))
                starPositions.append([sx, sy, sz])
                starPhases.append(Float(Double.random(in: 0...(.pi * 2), using: &rng)))
            }
        }

        // MARK: - Tap interaction

        func toggleRandomWindow() {
            guard !windows.isEmpty else { return }
            let idx = Int.random(in: 0..<windows.count)
            windows[idx].isLit.toggle()
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

            // Animate window intensities toward target
            for i in windows.indices {
                let target: Float = windows[i].isLit ? 1 : 0
                windows[i].intensity += (target - windows[i].intensity) * 0.05
            }

            // Camera drifts slowly down the street (Z from +8 to -4, loops every 40s)
            let driftT = t.truncatingRemainder(dividingBy: 40.0)
            let camZ = 8.0 - driftT * (12.0 / 40.0)
            let eye    = SIMD3<Float>(0.3, 1.55, camZ)
            let center = SIMD3<Float>(0.3, 1.35, camZ - 5)

            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect,
                                      near: 0.05, far: 50)
            let vp = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([-0.4, -0.8, -0.2]), 0),
                sunColor:       SIMD4<Float>([0.25, 0.28, 0.45], 0),
                ambientColor:   SIMD4<Float>([0.08, 0.06, 0.14], t),
                fogParams:      SIMD4<Float>(10, 40, 0, 0),
                fogColor:       SIMD4<Float>([0.04, 0.03, 0.06], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque geometry
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Glow / transparent pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                for (i, call) in transparentCalls.enumerated() {
                    if let win = windows.first(where: { $0.drawIndex == i }) {
                        let intensity = win.intensity
                        guard intensity > 0.01 else { continue }
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: call.buffer, vertexCount: call.count,
                                   model: call.model,
                                   emissiveColor: call.emissiveCol * intensity,
                                   emissiveMix: 1,
                                   opacity: call.opacity * intensity)
                    } else {
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: call.buffer, vertexCount: call.count,
                                   model: call.model,
                                   emissiveColor: call.emissiveCol,
                                   emissiveMix: call.emissiveMix,
                                   opacity: call.opacity)
                    }
                }
            }

            // Moths and stars as particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                for i in mothPositions.indices {
                    let ph = mothPhases[i]
                    let orbitR: Float = 0.3 + 0.2 * abs(sin(ph))
                    let mx = mothPositions[i].x + orbitR * sin(t * 2.1 + ph)
                    let my = mothPositions[i].y + 0.15 * cos(t * 1.7 + ph * 1.3)
                    let mz = mothPositions[i].z + orbitR * cos(t * 1.9 + ph * 0.7)
                    let bright = 0.3 + 0.7 * abs(sin(t * 3.0 + ph))
                    let col = SIMD4<Float>(0.8 * bright, 0.6 * bright,
                                           0.3 * bright, bright * 0.7)
                    particles.append(ParticleVertex3D(position: [mx, my, mz],
                                                       color: col, size: 4))
                }

                for i in starPositions.indices {
                    let ph = starPhases[i]
                    let bright = 0.5 + 0.5 * sin(t * 0.3 + ph)
                    let col = SIMD4<Float>(0.9 * bright, 0.85 * bright,
                                           0.7 * bright, bright * 0.8)
                    particles.append(ParticleVertex3D(position: starPositions[i],
                                                       color: col, size: 3))
                }

                if !particles.isEmpty,
                   let pbuf = makeParticleBuffer(particles, device: device) {
                    encoder.setRenderPipelineState(ppipe)
                    encoder.setDepthStencilState(depthROState)
                    encoder.setVertexBuffer(pbuf, offset: 0, index: 0)
                    encoder.setVertexBytes(&su,
                                           length: MemoryLayout<SceneUniforms3D>.size,
                                           index: 1)
                    encoder.drawPrimitives(type: .point, vertexStart: 0,
                                           vertexCount: particles.count)
                }
            }

            encoder.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    // MARK: - NSViewRepresentable methods

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate                = context.coordinator
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor              = MTLClearColor(red: 0.02, green: 0.015,
                                                      blue: 0.04, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.toggleRandomWindow()
    }
}
