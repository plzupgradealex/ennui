// Benchmark3DScene.swift — Metal 3D GPU benchmark inspired by 3DMark 2001–2006.
//
// A rail camera sweeps through a golden crystalline cathedral containing a massive
// rotating orrery of concentric torus rings, orbiting planets, and floating gems.
// 5000 additive particles — rising embers, orbital sparkles, ambient dust — fill
// the warm fog. ~80k triangles + 5000 particles rebuilt per frame at 60fps.
//
// Designed to push an M1 MacBook Air GPU while remaining beautiful.
// Tap to send a burst of golden sparks from the orrery heart.

import SwiftUI
import MetalKit

struct Benchmark3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        Benchmark3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct Benchmark3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // MARK: Coordinator

    final class Coordinator: NSObject, MTKViewDelegate {

        // Metal state
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePipeline:   MTLRenderPipelineState?
        var glowPipeline:     MTLRenderPipelineState?
        var particlePipeline: MTLRenderPipelineState?
        var depthState:   MTLDepthStencilState?
        var depthROState: MTLDepthStencilState?

        // ── Static geometry (pre-transformed, single draw call each) ──

        var architectureBuffer: MTLBuffer?
        var architectureCount  = 0

        var floorBuffer: MTLBuffer?
        var floorCount  = 0

        // ── Orrery ──

        var sunBuffer:     MTLBuffer?
        var sunCount      = 0
        var sunHaloBuffer: MTLBuffer?
        var sunHaloCount  = 0

        struct OrreryRing {
            var buffer: MTLBuffer; var count: Int
            var axis: SIMD3<Float>; var speed: Float
            var emissiveColor: SIMD3<Float>
        }
        var rings: [OrreryRing] = []

        struct OrreryPlanet {
            var buffer: MTLBuffer; var count: Int
            var ringIdx: Int; var angleOffset: Float
            var orbitRadius: Float; var emissiveColor: SIMD3<Float>
        }
        var planets: [OrreryPlanet] = []

        // ── Floating gems ──

        struct GemData {
            var buffer: MTLBuffer; var count: Int
            var orbit: Float; var height: Float; var speed: Float
            var phase: Float; var bobSpeed: Float
            var emissive: SIMD3<Float>
        }
        var gems: [GemData] = []

        // ── Particles (precomputed params, rebuilt each frame) ──

        struct EmberP    { var x, z, speed, phase, size, warmth: Float }
        struct SparkleP  { var radius, speed, phase, hBase, hAmp, hSpeed, brightness: Float }
        struct DustP     { var pos: SIMD3<Float>; var drift: SIMD3<Float>; var brightness, size: Float }

        var embers:   [EmberP]   = []
        var sparkles: [SparkleP] = []
        var dustMotes: [DustP]   = []

        // ── Tap burst ──
        var burstT: Float = -100
        var lastTapCount  = 0

        // ── Timing ──
        var startTime = CACurrentMediaTime()
        var aspect: Float = 1

        // ── Camera rail ──

        struct CamKey { var eye: SIMD3<Float>; var target: SIMD3<Float> }

        let camKeys: [CamKey] = [
            CamKey(eye: [0,   3,  -50], target: [0,  8,  0]),   // far approach
            CamKey(eye: [0,   4,  -15], target: [0, 10, 10]),   // entering aisle
            CamKey(eye: [-14, 8,    5], target: [0,  8,  0]),   // left sweep
            CamKey(eye: [0,  25,   20], target: [0,  5, -5]),   // bird's eye
            CamKey(eye: [16, 10,    0], target: [0,  8,-10]),   // right sweep
            CamKey(eye: [5,   3,   -8], target: [0,  9,  5]),   // low close pass
            CamKey(eye: [-3,  5,  -30], target: [0,  8,  0]),   // pulling out
            CamKey(eye: [0,   3,  -50], target: [0,  8,  0]),   // loop
        ]
        let loopDuration: Float = 60

        // ====================================================================
        // MARK: Init
        // ====================================================================

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePipeline   = try makeOpaquePipeline(device: device)
                glowPipeline     = try makeAlphaBlendPipeline(device: device)
                particlePipeline = try makeParticlePipeline(device: device)
            } catch { print("Benchmark3D pipeline error: \(error)") }
            depthState   = makeDepthState(device: device)
            depthROState = makeDepthReadOnlyState(device: device)
            buildScene()
        }

        // ====================================================================
        // MARK: Geometry Helpers
        // ====================================================================

        /// Pre-transform vertices by a model matrix so they can be merged into
        /// a single buffer and drawn with the identity model.
        private func xform(_ verts: [Vertex3D], _ model: simd_float4x4) -> [Vertex3D] {
            let nm = m4NormalMatrix(from: model)
            return verts.map { v in
                let p = model * SIMD4<Float>(v.px, v.py, v.pz, 1)
                let n = nm   * SIMD4<Float>(v.nx, v.ny, v.nz, 0)
                return Vertex3D(
                    position: [p.x, p.y, p.z],
                    normal:   simd_normalize([n.x, n.y, n.z]),
                    color:    SIMD4<Float>(v.r, v.g, v.b, v.a))
            }
        }

        /// Torus centred at origin, major circle in XZ plane, minor circle in
        /// the plane containing the centre line and Y.
        private func buildTorus(majorR: Float, minorR: Float,
                                majorSeg: Int, minorSeg: Int,
                                color: SIMD4<Float>) -> [Vertex3D] {
            var verts: [Vertex3D] = []
            verts.reserveCapacity(majorSeg * minorSeg * 6)
            for i in 0..<majorSeg {
                let t0 = 2 * Float.pi * Float(i)     / Float(majorSeg)
                let t1 = 2 * Float.pi * Float(i + 1) / Float(majorSeg)
                for j in 0..<minorSeg {
                    let p0 = 2 * Float.pi * Float(j)     / Float(minorSeg)
                    let p1 = 2 * Float.pi * Float(j + 1) / Float(minorSeg)

                    func tp(_ t: Float, _ p: Float) -> (SIMD3<Float>, SIMD3<Float>) {
                        let pos = SIMD3<Float>(
                            (majorR + minorR * cos(p)) * cos(t),
                            minorR * sin(p),
                            (majorR + minorR * cos(p)) * sin(t))
                        let nor = simd_normalize(SIMD3<Float>(
                            cos(p) * cos(t), sin(p), cos(p) * sin(t)))
                        return (pos, nor)
                    }
                    let (a, na) = tp(t0, p0), (b, nb) = tp(t1, p0)
                    let (c, nc) = tp(t0, p1), (d, nd) = tp(t1, p1)
                    verts += [
                        Vertex3D(position: a, normal: na, color: color),
                        Vertex3D(position: b, normal: nb, color: color),
                        Vertex3D(position: c, normal: nc, color: color),
                        Vertex3D(position: b, normal: nb, color: color),
                        Vertex3D(position: d, normal: nd, color: color),
                        Vertex3D(position: c, normal: nc, color: color),
                    ]
                }
            }
            return verts
        }

        /// Rotation matrix around an arbitrary unit axis.
        private func axisAngle(_ axis: SIMD3<Float>, _ angle: Float) -> simd_float4x4 {
            let n = simd_normalize(axis)
            let c = cos(angle), s = sin(angle), t: Float = 1 - c
            let x = n.x, y = n.y, z = n.z
            return simd_float4x4(columns: (
                SIMD4<Float>(t*x*x + c,     t*x*y + s*z,  t*x*z - s*y, 0),
                SIMD4<Float>(t*x*y - s*z,   t*y*y + c,    t*y*z + s*x, 0),
                SIMD4<Float>(t*x*z + s*y,   t*y*z - s*x,  t*z*z + c,   0),
                SIMD4<Float>(0, 0, 0, 1)
            ))
        }

        // ====================================================================
        // MARK: Build Scene
        // ====================================================================

        private func buildScene() {
            var rng = SplitMix64(seed: 3001)

            // ── Architecture (pre-transformed, merged) ──

            var arch: [Vertex3D] = []
            let sandstone: SIMD4<Float>     = [0.72, 0.58, 0.40, 1]
            let darkStone: SIMD4<Float>     = [0.50, 0.42, 0.32, 1]
            let archBeam:  SIMD4<Float>     = [0.65, 0.52, 0.38, 1]
            let platform:  SIMD4<Float>     = [0.55, 0.45, 0.35, 1]

            // Inner pillars: 2 rows of 8 at X = ±4
            for row in [-4, 4] as [Float] {
                for i in 0..<8 {
                    let z = Float(i) * 6 - 21
                    arch += xform(buildCylinder(radius: 0.55, height: 14,
                                                segments: 20, color: sandstone),
                                  m4Translation(row, 7, z))
                    arch += xform(buildBox(w: 1.4, h: 0.3, d: 1.4, color: sandstone),
                                  m4Translation(row, 0.15, z))
                    arch += xform(buildBox(w: 1.2, h: 0.3, d: 1.2, color: sandstone),
                                  m4Translation(row, 14.15, z))
                }
            }

            // Outer pillars: 2 rows at X = ±10
            for row in [-10, 10] as [Float] {
                for i in 0..<8 {
                    let z = Float(i) * 6 - 21
                    arch += xform(buildCylinder(radius: 0.4, height: 11,
                                                segments: 16, color: darkStone),
                                  m4Translation(row, 5.5, z))
                    arch += xform(buildBox(w: 1.0, h: 0.2, d: 1.0, color: darkStone),
                                  m4Translation(row, 0.1, z))
                }
            }

            // Crossbar arches bridging inner rows
            for i in 0..<8 {
                let z = Float(i) * 6 - 21
                arch += xform(buildBox(w: 8, h: 0.5, d: 0.8, color: archBeam),
                              m4Translation(0, 14.5, z))
            }

            // Side beams inner → outer
            for i in 0..<8 {
                let z = Float(i) * 6 - 21
                for x in [-7, 7] as [Float] {
                    arch += xform(buildBox(w: 6, h: 0.3, d: 0.5, color: darkStone),
                                  m4Translation(x, 11.25, z))
                }
            }

            // Central stepped platform
            for step in 0..<4 {
                let s = Float(step)
                let w = 6 - s * 1.2
                arch += xform(buildBox(w: w, h: 0.4, d: w, color: platform),
                              m4Translation(0, s * 0.4 + 0.2, 0))
            }

            // Decorative pedestal spheres on outer pillars (8 pedestals)
            for side in [-10, 10] as [Float] {
                for i in stride(from: 0, to: 8, by: 2) {
                    let z = Float(i) * 6 - 21
                    arch += xform(buildSphere(radius: 0.45, rings: 8, segments: 12,
                                              color: [0.80, 0.65, 0.40, 1]),
                                  m4Translation(side, 11.8, z))
                }
            }

            architectureBuffer = makeVertexBuffer(arch, device: device)
            architectureCount  = arch.count

            // ── Floor ──
            let floorV = buildPlane(w: 60, d: 80, color: [0.07, 0.06, 0.05, 1])
            floorBuffer = makeVertexBuffer(floorV, device: device)
            floorCount  = floorV.count

            // ── Sun (orrery centre at Y = 8) ──
            let sunV = buildSphere(radius: 1.5, rings: 16, segments: 24,
                                   color: [1.0, 0.92, 0.70, 1])
            sunBuffer = makeVertexBuffer(sunV, device: device)
            sunCount  = sunV.count

            let haloV = buildSphere(radius: 2.4, rings: 10, segments: 18,
                                    color: [1, 0.85, 0.50, 0.2])
            sunHaloBuffer = makeVertexBuffer(haloV, device: device)
            sunHaloCount  = haloV.count

            // ── Orrery rings (tori on tilted axes) ──

            let ringCfg: [(Float, Float, SIMD3<Float>, Float, SIMD3<Float>)] = [
                (3.5,  0.08, simd_normalize([0,    1, 0.1]),  0.80, [0.9, 0.7, 0.3]),
                (5.5,  0.06, simd_normalize([0.2,  1, 0]),    0.50, [0.7, 0.5, 0.9]),
                (7.5,  0.05, simd_normalize([-0.15,1, 0.1]),  0.35, [0.3, 0.7, 0.9]),
                (9.5,  0.04, simd_normalize([0.1,  1,-0.2]),  0.22, [0.9, 0.4, 0.4]),
                (11.5, 0.035,simd_normalize([0,    1, 0.15]), 0.15, [0.6, 0.9, 0.5]),
                (13.5, 0.03, simd_normalize([-0.1, 1,-0.1]),  0.10, [0.8, 0.6, 0.3]),
            ]
            for (mR, nR, ax, sp, em) in ringCfg {
                let v = buildTorus(majorR: mR, minorR: nR,
                                   majorSeg: 64, minorSeg: 12,
                                   color: [0.7, 0.6, 0.5, 1])
                if let buf = makeVertexBuffer(v, device: device) {
                    rings.append(OrreryRing(buffer: buf, count: v.count,
                                            axis: ax, speed: sp, emissiveColor: em))
                }
            }

            // ── Planets on rings ──

            let pCfg: [(Int, Float, Float, SIMD3<Float>, SIMD4<Float>)] = [
                (0, 0.0,           0.35, [1.0, 0.8, 0.3], [0.9, 0.7, 0.4, 1]),
                (0, .pi,           0.25, [0.9, 0.6, 0.2], [0.8, 0.6, 0.3, 1]),
                (1, 0.5,           0.45, [0.6, 0.4, 0.9], [0.5, 0.3, 0.8, 1]),
                (1, 2.5,           0.30, [0.7, 0.5, 0.8], [0.6, 0.4, 0.7, 1]),
                (2, 1.0,           0.50, [0.3, 0.6, 0.9], [0.2, 0.5, 0.8, 1]),
                (2, 3.5,           0.35, [0.4, 0.7, 0.8], [0.3, 0.6, 0.7, 1]),
                (3, 0.8,           0.40, [0.9, 0.3, 0.3], [0.8, 0.2, 0.2, 1]),
                (4, 1.5,           0.38, [0.5, 0.8, 0.4], [0.4, 0.7, 0.3, 1]),
                (4, 4.0,           0.28, [0.6, 0.9, 0.5], [0.5, 0.8, 0.4, 1]),
                (5, 2.0,           0.32, [0.8, 0.5, 0.2], [0.7, 0.5, 0.3, 1]),
                (5, 5.0,           0.22, [0.7, 0.6, 0.3], [0.6, 0.5, 0.3, 1]),
            ]
            for (ri, aOff, rad, em, col) in pCfg {
                let v = buildSphere(radius: rad, rings: 10, segments: 14, color: col)
                if let buf = makeVertexBuffer(v, device: device) {
                    planets.append(OrreryPlanet(buffer: buf, count: v.count,
                                                ringIdx: ri, angleOffset: aOff,
                                                orbitRadius: ringCfg[ri].0,
                                                emissiveColor: em))
                }
            }

            // ── Floating gems ──

            let gemCols: [SIMD3<Float>] = [
                [1.0, 0.8, 0.3], [0.8, 0.5, 1.0], [0.3, 0.8, 1.0],
                [1.0, 0.4, 0.4], [0.5, 1.0, 0.5], [1.0, 0.7, 0.2],
            ]
            for i in 0..<40 {
                let r = Float.random(in: 0.15...0.35, using: &rng)
                let v = buildSphere(radius: r, rings: 8, segments: 12,
                                    color: [0.9, 0.85, 0.75, 0.6])
                if let buf = makeVertexBuffer(v, device: device) {
                    gems.append(GemData(
                        buffer: buf, count: v.count,
                        orbit:    Float.random(in: 5...20,       using: &rng),
                        height:   Float.random(in: 3...16,       using: &rng),
                        speed:    Float.random(in: 0.12...0.45,  using: &rng),
                        phase:    Float.random(in: 0...(2 * .pi),using: &rng),
                        bobSpeed: Float.random(in: 0.3...1.0,    using: &rng),
                        emissive: gemCols[i % gemCols.count]))
                }
            }

            // ── Particle parameters (precomputed, animated in draw) ──

            for _ in 0..<2000 {
                embers.append(EmberP(
                    x:      Float.random(in: -18...18, using: &rng),
                    z:      Float.random(in: -28...28, using: &rng),
                    speed:  Float.random(in: 1.5...4.0, using: &rng),
                    phase:  Float.random(in: 0...22, using: &rng),
                    size:   Float.random(in: 2...6, using: &rng),
                    warmth: Float.random(in: 0...1, using: &rng)))
            }

            for _ in 0..<2000 {
                sparkles.append(SparkleP(
                    radius:     Float.random(in: 2...15,       using: &rng),
                    speed:      Float.random(in: 0.2...0.8,    using: &rng),
                    phase:      Float.random(in: 0...(2 * .pi),using: &rng),
                    hBase:      8,
                    hAmp:       Float.random(in: 1...6,        using: &rng),
                    hSpeed:     Float.random(in: 0.3...1.2,    using: &rng),
                    brightness: Float.random(in: 0.3...1.0,    using: &rng)))
            }

            for _ in 0..<1000 {
                dustMotes.append(DustP(
                    pos: SIMD3<Float>(Float.random(in: -22...22, using: &rng),
                                      Float.random(in: 1...18,   using: &rng),
                                      Float.random(in: -32...32, using: &rng)),
                    drift: SIMD3<Float>(Float.random(in: -0.3...0.3, using: &rng),
                                        Float.random(in: -0.1...0.2, using: &rng),
                                        Float.random(in: -0.3...0.3, using: &rng)),
                    brightness: Float.random(in: 0.15...0.5, using: &rng),
                    size:       Float.random(in: 1...3, using: &rng)))
            }
        }

        // ====================================================================
        // MARK: Camera Spline
        // ====================================================================

        private func catmullRom(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>,
                                _ p2: SIMD3<Float>, _ p3: SIMD3<Float>,
                                _ t: Float) -> SIMD3<Float> {
            let t2 = t * t, t3 = t2 * t
            return 0.5 * ((2 * p1) +
                           (-p0 + p2) * t +
                           (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                           (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
        }

        private func cameraAt(_ t: Float) -> (eye: SIMD3<Float>, target: SIMD3<Float>) {
            let n = camKeys.count - 1                           // 7 segments
            let norm = fmod(t, loopDuration) / loopDuration     // 0..<1
            let posF = norm * Float(n)                          // 0..<7
            let seg  = min(Int(posF), n - 1)
            let frac = posF - Float(seg)

            func w(_ i: Int) -> Int { ((i % n) + n) % n }
            let i0 = w(seg-1), i1 = w(seg), i2 = w(seg+1), i3 = w(seg+2)

            let eye = catmullRom(camKeys[i0].eye,    camKeys[i1].eye,
                                 camKeys[i2].eye,    camKeys[i3].eye, frac)
            let tgt = catmullRom(camKeys[i0].target, camKeys[i1].target,
                                 camKeys[i2].target, camKeys[i3].target, frac)
            return (eye, tgt)
        }

        // ====================================================================
        // MARK: Draw
        // ====================================================================

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            guard let opaque   = opaquePipeline,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            let t   = Float(CACurrentMediaTime() - startTime)
            let cam = cameraAt(t)

            let vp = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect,
                                    near: 0.1, far: 120) *
                     m4LookAt(eye: cam.eye, center: cam.target, up: [0, 1, 0])

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize([-0.2, -0.7, -0.4] as SIMD3<Float>), 0),
                sunColor:       [1.0, 0.92, 0.75, 0],
                ambientColor:   [0.12, 0.09, 0.06, t],
                fogParams:      [35, 65, 0, 0],
                fogColor:       [0.04, 0.03, 0.025, 0],
                cameraWorldPos: SIMD4<Float>(cam.eye, 0))

            // ── Opaque pass ──

            enc.setRenderPipelineState(opaque)
            enc.setDepthStencilState(depthState)
            enc.setCullMode(.back)
            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // Architecture (single merged buffer)
            if let buf = architectureBuffer, architectureCount > 0 {
                encodeDraw(encoder: enc, vertexBuffer: buf, vertexCount: architectureCount,
                           model: matrix_identity_float4x4,
                           emissiveColor: [0.15, 0.10, 0.05], emissiveMix: 0.08,
                           opacity: 1, specularPower: 24)
            }

            // Floor
            if let buf = floorBuffer, floorCount > 0 {
                encodeDraw(encoder: enc, vertexBuffer: buf, vertexCount: floorCount,
                           model: matrix_identity_float4x4,
                           emissiveColor: .zero, emissiveMix: 0,
                           opacity: 1, specularPower: 128)
            }

            // Central sun (pulsing scale)
            if let buf = sunBuffer, sunCount > 0 {
                let p = 1.0 + 0.06 * sin(t * 1.5)
                let m = m4Translation(0, 8, 0) * m4Scale(p, p, p)
                encodeDraw(encoder: enc, vertexBuffer: buf, vertexCount: sunCount,
                           model: m, emissiveColor: [1, 0.9, 0.6], emissiveMix: 1,
                           opacity: 1, specularPower: 16)
            }

            // Orrery rings
            for ring in rings {
                let rm = axisAngle(ring.axis, t * ring.speed)
                let m  = m4Translation(0, 8, 0) * rm
                encodeDraw(encoder: enc, vertexBuffer: ring.buffer, vertexCount: ring.count,
                           model: m, emissiveColor: ring.emissiveColor, emissiveMix: 0.6,
                           opacity: 1, specularPower: 64)
            }

            // Orbiting planets
            for planet in planets {
                let ring = rings[planet.ringIdx]
                let rm   = axisAngle(ring.axis, t * ring.speed)
                let local = SIMD4<Float>(
                    planet.orbitRadius * cos(planet.angleOffset), 0,
                    planet.orbitRadius * sin(planet.angleOffset), 1)
                let world = rm * local
                let m = m4Translation(world.x, 8 + world.y, world.z)
                encodeDraw(encoder: enc, vertexBuffer: planet.buffer, vertexCount: planet.count,
                           model: m, emissiveColor: planet.emissiveColor, emissiveMix: 0.5,
                           opacity: 1, specularPower: 48)
            }

            // ── Transparent / glow pass ──

            if let glow = glowPipeline {
                enc.setRenderPipelineState(glow)
                enc.setDepthStencilState(depthROState)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

                // Sun halo
                if let buf = sunHaloBuffer, sunHaloCount > 0 {
                    let p = 1.0 + 0.12 * sin(t * 1.2)
                    let m = m4Translation(0, 8, 0) * m4Scale(p, p, p)
                    encodeDraw(encoder: enc, vertexBuffer: buf, vertexCount: sunHaloCount,
                               model: m, emissiveColor: [1, 0.85, 0.5], emissiveMix: 1,
                               opacity: 0.22 * p, specularPower: 8)
                }

                // Floating gems
                for gem in gems {
                    let a = t * gem.speed + gem.phase
                    let bob = sin(t * gem.bobSpeed + gem.phase) * 1.5
                    let m = m4Translation(gem.orbit * cos(a),
                                          gem.height + bob,
                                          gem.orbit * sin(a))
                    encodeDraw(encoder: enc, vertexBuffer: gem.buffer, vertexCount: gem.count,
                               model: m, emissiveColor: gem.emissive, emissiveMix: 1,
                               opacity: 0.65, specularPower: 16)
                }
            }

            // ── Particle pass (5000 rebuilt per frame) ──

            if let ppipe = particlePipeline {
                var pv: [ParticleVertex3D] = []
                pv.reserveCapacity(5300)

                // Rising embers
                for e in embers {
                    let y     = fmod(e.speed * t + e.phase, 22)
                    let drift = sin(t * 0.3 + e.phase) * 1.8
                    let alpha = min(1, y / 3) * max(0, 1 - (y - 18) / 4) * 0.45
                    let w     = e.warmth
                    pv.append(ParticleVertex3D(
                        position: [e.x + drift, y, e.z],
                        color: [0.9 + w * 0.1, 0.55 + w * 0.35, 0.15 + (1 - w) * 0.2, alpha],
                        size: e.size * (0.7 + 0.3 * sin(t * 2 + e.phase))))
                }

                // Orrery sparkles
                for s in sparkles {
                    let a  = t * s.speed + s.phase
                    let y  = s.hBase + sin(t * s.hSpeed + s.phase) * s.hAmp
                    let tw = 0.5 + 0.5 * sin(t * 3 + s.phase)
                    pv.append(ParticleVertex3D(
                        position: [s.radius * cos(a), y, s.radius * sin(a)],
                        color: [0.85, 0.75, 0.55, s.brightness * tw * 0.35],
                        size: 2 + tw * 3))
                }

                // Ambient dust
                for d in dustMotes {
                    let raw = d.pos + d.drift * fmod(t, 80)
                    let x  = fmod(raw.x + 22, 44) - 22
                    let y  = fmod(raw.y, 20)
                    let z  = fmod(raw.z + 32, 64) - 32
                    let tw = 0.6 + 0.4 * sin(t * 0.8 + d.pos.x * 3)
                    pv.append(ParticleVertex3D(
                        position: [x, y, z],
                        color: [0.7, 0.65, 0.55, d.brightness * tw * 0.2],
                        size: d.size))
                }

                // Tap burst: 300 golden sparks
                let burstAge = t - burstT
                if burstAge >= 0 && burstAge < 3.5 {
                    let fade = max(0, 1 - burstAge / 3.5)
                    var brng = SplitMix64(seed: UInt64(burstT * 1000))
                    for _ in 0..<300 {
                        let th  = Float.random(in: 0...(2 * .pi), using: &brng)
                        let phi = Float.random(in: 0...(.pi), using: &brng)
                        let spd = Float.random(in: 3...14, using: &brng)
                        let dir = SIMD3<Float>(sin(phi) * cos(th),
                                               abs(sin(phi) * sin(th)) * 0.6 + 0.4,
                                               cos(phi))
                        let pos = SIMD3<Float>(0, 8, 0) + dir * spd * burstAge
                        let w = Float.random(in: 0...1, using: &brng)
                        pv.append(ParticleVertex3D(
                            position: pos,
                            color: [1, 0.7 + w * 0.3, 0.2 + w * 0.3, fade * 0.75],
                            size: Float.random(in: 3...9, using: &brng) * fade))
                    }
                }

                if let pbuf = makeParticleBuffer(pv, device: device), !pv.isEmpty {
                    enc.setRenderPipelineState(ppipe)
                    enc.setDepthStencilState(depthROState)
                    enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                    enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                    enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pv.count)
                }
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    // MARK: NSViewRepresentable

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate                 = context.coordinator
        v.colorPixelFormat         = .bgra8Unorm
        v.depthStencilPixelFormat  = .depth32Float
        v.clearColor               = MTLClearColor(red: 0.03, green: 0.025, blue: 0.02, alpha: 1)
        v.preferredFramesPerSecond = 60
        v.autoResizeDrawable       = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        c.burstT = Float(CACurrentMediaTime() - c.startTime)
    }
}
