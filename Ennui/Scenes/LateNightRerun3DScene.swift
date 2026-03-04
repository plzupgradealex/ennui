// LateNightRerun3DScene — Metal 3D nineties bedroom scene.
// First-person view from bed. CRT TV flickers coloured light across walls.
// Glow-in-the-dark stars on the ceiling. Lava lamp pulses. Pan to look around.
// Tap to change the channel. Rendered entirely in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct LateNightRerun3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        LateNightRerun3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct LateNightRerun3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // MARK: Coordinator / Renderer

    final class Coordinator: NSObject, MTKViewDelegate {

        // MARK: Metal core
        let device:         MTLDevice
        let commandQueue:   MTLCommandQueue
        var opaquePipeline: MTLRenderPipelineState?
        var glowPipeline:   MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:     MTLDepthStencilState?
        var depthROState:   MTLDepthStencilState?

        // MARK: Channel colours (TV)
        let channelColors: [SIMD3<Float>] = [
            [0.30, 0.35, 0.80],   // Late-show blue
            [0.20, 0.20, 0.20],   // Static grey
            [0.80, 0.75, 0.20],   // Colour bars
            [0.12, 0.45, 0.12],   // X-Files green
            [0.75, 0.50, 0.20],   // Poirot warm
        ]
        var channel = 0
        var tvColor: SIMD3<Float> = [0.30, 0.35, 0.80]
        var targetTvColor: SIMD3<Float> = [0.30, 0.35, 0.80]

        // MARK: Scene geometry
        struct DrawCall {
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // TV screen buffer (needs colour update each frame for channel shimmer)
        var tvScreenBuffer:   MTLBuffer?
        var tvScreenCount = 0

        // Lava lamp blobs
        var lavaPhases: [Float] = []
        var lavaColors: [SIMD3<Float>] = []

        // Ceiling star positions
        var starPositions: [SIMD3<Float>] = []
        var starPhases:    [Float] = []

        // MARK: Camera look-around (pan gesture)
        var camYaw:   Float = 0   // radians, horizontal
        var camPitch: Float = 0   // radians, vertical

        // MARK: Animation
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var lastTapCount = 0
        var aspect: Float = 1

        // MARK: - Init

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch {
                print("LateNightRerun3D Metal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build scene geometry

        private func buildScene() {
            buildRoom()
            buildTV()
            buildFurniture()
            buildDecorations()
            buildLavaLamp()
            buildCeilingStars()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                        emissiveCol: emissive, emissiveMix: mix))
        }

        private func addGlow(_ v: [Vertex3D], model: simd_float4x4,
                              emissive: SIMD3<Float>, opacity: Float = 0.9) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            transparentCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                             emissiveCol: emissive, emissiveMix: 1.0,
                                             opacity: opacity))
        }

        private func buildRoom() {
            let wallCol: SIMD4<Float>   = [0.10, 0.08, 0.13, 1]
            let floorCol: SIMD4<Float>  = [0.14, 0.09, 0.07, 1]
            let ceilCol: SIMD4<Float>   = [0.07, 0.06, 0.09, 1]

            // Floor (plane)
            addOpaque(buildPlane(w: 6, d: 6, color: floorCol),
                      model: matrix_identity_float4x4)

            // Back wall (facing +Z toward camera)
            addOpaque(buildQuad(w: 6, h: 3, color: wallCol, normal: [0, 0, 1]),
                      model: m4Translation(0, 1.5, -3))

            // Left wall
            addOpaque(buildQuad(w: 6, h: 3, color: wallCol, normal: [1, 0, 0]),
                      model: m4Translation(-3, 1.5, 0) * m4RotY(.pi/2))

            // Right wall
            addOpaque(buildQuad(w: 6, h: 3, color: wallCol, normal: [-1, 0, 0]),
                      model: m4Translation(3, 1.5, 0) * m4RotY(-.pi/2))

            // Ceiling
            addOpaque(buildQuad(w: 6, h: 6, color: ceilCol, normal: [0, -1, 0]),
                      model: m4Translation(0, 3, 0) * m4RotX(-.pi/2))
        }

        private func buildTV() {
            // TV stand / dresser
            addOpaque(buildBox(w: 1.2, h: 0.5, d: 0.6, color: [0.18, 0.12, 0.08, 1]),
                      model: m4Translation(0, 0.25, -2.6))

            // VHS tapes on dresser
            let tapeColors: [SIMD4<Float>] = [
                [0.10, 0.10, 0.12, 1], [0.12, 0.08, 0.06, 1], [0.07, 0.07, 0.10, 1]
            ]
            for (i, col) in tapeColors.enumerated() {
                addOpaque(buildBox(w: 0.19, h: 0.03, d: 0.12, color: col),
                          model: m4Translation(0.42, 0.52 + Float(i)*0.035, -2.55)
                            * m4RotY(Float(i)*0.08 - 0.04))
            }

            // CRT body
            addOpaque(buildBox(w: 0.70, h: 0.55, d: 0.50, color: [0.08, 0.07, 0.07, 1]),
                      model: m4Translation(0, 0.78, -2.6))

            // TV screen (emissive, updated each frame)
            let screenVerts = buildQuad(w: 0.52, h: 0.38, color: [1, 1, 1, 1])
            tvScreenBuffer = makeVertexBuffer(screenVerts, device: device)
            tvScreenCount  = screenVerts.count
        }

        private func buildFurniture() {
            let wood: SIMD4<Float> = [0.16, 0.10, 0.07, 1]

            // Mattress
            addOpaque(buildBox(w: 1.8, h: 0.25, d: 2.0, color: [0.25, 0.12, 0.10, 1]),
                      model: m4Translation(0, 0.3, 1.0))
            // Bed frame
            addOpaque(buildBox(w: 1.9, h: 0.15, d: 2.1, color: wood),
                      model: m4Translation(0, 0.1, 1.0))
            // Pillow
            addOpaque(buildBox(w: 0.5, h: 0.10, d: 0.35, color: [0.85, 0.80, 0.75, 1]),
                      model: m4Translation(0, 0.48, 1.7))
            // Nightstand
            addOpaque(buildBox(w: 0.4, h: 0.5, d: 0.35, color: wood),
                      model: m4Translation(1.1, 0.25, 0.8))
            // Alarm clock
            addOpaque(buildBox(w: 0.10, h: 0.07, d: 0.05, color: [0.06, 0.06, 0.06, 1]),
                      model: m4Translation(1.05, 0.535, 0.75))
            // Clock face (red LED glow)
            addGlow(buildQuad(w: 0.07, h: 0.035, color: [1, 1, 1, 1]),
                    model: m4Translation(1.05, 0.535, 0.73),
                    emissive: [0.9, 0.15, 0.1])
        }

        private func buildDecorations() {
            // Posters on left wall
            addGlow(buildQuad(w: 0.5, h: 0.7, color: [1,1,1,1]),
                    model: m4Translation(-2.99, 1.6, -0.5) * m4RotY(.pi/2),
                    emissive: [0.06, 0.04, 0.07], opacity: 0.7)
            addGlow(buildQuad(w: 0.35, h: 0.5, color: [1,1,1,1]),
                    model: m4Translation(-2.99, 1.5,  0.8) * m4RotY(.pi/2),
                    emissive: [0.04, 0.03, 0.06], opacity: 0.7)

            // Bookshelf on right wall
            addOpaque(buildBox(w: 0.8, h: 0.03, d: 0.2, color: [0.14, 0.09, 0.06, 1]),
                      model: m4Translation(2.88, 1.3, 0))
            // Books
            let bookCols: [SIMD4<Float>] = [
                [0.15, 0.08, 0.06, 1], [0.08, 0.06, 0.14, 1], [0.06, 0.12, 0.06, 1],
                [0.14, 0.10, 0.04, 1], [0.10, 0.04, 0.04, 1],
            ]
            var bx: Float = 2.62
            var rng = SplitMix64(seed: 9900)
            for col in bookCols {
                let bw = Float(0.04 + Double.random(in: 0...0.04, using: &rng))
                let bh = Float(0.15 + Double.random(in: 0...0.07, using: &rng))
                addOpaque(buildBox(w: bw, h: bh, d: 0.12, color: col),
                          model: m4Translation(bx + bw/2, 1.315 + bh/2, 0))
                bx += bw + 0.01
            }

            // Rug
            addOpaque(buildBox(w: 1.5, h: 0.005, d: 1.0, color: [0.30, 0.12, 0.12, 1]),
                      model: m4Translation(0, 0.003, -0.5))

            // Window (right wall, moonlit blue glow)
            addGlow(buildQuad(w: 0.65, h: 0.90, color: [1,1,1,1]),
                    model: m4Translation(2.99, 1.5, -1.5) * m4RotY(-.pi/2),
                    emissive: [0.08, 0.14, 0.40], opacity: 0.8)

            // String lights along ceiling edge
            var rng2 = SplitMix64(seed: 9901)
            for i in 0..<18 {
                let t = Float(i) / 17.0
                let x = -2.7 + t * 5.4
                let brightness = Float(0.7 + Double.random(in: 0...0.3, using: &rng2))
                let r = Float(0.9 + Double.random(in: 0...0.1, using: &rng2))
                let g = Float(0.5 + Double.random(in: 0...0.4, using: &rng2))
                let b = Float(0.2 + Double.random(in: 0...0.3, using: &rng2))
                addGlow(buildSphere(radius: 0.04, rings: 4, segments: 6, color: [1,1,1,1]),
                        model: m4Translation(x, 2.9, -2.9),
                        emissive: [r*brightness, g*brightness, b*brightness], opacity: 0.8)
            }
        }

        private func buildLavaLamp() {
            // Lava lamp body (tall cylinder)
            addOpaque(buildCylinder(radius: 0.07, height: 0.35, segments: 12,
                                    color: [0.08, 0.05, 0.06, 1]),
                      model: m4Translation(-1.1, 0.67, -2.55))
            // Base
            addOpaque(buildCylinder(radius: 0.09, height: 0.04, segments: 12,
                                    color: [0.15, 0.10, 0.06, 1]),
                      model: m4Translation(-1.1, 0.5, -2.55))
            // Outer glow (orange-red, updated each frame via draw)
            // stored as a transparent call so we can vary colour
            let lampGlow = buildSphere(radius: 0.08, rings: 6, segments: 8, color: [1,1,1,1])
            if let buf = makeVertexBuffer(lampGlow, device: device) {
                transparentCalls.append(DrawCall(buffer: buf, count: lampGlow.count,
                                                 model: m4Translation(-1.1, 0.67, -2.55),
                                                 emissiveCol: [0.9, 0.3, 0.1],
                                                 emissiveMix: 1.0, opacity: 0.5))
            }

            // Lava blob phases
            var rng = SplitMix64(seed: 9902)
            for _ in 0..<5 {
                lavaPhases.append(Float(Double.random(in: 0...2*Double.pi, using: &rng)))
                let r = Float(0.8 + Double.random(in: 0...0.2, using: &rng))
                let g = Float(0.1 + Double.random(in: 0...0.2, using: &rng))
                lavaColors.append([r, g, 0.05])
            }
        }

        private func buildCeilingStars() {
            var rng = SplitMix64(seed: 9903)
            for _ in 0..<40 {
                let sx = Float(Double.random(in: -2.8...2.8, using: &rng))
                let sz = Float(Double.random(in: -2.8...2.8, using: &rng))
                starPositions.append([sx, 2.95, sz])
                starPhases.append(Float(Double.random(in: 0...2*Double.pi, using: &rng)))
            }
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline    = opaquePipeline,
                  let drawable    = view.currentDrawable,
                  let rpDesc      = view.currentRenderPassDescriptor,
                  let cmdBuf      = commandQueue.makeCommandBuffer(),
                  let encoder     = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Lerp TV colour toward target (channel change)
            tvColor = tvColor + (targetTvColor - tvColor) * 0.12

            // TV shimmer (subtle animated colour on current channel base)
            let shimR = tvColor.x + 0.04 * sin(t * 4.5)
            let shimG = tvColor.y + 0.03 * cos(t * 3.2)
            let shimB = tvColor.z + 0.05 * sin(t * 5.8)
            let shimCol = SIMD3<Float>(max(0, shimR), max(0, shimG), max(0, shimB))

            // TV flicker intensity
            let flicker = 0.85 + 0.15 * abs(sin(t * 23.7 + 1.3))

            // Camera — look-around from bed, eye at ~(0, 0.55, 1.8)
            let eye: SIMD3<Float>    = [0, 0.55, 1.8]
            let camRot = m4RotX(-camPitch) * m4RotY(-camYaw)
            let forward: SIMD3<Float> = simd_normalize((camRot * SIMD4<Float>(0, 0, -1, 0)).xyz)
            let view4 = m4LookAt(eye: eye, center: eye + forward, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 70 * .pi / 180, aspect: aspect, near: 0.05, far: 20)
            let vp    = proj4 * view4

            // Sun = TV as the dominant coloured light source, no fog in small room
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>([0, 0, 1], 0),  // from behind camera (facing TV)
                sunColor:       SIMD4<Float>(shimCol * flicker * 0.6, 0),
                ambientColor:   SIMD4<Float>(shimCol * flicker * 0.15, t),
                fogParams:      SIMD4<Float>(18, 40, 0, 0),   // fog far away — no fog in room
                fogColor:       SIMD4<Float>(0.05, 0.04, 0.07, 0),
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
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // TV screen (emissive with shimmer)
            if let scBuf = tvScreenBuffer {
                encodeDraw(encoder: encoder,
                           vertexBuffer: scBuf, vertexCount: tvScreenCount,
                           model: m4Translation(0, 0.78, -2.34),
                           emissiveColor: shimCol * flicker,
                           emissiveMix: 1.0)
            }

            // Transparent / glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                // Static transparent draw calls (window, posters, string lights, etc.)
                for call in transparentCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }

                // Lava lamp blobs (animated)
                for i in lavaPhases.indices {
                    let ph = lavaPhases[i]
                    let blobY = -1.1 + sin(t * 0.5 + ph) * 0.10
                    let blobX = Float(-1.1) + cos(t * 0.3 + ph) * 0.03
                    let blobGlow = lavaColors[i] * (0.6 + 0.4 * abs(sin(t * 0.7 + ph)))
                    let blobVerts = buildSphere(radius: 0.025, rings: 4, segments: 6, color: [1,1,1,1])
                    if let buf = makeVertexBuffer(blobVerts, device: device) {
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: buf, vertexCount: blobVerts.count,
                                   model: m4Translation(blobX, 0.67 + blobY, -2.55),
                                   emissiveColor: blobGlow, emissiveMix: 1.0, opacity: 0.7)
                    }
                }
            }

            // Ceiling stars (glowing point sprites)
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for i in starPositions.indices {
                    let ph = starPhases[i]
                    let bright = (0.5 + 0.5 * sin(t * 0.4 + ph)) * 0.8
                    let col: SIMD4<Float> = [0.3 * Float(bright), 0.85 * Float(bright),
                                              0.4 * Float(bright), Float(bright)]
                    particles.append(ParticleVertex3D(position: starPositions[i],
                                                      color: col, size: 5))
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

        // MARK: - Gesture handler

        @objc func handlePan(_ g: NSPanGestureRecognizer) {
            let sensitivity: Float = 0.003
            let d = g.translation(in: g.view)
            camYaw   -= Float(d.x) * sensitivity
            camPitch -= Float(d.y) * sensitivity
            camYaw   = max(-.pi * 0.38, min(.pi * 0.38, camYaw))
            camPitch = max(-0.44, min(0.70, camPitch))
            g.setTranslation(.zero, in: g.view)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate              = context.coordinator
        view.colorPixelFormat      = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor            = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable    = true

        let pan = NSPanGestureRecognizer(target: context.coordinator,
                                         action: #selector(Coordinator.handlePan(_:)))
        view.addGestureRecognizer(pan)
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount   = interaction.tapCount
        c.channel        = (c.channel + 1) % c.channelColors.count
        c.targetTvColor  = c.channelColors[c.channel]
    }
}
