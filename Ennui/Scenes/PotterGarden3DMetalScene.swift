// PotterGarden3DMetalScene — Beatrix Potter English cottage garden diorama.
// Cabbages on brown earth, a stone wall, wooden gate, distant cottage,
// butterflies as particles, soft afternoon light. Tap to release butterflies.
// No SceneKit — geometry built via Metal3DHelpers.

import SwiftUI
import MetalKit

struct PotterGarden3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        PotterGarden3DMetalRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct PotterGarden3DMetalRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

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
        var transparentCalls: [DrawCall] = []

        // Cabbage wobble info
        struct CabbageInfo {
            var callIndices: [Int]  // indices into opaqueCalls
            var baseModel: simd_float4x4
            var wobbleDur: Float
            var wobbleAmt: Float
        }
        var cabbages: [CabbageInfo] = []

        // Flower sway info
        struct FlowerInfo {
            var callIndices: [Int]
            var baseModel: simd_float4x4
            var swayDur: Float
            var swayAmt: Float
        }
        var flowers: [FlowerInfo] = []

        // Butterfly particle data
        struct ButterflyMote {
            var basePos: SIMD3<Float>
            var phase: Float
            var dx: Float; var dy: Float; var dz: Float
            var dur: Float
            var hue: SIMD4<Float>
        }
        var butterflyMotes: [ButterflyMote] = []

        // Tap burst
        var burstT: Float = -100
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
            } catch {
                print("PotterGarden3DMetal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Helpers

        private func addOpaque(_ v: [Vertex3D], model: simd_float4x4,
                               emissive: SIMD3<Float> = .zero, mix: Float = 0) -> Int {
            guard let buf = makeVertexBuffer(v, device: device) else { return -1 }
            opaqueCalls.append(DrawCall(buffer: buf, count: v.count,
                                        model: model, emissiveCol: emissive, emissiveMix: mix))
            return opaqueCalls.count - 1
        }

        // MARK: - Build scene

        private func buildScene() {
            buildGround()
            buildPaths()
            buildStoneWall()
            buildGate()
            buildCabbages()
            buildCottage()
            buildFlowers()
            buildDistantTrees()
            buildButterflies()
        }

        private func buildGround() {
            // Garden earth
            _ = addOpaque(buildPlane(w: 20, d: 20, color: [0.38, 0.26, 0.16, 1]),
                          model: matrix_identity_float4x4)
            // Grass beyond wall
            _ = addOpaque(buildPlane(w: 20, d: 12, color: [0.40, 0.55, 0.30, 1]),
                          model: m4Translation(0, 0.01, -8))
        }

        private func buildPaths() {
            let pathCol: SIMD4<Float> = [0.50, 0.38, 0.25, 1]
            _ = addOpaque(buildPlane(w: 1.2, d: 8, color: pathCol),
                          model: m4Translation(0, 0.02, 2))
            _ = addOpaque(buildPlane(w: 6, d: 0.8, color: pathCol),
                          model: m4Translation(0, 0.02, 1))
        }

        private func buildStoneWall() {
            var rng = SplitMix64(seed: 2222)
            let wallZ: Float = -1.8

            for row in 0..<2 {
                var sx: Float = -5.0
                while sx < 5.0 {
                    let sw = Float(0.3 + rng.nextDouble() * 0.4)
                    let sh = Float(0.15 + rng.nextDouble() * 0.1)
                    let gy = Float(0.55 + rng.nextDouble() * 0.2)
                    let stoneCol: SIMD4<Float> = [gy, gy - 0.02, gy - 0.05, 1]
                    let yOff = Float(row) * 0.2
                    _ = addOpaque(buildBox(w: sw, h: sh, d: 0.2, color: stoneCol),
                                  model: m4Translation(sx + sw / 2, sh / 2 + yOff, wallZ))
                    sx += sw + 0.02
                }
            }
        }

        private func buildGate() {
            let woodCol: SIMD4<Float> = [0.45, 0.32, 0.20, 1]
            let gateZ: Float = -1.8
            let gateW: Float = 1.0
            let gateH: Float = 0.55

            // Posts
            for postX: Float in [-gateW / 2 - 0.05, gateW / 2 + 0.05] {
                _ = addOpaque(buildBox(w: 0.1, h: gateH + 0.15, d: 0.1, color: woodCol),
                              model: m4Translation(postX, (gateH + 0.15) / 2, gateZ))
            }
            // Rails
            for railY: Float in [0.12, gateH - 0.05] {
                _ = addOpaque(buildBox(w: gateW, h: 0.04, d: 0.04, color: woodCol),
                              model: m4Translation(0, railY, gateZ))
            }
            // Slats
            for i in 0..<5 {
                let slX = -gateW / 2 + 0.1 + Float(i) * (gateW - 0.2) / 4
                _ = addOpaque(buildBox(w: 0.03, h: gateH - 0.10, d: 0.02, color: woodCol),
                              model: m4Translation(slX, gateH / 2, gateZ))
            }
        }

        private func buildCabbages() {
            var rng = SplitMix64(seed: 1893)

            let rowStarts: [(Float, Float, Int)] = [
                (-3.5, -0.5, 6), (-3.5, 0.5, 6), (-3.5, 1.5, 5),
                ( 1.0,  0.0, 5), ( 1.0, 1.0, 5), ( 1.0, 2.0, 4),
                (-2.0,  2.5, 3), ( 0.5, 3.0, 3),
            ]

            for (startX, z, count) in rowStarts {
                for i in 0..<count {
                    let x = startX + Float(i) * 0.8 + Float(rng.nextDouble() - 0.5) * 0.15
                    let cz = z + Float(rng.nextDouble() - 0.5) * 0.1
                    let sz = Float(0.25 + rng.nextDouble() * 0.12)
                    let hue = Float(0.28 + rng.nextDouble() * 0.08)
                    let bri = Float(0.55 + rng.nextDouble() * 0.15)

                    let baseModel = m4Translation(x, 0, cz)
                    var indices: [Int] = []

                    // Central head — squashed sphere
                    let headCol: SIMD4<Float> = [hue * 0.4, bri + 0.1, hue * 0.35, 1]
                    let headModel = baseModel * m4Translation(0, sz * 0.35, 0) * m4Scale(1, 0.7, 1)
                    let idx = addOpaque(buildSphere(radius: sz * 0.5, rings: 4, segments: 6, color: headCol),
                                        model: headModel)
                    if idx >= 0 { indices.append(idx) }

                    // Outer leaves — smaller spheres around head
                    let leafCount = 5 + Int(rng.nextDouble() * 4)
                    for j in 0..<leafCount {
                        let angle = Float(j) / Float(leafCount) * Float.pi * 2
                        let dist = sz * 0.45
                        let leafBri = bri - 0.05 + Float(rng.nextDouble() * 0.08)
                        let leafCol: SIMD4<Float> = [hue * 0.38, leafBri, hue * 0.32, 1]
                        let leafModel = baseModel * m4Translation(cos(angle) * dist, sz * 0.15, sin(angle) * dist) * m4Scale(1.2, 0.4, 0.8)
                        let li = addOpaque(buildSphere(radius: sz * 0.35, rings: 3, segments: 5, color: leafCol),
                                           model: leafModel)
                        if li >= 0 { indices.append(li) }
                    }

                    let wobbleDur = Float(4.0 + rng.nextDouble() * 3.0)
                    let wobbleAmt = Float(0.01 + rng.nextDouble() * 0.008)
                    cabbages.append(CabbageInfo(callIndices: indices, baseModel: baseModel,
                                                wobbleDur: wobbleDur, wobbleAmt: wobbleAmt))
                }
            }
        }

        private func buildCottage() {
            let cx: Float = 3.0; let cz: Float = -6.0
            // Walls
            _ = addOpaque(buildBox(w: 1.5, h: 1.0, d: 1.2, color: [0.82, 0.75, 0.65, 1]),
                          model: m4Translation(cx, 0.5, cz))
            // Roof
            _ = addOpaque(buildPyramid(bw: 1.8, bd: 1.5, h: 0.7, color: [0.50, 0.32, 0.22, 1]),
                          model: m4Translation(cx, 1.0, cz))
            // Chimney
            _ = addOpaque(buildBox(w: 0.2, h: 0.5, d: 0.2, color: [0.55, 0.35, 0.25, 1]),
                          model: m4Translation(cx + 0.45, 1.5, cz))
            // Door
            _ = addOpaque(buildBox(w: 0.3, h: 0.55, d: 0.04, color: [0.35, 0.25, 0.18, 1]),
                          model: m4Translation(cx, 0.28, cz + 0.62))
            // Window
            _ = addOpaque(buildBox(w: 0.25, h: 0.20, d: 0.03, color: [0.65, 0.72, 0.82, 1]),
                          model: m4Translation(cx + 0.45, 0.65, cz + 0.62),
                          emissive: [0.15, 0.15, 0.18], mix: 0.3)
        }

        private func buildFlowers() {
            var rng = SplitMix64(seed: 7654)

            let positions: [(Float, Float)] = [
                (-3.5, -1.5), (-2.8, -1.6), (-1.5, -1.4), (1.2, -1.5), (2.5, -1.6), (3.2, -1.4),
                (-0.8, 0.1), (0.8, 0.1), (-2.0, 3.5), (2.0, 3.5), (-3.0, 2.5), (3.0, 2.2),
            ]

            let hues: [Float] = [0.0, 0.08, 0.12, 0.60, 0.75, 0.85]

            for (fx, fz) in positions {
                let ox = Float(rng.nextDouble() - 0.5) * 0.3
                let oz = Float(rng.nextDouble() - 0.5) * 0.2
                let baseModel = m4Translation(fx + ox, 0, fz + oz)
                var indices: [Int] = []

                // Stem
                let stemCol: SIMD4<Float> = [0.30, 0.50, 0.25, 1]
                let si = addOpaque(buildCylinder(radius: 0.01, height: 0.15, segments: 4, color: stemCol),
                                   model: baseModel * m4Translation(0, 0.075, 0))
                if si >= 0 { indices.append(si) }

                // Petal — small sphere at top
                let h = hues[Int(rng.nextDouble() * Double(hues.count))]
                let petalCol: SIMD4<Float> = [0.5 + h * 0.4, 0.3 + h * 0.3, 0.75 * (1 - h), 1]
                let pi = addOpaque(buildSphere(radius: 0.04, rings: 3, segments: 4, color: petalCol),
                                   model: baseModel * m4Translation(0, 0.16, 0) * m4Scale(1, 0.6, 1))
                if pi >= 0 { indices.append(pi) }

                let swayDur = Float(3.0 + rng.nextDouble() * 2.0)
                let swayAmt = Float(0.02 + rng.nextDouble() * 0.015)
                flowers.append(FlowerInfo(callIndices: indices, baseModel: baseModel,
                                          swayDur: swayDur, swayAmt: swayAmt))
            }
        }

        private func buildDistantTrees() {
            var rng = SplitMix64(seed: 5432)

            for _ in 0..<10 {
                let tx = Float(rng.nextDouble() * 12 - 6)
                let tz = Float(-5.0 - rng.nextDouble() * 6)
                let treeH = Float(0.8 + rng.nextDouble() * 1.2)

                // Trunk
                let trunkCol: SIMD4<Float> = [0.35, 0.22, 0.12, 1]
                _ = addOpaque(buildCylinder(radius: 0.06, height: treeH * 0.4, segments: 6, color: trunkCol),
                              model: m4Translation(tx, treeH * 0.2, tz))

                // Canopy
                let g = Float(0.35 + rng.nextDouble() * 0.2)
                let canopyCol: SIMD4<Float> = [g * 0.7, g, g * 0.6, 1]
                _ = addOpaque(buildSphere(radius: treeH * 0.35, rings: 4, segments: 6, color: canopyCol),
                              model: m4Translation(tx, treeH * 0.55, tz) * m4Scale(1, 0.8, 1))
            }
        }

        private func buildButterflies() {
            var rng = SplitMix64(seed: 3210)
            let huePool: [SIMD4<Float>] = [
                [0.85, 0.65, 0.35, 0.7],
                [0.90, 0.55, 0.55, 0.7],
                [0.60, 0.55, 0.85, 0.7],
                [0.85, 0.80, 0.40, 0.7],
                [0.95, 0.50, 0.30, 0.7],
                [0.50, 0.80, 0.60, 0.7],
            ]

            for i in 0..<6 {
                let x = Float(rng.nextDouble() * 6 - 3)
                let y = Float(0.4 + rng.nextDouble() * 0.8)
                let z = Float(rng.nextDouble() * 5 - 2)
                let dur = Float(6.0 + rng.nextDouble() * 5.0)
                let dx = Float((rng.nextDouble() - 0.5) * 2)
                let dy = Float(0.3 + rng.nextDouble() * 0.5)
                let dz = Float((rng.nextDouble() - 0.5) * 2)
                let phase = Float(rng.nextDouble() * 6.28)

                butterflyMotes.append(ButterflyMote(
                    basePos: [x, y, z], phase: phase,
                    dx: dx, dy: dy, dz: dz, dur: dur,
                    hue: huePool[i % huePool.count]))
            }
        }

        func handleTap() {
            burstT = Float(CACurrentMediaTime() - startTime)
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

            // Gentle camera orbit around garden
            let orbitAngle = t * (2 * Float.pi / 150.0)
            let pivotY: Float = 0.8
            let camDist: Float = 7.0
            let camH: Float = 2.5 + pivotY
            let eye: SIMD3<Float> = [sin(orbitAngle) * camDist, camH, cos(orbitAngle) * camDist]
            let center: SIMD3<Float> = [0, pivotY, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 50 * .pi / 180, aspect: aspect, near: 0.1, far: 40)
            let vp = proj4 * view4

            // Warm afternoon light
            let sunDir: SIMD3<Float> = simd_normalize([-0.4, -0.7, -0.3])
            let sunCol: SIMD3<Float> = [1.0, 0.92, 0.75]
            let ambCol: SIMD3<Float> = [0.30, 0.28, 0.24]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(15, 30, 0, 0),
                fogColor:       SIMD4<Float>(0.72, 0.78, 0.82, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Draw all opaque calls (static geometry is fine as-is)
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Butterfly particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []

                // Persistent flutter butterflies
                for mote in butterflyMotes {
                    let frac = fmod(t / mote.dur, 1.0)
                    let sway = sin(frac * Float.pi * 2)
                    let px = mote.basePos.x + mote.dx * sway
                    let py = mote.basePos.y + mote.dy * abs(sway)
                    let pz = mote.basePos.z + mote.dz * sway
                    let flutter = 0.5 + 0.4 * abs(sin(t * 3.0 + mote.phase))
                    particles.append(ParticleVertex3D(
                        position: [px, py, pz],
                        color: mote.hue * flutter,
                        size: 5))
                }

                // Tap burst — extra butterflies
                let burstAge = t - burstT
                if burstAge < 3.0 {
                    let alpha = max(0, 1 - burstAge / 3.0)
                    var brng = SplitMix64(seed: 4444)
                    for _ in 0..<12 {
                        let bx = Float(Double.random(in: -3...3, using: &brng))
                        let by = Float(0.3 + Double.random(in: 0...2, using: &brng)) + burstAge * 0.4
                        let bz = Float(Double.random(in: -2...3, using: &brng))
                        particles.append(ParticleVertex3D(
                            position: [bx, by, bz],
                            color: [0.85, 0.65, 0.35, alpha],
                            size: 4))
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
        view.clearColor               = MTLClearColor(red: 0.68, green: 0.76, blue: 0.85, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
