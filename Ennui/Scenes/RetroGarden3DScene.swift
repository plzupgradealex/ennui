// RetroGarden3DScene — Metal 3D low-poly garden: ground, hills, flowers, windmill, butterflies.
// Tap: spawn a new flower at a random position with a grow animation.

import SwiftUI
import MetalKit

struct RetroGarden3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { RetroGarden3DRepresentable(interaction: interaction) }
}

private struct RetroGarden3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        struct DrawCall {
            var buf: MTLBuffer; var count: Int; var model: simd_float4x4
            var emissiveCol: SIMD3<Float> = .zero; var emissiveMix: Float = 0
            var opacity: Float = 1
        }

        struct SpawnedFlower {
            var stemBuf: MTLBuffer; var stemCount: Int
            var headBuf: MTLBuffer; var headCount: Int
            var position: SIMD3<Float>; var spawnT: Float
        }

        var opaqueCalls:  [DrawCall] = []
        var spawnedFlowers: [SpawnedFlower] = []

        // Windmill blade buffer (shared, rotated in draw)
        var bladeBuf:   MTLBuffer?
        var bladeCount: Int = 0
        var windmillPos = SIMD3<Float>(4, 0, -4)

        // Butterfly data
        struct Butterfly {
            var orbitCenter: SIMD3<Float>; var orbitRadius: Float
            var period: Float; var phase: Float; var buf: MTLBuffer; var count: Int
        }
        var butterflies: [Butterfly] = []

        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        override init() {
            device = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("RetroGarden3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) {
            guard let buf = makeVertexBuffer(v, device: device) else { return }
            opaqueCalls.append(DrawCall(buf: buf, count: v.count, model: model,
                                        emissiveCol: emissive, emissiveMix: mix))
        }

        private func buildScene() {
            // Ground
            addOpaque(buildPlane(w: 14, d: 14, color: [0.30, 0.70, 0.20, 1]),
                      model: matrix_identity_float4x4)

            // Hills (flattened spheres)
            addOpaque(buildSphere(radius: 2.5, rings: 10, segments: 16, color: [0.25, 0.60, 0.18, 1]),
                      model: m4Translation(-6, -2.8, -5) * m4Scale(1, 0.45, 0.9))
            addOpaque(buildSphere(radius: 2.0, rings: 10, segments: 16, color: [0.22, 0.55, 0.15, 1]),
                      model: m4Translation(6, -2.3, -5) * m4Scale(1, 0.45, 0.9))

            // Flowers (9 preset)
            let flowerPositions: [SIMD3<Float>] = [
                [-3, 0, -1], [-1, 0, -3], [1, 0, -2], [3, 0, -1], [-2, 0, 2],
                [0, 0, 3], [2, 0, 3], [-4, 0, -3], [3, 0, -4]
            ]
            let headColors: [SIMD4<Float>] = [
                [1.0, 0.2, 0.2, 1], [1.0, 0.6, 0.1, 1], [1.0, 0.95, 0.1, 1],
                [0.8, 0.1, 0.8, 1], [0.3, 0.5, 1.0, 1], [0.95, 0.4, 0.65, 1],
                [0.5, 0.8, 0.3, 1], [1.0, 0.4, 0.2, 1], [0.6, 0.3, 0.9, 1]
            ]
            for (i, pos) in flowerPositions.enumerated() {
                let stemV = buildCylinder(radius: 0.05, height: 0.8, segments: 8, color: [0.2, 0.7, 0.1, 1])
                addOpaque(stemV, model: m4Translation(pos.x, 0.4, pos.z))
                let headV = buildCone(radius: 0.25, height: 0.30, segments: 8, color: headColors[i % headColors.count])
                addOpaque(headV, model: m4Translation(pos.x, 0.9, pos.z))
            }

            // Windmill body
            let windBodyV = buildCylinder(radius: 0.1, height: 3.0, segments: 8, color: [0.75, 0.65, 0.50, 1])
            addOpaque(windBodyV, model: m4Translation(windmillPos.x, 1.5, windmillPos.z))

            // Windmill blade geometry (centred at origin, offset upward)
            let bladeV = buildBox(w: 0.15, h: 0.9, d: 0.06, color: [0.85, 0.75, 0.55, 1])
            bladeBuf   = makeVertexBuffer(bladeV, device: device)
            bladeCount = bladeV.count

            // Butterflies (6 small thin boxes orbiting flower positions)
            let bfColors: [SIMD4<Float>] = [
                [0.9, 0.4, 0.8, 1], [0.4, 0.7, 1.0, 1], [1.0, 0.8, 0.2, 1],
                [0.6, 0.9, 0.4, 1], [0.9, 0.5, 0.3, 1], [0.5, 0.4, 0.9, 1]
            ]
            var rng = SplitMix64(seed: 55)
            for i in 0..<6 {
                let fp = flowerPositions[i % flowerPositions.count]
                let bfV = buildBox(w: 0.22, h: 0.02, d: 0.14, color: bfColors[i])
                guard let bfBuf = makeVertexBuffer(bfV, device: device) else { continue }
                butterflies.append(Butterfly(
                    orbitCenter: SIMD3<Float>(fp.x, 0.95, fp.z),
                    orbitRadius: Float(rng.nextDouble()) * 0.2 + 0.25,
                    period: Float(rng.nextDouble()) * 3 + 3,
                    phase: Float(rng.nextDouble()) * 2 * Float.pi,
                    buf: bfBuf, count: bfV.count
                ))
            }
        }

        func spawnFlower(at t: Float, tapCount: Int) {
            var rng = SplitMix64(seed: UInt64(t * 1000) ^ UInt64(tapCount) &* 6364136223846793005)
            let x = Float(rng.nextDouble()) * 10 - 5
            let z = Float(rng.nextDouble()) * 10 - 5
            let hue = Float(rng.nextDouble())
            let headColor = SIMD4<Float>(hue, Float(rng.nextDouble()) * 0.6 + 0.2, Float(rng.nextDouble()) * 0.6 + 0.2, 1)
            let stemV = buildCylinder(radius: 0.05, height: 0.8, segments: 8, color: [0.2, 0.7, 0.1, 1])
            let headV = buildCone(radius: 0.25, height: 0.30, segments: 8, color: headColor)
            guard let sb = makeVertexBuffer(stemV, device: device),
                  let hb = makeVertexBuffer(headV, device: device) else { return }
            spawnedFlowers.append(SpawnedFlower(
                stemBuf: sb, stemCount: stemV.count,
                headBuf: hb, headCount: headV.count,
                position: SIMD3<Float>(x, 0, z), spawnT: t
            ))
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd = view.currentRenderPassDescriptor,
                  let cmdBuf = commandQueue.makeCommandBuffer(),
                  let enc = cmdBuf.makeRenderCommandEncoder(descriptor: rpd) else { return }

            let t = Float(CACurrentMediaTime() - startTime)
            let camAngle = t * 2 * Float.pi / 60
            let eye = SIMD3<Float>(10 * cos(camAngle), 3, 10 * sin(camAngle))
            let proj = m4Perspective(fovyRad: 0.75, aspect: aspect, near: 0.1, far: 80)
            let viewM = m4LookAt(eye: eye, center: SIMD3<Float>(0, 0.5, 0), up: SIMD3<Float>(0, 1, 0))
            let vp = proj * viewM

            let sunDir = SIMD4<Float>(simd_normalize(SIMD3<Float>(0.5, 1.0, 0.3)), 0)
            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   sunDir,
                sunColor:       SIMD4<Float>(1.0, 0.95, 0.85, 1),
                ambientColor:   SIMD4<Float>(0.35, 0.45, 0.35, t),
                fogParams:      SIMD4<Float>(15, 30, 0, 0),
                fogColor:       SIMD4<Float>(0.5, 0.7, 0.9, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            enc.setCullMode(.back)
            enc.setDepthStencilState(depthState)
            enc.setRenderPipelineState(opaque)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Static scene
            for dc in opaqueCalls {
                var m = dc.model
                encodeDraw(encoder: enc, vertexBuffer: dc.buf, vertexCount: dc.count,
                           model: m, emissiveColor: dc.emissiveCol, emissiveMix: dc.emissiveMix,
                           opacity: dc.opacity)
            }

            // Windmill blades (4, spinning)
            if let bb = bladeBuf {
                let bladeAngle = t * (2 * Float.pi / 8.0)
                let hubPos = m4Translation(windmillPos.x, 3.05, windmillPos.z)
                for i in 0..<4 {
                    let a = bladeAngle + Float(i) * Float.pi / 2
                    let bladeModel = hubPos * m4RotZ(a) * m4Translation(0, 0.5, 0)
                    encodeDraw(encoder: enc, vertexBuffer: bb, vertexCount: bladeCount,
                               model: bladeModel)
                }
            }

            // Butterflies
            for bf in butterflies {
                let angle = t * 2 * Float.pi / bf.period + bf.phase
                let bx = bf.orbitCenter.x + bf.orbitRadius * cos(angle)
                let bz = bf.orbitCenter.z + bf.orbitRadius * sin(angle)
                let model = m4Translation(bx, bf.orbitCenter.y, bz) * m4RotY(angle + Float.pi / 2)
                            * m4RotX(0.25 * sin(t * 8 + bf.phase))
                encodeDraw(encoder: enc, vertexBuffer: bf.buf, vertexCount: bf.count, model: model)
            }

            // Spawned flowers (grow animation)
            for sf in spawnedFlowers {
                let age  = t - sf.spawnT
                let grow = min(1, max(0, age / 0.6))
                let stemModel = m4Translation(sf.position.x, 0.4 * grow, sf.position.z)
                                * m4Scale(grow, grow, grow)
                encodeDraw(encoder: enc, vertexBuffer: sf.stemBuf, vertexCount: sf.stemCount,
                           model: stemModel)
                let headModel = m4Translation(sf.position.x, 0.9 * grow, sf.position.z)
                                * m4Scale(grow, grow, grow)
                encodeDraw(encoder: enc, vertexBuffer: sf.headBuf, vertexCount: sf.headCount,
                           model: headModel)
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate = context.coordinator
        v.colorPixelFormat = .bgra8Unorm
        v.depthStencilPixelFormat = .depth32Float
        v.clearColor = MTLClearColor(red: 0.5, green: 0.7, blue: 0.9, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.spawnFlower(at: t, tapCount: interaction.tapCount)
    }
}
