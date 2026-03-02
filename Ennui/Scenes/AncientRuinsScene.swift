import SwiftUI

struct AncientRuinsScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

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
            if bursts.count > 5 { bursts.removeFirst() }
        }
    }

    private func setup() {
        fireflies = (0..<50).map { _ in
            Firefly(bx: .random(in: 0.05...0.95), by: .random(in: 0.3...0.85),
                    wander: .random(in: 0.02...0.07), speed: .random(in: 0.2...0.6),
                    phase: .random(in: 0...(.pi * 2)), brightness: .random(in: 0.4...1.0))
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
            (0.15, 0.8, 0.45), (0.2, 0.55, 0.85), (0.45, 0.25, 0.8),
            (0.1, 0.9, 0.55), (0.3, 0.7, 0.6),
        ]
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 55))
            l.opacity = 0.35
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
        for ff in fireflies {
            let x = (ff.bx + sin(t * ff.speed + ff.phase) * ff.wander) * size.width
            let y = (ff.by + cos(t * ff.speed * 0.7 + ff.phase) * ff.wander * 0.5) * size.height
            let pulse = sin(t * 1.8 + ff.phase) * 0.5 + 0.5
            let alpha = ff.brightness * pulse
            let color = Color(red: 0.95, green: 0.92, blue: 0.45)

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 8))
                l.fill(Ellipse().path(in: CGRect(x: x - 8, y: y - 8, width: 16, height: 16)),
                    with: .color(color.opacity(alpha * 0.3)))
            }
            ctx.fill(Ellipse().path(in: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)),
                with: .color(color.opacity(alpha * 0.9)))
        }
    }

    private func drawBursts(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for b in bursts {
            let age = t - b.birth
            guard age < 3 else { continue }
            let p = age / 3.0
            let fade = (1 - p) * (1 - p)
            for i in 0..<16 {
                let angle = Double(i) / 16 * .pi * 2 + age * 1.2
                let dist = p * 70 + sin(age * 3 + Double(i)) * 10
                let px = b.x + cos(angle) * dist
                let py = b.y + sin(angle) * dist - p * 20
                let s = 3.0 * fade
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 4))
                    l.fill(Ellipse().path(in: CGRect(x: px - s, y: py - s, width: s * 2, height: s * 2)),
                        with: .color(Color(red: 0.95, green: 0.9, blue: 0.4).opacity(fade * 0.5)))
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
                with: .color(Color(red: 0.9, green: 0.8, blue: 0.4).opacity(pulse * 0.3)))
        }
    }
}
