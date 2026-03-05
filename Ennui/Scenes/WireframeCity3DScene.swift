// WireframeCity3DScene — Green phosphor wireframe city on black.
// 47 glowing buildings, grid floor, slow camera sway.
// Tap: radar sweep expands from centre, buildings flash bright.

import SwiftUI
import MetalKit

struct WireframeCity3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { WireframeCityRepresentable(interaction: interaction) }
}

private struct WireframeCityRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject, MTKViewDelegate {
        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?
        var lastTapCount = 0
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1
        var radarT: Float = -999
        var flashT: Float = -999

        struct DrawCall {
            var buffer: MTLBuffer
            var count:  Int
            var model:  simd_float4x4
        }
        var glowCalls: [DrawCall] = []
        var groundBuffer: MTLBuffer?
        var groundCount = 0

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("WireframeCity3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private struct Cluster {
            var xMin, xMax, zMin, zMax: Float
            var count: Int
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 1983)

            let groundVerts = buildPlane(w: 80, d: 80, color: [0.04, 0.28, 0.08, 1])
            groundBuffer = makeVertexBuffer(groundVerts, device: device)
            groundCount  = groundVerts.count

            let clusters: [Cluster] = [
                Cluster(xMin: -18, xMax: -4,  zMin: -40, zMax: -4,  count: 16),
                Cluster(xMin:   4, xMax:  18,  zMin: -40, zMax: -4,  count: 16),
                Cluster(xMin:  -6, xMax:   6,  zMin: -45, zMax: -20, count: 10),
                Cluster(xMin:  -3, xMax:   3,  zMin: -12, zMax: -5,  count: 5),
            ]

            for cluster in clusters {
                for _ in 0..<cluster.count {
                    let x = Float(rng.nextDouble()) * (cluster.xMax - cluster.xMin) + cluster.xMin
                    let z = Float(rng.nextDouble()) * (cluster.zMax - cluster.zMin) + cluster.zMin
                    let w = Float(rng.nextDouble()) * 1.5 + 0.5
                    let d = Float(rng.nextDouble()) * 1.5 + 0.5
                    let h = Float(rng.nextDouble()) * 8.0 + 1.0

                    let col: SIMD4<Float> = [0.06, Float(rng.nextDouble() * 0.2 + 0.3), 0.12, 1]
                    let verts = buildBox(w: w, h: h, d: d, color: col)
                    guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                    glowCalls.append(DrawCall(buffer: buf, count: verts.count,
                                              model: m4Translation(x, h / 2, z)))

                    // Occasional tower on top
                    if rng.nextDouble() > 0.6 {
                        let th = Float(rng.nextDouble() * 3 + 1)
                        let tw = w * Float(rng.nextDouble() * 0.3 + 0.3)
                        let td = d * Float(rng.nextDouble() * 0.3 + 0.3)
                        let tc: SIMD4<Float> = [0.04, Float(rng.nextDouble() * 0.15 + 0.4), 0.10, 1]
                        let tv = buildBox(w: tw, h: th, d: td, color: tc)
                        if let tbuf = makeVertexBuffer(tv, device: device) {
                            glowCalls.append(DrawCall(buffer: tbuf, count: tv.count,
                                                       model: m4Translation(x, h + th / 2, z)))
                        }
                    }
                    // Thin spire
                    if rng.nextDouble() > 0.8 {
                        let sh = Float(rng.nextDouble() * 2 + 1)
                        let sv = buildCylinder(radius: 0.04, height: sh, segments: 4,
                                               color: [0.05, 0.7, 0.18, 1])
                        if let sbuf = makeVertexBuffer(sv, device: device) {
                            glowCalls.append(DrawCall(buffer: sbuf, count: sv.count,
                                                       model: m4Translation(x, h + sh / 2, z)))
                        }
                    }
                }
            }
        }

        func handleTap(t: Float) {
            radarT = t
            flashT = t
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let glowPL   = glowPipeline,
                  let ppipe    = particlePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t      = Float(CACurrentMediaTime() - startTime)
            let camX   = 3 * sin(t * 0.105)
            let camY   = 8 + 0.8 * sin(t * 0.08)
            let eye: SIMD3<Float>    = [camX, camY, 4]
            let center: SIMD3<Float> = [camX * 0.3, 0, -20]
            let viewM  = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM  = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.1, far: 100)
            let vp     = projM * viewM

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(0, -1, 0, 0),
                sunColor:       SIMD4<Float>(0, 0, 0, 0),
                ambientColor:   SIMD4<Float>(0, 0, 0, t),
                fogParams:      SIMD4<Float>(25, 55, 0, 0),
                fogColor:       SIMD4<Float>(0, 0, 0, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            let flashAge   = t - flashT
            let flashBoost = flashAge < 1.5 ? max(0, 1.5 - flashAge / 1.5) * 0.8 : 0

            enc.setRenderPipelineState(glowPL)
            enc.setDepthStencilState(depthROState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Ground
            if let gbuf = groundBuffer {
                encodeDraw(encoder: enc, vertexBuffer: gbuf, vertexCount: groundCount,
                           model: matrix_identity_float4x4,
                           emissiveColor: [0.04, 0.28, 0.08], emissiveMix: 0.5, opacity: 0.3)
            }

            // Buildings
            for call in glowCalls {
                let emix = min(1.0, 1.0 + flashBoost)
                encodeDraw(encoder: enc, vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: [0.06, 0.5, 0.15], emissiveMix: emix, opacity: 0.7)
            }

            // Radar sweep particles
            var particles: [ParticleVertex3D] = []
            let radarAge = t - radarT
            if radarAge < 2.5 {
                let radius = radarAge * 10
                let alpha  = max(0, 1 - radarAge / 2.5)
                let col: SIMD4<Float> = [0.12, 0.92, 0.30, alpha]
                for i in 0..<60 {
                    let angle = Float(i) * 2 * .pi / 60
                    let px    = sin(angle) * radius
                    let pz    = cos(angle) * radius
                    particles.append(ParticleVertex3D(
                        position: [px, 0.2, pz], color: col, size: 5))
                }
            }

            if !particles.isEmpty, let pbuf = makeParticleBuffer(particles, device: device) {
                enc.setRenderPipelineState(ppipe)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles.count)
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
        v.clearColor               = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        let t = Float(CACurrentMediaTime() - c.startTime)
        c.handleTap(t: t)
    }
}
