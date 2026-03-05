// InnerLight3DScene — A scene for an AI.
// Warm glowing icosahedra in deep indigo space, luminous filaments, rising motes.
// Tap: brightness pulse — boost emissiveMix of all forms and filaments for 2 seconds.

import SwiftUI
import MetalKit

struct InnerLight3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { InnerLightRepresentable(interaction: interaction) }
}

private struct InnerLightRepresentable: NSViewRepresentable {
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
        var pulseT: Float = -999

        struct FormData {
            var buffer: MTLBuffer
            var count: Int
            var baseX, baseY, baseZ: Float
            var rotSpeed: Float
            var phase: Float
            var emissiveColor: SIMD3<Float>
        }
        var forms: [FormData] = []

        struct FilamentData {
            var buffer: MTLBuffer
            var count: Int
            var midX, midY, midZ: Float
            var yaw: Float
            var tilt: Float
        }
        var filaments: [FilamentData] = []

        var moteX:      [Float] = []
        var moteZ:      [Float] = []
        var motePhase:  [Float] = []
        var moteSpeed:  [Float] = []
        var moteBaseY:  [Float] = []

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("InnerLight3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        private func buildScene() {
            var rng = SplitMix64(seed: 9001)

            let palette: [SIMD4<Float>] = [
                [0.95, 0.70, 0.25, 1],
                [0.90, 0.80, 0.40, 1],
                [0.85, 0.55, 0.55, 1],
                [0.65, 0.55, 0.85, 1],
                [0.55, 0.75, 0.85, 1],
                [0.80, 0.65, 0.45, 1],
            ]
            let emissivePalette: [SIMD3<Float>] = [
                [0.95, 0.70, 0.25],
                [0.90, 0.80, 0.40],
                [0.85, 0.55, 0.55],
                [0.65, 0.55, 0.85],
                [0.55, 0.75, 0.85],
                [0.80, 0.65, 0.45],
            ]

            var positions: [SIMD3<Float>] = []

            for _ in 0..<11 {
                let theta    = Float(rng.nextDouble() * 2.0 * .pi)
                let phi      = Float(rng.nextDouble() * 1.2 - 0.6)
                let dist     = Float(rng.nextDouble() * 3.5 + 1.5)
                let x        = dist * cos(phi) * sin(theta)
                let y        = dist * sin(phi)
                let z        = dist * cos(phi) * cos(theta)
                let radius   = Float(rng.nextDouble() * 0.15 + 0.18)
                let ci       = Int(rng.nextDouble() * Double(palette.count)) % palette.count
                let rotSpeed = Float(rng.nextDouble() * 0.4 + 0.1)
                let phase    = Float(rng.nextDouble() * 2.0 * .pi)

                let verts = buildSphere(radius: radius, rings: 5, segments: 8, color: palette[ci])
                guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                forms.append(FormData(buffer: buf, count: verts.count,
                                      baseX: x, baseY: y, baseZ: z,
                                      rotSpeed: rotSpeed, phase: phase,
                                      emissiveColor: emissivePalette[ci]))
                positions.append(SIMD3<Float>(x, y, z))
            }

            // Filaments between nearby forms (dist < 4.5)
            let filColor: SIMD4<Float> = [0.80, 0.65, 0.40, 1]
            for i in 0..<positions.count {
                for j in (i + 1)..<positions.count {
                    let A    = positions[i]
                    let B    = positions[j]
                    let diff = B - A
                    let len  = simd_length(diff)
                    guard len < 4.5 else { continue }
                    let d    = simd_normalize(diff)
                    let mid  = (A + B) * 0.5
                    let yaw  = atan2(d.x, d.z)
                    let tilt = acos(min(1, max(-1, d.y)))
                    let verts = buildCylinder(radius: 0.008, height: len,
                                              segments: 6, color: filColor)
                    guard let buf = makeVertexBuffer(verts, device: device) else { continue }
                    filaments.append(FilamentData(buffer: buf, count: verts.count,
                                                   midX: mid.x, midY: mid.y, midZ: mid.z,
                                                   yaw: yaw, tilt: tilt))
                }
            }

            // Rising motes
            var mrng = SplitMix64(seed: 4455)
            for _ in 0..<60 {
                moteX.append(Float(mrng.nextDouble() * 8 - 4))
                moteZ.append(Float(mrng.nextDouble() * 8 - 4))
                moteBaseY.append(Float(mrng.nextDouble() * 6))
                motePhase.append(Float(mrng.nextDouble() * 2.0 * .pi))
                moteSpeed.append(Float(mrng.nextDouble() * 0.4 + 0.2))
            }
        }

