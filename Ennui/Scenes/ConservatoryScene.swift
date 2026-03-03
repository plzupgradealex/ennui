import SwiftUI

struct ConservatoryScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    struct PalmData {
        let x, height, curve, phase: Double
        let fronds: Int
    }
    struct FernData {
        let x, y, spread, phase: Double
        let fronds: Int
    }
    struct IvyStrand {
        let x, anchorY, length, phase: Double
    }
    struct RainStreak {
        let x, speed, phase: Double
    }
    struct SteamPuff {
        let x, birth: Double
        let seed: UInt64
    }

    @State private var palms: [PalmData] = []
    @State private var ferns: [FernData] = []
    @State private var ivy: [IvyStrand] = []
    @State private var rain: [RainStreak] = []
    @State private var steamPuffs: [SteamPuff] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawGlassStructure(ctx: &ctx, size: size, t: t)
                drawRainOnGlass(ctx: &ctx, size: size, t: t)
                drawWarmGlow(ctx: &ctx, size: size, t: t)
                drawFloor(ctx: &ctx, size: size, t: t)
                drawPalms(ctx: &ctx, size: size, t: t)
                drawFerns(ctx: &ctx, size: size, t: t)
                drawIvy(ctx: &ctx, size: size, t: t)
                drawMist(ctx: &ctx, size: size, t: t)
                drawSteamPuffs(ctx: &ctx, size: size, t: t)
                drawCondensation(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.02, green: 0.03, blue: 0.02))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            steamPuffs.append(SteamPuff(x: loc.x, birth: t, seed: UInt64(t * 1000) & 0xFFFFFF))
            if steamPuffs.count > 6 { steamPuffs.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 1882) // Kew Gardens Temperate House era

        palms = (0..<4).map { _ in
            PalmData(
                x: Double.random(in: 0.12...0.88, using: &rng),
                height: Double.random(in: 0.28...0.48, using: &rng),
                curve: Double.random(in: -0.02...0.02, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng),
                fronds: Int.random(in: 7...11, using: &rng)
            )
        }

        ferns = (0..<10).map { _ in
            FernData(
                x: Double.random(in: 0.05...0.95, using: &rng),
                y: Double.random(in: 0.60...0.78, using: &rng),
                spread: Double.random(in: 0.04...0.09, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng),
                fronds: Int.random(in: 5...8, using: &rng)
            )
        }

        ivy = (0..<6).map { _ in
            IvyStrand(
                x: Double.random(in: 0.1...0.9, using: &rng),
                anchorY: Double.random(in: 0.08...0.22, using: &rng),
                length: Double.random(in: 0.06...0.15, using: &rng),
                phase: Double.random(in: 0...(.pi * 2), using: &rng)
            )
        }

        rain = (0..<50).map { _ in
            RainStreak(
                x: Double.random(in: 0...1, using: &rng),
                speed: Double.random(in: 0.12...0.35, using: &rng),
                phase: Double.random(in: 0...1, using: &rng)
            )
        }

        ready = true
    }

    // MARK: - Background

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = sin(t * 0.08) * 0.01
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.03, green: 0.05 + w, blue: 0.07),
                Color(red: 0.04, green: 0.06, blue: 0.05),
                Color(red: 0.05 + w, green: 0.07, blue: 0.04),
                Color(red: 0.04, green: 0.06, blue: 0.03),
                Color(red: 0.03, green: 0.04, blue: 0.02),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    // MARK: - Iron and glass framework

    private func archY(at xFrac: Double, size: CGSize) -> Double {
        let wallY = size.height * 0.45
        let peakY = size.height * 0.05
        let centered = (xFrac - 0.5) * 2.0
        return peakY + (wallY - peakY) * centered * centered
    }

    private func drawGlassStructure(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let ironColor = Color(red: 0.15, green: 0.13, blue: 0.10)

        // Main arch outline
        var archPath = Path()
        archPath.move(to: CGPoint(x: 0, y: size.height * 0.45))
        for i in 0...40 {
            let frac = Double(i) / 40.0
            archPath.addLine(to: CGPoint(x: frac * size.width, y: archY(at: frac, size: size)))
        }
        ctx.stroke(archPath, with: .color(ironColor.opacity(0.5)), lineWidth: 3)

        // Inner arch line
        var innerArch = Path()
        for i in 0...40 {
            let frac = Double(i) / 40.0
            let pt = CGPoint(x: frac * size.width, y: archY(at: frac, size: size) + 15)
            if i == 0 { innerArch.move(to: pt) } else { innerArch.addLine(to: pt) }
        }
        ctx.stroke(innerArch, with: .color(ironColor.opacity(0.3)), lineWidth: 1.5)

        // Vertical mullions
        let mullionCount = 9
        for i in 1..<mullionCount {
            let frac = Double(i) / Double(mullionCount)
            var bar = Path()
            bar.move(to: CGPoint(x: frac * size.width, y: archY(at: frac, size: size)))
            bar.addLine(to: CGPoint(x: frac * size.width, y: size.height * 0.45))
            ctx.stroke(bar, with: .color(ironColor.opacity(0.35)), lineWidth: 2)
        }

        // Horizontal ribs
        for band in 1...2 {
            let bandFrac = Double(band) / 3.0
            var ribPath = Path()
            for i in 0...40 {
                let frac = Double(i) / 40.0
                let fullY = archY(at: frac, size: size)
                let y = fullY + (size.height * 0.45 - fullY) * bandFrac
                let pt = CGPoint(x: frac * size.width, y: y)
                if i == 0 { ribPath.move(to: pt) } else { ribPath.addLine(to: pt) }
            }
            ctx.stroke(ribPath, with: .color(ironColor.opacity(0.25)), lineWidth: 1)
        }

        // Faint glass highlights on panes
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 20))
            l.opacity = 0.04
            let glassHighlight = Color(red: 0.2, green: 0.35, blue: 0.3)
            for i in 0..<mullionCount {
                let frac = (Double(i) + 0.5) / Double(mullionCount)
                let topY = archY(at: frac, size: size) + 10
                let paneH = size.height * 0.45 - topY
                let midY = (topY + size.height * 0.45) / 2
                let pw = size.width / Double(mullionCount) * 0.6
                let rect = CGRect(x: frac * size.width - pw / 2, y: midY - paneH * 0.3,
                                  width: pw, height: paneH * 0.6)
                l.fill(Ellipse().path(in: rect), with: .color(glassHighlight))
            }
        }
    }

    // MARK: - Rain streaks on glass

    private func drawRainOnGlass(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let maxY = size.height * 0.45

        for r in rain {
            let yProgress = fmod(r.phase + t * r.speed, 1.0)
            let topY = archY(at: r.x, size: size)
            let glassH = maxY - topY
            guard glassH > 10 else { continue }

            let y1 = topY + yProgress * glassH
            let streakLen = min(glassH * 0.08, 15.0)
            let waver = sin(t * 0.4 + r.phase * 20) * 2
            let x = r.x * size.width + waver
            let edgeFade = min(yProgress / 0.1, (1.0 - yProgress) / 0.15, 1.0)

            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y1))
            streak.addLine(to: CGPoint(x: x + 0.5, y: y1 + streakLen))
            ctx.stroke(streak, with: .color(
                Color(red: 0.4, green: 0.55, blue: 0.6).opacity(0.18 * edgeFade)),
                lineWidth: 1)
        }
    }

    // MARK: - Warm glow from Edison bulbs

    private func drawWarmGlow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let bulbPositions: [(x: Double, y: Double)] = [
            (0.25, 0.30), (0.50, 0.22), (0.75, 0.30)
        ]

        // Large warm glow halos
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: max(size.width, size.height) * 0.12))
            for (i, bp) in bulbPositions.enumerated() {
                let pulse = sin(t * 0.12 + Double(i) * 1.5) * 0.06 + 0.94
                let cx = bp.x * size.width
                let cy = bp.y * size.height
                let r = size.height * 0.35 * pulse
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                l.fill(Ellipse().path(in: rect), with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 1.3, green: 0.7, blue: 0.25).opacity(0.12 * pulse),
                        Color(red: 1.0, green: 0.5, blue: 0.15).opacity(0.05 * pulse),
                        Color.clear,
                    ]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: r
                ))
            }
        }

        // Small bright bulb cores
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            for (i, bp) in bulbPositions.enumerated() {
                let pulse = sin(t * 0.12 + Double(i) * 1.5) * 0.08 + 0.92
                let cx = bp.x * size.width
                let cy = bp.y * size.height
                let s = 4.0 * pulse
                l.fill(Ellipse().path(in: CGRect(x: cx - s, y: cy - s, width: s * 2, height: s * 2)),
                    with: .color(Color(red: 1.5, green: 1.0, blue: 0.5).opacity(0.25 * pulse)))
            }
        }
    }

    // MARK: - Floor

    private func drawFloor(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let floorY = size.height * 0.78
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: floorY, width: size.width, height: size.height - floorY)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.06, green: 0.05, blue: 0.03),
                Color(red: 0.04, green: 0.035, blue: 0.02),
                Color(red: 0.03, green: 0.025, blue: 0.015),
            ]), startPoint: CGPoint(x: 0, y: floorY),
                endPoint: CGPoint(x: 0, y: size.height)))

        // Warm light puddles on floor from bulbs
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            let bulbXs = [0.25, 0.50, 0.75]
            for (i, bx) in bulbXs.enumerated() {
                let pulse = sin(t * 0.12 + Double(i) * 1.5) * 0.05 + 0.95
                let cx = bx * size.width
                let rw = size.width * 0.15
                let rh = size.height * 0.08
                l.fill(Ellipse().path(in: CGRect(x: cx - rw, y: floorY - rh * 0.3,
                                                  width: rw * 2, height: rh * 2)),
                    with: .color(Color(red: 0.9, green: 0.5, blue: 0.15).opacity(0.04 * pulse)))
            }
        }
    }

    // MARK: - Palms (back row, silhouetted against glass)

    private func drawPalms(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let groundY = size.height * 0.78

        for palm in palms {
            let bx = palm.x * size.width
            let topY = groundY - palm.height * size.height
            let sway = sin(t * 0.15 + palm.phase) * size.width * 0.008

            // Trunk
            var trunk = Path()
            trunk.move(to: CGPoint(x: bx, y: groundY))
            for s in 1...20 {
                let frac = Double(s) / 20.0
                let x = bx + palm.curve * size.width * sin(frac * .pi) + sway * frac
                let y = groundY - (groundY - topY) * frac
                trunk.addLine(to: CGPoint(x: x, y: y))
            }
            ctx.stroke(trunk, with: .color(
                Color(red: 0.08, green: 0.06, blue: 0.04).opacity(0.7)), lineWidth: 4)

            // Fronds
            let topX = bx + palm.curve * size.width * sin(.pi) + sway
            for fi in 0..<palm.fronds {
                let angle = Double(fi) / Double(palm.fronds) * .pi * 1.2 - .pi * 0.6
                let frondSway = sin(t * 0.2 + palm.phase + Double(fi) * 0.8) * 0.05
                let frondLen = size.height * 0.12 * (0.8 + 0.4 * sin(Double(fi) * 0.7))
                let endX = topX + cos(angle + frondSway) * frondLen
                let endY = topY + sin(angle + frondSway) * frondLen * 0.5 + frondLen * 0.3

                var frond = Path()
                frond.move(to: CGPoint(x: topX, y: topY))
                frond.addQuadCurve(
                    to: CGPoint(x: endX, y: endY),
                    control: CGPoint(x: (topX + endX) / 2 + cos(angle) * frondLen * 0.2,
                                     y: (topY + endY) / 2 - frondLen * 0.1))

                let darkness = 0.10 + sin(Double(fi) * 1.3) * 0.03
                ctx.stroke(frond, with: .color(
                    Color(red: darkness, green: darkness + 0.04, blue: darkness - 0.02).opacity(0.6)),
                    lineWidth: 2)

                // Leaflets along frond
                for li in 1...6 {
                    let lFrac = Double(li) / 7.0
                    let lx = topX + (endX - topX) * lFrac
                    let ly = topY + (endY - topY) * lFrac
                    let lLen = frondLen * 0.15 * (1.0 - lFrac * 0.3)
                    let side: Double = li % 2 == 0 ? 1 : -1
                    let perpAngle = angle + .pi / 2

                    var leaflet = Path()
                    leaflet.move(to: CGPoint(x: lx, y: ly))
                    leaflet.addLine(to: CGPoint(
                        x: lx + cos(perpAngle) * lLen * side,
                        y: ly + sin(perpAngle) * lLen * 0.3 * side + lLen * 0.4))
                    ctx.stroke(leaflet, with: .color(
                        Color(red: darkness, green: darkness + 0.05, blue: darkness - 0.02).opacity(0.4)),
                        lineWidth: 1)
                }
            }
        }
    }

    // MARK: - Ferns (mid-ground, lush clusters)

    private func drawFerns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for fern in ferns {
            let cx = fern.x * size.width
            let cy = fern.y * size.height
            let spread = fern.spread * size.width

            for fi in 0..<fern.fronds {
                let angle = Double(fi) / Double(fern.fronds) * .pi - .pi / 2
                let sway = sin(t * 0.25 + fern.phase + Double(fi) * 0.6) * 0.04
                let len = spread * (0.7 + 0.6 * abs(sin(Double(fi) * 1.2)))

                let endX = cx + cos(angle + sway) * len
                let endY = cy + sin(angle + sway) * len * 0.4 - len * 0.2

                var stem = Path()
                stem.move(to: CGPoint(x: cx, y: cy))
                stem.addQuadCurve(
                    to: CGPoint(x: endX, y: endY),
                    control: CGPoint(x: (cx + endX) / 2, y: (cy + endY) / 2 - len * 0.15))

                let g = 0.22 + sin(fern.phase + Double(fi)) * 0.05
                ctx.stroke(stem, with: .color(
                    Color(hue: 0.33, saturation: 0.55, brightness: g).opacity(0.5)),
                    lineWidth: 1.5)

                // Pinnae along each frond
                for pi in 1...5 {
                    let pFrac = Double(pi) / 6.0
                    let px = cx + (endX - cx) * pFrac
                    let py = cy + (endY - cy) * pFrac
                    let pLen = len * 0.12 * (1.0 - pFrac * 0.4)
                    let side: Double = pi % 2 == 0 ? 1 : -1

                    var pinna = Path()
                    pinna.move(to: CGPoint(x: px, y: py))
                    pinna.addLine(to: CGPoint(x: px + side * pLen, y: py - pLen * 0.5))
                    ctx.stroke(pinna, with: .color(
                        Color(hue: 0.35, saturation: 0.5, brightness: g + 0.05).opacity(0.35)),
                        lineWidth: 1)
                }
            }
        }

        // Warm light catching fern tips
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 6))
            for fern in ferns {
                let cx = fern.x * size.width
                let cy = fern.y * size.height
                let breathe = sin(t * 0.18 + fern.phase) * 0.12 + 0.88
                let s = 10.0
                l.fill(Ellipse().path(in: CGRect(x: cx - s, y: cy - s * 1.5, width: s * 2, height: s * 2)),
                    with: .color(Color(hue: 0.33, saturation: 0.4, brightness: 1.2).opacity(0.06 * breathe)))
            }
        }
    }

    // MARK: - Ivy trailing from framework

    private func drawIvy(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for strand in ivy {
            let ax = strand.x * size.width
            let ay = strand.anchorY * size.height
            let len = strand.length * size.height

            var vine = Path()
            vine.move(to: CGPoint(x: ax, y: ay))
            for si in 1...12 {
                let frac = Double(si) / 12.0
                let sw = sin(t * 0.2 + strand.phase + frac * 3) * 8 * frac
                let vx = ax + sw
                let vy = ay + len * frac
                vine.addLine(to: CGPoint(x: vx, y: vy))

                // Small leaves at alternating intervals
                if si % 2 == 0 {
                    let leafSize = 3.0 + (1.0 - frac) * 2
                    let side: Double = si % 4 == 0 ? 1 : -1
                    let lx = vx + side * leafSize * 1.5

                    var leaf = Path()
                    leaf.move(to: CGPoint(x: vx, y: vy))
                    leaf.addQuadCurve(
                        to: CGPoint(x: lx, y: vy + leafSize * 0.5),
                        control: CGPoint(x: (vx + lx) / 2, y: vy - leafSize * 0.3))
                    ctx.stroke(leaf, with: .color(
                        Color(hue: 0.35, saturation: 0.45, brightness: 0.20).opacity(0.4)),
                        lineWidth: 1)
                }
            }
            ctx.stroke(vine, with: .color(
                Color(hue: 0.30, saturation: 0.5, brightness: 0.15).opacity(0.4)),
                lineWidth: 1)
        }
    }

    // MARK: - Mist and steam

    private func drawMist(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Upper drifting mist
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            for i in 0..<5 {
                let x = fmod(Double(i) * size.width * 0.25 + t * 3 + 200, size.width + 300) - 150
                let y = size.height * (0.50 + Double(i) * 0.06) + sin(t * 0.06 + Double(i) * 1.2) * 15
                let w = 180.0 + Double(i) * 20
                let h = 25.0 + Double(i) * 5
                let breathe = sin(t * 0.05 + Double(i)) * 0.03 + 0.07
                l.fill(Ellipse().path(in: CGRect(x: x, y: y, width: w, height: h)),
                    with: .color(Color(red: 0.35, green: 0.45, blue: 0.35).opacity(breathe)))
            }
        }

        // Warm ground-level steam
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 35))
            for i in 0..<3 {
                let x = fmod(Double(i) * size.width * 0.35 + t * 1.5 + 100, size.width + 200) - 100
                let y = size.height * 0.72 + sin(t * 0.04 + Double(i) * 2) * 10
                let breathe = sin(t * 0.1 + Double(i) * 1.5) * 0.02 + 0.05
                l.fill(Ellipse().path(in: CGRect(x: x, y: y, width: 140, height: 20)),
                    with: .color(Color(red: 0.5, green: 0.4, blue: 0.25).opacity(breathe)))
            }
        }
    }

    // MARK: - Tap steam puffs

    private func drawSteamPuffs(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for puff in steamPuffs {
            let age = t - puff.birth
            guard age >= 0 && age < 6.0 else { continue }
            let p = age / 6.0

            // Warm light bloom at origin
            let glowFade = age < 0.4 ? age / 0.4 : max(0, 1.0 - (age - 0.4) / 2.5)
            if glowFade > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 35))
                    let r = 30 + p * 50
                    l.fill(Ellipse().path(in: CGRect(x: puff.x - r, y: size.height * 0.6 - r * 0.5,
                                                     width: r * 2, height: r)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.2, green: 1.0, blue: 0.6).opacity(0.10 * glowFade),
                                Color(red: 0.8, green: 0.7, blue: 0.4).opacity(0.04 * glowFade),
                                .clear
                            ]),
                            center: CGPoint(x: puff.x, y: size.height * 0.6),
                            startRadius: 0, endRadius: r))
                }
            }

            // Multiple rising steam wisps
            var rng = SplitMix64(seed: puff.seed)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 20))
                for _ in 0..<8 {
                    let xOff = (nextDouble(&rng) - 0.5) * 40
                    let riseSpeed = nextDouble(&rng) * 0.12 + 0.10
                    let driftPhase = nextDouble(&rng) * .pi * 2
                    let driftAmp = nextDouble(&rng) * 25 + 10
                    let sz = nextDouble(&rng) * 25 + 15
                    let lifespan = nextDouble(&rng) * 2.5 + 3.0
                    guard age < lifespan else { continue }
                    let wp = age / lifespan
                    let wispFade = wp < 0.15 ? wp / 0.15 : max(0, 1.0 - (wp - 0.15) / 0.85)
                    let rise = age * riseSpeed * size.height
                    let drift = sin(age * 0.5 + driftPhase) * driftAmp
                    let cx = puff.x + xOff + drift
                    let cy = size.height * 0.65 - rise
                    let spread = sz + wp * 30

                    l.fill(Ellipse().path(in: CGRect(x: cx - spread, y: cy - spread * 0.4,
                                                      width: spread * 2, height: spread * 0.8)),
                        with: .color(Color(red: 0.55, green: 0.55, blue: 0.45).opacity(0.12 * wispFade)))
                }
            }

            // Condensation droplets cascading down glass
            ctx.drawLayer { l in
                for _ in 0..<10 {
                    let dx = puff.x + (nextDouble(&rng) - 0.5) * 80
                    let delay = nextDouble(&rng) * 1.5
                    let dropAge = age - delay
                    guard dropAge > 0 else { continue }
                    let speed = nextDouble(&rng) * 30 + 20
                    let lifespan = nextDouble(&rng) * 1.5 + 2.0
                    guard dropAge < lifespan else { continue }
                    let dp = dropAge / lifespan
                    let dropFade = dp < 0.1 ? dp / 0.1 : max(0, 1.0 - (dp - 0.5) / 0.5)
                    let dy = size.height * 0.15 + dropAge * speed
                    // Small elongated drop
                    l.fill(Ellipse().path(in: CGRect(x: dx - 1, y: dy - 2, width: 2, height: 4)),
                        with: .color(Color(red: 0.6, green: 0.7, blue: 0.65).opacity(0.25 * dropFade)))
                    // Tiny trail
                    if dropAge > 0.3 {
                        let trailLen = min(dropAge * 5, 12.0)
                        l.fill(Ellipse().path(in: CGRect(x: dx - 0.5, y: dy - trailLen - 2, width: 1, height: trailLen)),
                            with: .color(Color(red: 0.5, green: 0.6, blue: 0.55).opacity(0.10 * dropFade)))
                    }
                }
            }
        }
    }

    // MARK: - Condensation haze on glass

    private func drawCondensation(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 80))
            l.opacity = 0.05 + sin(t * 0.03) * 0.01
            let cx = size.width * 0.5
            let cy = size.height * 0.2
            let r = size.width * 0.4
            l.fill(Ellipse().path(in: CGRect(x: cx - r, y: cy - r * 0.6, width: r * 2, height: r * 1.2)),
                with: .color(Color(red: 0.3, green: 0.4, blue: 0.35)))
        }
    }
}
