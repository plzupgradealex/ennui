import SwiftUI

struct AncientRuinsScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    struct Firefly {
        let bx, by, wander, speed, phase, brightness: Double
    }
    struct FlyBurst: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    @State private var fireflies: [Firefly] = []
    @State private var bursts: [FlyBurst] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawAurora(ctx: &ctx, size: size, t: t)
                drawMountains(ctx: &ctx, size: size)
                drawRuins(ctx: &ctx, size: size, t: t)
                drawMist(ctx: &ctx, size: size, t: t)
                drawFireflies(ctx: &ctx, size: size, t: t)
                drawBursts(ctx: &ctx, size: size, t: t)
                drawGoldenDust(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            bursts.append(FlyBurst(x: loc.x, y: loc.y, birth: Date().timeIntervalSince(startDate)))
            if bursts.count > 8 { bursts.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 0xAE72C1)
        fireflies = (0..<50).map { _ in
            Firefly(bx: Double.random(in: 0.05...0.95, using: &rng),
                    by: Double.random(in: 0.3...0.85, using: &rng),
                    wander: Double.random(in: 0.02...0.07, using: &rng),
                    speed: Double.random(in: 0.2...0.6, using: &rng),
                    phase: Double.random(in: 0...(.pi * 2), using: &rng),
                    brightness: Double.random(in: 0.4...1.0, using: &rng))
        }
        ready = true
    }

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let s = sin(t * 0.012) * 0.02
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.02 + s, green: 0.03, blue: 0.12),
                Color(red: 0.04, green: 0.05 + s, blue: 0.18),
                Color(red: 0.05, green: 0.06, blue: 0.14),
                Color(red: 0.04, green: 0.05, blue: 0.08),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        var rng = SplitMix64(seed: 42)
        for _ in 0..<150 {
            let x = nextDouble(&rng) * size.width
            let y = nextDouble(&rng) * size.height * 0.5
            let sz = nextDouble(&rng) * 1.6 + 0.3
            let b = nextDouble(&rng) * 0.5 + 0.2
            let rate = nextDouble(&rng) + 0.3
            let off = nextDouble(&rng) * .pi * 2
            let tw = sin(t * rate + off) * 0.2 + 0.8
            let r = CGRect(x: x - sz / 2, y: y - sz / 2, width: sz, height: sz)
            ctx.fill(Ellipse().path(in: r), with: .color(.white.opacity(b * tw)))
        }
    }

    private func auroraY(nx: Double, h: Double, t: Double, off: Double) -> Double {
        h * 0.14 + sin(nx * .pi * 3 + t * 0.12 + off) * h * 0.07
            + sin(nx * .pi * 5 + t * 0.08 + off * 2) * h * 0.035
    }

    private func drawAurora(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let cols: [(Double, Double, Double)] = [
            (0.2, 1.4, 0.6), (0.3, 0.8, 1.5), (0.6, 0.3, 1.4),
            (0.15, 1.6, 0.7), (0.4, 1.2, 0.9),
        ]
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 55))
            l.opacity = 0.45
            for (i, c) in cols.enumerated() {
                let off = Double(i) * 0.7
                var p = Path()
                p.move(to: CGPoint(x: 0, y: auroraY(nx: 0, h: h, t: t, off: off)))
                for xi in stride(from: 4, through: Int(w), by: 4) {
                    let nx = Double(xi) / w
                    p.addLine(to: CGPoint(x: Double(xi), y: auroraY(nx: nx, h: h, t: t, off: off)))
                }
                for xi in stride(from: Int(w), through: 0, by: -4) {
                    let nx = Double(xi) / w
                    p.addLine(to: CGPoint(x: Double(xi), y: auroraY(nx: nx, h: h, t: t, off: off + 0.5) + h * 0.1))
                }
                p.closeSubpath()
                l.fill(p, with: .color(Color(red: c.0, green: c.1, blue: c.2)))
            }
        }
    }

    private func drawMountains(ctx: inout GraphicsContext, size: CGSize) {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height * 0.55))
        var rng = SplitMix64(seed: 111)
        for x in stride(from: 0.0, through: size.width, by: 8) {
            p.addLine(to: CGPoint(x: x, y: size.height * 0.55 - nextDouble(&rng) * size.height * 0.14))
        }
        p.addLine(to: CGPoint(x: size.width, y: size.height * 0.55))
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.addLine(to: CGPoint(x: 0, y: size.height))
        p.closeSubpath()
        ctx.fill(p, with: .color(Color(red: 0.03, green: 0.04, blue: 0.06)))
    }

    private func drawRuinsGround(ctx: inout GraphicsContext, size: CGSize, groundY: Double) {
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.05, green: 0.06, blue: 0.07),
                Color(red: 0.03, green: 0.04, blue: 0.05),
            ]), startPoint: CGPoint(x: 0, y: groundY), endPoint: CGPoint(x: 0, y: size.height)))
    }

    private func drawRuins(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let gy = size.height * 0.72
        let stone = Color(red: 0.13, green: 0.12, blue: 0.15)
        let base = Color(red: 0.09, green: 0.09, blue: 0.11)

        drawRuinsGround(ctx: &ctx, size: size, groundY: gy)

        let cols: [(x: Double, w: Double, h: Double, ok: Bool)] = [
            (0.10, 28, 200, true), (0.22, 24, 170, false), (0.35, 30, 220, true),
            (0.50, 26, 185, true), (0.65, 28, 210, false), (0.78, 24, 175, true),
            (0.90, 26, 195, false),
        ]

        for c in cols {
            let cx = c.x * size.width
            let ch = c.ok ? c.h : c.h * 0.55
            let top = gy - ch
            ctx.fill(Rectangle().path(in: CGRect(x: cx - c.w / 2, y: top, width: c.w, height: ch)),
                with: .linearGradient(Gradient(colors: [stone, base]),
                    startPoint: CGPoint(x: cx - c.w / 2, y: top),
                    endPoint: CGPoint(x: cx + c.w / 2, y: top)))
            if c.ok {
                let cw = c.w + 10
                ctx.fill(Rectangle().path(in: CGRect(x: cx - cw / 2, y: top - 10, width: cw, height: 10)),
                    with: .color(stone))
                for f in 0..<3 {
                    let fx = cx - c.w * 0.3 + Double(f) * c.w * 0.3
                    var fl = Path()
                    fl.move(to: CGPoint(x: fx, y: top))
                    fl.addLine(to: CGPoint(x: fx, y: gy))
                    ctx.stroke(fl, with: .color(.black.opacity(0.08)), lineWidth: 1)
                }
            }
            ctx.fill(Rectangle().path(in: CGRect(x: cx - (c.w + 6) / 2, y: gy - 6, width: c.w + 6, height: 6)),
                with: .color(base))
        }

        // Lintels
        for (a, b) in [(0, 2), (3, 5)] as [(Int, Int)] {
            if cols[a].ok && cols[b].ok {
                let lx = cols[a].x * size.width - 10
                let rx = cols[b].x * size.width + 10
                let ly = gy - max(cols[a].h, cols[b].h) - 14
                ctx.fill(Rectangle().path(in: CGRect(x: lx, y: ly, width: rx - lx, height: 14)),
                    with: .color(stone))
            }
        }

        // Scattered stones
        var srng = SplitMix64(seed: 777)
        for _ in 0..<12 {
            let sx = nextDouble(&srng) * size.width
            let sy = gy + nextDouble(&srng) * 18 + 5
            let sw = nextDouble(&srng) * 10 + 4
            let sh = nextDouble(&srng) * 5 + 3
            ctx.fill(Ellipse().path(in: CGRect(x: sx, y: sy, width: sw, height: sh)),
                with: .color(base.opacity(0.5)))
        }
    }

    private func drawMist(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            l.opacity = 0.18
            for i in 0..<6 {
                let off = Double(i) * size.width * 0.2
                let x = fmod(off - t * 6 + size.width * 2, size.width + 300) - 150
                let y = size.height * 0.68 + sin(t * 0.15 + Double(i)) * 15
                let w = 250.0 + sin(t * 0.1 + Double(i) * 2) * 45
                l.fill(Ellipse().path(in: CGRect(x: x, y: y, width: w, height: 45)),
                    with: .color(.white))
            }
        }
    }

    private func drawFireflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Single shared glow layer for all 50 fireflies (was 50 separate layers!)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 10))
            for ff in fireflies {
                let x = (ff.bx + sin(t * ff.speed + ff.phase) * ff.wander) * size.width
                let y = (ff.by + cos(t * ff.speed * 0.7 + ff.phase) * ff.wander * 0.5) * size.height
                let pulse = sin(t * 1.8 + ff.phase) * 0.5 + 0.5
                let alpha = ff.brightness * pulse
                let color = Color(red: 1.4, green: 1.35, blue: 0.55)
                l.fill(Ellipse().path(in: CGRect(x: x - 10, y: y - 10, width: 20, height: 20)),
                    with: .color(color.opacity(alpha * 0.35)))
            }
        }
        // Hard cores (no layer needed)
        for ff in fireflies {
            let x = (ff.bx + sin(t * ff.speed + ff.phase) * ff.wander) * size.width
            let y = (ff.by + cos(t * ff.speed * 0.7 + ff.phase) * ff.wander * 0.5) * size.height
            let pulse = sin(t * 1.8 + ff.phase) * 0.5 + 0.5
            let alpha = ff.brightness * pulse
            let color = Color(red: 1.4, green: 1.35, blue: 0.55)
            ctx.fill(Ellipse().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                with: .color(color.opacity(alpha * 0.9)))
        }
    }

    private func drawBursts(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let activeBursts = bursts.filter { t - $0.birth < 7.0 }
        guard !activeBursts.isEmpty else { return }

        for b in activeBursts {
            let age = t - b.birth
            let p = age / 7.0

            // Warm aurora wash bloom — golden light that illuminates nearby area
            let washFade = age < 0.4 ? age / 0.4 : max(0, 1.0 - (age - 0.4) / 3.0)
            if washFade > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 40 + p * 50))
                    let r = 40 + p * 120
                    l.fill(Ellipse().path(in: CGRect(x: b.x - r, y: b.y - r * 0.7,
                                                     width: r * 2, height: r * 1.4)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.5, green: 1.2, blue: 0.5).opacity(0.20 * washFade),
                                Color(red: 1.2, green: 0.9, blue: 0.3).opacity(0.08 * washFade),
                                .clear
                            ]),
                            center: CGPoint(x: b.x, y: b.y),
                            startRadius: 0, endRadius: r))
                }
            }

            // Drifting firefly motes — slow, twinkling, long-lived
            let seed = UInt64(b.birth * 1000) & 0xFFFFFF
            var rng = SplitMix64(seed: seed)

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 5))
                for _ in 0..<22 {
                    let angle = nextDouble(&rng) * .pi * 2
                    let drift = nextDouble(&rng) * 0.6 + 0.3
                    let riseRate = nextDouble(&rng) * 15 + 8
                    let wobblePhase = nextDouble(&rng) * .pi * 2
                    let wobbleAmp = nextDouble(&rng) * 15 + 8
                    let sz = nextDouble(&rng) * 2.5 + 2.0
                    let lifespan = nextDouble(&rng) * 3.0 + 3.5
                    guard age < lifespan else { continue }
                    let mp = age / lifespan
                    let moteFade = mp < 0.15 ? mp / 0.15 : max(0, 1.0 - (mp - 0.15) / 0.85)
                    let dist = mp * drift * 100
                    let mx = b.x + cos(angle) * dist + sin(age * 0.8 + wobblePhase) * wobbleAmp
                    let my = b.y + sin(angle) * dist * 0.5 - age * riseRate
                    // Firefly twinkle
                    let twinkle = sin(age * (3.0 + nextDouble(&rng) * 2.0) + wobblePhase)
                    let brightness = twinkle > 0.2 ? twinkle : 0.0
                    let s = sz * moteFade * max(0.3, brightness)
                    l.fill(Ellipse().path(in: CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)),
                        with: .color(Color(red: 1.4, green: 1.3, blue: 0.5).opacity(moteFade * 0.55 * brightness)))
                }
            }

            // Gentle expanding aureole ring
            let ringFade = max(0, 1.0 - p)
            if ringFade > 0 {
                let r = p * 90
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 8))
                    l.stroke(Ellipse().path(in: CGRect(x: b.x - r, y: b.y - r * 0.6,
                                                       width: r * 2, height: r * 1.2)),
                        with: .color(Color(red: 1.3, green: 1.1, blue: 0.5).opacity(ringFade * 0.15)),
                        lineWidth: 1.5)
                }
            }
        }
    }

    private func drawGoldenDust(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 666)
        for _ in 0..<25 {
            let bx = nextDouble(&rng)
            let by = nextDouble(&rng) * 0.7 + 0.2
            let sp = nextDouble(&rng) * 0.008 + 0.003
            let ph = nextDouble(&rng) * .pi * 2
            let x = fmod(bx + t * sp + sin(t * 0.3 + ph) * 0.02, 1.0) * size.width
            let y = by * size.height + cos(t * 0.4 + ph) * 15
            let pulse = sin(t * 0.7 + ph) * 0.4 + 0.6
            let s = 2.0
            ctx.fill(Ellipse().path(in: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)),
                with: .color(Color(red: 1.2, green: 1.05, blue: 0.5).opacity(pulse * 0.35)))
        }
    }
}