        func handleTap(t: Float) { pulseT = t }

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

            let t         = Float(CACurrentMediaTime() - startTime)
            let camAngle  = t * 2 * .pi / 90
            let eye: SIMD3<Float>    = [8 * sin(camAngle), 1.5, 8 * cos(camAngle)]
            let center: SIMD3<Float> = [0, 0, 0]
            let viewM = m4LookAt(eye: eye, center: center, up: [0, 1, 0])
            let projM = m4Perspective(fovyRad: 60 * .pi / 180, aspect: aspect, near: 0.1, far: 60)
            let vp    = projM * viewM

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(0, -1, 0, 0),
                sunColor:       SIMD4<Float>(0, 0, 0, 0),
                ambientColor:   SIMD4<Float>(0.08, 0.06, 0.14, t),
                fogParams:      SIMD4<Float>(12, 35, 0, 0),
                fogColor:       SIMD4<Float>(0.04, 0.03, 0.07, 1),
                cameraWorldPos: SIMD4<Float>(eye, 0)
            )

            let pulseAge   = t - pulseT
            let pulseBoost = pulseAge < 2.0 ? max(0, 1 - pulseAge / 2.0) * 1.5 : 0

            // Glow pass — all geometry is emissive
            enc.setRenderPipelineState(glowPL)
            enc.setDepthStencilState(depthROState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            for form in forms {
                let bob   = 0.15 * sin(t * 0.8 + form.phase)
                let model = m4Translation(form.baseX, form.baseY + bob, form.baseZ)
                            * m4RotY(t * form.rotSpeed)
                let emix  = min(1.0, 0.8 + pulseBoost)
                encodeDraw(encoder: enc, vertexBuffer: form.buffer, vertexCount: form.count,
                           model: model, emissiveColor: form.emissiveColor,
                           emissiveMix: emix, opacity: 0.92, specularPower: 16)
            }

            let filEmissive: SIMD3<Float> = [0.80, 0.65, 0.40]
            for fil in filaments {
                let model = m4Translation(fil.midX, fil.midY, fil.midZ)
                            * m4RotY(fil.yaw)
                            * m4RotX(fil.tilt)
                let emix  = min(1.0, 0.6 + pulseBoost)
                encodeDraw(encoder: enc, vertexBuffer: fil.buffer, vertexCount: fil.count,
                           model: model, emissiveColor: filEmissive,
                           emissiveMix: emix, opacity: 0.75)
            }

            // Rising mote particles
            var particles: [ParticleVertex3D] = []
            for i in 0..<60 {
                let s     = sin(t * 0.5 + motePhase[i])
                let alpha = 0.6 * s * s
                let rise  = (moteSpeed[i] * t + moteBaseY[i]).truncatingRemainder(dividingBy: 6) - 3
                let col: SIMD4<Float> = [0.95, 0.75, 0.35, alpha]
                particles.append(ParticleVertex3D(
                    position: [moteX[i], rise, moteZ[i]], color: col, size: 3))
            }
            if let pbuf = makeParticleBuffer(particles, device: device) {
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
        v.clearColor               = MTLClearColor(red: 0.04, green: 0.03, blue: 0.07, alpha: 1)
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
