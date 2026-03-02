import SwiftUI

struct ConservatoryScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct Raindrop {
        let x, speed, length, phase: Double
    }
    struct Plant {
        let x, y, height, sway, hue, phase: Double
    }
    struct Droplet: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    @State private var rain: [Raindrop] = []
    @State private var plants: [Plant] = []
    @State private var droplets: [Droplet] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBG(ctx: &ctx, size: size, t: t)
                drawGlass(ctx: &ctx, size: size, t: t)
                drawPlants(ctx: &ctx, size: size, t: t)
                drawRain(ctx: &ctx, size: size, t: t)
                drawMist(ctx: &ctx, size: size, t: t)
                drawDroplets(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            droplets.append(Droplet(x: loc.x, y: loc.y, birth: Date().timeIntervalSince(startDate)))
            if droplets.count > 8 { droplets.removeFirst() }
        }
    }

    private func setup() {
        rain = (0..<80).map { _ in
            Raindrop(x: .random(in: 0...1), speed: .random(in: 0.3...0.8),
                     length: .random(in: 8...25), phase: .random(in: 0...1))
        }
        plants = (0..<20).map { _ in
            Plant(x: .random(in: 0.05...0.95), y: .random(in: 0.55...0.85),
                  height: .random(in: 0.08...0.25), sway: .random(in: 0.3...0.7),
                  hue: .random(in: 0.25...0.42), phase: .random(in: 0...(.pi * 2)))
        }
        ready = true
    }

    private func drawBG(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = sin(t * 0.01) * 0.02
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.04 + w, green: 0.06, blue: 0.05),
                Color(red: 0.06, green: 0.09 + w, blue: 0.07),
                Color(red: 0.05, green: 0.08, blue: 0.06),
                Color(red: 0.03, green: 0.05, blue: 0.04),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    private func drawGlassArch(ctx: inout GraphicsContext, size: CGSize) {
        let cx = size.width / 2
        // Main arch
        var arch = Path()
        arch.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.5))
        arch.addQuadCurve(
            to: CGPoint(x: size.width * 0.95, y: size.height * 0.5),
            control: CGPoint(x: cx, y: -size.height * 0.1))
        ctx.stroke(arch, with: .color(.white), lineWidth: 2)

        // Vertical panes
        for i in 1..<8 {
            let px = size.width * Double(i) / 8.0
            let topY = size.height * 0.5 - sin(Double(i) / 8.0 * .pi) * size.height * 0.35
            var pane = Path()
            pane.move(to: CGPoint(x: px, y: topY))
            pane.addLine(to: CGPoint(x: px, y: size.height * 0.5))
            ctx.stroke(pane, with: .color(.white), lineWidth: 1)
        }

        // Horizontal bands
        for j in 1..<4 {
            let frac = Double(j) / 4.0
            var hp = Path()
            hp.move(to: CGPoint(x: size.width * 0.05, y: size.height * 0.5))
            hp.addQuadCurve(
                to: CGPoint(x: size.width * 0.95, y: size.height * 0.5),
                control: CGPoint(x: cx, y: size.height * 0.5 - frac * size.height * 0.35))
            ctx.stroke(hp, with: .color(.white), lineWidth: 0.5)
        }
    }

    private func drawGlass(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let cx = size.width / 2

        ctx.drawLayer { l in
            l.opacity = 0.08
            drawGlassArch(ctx: &ctx, size: size)
        }

        // Condensation glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            l.opacity = 0.06
            let gr = CGRect(x: cx - size.width * 0.3, y: 0, width: size.width * 0.6, height: size.height * 0.4)
            l.fill(Ellipse().path(in: gr), with: .color(Color(red: 0.4, green: 0.6, blue: 0.5)))
        }
    }

    private func drawPlantLeaves(ctx: inout GraphicsContext, bx: Double, by: Double, top: Double, sway: Double, hue: Double, height: Double, t: Double, phase: Double) {
        let leafCount = Int(height * 12)
        for li in 0..<leafCount {
            let frac = Double(li) / Double(leafCount)
            let lx = bx + sway * frac
            let ly = by - (by - top) * frac
            let leafSway = sin(t * 0.5 + phase + Double(li) * 0.5) * 6
            let side: Double = li % 2 == 0 ? 1 : -1
            let leafLen = (12.0 + height * 200) * (1.0 - frac * 0.5)

            var leaf = Path()
            leaf.move(to: CGPoint(x: lx, y: ly))
            leaf.addQuadCurve(
                to: CGPoint(x: lx + side * leafLen + leafSway, y: ly - 5),
                control: CGPoint(x: lx + side * leafLen * 0.6 + leafSway * 0.5, y: ly - 8))
            let leafHue = hue + frac * 0.05
            ctx.stroke(leaf, with: .color(
                Color(hue: leafHue, saturation: 0.5, brightness: 0.35).opacity(0.45)),
                lineWidth: 1.5)
        }
    }

    private func drawPlants(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Ground
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: size.height * 0.8, width: size.width, height: size.height * 0.2)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.04, green: 0.08, blue: 0.04),
                Color(red: 0.02, green: 0.05, blue: 0.03),
            ]), startPoint: CGPoint(x: 0, y: size.height * 0.8),
                endPoint: CGPoint(x: 0, y: size.height)))

        for p in plants {
            let plantSway = sin(t * p.sway + p.phase) * 0.015 * size.width
            let bx = p.x * size.width
            let by = p.y * size.height
            let top = by - p.height * size.height

            // Stem
            var stem = Path()
            stem.move(to: CGPoint(x: bx, y: by))
            stem.addQuadCurve(
                to: CGPoint(x: bx + plantSway, y: top),
                control: CGPoint(x: bx + plantSway * 0.4, y: by - (by - top) * 0.6))
            ctx.stroke(stem, with: .color(
                Color(hue: 0.35, saturation: 0.6, brightness: 0.25).opacity(0.6)),
                lineWidth: 2)

            // Leaves
            drawPlantLeaves(ctx: &ctx, bx: bx, by: by, top: top, sway: plantSway,
                          hue: p.hue, height: p.height, t: t, phase: p.phase)

            // Glow at tip
            let breathe = sin(t * 0.2 + p.phase) * 0.1 + 0.9
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 8))
                let gr = CGRect(x: bx + plantSway - 8, y: top - 8, width: 16, height: 16)
                l.fill(Ellipse().path(in: gr), with: .color(
                    Color(hue: p.hue, saturation: 0.4, brightness: 0.6).opacity(0.12 * breathe)))
            }
        }
    }

    private func drawRain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let roofY = size.height * 0.5
        for r in rain {
            let x = r.x * size.width + sin(t * 0.3 + r.phase * 10) * 3
            let y = fmod(r.phase + t * r.speed, 1.0) * roofY
            let alpha = 0.15 + r.speed * 0.15

            var drop = Path()
            drop.move(to: CGPoint(x: x, y: y))
            drop.addLine(to: CGPoint(x: x + 1, y: y + r.length))
            ctx.stroke(drop, with: .color(
                Color(red: 0.6, green: 0.7, blue: 0.8).opacity(alpha)),
                lineWidth: 0.8)
        }
    }

    private func drawMist(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 40))
            l.opacity = 0.10
            for i in 0..<4 {
                let x = fmod(Double(i) * size.width * 0.3 - t * 4 + size.width * 2, size.width + 200) - 100
                let y = size.height * 0.6 + sin(t * 0.1 + Double(i)) * 20
                l.fill(Ellipse().path(in: CGRect(x: x, y: y, width: 200, height: 35)),
                    with: .color(Color(red: 0.5, green: 0.7, blue: 0.5)))
            }
        }
    }

    private func drawDroplets(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for d in droplets {
            let age = t - d.birth
            guard age < 2.5 else { continue }
            let p = age / 2.5
            let fade = 1 - p

            // Water splash rings
            for ring in 0..<4 {
                let r = p * 50 * (0.4 + Double(ring) * 0.25)
                let rf = fade * (1 - Double(ring) * 0.2)
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 3))
                    l.stroke(
                        Ellipse().path(in: CGRect(x: d.x - r, y: d.y - r * 0.4, width: r * 2, height: r * 0.8)),
                        with: .color(Color(red: 0.5, green: 0.7, blue: 0.6).opacity(rf * 0.2)),
                        lineWidth: 1)
                }
            }

            // Tiny droplet splashes
            for i in 0..<8 {
                let angle = Double(i) / 8 * .pi * 2 + age * 0.8
                let dist = p * 35
                let sx = d.x + cos(angle) * dist
                let sy = d.y + sin(angle) * dist * 0.5 - p * 15
                let s = 1.5 * fade
                ctx.fill(Ellipse().path(in: CGRect(x: sx - s, y: sy - s, width: s * 2, height: s * 2)),
                    with: .color(Color(red: 0.6, green: 0.8, blue: 0.7).opacity(fade * 0.3)))
            }
        }
    }
}
