// SilicaBench3DScene.swift — 3DMark-style GPU cathedral benchmark.
//
// A vast golden rotunda: 32 fluted columns support a great dome.
// At the centre, a celestial orrery — five concentric torus rings
// tilted on different axes, eleven orbiting planetary spheres, and a
// pulsing golden sun. Forty crystal octahedra float and turn through
// the space, catching warm directional light. Six thousand embers
// rise like fireflies. The camera glides through on a Catmull-Rom
// spline rail — threading between columns, sweeping over the orrery,
// diving low, rising high — as in those 2003 GPU benchmarks that
// made your fan spin up and your jaw drop.
//
// Tap to release a golden starburst of 300 particles.

import SwiftUI
import MetalKit

struct SilicaBench3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        SilicaBench3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable wrapper

private struct SilicaBench3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    // ================================================================
    // MARK: Coordinator — all Metal state lives here
    // ================================================================

    final class Coordinator: NSObject, MTKViewDelegate {

        // ---- Metal core ----
        let device: MTLDevice
        let commandQueue: MTLCommandQueue
        var opaquePSO:   MTLRenderPipelineState?
        var blendPSO:    MTLRenderPipelineState?
        var particlePSO: MTLRenderPipelineState?
        var depthRW:  MTLDepthStencilState?
        var depthRO:  MTLDepthStencilState?

        // ---- Static meshes (built once in buildScene) ----
        struct Mesh { var buf: MTLBuffer; var count: Int }

        var architectureMesh: Mesh?   // all pillars + capitals + bases + floor + beams
        var domeMesh:         Mesh?   // hemisphere ceiling
        var platformMesh:     Mesh?   // raised platform under orrery

        // ---- Orrery ----
        var ringMeshes: [Mesh] = []   // five torus rings
        var sunMesh:    Mesh?         // central golden sphere
        var planetMesh: Mesh?         // unit sphere, reused per planet

        struct RingCfg {
            var majorR: Float; var minorR: Float
            var tiltX: Float; var tiltZ: Float; var speed: Float
        }
        let ringCfgs: [RingCfg] = [
            .init(majorR: 4.0,  minorR: 0.09, tiltX:  0,     tiltZ:  0,    speed:  0.15),
            .init(majorR: 5.5,  minorR: 0.10, tiltX:  0.26,  tiltZ:  0.1,  speed: -0.12),
            .init(majorR: 7.0,  minorR: 0.10, tiltX: -0.35,  tiltZ:  0.15, speed:  0.08),
            .init(majorR: 9.0,  minorR: 0.12, tiltX:  0.52,  tiltZ: -0.1,  speed: -0.06),
            .init(majorR: 11.5, minorR: 0.12, tiltX: -0.17,  tiltZ:  0.2,  speed:  0.04),
        ]

        struct PlanetCfg {
            var orbitR: Float; var speed: Float; var size: Float
            var color: SIMD3<Float>; var tiltX: Float; var tiltZ: Float
            var emissive: Float
        }
        var planetCfgs: [PlanetCfg] = []

        // ---- Gems ----
        var gemMesh: Mesh?
        struct GemCfg { var pos: SIMD3<Float>; var rotSpeed: Float }
        var gemCfgs: [GemCfg] = []

        // ---- Camera rail ----
        var rail: [SIMD3<Float>] = []
        let railPeriod: Float = 90       // seconds per full loop

        // ---- Particles ----
        let emberCount = 6000
        struct Ember {
            var pos: SIMD3<Float>; var vel: SIMD3<Float>
            var life: Float; var maxLife: Float
            var size: Float; var brightness: Float
        }
        var embers: [Ember] = []
        var rng = SplitMix64(seed: 7070)

        struct Burst { var pos: SIMD3<Float>; var vel: SIMD3<Float>; var life: Float }
        var bursts: [Burst] = []

        // ---- Timing ----
        var startTime = CACurrentMediaTime()
        var lastFrame = CACurrentMediaTime()
        var lastTapCount = 0
        var aspect: Float = 1

        // ============================================================
        // MARK: Init
        // ============================================================

        override init() {
            device       = MTLCreateSystemDefaultDevice()!
            commandQueue = device.makeCommandQueue()!
            super.init()
            do {
                opaquePSO   = try makeOpaquePipeline(device: device)
                blendPSO    = try makeAlphaBlendPipeline(device: device)
                particlePSO = try makeParticlePipeline(device: device)
            } catch { print("SilicaBench3D pipeline error: \(error)") }
            depthRW = makeDepthState(device: device)
            depthRO = makeDepthReadOnlyState(device: device)
            buildAll()
        }

        // ============================================================
        // MARK: Scene construction
        // ============================================================

        private func buildAll() {
            buildRail()
            buildArchitecture()
            buildOrrery()
            buildGems()
            seedEmbers()
        }

        // ---- Camera rail (Catmull-Rom control points) ----

        private func buildRail() {
            rail = [
                SIMD3<Float>(  0,  22,  32),   // high overview from south
                SIMD3<Float>( 24,  11,  22),   // diving SE between outer pillars
                SIMD3<Float>( 28,   4,   5),   // very low east, threading pillars
                SIMD3<Float>( 18,   7, -18),   // rising NE, past inner ring
                SIMD3<Float>(  5,   9,  -3),   // close to orrery, intimate
                SIMD3<Float>( -8,  15, -24),   // pulling back NW, rising
                SIMD3<Float>(-26,   5,  -8),   // low west corridor
                SIMD3<Float>(-18,   8,  12),   // SW, between pillars
                SIMD3<Float>( -2,  18,  22),   // south, rising
                SIMD3<Float>( 12,  25,   8),   // dramatic high angle
            ]
        }

        // ---- Architecture (positions baked into vertices, one draw call) ----

        private func buildArchitecture() {
            var v: [Vertex3D] = []
            let stoneCol   = SIMD4<Float>(0.82, 0.70, 0.48, 1)
            let capCol     = SIMD4<Float>(0.90, 0.78, 0.50, 1)
            let floorCol   = SIMD4<Float>(0.06, 0.05, 0.08, 1)
            let beamCol    = SIMD4<Float>(0.75, 0.62, 0.40, 1)

            // 32 outer pillars (radius 25, height 18)
            let outerN = 32, outerR: Float = 25, pillarH: Float = 18
            for i in 0..<outerN {
                let a = 2 * Float.pi * Float(i) / Float(outerN)
                let cx = outerR * cos(a), cz = outerR * sin(a)
                appendOffset(&v, buildCylinder(radius: 0.55, height: pillarH,
                             segments: 24, color: stoneCol), dx: cx, dy: pillarH/2, dz: cz)
                appendOffset(&v, buildBox(w: 1.8, h: 0.7, d: 1.8, color: capCol),
                             dx: cx, dy: pillarH + 0.35, dz: cz)
                appendOffset(&v, buildBox(w: 1.6, h: 0.4, d: 1.6, color: capCol),
                             dx: cx, dy: 0.2, dz: cz)
            }

            // 12 inner pillars (radius 15, height 14)
            let innerN = 12, innerR: Float = 15, innerH: Float = 14
            for i in 0..<innerN {
                let a = 2 * Float.pi * Float(i) / Float(innerN) + Float.pi / Float(innerN)
                let cx = innerR * cos(a), cz = innerR * sin(a)
                appendOffset(&v, buildCylinder(radius: 0.4, height: innerH,
                             segments: 16, color: stoneCol), dx: cx, dy: innerH/2, dz: cz)
                appendOffset(&v, buildBox(w: 1.3, h: 0.5, d: 1.3, color: capCol),
                             dx: cx, dy: innerH + 0.25, dz: cz)
            }

            // Floor
            v += buildPlane(w: 70, d: 70, color: floorCol)

            // 8 radial arch beams connecting inner and outer rings
            for i in 0..<8 {
                let a = 2 * Float.pi * Float(i) / 8
                let midR = (innerR + outerR) * 0.5
                let cx = midR * cos(a), cz = midR * sin(a)
                let beamLen = outerR - innerR + 2
                let raw = buildBox(w: 0.6, h: 0.5, d: beamLen, color: beamCol)
                let cosA = cos(a), sinA = sin(a)
                for vx in raw {
                    let rx = vx.px * cosA - vx.pz * sinA
                    let rz = vx.px * sinA + vx.pz * cosA
                    v.append(Vertex3D(
                        position: [rx + cx, vx.py + 16, rz + cz],
                        normal:   [vx.nx * cosA - vx.nz * sinA, vx.ny,
                                   vx.nx * sinA + vx.nz * cosA],
                        color:    [vx.r, vx.g, vx.b, vx.a]))
                }
            }

            if let buf = makeVertexBuffer(v, device: device) {
                architectureMesh = Mesh(buf: buf, count: v.count)
            }

            // Dome (hemisphere, normals inward so we see the inside)
            let dome = buildHemisphere(radius: 28, rings: 24, segments: 40,
                                       color: SIMD4<Float>(0.10, 0.08, 0.16, 1),
                                       baseY: 18.5)
            if let buf = makeVertexBuffer(dome, device: device) {
                domeMesh = Mesh(buf: buf, count: dome.count)
            }

            // Central platform
            var plat = buildCylinder(radius: 3.5, height: 0.6, segments: 32,
                                     color: SIMD4<Float>(0.16, 0.12, 0.09, 1))
            for i in 0..<plat.count { plat[i] = offsetVert(plat[i], dy: 0.3) }
            if let buf = makeVertexBuffer(plat, device: device) {
                platformMesh = Mesh(buf: buf, count: plat.count)
            }
        }

        // ---- Orrery rings, sun, planets ----

        private func buildOrrery() {
            let ringCol = SIMD4<Float>(0.92, 0.78, 0.35, 1)
            for cfg in ringCfgs {
                let t = buildTorus(majorR: cfg.majorR, minorR: cfg.minorR,
                                   majSeg: 48, minSeg: 10, color: ringCol)
                if let buf = makeVertexBuffer(t, device: device) {
                    ringMeshes.append(Mesh(buf: buf, count: t.count))
                }
            }
            let sun = buildSphere(radius: 1.8, rings: 16, segments: 24,
                                  color: SIMD4<Float>(1.0, 0.88, 0.45, 1))
            if let buf = makeVertexBuffer(sun, device: device) { sunMesh = Mesh(buf: buf, count: sun.count) }

            let planet = buildSphere(radius: 1, rings: 10, segments: 14,
                                     color: SIMD4<Float>(0.6, 0.6, 0.6, 1))
            if let buf = makeVertexBuffer(planet, device: device) { planetMesh = Mesh(buf: buf, count: planet.count) }

            planetCfgs = [
                .init(orbitR: 4.0,  speed:  0.80, size: 0.25, color: [0.85, 0.70, 0.50], tiltX:  0.1,  tiltZ:  0,    emissive: 0.5),
                .init(orbitR: 5.5,  speed:  0.50, size: 0.35, color: [0.95, 0.75, 0.40], tiltX:  0.25, tiltZ:  0.1,  emissive: 0.5),
                .init(orbitR: 5.5,  speed: -0.30, size: 0.20, color: [0.50, 0.65, 0.80], tiltX:  0.25, tiltZ:  0.1,  emissive: 0.5),
                .init(orbitR: 7.0,  speed:  0.35, size: 0.28, color: [0.90, 0.55, 0.35], tiltX: -0.35, tiltZ:  0.15, emissive: 0.5),
                .init(orbitR: 7.0,  speed: -0.20, size: 0.18, color: [0.75, 0.75, 0.65], tiltX: -0.35, tiltZ:  0.15, emissive: 0.4),
                .init(orbitR: 9.0,  speed:  0.18, size: 0.55, color: [0.80, 0.65, 0.40], tiltX:  0.52, tiltZ: -0.1,  emissive: 0.45),
                .init(orbitR: 9.0,  speed: -0.12, size: 0.30, color: [0.70, 0.60, 0.50], tiltX:  0.52, tiltZ: -0.1,  emissive: 0.4),
                .init(orbitR: 11.5, speed:  0.10, size: 0.45, color: [0.88, 0.80, 0.55], tiltX: -0.17, tiltZ:  0.2,  emissive: 0.5),
                .init(orbitR: 11.5, speed: -0.08, size: 0.22, color: [0.60, 0.55, 0.70], tiltX: -0.17, tiltZ:  0.2,  emissive: 0.45),
                .init(orbitR: 13.0, speed:  0.06, size: 0.38, color: [0.85, 0.72, 0.48], tiltX:  0.30, tiltZ:  0.05, emissive: 0.4),
                .init(orbitR: 13.0, speed: -0.04, size: 0.20, color: [0.65, 0.70, 0.60], tiltX:  0.30, tiltZ:  0.05, emissive: 0.4),
            ]
        }

        // ---- Floating crystal gems ----

        private func buildGems() {
            let gem = buildOctahedron(radius: 1, color: SIMD4<Float>(0.95, 0.82, 0.45, 1))
            if let buf = makeVertexBuffer(gem, device: device) { gemMesh = Mesh(buf: buf, count: gem.count) }

            var g = SplitMix64(seed: 3003)
            for _ in 0..<40 {
                let a = Float.random(in: 0...(2 * .pi), using: &g)
                let r = Float.random(in: 6...23, using: &g)
                let y = Float.random(in: 3...17, using: &g)
                let spd = Float.random(in: 0.3...1.2, using: &g)
                gemCfgs.append(GemCfg(pos: [r * cos(a), y, r * sin(a)], rotSpeed: spd))
            }
        }

        // ---- Embers ----

        private func seedEmbers() {
            embers.reserveCapacity(emberCount)
            for _ in 0..<emberCount { embers.append(spawnEmber(fullRandom: true)) }
        }

        private func spawnEmber(fullRandom: Bool) -> Ember {
            let a   = Float.random(in: 0...(2 * .pi), using: &rng)
            let r   = Float.random(in: 1...28, using: &rng)
            let y   = fullRandom ? Float.random(in: 0...22, using: &rng) : Float.random(in: -1...1, using: &rng)
            let ml  = Float.random(in: 6...14, using: &rng)
            let lf  = fullRandom ? Float.random(in: 0...ml, using: &rng) : ml
            let br  = Float.random(in: 0.5...1.0, using: &rng)
            return Ember(
                pos: [r * cos(a), y, r * sin(a)],
                vel: [Float.random(in: -0.3...0.3, using: &rng),
                      Float.random(in: 0.4...1.2, using: &rng),
                      Float.random(in: -0.3...0.3, using: &rng)],
                life: lf, maxLife: ml,
                size: Float.random(in: 2...6, using: &rng),
                brightness: br)
        }

        // ============================================================
        // MARK: Geometry helpers (local to this scene)
        // ============================================================

        /// Append `src` vertices, offsetting each position by (dx, dy, dz).
        private func appendOffset(_ dst: inout [Vertex3D], _ src: [Vertex3D],
                                  dx: Float, dy: Float, dz: Float) {
            for s in src {
                dst.append(Vertex3D(position: [s.px + dx, s.py + dy, s.pz + dz],
                                    normal:   [s.nx, s.ny, s.nz],
                                    color:    [s.r, s.g, s.b, s.a]))
            }
        }

        private func offsetVert(_ v: Vertex3D, dy: Float) -> Vertex3D {
            Vertex3D(position: [v.px, v.py + dy, v.pz],
                     normal: [v.nx, v.ny, v.nz], color: [v.r, v.g, v.b, v.a])
        }

        /// Hemisphere (half-sphere), base at `baseY`, dome rising above.
        /// Normals point inward so we see the interior.
        private func buildHemisphere(radius r: Float, rings: Int, segments: Int,
                                     color: SIMD4<Float>, baseY: Float) -> [Vertex3D] {
            var v: [Vertex3D] = []
            for i in 0..<rings {
                let p0 = Float.pi * 0.5 * Float(i)   / Float(rings)
                let p1 = Float.pi * 0.5 * Float(i+1) / Float(rings)
                for j in 0..<segments {
                    let t0 = 2 * Float.pi * Float(j)   / Float(segments)
                    let t1 = 2 * Float.pi * Float(j+1) / Float(segments)
                    func sp(_ p: Float, _ t: Float) -> SIMD3<Float> {
                        [r*cos(p)*cos(t), r*sin(p) + baseY, r*cos(p)*sin(t)]
                    }
                    let pts = [sp(p0,t0), sp(p1,t0), sp(p0,t1), sp(p1,t1)]
                    let ns  = pts.map { -simd_normalize(SIMD3<Float>($0.x, $0.y - baseY, $0.z)) }
                    v += [Vertex3D(position: pts[0], normal: ns[0], color: color),
                          Vertex3D(position: pts[2], normal: ns[2], color: color),
                          Vertex3D(position: pts[1], normal: ns[1], color: color),
                          Vertex3D(position: pts[1], normal: ns[1], color: color),
                          Vertex3D(position: pts[2], normal: ns[2], color: color),
                          Vertex3D(position: pts[3], normal: ns[3], color: color)]
                }
            }
            return v
        }

        /// Torus centred at origin, lying in the XZ plane.
        private func buildTorus(majorR: Float, minorR: Float,
                                majSeg: Int, minSeg: Int,
                                color: SIMD4<Float>) -> [Vertex3D] {
            var v: [Vertex3D] = []
            for i in 0..<majSeg {
                let th0 = 2 * Float.pi * Float(i)   / Float(majSeg)
                let th1 = 2 * Float.pi * Float(i+1) / Float(majSeg)
                for j in 0..<minSeg {
                    let ph0 = 2 * Float.pi * Float(j)   / Float(minSeg)
                    let ph1 = 2 * Float.pi * Float(j+1) / Float(minSeg)
                    func tp(_ th: Float, _ ph: Float) -> SIMD3<Float> {
                        let rr = majorR + minorR * cos(ph)
                        return [rr * cos(th), minorR * sin(ph), rr * sin(th)]
                    }
                    func tn(_ th: Float, _ ph: Float) -> SIMD3<Float> {
                        simd_normalize([cos(ph)*cos(th), sin(ph), cos(ph)*sin(th)])
                    }
                    let p00=tp(th0,ph0), p10=tp(th1,ph0), p01=tp(th0,ph1), p11=tp(th1,ph1)
                    let n00=tn(th0,ph0), n10=tn(th1,ph0), n01=tn(th0,ph1), n11=tn(th1,ph1)
                    v += [Vertex3D(position: p00, normal: n00, color: color),
                          Vertex3D(position: p10, normal: n10, color: color),
                          Vertex3D(position: p01, normal: n01, color: color),
                          Vertex3D(position: p10, normal: n10, color: color),
                          Vertex3D(position: p11, normal: n11, color: color),
                          Vertex3D(position: p01, normal: n01, color: color)]
                }
            }
            return v
        }

        /// Regular octahedron — 8 triangular faces, 24 vertices, outward normals.
        private func buildOctahedron(radius r: Float, color: SIMD4<Float>) -> [Vertex3D] {
            let top: SIMD3<Float> = [0, r, 0], bot: SIMD3<Float> = [0, -r, 0]
            let eq: [SIMD3<Float>] = [[r,0,0], [0,0,r], [-r,0,0], [0,0,-r]]
            var v: [Vertex3D] = []
            for i in 0..<4 {
                let a = eq[i], b = eq[(i+1) % 4]
                let nT = simd_normalize(simd_cross(b - top, a - top))
                v += [Vertex3D(position: top, normal: nT, color: color),
                      Vertex3D(position: b,   normal: nT, color: color),
                      Vertex3D(position: a,   normal: nT, color: color)]
                let nB = simd_normalize(simd_cross(a - bot, b - bot))
                v += [Vertex3D(position: bot, normal: nB, color: color),
                      Vertex3D(position: a,   normal: nB, color: color),
                      Vertex3D(position: b,   normal: nB, color: color)]
            }
            return v
        }

        // ============================================================
        // MARK: Catmull-Rom spline
        // ============================================================

        private func catmullRom(_ p0: SIMD3<Float>, _ p1: SIMD3<Float>,
                                _ p2: SIMD3<Float>, _ p3: SIMD3<Float>,
                                t: Float) -> SIMD3<Float> {
            let t2 = t * t
            let t3 = t2 * t
            let a: SIMD3<Float> = 2.0 * p1
            let b: SIMD3<Float> = (p2 - p0) * t
            let term2a: SIMD3<Float> = 2.0 * p0 - 5.0 * p1
            let term2b: SIMD3<Float> = 4.0 * p2 - p3
            let c: SIMD3<Float> = (term2a + term2b) * t2
            let term3a: SIMD3<Float> = 3.0 * p1 - p0
            let term3b: SIMD3<Float> = p3 - 3.0 * p2
            let d: SIMD3<Float> = (term3a + term3b) * t3
            return 0.5 * (a + b + c + d)
        }

        private func evalSpline(_ pts: [SIMD3<Float>], at t: Float) -> SIMD3<Float> {
            let n = pts.count
            let total = t * Float(n)
            let seg = Int(total) % n
            let frac = total - floor(total)
            return catmullRom(pts[(seg - 1 + n) % n], pts[seg],
                              pts[(seg + 1) % n], pts[(seg + 2) % n], t: frac)
        }

        // ============================================================
        // MARK: Per-frame updates
        // ============================================================

        private func stepEmbers(dt: Float) {
            for i in 0..<embers.count {
                embers[i].life -= dt
                if embers[i].life <= 0 { embers[i] = spawnEmber(fullRandom: false); continue }
                embers[i].pos += embers[i].vel * dt
                // gentle swirl
                let p = embers[i].pos
                embers[i].pos.x += sin(p.y * 0.5 + p.x) * 0.15 * dt
                embers[i].pos.z += cos(p.y * 0.5 + p.z) * 0.15 * dt
            }
        }

        private func stepBursts(dt: Float) {
            for i in (0..<bursts.count).reversed() {
                bursts[i].life -= dt
                if bursts[i].life <= 0 { bursts.remove(at: i); continue }
                bursts[i].pos += bursts[i].vel * dt
                bursts[i].vel.y -= 2.5 * dt
                bursts[i].vel *= (1 - 0.4 * dt)
            }
        }

        // ============================================================
        // MARK: Per-frame particle buffer
        // ============================================================

        private func buildParticles(t: Float) -> (MTLBuffer, Int)? {
            var pv: [ParticleVertex3D] = []
            pv.reserveCapacity(emberCount + bursts.count + 50)

            // Embers
            for e in embers {
                let age = e.maxLife - e.life
                let fadeIn  = min(age / 1.5, 1.0)
                let fadeOut = min(e.life / 2.0, 1.0)
                let a = fadeIn * fadeOut * 0.35 * e.brightness
                if a < 0.005 { continue }
                pv.append(ParticleVertex3D(
                    position: e.pos,
                    color: [0.95 * e.brightness, 0.75 * e.brightness, 0.30 * e.brightness, a],
                    size: e.size))
            }

            // Burst
            for b in bursts {
                let a = min(b.life / 0.5, 1) * 0.55
                pv.append(ParticleVertex3D(position: b.pos,
                                           color: [1.0, 0.85, 0.40, a],
                                           size: 4 + (1 - min(b.life / 3, 1)) * 4))
            }

            // Sun corona — orbiting glow points
            for i in 0..<40 {
                let fi = Float(i)
                let a = fi / 40 * 2 * Float.pi + t * 0.3
                let r: Float = 2.2 + sin(t * 2 + fi * 0.5) * 0.5
                let y: Float = 8 + sin(t * 1.5 + fi * 0.3) * 0.8
                pv.append(ParticleVertex3D(
                    position: [r * cos(a), y, r * sin(a)],
                    color: [1.0, 0.90, 0.50, 0.22],
                    size: 8 + sin(t * 3 + fi) * 3))
            }

            guard !pv.isEmpty, let buf = makeParticleBuffer(pv, device: device) else { return nil }
            return (buf, pv.count)
        }

        // ============================================================
        // MARK: draw(in:) — the render loop
        // ============================================================

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            aspect = size.width > 0 ? Float(size.width / size.height) : 1
        }

        func draw(in view: MTKView) {
            let now = CACurrentMediaTime()
            let t   = Float(now - startTime)
            let dt  = min(Float(now - lastFrame), 1.0 / 30.0)
            lastFrame = now

            stepEmbers(dt: dt)
            stepBursts(dt: dt)

            guard let opaque = opaquePSO,
                  let drawable = view.currentDrawable,
                  let rpd      = view.currentRenderPassDescriptor,
                  let cmdBuf   = commandQueue.makeCommandBuffer(),
                  let enc      = cmdBuf.makeRenderCommandEncoder(descriptor: rpd)
            else { return }

            // ---- Camera on rail ----
            let splineT = fmod(t / railPeriod, 1.0)
            let eye = evalSpline(rail, at: splineT)
            let lookY: Float = 8 + sin(t * 0.1) * 2
            let lookAt = SIMD3<Float>(sin(t * 0.05) * 2.5, lookY, cos(t * 0.05) * 2.5)

            let vp = m4Perspective(fovyRad: 55 * .pi / 180, aspect: aspect,
                                    near: 0.1, far: 200) *
                     m4LookAt(eye: eye, center: lookAt, up: [0, 1, 0])

            var su = SceneUniforms3D(
                viewProjection: vp,
                sunDirection:   SIMD4<Float>(simd_normalize(SIMD3<Float>(0.3, -0.8, -0.4)), 0),
                sunColor:       SIMD4<Float>(1.0, 0.90, 0.70, 0),
                ambientColor:   SIMD4<Float>(0.10, 0.08, 0.06, t),
                fogParams:      SIMD4<Float>(50, 130, 0, 0),
                fogColor:       SIMD4<Float>(0.015, 0.012, 0.025, 0),
                cameraWorldPos: SIMD4<Float>(eye, 0))

            enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
            enc.setFragmentBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)

            // ======== OPAQUE PASS ========
            enc.setRenderPipelineState(opaque)
            enc.setDepthStencilState(depthRW)
            enc.setCullMode(.back)

            // Architecture
            if let m = architectureMesh {
                encodeDraw(encoder: enc, vertexBuffer: m.buf, vertexCount: m.count,
                           model: matrix_identity_float4x4, specularPower: 16)
            }
            // Dome (see inside ⇒ no cull)
            if let m = domeMesh {
                enc.setCullMode(.none)
                encodeDraw(encoder: enc, vertexBuffer: m.buf, vertexCount: m.count,
                           model: matrix_identity_float4x4,
                           emissiveColor: SIMD3<Float>(0.04, 0.03, 0.06),
                           emissiveMix: 0.3, specularPower: 8)
                enc.setCullMode(.back)
            }
            // Platform
            if let m = platformMesh {
                encodeDraw(encoder: enc, vertexBuffer: m.buf, vertexCount: m.count,
                           model: matrix_identity_float4x4,
                           emissiveColor: [0.12, 0.08, 0.04], emissiveMix: 0.3, specularPower: 64)
            }

            // Central sun (pulsing emissive)
            let orreryBase = m4Translation(0, 8, 0) * m4RotY(t * 0.02) // slow global precession
            if let m = sunMesh {
                let pulse: Float = 0.8 + sin(t * 2) * 0.2
                let sc: Float = 1 + sin(t * 0.5) * 0.04
                let sunModel = orreryBase * m4Scale(sc, sc, sc)
                encodeDraw(encoder: enc, vertexBuffer: m.buf, vertexCount: m.count,
                           model: sunModel,
                           emissiveColor: SIMD3<Float>(1.0, 0.85, 0.40) * pulse,
                           emissiveMix: 0.92, specularPower: 128)
            }

            // Orrery rings
            for (i, cfg) in ringCfgs.enumerated() where i < ringMeshes.count {
                let rm = ringMeshes[i]
                let model = orreryBase * m4RotX(cfg.tiltX) * m4RotZ(cfg.tiltZ) * m4RotY(t * cfg.speed)
                encodeDraw(encoder: enc, vertexBuffer: rm.buf, vertexCount: rm.count,
                           model: model,
                           emissiveColor: [0.85, 0.70, 0.30], emissiveMix: 0.45, specularPower: 64)
            }

            // Planets
            if let pm = planetMesh {
                for cfg in planetCfgs {
                    let orbitAngle = t * cfg.speed
                    let px = cfg.orbitR * cos(orbitAngle)
                    let pz = cfg.orbitR * sin(orbitAngle)
                    let model = orreryBase *
                                m4RotX(cfg.tiltX) * m4RotZ(cfg.tiltZ) *
                                m4Translation(px, 0, pz) *
                                m4Scale(cfg.size, cfg.size, cfg.size)
                    encodeDraw(encoder: enc, vertexBuffer: pm.buf, vertexCount: pm.count,
                               model: model,
                               emissiveColor: cfg.color, emissiveMix: cfg.emissive,
                               specularPower: 48)
                }
            }

            // Gems (both sides visible)
            enc.setCullMode(.none)
            if let gm = gemMesh {
                for cfg in gemCfgs {
                    let rot = t * cfg.rotSpeed
                    let bob = sin(t * 0.5 + cfg.pos.x + cfg.pos.z) * 0.3
                    let model = m4Translation(cfg.pos.x, cfg.pos.y + bob, cfg.pos.z) *
                                m4RotY(rot) * m4RotX(rot * 0.7) *
                                m4Scale(0.4, 0.6, 0.4)
                    encodeDraw(encoder: enc, vertexBuffer: gm.buf, vertexCount: gm.count,
                               model: model,
                               emissiveColor: [0.95, 0.80, 0.35],
                               emissiveMix: 0.5 + sin(t * 2 + cfg.pos.y) * 0.2,
                               specularPower: 128)
                }
            }

            // ======== PARTICLE PASS (additive) ========
            if let ppso = particlePSO, let (pbuf, pcount) = buildParticles(t: t) {
                enc.setRenderPipelineState(ppso)
                enc.setDepthStencilState(depthRO)
                enc.setVertexBuffer(pbuf, offset: 0, index: 0)
                enc.setVertexBytes(&su, length: MemoryLayout<SceneUniforms3D>.size, index: 1)
                enc.drawPrimitives(type: .point, vertexStart: 0, vertexCount: pcount)
            }

            enc.endEncoding()
            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }

    // ================================================================
    // MARK: NSViewRepresentable plumbing
    // ================================================================

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let v = MTKView(frame: .zero, device: context.coordinator.device)
        v.delegate                  = context.coordinator
        v.colorPixelFormat          = .bgra8Unorm
        v.depthStencilPixelFormat   = .depth32Float
        v.clearColor                = MTLClearColor(red: 0.015, green: 0.012, blue: 0.025, alpha: 1)
        v.preferredFramesPerSecond  = 60
        v.autoResizeDrawable        = true
        return v
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount

        // Golden starburst near the orrery centre
        let t = Float(CACurrentMediaTime() - c.startTime)
        let center = SIMD3<Float>(Float.random(in: -2...2),
                                   Float.random(in: 6...10),
                                   Float.random(in: -2...2))
        var rng = SplitMix64(seed: UInt64(t * 1000) & 0xFFFFFF)
        for _ in 0..<300 {
            let dir = simd_normalize(SIMD3<Float>(
                Float.random(in: -1...1, using: &rng),
                Float.random(in: -1...1, using: &rng),
                Float.random(in: -1...1, using: &rng)))
            c.bursts.append(Coordinator.Burst(
                pos: center,
                vel: dir * Float.random(in: 4...12, using: &rng),
                life: Float.random(in: 1...3, using: &rng)))
        }
    }
}
