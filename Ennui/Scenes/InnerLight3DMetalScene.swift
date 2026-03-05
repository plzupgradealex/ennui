// InnerLight3DMetalScene — Expansive stellar nursery.
// Vast indigo-violet space filled with glowing nebula clouds, luminous suns of
// varying sizes connected by golden filaments, sparks and motes drifting everywhere.
// Fly with WASD + mouse look. Press & hold to create a black hole that sucks
// nearby stars in, then explodes into new nebula clouds that condense into stars.
// No SceneKit — pure Metal via Metal3DHelpers.

import SwiftUI
import MetalKit

struct InnerLight3DMetalScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        InnerLight3DMetalRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct InnerLight3DMetalRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState
    var tapCount: Int

    final class Coordinator: NSObject, MTKViewDelegate {

        let device:           MTLDevice
        let commandQueue:     MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:       MTLDepthStencilState?
        var depthROState:     MTLDepthStencilState?

        // ── Scene data ──

        // Suns / luminous orbs
        struct SunData {
            var pos: SIMD3<Float>; var radius: Float
            var emissiveColor: SIMD3<Float>; var bobPhase: Float; var rotSpeed: Float
            var alive: Bool; var velocity: SIMD3<Float>
        }
        var suns: [SunData] = []
        var sunBuffer: MTLBuffer?
        var sunVertCount: Int = 0

        // Small suns (using fewer rings)
        var smallSunBuffer: MTLBuffer?
        var smallSunVertCount: Int = 0

        // Filament geometry (thin cylinder)
        var filamentBuffer: MTLBuffer?
        var filamentVertCount: Int = 0

        // Nebula clouds — large translucent spheres
        struct NebulaData {
            var pos: SIMD3<Float>; var radius: Float
            var color: SIMD3<Float>; var driftPhase: Float
            var fadeAge: Float  // >0 means recently spawned, fading in
        }
        var nebulae: [NebulaData] = []
        var nebulaBuffer: MTLBuffer?
        var nebulaVertCount: Int = 0

        // Spark / mote particle data
        struct SparkData {
            var pos: SIMD3<Float>; var vel: SIMD3<Float>
            var phase: Float; var speed: Float; var color: SIMD4<Float>; var size: Float
        }
        var sparks: [SparkData] = []

        // Black hole state
        var blackHoleActive = false
        var blackHolePos: SIMD3<Float> = .zero
        var blackHoleAge: Float = 0
        var blackHolePhase: Int = 0  // 0=idle, 1=sucking, 2=exploding
        var explosionAge: Float = 0
        var explosionParticles: [(pos: SIMD3<Float>, vel: SIMD3<Float>, color: SIMD4<Float>)] = []

        // Camera state (WASD fly)
        var camPos: SIMD3<Float> = [0, 2, 12]
        var camYaw: Float = 0
        var camPitch: Float = 0
        weak var interaction: InteractionState?

        var lastTapCount = 0
        var glowBoostT: Float = -100
        var startTime: CFTimeInterval = CACurrentMediaTime()
        var lastFrameTime: CFTimeInterval = 0
        var aspect: Float = 1

        // Emissive color palette
        let palette: [SIMD3<Float>] = [
            [0.95, 0.70, 0.25],  // amber
            [0.90, 0.80, 0.40],  // gold
            [0.85, 0.55, 0.55],  // soft rose
            [0.65, 0.55, 0.85],  // pale violet
            [0.55, 0.75, 0.85],  // warm sky
            [0.80, 0.65, 0.45],  // warm copper
            [0.98, 0.92, 0.70],  // bright white-gold
            [0.70, 0.40, 0.80],  // deep violet
            [0.50, 0.85, 0.70],  // teal
            [0.95, 0.55, 0.30],  // orange
        ]

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch {
                print("InnerLight3DMetal pipeline error: \(error)")
            }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // MARK: - Build

        private func buildScene() {
            var rng = SplitMix64(seed: 42)

            // Shared geometry buffers
            let sunVerts = buildSphere(radius: 1.0, rings: 6, segments: 8,
                                       color: [0.12, 0.10, 0.08, 1])
            sunBuffer = makeVertexBuffer(sunVerts, device: device)
            sunVertCount = sunVerts.count

            let smallVerts = buildSphere(radius: 1.0, rings: 4, segments: 5,
                                         color: [0.10, 0.08, 0.06, 1])
            smallSunBuffer = makeVertexBuffer(smallVerts, device: device)
            smallSunVertCount = smallVerts.count

            let filVerts = buildCylinder(radius: 0.008, height: 1.0, segments: 4,
                                         color: [0.80, 0.65, 0.40, 1])
            filamentBuffer = makeVertexBuffer(filVerts, device: device)
            filamentVertCount = filVerts.count

            let nebVerts = buildSphere(radius: 1.0, rings: 8, segments: 10,
                                       color: [0.15, 0.10, 0.20, 1])
            nebulaBuffer = makeVertexBuffer(nebVerts, device: device)
            nebulaVertCount = nebVerts.count

            // Generate 30 suns spread across a large volume
            for _ in 0..<30 {
                let x = Float(Double.random(in: -25...25, using: &rng))
                let y = Float(Double.random(in: -15...15, using: &rng))
                let z = Float(Double.random(in: -25...25, using: &rng))
                let r = Float(Double.random(in: 0.2...1.2, using: &rng))
                let col = palette[Int.random(in: 0..<palette.count, using: &rng)]
                let bobPh = Float(Double.random(in: 0...(2 * .pi), using: &rng))
                let rotSpd = Float(Double.random(in: 0.2...0.7, using: &rng))
                suns.append(SunData(pos: [x, y, z], radius: r, emissiveColor: col,
                                    bobPhase: bobPh, rotSpeed: rotSpd,
                                    alive: true, velocity: .zero))
            }

            // Generate 12 nebula clouds — large translucent fog spheres
            for _ in 0..<12 {
                let x = Float(Double.random(in: -30...30, using: &rng))
                let y = Float(Double.random(in: -18...18, using: &rng))
                let z = Float(Double.random(in: -30...30, using: &rng))
                let r = Float(Double.random(in: 3.0...8.0, using: &rng))
                let nebColors: [SIMD3<Float>] = [
                    [0.35, 0.15, 0.50], // purple nebula
                    [0.15, 0.25, 0.50], // blue nebula
                    [0.50, 0.20, 0.30], // rose nebula
                    [0.20, 0.45, 0.40], // teal nebula
                    [0.55, 0.30, 0.15], // amber nebula
                ]
                let col = nebColors[Int.random(in: 0..<nebColors.count, using: &rng)]
                let driftPh = Float(Double.random(in: 0...(2 * .pi), using: &rng))
                nebulae.append(NebulaData(pos: [x, y, z], radius: r, color: col,
                                          driftPhase: driftPh, fadeAge: 0))
            }

            // Generate 200 sparks — tiny drifting luminous particles across the space
            for _ in 0..<200 {
                let x = Float(Double.random(in: -35...35, using: &rng))
                let y = Float(Double.random(in: -20...20, using: &rng))
                let z = Float(Double.random(in: -35...35, using: &rng))
                let vx = Float(Double.random(in: -0.3...0.3, using: &rng))
                let vy = Float(Double.random(in: 0.05...0.3, using: &rng))
                let vz = Float(Double.random(in: -0.3...0.3, using: &rng))
                let ph = Float(Double.random(in: 0...6.28, using: &rng))
                let spd = Float(Double.random(in: 0.1...0.5, using: &rng))
                let brightness = Float(Double.random(in: 0.5...1.0, using: &rng))
                let col: SIMD4<Float> = [0.95 * brightness, 0.75 * brightness, 0.35 * brightness, 0.6]
                let sz = Float(Double.random(in: 2.0...5.0, using: &rng))
                sparks.append(SparkData(pos: [x, y, z], vel: [vx, vy, vz],
                                        phase: ph, speed: spd, color: col, size: sz))
            }

            lastFrameTime = CACurrentMediaTime()
        }

        // MARK: - Camera

        private func updateCamera(dt: Float) {
            guard let inter = interaction else { return }
            let keys = inter.activeKeys
            let mouse = inter.mouseNormalized

            // Mouse look — offset from center (0.5, 0.5)
            let mx = mouse.x - 0.5
            let my = mouse.y - 0.5
            camYaw   -= mx * 0.03
            camPitch -= my * 0.02
            camPitch  = max(-.pi * 0.45, min(.pi * 0.45, camPitch))

            // Forward/right/up vectors from yaw/pitch
            let forward = SIMD3<Float>(
                -sin(camYaw) * cos(camPitch),
                 sin(camPitch),
                -cos(camYaw) * cos(camPitch)
            )
            let right = SIMD3<Float>(cos(camYaw), 0, -sin(camYaw))
            let up: SIMD3<Float> = [0, 1, 0]

            let speed: Float = 8.0 * dt
            if keys.contains("w") { camPos += forward * speed }
            if keys.contains("s") { camPos -= forward * speed }
            if keys.contains("a") { camPos -= right * speed }
            if keys.contains("d") { camPos += right * speed }
            if keys.contains("q") { camPos -= up * speed }
            if keys.contains("e") { camPos += up * speed }
        }

        private func viewMatrix() -> simd_float4x4 {
            let forward = SIMD3<Float>(
                -sin(camYaw) * cos(camPitch),
                 sin(camPitch),
                -cos(camYaw) * cos(camPitch)
            )
            return m4LookAt(eye: camPos, center: camPos + forward, up: [0, 1, 0])
        }

        private func cameraForward() -> SIMD3<Float> {
            return SIMD3<Float>(
                -sin(camYaw) * cos(camPitch),
                 sin(camPitch),
                -cos(camYaw) * cos(camPitch)
            )
        }

        // MARK: - Filament matrix

        private func filamentMatrix(from a: SIMD3<Float>, to b: SIMD3<Float>) -> simd_float4x4 {
            let mid = (a + b) * 0.5
            let diff = b - a
            let len = simd_length(diff)
            guard len > 0.001 else { return m4Translation(mid.x, mid.y, mid.z) }
            let dir = diff / len
            let upDir: SIMD3<Float> = [0, 1, 0]
            let dot = simd_dot(upDir, dir)
            let trans = m4Translation(mid.x, mid.y, mid.z)
            let scale = m4Scale(1, len, 1)
            if abs(dot) > 0.9999 {
                return trans * scale * (dot < 0 ? m4RotX(Float.pi) : matrix_identity_float4x4)
            }
            let axis = simd_normalize(simd_cross(upDir, dir))
            let angle = acos(min(1, max(-1, dot)))
            let c = cos(angle); let s = sin(angle); let omc = 1 - c
            let ax = axis.x; let ay = axis.y; let az = axis.z
            var rot = matrix_identity_float4x4
            rot.columns.0 = [c + ax*ax*omc,     ay*ax*omc + az*s,  az*ax*omc - ay*s, 0]
            rot.columns.1 = [ax*ay*omc - az*s,  c + ay*ay*omc,     az*ay*omc + ax*s, 0]
            rot.columns.2 = [ax*az*omc + ay*s,  ay*az*omc - ax*s,  c + az*az*omc,    0]
            return trans * rot * scale
        }

        // MARK: - Black hole

        private func updateBlackHole(dt: Float, t: Float) {
            guard let inter = interaction else { return }

            if inter.isHolding && blackHolePhase == 0 {
                blackHolePos = camPos + cameraForward() * 8.0
                blackHolePhase = 1
                blackHoleAge = 0
                blackHoleActive = true
            }

            if blackHolePhase == 1 {
                blackHoleAge += dt
                let pullRadius: Float = 6.0 + blackHoleAge * 2.0
                let pullStrength: Float = 3.0 + blackHoleAge * 1.5

                for i in suns.indices where suns[i].alive {
                    let toHole = blackHolePos - suns[i].pos
                    let dist = simd_length(toHole)
                    if dist < pullRadius && dist > 0.3 {
                        let force = simd_normalize(toHole) * pullStrength * dt / max(dist * 0.5, 0.5)
                        suns[i].velocity += force
                        suns[i].pos += suns[i].velocity * dt
                        if dist < 0.8 { suns[i].alive = false }
                    }
                }

                for i in sparks.indices {
                    let toHole = blackHolePos - sparks[i].pos
                    let dist = simd_length(toHole)
                    if dist < pullRadius * 1.5 && dist > 0.1 {
                        sparks[i].vel += simd_normalize(toHole) * pullStrength * 0.5 * dt / max(dist * 0.3, 0.3)
                    }
                }

                if !inter.isHolding || blackHoleAge > 8.0 {
                    blackHolePhase = 2
                    explosionAge = 0
                    var rng = SplitMix64(seed: UInt64(t * 1000))
                    explosionParticles = []
                    let deadCount = suns.filter { !$0.alive }.count
                    let particleCount = max(60, deadCount * 20)
                    for _ in 0..<particleCount {
                        let theta = Float(Double.random(in: 0...(2 * .pi), using: &rng))
                        let phi = Float(Double.random(in: -.pi...(.pi), using: &rng))
                        let speed = Float(Double.random(in: 3...12, using: &rng))
                        let vel = SIMD3<Float>(
                            cos(theta) * cos(phi) * speed,
                            sin(phi) * speed,
                            sin(theta) * cos(phi) * speed
                        )
                        let brightness = Float(Double.random(in: 0.6...1.0, using: &rng))
                        let nebColors: [SIMD4<Float>] = [
                            [0.5, 0.2, 0.7, 0.8], [0.2, 0.3, 0.7, 0.8],
                            [0.7, 0.3, 0.4, 0.8], [0.9, 0.7, 0.3, 0.8],
                            [0.3, 0.6, 0.5, 0.8],
                        ]
                        let col = nebColors[Int.random(in: 0..<nebColors.count, using: &rng)]
                            * [brightness, brightness, brightness, 1]
                        explosionParticles.append((pos: blackHolePos, vel: vel, color: col))
                    }
                }
            }

            if blackHolePhase == 2 {
                explosionAge += dt

                for i in explosionParticles.indices {
                    explosionParticles[i].pos += explosionParticles[i].vel * dt
                    explosionParticles[i].vel *= (1.0 - 0.8 * dt)
                }

                if explosionAge > 3.0 {
                    var rng = SplitMix64(seed: UInt64(t * 777))

                    // Spawn 2-3 new nebulae
                    for _ in 0..<Int.random(in: 2...3, using: &rng) {
                        let offset = SIMD3<Float>(
                            Float(Double.random(in: -5...5, using: &rng)),
                            Float(Double.random(in: -3...3, using: &rng)),
                            Float(Double.random(in: -5...5, using: &rng))
                        )
                        let nebColors: [SIMD3<Float>] = [
                            [0.45, 0.18, 0.55], [0.18, 0.30, 0.55],
                            [0.55, 0.22, 0.35], [0.25, 0.50, 0.45],
                        ]
                        nebulae.append(NebulaData(
                            pos: blackHolePos + offset,
                            radius: Float(Double.random(in: 3...6, using: &rng)),
                            color: nebColors[Int.random(in: 0..<nebColors.count, using: &rng)],
                            driftPhase: Float(Double.random(in: 0...6.28, using: &rng)),
                            fadeAge: t
                        ))
                    }

                    // Respawn dead suns scattered around explosion
                    for i in suns.indices where !suns[i].alive {
                        let offset = SIMD3<Float>(
                            Float(Double.random(in: -8...8, using: &rng)),
                            Float(Double.random(in: -5...5, using: &rng)),
                            Float(Double.random(in: -8...8, using: &rng))
                        )
                        suns[i].pos = blackHolePos + offset
                        suns[i].radius = Float(Double.random(in: 0.2...1.0, using: &rng))
                        suns[i].emissiveColor = palette[Int.random(in: 0..<palette.count, using: &rng)]
                        suns[i].velocity = .zero
                        suns[i].alive = true
                    }

                    // Add more sparks from explosion
                    for _ in 0..<30 {
                        let pos = blackHolePos + SIMD3<Float>(
                            Float(Double.random(in: -6...6, using: &rng)),
                            Float(Double.random(in: -4...4, using: &rng)),
                            Float(Double.random(in: -6...6, using: &rng))
                        )
                        let vel = SIMD3<Float>(
                            Float(Double.random(in: -0.5...0.5, using: &rng)),
                            Float(Double.random(in: 0.1...0.4, using: &rng)),
                            Float(Double.random(in: -0.5...0.5, using: &rng))
                        )
                        let brightness = Float(Double.random(in: 0.5...1.0, using: &rng))
                        sparks.append(SparkData(
                            pos: pos, vel: vel,
                            phase: Float(Double.random(in: 0...6.28, using: &rng)),
                            speed: Float(Double.random(in: 0.1...0.4, using: &rng)),
                            color: [0.95 * brightness, 0.75 * brightness, 0.35 * brightness, 0.6],
                            size: Float(Double.random(in: 2...5, using: &rng))
                        ))
                    }

                    blackHolePhase = 0
                    blackHoleActive = false
                    explosionParticles = []
                }
            }
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

            let now = CACurrentMediaTime()
            let dt = Float(min(now - lastFrameTime, 1.0 / 30.0))
            lastFrameTime = now
            let t = Float(now - startTime)

            // Update camera from WASD + mouse
            updateCamera(dt: dt)

            // Update black hole
            updateBlackHole(dt: dt, t: t)

            // Tap glow boost
            let glowBoost = max(0, 1 - (t - glowBoostT) / 2.0) * 1.5

            let view4 = viewMatrix()
            let proj4 = m4Perspective(fovyRad: 65 * .pi / 180, aspect: aspect, near: 0.05, far: 150)
            let vp = proj4 * view4

            let sunDir: SIMD3<Float> = simd_normalize([0.2, -0.5, -0.3])
            let sunCol: SIMD3<Float> = [0.08, 0.06, 0.12]
            let ambCol: SIMD3<Float> = [0.04, 0.03, 0.07]

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(sunDir, 0),
                sunColor:       SIMD4<Float>(sunCol, 0),
                ambientColor:   SIMD4<Float>(ambCol, t),
                fogParams:      SIMD4<Float>(30, 100, 0, 0),
                fogColor:       SIMD4<Float>(0.04, 0.03, 0.07, 0),
                cameraWorldPos: SIMD4<Float>(camPos, 0)
            )

            // === Opaque pass ===
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(depthState)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            encoder.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Draw filaments between nearby suns
            if let filBuf = filamentBuffer {
                let maxDist: Float = 8.0
                for i in 0..<suns.count where suns[i].alive {
                    for j in (i+1)..<suns.count where suns[j].alive {
                        let aPos = sunPosition(suns[i], t: t)
                        let bPos = sunPosition(suns[j], t: t)
                        let dist = simd_length(aPos - bPos)
                        guard dist < maxDist else { continue }
                        let model = filamentMatrix(from: aPos, to: bPos)
                        let pulse = 0.3 + 0.2 * sin(t * 1.6 + Float(i + j) * 0.7)
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: filBuf, vertexCount: filamentVertCount,
                                   model: model,
                                   emissiveColor: [0.80, 0.65, 0.40] * pulse,
                                   emissiveMix: 0.7, opacity: 0.3)
                    }
                }
            }

            // === Transparent / glow pass ===
            if let glow = glowPipeline {
                encoder.setRenderPipelineState(glow)
                encoder.setDepthStencilState(depthROState)

                // Draw nebula clouds (large translucent foggy spheres)
                if let nebBuf = nebulaBuffer {
                    for neb in nebulae {
                        let drift = SIMD3<Float>(
                            0.8 * sin(t * 0.03 + neb.driftPhase),
                            0.5 * cos(t * 0.025 + neb.driftPhase * 1.3),
                            0.6 * sin(t * 0.02 + neb.driftPhase * 0.7)
                        )
                        let nPos = neb.pos + drift
                        let breathe = neb.radius * (1.0 + 0.06 * sin(t * 0.4 + neb.driftPhase))
                        let model = m4Translation(nPos.x, nPos.y, nPos.z) * m4Scale(breathe, breathe, breathe)
                        var alpha: Float = 0.12
                        if neb.fadeAge > 0 {
                            let age = t - neb.fadeAge
                            alpha = min(0.12, age * 0.04)
                        }
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: nebBuf, vertexCount: nebulaVertCount,
                                   model: model,
                                   emissiveColor: neb.color * 0.6,
                                   emissiveMix: 0.9, opacity: alpha)
                    }
                }

                // Draw suns (glowing translucent spheres)
                for (i, sun) in suns.enumerated() where sun.alive {
                    let pos = sunPosition(sun, t: t)
                    let rotAngle = sun.rotSpeed * t
                    let model = m4Translation(pos.x, pos.y, pos.z)
                        * m4RotY(rotAngle) * m4RotX(rotAngle * 0.3)
                        * m4Scale(sun.radius, sun.radius, sun.radius)

                    let buf = sun.radius > 0.5 ? sunBuffer : smallSunBuffer
                    let cnt = sun.radius > 0.5 ? sunVertCount : smallSunVertCount
                    guard let vb = buf else { continue }

                    let pulse = 1.0 + 0.15 * sin(t * 1.2 + Float(i) * 0.9) + glowBoost
                    encodeDraw(encoder: encoder,
                               vertexBuffer: vb, vertexCount: cnt,
                               model: model,
                               emissiveColor: sun.emissiveColor * pulse,
                               emissiveMix: 0.85, opacity: 0.92)

                    // Corona glow — slightly larger, very transparent
                    let coronaScale = sun.radius * 1.5
                    let coronaModel = m4Translation(pos.x, pos.y, pos.z)
                        * m4Scale(coronaScale, coronaScale, coronaScale)
                    encodeDraw(encoder: encoder,
                               vertexBuffer: vb, vertexCount: cnt,
                               model: coronaModel,
                               emissiveColor: sun.emissiveColor * 0.5 * pulse,
                               emissiveMix: 1.0, opacity: 0.08)
                }

                // Draw black hole (dark sphere with accretion ring)
                if blackHoleActive, let sunBuf = sunBuffer {
                    let bhScale: Float
                    if blackHolePhase == 1 {
                        bhScale = 0.5 + blackHoleAge * 0.3
                    } else {
                        bhScale = max(0, (3.0 - explosionAge) * 0.5)
                    }
                    if bhScale > 0.01 {
                        let model = m4Translation(blackHolePos.x, blackHolePos.y, blackHolePos.z)
                            * m4Scale(bhScale, bhScale, bhScale)
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: sunBuf, vertexCount: sunVertCount,
                                   model: model,
                                   emissiveColor: [0.1, 0.0, 0.15],
                                   emissiveMix: 0.95, opacity: 0.9)
                        // Accretion ring
                        let ringScale = bhScale * 2.5
                        let ringModel = m4Translation(blackHolePos.x, blackHolePos.y, blackHolePos.z)
                            * m4RotX(Float.pi * 0.4 + t * 0.5)
                            * m4Scale(ringScale, 0.15, ringScale)
                        encodeDraw(encoder: encoder,
                                   vertexBuffer: sunBuf, vertexCount: sunVertCount,
                                   model: ringModel,
                                   emissiveColor: [0.6, 0.3, 0.8],
                                   emissiveMix: 1.0, opacity: 0.4)
                    }
                }
            }

            // === Particle pass ===
            if let ppipe = particlePipeline {
                encoder.setRenderPipelineState(ppipe)
                encoder.setDepthStencilState(depthROState)

                var particles: [ParticleVertex3D] = []

                // Sparks / motes
                for sp in sparks {
                    let yOff = fmod(t * sp.speed, 40.0) - 20.0
                    let px = sp.pos.x + 1.5 * sin(t * 0.15 + sp.phase)
                    let py = sp.pos.y + yOff
                    let pz = sp.pos.z + 1.2 * cos(t * 0.18 + sp.phase)
                    let alpha = (0.35 + 0.25 * sin(t * 0.6 + sp.phase))
                    particles.append(ParticleVertex3D(
                        position: [px, py, pz],
                        color: sp.color * [1, 1, 1, alpha],
                        size: sp.size
                    ))
                }

                // Explosion particles
                for ep in explosionParticles {
                    let fade = max(0, 1.0 - explosionAge / 3.5)
                    particles.append(ParticleVertex3D(
                        position: ep.pos,
                        color: ep.color * [1, 1, 1, fade],
                        size: 4.0
                    ))
                }

                // Black hole sucking visual — swirl particles toward hole
                if blackHolePhase == 1 {
                    let swirlCount = 40
                    for i in 0..<swirlCount {
                        let fi = Float(i) / Float(swirlCount)
                        let angle = fi * Float.pi * 6 + t * 3.0
                        let dist = (1 - fi) * 5.0
                        let px = blackHolePos.x + cos(angle) * dist
                        let py = blackHolePos.y + sin(angle * 0.7) * dist * 0.3
                        let pz = blackHolePos.z + sin(angle) * dist
                        let alpha = fi * 0.7
                        particles.append(ParticleVertex3D(
                            position: [px, py, pz],
                            color: [0.6, 0.3, 0.9, alpha],
                            size: 3.0 + fi * 4.0
                        ))
                    }
                }

                if !particles.isEmpty, let pbuf = makeParticleBuffer(particles, device: device) {
                    encoder.setVertexBuffer(pbuf, offset: 0, index: 0)
                    encoder.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    encoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particles.count)
                }
            }

            encoder.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }

        // MARK: - Helpers

        private func sunPosition(_ sun: SunData, t: Float) -> SIMD3<Float> {
            let bob = 0.2 * sin(t * 0.6 + sun.bobPhase)
            return sun.pos + [0, bob, 0]
        }
    }

    func makeCoordinator() -> Coordinator {
        let c = Coordinator()
        c.interaction = interaction
        return c
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: context.coordinator.device)
        view.delegate                 = context.coordinator
        view.colorPixelFormat         = .bgra8Unorm
        view.depthStencilPixelFormat  = .depth32Float
        view.clearColor               = MTLClearColor(red: 0.04, green: 0.03, blue: 0.07, alpha: 1)
        view.preferredFramesPerSecond = 60
        view.autoResizeDrawable       = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        c.interaction = interaction
        if tapCount != c.lastTapCount {
            c.lastTapCount = tapCount
            c.glowBoostT = Float(CACurrentMediaTime() - c.startTime)
        }
    }
}
