// NightTrain3DScene — Metal 3D night train journey through moonlit countryside.
// Train carriage interior: seats, windows, amber overhead bulbs.
// Tap to light up the next window with an intensity spike.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct NightTrain3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        NightTrain3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct NightTrain3DRepresentable: NSViewRepresentable {
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
        var opaqueCalls:      [DrawCall] = []
        var glowCalls:        [DrawCall] = []

        // Windows: 3 windows on right wall, lit-time for tap spike
        var windowLitTimes:   [Float] = [-999, -999, -999]
        var windowDrawIndices: [Int]  = []
        var nextWindow:        Int    = 0

        // Landscape particles (scrolling countryside)
        struct LandscapeParticle {
            var x, y, baseZ: Float
            var speed: Float
            var size: Float
        }
        var landscape: [LandscapeParticle] = []

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect:    Float = 1

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("NightTrain3D pipeline error: \(error)") }
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
                              emissive: SIMD3<Float>, opacity: Float = 0.9) -> Int {
            guard let buf = makeVertexBuffer(v, device: device) else { return -1 }
            let idx = glowCalls.count
            glowCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                      emissiveCol: emissive, emissiveMix: 1.0, opacity: opacity))
            return idx
        }

        private func buildScene() {
            let carriageCol: SIMD4<Float> = [0.15, 0.16, 0.18, 1]
            let fabricCol:   SIMD4<Float> = [0.10, 0.12, 0.20, 1]
            let seatCol:     SIMD4<Float> = [0.18, 0.20, 0.30, 1]

            // Floor
            addOpaque(buildBox(w: 3, h: 0.05, d: 6, color: carriageCol),
                      model: m4Translation(0, 0, 0))
            // Ceiling
            addOpaque(buildBox(w: 3, h: 0.05, d: 6, color: carriageCol),
                      model: m4Translation(0, 2.05, 0))
            // Left wall
            addOpaque(buildBox(w: 0.1, h: 2, d: 6, color: fabricCol),
                      model: m4Translation(-1.5, 1.0, 0))
            // Right wall
            addOpaque(buildBox(w: 0.1, h: 2, d: 6, color: fabricCol),
                      model: m4Translation(1.5, 1.0, 0))
            // Front/back end walls
            addOpaque(buildBox(w: 3, h: 2, d: 0.08, color: carriageCol),
                      model: m4Translation(0, 1.0, -3))
            addOpaque(buildBox(w: 3, h: 2, d: 0.08, color: carriageCol),
                      model: m4Translation(0, 1.0,  3))

            // Seat rows
            for rz: Float in [-1.5, 0, 1.5] {
                for sx: Float in [-0.85, 0.85] {
                    // Seat cushion
                    addOpaque(buildBox(w: 0.5, h: 0.4, d: 0.45, color: seatCol),
                              model: m4Translation(sx, 0.45, rz))
                    // Backrest
                    addOpaque(buildBox(w: 0.5, h: 0.5, d: 0.08, color: seatCol),
                              model: m4Translation(sx, 0.9, rz - 0.2))
                }
            }

            // Overhead bulbs (emissive amber cylinders)
            for oz: Float in [-1.5, 0, 1.5] {
                let bulbCol: SIMD4<Float> = [1.0, 0.85, 0.55, 1]
                addOpaque(buildSphere(radius: 0.05, rings: 4, segments: 8, color: bulbCol),
                          model: m4Translation(0, 1.92, oz))
                _ = addGlow(buildSphere(radius: 0.07, rings: 4, segments: 8, color: [1,1,1,1]),
                            model: m4Translation(0, 1.92, oz),
                            emissive: [1.0, 0.80, 0.45], opacity: 0.7)
            }

            // Windows on right wall — stored as glow quads
            for wz: Float in [-1.5, 0, 1.5] {
                let wIdx = addGlow(
                    buildQuad(w: 0.6, h: 0.5, color: [1,1,1,1],
                              normal: [-1, 0, 0]),
                    model: m4Translation(1.44, 1.1, wz),
                    emissive: [0.08, 0.12, 0.22], opacity: 0.7)
                windowDrawIndices.append(wIdx)
            }

            // Landscape particles setup
            var rng = SplitMix64(seed: 4201)
            for _ in 0..<120 {
                landscape.append(LandscapeParticle(
                    x:     Float(Double.random(in: 1.6...6.0, using: &rng)),
                    y:     Float(Double.random(in: 0.6...1.6, using: &rng)),
                    baseZ: Float(Double.random(in: -3.0...3.0, using: &rng)),
                    speed: Float(Double.random(in: 3.0...8.0, using: &rng)),
                    size:  Float(Double.random(in: 2.0...5.0, using: &rng))
                ))
            }
        }

        func triggerWindowLit(time: Float) {
            let idx = nextWindow % windowLitTimes.count
            windowLitTimes[idx] = time
            nextWindow += 1
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opPipe  = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpDesc   = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let encoder  = cmdBuf.makeRenderCommandEncoder(descriptor: rpDesc)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            // Camera: interior seat view, gentle rocking
            let rock = sin(t * 0.5) * 0.009
            let eye: SIMD3<Float>    = [0, 1.2, 1.8]
            let center: SIMD3<Float> = [0, 0.95, -1.0]
            let upVec: SIMD3<Float>  = [sin(rock), cos(rock), 0]
            let view4 = m4LookAt(eye: eye, center: center, up: upVec)
            let proj4 = m4Perspective(fovyRad: 72 * .pi / 180, aspect: aspect, near: 0.02, far: 40)
            let vp    = proj4 * view4

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>([0, 1, 0], 0),
                sunColor:       SIMD4<Float>([0.30, 0.25, 0.20], 0),
                ambientColor:   SIMD4<Float>([0.06, 0.07, 0.12], t),
                fogParams:      SIMD4<Float>(8, 20, 0, 0),
                fogColor:       SIMD4<Float>([0.02, 0.03, 0.08], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Glow pass
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                for (i, call) in glowCalls.enumerated() {
                    var emix = call.emissiveMix
                    var ecol = call.emissiveCol
                    // Check if this is a window draw call
                    if let wPos = windowDrawIndices.firstIndex(of: i) {
                        let since = t - windowLitTimes[wPos]
                        if since >= 0 && since < 1.0 {
                            let spike: Float = since < 0.1
                                ? since / 0.1
                                : 1.0 - (since - 0.1) / 0.9
                            ecol = ecol + [0.65, 0.60, 0.30] * spike
                            emix = min(1.0, emix + spike * 0.5)
                        }
                    }
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: ecol, emissiveMix: emix, opacity: call.opacity)
                }
            }

            // Landscape particles rushing past windows
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for p in landscape {
                    let pz = (p.baseZ - t * p.speed * 0.5)
                        .truncatingRemainder(dividingBy: 7.0)
                    // Only show near window strip
                    let pzClamped = pz < -3.5 ? pz + 7.0 : pz
                    let alpha: Float = (abs(pzClamped) < 3.0) ? 0.6 : 0.0
                    if alpha > 0 {
                        particles.append(ParticleVertex3D(
                            position: [p.x, p.y, pzClamped],
                            color: [0.85, 0.88, 0.95, alpha], size: p.size))
                    }
                }
                if !particles.isEmpty, let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.delegate                = context.coordinator
        view.colorPixelFormat        = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor              = MTLClearColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.triggerWindowLit(time: t)
    }
}
