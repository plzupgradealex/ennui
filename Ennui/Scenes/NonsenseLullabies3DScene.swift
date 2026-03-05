// NonsenseLullabies3DScene — Metal 3D nursery dreamscape.
// Warm ivory background, 20 floating pastel shapes bobbing gently.
// Tap for a 1.5s sparkle burst around centre.

import SwiftUI
import MetalKit

struct NonsenseLullabies3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { NonsenseLullabies3DRepresentable(interaction: interaction) }
}

private struct NonsenseLullabies3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        struct ShapePart {
            var buffer: MTLBuffer; var count: Int
            var localModel: simd_float4x4
            var emissive: SIMD3<Float>; var emissiveMix: Float
        }
        struct ShapeInstance {
            var parts: [ShapePart]
            var baseX, baseY, baseZ: Float
            var bobAmp, bobPeriod, bobPhase: Float
        }
        var shapeInstances: [ShapeInstance] = []

        var sparkleT: Float = -999
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
            } catch { print("NonsenseLullabies3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func makePart(_ verts: [Vertex3D],
                               local: simd_float4x4,
                               emissive: SIMD3<Float> = .zero,
                               mix: Float = 0) -> ShapePart? {
            guard let buf = makeVertexBuffer(verts, device: device) else { return nil }
            return ShapePart(buffer: buf, count: verts.count, localModel: local,
                             emissive: emissive, emissiveMix: mix)
        }

        private func buildScene() {
            let pink:     SIMD4<Float> = [0.98, 0.72, 0.80, 1]
            let lavender: SIMD4<Float> = [0.78, 0.70, 0.95, 1]
            let yellow:   SIMD4<Float> = [0.99, 0.92, 0.52, 1]
            let peach:    SIMD4<Float> = [0.99, 0.80, 0.65, 1]
            let mint:     SIMD4<Float> = [0.68, 0.95, 0.82, 1]
            let palette: [SIMD4<Float>] = [pink, lavender, yellow, peach, mint]

            var rng = SplitMix64(seed: 3141)

            for i in 0..<20 {
                let bx  = Float(rng.nextDouble() * 10 - 5)
                let by  = Float(rng.nextDouble() * 5  - 2)
                let bz  = Float(rng.nextDouble() * 5  - 8)
                let amp = Float(rng.nextDouble() * 0.2 + 0.2)
                let per = Float(rng.nextDouble() * 3   + 2)
                let ph  = Float(rng.nextDouble() * 2   * Double.pi)
                let col = palette[i % 5]
                let ec  = SIMD3<Float>(col.x, col.y, col.z)

                var parts: [ShapePart] = []
                switch i % 4 {
                case 0: // cat
                    let body = buildBox(w: 0.30, h: 0.25, d: 0.15, color: col)
                    let head = buildSphere(radius: 0.12, rings: 6, segments: 10, color: col)
                    let earL = buildCone(radius: 0.04, height: 0.12, segments: 6, color: col)
                    let earR = buildCone(radius: 0.04, height: 0.12, segments: 6, color: col)
                    if let p = makePart(body, local: m4Translation(0, 0.125, 0)) { parts.append(p) }
                    if let p = makePart(head, local: m4Translation(0, 0.37, 0)) { parts.append(p) }
                    if let p = makePart(earL, local: m4Translation(-0.08, 0.52, 0)) { parts.append(p) }
                    if let p = makePart(earR, local: m4Translation( 0.08, 0.52, 0)) { parts.append(p) }
                case 1: // moon
                    let moon = buildSphere(radius: 0.20, rings: 8, segments: 12, color: col)
                    if let p = makePart(moon, local: matrix_identity_float4x4,
                                        emissive: ec, mix: 0.3) { parts.append(p) }
                case 2: // house
                    let body = buildBox(w: 0.40, h: 0.35, d: 0.30, color: col)
                    let roof = buildPyramid(bw: 0.44, bd: 0.34, h: 0.22, color: peach)
                    if let p = makePart(body, local: m4Translation(0, 0.175, 0)) { parts.append(p) }
                    if let p = makePart(roof, local: m4Translation(0, 0.35, 0)) { parts.append(p) }
                default: // star
                    let star = buildSphere(radius: 0.08, rings: 6, segments: 8, color: col)
                    if let p = makePart(star, local: matrix_identity_float4x4,
                                        emissive: ec, mix: 0.5) { parts.append(p) }
                }
                shapeInstances.append(ShapeInstance(parts: parts,
                                                     baseX: bx, baseY: by, baseZ: bz,
                                                     bobAmp: amp, bobPeriod: per, bobPhase: ph))
            }
        }

        func handleTap() {
            sparkleT = Float(CACurrentMediaTime() - startTime)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let pipeline = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t = Float(CACurrentMediaTime() - startTime)

            let orbitAngle = t * 2 * .pi / 120.0
            let eye: SIMD3<Float>    = [9 * sin(orbitAngle), 1.5, 9 * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 0.5, -5.5]
            let viewM = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect, near: 0.1, far: 60)
            let vp    = projM * viewM

            let sunDir: SIMD3<Float> = simd_normalize([0.5, -0.8, -0.3])
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(1.0, 0.95, 0.85, 0),
                ambientColor:   SIMD4<Float>(0.6, 0.55, 0.50, t),
                fogParams:      SIMD4<Float>(20, 40, 0, 0),
                fogColor:       SIMD4<Float>(0.95, 0.90, 0.82, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setRenderPipelineState(pipeline)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for inst in shapeInstances {
                let bob    = inst.bobAmp * sin(t * 2 * .pi / inst.bobPeriod + inst.bobPhase)
                let worldT = m4Translation(inst.baseX, inst.baseY + bob, inst.baseZ)
                for part in inst.parts {
                    let model = worldT * part.localModel
                    if part.emissiveMix > 0 {
                        // drawn in glow pass below
                        continue
                    }
                    encodeDraw(encoder: enc, vertexBuffer: part.buffer, vertexCount: part.count,
                               model: model,
                               emissiveColor: part.emissive, emissiveMix: part.emissiveMix)
                }
            }

            if let glowPL = glowPipeline {
                enc.setRenderPipelineState(glowPL)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                for inst in shapeInstances {
                    let bob    = inst.bobAmp * sin(t * 2 * .pi / inst.bobPeriod + inst.bobPhase)
                    let worldT = m4Translation(inst.baseX, inst.baseY + bob, inst.baseZ)
                    for part in inst.parts where part.emissiveMix > 0 {
                        let model = worldT * part.localModel
                        encodeDraw(encoder: enc, vertexBuffer: part.buffer, vertexCount: part.count,
                                   model: model,
                                   emissiveColor: part.emissive, emissiveMix: part.emissiveMix,
                                   opacity: 0.9)
                    }
                }
            }

            let sparkAge = t - sparkleT
            if let ppipe = particlePipeline, sparkAge >= 0 && sparkAge < 1.5 {
                var sparks: [ParticleVertex3D] = []
                var prng = SplitMix64(seed: 7890)
                for _ in 0..<80 {
                    let theta = Float(prng.nextDouble() * 2 * Double.pi)
                    let phi   = Float(prng.nextDouble() * Double.pi)
                    let r     = Float(prng.nextDouble() * 3)
                    let px    = r * sin(phi) * cos(theta)
                    let py    = r * sin(phi) * sin(theta)
                    let pz    = -5 + r * cos(phi)
                    let fade  = max(0, Float(1 - sparkAge / 1.5))
                    let twink = 0.7 + 0.3 * sin(t * 15 + r * 5)
                    let br    = fade * twink
                    let col: SIMD4<Float> = [br, br * 0.9, br * 0.5, fade]
                    sparks.append(ParticleVertex3D(position: [px, py, pz], color: col,
                                                   size: 6 * fade))
                }
                if let pbuf = makeParticleBuffer(sparks, device: device) {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: sparks.count)
                }
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate                 = context.coordinator
        v.colorPixelFormat         = .bgra8Unorm
        v.depthStencilPixelFormat  = .depth32Float
        v.clearColor               = MTLClearColor(red: 0.95, green: 0.90, blue: 0.82, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
