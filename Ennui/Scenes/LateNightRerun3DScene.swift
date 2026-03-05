// LateNightRerun3DScene — Metal 3D first-person bedroom at night.
// View from bed. CRT TV flickers colored light across the walls. Lava lamp
// glows. Glow-in-the-dark stars on ceiling. String lights along the back wall.
// Tap to change the channel. Drag to look around. Rendered in Metal (MTKView).

import SwiftUI
import MetalKit

struct LateNightRerun3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        LateNightRerun3DRepresentable(interaction: interaction,
                                       tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct LateNightRerun3DRepresentable: NSViewRepresentable {
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

        // MARK: TV state
        var channel = 0
        let channelColors: [SIMD3<Float>] = [
            [0.30, 0.35, 0.80],  // Late show blue
            [0.20, 0.20, 0.20],  // Static gray
            [0.80, 0.75, 0.20],  // Color bars
            [0.12, 0.45, 0.12],  // X-Files green
            [0.75, 0.50, 0.20],  // Poirot warm
        ]
        var tvScreenDrawIndex: Int = -1
        var staticFlashTime: Float = -999

        // MARK: String light positions
        struct StringLight {
            var position: SIMD3<Float>
            var hue: Float
            var phase: Float
        }
        var stringLights: [StringLight] = []

        // MARK: Ceiling stars
        var starPositions: [SIMD3<Float>] = []

        // MARK: Rain streak state
        struct RainStreak {
            var z: Float; var startY: Float; var len: Float; var speed: Float
        }
        var rainStreaks: [RainStreak] = []

        // MARK: Camera look-around
        var camYaw:   Float = 0
        var camPitch: Float = 0

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
            buildRoom()
            buildTV()
            buildFurniture()
            buildWindow()
            buildStringLights()
            buildLavaLamp()
            buildDecorations()
            buildCeilingStars()
            buildRainStreaks()
        }

        private func buildRoom() {
            let wallCol: SIMD4<Float>  = [0.10, 0.08, 0.13, 1]
            let floorCol: SIMD4<Float> = [0.14, 0.09, 0.07, 1]
            let ceilCol: SIMD4<Float>  = [0.07, 0.06, 0.09, 1]

            // Floor
            addOpaque(buildPlane(w: 6, d: 6, color: floorCol),
                      model: matrix_identity_float4x4)
            // Back wall
            addOpaque(buildQuad(w: 6, h: 3, color: wallCol),
                      model: m4Translation(0, 1.5, -3))
            // Left wall
            addOpaque(buildQuad(w: 6, h: 3, color: wallCol),
                      model: m4Translation(-3, 1.5, 0) * m4RotY(.pi / 2))
            // Right wall
            addOpaque(buildQuad(w: 6, h: 3, color: wallCol),
                      model: m4Translation(3, 1.5, 0) * m4RotY(-.pi / 2))
            // Ceiling
            addOpaque(buildQuad(w: 6, h: 6, color: ceilCol),
                      model: m4Translation(0, 3, 0) * m4RotX(.pi / 2))
        }

        private func buildTV() {
            let woodCol: SIMD4<Float> = [0.18, 0.12, 0.08, 1]

            // TV stand / dresser
            addOpaque(buildBox(w: 1.2, h: 0.5, d: 0.6, color: woodCol),
                      model: m4Translation(0, 0.25, -2.6))

            // VHS tapes
            let tapeColors: [SIMD4<Float>] = [
                [0.10, 0.10, 0.12, 1],
                [0.12, 0.08, 0.06, 1],
                [0.07, 0.07, 0.10, 1],
            ]
            for (i, col) in tapeColors.enumerated() {
                addOpaque(buildBox(w: 0.19, h: 0.03, d: 0.12, color: col),
                          model: m4Translation(0.42, 0.52 + Float(i) * 0.035, -2.55)
                                 * m4RotY(Float(i) * 0.08 - 0.04))
                // Label sticker
                addGlow(buildQuad(w: 0.12, h: 0.02, color: [1, 1, 1, 1]),
                        model: m4Translation(0.42, 0.52 + Float(i) * 0.035, -2.49),
                        emissive: [0.7, 0.65, 0.55], opacity: 0.3)
            }

            // CRT body
            addOpaque(buildBox(w: 0.7, h: 0.55, d: 0.5, color: [0.08, 0.07, 0.07, 1]),
                      model: m4Translation(0, 0.78, -2.6))

            // TV screen (emissive)
            tvScreenDrawIndex = addGlow(
                buildQuad(w: 0.52, h: 0.38, color: [1, 1, 1, 1]),
                model: m4Translation(0, 0.78, -2.34),
                emissive: channelColors[0], opacity: 0.95)
        }

        private func buildFurniture() {
            let woodCol: SIMD4<Float> = [0.16, 0.10, 0.07, 1]

            // Bed mattress
            addOpaque(buildBox(w: 1.8, h: 0.25, d: 2.0,
                               color: [0.25, 0.12, 0.10, 1]),
                      model: m4Translation(0, 0.3, 1.0))
            // Bed frame
            addOpaque(buildBox(w: 1.9, h: 0.15, d: 2.1, color: woodCol),
                      model: m4Translation(0, 0.1, 1.0))
            // Pillow
            addOpaque(buildBox(w: 0.5, h: 0.1, d: 0.35,
                               color: [0.85, 0.80, 0.75, 1]),
                      model: m4Translation(0, 0.48, 1.7))

            // Nightstand
            addOpaque(buildBox(w: 0.4, h: 0.5, d: 0.35, color: woodCol),
                      model: m4Translation(1.1, 0.25, 0.8))
            // Alarm clock
            addOpaque(buildBox(w: 0.1, h: 0.07, d: 0.05,
                               color: [0.06, 0.06, 0.06, 1]),
                      model: m4Translation(1.05, 0.535, 0.75))
            // Clock display (red LED)
            addGlow(buildQuad(w: 0.07, h: 0.035, color: [1, 1, 1, 1]),
                    model: m4Translation(1.05, 0.535, 0.73),
                    emissive: [0.9, 0.15, 0.1], opacity: 0.9)

            // Rug
            addOpaque(buildBox(w: 1.5, h: 0.005, d: 1.0,
                               color: [0.30, 0.12, 0.12, 1]),
                      model: m4Translation(0, 0.003, -0.5))
        }

        private func buildWindow() {
            // Window on right wall
            let wx: Float = 2.99, wy: Float = 1.5, wz: Float = -1.5
            let wW: Float = 0.65, wH: Float = 0.90

            // Glass pane (emissive night-sky blue)
            addGlow(buildQuad(w: wW, h: wH, color: [1, 1, 1, 1]),
                    model: m4Translation(wx, wy, wz) * m4RotY(-.pi / 2),
                    emissive: [0.08, 0.14, 0.40], opacity: 0.7)

            // Window frame (dark wood boxes)
            let frameCol: SIMD4<Float> = [0.09, 0.06, 0.04, 1]
            let ft: Float = 0.025, fd: Float = 0.04
            // Top
            addOpaque(buildBox(w: fd, h: ft, d: wW + ft * 2, color: frameCol),
                      model: m4Translation(wx, wy + wH / 2 + ft / 2, wz))
            // Bottom
            addOpaque(buildBox(w: fd, h: ft, d: wW + ft * 2, color: frameCol),
                      model: m4Translation(wx, wy - wH / 2 - ft / 2, wz))
            // Left
            addOpaque(buildBox(w: fd, h: wH + ft * 2, d: ft, color: frameCol),
                      model: m4Translation(wx, wy, wz - wW / 2 - ft / 2))
            // Right
            addOpaque(buildBox(w: fd, h: wH + ft * 2, d: ft, color: frameCol),
                      model: m4Translation(wx, wy, wz + wW / 2 + ft / 2))
            // Horizontal divider
            addOpaque(buildBox(w: fd - 0.01, h: 0.015, d: wW, color: frameCol),
                      model: m4Translation(wx, wy, wz))
            // Vertical divider
            addOpaque(buildBox(w: fd - 0.01, h: wH, d: 0.015, color: frameCol),
                      model: m4Translation(wx, wy, wz))
            // Sill
            addOpaque(buildBox(w: 0.08, h: 0.03, d: wW + 0.1,
                               color: [0.12, 0.08, 0.05, 1]),
                      model: m4Translation(wx - 0.02, wy - wH / 2 - 0.015, wz))

            // Curtains (dark fabric quads pulled back)
            let curtainCol: SIMD4<Float> = [0.13, 0.07, 0.09, 1]
            for dz: Float in [-0.22, 0.22] {
                addOpaque(buildQuad(w: 0.26, h: wH + 0.2, color: curtainCol),
                          model: m4Translation(wx - 0.005, wy + 0.05, wz + dz)
                                 * m4RotY(-.pi / 2))
            }
        }

        private func buildStringLights() {
            var rng = SplitMix64(seed: 5555)
            let count = 14

            for i in 0..<count {
                let frac = Float(i) / Float(count - 1)
                let x    = -2.6 + frac * 5.2
                let sag  = 4 * frac * (1 - frac) * 0.18
                let y    = Float(2.97) - sag
                let z    = Float(-2.94)
                let hue  = Float(Double.random(in: 0.04...0.16, using: &rng))
                let phase = Float(Double.random(in: 0...(.pi * 2), using: &rng))

                stringLights.append(StringLight(position: [x, y, z],
                                                hue: hue, phase: phase))

                // Small bulb sphere glow
                addGlow(buildSphere(radius: 0.022, rings: 4, segments: 6,
                                    color: [1, 1, 1, 1]),
                        model: m4Translation(x, y, z),
                        emissive: hueToRGB(hue), opacity: 0.85)
            }
        }

        private func buildLavaLamp() {
            // Lamp body cylinder
            addOpaque(buildCylinder(radius: 0.06, height: 0.28, segments: 10,
                                    color: [0.12, 0.08, 0.12, 1]),
                      model: m4Translation(1.1, 0.64, 0.8))
            // Lava glow (emissive inner cylinder)
            addGlow(buildCylinder(radius: 0.045, height: 0.18, segments: 10,
                                  color: [1, 1, 1, 1]),
                    model: m4Translation(1.1, 0.64, 0.8),
                    emissive: [0.85, 0.25, 0.55], opacity: 0.85)
        }

        private func buildDecorations() {
            // Poster on left wall
            addGlow(buildQuad(w: 0.5, h: 0.7, color: [1, 1, 1, 1]),
                    model: m4Translation(-2.99, 1.6, -0.5) * m4RotY(.pi / 2),
                    emissive: [0.06, 0.04, 0.07], opacity: 0.5)
            // Second poster
            addGlow(buildQuad(w: 0.35, h: 0.5, color: [1, 1, 1, 1]),
                    model: m4Translation(-2.99, 1.5, 0.8) * m4RotY(.pi / 2),
                    emissive: [0.04, 0.03, 0.06], opacity: 0.4)
            // Bookshelf
            addOpaque(buildBox(w: 0.8, h: 0.03, d: 0.2,
                               color: [0.14, 0.09, 0.06, 1]),
                      model: m4Translation(2.88, 1.3, 0))

            // Books
            var rng = SplitMix64(seed: 6666)
            let bookColors: [SIMD4<Float>] = [
                [0.15, 0.08, 0.06, 1], [0.08, 0.06, 0.14, 1],
                [0.06, 0.12, 0.06, 1], [0.14, 0.10, 0.04, 1],
                [0.10, 0.04, 0.04, 1],
            ]
            var bx: Float = 2.88 - 0.3
            for col in bookColors {
                let bw = Float(0.04 + Double.random(in: 0...0.04, using: &rng))
                let bh = Float(0.15 + Double.random(in: 0...0.07, using: &rng))
                addOpaque(buildBox(w: bw, h: bh, d: 0.12, color: col),
                          model: m4Translation(bx + bw / 2, 1.3 + 0.015 + bh / 2, 0))
                bx += bw + 0.01
            }
        }

        private func buildCeilingStars() {
            var rng = SplitMix64(seed: 2001)
            for _ in 0..<25 {
                let sx = Float(-2.5 + Double.random(in: 0...5, using: &rng))
                let sz = Float(-2.5 + Double.random(in: 0...5, using: &rng))
                starPositions.append([sx, 2.99, sz])
            }
        }

        private func buildRainStreaks() {
            var rng = SplitMix64(seed: 9876)
            let wz: Float = -1.5, wW: Float = 0.65, wH: Float = 0.90
            let topY: Float = 1.5 + wH / 2 - 0.02
            for _ in 0..<18 {
                let z = (wz - wW / 2 + 0.03) +
                        Float(Double.random(in: 0...1, using: &rng)) *
                        (wW - 0.06)
                let startFrac = Float(Double.random(in: 0...1, using: &rng))
                let len   = Float(0.04 + Double.random(in: 0...0.07, using: &rng))
                let speed = Float(0.10 + Double.random(in: 0...0.12, using: &rng))
                rainStreaks.append(RainStreak(z: z, startY: topY - startFrac * wH,
                                              len: len, speed: speed))
            }
        }

        // MARK: - Color helper

        private func hueToRGB(_ h: Float) -> SIMD3<Float> {
            let r = abs(h * 6 - 3) - 1
            let g = 2 - abs(h * 6 - 2)
            let b = 2 - abs(h * 6 - 4)
            return SIMD3<Float>(min(max(r, 0), 1),
                                min(max(g, 0), 1),
                                min(max(b, 0), 1))
        }

        // MARK: - Tap interaction

        func changeChannel() {
            channel = (channel + 1) % channelColors.count
        }

        // MARK: - Pan gesture

        @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
            let sensitivity: Float = 0.003
            let delta = gesture.translation(in: gesture.view)
            camYaw  -= Float(delta.x) * sensitivity
            camPitch -= Float(delta.y) * sensitivity
            camYaw   = max(-.pi * 0.38, min(.pi * 0.38, camYaw))
            camPitch = max(-0.44, min(0.70, camPitch))
            gesture.setTranslation(.zero, in: gesture.view)
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

            // TV content shimmer
            let tvR = channelColors[channel].x + 0.08 * sin(t * 4.5)
            let tvG = channelColors[channel].y + 0.06 * cos(t * 3.2)
            let tvB = channelColors[channel].z + 0.10 * sin(t * 5.8)
            var tvColor = SIMD3<Float>(tvR, tvG, tvB)

            // Static flash on channel change
            let sincFlash = t - staticFlashTime
            if sincFlash < 0.12 {
                tvColor = [0.6, 0.6, 0.6]
            }

            // Update TV screen emissive color
            if tvScreenDrawIndex >= 0 && tvScreenDrawIndex < transparentCalls.count {
                transparentCalls[tvScreenDrawIndex].emissiveCol = tvColor
            }

            // Camera — lying in bed, propped up, with breathing sway and look-around
            let breathe: Float = 0.015 * sin(t * .pi / 4)
            let eyeY: Float = 0.75 + breathe
            let eye = SIMD3<Float>(0, eyeY, 1.5)

            // Look direction from yaw/pitch
            let lookX = sin(camYaw)
            let lookY = sin(camPitch)
            let lookZ = -cos(camYaw)
            let center = eye + SIMD3<Float>(lookX, lookY, lookZ)

            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect,
                                      near: 0.1, far: 20)
            let vp = proj4 * view4

            // Ambient from TV (dim, tinted by channel color)
            let tvAmbient = tvColor * 0.08

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(0, -1, 0, 0),
                sunColor:       SIMD4<Float>(tvColor * 0.15, 0),
                ambientColor:   SIMD4<Float>(tvAmbient + SIMD3<Float>(0.04, 0.03, 0.06), t),
                fogParams:      SIMD4<Float>(8, 20, 0, 0),
                fogColor:       SIMD4<Float>([0.02, 0.02, 0.03], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none) // room interior needs both sides visible
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
                for call in transparentCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            // Particles: ceiling stars, string light flicker, rain streaks
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Ceiling glow stars
                for pos in starPositions {
                    let bright = Float(0.3 + 0.15 * sin(Double(t) * 0.4 +
                                 Double(pos.x * 3 + pos.z * 7)))
                    let col = SIMD4<Float>(0.4 * bright, 0.9 * bright,
                                           0.4 * bright, bright)
                    particles.append(ParticleVertex3D(position: pos,
                                                       color: col, size: 4))
                }

                // String light sparkle
                for sl in stringLights {
                    let flicker = 0.85 + 0.15 *
                        sin(t / 2.5 * .pi * 3 + sl.phase)
                    let rgb = hueToRGB(sl.hue) * flicker
                    let col = SIMD4<Float>(rgb, flicker * 0.8)
                    particles.append(ParticleVertex3D(position: sl.position,
                                                       color: col, size: 6))
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
        view.clearColor              = MTLClearColor(red: 0, green: 0,
                                                      blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true

        // Pan gesture for look-around
        let pan = NSPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)

        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.staticFlashTime = Float(CACurrentMediaTime() - c.startTime)
        c.changeChannel()
    }
}
