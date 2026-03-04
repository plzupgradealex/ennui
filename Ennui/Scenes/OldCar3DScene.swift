// OldCar3DScene — Metal 3D view from inside a 1950s land yacht in a blizzard.
// Bench seat, wide windshield with sweeping wipers, amber dash glow, chrome
// radio knobs, snow rushing at the glass. Utility poles scroll past.
// Tap to flash the dash (horn honk). Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct OldCar3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        OldCar3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct OldCar3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

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
            var opacity:     Float = 1
        }
        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []

        // MARK: Wiper animation
        var wiperAngle: Float = 0        // oscillates between -0.6 and +0.6
        var wiperDir:   Float = 1

        // MARK: Dash brightness (tap to flash)
        var dashBrightness: Float = 1.0
        var dashTarget:     Float = 1.0
        var honkT:          Float = -999   // time of last honk

        // MARK: Snow particles
        var snowPositions: [SIMD3<Float>] = []
        var snowPhases:    [Float] = []
        var snowVelocities:[SIMD3<Float>] = []
        var snowSizes:     [Float] = []

        // MARK: Utility poles scroll
        var poleOffsets: [Float] = []

        // MARK: Interaction
        var lastTapCount = 0

        // MARK: Animation
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect:    Float = 1

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
                print("OldCar3D Metal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Helpers

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

        // MARK: - Build scene

        private func buildScene() {
            buildExterior()
            buildCarInterior()
            buildWindshield()
            buildDashboard()
            buildRadio()
            buildBenchSeat()
            buildSnow()
        }

        private func buildExterior() {
            // Sky dome (stormy dark)
            addOpaque(buildSphere(radius: 40, rings: 6, segments: 12, color: [0.04, 0.04, 0.07, 1]),
                      model: matrix_identity_float4x4)

            // Road
            addOpaque(buildBox(w: 12, h: 0.01, d: 80, color: [0.14, 0.13, 0.12, 1]),
                      model: m4Translation(0, -1.5, -18))

            // Snow-covered road overlay
            addGlow(buildBox(w: 12, h: 0.005, d: 80, color: [1,1,1,0.35]),
                    model: m4Translation(0, -1.48, -18),
                    emissive: [0.55, 0.55, 0.60], opacity: 0.35)

            // Utility pole initial positions (scroll in render loop)
            var rng = SplitMix64(seed: 5501)
            for i in 0..<6 {
                poleOffsets.append(Float(-4 - i * 8))
                _ = rng  // suppress warning
            }

            // Barn silhouettes (static)
            addOpaque(buildBox(w: 6, h: 4, d: 0.5, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(-14, 0.5, -30))
            addOpaque(buildPyramid(bw: 6.2, bd: 0.6, h: 2, color: [0.05, 0.03, 0.02, 1]),
                      model: m4Translation(-14, 4.5, -30))
            addOpaque(buildBox(w: 5, h: 4.5, d: 0.5, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(18, 1.0, -45))
        }

        private func buildCarInterior() {
            let interiorCol: SIMD4<Float> = [0.08, 0.05, 0.03, 1]
            // A-pillars (sides of windshield)
            addOpaque(buildBox(w: 0.12, h: 0.9, d: 0.1, color: interiorCol),
                      model: m4Translation(-1.05, 0.35, -0.6))
            addOpaque(buildBox(w: 0.12, h: 0.9, d: 0.1, color: interiorCol),
                      model: m4Translation( 1.05, 0.35, -0.6))
            // Headliner (inside roof)
            addOpaque(buildBox(w: 2.2, h: 0.05, d: 1.5, color: [0.12, 0.09, 0.07, 1]),
                      model: m4Translation(0, 0.85, 0.1))
            // Door panels
            addOpaque(buildBox(w: 0.05, h: 0.8, d: 1.5, color: interiorCol),
                      model: m4Translation(-1.1, 0.2, 0.1))
            addOpaque(buildBox(w: 0.05, h: 0.8, d: 1.5, color: interiorCol),
                      model: m4Translation( 1.1, 0.2, 0.1))
        }

        private func buildWindshield() {
            // Windshield glass (semi-transparent, facing forward)
            addGlow(buildQuad(w: 2.1, h: 0.9, color: [1,1,1,1]),
                    model: m4Translation(0, 0.35, -0.65) * m4RotX(.pi * 0.12),
                    emissive: [0.03, 0.04, 0.07], opacity: 0.18)
            // Windshield frame
            addOpaque(buildBox(w: 2.2, h: 0.06, d: 0.06, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(0, 0.81, -0.63))   // top
            addOpaque(buildBox(w: 2.2, h: 0.06, d: 0.06, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(0, -0.10, -0.63))  // bottom (dashboard top)
        }

        private func buildDashboard() {
            // Dashboard panel
            addOpaque(buildBox(w: 2.3, h: 0.28, d: 0.30, color: [0.10, 0.06, 0.04, 1]),
                      model: m4Translation(0, -0.06, -0.6))
            // Instrument cluster (emissive amber — dash glow)
            addGlow(buildQuad(w: 0.6, h: 0.14, color: [1,1,1,1]),
                    model: m4Translation(-0.4, 0.0, -0.46),
                    emissive: [0.85, 0.55, 0.15], opacity: 0.9)
            // Glove box
            addOpaque(buildBox(w: 0.5, h: 0.16, d: 0.02, color: [0.12, 0.07, 0.04, 1]),
                      model: m4Translation(0.65, -0.06, -0.47))
            // Steering wheel rim
            addOpaque(buildCylinder(radius: 0.23, height: 0.015, segments: 16,
                                    color: [0.25, 0.20, 0.15, 1]),
                      model: m4Translation(-0.3, -0.02, -0.52) * m4RotX(.pi * 0.15))
            // Steering column
            addOpaque(buildCylinder(radius: 0.025, height: 0.35, segments: 8,
                                    color: [0.18, 0.14, 0.10, 1]),
                      model: m4Translation(-0.3, -0.20, -0.55) * m4RotX(.pi * 0.05))
        }

        private func buildRadio() {
            // Radio faceplate
            addOpaque(buildBox(w: 0.30, h: 0.10, d: 0.02, color: [0.08, 0.06, 0.04, 1]),
                      model: m4Translation(0.2, 0.02, -0.47))
            // AM/FM dial (emissive amber strip)
            addGlow(buildQuad(w: 0.18, h: 0.035, color: [1,1,1,1]),
                    model: m4Translation(0.17, 0.035, -0.461),
                    emissive: [0.90, 0.70, 0.25], opacity: 0.85)
            // Two chrome knobs
            for side in [-1.0, 1.0] {
                addOpaque(buildCylinder(radius: 0.016, height: 0.025, segments: 8,
                                        color: [0.45, 0.40, 0.35, 1]),
                          model: m4Translation(Float(0.2 + side * 0.09), 0.02, -0.462))
            }
        }

        private func buildBenchSeat() {
            // Seat cushion (viewer sits here)
            addOpaque(buildBox(w: 2.0, h: 0.14, d: 0.55, color: [0.30, 0.16, 0.10, 1]),
                      model: m4Translation(0, -0.33, 0.4))
            // Seat back
            addOpaque(buildBox(w: 2.0, h: 0.60, d: 0.08, color: [0.28, 0.14, 0.09, 1]),
                      model: m4Translation(0, -0.01, 0.65))
            // Centre armrest divider
            addOpaque(buildBox(w: 0.09, h: 0.16, d: 0.50, color: [0.14, 0.08, 0.05, 1]),
                      model: m4Translation(0, -0.17, 0.4))
        }

        private func buildSnow() {
            var rng = SplitMix64(seed: 7700)
            for _ in 0..<200 {
                let sx = Float(Double.random(in: -1.5...1.5, using: &rng))
                let sy = Float(Double.random(in: -0.3...1.0, using: &rng))
                let sz = Float(Double.random(in: -5...0, using: &rng))
                snowPositions.append([sx, sy, sz])
                snowPhases.append(Float(Double.random(in: 0...2*Double.pi, using: &rng)))
                let vx = Float(Double.random(in: -0.15...0.15, using: &rng))
                let vy = Float(-0.4 - Double.random(in: 0...0.4, using: &rng))
                let vz = Float(4.0 + Double.random(in: 0...3, using: &rng))
                snowVelocities.append([vx, vy, vz])
                snowSizes.append(Float(3 + Double.random(in: 0...4, using: &rng)))
            }
        }

        // MARK: - Interaction

        func triggerHonk(time: Float) {
            honkT = time
        }

        // MARK: - MTKViewDelegate

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable  = view.currentDrawable,
                  let rpDesc    = view.currentRenderPassDescriptor,
                  let cmdBuf    = commandQueue.makeCommandBuffer(),
                  let encoder   = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Wiper sweep: oscillates ±35°
            wiperAngle += wiperDir * 0.018
            if wiperAngle > 0.60 { wiperDir = -1 }
            if wiperAngle < -0.60 { wiperDir = 1 }

            // Dash brightness (honk flash then fade)
            let sincHonk = t - honkT
            if sincHonk < 0.5 {
                dashBrightness = 2.5 - sincHonk * 3.0
            } else {
                dashBrightness = max(1.0, dashBrightness - 0.05)
            }

            // Camera: fixed interior viewpoint, slightly above the seat
            let eye: SIMD3<Float>    = [0, 0.15, 0.35]
            let center: SIMD3<Float> = [0, 0.1, -1.0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 72 * .pi / 180, aspect: aspect, near: 0.02, far: 80)
            let vp    = proj4 * view4

            // Ambient from dash glow
            let dashAmb: SIMD3<Float> = [0.80, 0.50, 0.15] * dashBrightness * 0.1
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>([0, -1, 0.3], 0),  // headlights pointing forward
                sunColor:       SIMD4<Float>([0.30, 0.25, 0.20] * dashBrightness * 0.5, 0),
                ambientColor:   SIMD4<Float>(dashAmb, t),
                fogParams:      SIMD4<Float>(20, 60, 0, 0),
                fogColor:       SIMD4<Float>([0.04, 0.04, 0.06], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)  // interior geometry needs both sides
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque geometry
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Wiper blades (dynamic model matrices)
            let wiperVerts = buildBox(w: 0.015, h: 0.012, d: 0.60, color: [0.10, 0.09, 0.08, 1])
            if let wBuf = makeVertexBuffer(wiperVerts, device: device) {
                // Left wiper
                let lWiperModel = m4Translation(-0.35, -0.12, -0.68) * m4RotZ(wiperAngle)
                                  * m4Translation(0, 0.30, 0)
                encodeDraw(encoder: encoder, vertexBuffer: wBuf, vertexCount: wiperVerts.count,
                           model: lWiperModel)
                // Right wiper (opposite phase)
                let rWiperModel = m4Translation( 0.35, -0.12, -0.68) * m4RotZ(-wiperAngle)
                                  * m4Translation(0, 0.30, 0)
                encodeDraw(encoder: encoder, vertexBuffer: wBuf, vertexCount: wiperVerts.count,
                           model: rWiperModel)
            }

            // Utility poles scrolling
            for i in poleOffsets.indices {
                let pz2 = (Float(-4 - i * 8) + t * 2.5).truncatingRemainder(dividingBy: 48) - 48/2
                let poleVerts = buildCylinder(radius: 0.06, height: 7.0, segments: 6,
                                              color: [0.15, 0.12, 0.10, 1])
                if let pBuf = makeVertexBuffer(poleVerts, device: device) {
                    encodeDraw(encoder: encoder, vertexBuffer: pBuf, vertexCount: poleVerts.count,
                               model: m4Translation(5.5, -1.5 + 3.5, pz2))
                }
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)
                for call in transparentCalls {
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol * dashBrightness,
                               emissiveMix: call.emissiveMix,
                               opacity: call.opacity)
                }
            }

            // Snow particles (rushing at windshield)
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for i in snowPositions.indices {
                    let ph = snowPhases[i]
                    // Positions drift forward (toward camera) and wrap
                    let progress = t * 1.5
                    let vz = snowVelocities[i].z
                    let baseZ = snowPositions[i].z
                    let sz = baseZ + (progress * vz).truncatingRemainder(dividingBy: 5.5)
                    let sx = snowPositions[i].x + 0.05 * sin(t * 2 + ph)
                    let sy = snowPositions[i].y + snowVelocities[i].y * fmod(progress, 1.5) * 0.3
                    let alpha: Float = sz < -0.2 ? 0.7 : max(0, 0.7 * (-sz / 0.2))
                    let col: SIMD4<Float> = [0.85, 0.88, 0.95, alpha]
                    particles.append(ParticleVertex3D(position: [sx, sy, sz],
                                                      color: col, size: snowSizes[i]))
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
        view.delegate              = context.coordinator
        view.colorPixelFormat      = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor            = MTLClearColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable    = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerHonk(time: t)
    }
}
