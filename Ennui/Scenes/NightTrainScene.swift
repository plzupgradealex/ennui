import SwiftUI

// A meditative train window view — cycling through weather and time:
// starlit Soviet-era night, rainy afternoon, golden Orient Express sunset,
// snowy dawn. Telegraph poles tick past, villages glow, tea in a
// podstakannik catches the light. Tap the window for condensation bloom.

struct NightTrainScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    private let cycleDuration: Double = 120.0

    struct TelegraphPole {
        let baseOffset: Double
        let height: Double
        let lean: Double
    }

    struct DistantLight {
        let x, y, brightness, flickerRate, flickerPhase: Double
        let r, g, b: Double
    }

    struct TreeCluster {
        let x, y, width, height: Double
        let shade: Double
    }

    struct WindowDrop {
        let id: Int
        let x, y, radius: Double
        let birthPhase: Double
    }

    struct CondensationBloom: Identifiable {
        let id = UUID()
        let x, y, birthTime: Double
    }

    @State private var poles: [TelegraphPole] = []
    @State private var distantLights: [DistantLight] = []
    @State private var trees: [TreeCluster] = []
    @State private var windowDrops: [WindowDrop] = []
    @State private var condensation: [CondensationBloom] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                let phase = weatherPhase(t)
                drawSky(ctx: &ctx, size: size, t: t, phase: phase)
                drawLandscape(ctx: &ctx, size: size, t: t, phase: phase)
                drawTelegraphPoles(ctx: &ctx, size: size, t: t, phase: phase)
                drawDistantVillage(ctx: &ctx, size: size, t: t, phase: phase)
                drawTracks(ctx: &ctx, size: size, t: t, phase: phase)
                drawRain(ctx: &ctx, size: size, t: t, phase: phase)
                drawSnow(ctx: &ctx, size: size, t: t, phase: phase)
                drawWindowFrame(ctx: &ctx, size: size, t: t, phase: phase)
                drawWindowDroplets(ctx: &ctx, size: size, t: t, phase: phase)
                drawCondensation(ctx: &ctx, size: size, t: t, phase: phase)
                drawInteriorReflection(ctx: &ctx, size: size, t: t, phase: phase)
                drawPodstakannik(ctx: &ctx, size: size, t: t, phase: phase)
            }
        }
        .background(Color(red: 0.02, green: 0.02, blue: 0.06))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            condensation.append(CondensationBloom(x: loc.x, y: loc.y, birthTime: t))
            if condensation.count > 8 { condensation.removeFirst() }
        }
    }

    // MARK: - Weather phases (smooth cycling)
    // 0.0-0.25: Starlit night (Soviet sleeper, deep blue-black)
    // 0.25-0.5: Rainy afternoon (grey, drops on glass, green countryside)
    // 0.5-0.75: Golden sunset (Orient Express luxury, amber sky)
    // 0.75-1.0: Snowy dawn (pale lavender, soft flakes, birch trees)

    struct WeatherPhase {
        let night, rain, sunset, snow: Double
        let skyTop, skyBot: (Double, Double, Double)
        let landscapeBase: (Double, Double, Double)
        let ambientWarmth: Double
    }

    private func weatherPhase(_ t: Double) -> WeatherPhase {
        let f = fmod(t / cycleDuration, 1.0)

        func bell(_ center: Double, _ width: Double) -> Double {
            let d = min(abs(f - center), min(abs(f - center + 1.0), abs(f - center - 1.0)))
            return max(0, cos(d / width * .pi * 0.5))
        }

        let night  = bell(0.125,  0.18)
        let rain   = bell(0.375,  0.18)
        let sunset = bell(0.625,  0.18)
        let snow   = bell(0.875,  0.18)
        let total  = max(night + rain + sunset + snow, 0.001)
        let n = night/total, r = rain/total, s = sunset/total, w = snow/total

        let skyTop = (
            0.02*n + 0.30*r + 0.45*s + 0.25*w,
            0.02*n + 0.32*r + 0.22*s + 0.22*w,
            0.08*n + 0.36*r + 0.12*s + 0.35*w
        )
        let skyBot = (
            0.04*n + 0.38*r + 0.85*s + 0.55*w,
            0.03*n + 0.40*r + 0.45*s + 0.45*w,
            0.10*n + 0.42*r + 0.20*s + 0.60*w
        )
        let land = (
            0.03*n + 0.18*r + 0.15*s + 0.40*w,
            0.04*n + 0.25*r + 0.12*s + 0.38*w,
            0.03*n + 0.12*r + 0.06*s + 0.42*w
        )
        let warmth = 0.1*n + 0.2*r + 0.9*s + 0.3*w

        return WeatherPhase(
            night: n, rain: r, sunset: s, snow: w,
            skyTop: skyTop, skyBot: skyBot,
            landscapeBase: land, ambientWarmth: warmth
        )
    }

    private func setup() {
        var rng = SplitMix64(seed: 4488)
        poles = (0..<20).map { i in
            TelegraphPole(
                baseOffset: Double(i) / 20.0 + nextDouble(&rng) * 0.015,
                height: 80 + nextDouble(&rng) * 30,
                lean: (nextDouble(&rng) - 0.5) * 4
            )
        }
        distantLights = (0..<30).map { _ in
            DistantLight(
                x: nextDouble(&rng), y: 0.30 + nextDouble(&rng) * 0.12,
                brightness: 0.3 + nextDouble(&rng) * 0.7,
                flickerRate: 0.5 + nextDouble(&rng) * 3.0,
                flickerPhase: nextDouble(&rng) * .pi * 2,
                r: 0.9 + nextDouble(&rng) * 0.3,
                g: 0.65 + nextDouble(&rng) * 0.25,
                b: 0.2 + nextDouble(&rng) * 0.2
            )
        }
        trees = (0..<45).map { _ in
            TreeCluster(
                x: nextDouble(&rng), y: 0.35 + nextDouble(&rng) * 0.10,
                width: 15 + nextDouble(&rng) * 40,
                height: 25 + nextDouble(&rng) * 50,
                shade: nextDouble(&rng)
            )
        }
        windowDrops = (0..<35).map { i in
            WindowDrop(
                id: i,
                x: nextDouble(&rng), y: nextDouble(&rng),
                radius: 1.5 + nextDouble(&rng) * 3.5,
                birthPhase: nextDouble(&rng)
            )
        }
        ready = true
    }

    // MARK: - Sky

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let st = phase.skyTop, sb = phase.skyBot
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h * 0.52)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: st.0, green: st.1, blue: st.2),
                    Color(red: sb.0, green: sb.1, blue: sb.2),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: h * 0.52)
            )
        )

        // Stars (night phase)
        if phase.night > 0.05 {
            var rng = SplitMix64(seed: 1234)
            for _ in 0..<120 {
                let sx = nextDouble(&rng) * w
                let sy = nextDouble(&rng) * h * 0.42
                let sz = 0.5 + nextDouble(&rng) * 1.8
                let twinkle = sin(t * (0.4 + nextDouble(&rng) * 1.2) + nextDouble(&rng) * 6.28) * 0.3 + 0.7
                let alpha = phase.night * twinkle * (0.3 + nextDouble(&rng) * 0.7)
                let bright = nextDouble(&rng) > 0.85 ? 1.3 : 1.0
                let rect = CGRect(x: sx - sz/2, y: sy - sz/2, width: sz, height: sz)
                ctx.fill(Ellipse().path(in: rect),
                         with: .color(Color(red: bright, green: bright * 0.95, blue: bright * 1.1).opacity(alpha)))
            }
            // Moon
            if phase.night > 0.3 {
                let mx = w * 0.78, my = h * 0.1, mr: Double = 22
                let moonRect = CGRect(x: mx - mr, y: my - mr, width: mr * 2, height: mr * 2)
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 3))
                    l.fill(Ellipse().path(in: moonRect),
                           with: .color(Color(red: 1.2, green: 1.15, blue: 0.95).opacity(phase.night * 0.7)))
                }
                let shadowRect = CGRect(x: mx - mr + 8, y: my - mr - 2, width: mr * 2, height: mr * 2)
                ctx.fill(Ellipse().path(in: shadowRect),
                         with: .color(Color(red: phase.skyTop.0, green: phase.skyTop.1, blue: phase.skyTop.2)))
            }
        }

        // Sunset glow band
        if phase.sunset > 0.1 {
            let bandY = h * 0.35
            let bandH = h * 0.18
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 30))
                l.fill(Path(CGRect(x: 0, y: bandY, width: w, height: bandH)),
                       with: .color(Color(red: 1.4, green: 0.6, blue: 0.2).opacity(phase.sunset * 0.25)))
            }
        }
    }

    // MARK: - Landscape (scrolling parallax)

    private func drawLandscape(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let lb = phase.landscapeBase

        // Distant hills
        var farHill = Path()
        farHill.move(to: CGPoint(x: 0, y: h * 0.50))
        for xi in stride(from: 0.0, through: w, by: 3) {
            let f = (xi + t * 8) / w
            let hill = sin(f * 2.5) * 20 + sin(f * 5.5 + 1.0) * 10 + cos(f * 1.2) * 15
            farHill.addLine(to: CGPoint(x: xi, y: h * 0.42 - hill))
        }
        farHill.addLine(to: CGPoint(x: w, y: h * 0.50))
        farHill.closeSubpath()
        ctx.fill(farHill, with: .color(Color(red: lb.0 * 0.7, green: lb.1 * 0.7, blue: lb.2 * 0.7)))

        // Mid hills
        var midHill = Path()
        midHill.move(to: CGPoint(x: 0, y: h * 0.56))
        for xi in stride(from: 0.0, through: w, by: 3) {
            let f = (xi + t * 22) / w
            let hill = sin(f * 1.8 + 0.5) * 16 + sin(f * 4.2 + 2.0) * 8
            midHill.addLine(to: CGPoint(x: xi, y: h * 0.48 - hill))
        }
        midHill.addLine(to: CGPoint(x: w, y: h * 0.56))
        midHill.closeSubpath()
        ctx.fill(midHill, with: .color(Color(red: lb.0, green: lb.1, blue: lb.2)))

        // Trees (birch/pine style, scrolling)
        for tree in trees {
            let tx = fmod(tree.x * w - t * 22 + w * 10, w * 1.3) - w * 0.15
            let ty = tree.y * h
            let darkFactor = 0.6 + tree.shade * 0.3
            let tr = lb.0 * darkFactor * (1.0 + phase.sunset * 0.3)
            let tg = lb.1 * darkFactor * (1.0 + phase.rain * 0.2)
            let tb = lb.2 * darkFactor * (1.0 + phase.snow * 0.3)
            var treePath = Path()
            treePath.move(to: CGPoint(x: tx, y: ty))
            treePath.addLine(to: CGPoint(x: tx - tree.width * 0.5, y: ty + tree.height))
            treePath.addLine(to: CGPoint(x: tx + tree.width * 0.5, y: ty + tree.height))
            treePath.closeSubpath()
            ctx.fill(treePath, with: .color(Color(red: tr, green: tg, blue: tb)))
        }

        // Near ground
        var ground = Path()
        ground.move(to: CGPoint(x: 0, y: h))
        for xi in stride(from: 0.0, through: w, by: 2) {
            let f = (xi + t * 80) / w
            let bump = sin(f * 12.0) * 3 + sin(f * 5.0 + 0.7) * 6
            ground.addLine(to: CGPoint(x: xi, y: h * 0.60 - bump))
        }
        ground.addLine(to: CGPoint(x: w, y: h))
        ground.closeSubpath()
        ctx.fill(ground, with: .color(Color(red: lb.0 * 1.1, green: lb.1 * 1.1, blue: lb.2 * 0.9)))

        if phase.snow > 0.2 {
            ctx.fill(ground, with: .color(Color.white.opacity(phase.snow * 0.35)))
        }
    }

    // MARK: - Telegraph poles (rhythmic tick-tock)

    private func drawTelegraphPoles(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let spacing = w / 3.5
        let scrollOffset = fmod(t * 80, spacing)

        for i in -1..<5 {
            let baseX = Double(i) * spacing - scrollOffset
            guard baseX > -50 && baseX < w + 50 else { continue }
            let rawPhase = Double(i) + t * 80.0 / spacing + 100.0
            let wrappedPhase = fmod(rawPhase, Double(poles.count))
            let poleIdx = abs(Int(wrappedPhase)) % poles.count
            let pole = poles[poleIdx]

            let bottom = h * 0.60
            let top = bottom - pole.height

            let poleDark = 0.08 + phase.ambientWarmth * 0.06
            var polePath = Path()
            polePath.move(to: CGPoint(x: baseX - 2 + pole.lean * 0.1, y: top))
            polePath.addLine(to: CGPoint(x: baseX + 2 + pole.lean * 0.1, y: top))
            polePath.addLine(to: CGPoint(x: baseX + 3, y: bottom))
            polePath.addLine(to: CGPoint(x: baseX - 3, y: bottom))
            polePath.closeSubpath()
            ctx.fill(polePath, with: .color(Color(red: poleDark, green: poleDark * 0.8, blue: poleDark * 0.6)))

            // Crossbar
            let barY = top + 8
            ctx.fill(Path(CGRect(x: baseX - 14, y: barY, width: 28, height: 2.5)),
                     with: .color(Color(red: poleDark, green: poleDark * 0.8, blue: poleDark * 0.6)))

            // Wires with catenary sag
            if i < 4 {
                let nextX = baseX + spacing
                for wireIdx in 0..<2 {
                    let wireY = barY + Double(wireIdx) * 6
                    var wire = Path()
                    wire.move(to: CGPoint(x: baseX, y: wireY))
                    for s in 1...12 {
                        let frac = Double(s) / 12.0
                        let wx = baseX + (nextX - baseX) * frac
                        let sag = sin(frac * .pi) * 18
                        let windSway = sin(t * 0.3 + frac * 4) * 1.5 * phase.rain
                        wire.addLine(to: CGPoint(x: wx, y: wireY + sag + windSway))
                    }
                    ctx.stroke(wire, with: .color(Color(white: 0.15, opacity: 0.4 + phase.night * 0.2)),
                               lineWidth: 0.6)
                }
            }
        }
    }

    // MARK: - Distant village lights

    private func drawDistantVillage(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let visibility = phase.night * 0.9 + phase.sunset * 0.5 + phase.rain * 0.15
        guard visibility > 0.05 else { return }

        // Hard cores
        for light in distantLights {
            let lx = fmod(light.x * w - t * 8 + w * 20, w * 1.5) - w * 0.25
            let ly = light.y * h
            let flicker = sin(t * light.flickerRate + light.flickerPhase) * 0.15 + 0.85
            let alpha = light.brightness * flicker * visibility
            let hdrMul = phase.night > 0.5 ? 1.25 : 1.0

            let s: Double = 2.5 + light.brightness * 2.0
            let rect = CGRect(x: lx - s/2, y: ly - s/2, width: s, height: s)
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(Color(red: light.r * hdrMul, green: light.g * hdrMul, blue: light.b * hdrMul).opacity(alpha)))
        }

        // Single shared glow layer for all village lights (was up to 20 separate layers)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 6))
            for light in distantLights {
                let lx = fmod(light.x * w - t * 8 + w * 20, w * 1.5) - w * 0.25
                let ly = light.y * h
                let flicker = sin(t * light.flickerRate + light.flickerPhase) * 0.15 + 0.85
                let alpha = light.brightness * flicker * visibility
                let hdrMul = phase.night > 0.5 ? 1.25 : 1.0
                guard alpha > 0.3 else { continue }
                let s: Double = 2.5 + light.brightness * 2.0
                let gs = s * 5
                let glowRect = CGRect(x: lx - gs/2, y: ly - gs/2, width: gs, height: gs)
                l.fill(Ellipse().path(in: glowRect),
                       with: .color(Color(red: light.r * hdrMul, green: light.g * 0.7, blue: light.b * 0.5).opacity(alpha * 0.08)))
            }
        }
    }

    // MARK: - Track bed (sleepers rushing past)

    private func drawTracks(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let trackY = h * 0.62
        let trackH = h * 0.06

        ctx.fill(Path(CGRect(x: 0, y: trackY, width: w, height: trackH)),
                 with: .color(Color(red: 0.22, green: 0.20, blue: 0.18)))

        let sleeperSpacing: Double = 22
        let scrollOffset = fmod(t * 180, sleeperSpacing)
        for i in -1..<Int(w / sleeperSpacing) + 2 {
            let sx = Double(i) * sleeperSpacing - scrollOffset
            ctx.fill(Path(CGRect(x: sx, y: trackY + 2, width: 8, height: trackH - 4)),
                     with: .color(Color(red: 0.14, green: 0.12, blue: 0.10)))
        }

        let railAlpha = 0.4 + phase.ambientWarmth * 0.3
        let railColor = Color(red: 0.5, green: 0.48, blue: 0.44).opacity(railAlpha)
        ctx.fill(Path(CGRect(x: 0, y: trackY + trackH * 0.25, width: w, height: 1.5)), with: .color(railColor))
        ctx.fill(Path(CGRect(x: 0, y: trackY + trackH * 0.70, width: w, height: 1.5)), with: .color(railColor))
    }

    // MARK: - Rain

    private func drawRain(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        guard phase.rain > 0.1 else { return }
        let w = size.width, h = size.height
        var rng = SplitMix64(seed: 7777)
        let count = Int(80.0 * phase.rain)
        for _ in 0..<count {
            let bx = nextDouble(&rng) * w
            let speed = 0.5 + nextDouble(&rng) * 0.3
            let len = 8 + nextDouble(&rng) * 14
            let y = fmod(nextDouble(&rng) + t * speed, 1.0) * h
            let x = bx + sin(t * 0.5) * 3
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - 1.5, y: y + len))
            ctx.stroke(path, with: .color(Color(white: 0.65, opacity: phase.rain * 0.25)), lineWidth: 0.7)
        }
    }

    // MARK: - Snow

    private func drawSnow(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        guard phase.snow > 0.1 else { return }
        let w = size.width, h = size.height
        var rng = SplitMix64(seed: 5555)
        let count = Int(60.0 * phase.snow)
        for _ in 0..<count {
            let bx = nextDouble(&rng) * w
            let speed = 0.08 + nextDouble(&rng) * 0.12
            let s = 1.5 + nextDouble(&rng) * 3.0
            let y = fmod(nextDouble(&rng) + t * speed, 1.0) * h
            let drift = sin(t * 0.4 + nextDouble(&rng) * 6.28) * 15
            let x = bx + drift
            let rect = CGRect(x: x - s/2, y: y - s/2, width: s, height: s)
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(Color.white.opacity(phase.snow * 0.45 * (0.5 + nextDouble(&rng) * 0.5))))
        }
    }

    // MARK: - Window frame (mahogany wood, brass fittings — Orient Express elegance)

    private func drawWindowFrame(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let frameW: Double = 28
        let warmth = phase.ambientWarmth

        let fr = 0.18 + warmth * 0.22
        let fg = 0.10 + warmth * 0.10
        let fb = 0.06 + warmth * 0.04
        let frameColor = Color(red: fr, green: fg, blue: fb)

        // Bottom sill (where the podstakannik sits)
        let sillY = h * 0.70
        ctx.fill(Path(CGRect(x: 0, y: sillY, width: w, height: h - sillY)),
                 with: .color(Color(red: fr * 0.8, green: fg * 0.8, blue: fb * 0.8)))

        ctx.fill(Path(CGRect(x: 0, y: sillY, width: w, height: 2)),
                 with: .color(Color(red: fr * 1.3, green: fg * 1.2, blue: fb * 1.1).opacity(0.5)))

        ctx.fill(Path(CGRect(x: 0, y: 0, width: frameW, height: sillY)), with: .color(frameColor))
        ctx.fill(Path(CGRect(x: w - frameW, y: 0, width: frameW, height: sillY)), with: .color(frameColor))
        ctx.fill(Path(CGRect(x: 0, y: 0, width: w, height: frameW * 0.7)), with: .color(frameColor))

        // Brass corners (HDR warm glow)
        let brassColor = Color(red: 1.2 + warmth * 0.2, green: 0.85, blue: 0.3)
        let cornerSize: Double = 8
        for (cx, cy) in [(frameW, frameW * 0.7), (w - frameW, frameW * 0.7),
                          (frameW, sillY), (w - frameW, sillY)] {
            let rect = CGRect(x: cx - cornerSize/2, y: cy - cornerSize/2,
                             width: cornerSize, height: cornerSize)
            ctx.fill(Ellipse().path(in: rect), with: .color(brassColor.opacity(0.35)))
        }
    }

    // MARK: - Window droplets (rain on glass)

    private func drawWindowDroplets(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        guard phase.rain > 0.15 else { return }
        let w = size.width, h = size.height * 0.70

        // Single shared layer for all window droplets (was 35 separate layers!)
        ctx.drawLayer { l in
            for drop in windowDrops {
                let slideSpeed = 0.02 + drop.radius * 0.008
                let dy = fmod(drop.birthPhase + t * slideSpeed * phase.rain, 1.0)
                let dx = drop.x * w
                let dyPos = dy * h

                let r = drop.radius * (0.8 + phase.rain * 0.4)
                let rect = CGRect(x: dx - r, y: dyPos - r, width: r * 2, height: r * 2.5)

                l.fill(Ellipse().path(in: rect),
                       with: .color(Color.white.opacity(phase.rain * 0.12)))
                let sparkRect = CGRect(x: dx - r * 0.3, y: dyPos - r * 0.4,
                                      width: r * 0.5, height: r * 0.4)
                l.fill(Ellipse().path(in: sparkRect),
                       with: .color(Color(red: 1.2, green: 1.2, blue: 1.3).opacity(phase.rain * 0.2)))
            }
        }
    }

    // MARK: - Tap condensation bloom

    private func drawCondensation(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let active = condensation.filter { t - $0.birthTime < 6.0 }
        guard !active.isEmpty else { return }

        // Single shared blur layer for all condensation blooms (was up to 8 separate layers)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 25))
            for bloom in active {
                let age = t - bloom.birthTime
                let progress = age / 6.0
                let radius = 20 + progress * 80
                let alpha = (1.0 - progress) * 0.25
                let rect = CGRect(x: bloom.x - radius, y: bloom.y - radius,
                                 width: radius * 2, height: radius * 2)
                l.fill(Ellipse().path(in: rect),
                       with: .color(Color.white.opacity(alpha)))
            }
        }
    }

    // MARK: - Interior reflection (warm amber lamp on glass)

    private func drawInteriorReflection(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let reflectAlpha = 0.04 + phase.night * 0.08 + phase.sunset * 0.03

        let breathe = sin(t * 0.15) * 0.3 + 0.7
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            let lampX = w * 0.75, lampY = h * 0.35, lampR: Double = 120
            let rect = CGRect(x: lampX - lampR, y: lampY - lampR, width: lampR * 2, height: lampR * 2)
            l.fill(Ellipse().path(in: rect),
                   with: .color(Color(red: 1.2, green: 0.8, blue: 0.3).opacity(reflectAlpha * breathe)))
        }

        // Curtain edge reflection
        var curtain = Path()
        curtain.move(to: CGPoint(x: 0, y: 0))
        curtain.addLine(to: CGPoint(x: w * 0.08, y: 0))
        curtain.addLine(to: CGPoint(x: w * 0.05, y: h * 0.65))
        curtain.addLine(to: CGPoint(x: 0, y: h * 0.65))
        curtain.closeSubpath()
        ctx.fill(curtain, with: .color(Color(red: 0.5, green: 0.15, blue: 0.12).opacity(reflectAlpha * 0.5)))
    }

    // MARK: - Podstakannik (tea glass in Soviet-style metal holder — heart of the scene)

    private func drawPodstakannik(ctx: inout GraphicsContext, size: CGSize, t: Double, phase: WeatherPhase) {
        let w = size.width, h = size.height
        let cx = w * 0.72
        let baseY = h * 0.72
        let sway = sin(t * 0.8) * 1.2  // gentle rocking with train

        // Saucer
        let saucerRect = CGRect(x: cx - 19 + sway, y: baseY + 22, width: 38, height: 6)
        ctx.fill(Ellipse().path(in: saucerRect),
                 with: .color(Color(red: 0.75, green: 0.72, blue: 0.68)))

        // Holder (ornate metal trapezoid)
        let holderW: Double = 22, holderH: Double = 26
        let hLeft = cx - holderW * 0.5 + sway
        let hRight = cx + holderW * 0.5 + sway
        let holderTop = baseY - holderH + 22.0
        let holderBot = baseY + 22.0
        var holder = Path()
        holder.move(to: CGPoint(x: hLeft - 2, y: holderBot))
        holder.addLine(to: CGPoint(x: hLeft + 1, y: holderTop))
        holder.addLine(to: CGPoint(x: hRight - 1, y: holderTop))
        holder.addLine(to: CGPoint(x: hRight + 2, y: holderBot))
        holder.closeSubpath()
        let metalShine = 0.45 + phase.ambientWarmth * 0.15
        ctx.fill(holder, with: .color(Color(red: metalShine, green: metalShine * 0.85, blue: metalShine * 0.5)))

        // Handle
        let handleX = hRight + 1
        var handle = Path()
        handle.move(to: CGPoint(x: handleX, y: baseY + 6))
        handle.addQuadCurve(to: CGPoint(x: handleX, y: baseY + 18),
                           control: CGPoint(x: handleX + 11, y: baseY + 12))
        ctx.stroke(handle, with: .color(Color(red: metalShine, green: metalShine * 0.85, blue: metalShine * 0.5)),
                   lineWidth: 2)

        // Glass (translucent amber tea)
        let glassW: Double = 16, glassH: Double = 22
        let glassLeft = cx - glassW * 0.5 + sway
        let glassTop = baseY - glassH + 20.0
        let glassRect = CGRect(x: glassLeft, y: glassTop,
                               width: glassW, height: glassH)
        ctx.fill(RoundedRectangle(cornerRadius: 2).path(in: glassRect),
                 with: .color(Color(red: 0.65, green: 0.35, blue: 0.08).opacity(0.5)))

        // Tea surface shimmer
        let teaSurface = CGRect(x: glassLeft + 1, y: glassTop + 1,
                                width: glassW - 2, height: 3)
        let shimmer = sin(t * 1.5) * 0.1 + 0.3
        ctx.fill(Path(teaSurface),
                 with: .color(Color(red: 1.3, green: 0.75, blue: 0.2).opacity(shimmer)))

        // Steam wisps — single shared blur layer (was 3 separate)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 5))
            for i in 0..<3 {
                let steamX = cx + sway + sin(t * 0.6 + Double(i) * 2.1) * 5
                let steamBase = baseY - glassH + 15
                let steamY = steamBase - Double(i) * 8 - fmod(t * 3, 20)
                let steamAlpha = max(0, 0.15 - Double(i) * 0.04 - fmod(t * 0.1, 0.1))
                let steamR: Double = 4 + Double(i) * 3
                let rect = CGRect(x: steamX - steamR, y: steamY - steamR,
                                 width: steamR * 2, height: steamR * 2)
                l.fill(Ellipse().path(in: rect),
                       with: .color(Color.white.opacity(steamAlpha)))
            }
        }

        // Spoon glint
        var spoon = Path()
        spoon.move(to: CGPoint(x: cx + 4 + sway, y: baseY))
        spoon.addLine(to: CGPoint(x: cx + 6 + sway, y: baseY + 16))
        ctx.stroke(spoon, with: .color(Color(red: 0.7, green: 0.68, blue: 0.62).opacity(0.6)),
                   lineWidth: 1)
    }
}
