import SwiftUI

// Late Night Rerun — millennial comfort: falling asleep to late-night TV
// in a cozy 90s bedroom. A CRT television flickers softly, casting
// shifting light across the room. Glow-in-the-dark stars dot the ceiling,
// a lava lamp bubbles on the nightstand, string lights drape the wall,
// rain taps against the window. Tap to change the channel — colour bars,
// static, a bouncing DVD logo, or a warm late-night rerun.
// Pure Canvas, 60fps, no state mutation inside draw calls.

struct LateNightRerunScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // TV channel state
    @State private var channel: Int = 0
    @State private var channelChangeTime: Double = -10
    private let channelCount = 4

    // MARK: - Data types

    struct GlowStar {
        let x, y, size, phase, brightness: Double
    }

    struct StringLightBulb {
        let x, y, phase, hue: Double
    }

    struct RainStreak {
        let x, speed, length, phase: Double
    }

    struct LavaBlob {
        let baseY, size, riseSpeed, wanderPhase, warmth: Double
    }

    @State private var glowStars: [GlowStar] = []
    @State private var stringLights: [StringLightBulb] = []
    @State private var rainStreaks: [RainStreak] = []
    @State private var lavaBlobs: [LavaBlob] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawRoomBase(ctx: &ctx, size: size, t: t)
                drawTVGlow(ctx: &ctx, size: size, t: t)
                drawWindow(ctx: &ctx, size: size, t: t)
                drawRain(ctx: &ctx, size: size, t: t)
                drawPoster(ctx: &ctx, size: size, t: t)
                drawBookshelf(ctx: &ctx, size: size, t: t)
                drawNightstand(ctx: &ctx, size: size, t: t)
                drawTV(ctx: &ctx, size: size, t: t)
                drawLavaLamp(ctx: &ctx, size: size, t: t)
                drawClock(ctx: &ctx, size: size, t: t)
                drawStringLights(ctx: &ctx, size: size, t: t)
                drawCeilingStars(ctx: &ctx, size: size, t: t)
                drawBed(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.02, green: 0.015, blue: 0.04))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            channelChangeTime = Date().timeIntervalSince(startDate)
            channel = (channel + 1) % channelCount
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 2001) // Y2K baby

        glowStars = (0..<30).map { _ in
            GlowStar(
                x: nextDouble(&rng),
                y: nextDouble(&rng) * 0.18,
                size: 2 + nextDouble(&rng) * 4,
                phase: nextDouble(&rng) * .pi * 2,
                brightness: 0.4 + nextDouble(&rng) * 0.6
            )
        }

        // String lights in catenary along wall-ceiling boundary
        stringLights = (0..<14).map { i in
            let frac = Double(i) / 13.0
            let x = 0.08 + frac * 0.84
            let sag = 4.0 * frac * (1.0 - frac) // parabolic droop
            let y = 0.19 - sag * 0.035
            return StringLightBulb(
                x: x, y: y,
                phase: nextDouble(&rng) * .pi * 2,
                hue: nextDouble(&rng) * 0.12 + 0.06
            )
        }

        rainStreaks = (0..<45).map { _ in
            RainStreak(
                x: nextDouble(&rng),
                speed: 0.3 + nextDouble(&rng) * 0.5,
                length: 12 + nextDouble(&rng) * 25,
                phase: nextDouble(&rng)
            )
        }

        lavaBlobs = (0..<8).map { _ in
            LavaBlob(
                baseY: nextDouble(&rng),
                size: 6 + nextDouble(&rng) * 12,
                riseSpeed: 0.02 + nextDouble(&rng) * 0.03,
                wanderPhase: nextDouble(&rng) * .pi * 2,
                warmth: nextDouble(&rng)
            )
        }

        ready = true
    }

    // MARK: - TV colour for current channel

    private func tvColor(t: Double) -> (r: Double, g: Double, b: Double, brightness: Double) {
        switch channel {
        case 0: // Late show — warm shifting amber/teal
            let shift = sin(t * 0.3) * 0.5 + 0.5
            return (0.3 + shift * 0.35, 0.22 + shift * 0.12, 0.12 + (1 - shift) * 0.15, 0.7)
        case 1: // Colour bars
            return (0.5, 0.45, 0.4, 0.55)
        case 2: // Static
            return (0.32, 0.32, 0.35, 0.45 + sin(t * 20) * 0.12)
        case 3: // DVD screensaver — deep blue with accent
            let hue = fmod(t * 0.08, 1.0)
            return (0.08 + hue * 0.15, 0.08 + (1 - hue) * 0.15, 0.4, 0.5)
        default:
            return (0.3, 0.3, 0.35, 0.5)
        }
    }

    // MARK: - Room base

    private func drawRoomBase(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let ceilH = size.height * 0.20
        // Ceiling
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: size.width, height: ceilH)),
            with: .color(Color(red: 0.035, green: 0.03, blue: 0.055))
        )
        // Wall
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: ceilH, width: size.width, height: size.height * 0.65)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.05, green: 0.04, blue: 0.07),
                    Color(red: 0.04, green: 0.035, blue: 0.06),
                ]),
                startPoint: CGPoint(x: size.width * 0.5, y: ceilH),
                endPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.85)
            )
        )
        // Floor line
        let floorY = size.height * 0.85
        ctx.stroke(
            Path { p in p.move(to: CGPoint(x: 0, y: floorY)); p.addLine(to: CGPoint(x: size.width, y: floorY)) },
            with: .color(Color.white.opacity(0.025)), lineWidth: 1
        )
        // Carpet
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)),
            with: .color(Color(red: 0.03, green: 0.025, blue: 0.04))
        )
    }

    // MARK: - TV ambient glow (washes the whole room)

    private func drawTVGlow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let tv = tvColor(t: t)
        let tvCx = size.width * 0.60
        let tvCy = size.height * 0.48
        let flicker = 1.0 + sin(t * 8.3) * 0.015 + sin(t * 13.7) * 0.008
        let glowR = max(size.width, size.height) * 0.55

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: glowR * 0.35))
            let rect = CGRect(x: tvCx - glowR, y: tvCy - glowR * 0.7,
                              width: glowR * 2, height: glowR * 1.4)
            l.fill(
                Ellipse().path(in: rect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: tv.r * 1.3, green: tv.g * 1.3, blue: tv.b * 1.3)
                            .opacity(0.10 * tv.brightness * flicker),
                        Color(red: tv.r, green: tv.g, blue: tv.b)
                            .opacity(0.04 * tv.brightness * flicker),
                        Color.clear,
                    ]),
                    center: CGPoint(x: tvCx, y: tvCy),
                    startRadius: 0, endRadius: glowR
                )
            )
        }
    }

    // MARK: - Window (left side, with moonlight)

    private func drawWindow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wx = size.width * 0.08
        let wy = size.height * 0.26
        let ww = size.width * 0.16
        let wh = size.height * 0.32

        // Night sky through window
        let moonPulse = sin(t * 0.08) * 0.03 + 0.08
        ctx.fill(
            Rectangle().path(in: CGRect(x: wx, y: wy, width: ww, height: wh)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.05, green: 0.06, blue: 0.14).opacity(0.8 + moonPulse),
                    Color(red: 0.03, green: 0.04, blue: 0.10).opacity(0.9),
                ]),
                startPoint: CGPoint(x: wx + ww / 2, y: wy),
                endPoint: CGPoint(x: wx + ww / 2, y: wy + wh)
            )
        )

        // Distant streetlight
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 18))
            let sx = wx + ww * 0.72
            let sy = wy + wh * 0.35
            l.fill(
                Ellipse().path(in: CGRect(x: sx - 12, y: sy - 12, width: 24, height: 24)),
                with: .color(Color(red: 0.55, green: 0.45, blue: 0.25).opacity(0.15))
            )
        }

        // A couple tiny distant buildings
        let buildingColor = Color(red: 0.04, green: 0.04, blue: 0.08)
        ctx.fill(Rectangle().path(in: CGRect(x: wx + 5, y: wy + wh * 0.55, width: 8, height: wh * 0.45)),
                 with: .color(buildingColor))
        ctx.fill(Rectangle().path(in: CGRect(x: wx + 16, y: wy + wh * 0.65, width: 12, height: wh * 0.35)),
                 with: .color(buildingColor))
        // Tiny lit window in building
        let litPulse = sin(t * 0.4) * 0.1 + 0.9
        ctx.fill(Rectangle().path(in: CGRect(x: wx + 7, y: wy + wh * 0.62, width: 2, height: 2)),
                 with: .color(Color(red: 0.6, green: 0.5, blue: 0.2).opacity(0.3 * litPulse)))

        // Window frame (cross)
        let frameColor = Color(red: 0.075, green: 0.07, blue: 0.095)
        ctx.fill(Rectangle().path(in: CGRect(x: wx + ww / 2 - 2, y: wy, width: 4, height: wh)),
                 with: .color(frameColor))
        ctx.fill(Rectangle().path(in: CGRect(x: wx, y: wy + wh / 2 - 2, width: ww, height: 4)),
                 with: .color(frameColor))
        ctx.stroke(Rectangle().path(in: CGRect(x: wx, y: wy, width: ww, height: wh)),
                   with: .color(frameColor), lineWidth: 3)

        // Windowsill
        ctx.fill(
            Rectangle().path(in: CGRect(x: wx - 4, y: wy + wh, width: ww + 8, height: 5)),
            with: .color(Color(red: 0.065, green: 0.06, blue: 0.08))
        )
    }

    // MARK: - Rain streaks on window glass

    private func drawRain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wx = size.width * 0.08
        let wy = size.height * 0.26
        let ww = size.width * 0.16
        let wh = size.height * 0.32
        let windowRect = CGRect(x: wx, y: wy, width: ww, height: wh)

        ctx.drawLayer { l in
            l.clip(to: Rectangle().path(in: windowRect))
            let windSlant = sin(t * 0.15) * 3.0
            for drop in rainStreaks {
                let yOff = fmod(drop.phase + t * drop.speed, 1.3) * (wh + drop.length) - drop.length
                let dx = wx + drop.x * ww
                let dy = wy + yOff
                var streak = Path()
                streak.move(to: CGPoint(x: dx + windSlant, y: dy))
                streak.addLine(to: CGPoint(x: dx, y: dy + drop.length))
                l.stroke(streak, with: .color(Color.white.opacity(0.07)), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Glow-in-the-dark ceiling stars

    private func drawCeilingStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Soft glow layer
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 3))
            for star in glowStars {
                let sx = star.x * size.width
                let sy = star.y * size.height
                let pulse = sin(t * 0.35 + star.phase) * 0.3 + 0.7
                let alpha = star.brightness * pulse * 0.30
                let s = star.size
                l.fill(
                    Ellipse().path(in: CGRect(x: sx - s / 2, y: sy - s / 2, width: s, height: s)),
                    with: .color(Color(red: 0.5, green: 1.0, blue: 0.35).opacity(alpha))
                )
            }
        }
        // Sharp cores
        for star in glowStars {
            let sx = star.x * size.width
            let sy = star.y * size.height
            let pulse = sin(t * 0.35 + star.phase) * 0.3 + 0.7
            let alpha = star.brightness * pulse * 0.45
            let s = star.size * 0.3
            ctx.fill(
                Ellipse().path(in: CGRect(x: sx - s / 2, y: sy - s / 2, width: s, height: s)),
                with: .color(Color(red: 0.6, green: 1.2, blue: 0.4).opacity(alpha))
            )
        }
    }

    // MARK: - String / fairy lights

    private func drawStringLights(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Wire
        var wire = Path()
        for (i, light) in stringLights.enumerated() {
            let pt = CGPoint(x: light.x * size.width, y: light.y * size.height)
            if i == 0 { wire.move(to: pt) } else { wire.addLine(to: pt) }
        }
        ctx.stroke(wire, with: .color(Color.white.opacity(0.03)), lineWidth: 0.7)

        // Bulb glow (shared blur layer)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 10))
            for light in stringLights {
                let x = light.x * size.width
                let y = light.y * size.height
                let pulse = sin(t * 0.45 + light.phase) * 0.2 + 0.8
                let s = 12.0 * pulse
                let warmR = 1.0 + light.hue
                l.fill(
                    Ellipse().path(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                    with: .color(Color(red: warmR * 0.85, green: 0.6, blue: 0.18).opacity(0.2 * pulse))
                )
            }
        }
        // Sharp bulb cores
        for light in stringLights {
            let x = light.x * size.width
            let y = light.y * size.height
            let pulse = sin(t * 0.45 + light.phase) * 0.2 + 0.8
            ctx.fill(
                Ellipse().path(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                with: .color(Color(red: 1.3, green: 0.85, blue: 0.35).opacity(0.55 * pulse))
            )
        }
    }

    // MARK: - The CRT Television

    private func drawTV(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let tvX = size.width * 0.50
        let tvY = size.height * 0.32
        let tvW = size.width * 0.22
        let tvH = tvW * 0.75 // 4:3 aspect

        // Chunky CRT plastic body
        let pad: Double = 14.0
        let bodyRect = CGRect(x: tvX - pad, y: tvY - pad,
                              width: tvW + pad * 2, height: tvH + pad * 2 + 18)
        ctx.fill(
            RoundedRectangle(cornerRadius: 8).path(in: bodyRect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.065, blue: 0.08),
                    Color(red: 0.055, green: 0.05, blue: 0.065),
                ]),
                startPoint: CGPoint(x: tvX, y: tvY - pad),
                endPoint: CGPoint(x: tvX, y: tvY + tvH + pad + 18)
            )
        )

        // Screen bezel
        ctx.fill(
            RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: tvX - 3, y: tvY - 3,
                                                               width: tvW + 6, height: tvH + 6)),
            with: .color(Color(red: 0.025, green: 0.025, blue: 0.035))
        )

        // Screen content (clipped to screen rect)
        let screenRect = CGRect(x: tvX, y: tvY, width: tvW, height: tvH)
        let changeDelta = t - channelChangeTime

        ctx.drawLayer { l in
            l.clip(to: RoundedRectangle(cornerRadius: 2).path(in: screenRect))

            // Brief static flash on channel change
            if changeDelta > 0 && changeDelta < 0.25 {
                drawChannel_Static(ctx: &l, rect: screenRect, t: t)
                let fade = changeDelta / 0.25
                l.opacity = 1.0 - fade
            }

            // Actual channel content
            switch channel {
            case 0: drawChannel_LateShow(ctx: &l, rect: screenRect, t: t)
            case 1: drawChannel_ColorBars(ctx: &l, rect: screenRect, t: t)
            case 2: drawChannel_Static(ctx: &l, rect: screenRect, t: t)
            case 3: drawChannel_Screensaver(ctx: &l, rect: screenRect, t: t)
            default: break
            }

            // CRT scanlines on screen
            let lineAlpha = 0.10 + sin(t * 0.2) * 0.015
            for y in stride(from: screenRect.minY, through: screenRect.maxY, by: 2.0) {
                l.fill(
                    Rectangle().path(in: CGRect(x: screenRect.minX, y: y,
                                                width: screenRect.width, height: 0.7)),
                    with: .color(Color.black.opacity(lineAlpha))
                )
            }

            // Rolling VHS tracking bar (slow, subtle)
            let barY = fmod(t * 25, screenRect.height + 40) - 20
            let barAlpha = 0.05 + sin(t * 0.7) * 0.02
            l.fill(
                Rectangle().path(in: CGRect(x: screenRect.minX,
                                            y: screenRect.minY + barY,
                                            width: screenRect.width, height: 3)),
                with: .color(Color.white.opacity(barAlpha))
            )

            // CRT curvature vignette
            l.fill(
                Rectangle().path(in: screenRect),
                with: .radialGradient(
                    Gradient(colors: [.clear, .clear, Color.black.opacity(0.35)]),
                    center: CGPoint(x: screenRect.midX, y: screenRect.midY),
                    startRadius: min(tvW, tvH) * 0.3,
                    endRadius: max(tvW, tvH) * 0.58
                )
            )
        }

        // Screen glass reflection
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 5))
            l.opacity = 0.035
            l.fill(
                Ellipse().path(in: CGRect(x: tvX + tvW * 0.08, y: tvY + 4,
                                          width: tvW * 0.45, height: tvH * 0.18)),
                with: .color(.white)
            )
        }

        // Power LED (green, gently pulsing)
        let ledX = tvX + tvW + pad - 10
        let ledY = tvY + tvH + pad + 4
        let ledPulse = sin(t * 0.5) * 0.12 + 0.88
        ctx.fill(
            Circle().path(in: CGRect(x: ledX - 1.5, y: ledY - 1.5, width: 3, height: 3)),
            with: .color(Color(red: 0.1, green: 0.75, blue: 0.1).opacity(0.55 * ledPulse))
        )
        // LED glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            l.fill(
                Circle().path(in: CGRect(x: ledX - 4, y: ledY - 4, width: 8, height: 8)),
                with: .color(Color(red: 0.1, green: 0.7, blue: 0.1).opacity(0.12 * ledPulse))
            )
        }

        // TV stand — small legs
        let standTop = tvY + tvH + pad * 2 + 16
        let legW = 3.0
        ctx.fill(Rectangle().path(in: CGRect(x: tvX + 8, y: standTop - 8, width: legW, height: 8)),
                 with: .color(Color(red: 0.06, green: 0.055, blue: 0.07)))
        ctx.fill(Rectangle().path(in: CGRect(x: tvX + tvW - 11, y: standTop - 8, width: legW, height: 8)),
                 with: .color(Color(red: 0.06, green: 0.055, blue: 0.07)))

        // Dresser / surface TV sits on
        let dresserY = standTop
        let dresserRect = CGRect(x: tvX - pad - 15, y: dresserY,
                                 width: tvW + pad * 2 + 30,
                                 height: size.height * 0.85 - dresserY)
        ctx.fill(
            Rectangle().path(in: dresserRect),
            with: .color(Color(red: 0.04, green: 0.035, blue: 0.05))
        )
        // Dresser top edge
        ctx.fill(
            Rectangle().path(in: CGRect(x: dresserRect.minX, y: dresserY,
                                        width: dresserRect.width, height: 2)),
            with: .color(Color(red: 0.055, green: 0.05, blue: 0.065))
        )

        // VHS tapes stacked on dresser
        let vhsX = tvX + tvW + pad + 2
        for i in 0..<3 {
            let vy = dresserY + 5 + Double(i) * 6.0
            let vhsColor = [
                Color(red: 0.06, green: 0.05, blue: 0.07),
                Color(red: 0.05, green: 0.055, blue: 0.06),
                Color(red: 0.055, green: 0.045, blue: 0.065),
            ][i]
            ctx.fill(
                Rectangle().path(in: CGRect(x: vhsX, y: vy, width: 18, height: 5)),
                with: .color(vhsColor)
            )
            // Label stripe on VHS
            let labelColors = [
                Color(red: 0.08, green: 0.05, blue: 0.04),
                Color(red: 0.04, green: 0.06, blue: 0.08),
                Color(red: 0.07, green: 0.07, blue: 0.04),
            ]
            ctx.fill(
                Rectangle().path(in: CGRect(x: vhsX + 2, y: vy + 1, width: 10, height: 3)),
                with: .color(labelColors[i])
            )
        }
    }

    // MARK: - Channel: Late Show (warm shifting amber)

    private func drawChannel_LateShow(ctx: inout GraphicsContext, rect: CGRect, t: Double) {
        let shift = sin(t * 0.25) * 0.5 + 0.5
        let warmth = sin(t * 0.6) * 0.3 + 0.5

        // Warm background — like half-watching a sitcom
        ctx.fill(
            Rectangle().path(in: rect),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.22 + shift * 0.15, green: 0.16 + warmth * 0.08, blue: 0.09),
                    Color(red: 0.18 + warmth * 0.1, green: 0.13, blue: 0.10 + shift * 0.04),
                ]),
                startPoint: CGPoint(x: rect.minX, y: rect.minY),
                endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
            )
        )

        // Vague figures suggesting people talking on a set
        let figH = rect.height * 0.38
        let figW = rect.width * 0.13
        let sway = sin(t * 0.7) * 4

        // Figure 1
        ctx.fill(
            RoundedRectangle(cornerRadius: figW * 0.3).path(in: CGRect(
                x: rect.minX + rect.width * 0.3 + sway - figW / 2,
                y: rect.maxY - figH - 8, width: figW, height: figH)),
            with: .color(Color(red: 0.14, green: 0.09, blue: 0.07).opacity(0.45))
        )
        // Head 1
        ctx.fill(
            Circle().path(in: CGRect(
                x: rect.minX + rect.width * 0.3 + sway - figW * 0.35,
                y: rect.maxY - figH - 8 - figW * 0.5, width: figW * 0.7, height: figW * 0.7)),
            with: .color(Color(red: 0.14, green: 0.09, blue: 0.07).opacity(0.4))
        )

        // Figure 2
        let sway2 = sin(t * 0.7 + 1.5) * 3
        ctx.fill(
            RoundedRectangle(cornerRadius: figW * 0.3).path(in: CGRect(
                x: rect.minX + rect.width * 0.65 + sway2 - figW / 2,
                y: rect.maxY - figH * 0.85 - 8, width: figW, height: figH * 0.85)),
            with: .color(Color(red: 0.12, green: 0.08, blue: 0.06).opacity(0.38))
        )
        // Head 2
        ctx.fill(
            Circle().path(in: CGRect(
                x: rect.minX + rect.width * 0.65 + sway2 - figW * 0.3,
                y: rect.maxY - figH * 0.85 - 8 - figW * 0.5, width: figW * 0.6, height: figW * 0.6)),
            with: .color(Color(red: 0.12, green: 0.08, blue: 0.06).opacity(0.35))
        )

        // Occasional brightness shift (commercial break feeling)
        let commercialCycle = fmod(t * 0.02, 1.0)
        if commercialCycle > 0.92 {
            let flash = (commercialCycle - 0.92) / 0.08
            ctx.fill(
                Rectangle().path(in: rect),
                with: .color(Color.white.opacity(0.06 * flash))
            )
        }
    }

    // MARK: - Channel: Colour Bars (SMPTE)

    private func drawChannel_ColorBars(ctx: inout GraphicsContext, rect: CGRect, t: Double) {
        let colors: [(Double, Double, Double)] = [
            (0.75, 0.75, 0.75), // white
            (0.75, 0.75, 0.0),  // yellow
            (0.0, 0.75, 0.75),  // cyan
            (0.0, 0.75, 0.0),   // green
            (0.75, 0.0, 0.75),  // magenta
            (0.75, 0.0, 0.0),   // red
            (0.0, 0.0, 0.75),   // blue
        ]

        let barWidth = rect.width / Double(colors.count)
        for (i, c) in colors.enumerated() {
            let jitter = sin(t * 2.5 + Double(i) * 1.3) * 0.015
            let barRect = CGRect(x: rect.minX + Double(i) * barWidth, y: rect.minY,
                                 width: barWidth + 1, height: rect.height)
            ctx.fill(
                Rectangle().path(in: barRect),
                with: .color(Color(red: c.0 + jitter, green: c.1 + jitter, blue: c.2 + jitter))
            )
        }

        // Subtle crawl line at bottom (test signal artefact)
        let crawlY = rect.maxY - 8
        ctx.fill(
            Rectangle().path(in: CGRect(x: rect.minX, y: crawlY, width: rect.width, height: 6)),
            with: .color(Color(red: 0.1, green: 0.1, blue: 0.1))
        )
    }

    // MARK: - Channel: Static / Snow

    private func drawChannel_Static(ctx: inout GraphicsContext, rect: CGRect, t: Double) {
        let flicker = sin(t * 30) * 0.04
        ctx.fill(Rectangle().path(in: rect),
                 with: .color(Color(red: 0.11 + flicker, green: 0.11 + flicker, blue: 0.12 + flicker)))

        // Noise pixels
        let pixSize = 3.5
        let seed = UInt64(t * 60)
        var rng = SplitMix64(seed: seed)
        let sampleCount = Int(rect.width * rect.height / (pixSize * pixSize) / 3)

        for _ in 0..<sampleCount {
            let px = rect.minX + nextDouble(&rng) * rect.width
            let py = rect.minY + nextDouble(&rng) * rect.height
            let brightness = nextDouble(&rng) * 0.4
            ctx.fill(
                Rectangle().path(in: CGRect(x: px, y: py, width: pixSize, height: pixSize)),
                with: .color(Color.white.opacity(brightness))
            )
        }
    }

    // MARK: - Channel: DVD Screensaver (bouncing logo)

    private func drawChannel_Screensaver(ctx: inout GraphicsContext, rect: CGRect, t: Double) {
        // Deep blue-black background
        ctx.fill(Rectangle().path(in: rect),
                 with: .color(Color(red: 0.015, green: 0.015, blue: 0.09)))

        let logoW = 28.0
        let logoH = 16.0
        let speedX = 42.0
        let speedY = 30.0

        let rangeX = max(rect.width - logoW, 1)
        let rangeY = max(rect.height - logoH, 1)

        func triangleWave(_ val: Double, _ range: Double) -> Double {
            let period = 2.0 * range
            let phase = fmod(abs(val), period)
            return phase < range ? phase : period - phase
        }

        let lx = rect.minX + triangleWave(t * speedX, rangeX)
        let ly = rect.minY + triangleWave(t * speedY + 17, rangeY)

        // Colour changes on bounce
        let bounceX = Int(t * speedX / rangeX)
        let bounceY = Int(t * speedY / rangeY)
        let hues: [Color] = [
            Color(red: 0.75, green: 0.18, blue: 0.18),
            Color(red: 0.18, green: 0.65, blue: 0.18),
            Color(red: 0.25, green: 0.25, blue: 0.85),
            Color(red: 0.75, green: 0.65, blue: 0.1),
            Color(red: 0.65, green: 0.18, blue: 0.65),
            Color(red: 0.18, green: 0.65, blue: 0.65),
        ]
        let logoColor = hues[(bounceX + bounceY) % hues.count]

        // Glow behind logo
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 12))
            l.fill(
                Ellipse().path(in: CGRect(x: lx - 8, y: ly - 8,
                                          width: logoW + 16, height: logoH + 16)),
                with: .color(logoColor.opacity(0.12))
            )
        }

        // The "DVD" logo — rounded rect
        ctx.fill(
            RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: lx, y: ly,
                                                               width: logoW, height: logoH)),
            with: .color(logoColor.opacity(0.85))
        )

        // "DVD" text lines inside
        ctx.fill(
            Rectangle().path(in: CGRect(x: lx + 4, y: ly + logoH * 0.35,
                                        width: logoW - 8, height: 1.5)),
            with: .color(Color.white.opacity(0.35))
        )
        ctx.fill(
            Rectangle().path(in: CGRect(x: lx + 6, y: ly + logoH * 0.55,
                                        width: logoW - 12, height: 1)),
            with: .color(Color.white.opacity(0.2))
        )
    }

    // MARK: - Lava Lamp (on nightstand, left side)

    private func drawLavaLamp(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let lampCx = size.width * 0.33
        let lampTop = size.height * 0.50
        let lampW = size.width * 0.035
        let lampH = size.height * 0.20

        // Base
        ctx.fill(
            RoundedRectangle(cornerRadius: 2).path(in: CGRect(
                x: lampCx - lampW * 0.65, y: lampTop + lampH,
                width: lampW * 1.3, height: 8)),
            with: .color(Color(red: 0.075, green: 0.06, blue: 0.09))
        )
        // Cap
        ctx.fill(
            RoundedRectangle(cornerRadius: 3).path(in: CGRect(
                x: lampCx - lampW * 0.4, y: lampTop - 4,
                width: lampW * 0.8, height: 6)),
            with: .color(Color(red: 0.075, green: 0.06, blue: 0.09))
        )

        // Glass body
        var lampShape = Path()
        lampShape.addEllipse(in: CGRect(x: lampCx - lampW / 2, y: lampTop,
                                         width: lampW, height: lampH))

        ctx.drawLayer { l in
            l.clip(to: lampShape)
            // Inner fill
            l.fill(
                Rectangle().path(in: CGRect(x: lampCx - lampW, y: lampTop,
                                            width: lampW * 2, height: lampH)),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.35, green: 0.05, blue: 0.45).opacity(0.4),
                        Color(red: 0.55, green: 0.08, blue: 0.28).opacity(0.5),
                        Color(red: 0.35, green: 0.05, blue: 0.45).opacity(0.4),
                    ]),
                    startPoint: CGPoint(x: lampCx, y: lampTop),
                    endPoint: CGPoint(x: lampCx, y: lampTop + lampH)
                )
            )

            // Lava blobs
            for blob in lavaBlobs {
                let yFrac = fmod(blob.baseY + t * blob.riseSpeed, 1.0)
                let wander = sin(t * 0.55 + blob.wanderPhase) * lampW * 0.2
                let bx = lampCx + wander
                let by = lampTop + (1.0 - yFrac) * lampH
                let breathe = sin(t * 0.3 + blob.wanderPhase) * 0.3 + 1.0
                let s = blob.size * breathe
                let edgeFade = min(yFrac / 0.15, (1.0 - yFrac) / 0.15, 1.0)

                let w = blob.warmth
                let r = 0.8 + w * 0.4
                let g = 0.1 + w * 0.12
                let b = 0.35 - w * 0.15

                l.drawLayer { bl in
                    bl.addFilter(.blur(radius: s * 0.4))
                    bl.opacity = 0.55 * edgeFade
                    bl.fill(
                        Ellipse().path(in: CGRect(x: bx - s / 2, y: by - s / 2,
                                                  width: s, height: s)),
                        with: .color(Color(red: r, green: g, blue: b))
                    )
                }
            }
        }

        // Outer lamp glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 22))
            let pulse = sin(t * 0.18) * 0.03 + 0.97
            l.fill(
                Ellipse().path(in: CGRect(x: lampCx - lampW * 2, y: lampTop - 8,
                                          width: lampW * 4, height: lampH + 16)),
                with: .color(Color(red: 0.45, green: 0.08, blue: 0.35).opacity(0.05 * pulse))
            )
        }

        // Glass outline
        ctx.stroke(lampShape, with: .color(Color.white.opacity(0.03)), lineWidth: 0.5)
    }

    // MARK: - Alarm Clock (LED digits)

    private func drawClock(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let clockX = size.width * 0.29
        let clockY = size.height * 0.725
        let clockW = 44.0
        let clockH = 20.0

        // Clock body
        ctx.fill(
            RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: clockX, y: clockY,
                                                               width: clockW, height: clockH)),
            with: .color(Color(red: 0.035, green: 0.035, blue: 0.045))
        )

        // LED digits — 12:XX cycling slowly
        let minutes = Int(fmod(t * 0.5, 60))
        let colonBlink = sin(t * 2.0) > 0
        let timeStr = colonBlink
            ? String(format: "12:%02d", minutes)
            : String(format: "12 %02d", minutes)

        let text = Text(timeStr)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(Color(red: 1.0, green: 0.12, blue: 0.08))

        let resolved = ctx.resolve(text)
        let center = CGPoint(x: clockX + clockW / 2, y: clockY + clockH / 2)

        // Red glow behind digits
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 5))
            l.draw(resolved, at: center, anchor: .center)
        }
        // Sharp digits
        ctx.draw(resolved, at: center, anchor: .center)
    }

    // MARK: - Poster on wall

    private func drawPoster(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let px = size.width * 0.30
        let py = size.height * 0.26
        let pw = size.width * 0.10
        let ph = pw * 1.35

        // Poster background
        ctx.fill(
            Rectangle().path(in: CGRect(x: px, y: py, width: pw, height: ph)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.07, green: 0.04, blue: 0.06),
                    Color(red: 0.055, green: 0.03, blue: 0.065),
                ]),
                startPoint: CGPoint(x: px, y: py),
                endPoint: CGPoint(x: px, y: py + ph)
            )
        )

        // Band silhouettes
        for i in 0..<3 {
            let fx = px + pw * (0.22 + Double(i) * 0.24)
            let fy = py + ph * 0.45
            let fw = pw * 0.11
            let fh = ph * 0.35

            ctx.fill(
                RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: fx - fw / 2, y: fy,
                                                                   width: fw, height: fh)),
                with: .color(Color(red: 0.09, green: 0.055, blue: 0.075).opacity(0.7))
            )
            // Head
            ctx.fill(
                Circle().path(in: CGRect(x: fx - fw * 0.35, y: fy - fw * 0.5,
                                         width: fw * 0.7, height: fw * 0.7)),
                with: .color(Color(red: 0.09, green: 0.055, blue: 0.075).opacity(0.65))
            )
        }

        // Band name text line (abstract)
        ctx.fill(
            Rectangle().path(in: CGRect(x: px + pw * 0.15, y: py + ph * 0.10,
                                        width: pw * 0.7, height: 2)),
            with: .color(Color(red: 0.11, green: 0.07, blue: 0.09).opacity(0.5))
        )
        // Smaller text line
        ctx.fill(
            Rectangle().path(in: CGRect(x: px + pw * 0.25, y: py + ph * 0.88,
                                        width: pw * 0.5, height: 1.5)),
            with: .color(Color(red: 0.10, green: 0.06, blue: 0.08).opacity(0.4))
        )
    }

    // MARK: - Bookshelf (right side of room)

    private func drawBookshelf(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let shelfX = size.width * 0.82
        let shelfY = size.height * 0.32
        let shelfW = size.width * 0.11
        let shelfH = size.height * 0.38

        // Back panel
        ctx.fill(
            Rectangle().path(in: CGRect(x: shelfX, y: shelfY, width: shelfW, height: shelfH)),
            with: .color(Color(red: 0.042, green: 0.038, blue: 0.052))
        )

        // Shelf boards
        for i in 0...3 {
            let sy = shelfY + Double(i) * shelfH / 3
            ctx.fill(
                Rectangle().path(in: CGRect(x: shelfX - 2, y: sy, width: shelfW + 4, height: 2.5)),
                with: .color(Color(red: 0.058, green: 0.052, blue: 0.068))
            )
        }

        // Books
        var rng = SplitMix64(seed: 9090)
        for shelf in 0..<3 {
            let baseY = shelfY + Double(shelf) * shelfH / 3 + 3
            let maxH = shelfH / 3 - 6
            var bx = shelfX + 3.0
            while bx < shelfX + shelfW - 5 {
                let bw = 3.5 + nextDouble(&rng) * 5.5
                let bh = maxH * (0.65 + nextDouble(&rng) * 0.35)
                let r = 0.04 + nextDouble(&rng) * 0.05
                let g = 0.03 + nextDouble(&rng) * 0.04
                let b = 0.045 + nextDouble(&rng) * 0.055
                ctx.fill(
                    Rectangle().path(in: CGRect(x: bx, y: baseY + (maxH - bh),
                                                width: bw, height: bh)),
                    with: .color(Color(red: r, green: g, blue: b))
                )
                bx += bw + 0.8
            }
        }
    }

    // MARK: - Nightstand (under lava lamp and clock)

    private func drawNightstand(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let nx = size.width * 0.26
        let ny = size.height * 0.72
        let nw = size.width * 0.12
        let nh = size.height * 0.13

        ctx.fill(
            Rectangle().path(in: CGRect(x: nx, y: ny, width: nw, height: nh)),
            with: .color(Color(red: 0.042, green: 0.038, blue: 0.052))
        )
        // Top surface
        ctx.fill(
            Rectangle().path(in: CGRect(x: nx - 2, y: ny, width: nw + 4, height: 2.5)),
            with: .color(Color(red: 0.058, green: 0.052, blue: 0.065))
        )
        // Drawer handle
        ctx.fill(
            RoundedRectangle(cornerRadius: 1).path(in: CGRect(
                x: nx + nw * 0.35, y: ny + nh * 0.45, width: nw * 0.3, height: 2)),
            with: .color(Color(red: 0.07, green: 0.065, blue: 0.08))
        )
    }

    // MARK: - Bed / blanket (foreground, bottom edge)

    private func drawBed(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let bedTop = size.height * 0.87
        let breathe = sin(t * 0.12) * 1.5

        // Blanket with undulating top edge
        var blanket = Path()
        blanket.move(to: CGPoint(x: 0, y: size.height))
        blanket.addLine(to: CGPoint(x: 0, y: bedTop + 5))

        let steps = 24
        for i in 0...steps {
            let frac = Double(i) / Double(steps)
            let x = frac * size.width
            let wave = sin(frac * .pi * 3.5 + t * 0.08) * 3.5 + breathe * sin(frac * .pi)
            blanket.addLine(to: CGPoint(x: x, y: bedTop + wave))
        }
        blanket.addLine(to: CGPoint(x: size.width, y: size.height))
        blanket.closeSubpath()

        ctx.fill(
            blanket,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.065, green: 0.045, blue: 0.085),
                    Color(red: 0.05, green: 0.035, blue: 0.065),
                    Color(red: 0.04, green: 0.028, blue: 0.05),
                ]),
                startPoint: CGPoint(x: size.width / 2, y: bedTop),
                endPoint: CGPoint(x: size.width / 2, y: size.height)
            )
        )

        // Subtle fold lines
        for i in 0..<3 {
            let foldY = bedTop + 12 + Double(i) * 15
            var fold = Path()
            fold.move(to: CGPoint(x: size.width * 0.05, y: foldY))
            for s in 0...12 {
                let fx = size.width * 0.05 + Double(s) * size.width * 0.075
                let fy = foldY + sin(Double(s) * 0.7 + t * 0.04) * 1.5
                fold.addLine(to: CGPoint(x: fx, y: fy))
            }
            ctx.stroke(fold, with: .color(Color.white.opacity(0.012)), lineWidth: 0.5)
        }
    }
}
