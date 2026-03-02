import SwiftUI

// Paper Lantern Festival — Genesis-inspired gentle meditation.
// A sparse, serene lake at dusk. The sky is banded in warm 16-bit
// style gradients. The scene starts quiet — just water, mountains,
// a few fireflies. Each click releases ONE paper lantern carrying
// a kind message. Lanterns rise slowly, glowing, their words visible.
// The lake reflects their light. Unhurried. Contemplative.
// Pure Canvas, 60fps, no state mutation inside Canvas closure.

struct PaperLanternFestivalScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data

    struct FireflyData {
        let baseX, baseY, orbitR, speed, phase, brightness: Double
    }

    struct MountainPt {
        let x, y: Double
    }

    struct Lantern: Identifiable {
        let id = UUID()
        let x: Double           // normalised 0..1
        let birth: Double       // time of creation
        let driftPhase: Double
        let driftAmp: Double
        let riseSpeed: Double
        let warmth: Double      // 0..1 colour variation
        let flickerRate: Double
        let flickerPhase: Double
        let message: String
    }

    private static let messages: [String] = [
        "be gentle", "you are enough", "breathe",
        "rest now", "be kind", "all is well",
        "you belong", "peace", "take your time",
        "let go", "you matter", "be still",
        "dream softly", "you're okay", "keep going",
        "you're loved", "slow down", "be here now",
        "hope", "you're safe", "one step",
        "be warm", "smile", "grace",
        "it's alright", "you're here", "softly now",
        "patience", "wonder", "tenderness",
    ]

    @State private var lanterns: [Lantern] = []
    @State private var fireflies: [FireflyData] = []
    @State private var mountains: [MountainPt] = []
    @State private var ready = false
    @State private var viewSize: CGSize = CGSize(width: 1200, height: 800)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawMountains(ctx: &ctx, size: size)
                drawWater(ctx: &ctx, size: size, t: t)
                drawLanterns(ctx: &ctx, size: size, t: t)
                drawReflections(ctx: &ctx, size: size, t: t)
                drawFireflies(ctx: &ctx, size: size, t: t)
                drawReeds(ctx: &ctx, size: size)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { viewSize = geo.size }
                    .onChange(of: geo.size) { _, newSize in viewSize = newSize }
            }
        )
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            let screenW = max(viewSize.width, 1)
            let nx = loc.x / screenW
            var rng = SplitMix64(seed: UInt64(t * 10000))
            let msgIndex = Int(nextUInt64(&rng) % UInt64(Self.messages.count))
            lanterns.append(Lantern(
                x: nx,
                birth: t,
                driftPhase: rng.nextDouble() * .pi * 2,
                driftAmp: 0.006 + rng.nextDouble() * 0.012,
                riseSpeed: 0.010 + rng.nextDouble() * 0.006,
                warmth: rng.nextDouble(),
                flickerRate: 1.5 + rng.nextDouble() * 2.0,
                flickerPhase: rng.nextDouble() * .pi * 2,
                message: Self.messages[msgIndex]
            ))
            // Keep it sparse
            if lanterns.count > 20 { lanterns.removeFirst() }
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 0xA4E840)

        // Just a handful of fireflies — gentle presence
        for _ in 0..<12 {
            fireflies.append(FireflyData(
                baseX: rng.nextDouble(),
                baseY: 0.30 + rng.nextDouble() * 0.28,
                orbitR: 0.004 + rng.nextDouble() * 0.012,
                speed: 0.25 + rng.nextDouble() * 0.6,
                phase: rng.nextDouble() * .pi * 2,
                brightness: 0.15 + rng.nextDouble() * 0.4
            ))
        }

        // Mountain silhouette — gentle rolling profile
        let segments = 24
        for i in 0...segments {
            let frac = Double(i) / Double(segments)
            let h = 0.06 + sin(frac * .pi * 2.5) * 0.022 + rng.nextDouble() * 0.012
            mountains.append(MountainPt(x: frac, y: h))
        }

        ready = true
    }

    // MARK: - Drawing

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        // Genesis-style banded gradient — distinct warm colour bands
        let bands: [(r: Double, g: Double, b: Double)] = [
            (0.02, 0.01, 0.09),   // deep indigo
            (0.04, 0.02, 0.12),
            (0.06, 0.03, 0.14),
            (0.09, 0.04, 0.14),
            (0.13, 0.05, 0.13),
            (0.17, 0.06, 0.11),
            (0.21, 0.07, 0.10),
            (0.26, 0.09, 0.09),
            (0.31, 0.12, 0.08),
            (0.35, 0.15, 0.07),   // warm amber horizon
        ]
        let bandH = waterLine / Double(bands.count)
        for (i, c) in bands.enumerated() {
            let y0 = Double(i) * bandH
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: bandH + 1)),
                with: .color(Color(red: c.r, green: c.g, blue: c.b))
            )
        }

        // Thin warm glow at horizon
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 25))
            let glowRect = CGRect(x: 0, y: waterLine - 30, width: w, height: 30)
            layer.fill(Path(glowRect),
                with: .color(Color(red: 0.4, green: 0.15, blue: 0.06).opacity(0.12)))
        }
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65
        var rng = SplitMix64(seed: 0x5EA450)
        for _ in 0..<50 {
            let sx = rng.nextDouble() * w
            let sy = rng.nextDouble() * waterLine * 0.55
            let br = 0.08 + rng.nextDouble() * 0.22
            let twinkle = sin(t * (0.4 + rng.nextDouble() * 1.2) + rng.nextDouble() * 6.28) * 0.2 + 0.8
            let r = 0.4 + rng.nextDouble() * 0.5
            ctx.fill(
                Circle().path(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                with: .color(Color.white.opacity(br * twinkle))
            )
        }
    }

    private func drawMountains(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        var path = Path()
        for (i, pt) in mountains.enumerated() {
            let x = pt.x * w
            let y = waterLine - pt.y * h
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        path.addLine(to: CGPoint(x: w, y: waterLine))
        path.addLine(to: CGPoint(x: 0, y: waterLine))
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(red: 0.03, green: 0.02, blue: 0.05)))
    }

    private func drawWater(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        ctx.fill(
            Path(CGRect(x: 0, y: waterLine, width: w, height: h - waterLine)),
            with: .color(Color(red: 0.015, green: 0.012, blue: 0.03))
        )

        // Gentle wave lines
        for i in 0..<5 {
            let wy = waterLine + Double(i + 1) * (h - waterLine) / 6.0
            var wave = Path()
            for xi in 0...30 {
                let frac = Double(xi) / 30.0
                let x = frac * w
                let offset = sin(frac * .pi * 3 + t * 0.18 + Double(i) * 0.9) * 1.2
                let pt = CGPoint(x: x, y: wy + offset)
                if xi == 0 { wave.move(to: pt) } else { wave.addLine(to: pt) }
            }
            ctx.stroke(wave, with: .color(Color(red: 0.10, green: 0.07, blue: 0.15).opacity(0.05)), lineWidth: 0.5)
        }
    }

    private func drawLanterns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        for lantern in lanterns {
            let age = t - lantern.birth
            guard age > 0 else { continue }

            // Slow gentle rise from lower sky
            let rise = age * lantern.riseSpeed
            let x = (lantern.x + sin(age * 0.35 + lantern.driftPhase) * lantern.driftAmp) * w
            let y = (0.56 - rise) * h
            guard y > -20, y < waterLine else { continue }

            // Fade in gently over 2.5s, fade out near top
            let normY = y / waterLine
            var alpha = 1.0
            if age < 2.5 { alpha = age / 2.5 }
            if normY < 0.08 { alpha *= normY / 0.08 }
            guard alpha > 0.01 else { continue }

            let flicker = sin(t * lantern.flickerRate + lantern.flickerPhase) * 0.06 + 0.94
            let s: Double = 12.0   // lantern body radius
            let warmR = 1.0 + lantern.warmth * 0.2
            let warmG = 0.55 + lantern.warmth * 0.15
            let warmB = 0.10

            // Soft outer glow
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 22))
                let gr = s * 3.5
                layer.fill(
                    Ellipse().path(in: CGRect(x: x - gr, y: y - gr, width: gr * 2, height: gr * 2)),
                    with: .color(Color(red: warmR, green: warmG, blue: warmB).opacity(alpha * flicker * 0.12))
                )
            }

            // Lantern body — warm rounded shape
            let bodyW = s * 1.5
            let bodyH = s * 2.0
            let bodyRect = CGRect(x: x - bodyW / 2, y: y - bodyH / 2, width: bodyW, height: bodyH)
            ctx.fill(
                RoundedRectangle(cornerRadius: s * 0.4).path(in: bodyRect),
                with: .color(Color(red: warmR * flicker, green: warmG * flicker, blue: warmB).opacity(alpha * 0.80))
            )

            // Inner flame
            let flameR = s * 0.18
            let flameY = y + sin(t * 2.5 + lantern.flickerPhase) * s * 0.04
            ctx.fill(
                Circle().path(in: CGRect(x: x - flameR, y: flameY - flameR, width: flameR * 2, height: flameR * 2)),
                with: .color(Color(red: 1.3, green: 1.0, blue: 0.4).opacity(alpha * flicker * 0.6))
            )

            // Message text on the lantern
            let textAlpha = alpha * 0.85
            let text = Text(lantern.message)
                .font(.system(size: 8, weight: .light, design: .serif))
                .foregroundColor(Color(red: 0.25, green: 0.12, blue: 0.04).opacity(textAlpha))
            ctx.draw(text, at: CGPoint(x: x, y: y - s * 0.1))

            // Thin string below
            var stringPath = Path()
            stringPath.move(to: CGPoint(x: x, y: y + bodyH / 2))
            stringPath.addLine(to: CGPoint(x: x + sin(t * 0.25 + lantern.driftPhase) * 0.8,
                                           y: y + bodyH / 2 + s * 0.35))
            ctx.stroke(stringPath, with: .color(Color.white.opacity(alpha * 0.08)), lineWidth: 0.4)
        }
    }

    private func drawReflections(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 16))
            for lantern in lanterns {
                let age = t - lantern.birth
                guard age > 0 else { continue }
                let rise = age * lantern.riseSpeed
                let x = (lantern.x + sin(age * 0.35 + lantern.driftPhase) * lantern.driftAmp) * w
                let y = (0.56 - rise) * h
                guard y > 0, y < waterLine else { continue }

                var alpha = 1.0
                if age < 2.5 { alpha = age / 2.5 }
                let normY = y / waterLine
                if normY < 0.08 { alpha *= normY / 0.08 }
                guard alpha > 0.02 else { continue }

                let reflX = x + sin(t * 0.25 + lantern.driftPhase) * 2.0
                let reflY = waterLine + (waterLine - y) * 0.3
                let reflH = (h - waterLine) * 0.18
                let reflW = 3.5

                layer.fill(
                    Ellipse().path(in: CGRect(x: reflX - reflW, y: reflY, width: reflW * 2, height: reflH)),
                    with: .color(Color(red: 0.8 + lantern.warmth * 0.2, green: 0.4 + lantern.warmth * 0.1, blue: 0.08).opacity(alpha * 0.04))
                )
            }
        }
    }

    private func drawFireflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            for ff in fireflies {
                let angle = t * ff.speed + ff.phase
                let x = (ff.baseX + cos(angle) * ff.orbitR) * w
                let y = (ff.baseY + sin(angle * 0.6) * ff.orbitR * 0.5) * h
                let pulse = sin(t * 1.2 + ff.phase) * 0.4 + 0.6
                let alpha = ff.brightness * pulse * 0.3
                let r = 1.2 + pulse * 0.4
                layer.fill(
                    Circle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 1.0, green: 0.85, blue: 0.3).opacity(alpha))
                )
            }
        }
    }

    private func drawReeds(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let waterLine = h * 0.65

        var rng = SplitMix64(seed: 0xBEED5)
        for _ in 0..<20 {
            let side = rng.nextDouble() > 0.5
            let baseX = side ? w - rng.nextDouble() * w * 0.10 : rng.nextDouble() * w * 0.10
            let baseY = waterLine - rng.nextDouble() * 3.0
            let reedH = 10.0 + rng.nextDouble() * 22.0
            let lean = (rng.nextDouble() - 0.5) * 5.0

            var reed = Path()
            reed.move(to: CGPoint(x: baseX, y: baseY))
            reed.addQuadCurve(
                to: CGPoint(x: baseX + lean, y: baseY - reedH),
                control: CGPoint(x: baseX + lean * 0.5, y: baseY - reedH * 0.5)
            )
            ctx.stroke(reed, with: .color(Color(red: 0.02, green: 0.02, blue: 0.03)),
                        lineWidth: 0.7 + rng.nextDouble() * 0.4)
        }
    }
}
