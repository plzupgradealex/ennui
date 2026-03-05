// MedievalVillage3DScene — Metal 3D diorama of the medieval hamlet.
// Low-poly buildings viewed from an orbiting camera above. Warm amber windows
// that tap-extinguish one by one. Firefly particles. Moon directional light.
// Rendered entirely in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct MedievalVillage3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        MedievalVillage3DRepresentable(interaction: interaction,
                                        tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct MedievalVillage3DRepresentable: NSViewRepresentable {
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

        // MARK: Window glow state (tap to extinguish one by one)
        struct WindowGlow {
            var intensity: Float   // 1 = lit, animates toward 0
            var drawIndex: Int     // index into transparentCalls
            var emissive:  SIMD3<Float>
        }
        var windows:          [WindowGlow] = []
        var extinguishedCount = 0

        // MARK: Fireflies
        var fireflyPositions: [SIMD3<Float>] = []
        var fireflyPhases:    [Float] = []

        // MARK: Frame state
        let startTime = CACurrentMediaTime()
        var aspect: Float = 1
        var lastTapCount  = 0

        // Ambient / moon brightness (dims as windows go out)
        var ambientLevel: Float = 1.0
        var moonLevel:    Float = 1.0

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
            buildBuildings()
            buildTrees()
            buildFireflies()
        }

        private func buildGround() {
            addOpaque(buildPlane(w: 30, d: 30, color: [0.06, 0.10, 0.04, 1]),
                      model: matrix_identity_float4x4)
            addOpaque(buildBox(w: 1.0, h: 0.01, d: 14, color: [0.12, 0.09, 0.06, 1]),
                      model: m4Translation(0, 0.005, 0))
        }

        private func buildBuildings() {
            var rng = SplitMix64(seed: 1350)

            struct Spot { let x, z, s: Float; let isChurch: Bool }
            let spots: [Spot] = [
                Spot(x: -3.2, z: -2.0, s: 1.0,  isChurch: false),
                Spot(x: -1.0, z: -3.2, s: 0.8,  isChurch: false),
                Spot(x:  1.2, z: -2.5, s: 1.1,  isChurch: false),
                Spot(x:  3.0, z: -1.0, s: 0.9,  isChurch: false),
                Spot(x: -2.2, z:  1.2, s: 0.85, isChurch: false),
                Spot(x:  0.5, z:  0.5, s: 1.15, isChurch: true),
                Spot(x:  2.5, z:  1.8, s: 0.95, isChurch: false),
            ]

            let wallCol: SIMD4<Float> = [0.20, 0.16, 0.10, 1]
            let roofCol: SIMD4<Float> = [0.28, 0.18, 0.08, 1]

            for spot in spots {
                let bh = spot.isChurch
                    ? Float(2.8)
                    : Float(1.0 + Double.random(in: 0...0.7, using: &rng))
                let bw = spot.isChurch
                    ? Float(1.3)
                    : Float(0.7 + Double.random(in: 0...0.5, using: &rng))
                let bd = spot.isChurch
                    ? Float(1.3)
                    : Float(0.6 + Double.random(in: 0...0.4, using: &rng))
                let sw = bw * spot.s, sh = bh * spot.s, sd = bd * spot.s

                // Body
                addOpaque(buildBox(w: sw, h: sh, d: sd, color: wallCol),
                          model: m4Translation(spot.x, sh / 2, spot.z))
                // Roof
                let roofH = 0.55 * spot.s
                addOpaque(buildPyramid(bw: sw + 0.15, bd: sd + 0.15, h: roofH, color: roofCol),
                          model: m4Translation(spot.x, sh, spot.z))

                // Windows — emissive quads on front face
                let winCols = 2
                let winRows = spot.isChurch ? 2 : 1
                let winW = sw * 0.12, winH = sh * 0.13
                let amber: SIMD3<Float> = [0.95, 0.70, 0.30]

                for row in 0..<winRows {
                    for col in 0..<winCols {
                        let xFrac = (Float(col) + 1) / Float(winCols + 1)
                        let yFrac = (Float(row) + 1) / Float(winRows + 1)
                        let wx = spot.x + (xFrac - 0.5) * sw
                        let wy = yFrac * sh
                        let wz = spot.z + sd / 2 + 0.01

                        let idx = addGlow(
                            buildQuad(w: winW, h: winH,
                                      color: [amber.x, amber.y, amber.z, 1]),
                            model: m4Translation(wx, wy, wz),
                            emissive: amber, opacity: 0.9)
                        windows.append(WindowGlow(intensity: 1,
                                                   drawIndex: idx,
                                                   emissive: amber))
                    }
                }
            }
        }

        private func buildTrees() {
            var rng = SplitMix64(seed: 1351)
            let trunkCol: SIMD4<Float> = [0.18, 0.10, 0.05, 1]
            let leafCol:  SIMD4<Float> = [0.05, 0.14, 0.05, 1]

            for _ in 0..<12 {
                let tx = Float(Double.random(in: -6...6, using: &rng))
                let tz = Float(Double.random(in: -5...5, using: &rng))
                let ts = Float(0.5 + Double.random(in: 0...0.5, using: &rng))

                addOpaque(buildCylinder(radius: 0.06 * ts, height: 0.5 * ts,
                                        segments: 6, color: trunkCol),
                          model: m4Translation(tx, 0.25 * ts, tz))
                addOpaque(buildCone(radius: 0.4 * ts, height: 0.9 * ts,
                                    segments: 8, color: leafCol),
                          model: m4Translation(tx, 0.5 * ts + 0.45 * ts, tz))
            }
        }

        private func buildFireflies() {
            var rng = SplitMix64(seed: 1352)
            for _ in 0..<20 {
                let fx = Float(Double.random(in: -5...5, using: &rng))
                let fy = Float(0.5 + Double.random(in: 0...1.5, using: &rng))
                let fz = Float(Double.random(in: -4...4, using: &rng))
                fireflyPositions.append([fx, fy, fz])
                fireflyPhases.append(Float(Double.random(in: 0...(.pi * 2), using: &rng)))
            }
        }

        // MARK: - Tap interaction

        func extinguishNextWindow() {
            guard extinguishedCount < windows.count else { return }
            windows[extinguishedCount].intensity = -1
            extinguishedCount += 1

            let total = Float(windows.count)
            let remaining = max(0, total - Float(extinguishedCount))
            let frac = total > 0 ? remaining / total : 0
            ambientLevel = 0.15 + 0.85 * frac
            moonLevel    = 0.3  + 0.7  * frac
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

            // Animate window intensities
            for i in windows.indices {
                if windows[i].intensity < 0 {
                    windows[i].intensity += 0.008
                    if windows[i].intensity >= 0 { windows[i].intensity = 0 }
                }
            }

            // Orbiting camera — one revolution every 120s
            let orbitAngle = t * (2 * .pi / 120)
            let orbitR: Float = 11
            let camY: Float   = 7
            let eye = SIMD3<Float>(orbitR * sin(orbitAngle), camY,
                                   orbitR * cos(orbitAngle))
            let center = SIMD3<Float>(0, 0.5, 0)

            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 48 * .pi / 180, aspect: aspect,
                                      near: 0.1, far: 80)
            let vp = proj4 * view4

            let moonColor = SIMD3<Float>(0.40, 0.45, 0.70) * moonLevel
            let ambColor  = SIMD3<Float>(0.15, 0.12, 0.25) * ambientLevel

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([-0.3, -0.8, -0.4]), 0),
                sunColor:       SIMD4<Float>(moonColor, 0),
                ambientColor:   SIMD4<Float>(ambColor, t),
                fogParams:      SIMD4<Float>(12, 35, 0, 0),
                fogColor:       SIMD4<Float>([0.03, 0.03, 0.06], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model)
            }

            // Glow pass (windows)
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                for (i, call) in transparentCalls.enumerated() {
                    if let win = windows.first(where: { $0.drawIndex == i }) {
                        let bright = max(0, win.intensity)
                        guard bright > 0.001 else { continue }
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: call.buffer, vertexCount: call.count,
                                   model: call.model,
                                   emissiveColor: call.emissiveCol * bright,
                                   emissiveMix: 1,
                                   opacity: call.opacity * bright)
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

            // Firefly particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for i in fireflyPositions.indices {
                    let ph = fireflyPhases[i]
                    let drift: Float = 0.4
                    let fx = fireflyPositions[i].x + drift * sin(t * 0.7 + ph)
                    let fy = fireflyPositions[i].y + 0.2 * cos(t * 0.5 + ph * 1.3)
                    let fz = fireflyPositions[i].z + drift * cos(t * 0.6 + ph * 0.8)
                    let bright = 0.4 + 0.6 * abs(sin(t * 1.2 + ph))
                    let col = SIMD4<Float>(0.9 * bright, 0.8 * bright,
                                           0.3 * bright, 0.85 * bright)
                    particles.append(ParticleVertex3D(position: [fx, fy, fz],
                                                       color: col, size: 5))
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
        view.clearColor              = MTLClearColor(red: 0.015, green: 0.015,
                                                      blue: 0.04, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.extinguishNextWindow()
    }
}
