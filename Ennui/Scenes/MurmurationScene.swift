// MurmurationScene.swift — 2D Canvas boid murmuration.
//
// 500 points of warm light following three simple rules — separation, alignment,
// cohesion — and from those rules, something emerges that looks alive.
// No bird decides to make it beautiful. The beauty is emergent.
//
// Tap to send a gentle scare ripple through the flock.

import SwiftUI

struct MurmurationScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    // The simulation lives in a reference-type class so the Canvas can call
    // step() each frame without mutating @State (which would cause re-renders).
    // The @State reference itself never changes — only the object's internals do.
    @State private var sim = FlockSim2D()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                sim.step(t: now)

                let cx = size.width / 2
                let cy = size.height / 2
                let scale = min(size.width, size.height) / 640

                // --- Trails: oldest to newest, fading in ---
                for i in 0..<sim.count {
                    let trail = sim.trails[i]
                    for (j, pos) in trail.enumerated() {
                        let frac = Double(j + 1) / Double(sim.trailLen + 1)
                        let alpha = frac * 0.16
                        let r = (1.0 + frac * 0.7) * scale
                        let sx = cx + pos.x * scale
                        let sy = cy + pos.y * scale
                        ctx.fill(
                            Path(ellipseIn: CGRect(x: sx - r, y: sy - r,
                                                   width: 2 * r, height: 2 * r)),
                            with: .color(.init(red: 0.90, green: 0.82, blue: 0.65,
                                               opacity: alpha))
                        )
                    }
                }

                // --- Boids: warm cream dots ---
                for b in sim.boids {
                    let sx = cx + b.x * scale
                    let sy = cy + b.y * scale
                    let r = 2.0 * scale
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: sx - r, y: sy - r,
                                               width: 2 * r, height: 2 * r)),
                        with: .color(.init(red: 0.95, green: 0.88, blue: 0.72,
                                           opacity: 0.85))
                    )
                }
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .allowedDynamicRange(.high)
            .background(Color(red: 0.015, green: 0.015, blue: 0.05))
        }
        .onChange(of: interaction.tapCount) { _, _ in
            sim.scare(at: Date().timeIntervalSince(startDate))
        }
    }
}

// MARK: - 2D Flock Simulation

/// A plain reference type — NOT Observable, NOT ObservableObject.
/// Mutating its internals from within a Canvas closure does not trigger
/// SwiftUI re-renders (the @State reference itself is unchanged).
private final class FlockSim2D {

    struct Boid {
        var x, y: Double     // position  (coordinate space ≈ ±300)
        var vx, vy: Double   // velocity  (units/second)
    }

    let count       = 500
    let trailLen    = 6
    var boids:  [Boid]            = []
    var trails: [[SIMD2<Double>]] = []
    var lastT:  Double            = -1
    var scareT: Double            = -100
    var scareX  = 0.0
    var scareY  = 0.0
    var frameTick = 0

    // --- Tuning ---
    let visualRange     = 50.0
    let protectedRange  = 10.0
    let matchingFactor  = 0.05    // alignment
    let centeringFactor = 0.002   // cohesion
    let avoidFactor     = 0.06    // separation
    let maxSpeed        = 150.0
    let minSpeed        = 60.0
    let boundaryRadius  = 260.0
    let turnFactor      = 0.6

    init() {
        var rng = SplitMix64(seed: 2026)
        boids = (0..<count).map { _ in
            let angle = Double.random(in: 0...(2 * .pi), using: &rng)
            let speed = Double.random(in: 60...120, using: &rng)
            return Boid(
                x:  Double.random(in: -150...150, using: &rng),
                y:  Double.random(in: -150...150, using: &rng),
                vx: cos(angle) * speed,
                vy: sin(angle) * speed
            )
        }
        trails = Array(repeating: [], count: count)
    }

    // MARK: Step

