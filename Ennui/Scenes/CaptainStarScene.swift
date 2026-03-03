import SwiftUI

struct CaptainStarScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct RockData {
        let x, y, size, drift, phase, rotation: Double
    }

    struct DustMote {
        let x, y, speed, size, phase: Double
    }

    struct SkyStreak {
        let y, width, speed, alpha: Double
    }

    struct TapGlow {
        let x, y, birth: Double
    }

    @State private var rocks: [RockData] = []
    @State private var dust: [DustMote] = []
    @State private var streaks: [SkyStreak] = []
    @State private var distantPeaks: [(x: Double, h: Double, w: Double)] = []
    @State private var tapGlows: [TapGlow] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawDistantMountains(ctx: &ctx, size: size, t: t)
                drawDesertFloor(ctx: &ctx, size: size, t: t)
                drawFloatingRocks(ctx: &ctx, size: size, t: t)
                drawOutpost(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawDust(ctx: &ctx, size: size, t: t)
                drawSkyStreaks(ctx: &ctx, size: size, t: t)
                drawTapGlows(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.12, green: 0.09, blue: 0.06))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: generate)
        .onChange(of: interaction.tapCount) { _, _ in handleTap() }
    }

    private func generate() {
        var rng = SplitMix64(seed: 1997)

        rocks = (0..<12).map { _ in
            RockData(
                x: nextDouble(&rng),
                y: 0.15 + nextDouble(&rng) * 0.45,
                size: 8 + nextDouble(&rng) * 25,
                drift: 0.003 + nextDouble(&rng) * 0.006,
                phase: nextDouble(&rng) * .pi * 2,
                rotation: nextDouble(&rng) * .pi * 2
            )
        }

        dust = (0..<80).map { _ in
            DustMote(
                x: nextDouble(&rng),
                y: nextDouble(&rng),
                speed: 0.002 + nextDouble(&rng) * 0.005,
                size: 0.5 + nextDouble(&rng) * 2.5,
                phase: nextDouble(&rng) * .pi * 2
            )
        }

        streaks = (0..<6).map { _ in
            SkyStreak(
                y: 0.05 + nextDouble(&rng) * 0.35,
                width: 40 + nextDouble(&rng) * 120,
                speed: 0.5 + nextDouble(&rng) * 1.5,
                alpha: 0.02 + nextDouble(&rng) * 0.04
            )
        }

        distantPeaks = (0..<20).map { _ in
            (x: nextDouble(&rng), h: 0.05 + nextDouble(&rng) * 0.15, w: 0.02 + nextDouble(&rng) * 0.06)
        }

        ready = true
    }

    private func handleTap() {
        // A gentle luminous pulse from a random spot on the desert
        var rng = SplitMix64(seed: UInt64(interaction.tapCount * 31 + 77))
        let glow = TapGlow(
            x: 0.2 + nextDouble(&rng) * 0.6,
            y: 0.5 + nextDouble(&rng) * 0.3,
            birth: Date().timeIntervalSince(startDate)
        )
        tapGlows.append(glow)
        if tapGlows.count > 5 { tapGlows.removeFirst() }
    }

    // MARK: - Sky (ochre gradient, vast emptiness)

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let breathe = sin(t * 0.04) * 0.02
        let skyRect = CGRect(origin: .zero, size: size)
        ctx.fill(Rectangle().path(in: skyRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.18 + breathe, green: 0.14 + breathe * 0.5, blue: 0.08),
                Color(red: 0.55 + breathe, green: 0.38, blue: 0.15),
                Color(red: 0.72 + breathe, green: 0.52, blue: 0.22),
            ]),
            startPoint: CGPoint(x: size.width * 0.5, y: 0),
            endPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.65)
        ))
    }

    // MARK: - Stars (visible even in the ochre sky — edge of the universe)

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 3344)
        for _ in 0..<100 {
            let sx = nextDouble(&rng) * size.width
            let sy = nextDouble(&rng) * size.height * 0.55
            let ss = 0.5 + nextDouble(&rng) * 1.5
            let twinkle = sin(t * (0.5 + nextDouble(&rng) * 1.5) + nextDouble(&rng) * 6.28) * 0.3 + 0.7
            // Stars are muted — visible through the dusty sky
            let brightness = (0.3 + nextDouble(&rng) * 0.4) * twinkle
            let yFade = 1.0 - (sy / (size.height * 0.55)) * 0.6
            ctx.fill(Ellipse().path(in: CGRect(x: sx - ss / 2, y: sy - ss / 2, width: ss, height: ss)),
                     with: .color(Color(red: brightness * 1.1, green: brightness * 0.9, blue: brightness * 0.7).opacity(0.4 * yFade)))
        }
    }

    // MARK: - Distant jagged mountains (silhouette)

    private func drawDistantMountains(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let horizonY = size.height * 0.6

        // Far range — very faint
        var farPath = Path()
        farPath.move(to: CGPoint(x: 0, y: horizonY))
        for peak in distantPeaks {
            let px = peak.x * size.width
            let py = horizonY - peak.h * size.height * 0.7
            farPath.addLine(to: CGPoint(x: px, y: py))
        }
        farPath.addLine(to: CGPoint(x: size.width, y: horizonY))
        farPath.closeSubpath()
        ctx.fill(farPath, with: .color(Color(red: 0.25, green: 0.18, blue: 0.12).opacity(0.35)))

        // Near range — slightly darker
        var nearPath = Path()
        nearPath.move(to: CGPoint(x: 0, y: horizonY + 5))
        var nRng = SplitMix64(seed: 7788)
        for i in 0..<15 {
            let nx = Double(i) / 14.0 * size.width
            let nh = (0.02 + nextDouble(&nRng) * 0.08) * size.height
            nearPath.addLine(to: CGPoint(x: nx, y: horizonY + 5 - nh))
        }
        nearPath.addLine(to: CGPoint(x: size.width, y: horizonY + 5))
        nearPath.closeSubpath()
        ctx.fill(nearPath, with: .color(Color(red: 0.20, green: 0.14, blue: 0.09).opacity(0.5)))
    }

    // MARK: - Desert floor (barren, stretching to horizon)

    private func drawDesertFloor(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let horizonY = size.height * 0.6
        let floorRect = CGRect(x: 0, y: horizonY, width: size.width, height: size.height - horizonY)
        ctx.fill(Rectangle().path(in: floorRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.35, green: 0.25, blue: 0.14),
                Color(red: 0.22, green: 0.16, blue: 0.10),
                Color(red: 0.12, green: 0.09, blue: 0.06),
            ]),
            startPoint: CGPoint(x: size.width * 0.5, y: horizonY),
            endPoint: CGPoint(x: size.width * 0.5, y: size.height)
        ))

        // Sparse surface detail — cracks, pebbles
        var rng = SplitMix64(seed: 2233)
        for _ in 0..<25 {
            let cx = nextDouble(&rng) * size.width
            let cy = horizonY + 10 + nextDouble(&rng) * (size.height - horizonY - 10)
            let cw = 8 + nextDouble(&rng) * 30
            let depth = (cy - horizonY) / (size.height - horizonY)
            ctx.fill(Rectangle().path(in: CGRect(x: cx, y: cy, width: cw, height: 0.5 + depth)),
                     with: .color(Color(red: 0.18, green: 0.13, blue: 0.08).opacity(0.15 + depth * 0.1)))
        }
    }

    // MARK: - Floating rocks (cosmic gravity anomalies)

    private func drawFloatingRocks(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for rock in rocks {
            let bobble = sin(t * rock.drift * 50 + rock.phase) * 12
            let lateralDrift = sin(t * rock.drift * 20 + rock.phase * 1.5) * 5
            let rx = rock.x * size.width + lateralDrift
            let ry = rock.y * size.height + bobble
            let s = rock.size

            // Sketchy angular shape — irregular polygon
            var shape = Path()
            let points = 5
            for i in 0..<points {
                let angle = Double(i) / Double(points) * .pi * 2 + rock.rotation
                let r = s * (0.6 + sin(angle * 2.3 + rock.phase) * 0.4)
                let px = rx + cos(angle) * r
                let py = ry + sin(angle) * r
                if i == 0 { shape.move(to: CGPoint(x: px, y: py)) }
                else { shape.addLine(to: CGPoint(x: px, y: py)) }
            }
            shape.closeSubpath()

            // Warm ochre rock with slight glow
            let rockBright = 0.25 + sin(t * 0.2 + rock.phase) * 0.04
            ctx.fill(shape, with: .color(Color(red: rockBright + 0.1, green: rockBright, blue: rockBright * 0.6).opacity(0.6)))

            // Subtle shadow underneath
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 6))
                l.fill(Ellipse().path(in: CGRect(x: rx - s * 0.5, y: ry + s * 0.8, width: s, height: s * 0.3)),
                       with: .color(Color(red: 0.05, green: 0.03, blue: 0.02).opacity(0.15)))
            }
        }
    }

    // MARK: - The outpost (lone glass/crystal structure, catching starlight)

    private func drawOutpost(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseX = size.width * 0.52
        let baseY = size.height * 0.62
        let outpostW: Double = 55
        let outpostH: Double = 90

        // Main tower — translucent glass/crystal
        let shimmer = sin(t * 0.15) * 0.03
        var tower = Path()
        tower.move(to: CGPoint(x: baseX - outpostW * 0.25, y: baseY))
        tower.addLine(to: CGPoint(x: baseX - outpostW * 0.15, y: baseY - outpostH))
        tower.addLine(to: CGPoint(x: baseX + outpostW * 0.15, y: baseY - outpostH * 1.05))
        tower.addLine(to: CGPoint(x: baseX + outpostW * 0.25, y: baseY))
        tower.closeSubpath()
        ctx.fill(tower, with: .color(Color(red: 0.25 + shimmer, green: 0.30 + shimmer, blue: 0.40 + shimmer).opacity(0.35)))

        // Glass panel reflections
        for i in 0..<5 {
            let panelY = baseY - Double(i + 1) * outpostH / 6
            let panelW = outpostW * 0.25 * (1.0 - Double(i) * 0.05)
            let glint = sin(t * 0.3 + Double(i) * 1.2) * 0.06 + 0.12
            ctx.fill(Rectangle().path(in: CGRect(x: baseX - panelW * 0.4, y: panelY - 4, width: panelW * 0.8, height: 3)),
                     with: .color(Color(red: 0.5 + glint, green: 0.6 + glint, blue: 0.8 + glint).opacity(0.2)))
        }

        // Dome at top
        let domeR: Double = 8
        let domeY = baseY - outpostH * 1.05 - domeR
        ctx.fill(Ellipse().path(in: CGRect(x: baseX - domeR, y: domeY, width: domeR * 2, height: domeR * 1.3)),
                 with: .color(Color(red: 0.3 + shimmer, green: 0.35 + shimmer, blue: 0.5 + shimmer).opacity(0.3)))

        // Warm interior glow (someone is inside)
        let glowPulse = sin(t * 0.25) * 0.08 + 0.92
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 15))
            let glowRect = CGRect(x: baseX - 15, y: baseY - outpostH * 0.5 - 15, width: 30, height: 30)
            l.fill(Ellipse().path(in: glowRect),
                   with: .color(Color(red: 0.9 * glowPulse, green: 0.6 * glowPulse, blue: 0.2).opacity(0.15)))
        }

        // Tiny warm window
        ctx.fill(Rectangle().path(in: CGRect(x: baseX - 3, y: baseY - outpostH * 0.4 - 2, width: 6, height: 4)),
                 with: .color(Color(red: 1.1 * glowPulse, green: 0.75 * glowPulse, blue: 0.3).opacity(0.5)))

        // Secondary smaller structure (antenna/relay)
        let ant2X = baseX + outpostW * 0.6
        let ant2Y = baseY + 2
        ctx.fill(Rectangle().path(in: CGRect(x: ant2X - 1.5, y: ant2Y - 35, width: 3, height: 35)),
                 with: .color(Color(red: 0.22, green: 0.18, blue: 0.14).opacity(0.4)))
        // Blinking light on relay
        let blink = sin(t * 1.8) > 0.6
        if blink {
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                l.fill(Ellipse().path(in: CGRect(x: ant2X - 3, y: ant2Y - 38, width: 6, height: 6)),
                       with: .color(Color(red: 0.9, green: 0.3, blue: 0.15).opacity(0.5)))
            }
        }
    }

    // MARK: - Dust motes (ever-present, drifting)

    private func drawDust(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for mote in dust {
            let mx = fmod(mote.x + t * mote.speed, 1.1) * size.width
            let my = mote.y * size.height + sin(t * 0.5 + mote.phase) * 8
            let alpha = sin(t * 0.3 + mote.phase) * 0.15 + 0.2
            ctx.fill(Ellipse().path(in: CGRect(x: mx - mote.size / 2, y: my - mote.size / 2,
                                                width: mote.size, height: mote.size)),
                     with: .color(Color(red: 0.7, green: 0.55, blue: 0.35).opacity(alpha)))
        }
    }

    // MARK: - Sky streaks (thin wind lines across the ochre sky)

    private func drawSkyStreaks(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for streak in streaks {
            let sx = fmod(t * streak.speed * 10, size.width + streak.width * 2) - streak.width
            let sy = streak.y * size.height + sin(t * 0.1 + streak.y * 5) * 3
            ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy, width: streak.width, height: 0.5)),
                     with: .color(Color(red: 0.6, green: 0.45, blue: 0.25).opacity(streak.alpha)))
        }
    }

    // MARK: - Tap glows (luminous pulses from the desert)

    private func drawTapGlows(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for glow in tapGlows {
            let age = t - glow.birth
            guard age < 4.0 else { continue }
            let fade = 1.0 - age / 4.0
            let expand = age * 25
            let gx = glow.x * size.width
            let gy = glow.y * size.height

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 12 + expand * 0.5))
                let r = 10 + expand
                l.fill(Ellipse().path(in: CGRect(x: gx - r, y: gy - r, width: r * 2, height: r * 2)),
                       with: .color(Color(red: 0.8 * fade, green: 0.5 * fade, blue: 0.15).opacity(0.15 * fade)))
            }
        }
    }
}
