import SwiftUI

struct DesertStarscapeScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    struct Star {
        let x, y, brightness, size, rate, offset, warmth: Double
    }
    struct SandRipple: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    @State private var stars: [Star] = []
    @State private var ripples: [SandRipple] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawMilkyWay(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawShootingStars(ctx: &ctx, size: size, t: t)
                drawShimmer(ctx: &ctx, size: size, t: t)
                drawDunes(ctx: &ctx, size: size, t: t)
                drawSand(ctx: &ctx, size: size, t: t)
                drawRipples(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            ripples.append(SandRipple(x: loc.x, y: loc.y, birth: Date().timeIntervalSince(startDate)))
            if ripples.count > 5 { ripples.removeFirst() }
        }
    }

    private func setup() {
        stars = (0..<380).map { _ in
            Star(x: .random(in: 0...1), y: .random(in: 0...0.68),
                 brightness: .random(in: 0.05...1.0), size: .random(in: 0.2...3.0),
                 rate: .random(in: 0.3...1.6), offset: .random(in: 0...(.pi * 2)),
                 warmth: .random(in: 0...1))
        }
        ready = true
    }

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = sin(t * 0.01) * 0.02
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.02, green: 0.02, blue: 0.09),
                Color(red: 0.04 + w, green: 0.03, blue: 0.14),
                Color(red: 0.08 + w, green: 0.05, blue: 0.16),
                Color(red: 0.15 + w, green: 0.08, blue: 0.14),
                Color(red: 0.22 + w, green: 0.12, blue: 0.10),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.72)))
    }

    private func drawMilkyWay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            l.opacity = 0.15
            var band = Path()
            band.move(to: CGPoint(x: -20, y: size.height * 0.38))
            band.addCurve(
                to: CGPoint(x: size.width + 20, y: size.height * 0.12),
                control1: CGPoint(x: size.width * 0.3, y: size.height * 0.08),
                control2: CGPoint(x: size.width * 0.7, y: size.height * 0.05))
            band.addCurve(
                to: CGPoint(x: -20, y: size.height * 0.50),
                control1: CGPoint(x: size.width * 0.7, y: size.height * 0.18),
                control2: CGPoint(x: size.width * 0.3, y: size.height * 0.22))
            band.closeSubpath()
            l.fill(band, with: .color(Color(red: 0.7, green: 0.55, blue: 1.1)))
        }
        // Dust clouds
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 30))
            l.opacity = 0.08
            var rng = SplitMix64(seed: 999)
            for _ in 0..<12 {
                let cx = nextDouble(&rng) * size.width
                let cy = size.height * (0.08 + nextDouble(&rng) * 0.3)
                let r = nextDouble(&rng) * 60 + 30
                let hue = 0.6 + nextDouble(&rng) * 0.2
                l.fill(Ellipse().path(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(Color(hue: hue, saturation: 0.5, brightness: 1.1)))
            }
        }
    }

    private func drawStarFlare(ctx: inout GraphicsContext, x: Double, y: Double, flareLen: Double, alpha: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 2))
            l.opacity = alpha * 0.2
            var h = Path()
            h.move(to: CGPoint(x: x - flareLen, y: y))
            h.addLine(to: CGPoint(x: x + flareLen, y: y))
            l.stroke(h, with: .color(Color(red: 1.5, green: 1.4, blue: 1.7)), lineWidth: 0.5)
            var v = Path()
            v.move(to: CGPoint(x: x, y: y - flareLen))
            v.addLine(to: CGPoint(x: x, y: y + flareLen))
            l.stroke(v, with: .color(Color(red: 1.5, green: 1.4, blue: 1.7)), lineWidth: 0.5)
        }
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Draw all star cores
        for s in stars {
            let tw = sin(t * s.rate + s.offset) * 0.25 + 0.75
            let alpha = s.brightness * tw
            let x = s.x * size.width
            let y = s.y * size.height
            let w = s.warmth
            let brightBoost = s.brightness > 0.85 ? 1.3 : 1.0
            let c = Color(red: (0.9 + w * 0.1) * brightBoost, green: (0.85 + (1 - w) * 0.15) * brightBoost, blue: (0.75 + (1 - w) * 0.25) * brightBoost)

            ctx.fill(Ellipse().path(in: CGRect(x: x - s.size / 2, y: y - s.size / 2, width: s.size, height: s.size)),
                with: .color(c.opacity(alpha)))
        }

        // Single shared flare layer for all bright stars (was ~20 separate layers)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 2))
            for s in stars {
                guard s.brightness > 0.85 && s.size > 2 else { continue }
                let tw = sin(t * s.rate + s.offset) * 0.25 + 0.75
                let alpha = s.brightness * tw
                let x = s.x * size.width
                let y = s.y * size.height
                let flareLen = s.size * 3 * tw

                l.opacity = alpha * 0.2
                var h = Path()
                h.move(to: CGPoint(x: x - flareLen, y: y))
                h.addLine(to: CGPoint(x: x + flareLen, y: y))
                l.stroke(h, with: .color(Color(red: 1.5, green: 1.4, blue: 1.7)), lineWidth: 0.5)
                var v = Path()
                v.move(to: CGPoint(x: x, y: y - flareLen))
                v.addLine(to: CGPoint(x: x, y: y + flareLen))
                l.stroke(v, with: .color(Color(red: 1.5, green: 1.4, blue: 1.7)), lineWidth: 0.5)
            }
        }
    }

    private func drawShootingStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for i in 0..<3 {
            let cycle = 10.0 + Double(i) * 8
            let off = Double(i) * 3.5
            let phase = fmod(t + off, cycle)
            guard phase < 1.5 else { continue }
            let p = phase / 1.5
            let eased = p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2
            let fadeIn = min(p / 0.1, 1.0)
            let fadeOut = max(1 - (p - 0.6) / 0.4, 0.0)
            let fade = min(fadeIn, fadeOut)

            let seed = floor((t + off) / cycle) + Double(i) * 100
            let sx = fmod(abs(sin(seed * 3.7)) * 0.6 + 0.2, 1.0)
            let sy = fmod(abs(cos(seed * 5.3)) * 0.2 + 0.02, 0.35)
            let angle = 0.35 + sin(seed * 1.3) * 0.15

            let hx = (sx + eased * 0.35 * cos(angle)) * size.width
            let hy = (sy + eased * 0.2 * sin(angle)) * size.height
            let tl = 70.0 * fade

            var path = Path()
            path.move(to: CGPoint(x: hx, y: hy))
            path.addLine(to: CGPoint(x: hx - cos(angle) * tl, y: hy - sin(angle) * tl * 0.6))
            let hdrMeteor = Color(red: 1.6, green: 1.5, blue: 1.7)
            ctx.stroke(path, with: .linearGradient(
                Gradient(colors: [hdrMeteor.opacity(0.7 * fade), hdrMeteor.opacity(0)]),
                startPoint: CGPoint(x: hx, y: hy),
                endPoint: CGPoint(x: hx - cos(angle) * tl, y: hy - sin(angle) * tl * 0.6)),
                lineWidth: 1.5)
            ctx.fill(Ellipse().path(in: CGRect(x: hx - 2, y: hy - 2, width: 4, height: 4)),
                with: .color(hdrMeteor.opacity(0.9 * fade)))
        }
    }

    private func drawShimmer(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 15))
            l.opacity = 0.06
            for i in 0..<6 {
                let x = size.width * Double(i) / 5.0
                let y = size.height * 0.68 + sin(t * 0.8 + Double(i) * 1.5) * 8
                l.fill(Ellipse().path(in: CGRect(x: x - 50, y: y - 5, width: 100, height: 10)),
                    with: .color(Color(red: 1.1, green: 0.8, blue: 0.4)))
            }
        }
    }

    private func drawDunes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wind = sin(t * 0.08) * 0.005
        let layers: [(y: Double, c: Color)] = [
            (0.72, Color(red: 0.16, green: 0.10, blue: 0.07)),
            (0.78, Color(red: 0.20, green: 0.13, blue: 0.08)),
            (0.85, Color(red: 0.24, green: 0.16, blue: 0.10)),
        ]
        for (idx, layer) in layers.enumerated() {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: size.height))
            let d = Double(idx)
            for x in stride(from: 0.0, through: size.width, by: 2) {
                let nx = x / size.width
                let y = size.height * layer.y
                    + sin(nx * .pi * (1.8 + d * 0.4) + d * 1.2 + wind * 5) * size.height * (0.03 - d * 0.005)
                    + sin(nx * .pi * (3.5 + d) + d * 2.5) * size.height * 0.012
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.closeSubpath()
            ctx.fill(p, with: .color(layer.c))
        }
    }

    private func drawSand(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 333)
        for _ in 0..<45 {
            let bx = nextDouble(&rng)
            let by = 0.7 + nextDouble(&rng) * 0.25
            let sp = nextDouble(&rng) * 0.015 + 0.005
            let a = nextDouble(&rng) * 0.25 + 0.1
            let s = nextDouble(&rng) * 1.2 + 0.5
            let x = fmod(bx + t * sp, 1.0) * size.width
            let y = by * size.height + sin(t * 1.5 + bx * 10) * 3
            ctx.fill(Ellipse().path(in: CGRect(x: x, y: y, width: s, height: s)),
                with: .color(Color(red: 0.55, green: 0.40, blue: 0.25).opacity(a)))
        }
    }

    private func drawRipples(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for rp in ripples {
            let age = t - rp.birth
            guard age < 3 else { continue }
            let p = age / 3.0
            let fade = 1 - p
            for ring in 0..<3 {
                let r = p * 60 * (0.5 + Double(ring) * 0.3)
                let f = fade * (1 - Double(ring) * 0.3)
                ctx.stroke(
                    Ellipse().path(in: CGRect(x: rp.x - r, y: rp.y - r * 0.3, width: r * 2, height: r * 0.6)),
                    with: .color(Color(red: 0.6, green: 0.45, blue: 0.3).opacity(f * 0.25)),
                    lineWidth: 1)
            }
        }
    }
}
