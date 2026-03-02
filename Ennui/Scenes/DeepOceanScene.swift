import SwiftUI

struct DeepOceanScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

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
    }

    @State private var particles: [Particle] = []
    @State private var jellies: [Jelly] = []
    @State private var flashes: [BioFlash] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBG(ctx: &ctx, size: size, t: t)
                drawRays(ctx: &ctx, size: size, t: t)
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
            flashes.append(BioFlash(x: loc.x, y: loc.y, birth: Date().timeIntervalSince(startDate)))
            if flashes.count > 6 { flashes.removeFirst() }
        }
    }

    private func setup() {
        particles = (0..<160).map { i in
            Particle(x: .random(in: 0...1), baseY: .random(in: 0...1),
                     size: .random(in: 0.8...5), speed: .random(in: 0.005...0.025),
                     brightness: .random(in: 0.2...1.0), hue: .random(in: 0.45...0.7),
                     phase: .random(in: 0...(.pi * 2)),
                     layer: i < 50 ? 0 : (i < 110 ? 1 : 2))
        }
        jellies = (0..<8).map { _ in
            Jelly(x: .random(in: 0.08...0.92), baseY: .random(in: 0.15...0.75),
                  size: .random(in: 25...85), speed: .random(in: 0.002...0.008),
                  phase: .random(in: 0...(.pi * 2)), hue: .random(in: 0.5...0.9),
                  tents: Int.random(in: 5...9))
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

    private func drawParticles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for p in particles {
            let la = [0.3, 0.6, 1.0][p.layer]
            let ls = [0.6, 1.0, 1.5][p.layer]
            let x = (p.x + sin(t * 0.2 + p.phase) * 0.025) * size.width
            let y = fmod(p.baseY - t * p.speed * ls + 10, 1.0) * size.height
            let pulse = sin(t + p.phase) * 0.3 + 0.7
            let alpha = p.brightness * pulse * la
            let c = Color(hue: p.hue, saturation: 0.7, brightness: 1.3)
            let s = p.size * (0.8 + pulse * 0.3)

            ctx.fill(Ellipse().path(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                with: .color(c.opacity(alpha * 0.6)))

            if s > 3 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: s))
                    l.fill(Ellipse().path(in: CGRect(x: x - s * 2, y: y - s * 2, width: s * 4, height: s * 4)),
                        with: .color(c.opacity(alpha * 0.10)))
                }
            }
        }
    }

    private func drawJellyBell(ctx: inout GraphicsContext, x: Double, y: Double, bw: Double, bh: Double, color: Color, pulse: Double) {
        ctx.drawLayer { bl in
            bl.addFilter(.blur(radius: 2))
            bl.fill(Ellipse().path(in: CGRect(x: x - bw / 2, y: y - bh / 2, width: bw, height: bh)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.6), color.opacity(0.2), color.opacity(0.05)]),
                    center: CGPoint(x: x, y: y - bh * 0.1), startRadius: 0, endRadius: bw * 0.5))
        }
        ctx.fill(Ellipse().path(in: CGRect(x: x - bw * 0.25, y: y - bh * 0.2, width: bw * 0.5, height: bh * 0.4)),
            with: .color(Color(red: 0.7, green: 1.4, blue: 1.6).opacity(0.12 * pulse)))
    }

    private func drawJellies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for jf in jellies {
            let x = (jf.x + sin(t * jf.speed * 5 + jf.phase) * 0.06) * size.width
            let y = (jf.baseY + sin(t * jf.speed * 3 + jf.phase) * 0.04) * size.height
            let s = jf.size
            let c = Color(hue: jf.hue, saturation: 0.5, brightness: 0.85)
            let pulse = sin(t * 0.6 + jf.phase) * 0.5 + 0.5
            let contract = sin(t * 0.8 + jf.phase) * 0.1 + 0.9

            ctx.drawLayer { l in
                l.opacity = 0.25 + pulse * 0.25

                // Outer glow
                ctx.drawLayer { g in
                    g.addFilter(.blur(radius: s * 0.4))
                    g.fill(Ellipse().path(in: CGRect(x: x - s * 0.8, y: y - s * 0.5, width: s * 1.6, height: s)),
                        with: .color(c.opacity(0.12 * pulse)))
                }

                let bw = s * contract
                let bh = s * 0.55 * (1.1 - contract * 0.1)
                drawJellyBell(ctx: &ctx, x: x, y: y, bw: bw, bh: bh, color: c, pulse: pulse)

                // Tentacles
                for ti in 0..<jf.tents {
                    let f = Double(ti) / Double(jf.tents - 1)
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
            guard age < 3.5 else { continue }
            let p = age / 3.5
            let r = p * 100
            let fade = (1 - p) * (1 - p)

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 15 + p * 30))
                l.fill(Ellipse().path(in: CGRect(x: fl.x - r, y: fl.y - r, width: r * 2, height: r * 2)),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.3, green: 1.4, blue: 1.6).opacity(0.35 * fade),
                            Color(red: 0.2, green: 1.0, blue: 1.2).opacity(0.12 * fade),
                            .clear,
                        ]),
                        center: CGPoint(x: fl.x, y: fl.y), startRadius: 0, endRadius: r))
            }

            for i in 0..<10 {
                let angle = Double(i) / 10 * .pi * 2 + age * 0.3
                let dist = p * 60 + sin(age * 2 + Double(i)) * 10
                let mx = fl.x + cos(angle) * dist
                let my = fl.y + sin(angle) * dist
                let s = 2.0 * fade
                ctx.fill(Ellipse().path(in: CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)),
                    with: .color(Color(red: 0.2, green: 1.3, blue: 1.5).opacity(fade * 0.45)))
            }
        }
    }
}