    func step(t: Double) {
        guard lastT >= 0 else { lastT = t; return }
        let dt = min(t - lastT, 1.0 / 30.0)
        guard dt > 0.001 else { return }
        lastT = t

        // Scare
        let scareDt  = t - scareT
        let scareStr = scareDt < 3 ? 200 * max(0, 1 - scareDt / 2) : 0.0

        // Slow rotating wind — creates the sweeping turns
        let windA = t * 0.15
        let windX = cos(windA) * 5
        let windY = sin(windA) * 5

        let vr2 = visualRange * visualRange
        let pr2 = protectedRange * protectedRange

        for i in 0..<count {
            var closeX = 0.0, closeY = 0.0
            var avgVx  = 0.0, avgVy  = 0.0
            var avgX   = 0.0, avgY   = 0.0
            var neighbors = 0

            for j in 0..<count where j != i {
                let dx = boids[j].x - boids[i].x
                let dy = boids[j].y - boids[i].y
                let d2 = dx * dx + dy * dy

                if d2 < pr2 && d2 > 0 {
                    closeX -= dx
                    closeY -= dy
                }
                if d2 < vr2 {
                    avgVx += boids[j].vx
                    avgVy += boids[j].vy
                    avgX  += boids[j].x
                    avgY  += boids[j].y
                    neighbors += 1
                }
            }

            if neighbors > 0 {
                let n = Double(neighbors)
                boids[i].vx += (avgVx / n - boids[i].vx) * matchingFactor
                boids[i].vy += (avgVy / n - boids[i].vy) * matchingFactor
                boids[i].vx += (avgX / n - boids[i].x) * centeringFactor
                boids[i].vy += (avgY / n - boids[i].y) * centeringFactor
            }

            boids[i].vx += closeX * avoidFactor
            boids[i].vy += closeY * avoidFactor

            // Soft boundary — stronger push the further out
            let dist = sqrt(boids[i].x * boids[i].x + boids[i].y * boids[i].y)
            if dist > boundaryRadius {
                let excess = (dist - boundaryRadius) / boundaryRadius
                boids[i].vx -= boids[i].x / dist * turnFactor * (1 + excess * 3)
                boids[i].vy -= boids[i].y / dist * turnFactor * (1 + excess * 3)
            }

            // Wind
            boids[i].vx += windX * dt
            boids[i].vy += windY * dt

            // Scare ripple
            if scareStr > 0 {
                let sdx = boids[i].x - scareX
                let sdy = boids[i].y - scareY
                let sd  = max(sqrt(sdx * sdx + sdy * sdy), 1)
                boids[i].vx += sdx / sd * scareStr / (sd + 20) * dt
                boids[i].vy += sdy / sd * scareStr / (sd + 20) * dt
            }

            // Speed limits
            let speed = sqrt(boids[i].vx * boids[i].vx + boids[i].vy * boids[i].vy)
            if speed > maxSpeed {
                boids[i].vx = boids[i].vx / speed * maxSpeed
                boids[i].vy = boids[i].vy / speed * maxSpeed
            } else if speed < minSpeed && speed > 0 {
                boids[i].vx = boids[i].vx / speed * minSpeed
                boids[i].vy = boids[i].vy / speed * minSpeed
            }

            // Integrate
            boids[i].x += boids[i].vx * dt
            boids[i].y += boids[i].vy * dt
        }

        // Record trail positions every 3 frames — subtler, lighter
        frameTick += 1
        if frameTick % 3 == 0 {
            for i in 0..<count {
                trails[i].append(SIMD2(boids[i].x, boids[i].y))
                if trails[i].count > trailLen { trails[i].removeFirst() }
            }
        }
    }

    // MARK: Scare

    /// A gentle impulse near the flock center — the flock parts, then reforms.
    func scare(at t: Double) {
        scareT = t
        var cx = 0.0, cy = 0.0
        for b in boids { cx += b.x; cy += b.y }
        cx /= Double(count); cy /= Double(count)
        scareX = cx + Double.random(in: -40...40)
        scareY = cy + Double.random(in: -40...40)
    }
}
