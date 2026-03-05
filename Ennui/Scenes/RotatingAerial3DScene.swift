// RotatingAerial3DScene — A rooftop TV antenna on a motorised rotator.
// Dark dusk sky with stars, silhouette rooftop, the Yagi-Uda aerial slowly
// turning on its mast while reception static shifts on a small TV below.
// Tap to reverse the rotation direction.
// Rendered in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct RotatingAerial3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        RotatingAerial3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

private struct RotatingAerial3DRepresentable: NSViewRepresentable {
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

        // Antenna geometry (rebuilt each frame with rotation)
        var mastBuffer:     MTLBuffer?
        var mastCount:      Int = 0
        var motorBuffer:    MTLBuffer?
        var motorCount:     Int = 0
        var boomBuffer:     MTLBuffer?
        var boomCount:      Int = 0
        var elementBuffers: [MTLBuffer] = []
        var elementCounts:  [Int] = []
        var reflectorBuffer: MTLBuffer?
        var reflectorCount: Int = 0

        // TV screen geometry
        var tvScreenBuffer: MTLBuffer?
        var tvScreenCount:  Int = 0

        // Stars
        var starPositions: [SIMD3<Float>] = []
        var starBrights:   [Float] = []

        // Tap: reverse rotation direction
        var rotationSign: Float = 1.0
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
            } catch { print("RotatingAerial3D pipeline error: \(error)") }
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
                              emissive: SIMD3<Float>, mix: Float = 1.0, opacity: Float = 0.9) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            glowCalls.append(DrawCall(buffer: buf, count: v.count, model: model,
                                      emissiveCol: emissive, emissiveMix: mix, opacity: opacity))
        }

        // MARK: - Build static scene

        private func buildScene() {
            let roofCol: SIMD4<Float>   = [0.08, 0.06, 0.05, 1]  // dark shingles
            let chimneyCol: SIMD4<Float> = [0.12, 0.08, 0.06, 1]
            let mastCol: SIMD4<Float>    = [0.35, 0.35, 0.38, 1]  // galvanised steel
            let antennaCol: SIMD4<Float> = [0.40, 0.40, 0.42, 1]
            let motorCol: SIMD4<Float>   = [0.25, 0.22, 0.20, 1]

            // ── Roof (angled planes as two slopes) ──
            // Left slope
            let leftSlope = buildBox(w: 3.5, h: 0.08, d: 5.0, color: roofCol)
            addOpaque(leftSlope, model: m4Translation(-0.85, 1.38, 0) * m4RotZ(0.38))
            // Right slope
            let rightSlope = buildBox(w: 3.5, h: 0.08, d: 5.0, color: roofCol)
            addOpaque(rightSlope, model: m4Translation(0.85, 1.38, 0) * m4RotZ(-0.38))
            // Ridge beam
            addOpaque(buildBox(w: 0.12, h: 0.06, d: 5.0, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(0, 2.0, 0))
            // Fascia boards (front/back)
            for z: Float in [-2.5, 2.5] {
                addOpaque(buildBox(w: 4.0, h: 0.5, d: 0.06, color: roofCol),
                          model: m4Translation(0, 1.15, z))
            }
            // Eaves underside
            addOpaque(buildBox(w: 4.0, h: 0.04, d: 5.0, color: [0.06, 0.04, 0.03, 1]),
                      model: m4Translation(0, 0.92, 0))

            // ── Chimney ──
            addOpaque(buildBox(w: 0.5, h: 1.4, d: 0.5, color: chimneyCol),
                      model: m4Translation(1.2, 2.1, -0.8))
            // Chimney cap
            addOpaque(buildBox(w: 0.58, h: 0.06, d: 0.58, color: [0.15, 0.10, 0.08, 1]),
                      model: m4Translation(1.2, 2.83, -0.8))

            // ── Antenna mast (fixed, goes straight up through roof) ──
            let mastVerts = buildCylinder(radius: 0.04, height: 2.0, segments: 8, color: mastCol)
            mastBuffer = makeVertexBuffer(mastVerts, device: device)
            mastCount = mastVerts.count

            // Motor housing at top of mast
            let motorVerts = buildBox(w: 0.18, h: 0.14, d: 0.18, color: motorCol)
            motorBuffer = makeVertexBuffer(motorVerts, device: device)
            motorCount = motorVerts.count

            // ── Antenna boom (long horizontal arm that rotates) ──
            let boomVerts = buildCylinder(radius: 0.02, height: 2.4, segments: 6, color: antennaCol)
            boomBuffer = makeVertexBuffer(boomVerts, device: device)
            boomCount = boomVerts.count

            // ── Antenna elements (perpendicular dipoles, Yagi-Uda style) ──
            // Director elements (shorter, in front)
            let directorLengths: [Float] = [0.22, 0.26, 0.30, 0.34, 0.38]
            let directorOffsets: [Float]  = [0.90, 0.65, 0.40, 0.15, -0.10]
            // Driven element + reflector
            let drivenLength: Float = 0.50
            let drivenOffset: Float = -0.35
            let reflectorLength: Float = 0.55
            let reflectorOffset: Float = -0.60

            elementBuffers = []
            elementCounts = []
            for (i, len) in directorLengths.enumerated() {
                let v = buildCylinder(radius: 0.012, height: len, segments: 4, color: antennaCol)
                if let buf = makeVertexBuffer(v, device: device) {
                    elementBuffers.append(buf)
                    elementCounts.append(v.count)
                }
                _ = directorOffsets[i] // used at draw time
            }
            // Driven element
            let drivenVerts = buildCylinder(radius: 0.014, height: drivenLength, segments: 4, color: antennaCol)
            if let buf = makeVertexBuffer(drivenVerts, device: device) {
                elementBuffers.append(buf)
                elementCounts.append(drivenVerts.count)
            }
            // Reflector
            let reflVerts = buildCylinder(radius: 0.014, height: reflectorLength, segments: 4, color: antennaCol)
            reflectorBuffer = makeVertexBuffer(reflVerts, device: device)
            reflectorCount = reflVerts.count

            // Store element positioning data
            elementOffsets = directorOffsets + [drivenOffset]
            self.reflectorOffset = reflectorOffset

            // ── Little TV set resting on roof near chimney ──
            // TV body
            addOpaque(buildBox(w: 0.38, h: 0.30, d: 0.28, color: [0.10, 0.08, 0.07, 1]),
                      model: m4Translation(-1.0, 1.25, 1.2))
            // TV screen (glowing, updated each frame for static)
            let screenVerts = buildQuad(w: 0.30, h: 0.22, color: [0.6, 0.65, 0.7, 1], normal: [0, 0, 1])
            tvScreenBuffer = makeVertexBuffer(screenVerts, device: device)
            tvScreenCount = screenVerts.count
            // TV rabbit ears (simple V-antenna on top of set)
            for side: Float in [-1, 1] {
                let earVerts = buildCylinder(radius: 0.008, height: 0.22, segments: 4, color: mastCol)
                if let buf = makeVertexBuffer(earVerts, device: device) {
                    let tilt = m4RotZ(side * 0.45)
                    let pos = m4Translation(-1.0 + side * 0.08, 1.51, 1.2)
                    glowCalls.append(DrawCall(buffer: buf, count: earVerts.count,
                                              model: pos * tilt, emissiveCol: [0.3, 0.3, 0.32],
                                              emissiveMix: 0.3, opacity: 1.0))
                }
            }

            // ── Window glow from below ──
            addGlow(buildQuad(w: 0.5, h: 0.3, color: [1, 1, 1, 1], normal: [0, 1, 0]),
                    model: m4Translation(0.4, 0.94, 1.5),
                    emissive: [0.85, 0.60, 0.25], mix: 1.0, opacity: 0.2)
            addGlow(buildQuad(w: 0.4, h: 0.25, color: [1, 1, 1, 1], normal: [0, 1, 0]),
                    model: m4Translation(-0.3, 0.94, 1.5),
                    emissive: [0.75, 0.55, 0.20], mix: 1.0, opacity: 0.15)

            // ── Stars ──
            var rng = SplitMix64(seed: 1987)
            for _ in 0..<90 {
                let theta = Float(Double.random(in: 0...Double.pi * 2, using: &rng))
                let phi = Float(Double.random(in: 0.05...1.2, using: &rng))
                let r: Float = 40.0
                let x = r * cos(theta) * sin(phi)
                let y = r * cos(phi) + 8.0
                let z = r * sin(theta) * sin(phi)
                starPositions.append(SIMD3<Float>(x, y, z))
                starBrights.append(Float(Double.random(in: 0.4...1.0, using: &rng)))
            }
        }

        // Element positioning data
        var elementOffsets: [Float] = []
        var reflectorOffset: Float = -0.60

        // MARK: - Draw

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

            // Antenna rotation: slow continuous turn, ~11 seconds per revolution
            let antennaAngle = t * 0.58 * rotationSign

            // "Reception" signal — strongest when antenna points toward signal
            // sources at specific angles. Multiple broadcast towers at different azimuths.
            let towerAngles: [Float] = [0.0, 1.8, 3.5, 5.2]  // radians
            var bestSignal: Float = 0
            let normalizedAngle = antennaAngle.truncatingRemainder(dividingBy: Float.pi * 2)
            for ta in towerAngles {
                let diff = abs(normalizedAngle - ta)
                let wrapped = min(diff, Float.pi * 2 - diff)
                let sig = max(0, 1.0 - wrapped / 0.6)
                bestSignal = max(bestSignal, sig)
            }
            // Add some gentle noise to signal
            let signalNoise = sin(t * 7.3) * 0.08 + sin(t * 13.1) * 0.05
            let signal = min(1.0, max(0, bestSignal + signalNoise))

            // Camera: looking up at antenna from roof level, slight orbit
            let camOrbit = t * 0.03
            let camR: Float = 4.5
            let eye = SIMD3<Float>(sin(camOrbit) * camR, 2.8, cos(camOrbit) * camR + 1.0)
            let center = SIMD3<Float>(0, 3.0, 0)
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect, near: 0.05, far: 80)
            let vp = proj4 * view4

            // Dusk sky colors for fog
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(normalize(SIMD3<Float>(-0.3, 0.2, -0.5)), 0),
                sunColor:       SIMD4<Float>([0.55, 0.35, 0.20], 0),
                ambientColor:   SIMD4<Float>([0.06, 0.05, 0.08], t),
                fogParams:      SIMD4<Float>(15, 50, 0, 0),
                fogColor:       SIMD4<Float>([0.04, 0.03, 0.06], 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(opPipe)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.none)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // ── Draw static opaque geometry (roof, chimney, TV body) ──
            for call in opaqueCalls {
                encodeDraw(encoder: encoder, vertexBuffer: call.buffer,
                           vertexCount: call.count, model: call.model)
            }

            // ── Draw antenna mast (fixed) ──
            if let buf = mastBuffer {
                let mastModel = m4Translation(0, 2.6, 0)
                encodeDraw(encoder: encoder, vertexBuffer: buf, vertexCount: mastCount,
                           model: mastModel)
            }

            // ── Draw motor housing (fixed, at top of mast) ──
            if let buf = motorBuffer {
                let motorModel = m4Translation(0, 3.6, 0)
                encodeDraw(encoder: encoder, vertexBuffer: buf, vertexCount: motorCount,
                           model: motorModel)
            }

            // ── Draw rotating antenna assembly ──
            let antennaBase = m4Translation(0, 3.68, 0) * m4RotY(antennaAngle)

            // Boom (horizontal, rotated to lie along X by rotating 90° around Z)
            if let buf = boomBuffer {
                let boomModel = antennaBase * m4RotZ(Float.pi / 2)
                encodeDraw(encoder: encoder, vertexBuffer: buf, vertexCount: boomCount,
                           model: boomModel)
            }

            // Elements (perpendicular to boom — vertical sticks along boom length)
            for (i, buf) in elementBuffers.enumerated() {
                let offset = elementOffsets[i]
                let elemModel = antennaBase * m4Translation(offset, 0, 0)
                encodeDraw(encoder: encoder, vertexBuffer: buf, vertexCount: elementCounts[i],
                           model: elemModel)
            }

            // Reflector
            if let buf = reflectorBuffer {
                let rModel = antennaBase * m4Translation(reflectorOffset, 0, 0)
                encodeDraw(encoder: encoder, vertexBuffer: buf, vertexCount: reflectorCount,
                           model: rModel)
            }

            // ── Glow pass ──
            if let gp = glowPipeline {
                encoder.setRenderPipelineState(gp)
                encoder.setDepthStencilState(depthROState)

                // Static glow calls (window light, rabbit ears)
                for call in glowCalls {
                    encodeDraw(encoder: encoder, vertexBuffer: call.buffer,
                               vertexCount: call.count, model: call.model,
                               emissiveColor: call.emissiveCol,
                               emissiveMix: call.emissiveMix, opacity: call.opacity)
                }

                // TV screen — colour shifts with signal strength
                if let buf = tvScreenBuffer {
                    let screenModel = m4Translation(-1.0, 1.28, 1.35)
                    // Good signal: warm image colour. Bad signal: blue-white static.
                    let staticFlicker = sin(t * 47) * 0.15 + sin(t * 89) * 0.1
                    let warmR: Float = 0.75 + signal * 0.15
                    let warmG: Float = 0.60 + signal * 0.20
                    let warmB: Float = 0.35 + signal * 0.10
                    let coldR: Float = 0.30 + staticFlicker
                    let coldG: Float = 0.35 + staticFlicker
                    let coldB: Float = 0.45 + staticFlicker
                    let r = warmR * signal + coldR * (1 - signal)
                    let g = warmG * signal + coldG * (1 - signal)
                    let b = warmB * signal + coldB * (1 - signal)
                    let screenBright: Float = 0.35 + signal * 0.50 + abs(staticFlicker) * (1 - signal) * 0.3
                    encodeDraw(encoder: encoder, vertexBuffer: buf,
                               vertexCount: tvScreenCount, model: screenModel,
                               emissiveColor: SIMD3<Float>(r, g, b) * screenBright,
                               emissiveMix: 1.0, opacity: 0.92)
                }
            }

            // ── Stars as point-sprite particles ──
            if let pp = particlePipeline {
                encoder.setRenderPipelineState(pp)
                encoder.setDepthStencilState(depthROState)

                var particles: [ParticleVertex3D] = []
                for (i, pos) in starPositions.enumerated() {
                    let twinkle = starBrights[i] * (0.7 + 0.3 * sin(t * (1.5 + Float(i) * 0.13) + Float(i)))
                    particles.append(ParticleVertex3D(
                        position: pos,
                        color: SIMD4<Float>(twinkle, twinkle, twinkle * 0.95, twinkle),
                        size: 2.0 + starBrights[i] * 1.5
                    ))
                }
                if !particles.isEmpty,
                   let pbuf = device.makeBuffer(bytes: particles,
                                                length: particles.count * MemoryLayout<ParticleVertex3D>.stride) {
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
        view.clearColor              = MTLClearColor(red: 0.025, green: 0.02, blue: 0.05, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable      = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        c.rotationSign *= -1  // reverse direction on tap
    }
}
