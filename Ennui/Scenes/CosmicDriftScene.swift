import SwiftUI

struct CosmicDriftScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct StarData: Identifiable {
        let id: Int
        let x, y, brightness, size, speed, twinkleRate, twinkleOffset: Double
        let layer: Int
        let warmth: Double // 0 = cool blue-white, 1 = warm amber
    }

    struct NebulaData {
        let cx, cy, radius: Double
        let r, g, b: Double
        let driftX, driftY, phase: Double
    }

    struct RippleData: Identifiable {
        let id = UUID()
        let x, y, birthTime: Double
    }

    @State private var stars: [StarData] = []
    @State private var nebulae: [NebulaData] = []
    @State private var ripples: [RippleData] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawNebulae(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawShootingStars(ctx: &ctx, size: size, t: t)
                drawRipples(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapLocation) { _, loc in
            guard let loc = loc else { return }
            let r = RippleData(x: loc.x, y: loc.y, birthTime: Date().timeIntervalSince(startDate))
            ripples.append(r)
            // Keep last 6 ripples
            if ripples.count > 6 { ripples.removeFirst() }
        }
    }

    private func setup() {
        stars = (0..<300).map { i in
            let layer = i < 100 ? 0 : (i < 220 ? 1 : 2)
            let sizeRange: ClosedRange<Double> = layer == 0 ? 0.3...1.0 : (layer == 1 ? 0.8...2.0 : 1.5...3.5)
            return StarData(
                id: i,
                x: .random(in: 0...1),
                y: .random(in: 0...1),
                brightness: .random(in: 0.15...1.0),
                size: .random(in: sizeRange),
                speed: [0.0005, 0.0015, 0.004][layer] * .random(in: 0.7...1.3),
                twinkleRate: .random(in: 0.2...1.2),
                twinkleOffset: .random(in: 0...(.pi * 2)),
                layer: layer,
                warmth: .random(in: 0...1)
            )
        }
        // More nebulae, warmer palette
        nebulae = (0..<14).map { _ in
            NebulaData(
                cx: .random(in: -0.2...1.2),
                cy: .random(in: -0.2...1.2),
                radius: .random(in: 0.12...0.45),
                r: .random(in: 0.15...0.85),
                g: .random(in: 0.08...0.45),
                b: .random(in: 0.15...0.65),
                driftX: .random(in: -0.002...0.002),
                driftY: .random(in: -0.0015...0.0015),
                phase: .random(in: 0...(.pi * 2))
            )
        }
        ready = true
    }

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Slowly cycling warm/cool background
        let warmCycle = sin(t * 0.02) * 0.5 + 0.5
        let r1 = 0.02 + warmCycle * 0.04
        let g1 = 0.008 + warmCycle * 0.01
        let b1 = 0.06 + (1 - warmCycle) * 0.04
        ctx.fill(
            Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: r1, green: g1, blue: b1),
                    Color(red: r1 * 1.5, green: g1 * 1.2, blue: b1 * 0.8),
                    Color(red: r1 * 0.8, green: g1 * 1.5, blue: b1 * 1.2),
                ]),
                startPoint: CGPoint(x: size.width * 0.5 + sin(t * 0.03) * size.width * 0.3, y: 0),
                endPoint: CGPoint(x: size.width * 0.5 + cos(t * 0.02) * size.width * 0.3, y: size.height)
            )
        )
    }

    private func drawNebulae(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for n in nebulae {
            let x = (n.cx + sin(t * n.driftX * 8 + n.phase) * 0.06) * size.width
            let y = (n.cy + cos(t * n.driftY * 8 + n.phase) * 0.06) * size.height
            let baseR = n.radius * max(size.width, size.height)
            // Breathe: radius pulses gently
            let breathe = sin(t * 0.15 + n.phase) * 0.08 + 1.0
            let r = baseR * breathe
            let color = Color(red: n.r, green: n.g, blue: n.b)

            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: r * 0.5))
                layerCtx.opacity = 0.3
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                layerCtx.fill(
                    Ellipse().path(in: rect),
                    with: .radialGradient(
                        Gradient(colors: [color.opacity(0.7), color.opacity(0.2), color.opacity(0)]),
                        center: CGPoint(x: x, y: y),
                        startRadius: 0,
                        endRadius: r
                    )
                )
            }
        }
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for star in stars {
            let twinkle = (sin(t * star.twinkleRate + star.twinkleOffset) + 1.0) * 0.5
            let smoothTwinkle = twinkle * 0.35 + 0.65
            let alpha = star.brightness * smoothTwinkle
            let x = fmod(star.x + t * star.speed + 10, 1.0) * size.width
            let y = star.y * size.height
            let s = star.size * (0.8 + smoothTwinkle * 0.2)

            // Warm/cool star color — HDR bloom for bright stars
            let w = star.warmth
            let brightMul = star.brightness > 0.7 ? 1.35 : 1.0
            let sr = (0.85 + w * 0.15) * brightMul
            let sg = (0.8 + w * 0.1 - (1 - w) * 0.1) * brightMul
            let sb = (1.0 - w * 0.3) * brightMul
            let starColor = Color(red: sr, green: sg, blue: sb)

            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            ctx.fill(Ellipse().path(in: rect), with: .color(starColor.opacity(alpha)))

            if star.brightness > 0.7 && star.layer == 2 {
                let glowS = s * 4
                let glowRect = CGRect(x: x - glowS / 2, y: y - glowS / 2, width: glowS, height: glowS)
                ctx.fill(Ellipse().path(in: glowRect), with: .color(starColor.opacity(alpha * 0.06)))
            }
        }
    }

    private func drawShootingStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Multiple shooting stars at different intervals
        for i in 0..<3 {
            let cycle = 12.0 + Double(i) * 7.0
            let offset = Double(i) * 4.2
            let phase = fmod(t + offset, cycle)
            guard phase < 1.8 else { continue }
            let progress = phase / 1.8

            // Smooth ease-in-out
            let eased = progress < 0.5
                ? 2.0 * progress * progress
                : 1.0 - pow(-2.0 * progress + 2.0, 2.0) / 2.0

            // Fade: smooth in and out
            let fadeIn = min(progress / 0.15, 1.0)
            let fadeOut = max(1.0 - (progress - 0.7) / 0.3, 0.0)
            let fade = min(fadeIn, fadeOut)

            let seed = floor((t + offset) / cycle) + Double(i) * 100
            let startX = fmod(abs(sin(seed * 3.7)) * 0.6 + 0.2, 1.0)
            let startY = fmod(abs(cos(seed * 5.3)) * 0.25 + 0.02, 0.4)
            let angle = 0.3 + sin(seed * 1.3) * 0.2

            let sx = (startX + eased * 0.3 * cos(angle)) * size.width
            let sy = (startY + eased * 0.25 * sin(angle)) * size.height
            let tailLen: Double = 60.0 * fade

            let dx = -cos(angle)
            let dy = -sin(angle)

            var path = Path()
            path.move(to: CGPoint(x: sx, y: sy))
            path.addLine(to: CGPoint(x: sx + dx * tailLen, y: sy + dy * tailLen * 0.8))

            let hdrHead = Color(red: 1.6, green: 1.5, blue: 1.8)

            ctx.stroke(path, with: .linearGradient(
                Gradient(colors: [hdrHead.opacity(0.8 * fade), hdrHead.opacity(0)]),
                startPoint: CGPoint(x: sx, y: sy),
                endPoint: CGPoint(x: sx + dx * tailLen, y: sy + dy * tailLen * 0.8)
            ), lineWidth: 1.5)

            let headRect = CGRect(x: sx - 2, y: sy - 2, width: 4, height: 4)
            ctx.fill(Ellipse().path(in: headRect), with: .color(hdrHead.opacity(0.9 * fade)))
        }
    }

    private func drawRipples(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for ripple in ripples {
            let age = t - ripple.birthTime
            guard age < 4.0 else { continue }
            let progress = age / 4.0
            let radius = progress * 120.0
            let alpha = (1.0 - progress) * 0.25

            let warmColor = Color(red: 1.1, green: 0.6, blue: 1.3)
            let rect = CGRect(x: ripple.x - radius, y: ripple.y - radius,
                             width: radius * 2, height: radius * 2)

            ctx.drawLayer { layerCtx in
                layerCtx.addFilter(.blur(radius: 8 + progress * 20))
                layerCtx.stroke(
                    Ellipse().path(in: rect),
                    with: .color(warmColor.opacity(alpha)),
                    lineWidth: 2.0 - progress * 1.5
                )
            }
        }
    }
}
