import SwiftUI

struct CosmicDriftScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

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

    struct DustMote {
        let x, y, size, brightness, driftSpeed, phase: Double
    }

    @State private var stars: [StarData] = []
    @State private var nebulae: [NebulaData] = []
    @State private var ripples: [RippleData] = []
    @State private var dust: [DustMote] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawDustLane(ctx: &ctx, size: size, t: t)
                drawNebulae(ctx: &ctx, size: size, t: t)
                drawDust(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawShootingStars(ctx: &ctx, size: size, t: t)
                drawRipples(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let r = RippleData(x: loc.x, y: loc.y, birthTime: Date().timeIntervalSince(startDate))
            ripples.append(r)
            if ripples.count > 8 { ripples.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 0xC05A1C)

        stars = (0..<300).map { i in
            let layer = i < 100 ? 0 : (i < 220 ? 1 : 2)
            let sizeRange: ClosedRange<Double> = layer == 0 ? 0.3...1.0 : (layer == 1 ? 0.8...2.0 : 1.5...3.5)
            return StarData(
                id: i,
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                brightness: Double.random(in: 0.15...1.0, using: &rng),
                size: Double.random(in: sizeRange, using: &rng),
                speed: [0.0005, 0.0015, 0.004][layer] * Double.random(in: 0.7...1.3, using: &rng),
                twinkleRate: Double.random(in: 0.2...1.2, using: &rng),
                twinkleOffset: Double.random(in: 0...(.pi * 2), using: &rng),
                layer: layer,
                warmth: Double.random(in: 0...1, using: &rng)
            )
        }

        nebulae = (0..<14).map { _ in
            NebulaData(
                cx: Double.random(in: -0.2...1.2, using: &rng),
                cy: Double.random(in: -0.2...1.2, using: &rng),
                radius: Double.random(in: 0.12...0.45, using: &rng),
                r: Double.random(in: 0.15...0.85, using: &rng),
                g: Double.random(in: 0.08...0.45, using: &rng),
                b: Double.random(in: 0.15...0.65, using: &rng),
                driftX: Double.random(in: -0.002...0.002, using: &rng),
                driftY: Double.random(in: -0.0015...0.0015, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng)
            )
        }

        dust = (0..<40).map { _ in
            DustMote(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                size: Double.random(in: 0.5...2.0, using: &rng),
                brightness: Double.random(in: 0.08...0.25, using: &rng),
                driftSpeed: Double.random(in: 0.0003...0.0012, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng)
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

    // MARK: - Subtle Milky Way dust lane

    private func drawDustLane(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: max(size.width, size.height) * 0.15))
            let breathe = sin(t * 0.025) * 0.008 + 0.035
            // Diagonal translucent band of warm cosmic gas
            let bandW = max(size.width, size.height) * 0.25
            for i in 0..<6 {
                let frac = Double(i) / 5.0
                let x = frac * size.width * 1.4 - size.width * 0.2
                let y = (1.0 - frac) * size.height * 1.2 - size.height * 0.1
                let drift = sin(t * 0.01 + frac * 2) * 20
                let r = bandW * (0.6 + sin(frac * .pi) * 0.4)
                let warmth = 0.5 + sin(frac * .pi * 2) * 0.3
                l.fill(Ellipse().path(in: CGRect(x: x + drift - r, y: y - r * 0.4,
                                                  width: r * 2, height: r * 0.8)),
                    with: .color(Color(red: 0.3 + warmth * 0.15, green: 0.15 + warmth * 0.08,
                                       blue: 0.25).opacity(breathe)))
            }
        }
    }

    // MARK: - Drifting cosmic dust particles

    private func drawDust(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for mote in dust {
            let x = fmod(mote.x + t * mote.driftSpeed + 10, 1.0) * size.width
            let y = fmod(mote.y + t * mote.driftSpeed * 0.3 + 10, 1.0) * size.height
            let twinkle = sin(t * 0.5 + mote.phase) * 0.3 + 0.7
            let alpha = mote.brightness * twinkle
            let s = mote.size
            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            ctx.fill(Ellipse().path(in: rect),
                with: .color(Color(red: 0.9, green: 0.75, blue: 0.6).opacity(alpha)))
        }
    }

    private func drawNebulae(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Single shared blur layer for all 14 nebulae (was 14 separate layers)
        ctx.drawLayer { layerCtx in
            layerCtx.addFilter(.blur(radius: size.width * 0.08))
            layerCtx.opacity = 0.3
            for n in nebulae {
                let x = (n.cx + sin(t * n.driftX * 8 + n.phase) * 0.06) * size.width
                let y = (n.cy + cos(t * n.driftY * 8 + n.phase) * 0.06) * size.height
                let baseR = n.radius * max(size.width, size.height)
                let breathe = sin(t * 0.15 + n.phase) * 0.08 + 1.0
                let r = baseR * breathe
                let color = Color(red: n.r, green: n.g, blue: n.b)

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
        let active = ripples.filter { t - $0.birthTime < 7.0 }
        guard !active.isEmpty else { return }

        for ripple in active {
            let age = t - ripple.birthTime
            let p = age / 7.0

            // Core flash — bright then fading
            let coreFade = age < 0.3 ? age / 0.3 : max(0, 1.0 - (age - 0.3) / 2.0)
            if coreFade > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 20 + p * 30))
                    let r = 15 + p * 40
                    l.fill(Ellipse().path(in: CGRect(x: ripple.x - r, y: ripple.y - r,
                                                     width: r * 2, height: r * 2)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.5, green: 1.2, blue: 1.6).opacity(0.30 * coreFade),
                                Color(red: 1.1, green: 0.6, blue: 1.3).opacity(0.10 * coreFade),
                                .clear
                            ]),
                            center: CGPoint(x: ripple.x, y: ripple.y),
                            startRadius: 0, endRadius: r))
                }
            }

            // 3 expanding rings — warm center to cool edge
            let ringColors: [(Double, Double, Double)] = [
                (1.3, 0.8, 0.5),   // amber
                (1.1, 0.6, 1.3),   // magenta
                (0.5, 0.8, 1.4),   // cyan
            ]
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 10))
                for (ri, rc) in ringColors.enumerated() {
                    let delay = Double(ri) * 0.4
                    let ringAge = age - delay
                    guard ringAge > 0 else { continue }
                    let rp = min(ringAge / 5.5, 1.0)
                    let ringFade = max(0, 1.0 - rp) * (1.0 - Double(ri) * 0.15)
                    let radius = rp * (100 + Double(ri) * 40)
                    let rect = CGRect(x: ripple.x - radius, y: ripple.y - radius,
                                     width: radius * 2, height: radius * 2)
                    l.stroke(Ellipse().path(in: rect),
                        with: .color(Color(red: rc.0, green: rc.1, blue: rc.2).opacity(ringFade * 0.22)),
                        lineWidth: 2.0 - rp * 1.2)
                }
            }

            // Spiral stardust particles
            let seed = UInt64(ripple.birthTime * 1000) & 0xFFFFFF
            var rng = SplitMix64(seed: seed)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 3))
                for i in 0..<16 {
                    let baseAngle = Double(i) / 16.0 * .pi * 2
                    let spiralTwist = nextDouble(&rng) * 2.0 + 1.0
                    let driftSpeed = nextDouble(&rng) * 0.5 + 0.5
                    let sz = nextDouble(&rng) * 2.0 + 1.5
                    let lifespan = nextDouble(&rng) * 3.0 + 3.5
                    guard age < lifespan else { continue }
                    let mp = age / lifespan
                    let moteFade = mp < 0.1 ? mp / 0.1 : max(0, 1.0 - (mp - 0.1) / 0.9)
                    let dist = mp * driftSpeed * 130
                    let angle = baseAngle + age * spiralTwist * 0.3
                    let mx = ripple.x + cos(angle) * dist
                    let my = ripple.y + sin(angle) * dist
                    let pulse = sin(age * 2.5 + Double(i)) * 0.25 + 0.75
                    let s = sz * moteFade * pulse
                    let warmth = nextDouble(&rng)
                    let color = warmth > 0.5
                        ? Color(red: 1.3, green: 0.9, blue: 1.5)
                        : Color(red: 0.8, green: 1.1, blue: 1.4)
                    l.fill(Ellipse().path(in: CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)),
                        with: .color(color.opacity(moteFade * 0.5 * pulse)))
                }
            }
        }
    }
}
