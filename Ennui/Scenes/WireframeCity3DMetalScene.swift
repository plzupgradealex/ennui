// WireframeCity3DMetalScene — Green phosphor wireframe city flyover.
// Glowing green buildings on pure black, scrolling grid floor, like an early
// 1980s vector display / CAD terminal. Tap for a radar pulse flash.
// Rendered in Metal (MTKView) — no SceneKit. Seed 1983.

import SwiftUI
import MetalKit

struct WireframeCity3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        WireframeCity3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct WireframeCity3DMetalRepresentable: NSViewRepresentable {
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

        // Grid floor bars (scrolling)
        struct GridBar {
            var buffer: MTLBuffer; var count: Int; var baseZ: Float; var isX: Bool
        }
        var gridBarsZ: [GridBar] = []      // bars along X axis (scroll in Z)
        var gridBarsX: [GridBar] = []      // bars along Z axis (static or slow drift)

        // Building data for flash effect (indices in opaqueCalls)
        var buildingStartIdx: Int = 0
        var buildingCount: Int = 0

        // Antenna spires (glowCalls indices)
        var antennaIndices: [Int] = []

        // HUD bars (glowCalls indices)
        var hudIndices: [Int] = []

        // Tap flash
        var flashT: Float = -100

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
            } catch { print("WireframeCity3DMetal pipeline error: \(error)") }
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
            var rng = SplitMix64(seed: 1983)

            let greenDark:  SIMD4<Float> = [0.01, 0.04, 0.01, 1]
            let greenBright: SIMD3<Float> = [0.12, 0.92, 0.30]
            let greenDim:    SIMD3<Float> = [0.06, 0.50, 0.15]

            // ── Ground plane (very dark) ──
            addOpaque(buildPlane(w: 80, d: 80, color: [0.005, 0.01, 0.005, 1]),
                      model: matrix_identity_float4x4,
                      emissive: [0.01, 0.05, 0.01], mix: 0.1)

            // ── Grid bars along X (will scroll in Z) ──
            let gridCol: SIMD4<Float> = [0.02, 0.08, 0.02, 1]
            let gridBarVerts = buildBox(w: 60, h: 0.015, d: 0.03, color: gridCol)
            for i in 0..<30 {
                let z = Float(i) * 2.0 - 30.0
                if let buf = makeVertexBuffer(gridBarVerts, device: device) {
                    gridBarsZ.append(GridBar(buffer: buf, count: gridBarVerts.count,
                                             baseZ: z, isX: false))
                }
            }

            // ── Grid bars along Z (static) ──
            let gridBarVertsZ = buildBox(w: 0.03, h: 0.015, d: 60, color: gridCol)
            for i in 0..<30 {
                let x = Float(i) * 2.0 - 30.0
                if let buf = makeVertexBuffer(gridBarVertsZ, device: device) {
                    gridBarsX.append(GridBar(buffer: buf, count: gridBarVertsZ.count,
                                              baseZ: x, isX: true))
                }
            }

            // ── Buildings ──
            buildingStartIdx = opaqueCalls.count

            // Near buildings (close to camera path)
            for _ in 0..<20 {
                let bx = Float(Double.random(in: -5.0...5.0, using: &rng))
                let bz = Float(Double.random(in: -12.0 ... -2.0, using: &rng))
                let bw = Float(0.6 + Double.random(in: 0...1.0, using: &rng))
                let bh = Float(1.0 + Double.random(in: 0...5.0, using: &rng))
                let bd = Float(0.6 + Double.random(in: 0...1.0, using: &rng))
                let mix: Float = Float(0.8 + Double.random(in: 0...0.2, using: &rng))
                addOpaque(buildBox(w: bw, h: bh, d: bd, color: greenDark),
                          model: m4Translation(bx, bh * 0.5, bz),
                          emissive: greenBright, mix: mix)
            }

            // Mid-distance buildings
            for _ in 0..<25 {
                let bx = Float(Double.random(in: -14.0...14.0, using: &rng))
                let bz = Float(Double.random(in: -25.0 ... -10.0, using: &rng))
                let bw = Float(0.8 + Double.random(in: 0...1.5, using: &rng))
                let bh = Float(1.5 + Double.random(in: 0...8.0, using: &rng))
                let bd = Float(0.8 + Double.random(in: 0...1.5, using: &rng))
                let mix: Float = Float(0.7 + Double.random(in: 0...0.3, using: &rng))
                addOpaque(buildBox(w: bw, h: bh, d: bd, color: greenDark),
                          model: m4Translation(bx, bh * 0.5, bz),
                          emissive: greenBright, mix: mix)
            }

            // Far buildings (skyline)
            for _ in 0..<15 {
                let bx = Float(Double.random(in: -20.0...20.0, using: &rng))
                let bz = Float(Double.random(in: -40.0 ... -22.0, using: &rng))
                let bw = Float(1.0 + Double.random(in: 0...2.0, using: &rng))
                let bh = Float(2.0 + Double.random(in: 0...12.0, using: &rng))
                let bd = Float(1.0 + Double.random(in: 0...2.0, using: &rng))
                addOpaque(buildBox(w: bw, h: bh, d: bd, color: greenDark),
                          model: m4Translation(bx, bh * 0.5, bz),
                          emissive: greenDim, mix: 0.9)
            }

            buildingCount = opaqueCalls.count - buildingStartIdx

            // ── Antenna spires on ~10 buildings ──
            for _ in 0..<10 {
                let ax = Float(Double.random(in: -12.0...12.0, using: &rng))
                let az = Float(Double.random(in: -30.0 ... -5.0, using: &rng))
                let baseH = Float(3.0 + Double.random(in: 0...8.0, using: &rng))
                let spireH = Float(0.8 + Double.random(in: 0...1.5, using: &rng))
                antennaIndices.append(glowCalls.count)
                addGlow(buildCylinder(radius: 0.03, height: spireH, segments: 4,
                                      color: [0.02, 0.10, 0.03, 1]),
                        model: m4Translation(ax, baseH + spireH * 0.5, az),
                        emissive: greenBright, mix: 1.0, opacity: 0.7)
                // Tip light
                addGlow(buildSphere(radius: 0.05, rings: 3, segments: 4,
                                    color: [0.10, 0.80, 0.25, 1]),
                        model: m4Translation(ax, baseH + spireH, az),
                        emissive: [0.15, 1.0, 0.35], mix: 1.0, opacity: 0.6)
            }

            // ── Pyramid caps on ~6 buildings ──
            for _ in 0..<6 {
                let px = Float(Double.random(in: -10.0...10.0, using: &rng))
                let pz = Float(Double.random(in: -25.0 ... -5.0, using: &rng))
                let baseH = Float(2.0 + Double.random(in: 0...6.0, using: &rng))
                let capW = Float(0.8 + Double.random(in: 0...0.8, using: &rng))
                addOpaque(buildPyramid(bw: capW, bd: capW, h: 0.8,
                                       color: greenDark),
                          model: m4Translation(px, baseH, pz),
                          emissive: greenBright, mix: 0.85)
            }

            // ── HUD: thin scanning bars near camera (world space) ──
            hudIndices.append(glowCalls.count)
            addGlow(buildBox(w: 0.01, h: 3.0, d: 0.01, color: [0.02, 0.10, 0.03, 1]),
                    model: m4Translation(-4.5, 4.0, 2.0),
                    emissive: greenDim, mix: 1.0, opacity: 0.25)
            hudIndices.append(glowCalls.count)
            addGlow(buildBox(w: 0.01, h: 3.0, d: 0.01, color: [0.02, 0.10, 0.03, 1]),
                    model: m4Translation(4.5, 4.0, 2.0),
                    emissive: greenDim, mix: 1.0, opacity: 0.25)
            // Horizontal scan line
            hudIndices.append(glowCalls.count)
            addGlow(buildBox(w: 9.0, h: 0.01, d: 0.01, color: [0.02, 0.10, 0.03, 1]),
                    model: m4Translation(0, 5.5, 2.0),
                    emissive: greenDim, mix: 1.0, opacity: 0.2)
        }

        func handleTap() {
            flashT = Float(CACurrentMediaTime() - startTime)
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
            let flashFade = max(0, 1 - (t - flashT) / 1.5)

            // Camera — elevated, looking down at city, gentle lateral sway
            let swayX = 1.5 * sin(t * 0.08)
            let swayZ = 0.8 * sin(t * 0.06)
            let eye: SIMD3<Float> = [swayX, 8.0, 5.0 + swayZ]
            let center: SIMD3<Float> = [swayX * 0.5, 0, -8.0 + swayZ * 0.3]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 70 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            // Black environment — all visuals from emissive
            let sunDir: SIMD3<Float> = simd_normalize([0, -1, 0])
            let sunCol: SIMD3<Float> = [0.03, 0.08, 0.03]
            let ambCol: SIMD3<Float> = [0.01, 0.03, 0.01]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(25, 55, 0, 0),
                fogColor:       SIMD4<Float>(0, 0, 0, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Grid bars (scrolling Z)
            let gridSpeed: Float = 1.2
            for bar in gridBarsZ {
                let z = fmod(bar.baseZ + t * gridSpeed, 60.0) - 30.0
                let model = m4Translation(0, 0.008, z)
                encodeDraw(encoder: encoder,
                           vertexBuffer: bar.buffer, vertexCount: bar.count,
                           model: model,
                           emissiveColor: [0.05, 0.35, 0.10], emissiveMix: 0.9)
            }

            // Grid bars (static X lines)
            for bar in gridBarsX {
                let model = m4Translation(bar.baseZ, 0.008, 0)
                encodeDraw(encoder: encoder,
                           vertexBuffer: bar.buffer, vertexCount: bar.count,
                           model: model,
                           emissiveColor: [0.05, 0.35, 0.10], emissiveMix: 0.9)
            }

            // Static opaque geometry (ground + buildings)
            let flashBoost: Float = flashFade * 0.6
            for (i, call) in opaqueCalls.enumerated() {
                var em = call.emissiveCol
                var mix = call.emissiveMix
                // Flash effect on buildings
                if i >= buildingStartIdx && i < buildingStartIdx + buildingCount {
                    em = em * (1 + flashBoost)
                    mix = min(1, mix + flashBoost * 0.3)
                }
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: em, emissiveMix: mix)
            }

            // Glow pass — antennas, HUD
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for (i, call) in glowCalls.enumerated() {
                    var em = call.emissiveCol
                    var op = call.opacity

                    // Antenna tip lights blink
                    if antennaIndices.contains(i) {
                        let blink = 0.5 + 0.5 * sin(t * 2.0 + Float(i) * 1.3)
                        em = em * blink
                        op = op * blink
                    }

                    // HUD scanline flickers
                    if hudIndices.contains(i) {
                        let flicker = 0.6 + 0.4 * abs(sin(t * 1.5 + Float(i) * 0.5))
                        op = op * flicker
                    }

                    // Flash boost on everything
                    em = em * (1 + flashBoost * 0.5)

                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: em, emissiveMix: call.emissiveMix,
                               opacity: min(1, op))
                }
            }

            // Particle pass — drifting data motes, scan dots
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Drifting green data motes
                var moteRng = SplitMix64(seed: 2001)
                for i in 0..<30 {
                    let phase = Float(i) * 0.7
                    let mx = Float(Double.random(in: -8.0...8.0, using: &moteRng))
                    let my = Float(0.5 + Double.random(in: 0...6.0, using: &moteRng))
                    let mz = Float(Double.random(in: -18.0...0.0, using: &moteRng))
                    let wx = mx + 0.5 * sin(t * 0.1 + phase)
                    let wy = my + 0.3 * sin(t * 0.15 + phase * 0.6)
                    let wz = mz + 0.4 * cos(t * 0.12 + phase)
                    let pulse = 0.2 + 0.3 * abs(sin(t * 0.8 + phase))
                    particles.append(ParticleVertex3D(
                        position: [wx, wy, wz],
                        color: [0.10, 0.85, 0.25, pulse], size: 3))
                }

                // Radar sweep particles on tap
                if flashFade > 0 {
                    let sweepAngle = (t - flashT) * 4.0
                    for i in 0..<20 {
                        let r = Float(i) * 1.2 + 0.5
                        let a = sweepAngle + Float(i) * 0.02
                        let px = r * cos(a) + swayX * 0.5
                        let pz = -8.0 + r * sin(a) + swayZ * 0.3
                        let alpha = flashFade * max(0, 1 - Float(i) * 0.04)
                        particles.append(ParticleVertex3D(
                            position: [px, 0.05, pz],
                            color: [0.15, 1.0, 0.35, alpha], size: 4))
                    }
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
        view.clearColor               = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
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
