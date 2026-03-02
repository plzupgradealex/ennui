import SwiftUI

struct DeepOceanScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    struct Particle {
        let x, baseY, size, speed, brightness, hue, phase: Double
        let layer: Int
    }
    struct Jelly {
        let x, baseY, size, speed, phase, hue: Double
        let tents: Int
    }
    struct BioFlash: Identifiable {
        let id = UUID()
        let x, y, birth: Double
        let seed: UInt64
    }
    struct SeafloorPeak {
        let x, height: Double
    }
    struct DeepSpeck {
        let x, y, size, phase, rate: Double
    }

    @State private var particles: [Particle] = []
    @State private var jellies: [Jelly] = []
    @State private var flashes: [BioFlash] = []
    @State private var seafloor: [SeafloorPeak] = []
    @State private var deepSpecks: [DeepSpeck] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBG(ctx: &ctx, size: size, t: t)
                drawRays(ctx: &ctx, size: size, t: t)
                drawSeafloor(ctx: &ctx, size: size, t: t)
                drawDeepSpecks(ctx: &ctx, size: size, t: t)
                drawCurrents(ctx: &ctx, size: size, t: t)
                drawParticles(ctx: &ctx, size: size, t: t)
                drawJellies(ctx: &ctx, size: size, t: t)
                drawFlashes(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            flashes.append(BioFlash(x: loc.x, y: loc.y, birth: t, seed: UInt64(t * 1000) & 0xFFFFFF))
            if flashes.count > 8 { flashes.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 0xAB155)

        particles = (0..<160).map { i in
            Particle(x: Double.random(in: 0...1, using: &rng),
                     baseY: Double.random(in: 0...1, using: &rng),
                     size: Double.random(in: 0.8...5, using: &rng),
                     speed: Double.random(in: 0.005...0.025, using: &rng),
                     brightness: Double.random(in: 0.2...1.0, using: &rng),
                     hue: Double.random(in: 0.45...0.7, using: &rng),
                     phase: Double.random(in: 0...(.pi * 2), using: &rng),
                     layer: i < 50 ? 0 : (i < 110 ? 1 : 2))
        }
        jellies = (0..<8).map { _ in
            Jelly(x: Double.random(in: 0.08...0.92, using: &rng),
                  baseY: Double.random(in: 0.15...0.75, using: &rng),
                  size: Double.random(in: 25...85, using: &rng),
                  speed: Double.random(in: 0.002...0.008, using: &rng),
                  phase: Double.random(in: 0...(.pi * 2), using: &rng),
                  hue: Double.random(in: 0.5...0.9, using: &rng),
                  tents: Int.random(in: 5...9, using: &rng))
        }
        seafloor = (0..<20).map { i in
            SeafloorPeak(
                x: Double(i) / 19.0,
                height: Double.random(in: 0.02...0.08, using: &rng)
            )
        }
        deepSpecks = (0..<25).map { _ in
            DeepSpeck(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0.6...0.95, using: &rng),
                size: Double.random(in: 0.5...1.5, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng),
                rate: Double.random(in: 0.3...0.9, using: &rng)
            )
        }
        ready = true
    }

    private func drawBG(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let s = sin(t * 0.02) * 0.02
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.0 + s, green: 0.02, blue: 0.10),
                Color(red: 0.0, green: 0.04 + s, blue: 0.18),
                Color(red: 0.0, green: 0.03, blue: 0.12),
                Color(red: 0.0, green: 0.01, blue: 0.04),
            ]), startPoint: .zero, endPoint: CGPoint(x: size.width * 0.3, y: size.height)))
    }

    private func drawRays(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 35))
            for i in 0..<6 {
                let bx = size.width * (0.15 + Double(i) * 0.13)
                let sway = sin(t * 0.15 + Double(i) * 1.3) * 40
                let pulse = sin(t * 0.1 + Double(i) * 0.7) * 0.01 + 0.04
                var p = Path()
                p.move(to: CGPoint(x: bx + sway - 15, y: -10))
                p.addLine(to: CGPoint(x: bx + sway + 15, y: -10))
                p.addLine(to: CGPoint(x: bx + sway + 70, y: size.height * 0.65))
                p.addLine(to: CGPoint(x: bx + sway - 70, y: size.height * 0.65))
                p.closeSubpath()
                l.fill(p, with: .color(Color(red: 0.08, green: 0.25, blue: 0.45).opacity(pulse)))
            }
        }
    }

    private func drawCurrents(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 20))
            l.opacity = 0.04
            for i in 0..<4 {
                let yb = size.height * (0.2 + Double(i) * 0.2)
                var p = Path()
                p.move(to: CGPoint(x: -20, y: yb))
                for x in stride(from: 0.0, through: size.width + 20, by: 10) {
                    p.addLine(to: CGPoint(x: x, y: yb + sin(x * 0.005 + t * 0.2 + Double(i) * 2) * 30))
                }
                l.stroke(p, with: .color(Color(hue: 0.55, saturation: 0.5, brightness: 0.8)), lineWidth: 20)
            }
        }
    }

    // MARK: - Seafloor silhouette

    private func drawSeafloor(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseY = size.height * 0.92
        var floor = Path()
        floor.move(to: CGPoint(x: 0, y: size.height))
        for peak in seafloor {
            let x = peak.x * size.width
            let sway = sin(t * 0.05 + peak.x * 6) * 3
            let y = baseY - peak.height * size.height + sway
            floor.addLine(to: CGPoint(x: x, y: y))
        }
        floor.addLine(to: CGPoint(x: size.width, y: size.height))
        floor.closeSubpath()
        ctx.fill(floor, with: .color(Color(red: 0.01, green: 0.015, blue: 0.03).opacity(0.8)))

        // Faint warm glow along the ridgeline
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 12))
            for peak in seafloor where peak.height > 0.05 {
                let x = peak.x * size.width
                let y = baseY - peak.height * size.height
                let s = 8.0
                l.fill(Ellipse().path(in: CGRect(x: x - s, y: y - s * 0.5, width: s * 2, height: s)),
                    with: .color(Color(hue: 0.55, saturation: 0.6, brightness: 0.8).opacity(0.06)))
            }
        }
    }

    // MARK: - Distant bioluminescent specks

    private func drawDeepSpecks(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for speck in deepSpecks {
            let pulse = sin(t * speck.rate + speck.phase)
            // Only visible during the bright half of the pulse cycle
            let alpha = max(0, pulse) * 0.2
            guard alpha > 0.01 else { continue }
            let x = speck.x * size.width + sin(t * 0.1 + speck.phase) * 5
            let y = speck.y * size.height
            let s = speck.size
            ctx.fill(Ellipse().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                with: .color(Color(hue: 0.52, saturation: 0.6, brightness: 1.2).opacity(alpha)))
        }
    }

    private func drawParticles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Draw all particle cores directly (no layers)
        for p in particles {
            let li = min(p.layer, 2)
            let la = [0.3, 0.6, 1.0][li]
            let ls = [0.6, 1.0, 1.5][li]
            let x = (p.x + sin(t * 0.2 + p.phase) * 0.025) * size.width
            let y = fmod(p.baseY - t * p.speed * ls + 10, 1.0) * size.height
            let pulse = sin(t + p.phase) * 0.3 + 0.7
            let alpha = p.brightness * pulse * la
            let c = Color(hue: p.hue, saturation: 0.7, brightness: 1.3)
            let s = p.size * (0.8 + pulse * 0.3)

            ctx.fill(Ellipse().path(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                with: .color(c.opacity(alpha * 0.6)))
        }

        // Single shared glow layer for all large particles (was ~60 separate layers!)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 6))
            for p in particles {
                let li = min(p.layer, 2)
                let la = [0.3, 0.6, 1.0][li]
                let ls = [0.6, 1.0, 1.5][li]
                let x = (p.x + sin(t * 0.2 + p.phase) * 0.025) * size.width
                let y = fmod(p.baseY - t * p.speed * ls + 10, 1.0) * size.height
                let pulse = sin(t + p.phase) * 0.3 + 0.7
                let alpha = p.brightness * pulse * la
                let c = Color(hue: p.hue, saturation: 0.7, brightness: 1.3)
                let s = p.size * (0.8 + pulse * 0.3)
                guard s > 3 else { continue }
                l.fill(Ellipse().path(in: CGRect(x: x - s * 2, y: y - s * 2, width: s * 4, height: s * 4)),
                    with: .color(c.opacity(alpha * 0.10)))
            }
        }
    }

    private func drawJellies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Single shared glow layer for all jellies (was 8 separate nested layers)
        ctx.drawLayer { gl in
            gl.addFilter(.blur(radius: 25))
            for jf in jellies {
                let x = (jf.x + sin(t * jf.speed * 5 + jf.phase) * 0.06) * size.width
                let y = (jf.baseY + sin(t * jf.speed * 3 + jf.phase) * 0.04) * size.height
                let s = jf.size
                let c = Color(hue: jf.hue, saturation: 0.5, brightness: 0.85)
                let pulse = sin(t * 0.6 + jf.phase) * 0.5 + 0.5
                let alpha = (0.25 + pulse * 0.25) * 0.12 * pulse
                gl.fill(Ellipse().path(in: CGRect(x: x - s * 0.8, y: y - s * 0.5, width: s * 1.6, height: s)),
                    with: .color(c.opacity(alpha)))
            }
        }

        // Draw each jelly body + tentacles in one layer (no nesting)
        for jf in jellies {
            let x = (jf.x + sin(t * jf.speed * 5 + jf.phase) * 0.06) * size.width
            let y = (jf.baseY + sin(t * jf.speed * 3 + jf.phase) * 0.04) * size.height
            let s = jf.size
            let c = Color(hue: jf.hue, saturation: 0.5, brightness: 0.85)
            let pulse = sin(t * 0.6 + jf.phase) * 0.5 + 0.5
            let contract = sin(t * 0.8 + jf.phase) * 0.1 + 0.9
            let alpha = 0.25 + pulse * 0.25

            ctx.drawLayer { l in
                l.opacity = alpha

                // Bell — radialGradient already provides softness, no inner blur layer needed
                let bw = s * contract
                let bh = s * 0.55 * (1.1 - contract * 0.1)
                l.fill(Ellipse().path(in: CGRect(x: x - bw / 2, y: y - bh / 2, width: bw, height: bh)),
                    with: .radialGradient(
                        Gradient(colors: [c.opacity(0.6), c.opacity(0.2), c.opacity(0.05)]),
                        center: CGPoint(x: x, y: y - bh * 0.1), startRadius: 0, endRadius: bw * 0.5))
                // Inner highlight
                l.fill(Ellipse().path(in: CGRect(x: x - bw * 0.25, y: y - bh * 0.2, width: bw * 0.5, height: bh * 0.4)),
                    with: .color(Color(red: 0.7, green: 1.4, blue: 1.6).opacity(0.12 * pulse)))

                // Tentacles
                for ti in 0..<jf.tents {
                    let f = Double(ti) / Double(max(jf.tents - 1, 1))
                    let tx = x - bw * 0.35 + bw * 0.7 * f
                    let tw = sin(t * 1.2 + Double(ti) * 0.6 + jf.phase) * (8 + s * 0.1)
                    let tl = s * 0.6 + sin(t * 0.5 + Double(ti)) * s * 0.15
                    var path = Path()
                    path.move(to: CGPoint(x: tx, y: y + bh * 0.2))
                    path.addCurve(
                        to: CGPoint(x: tx + tw, y: y + bh * 0.2 + tl),
                        control1: CGPoint(x: tx + tw * 0.3, y: y + bh * 0.2 + tl * 0.3),
                        control2: CGPoint(x: tx + tw * 0.8, y: y + bh * 0.2 + tl * 0.6))
                    l.stroke(path, with: .color(c.opacity(0.3)), lineWidth: 1.2)
                }
            }
        }
    }

    private func drawFlashes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for fl in flashes {
            let age = t - fl.birth
            guard age < 7.0 else { continue }
            let p = age / 7.0

            // Central bioluminescent bloom — two pulses
            let pulse1 = age < 0.5 ? age / 0.5 : max(0, 1.0 - (age - 0.5) / 2.5)
            let pulse2 = age > 1.5 && age < 2.0 ? (age - 1.5) / 0.5 : (age >= 2.0 ? max(0, 1.0 - (age - 2.0) / 2.0) : 0)
            let bloomIntensity = max(pulse1, pulse2 * 0.5)

            if bloomIntensity > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 20 + p * 35))
                    let r = 25 + p * 80
                    l.fill(Ellipse().path(in: CGRect(x: fl.x - r, y: fl.y - r,
                                                     width: r * 2, height: r * 2)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 0.3, green: 1.5, blue: 1.7).opacity(0.30 * bloomIntensity),
                                Color(red: 0.4, green: 1.0, blue: 1.3).opacity(0.10 * bloomIntensity),
                                Color(red: 0.6, green: 0.3, blue: 1.2).opacity(0.04 * bloomIntensity),
                                .clear
                            ]),
                            center: CGPoint(x: fl.x, y: fl.y),
                            startRadius: 0, endRadius: r))
                }
            }

            // Jellyfish-like tendrils extending from center
            var rng = SplitMix64(seed: fl.seed)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 6))
                for _ in 0..<8 {
                    let baseAngle = nextDouble(&rng) * .pi * 2
                    let curveBias = (nextDouble(&rng) - 0.5) * 2.0
                    let tendrilSpeed = nextDouble(&rng) * 0.5 + 0.4
                    let lifespan = nextDouble(&rng) * 3.0 + 3.5
                    guard age < lifespan else { continue }
                    let tp = age / lifespan
                    let tendrilFade = tp < 0.15 ? tp / 0.15 : max(0, 1.0 - (tp - 0.15) / 0.85)
                    let len = tp * tendrilSpeed * 120

                    var path = Path()
                    path.move(to: CGPoint(x: fl.x, y: fl.y))
                    let steps = 10
                    for s in 1...steps {
                        let sf = Double(s) / Double(steps)
                        let dist = sf * len
                        let angle = baseAngle + sf * curveBias + sin(age * 0.8 + sf * 3) * 0.3
                        let wx = fl.x + cos(angle) * dist
                        let wy = fl.y + sin(angle) * dist + sf * 15 // slight downward drift
                        path.addLine(to: CGPoint(x: wx, y: wy))
                    }

                    let warmth = nextDouble(&rng)
                    let col = warmth > 0.5
                        ? Color(red: 0.2, green: 1.3, blue: 1.5)
                        : Color(red: 0.5, green: 0.3, blue: 1.3)
                    l.stroke(path, with: .color(col.opacity(tendrilFade * 0.18)),
                        lineWidth: 2.0 * tendrilFade)
                }
            }

            // Chain-reaction particles spreading outward
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                for _ in 0..<14 {
                    let angle = nextDouble(&rng) * .pi * 2
                    let driftSpeed = nextDouble(&rng) * 0.5 + 0.3
                    let delay = nextDouble(&rng) * 1.0
                    let moteAge = age - delay
                    guard moteAge > 0 else { continue }
                    let lifespan = nextDouble(&rng) * 2.5 + 3.0
                    guard moteAge < lifespan else { continue }
                    let mp = moteAge / lifespan
                    let moteFade = mp < 0.1 ? mp / 0.1 : max(0, 1.0 - (mp - 0.1) / 0.9)
                    let dist = mp * driftSpeed * 100
                    let wobble = sin(moteAge * 1.5 + nextDouble(&rng) * 6) * 10
                    let mx = fl.x + cos(angle) * dist + wobble
                    let my = fl.y + sin(angle) * dist * 0.7 + mp * 20
                    let sz = (nextDouble(&rng) * 2.0 + 1.5) * moteFade
                    let pulse = sin(moteAge * 3.0 + nextDouble(&rng) * 6) * 0.3 + 0.7
                    let warmth = nextDouble(&rng)
                    let color = warmth > 0.5
                        ? Color(red: 0.2, green: 1.4, blue: 1.6)
                        : Color(red: 0.5, green: 0.4, blue: 1.4)
                    l.fill(Ellipse().path(in: CGRect(x: mx - sz, y: my - sz, width: sz * 2, height: sz * 2)),
                        with: .color(color.opacity(moteFade * 0.45 * pulse)))
                }
            }
        }
    }
}
