// MedievalVillage3DScene — Metal 3D diorama of the medieval hamlet.
// Low-poly buildings viewed from an orbiting camera above. Warm amber windows
// that tap-extinguish one by one. Firefly particles. Moon directional light.
// Rendered entirely in Metal (MTKView) — no SceneKit.

import SwiftUI
import MetalKit

struct MedievalVillage3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        MedievalVillage3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct MedievalVillage3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // MARK: Coordinator / Renderer

    final class Coordinator: NSObject, MTKViewDelegate {

        // MARK: Metal core
        let device:         MTLDevice
        let commandQueue:   MTLCommandQueue
        var opaquePipeline: MTLRenderPipelineState?
        var glowPipeline:   MTLRenderPipelineState?   // alpha-blend for window glow
        var particlePipeline: MTLRenderPipelineState?
        var depthState:     MTLDepthStencilState?
        var depthROState:   MTLDepthStencilState?     // read-only for transparent pass

        // MARK: Scene geometry buffers
        struct DrawCall {
            var buffer:      MTLBuffer
            var count:       Int
            var model:       simd_float4x4
            var emissiveCol: SIMD3<Float>
            var emissiveMix: Float
            var opacity:     Float = 1
        }

        var opaqueCalls:      [DrawCall] = []
        var transparentCalls: [DrawCall] = []  // window glow quads

        // MARK: Window glow state (tap to extinguish one by one)
        var windowGlowIntensities: [Float] = []   // 1 = lit, 0 = dark
        var extinguishedCount = 0
        var lastTapCount = 0

        // MARK: Ambient fade (dim as windows go out)
        var ambientIntensity: Float = 1.0   // 0..1 multiplier
        var moonIntensity:    Float = 1.0

        // MARK: Firefly particles
        var fireflyBase: [SIMD3<Float>] = []    // spawn positions
        var fireflyPhase: [Float]       = []    // per-firefly phase offset

        // MARK: Animation
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var aspect: Float = 1

        // MARK: Geometry parameters (mirrors SceneKit scene)
        struct Building {
            var x, z, w, h, d: Float
            var isChurch: Bool
            var windowCount: Int   // total windows for this building
            var firstWindowIndex: Int
        }
        var buildings: [Building] = []

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
                print("MedievalVillage3D Metal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build scene geometry

        private func buildScene() {
            var rng = SplitMix64(seed: 1350)

            // Ground
            let groundColor: SIMD4<Float> = [0.06, 0.10, 0.04, 1]
            addOpaque(buildPlane(w: 30, d: 30, color: groundColor),
                      model: matrix_identity_float4x4)

            // Path
            let pathColor: SIMD4<Float> = [0.12, 0.09, 0.06, 1]
            addOpaque(buildBox(w: 1.0, h: 0.01, d: 14, color: pathColor),
                      model: m4Translation(0, 0.005, 0))

            // Buildings
            let wallCol: SIMD4<Float> = [0.20, 0.16, 0.10, 1]
            let roofCol: SIMD4<Float> = [0.28, 0.18, 0.08, 1]

            struct Spot { let x: Float; let z: Float; let s: Float; let isChurch: Bool }
            let spots: [Spot] = [
                Spot(x: -3.2, z: -2.0, s: 1.0,  isChurch: false),
                Spot(x: -1.0, z: -3.2, s: 0.8,  isChurch: false),
                Spot(x:  1.2, z: -2.5, s: 1.1,  isChurch: false),
                Spot(x:  3.0, z: -1.0, s: 0.9,  isChurch: false),
                Spot(x: -2.2, z:  1.2, s: 0.85, isChurch: false),
                Spot(x:  0.5, z:  0.5, s: 1.15, isChurch: true),
                Spot(x:  2.5, z:  1.8, s: 0.95, isChurch: false),
            ]

            var windowIndex = 0

            for spot in spots {
                let bh = Float(spot.isChurch ? 2.8 : (1.0 + Double.random(in: 0...0.7, using: &rng)))
                let bw = Float(spot.isChurch ? 1.3 : (0.7 + Double.random(in: 0...0.5, using: &rng)))
                let bd = Float(spot.isChurch ? 1.3 : (0.6 + Double.random(in: 0...0.4, using: &rng)))
                let sw = bw * spot.s, sh = bh * spot.s, sd = bd * spot.s

                // Body
                addOpaque(buildBox(w: sw, h: sh, d: sd, color: wallCol),
                          model: m4Translation(spot.x, sh / 2, spot.z))

                // Roof
                let roofH = 0.55 * spot.s
                addOpaque(buildPyramid(bw: sw + 0.15, bd: sd + 0.15, h: roofH, color: roofCol),
                          model: m4Translation(spot.x, sh, spot.z))

                // Windows (emissive quads on front face)
                let winCols = 2, winRows = spot.isChurch ? 2 : 1
                let winW = sw * 0.12, winH = sh * 0.13
                let amber: SIMD3<Float> = [0.95, 0.70, 0.30]
                let amberA: SIMD4<Float> = [amber.x, amber.y, amber.z, 1.0]
                let firstIdx = windowIndex

                for row in 0..<winRows {
                    for col in 0..<winCols {
                        let xFrac = Float(col + 1) / Float(winCols + 1)
                        let yFrac = Float(row + 1) / Float(winRows + 1)
                        let wx = spot.x + (xFrac - 0.5) * sw
                        let wy = yFrac * sh
                        let wz = spot.z + sd / 2 + 0.005

                        let winVerts = buildQuad(w: winW, h: winH, color: amberA)
                        let model = m4Translation(wx, wy, wz)
                        // Window glow is a transparent draw call
                        if let buf = makeVertexBuffer(winVerts, device: device) {
                            transparentCalls.append(DrawCall(
                                buffer:      buf,
                                count:       winVerts.count,
                                model:       model,
                                emissiveCol: amber,
                                emissiveMix: 1.0
                            ))
                        }
                        windowGlowIntensities.append(1.0)
                        windowIndex += 1
                    }
                }

                buildings.append(Building(x: spot.x, z: spot.z,
                                          w: sw, h: sh, d: sd,
                                          isChurch: spot.isChurch,
                                          windowCount: winRows * winCols,
                                          firstWindowIndex: firstIdx))
            }

            // Trees
            var rng2 = SplitMix64(seed: 1351)
            let trunkCol: SIMD4<Float> = [0.18, 0.10, 0.05, 1]
            let leafCol:  SIMD4<Float> = [0.05, 0.14, 0.05, 1]
            for _ in 0..<12 {
                let tx = Float(Double.random(in: -6...6, using: &rng2))
                let tz = Float(Double.random(in: -5...5, using: &rng2))
                let ts = Float(0.5 + Double.random(in: 0...0.5, using: &rng2))
                addOpaque(buildCylinder(radius: 0.06*ts, height: 0.5*ts,
                                        segments: 8, color: trunkCol),
                          model: m4Translation(tx, 0.25*ts, tz))
                addOpaque(buildCone(radius: 0.4*ts, height: 0.9*ts,
                                    segments: 8, color: leafCol),
                          model: m4Translation(tx, 0.95*ts, tz))
            }

            // Firefly spawn positions
            var rng3 = SplitMix64(seed: 1352)
            for _ in 0..<60 {
                let fx = Float(Double.random(in: -5...5, using: &rng3))
                let fz = Float(Double.random(in: -4...4, using: &rng3))
                let fy = Float(0.4 + Double.random(in: 0...1.2, using: &rng3))
                fireflyBase.append([fx, fy, fz])
                fireflyPhase.append(Float(Double.random(in: 0...2*Double.pi, using: &rng3)))
            }
        }

        private func addOpaque(_ verts: [Vertex3D], model: simd_float4x4) {
            guard let buf = makeVertexBuffer(verts, device: device) else { return }
            opaqueCalls.append(DrawCall(buffer: buf, count: verts.count,
                                        model: model,
                                        emissiveCol: .zero, emissiveMix: 0))
        }

        // MARK: - Tap interaction

        func handleTap() {
            guard extinguishedCount < windowGlowIntensities.count else { return }
            // Fade the next window to dark over ~2 seconds (driven by render loop)
            windowGlowIntensities[extinguishedCount] = -1  // sentinel: fading out
            extinguishedCount += 1

            // Dim overall ambient proportionally
            let remaining = windowGlowIntensities.count - extinguishedCount
            let frac = Float(remaining) / Float(max(1, windowGlowIntensities.count))
            ambientIntensity = 0.14 + 0.86 * frac
            moonIntensity    = 0.31 + 0.69 * frac
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

            // Fade extinguishing windows over 2 seconds
            for i in windowGlowIntensities.indices {
                if windowGlowIntensities[i] < 0 {
                    // Already fading — value stored as negative progress
                    let progress = -windowGlowIntensities[i]
                    if progress >= 2.0 {
                        windowGlowIntensities[i] = 0
                    } else {
                        windowGlowIntensities[i] = -(progress + 1/60.0)
                    }
                }
            }

            // Camera — slow orbit 120 s/rev, angled down
            let orbitAngle = t * (2 * Float.pi / 120.0)
            let orbitR: Float = 13.0, orbitY: Float = 7.0
            let eye: SIMD3<Float> = [orbitR * sin(orbitAngle), orbitY, orbitR * cos(orbitAngle)]
            let center: SIMD3<Float> = [0, 0.5, 0]
            let view4 = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let proj4 = m4Perspective(fovyRad: 48 * .pi / 180, aspect: aspect, near: 0.1, far: 80)
            let vp    = proj4 * view4

            // Moon direction (fixed)
            let moonDir: SIMD3<Float> = simd_normalize([-0.5, -0.85, -0.3])
            let moonCol = SIMD3<Float>(0.40, 0.45, 0.70)
            let ambBase = SIMD3<Float>(0.15, 0.12, 0.25)

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(moonDir, 0),
                sunColor:       SIMD4<Float>(moonCol * moonIntensity, 0),
                ambientColor:   SIMD4<Float>(ambBase * ambientIntensity, t),
                fogParams:      SIMD4<Float>(12, 35, 0, 0),
                fogColor:       SIMD4<Float>(0.03, 0.03, 0.06, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Opaque pass
            for call in opaqueCalls {
                encodeDraw(encoder: encoder,
                           vertexBuffer: call.buffer, vertexCount: call.count,
                           model: call.model,
                           emissiveColor: call.emissiveCol, emissiveMix: call.emissiveMix)
            }

            // Window glow (blended, depth read-only)
            if let glowPL = glowPipeline {
                encoder.setRenderPipelineState(glowPL)
                encoder.setDepthStencilState(depthROState)
                for (i, call) in transparentCalls.enumerated() {
                    let raw = windowGlowIntensities[i]
                    let intensity: Float = raw >= 0 ? raw : max(0, 1 - (-raw) / 2.0)
                    guard intensity > 0.01 else { continue }
                    // Billboard — face camera (simple Y-rotation only, sufficient here)
                    encodeDraw(encoder: encoder,
                               vertexBuffer: call.buffer, vertexCount: call.count,
                               model: call.model,
                               emissiveColor: call.emissiveCol * intensity,
                               emissiveMix: 1.0,
                               opacity: intensity * 0.85)
                }
            }

            // Firefly particles
            if let ppipe = particlePipeline {
                var particles: [ParticleVertex3D] = []
                for i in fireflyBase.indices {
                    let ph = fireflyPhase[i]
                    let blink = max(0, sin(t * 1.8 + ph))
                    if blink < 0.1 { continue }
                    let wx = fireflyBase[i].x + 0.3 * sin(t * 0.7 + ph)
                    let wy = fireflyBase[i].y + 0.15 * sin(t * 1.1 + ph * 1.3)
                    let wz = fireflyBase[i].z + 0.3 * cos(t * 0.5 + ph * 0.9)
                    let col: SIMD4<Float> = [0.9, 0.8, 0.3, Float(blink) * 0.85]
                    particles.append(ParticleVertex3D(position: [wx, wy, wz], color: col, size: 6))
                }
                if !particles.isEmpty,
                   let pbuf = makeParticleBuffer(particles, device: device) {
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
        view.clearColor            = MTLClearColor(red: 0.015, green: 0.015, blue: 0.04, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable    = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.handleTap()
    }
}
