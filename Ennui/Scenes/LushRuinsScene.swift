import SwiftUI

// Lush Ruins — Sonic-inspired ancient temple ruins in a tropical Indonesian
// jungle. Think Borobudur meets Angel Island Zone. Wet stone terraces draped
// with vines and moss, waterfalls cascading off carved ledges, dense canopy
// with god-rays piercing through, tree roots cracking stone, steam rising
// from hot jungle floor, tropical birds, butterflies, dripping water,
// puddles that shimmer. Everything glistens. The humidity is palpable.
// Tap to send a gust of wind — leaves scatter, water droplets fly, vines sway.

struct LushRuinsScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()
    @State private var ready = false
    @State private var gusts: [(x: Double, y: Double, birth: Double)] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawCanopy(ctx: &ctx, size: size, t: t)
                drawGodRays(ctx: &ctx, size: size, t: t)
                drawDistantTemple(ctx: &ctx, size: size, t: t)
                drawWaterfall(ctx: &ctx, size: size, t: t)
                drawMidgroundRuins(ctx: &ctx, size: size, t: t)
                drawVines(ctx: &ctx, size: size, t: t)
                drawMoss(ctx: &ctx, size: size, t: t)
                drawTreeRoots(ctx: &ctx, size: size, t: t)
                drawForegroundStone(ctx: &ctx, size: size, t: t)
                drawPuddles(ctx: &ctx, size: size, t: t)
                drawSteam(ctx: &ctx, size: size, t: t)
                drawDrips(ctx: &ctx, size: size, t: t)
                drawButterflies(ctx: &ctx, size: size, t: t)
                drawLeafGusts(ctx: &ctx, size: size, t: t)
                drawHumidityHaze(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.02, green: 0.06, blue: 0.03))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear { ready = true }
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            gusts.append((x: loc.x, y: loc.y, birth: Date().timeIntervalSince(startDate)))
            if gusts.count > 8 { gusts.removeFirst() }
        }
    }

    // MARK: - Dense canopy background

    private func drawCanopy(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Deep layered jungle — dark greens with variation
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.01, green: 0.04, blue: 0.02),
                Color(red: 0.02, green: 0.08, blue: 0.04),
                Color(red: 0.03, green: 0.10, blue: 0.05),
                Color(red: 0.02, green: 0.07, blue: 0.03),
            ]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))

        // Canopy leaf clusters at top
        var rng = SplitMix64(seed: 0xCA40A1E)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 25))
            for _ in 0..<30 {
                let x = nextDouble(&rng) * size.width
                let y = nextDouble(&rng) * size.height * 0.35
                let w = 60 + nextDouble(&rng) * 120
                let h = 30 + nextDouble(&rng) * 60
                let g = 0.08 + nextDouble(&rng) * 0.08
                let sway = sin(t * 0.15 + nextDouble(&rng) * 6) * 8
                l.fill(Ellipse().path(in: CGRect(x: x + sway - w / 2, y: y - h / 2, width: w, height: h)),
                    with: .color(Color(red: 0.02, green: g, blue: 0.03).opacity(0.7)))
            }
        }

        // Individual hanging leaves
        for _ in 0..<18 {
            let x = nextDouble(&rng) * size.width
            let y = nextDouble(&rng) * size.height * 0.25 + 10
            let sway = sin(t * (0.2 + nextDouble(&rng) * 0.3) + nextDouble(&rng) * 6) * 6
            let lw = 15 + nextDouble(&rng) * 20
            let lh = 6 + nextDouble(&rng) * 10
            let shade = 0.06 + nextDouble(&rng) * 0.10
            var leaf = Path()
            leaf.move(to: CGPoint(x: x + sway, y: y))
            leaf.addQuadCurve(to: CGPoint(x: x + sway + lw, y: y + lh / 2),
                             control: CGPoint(x: x + sway + lw * 0.5, y: y - lh))
            leaf.addQuadCurve(to: CGPoint(x: x + sway, y: y),
                             control: CGPoint(x: x + sway + lw * 0.5, y: y + lh * 2))
            ctx.fill(leaf, with: .color(Color(red: 0.03, green: shade, blue: 0.02).opacity(0.8)))
        }
    }

    // MARK: - God rays through canopy

    private func drawGodRays(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 30))
            l.opacity = 0.12 + sin(t * 0.05) * 0.03
            var rng = SplitMix64(seed: 0xCA50A1E)
            for _ in 0..<5 {
                let topX = nextDouble(&rng) * size.width
                let spread = 40 + nextDouble(&rng) * 80
                let drift = sin(t * 0.03 + nextDouble(&rng) * 6) * 15
                var ray = Path()
                ray.move(to: CGPoint(x: topX + drift - 5, y: 0))
                ray.addLine(to: CGPoint(x: topX + drift + 5, y: 0))
                ray.addLine(to: CGPoint(x: topX + drift + spread, y: size.height * 0.8))
                ray.addLine(to: CGPoint(x: topX + drift - spread * 0.3, y: size.height * 0.8))
                ray.closeSubpath()
                l.fill(ray, with: .color(Color(red: 1.2, green: 1.1, blue: 0.6)))
            }
        }
    }

    // MARK: - Distant temple (Borobudur silhouette)

    private func drawDistantTemple(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseY = size.height * 0.55
        let cx = size.width * 0.45

        // Stepped pyramid — 5 terraces
        for level in 0..<5 {
            let frac = Double(level) / 5.0
            let w = 180 - frac * 120
            let h = 22.0
            let y = baseY - Double(level) * h
            let shade = 0.08 + frac * 0.03
            ctx.fill(Rectangle().path(in: CGRect(x: cx - w / 2, y: y - h, width: w, height: h)),
                with: .color(Color(red: shade, green: shade + 0.01, blue: shade - 0.01)))
        }

        // Stupa on top
        let stupaY = baseY - 5 * 22 - 14
        ctx.fill(Ellipse().path(in: CGRect(x: cx - 10, y: stupaY - 8, width: 20, height: 12)),
            with: .color(Color(red: 0.10, green: 0.09, blue: 0.08)))
        // Spire
        var spire = Path()
        spire.move(to: CGPoint(x: cx, y: stupaY - 18))
        spire.addLine(to: CGPoint(x: cx - 3, y: stupaY - 6))
        spire.addLine(to: CGPoint(x: cx + 3, y: stupaY - 6))
        spire.closeSubpath()
        ctx.fill(spire, with: .color(Color(red: 0.11, green: 0.10, blue: 0.09)))

        // Carved relief details (small niches)
        var rng = SplitMix64(seed: 0xBDBDBD)
        for level in 0..<4 {
            let frac = Double(level) / 5.0
            let w = 180 - frac * 120
            let y = baseY - Double(level) * 22
            let nicheCount = Int(w / 18)
            for ni in 0..<nicheCount {
                let nx = cx - w / 2 + Double(ni) * 18 + 4
                let ny = y - 18
                let nb = nextDouble(&rng) * 0.02 + 0.06
                ctx.fill(Rectangle().path(in: CGRect(x: nx, y: ny, width: 8, height: 12)),
                    with: .color(Color(red: nb, green: nb + 0.01, blue: nb).opacity(0.6)))
            }
        }
    }

    // MARK: - Waterfall

    private func drawWaterfall(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wfX: Double = size.width * 0.70
        let wfTop: Double = size.height * 0.28
        let wfBot: Double = size.height * 0.70
        let wfW: Double = 25.0

        // Water streams
        drawWaterfallStreams(ctx: &ctx, wfX: wfX, wfTop: wfTop, wfBot: wfBot, wfW: wfW, t: t)

        // Splash at bottom
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 12))
            let splashPulse: Double = sin(t * 2) * 0.05 + 0.15
            let splashRect = CGRect(x: wfX - 30, y: wfBot - 10, width: 60, height: 20)
            l.fill(Ellipse().path(in: splashRect),
                with: .color(Color(red: 0.5, green: 0.8, blue: 1.0).opacity(splashPulse)))
        }

        // Mist spray
        drawWaterfallMist(ctx: &ctx, wfX: wfX, wfBot: wfBot, t: t)
    }

    private func drawWaterfallStreams(ctx: inout GraphicsContext, wfX: Double, wfTop: Double, wfBot: Double, wfW: Double, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 6))
            for i in 0..<8 {
                let xOff: Double = sin(t * (0.5 + Double(i) * 0.2) + Double(i) * 1.3) * 5
                let lineX: Double = wfX + Double(i) * wfW / 8 - wfW / 2 + xOff
                let alpha: Double = 0.15 + sin(t * 0.7 + Double(i)) * 0.05
                var stream = Path()
                stream.move(to: CGPoint(x: lineX, y: wfTop))
                let c1 = CGPoint(x: lineX + 3, y: wfTop + (wfBot - wfTop) * 0.3)
                let c2 = CGPoint(x: lineX + xOff, y: wfTop + (wfBot - wfTop) * 0.7)
                stream.addCurve(to: CGPoint(x: lineX + xOff * 0.5, y: wfBot), control1: c1, control2: c2)
                let waterColor = Color(red: 0.6, green: 0.85, blue: 1.0).opacity(alpha)
                l.stroke(stream, with: .color(waterColor), lineWidth: 2)
            }
        }
    }

    private func drawWaterfallMist(ctx: inout GraphicsContext, wfX: Double, wfBot: Double, t: Double) {
        var rng = SplitMix64(seed: 0x5A1A5B1)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 20))
            for _ in 0..<10 {
                let mx = wfX + (nextDouble(&rng) - 0.5) * 50
                let my = wfBot + (nextDouble(&rng) - 0.5) * 25
                let rise = sin(t * 0.3 + nextDouble(&rng) * 6) * 12 - 8
                let sz = 15 + nextDouble(&rng) * 20
                l.fill(Ellipse().path(in: CGRect(x: mx - sz / 2, y: my + rise - sz / 2, width: sz, height: sz)),
                    with: .color(.white.opacity(0.04)))
            }
        }
    }

    // MARK: - Mid-ground stone ruins

    private func drawMidgroundRuins(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let baseY = size.height * 0.68
        let stoneCol = Color(red: 0.12, green: 0.11, blue: 0.09)
        let wetStone = Color(red: 0.08, green: 0.09, blue: 0.07)

        // Stairs / terraces
        for step in 0..<6 {
            let y = baseY - Double(step) * 14
            let inset = Double(step) * 22
            let w = size.width * 0.6 - inset
            let x = size.width * 0.1 + inset / 2
            ctx.fill(Rectangle().path(in: CGRect(x: x, y: y, width: w, height: 14)),
                with: .color(step % 2 == 0 ? stoneCol : wetStone))
        }

        // Broken columns
        let columns: [(x: Double, h: Double, broken: Bool)] = [
            (0.16, 90, false), (0.26, 65, true), (0.36, 95, false),
            (0.56, 70, true), (0.66, 85, false),
        ]
        for col in columns {
            let cx = col.x * size.width
            let colW = 14.0
            let colH = col.broken ? col.h * 0.6 : col.h
            let colY = baseY - colH
            ctx.fill(Rectangle().path(in: CGRect(x: cx - colW / 2, y: colY, width: colW, height: colH)),
                with: .color(stoneCol))
            // Capital
            if !col.broken {
                ctx.fill(Rectangle().path(in: CGRect(x: cx - colW / 2 - 3, y: colY - 5, width: colW + 6, height: 5)),
                    with: .color(stoneCol))
            }
            // Wet streaks
            for s in 0..<3 {
                let sx = cx - colW / 2 + 2 + Double(s) * 4
                let streakH = colH * (0.3 + sin(t * 0.05 + Double(s)) * 0.1)
                ctx.fill(Rectangle().path(in: CGRect(x: sx, y: colY + colH - streakH, width: 1, height: streakH)),
                    with: .color(Color(red: 0.06, green: 0.08, blue: 0.06).opacity(0.3)))
            }
        }

        // Carved face (Borobudur-style Buddha niche)
        let faceX = size.width * 0.43
        let faceY = baseY - 50
        // Niche frame
        ctx.fill(Rectangle().path(in: CGRect(x: faceX - 14, y: faceY - 20, width: 28, height: 30)),
            with: .color(Color(red: 0.07, green: 0.07, blue: 0.06)))
        // Simple seated figure silhouette
        ctx.fill(Ellipse().path(in: CGRect(x: faceX - 6, y: faceY - 16, width: 12, height: 10)),
            with: .color(Color(red: 0.10, green: 0.09, blue: 0.08)))
        ctx.fill(Rectangle().path(in: CGRect(x: faceX - 8, y: faceY - 8, width: 16, height: 12)),
            with: .color(Color(red: 0.10, green: 0.09, blue: 0.08)))
    }

    // MARK: - Hanging vines

    private func drawVines(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0x71AE5B1)
        let gustEffect = currentGustAt(t: t)

        for _ in 0..<12 {
            let topX = nextDouble(&rng) * size.width
            let topY = nextDouble(&rng) * size.height * 0.25
            let hangLen = 60 + nextDouble(&rng) * 120
            let sway = sin(t * (0.2 + nextDouble(&rng) * 0.2) + nextDouble(&rng) * 6) * 10
            let gustPush = gustEffect.0 * 20

            var vine = Path()
            vine.move(to: CGPoint(x: topX, y: topY))
            vine.addCurve(to: CGPoint(x: topX + sway + gustPush, y: topY + hangLen),
                         control1: CGPoint(x: topX + sway * 0.3 + gustPush * 0.5, y: topY + hangLen * 0.3),
                         control2: CGPoint(x: topX + sway * 0.8 + gustPush * 0.8, y: topY + hangLen * 0.7))
            ctx.stroke(vine, with: .color(Color(red: 0.05, green: 0.14, blue: 0.04).opacity(0.7)), lineWidth: 2)

            // Small leaves along vine
            for li in stride(from: 0.2, through: 0.9, by: 0.2) {
                let lx = topX + sway * li + gustPush * li
                let ly = topY + hangLen * li
                let leafSz = 4 + nextDouble(&rng) * 4
                ctx.fill(Ellipse().path(in: CGRect(x: lx - leafSz / 2, y: ly - leafSz / 3, width: leafSz, height: leafSz * 0.6)),
                    with: .color(Color(red: 0.04, green: 0.16, blue: 0.04).opacity(0.7)))
            }
        }
    }

    // MARK: - Moss on stones

    private func drawMoss(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xA055B05)
        for _ in 0..<20 {
            let x = nextDouble(&rng) * size.width * 0.8 + size.width * 0.1
            let y = size.height * (0.55 + nextDouble(&rng) * 0.2)
            let w = 8 + nextDouble(&rng) * 18
            let h = 4 + nextDouble(&rng) * 8
            let g = 0.15 + nextDouble(&rng) * 0.12
            ctx.fill(Ellipse().path(in: CGRect(x: x, y: y, width: w, height: h)),
                with: .color(Color(red: 0.04, green: g, blue: 0.03).opacity(0.6)))
        }
    }

    // MARK: - Tree roots cracking stone

    private func drawTreeRoots(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let rootColor = Color(red: 0.10, green: 0.07, blue: 0.04)
        // Big root from left
        var r1 = Path()
        r1.move(to: CGPoint(x: 0, y: size.height * 0.45))
        r1.addCurve(to: CGPoint(x: size.width * 0.25, y: size.height * 0.68),
                    control1: CGPoint(x: size.width * 0.08, y: size.height * 0.48),
                    control2: CGPoint(x: size.width * 0.18, y: size.height * 0.62))
        ctx.stroke(r1, with: .color(rootColor), lineWidth: 8)
        // Smaller branching
        var r2 = Path()
        r2.move(to: CGPoint(x: size.width * 0.12, y: size.height * 0.52))
        r2.addQuadCurve(to: CGPoint(x: size.width * 0.2, y: size.height * 0.72),
                       control: CGPoint(x: size.width * 0.22, y: size.height * 0.58))
        ctx.stroke(r2, with: .color(rootColor.opacity(0.8)), lineWidth: 4)
        // Right side root
        var r3 = Path()
        r3.move(to: CGPoint(x: size.width, y: size.height * 0.5))
        r3.addCurve(to: CGPoint(x: size.width * 0.72, y: size.height * 0.70),
                    control1: CGPoint(x: size.width * 0.9, y: size.height * 0.55),
                    control2: CGPoint(x: size.width * 0.78, y: size.height * 0.65))
        ctx.stroke(r3, with: .color(rootColor), lineWidth: 6)
    }

    // MARK: - Foreground stone platform

    private func drawForegroundStone(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let stoneY = size.height * 0.78
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: stoneY, width: size.width, height: size.height - stoneY)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.09, green: 0.08, blue: 0.07),
                Color(red: 0.05, green: 0.06, blue: 0.04),
            ]), startPoint: CGPoint(x: 0, y: stoneY), endPoint: CGPoint(x: 0, y: size.height)))

        // Stone cracks
        var rng = SplitMix64(seed: 0xC4ACB5)
        for _ in 0..<8 {
            let sx = nextDouble(&rng) * size.width
            let sy = stoneY + nextDouble(&rng) * (size.height - stoneY)
            var crack = Path()
            crack.move(to: CGPoint(x: sx, y: sy))
            crack.addLine(to: CGPoint(x: sx + (nextDouble(&rng) - 0.5) * 30, y: sy + nextDouble(&rng) * 15))
            ctx.stroke(crack, with: .color(Color(red: 0.04, green: 0.04, blue: 0.03).opacity(0.4)), lineWidth: 0.8)
        }
    }

    // MARK: - Puddles glistening

    private func drawPuddles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let stoneY = size.height * 0.78
        var rng = SplitMix64(seed: 0xA0DD1E5)
        for _ in 0..<6 {
            let px = nextDouble(&rng) * size.width * 0.8 + size.width * 0.1
            let py = stoneY + 5 + nextDouble(&rng) * (size.height - stoneY - 15)
            let pw = 25 + nextDouble(&rng) * 40
            let ph = 5 + nextDouble(&rng) * 8
            let shimmer = sin(t * 0.6 + nextDouble(&rng) * 6) * 0.1 + 0.2

            // Puddle base
            ctx.fill(Ellipse().path(in: CGRect(x: px, y: py, width: pw, height: ph)),
                with: .color(Color(red: 0.06, green: 0.10, blue: 0.12).opacity(0.5)))

            // Reflection shimmer (sky/foliage)
            ctx.fill(Ellipse().path(in: CGRect(x: px + 2, y: py + 1, width: pw - 4, height: ph - 2)),
                with: .color(Color(red: 0.15, green: 0.35, blue: 0.2).opacity(shimmer)))

            // Specular highlight
            let specX = px + pw * 0.3 + sin(t * 0.2) * 3
            ctx.fill(Ellipse().path(in: CGRect(x: specX, y: py + 1, width: 6, height: 2)),
                with: .color(Color(red: 1.2, green: 1.1, blue: 0.9).opacity(shimmer * 0.3)))
        }
    }

    // MARK: - Rising steam

    private func drawSteam(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 25))
            var rng = SplitMix64(seed: 0x57EA4B1)
            for _ in 0..<8 {
                let bx = nextDouble(&rng) * size.width * 0.7 + size.width * 0.15
                let by = size.height * 0.75
                let phase = nextDouble(&rng) * 100
                let age = fmod(t * 0.15 + phase, 3.0)
                let rise = age * 50
                let drift = sin(t * 0.1 + phase) * 15
                let fade = max(0, 1.0 - age / 3.0)
                let sz = 20 + age * 25
                l.fill(Ellipse().path(in: CGRect(x: bx + drift - sz / 2, y: by - rise - sz / 2, width: sz, height: sz * 0.6)),
                    with: .color(.white.opacity(0.03 * fade)))
            }
        }
    }

    // MARK: - Dripping water from ruins

    private func drawDrips(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xDB1A5B1)
        for _ in 0..<15 {
            let bx = nextDouble(&rng) * size.width * 0.8 + size.width * 0.1
            let startY = size.height * (0.3 + nextDouble(&rng) * 0.3)
            let speed = 80 + nextDouble(&rng) * 60
            let phase = nextDouble(&rng) * 100
            let endY = size.height * 0.78
            let cycle = (endY - startY) / speed + 0.5
            let age = fmod(t + phase, cycle)
            let y = startY + min(age * speed, endY - startY)
            let isFalling = age < (endY - startY) / speed

            if isFalling {
                // Drop
                let s = 2.0
                ctx.fill(Ellipse().path(in: CGRect(x: bx - s / 2, y: y - s, width: s, height: s * 1.5)),
                    with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.3)))
            } else {
                // Splash ring
                let splashAge = age - (endY - startY) / speed
                let radius = splashAge * 20
                let fade = max(0, 1.0 - splashAge / 0.5)
                var ring = Path()
                ring.addEllipse(in: CGRect(x: bx - radius, y: endY - radius * 0.3, width: radius * 2, height: radius * 0.6))
                ctx.stroke(ring, with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(0.15 * fade)), lineWidth: 0.8)
            }
        }
    }

    // MARK: - Butterflies

    private func drawButterflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xBF10EEE)
        let colors: [(Double, Double, Double)] = [
            (0.2, 0.5, 1.0), (1.0, 0.6, 0.1), (0.9, 0.2, 0.5), (0.3, 0.9, 0.4),
        ]
        for i in 0..<6 {
            let bx = nextDouble(&rng) * 0.8 + 0.1
            let by = nextDouble(&rng) * 0.4 + 0.3
            let sp = nextDouble(&rng) * 0.4 + 0.1
            let ph = nextDouble(&rng) * .pi * 2
            let x = (bx + sin(t * sp + ph) * 0.05) * size.width
            let y = (by + cos(t * sp * 0.7 + ph) * 0.03) * size.height
            let wingAngle = sin(t * 4 + ph) * 0.5

            let col = colors[i % colors.count]
            let wingColor = Color(red: col.0, green: col.1, blue: col.2).opacity(0.5)
            let wingW = 5.0, wingH = 3.0 + wingAngle * 2

            // Wings
            ctx.fill(Ellipse().path(in: CGRect(x: x - wingW, y: y - wingH / 2, width: wingW, height: wingH)),
                with: .color(wingColor))
            ctx.fill(Ellipse().path(in: CGRect(x: x, y: y - wingH / 2, width: wingW, height: wingH)),
                with: .color(wingColor))
            // Body
            ctx.fill(Ellipse().path(in: CGRect(x: x - 1, y: y - 1.5, width: 2, height: 3)),
                with: .color(.black.opacity(0.4)))
        }
    }

    // MARK: - Leaf gusts on tap

    private func drawLeafGusts(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let currentT = t
        for gust in gusts {
            let age = currentT - gust.birth
            guard age < 5.5 else { continue }
            let p = age / 5.5

            // Warm god-ray bloom at impact point
            let glowFade = age < 0.3 ? age / 0.3 : max(0, 1.0 - (age - 0.3) / 2.0)
            if glowFade > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 35))
                    let r = 30 + p * 50
                    l.fill(Ellipse().path(in: CGRect(x: gust.x - r, y: gust.y - r * 0.7,
                                                     width: r * 2, height: r * 1.4)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.2, green: 1.1, blue: 0.6).opacity(0.12 * glowFade),
                                .clear
                            ]),
                            center: CGPoint(x: gust.x, y: gust.y),
                            startRadius: 0, endRadius: r))
                }
            }

            // Scattering leaves
            var rng = SplitMix64(seed: UInt64(gust.birth * 1000) & 0xFFFFFF)
            for _ in 0..<24 {
                let angle = nextDouble(&rng) * .pi * 2
                let dist = p * (70 + nextDouble(&rng) * 90)
                let risePhase = nextDouble(&rng) * .pi * 2
                let wobbleAmp = nextDouble(&rng) * 18 + 8
                let fallSpeed = nextDouble(&rng) * 12 + 5
                let sz = 4 + nextDouble(&rng) * 5
                let g = 0.12 + nextDouble(&rng) * 0.18
                let rotation = age * (2 + nextDouble(&rng) * 3) + nextDouble(&rng) * 6
                let lifespan = nextDouble(&rng) * 2.5 + 2.5
                guard age < lifespan else { continue }
                let lp = age / lifespan
                let leafFade = lp < 0.1 ? lp / 0.1 : max(0, 1.0 - (lp - 0.3) / 0.7)

                let lx = gust.x + cos(angle) * dist + sin(age * 0.8 + risePhase) * wobbleAmp
                let ly = gust.y + sin(angle) * dist * 0.5 - (lp < 0.3 ? lp / 0.3 * 25 : 25 - (lp - 0.3) / 0.7 * 25) + (age > 1.0 ? (age - 1.0) * fallSpeed : 0)

                var leaf = Path()
                leaf.move(to: CGPoint(x: lx, y: ly))
                leaf.addQuadCurve(to: CGPoint(x: lx + sz * cos(rotation), y: ly + sz * sin(rotation)),
                                 control: CGPoint(x: lx + sz * 0.5 * cos(rotation + 1), y: ly + sz * 0.5 * sin(rotation + 1) - 3))
                leaf.addQuadCurve(to: CGPoint(x: lx, y: ly),
                                 control: CGPoint(x: lx + sz * 0.5 * cos(rotation - 1), y: ly + sz * 0.5 * sin(rotation - 1) + 3))
                ctx.fill(leaf, with: .color(Color(red: 0.06, green: g, blue: 0.03).opacity(max(0, leafFade) * 0.7)))
            }

            // Water droplets from wet foliage
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 2))
                for _ in 0..<10 {
                    let dAngle = nextDouble(&rng) * .pi * 2
                    let dDist = p * (40 + nextDouble(&rng) * 50)
                    let dRise = nextDouble(&rng) * 20 + 10
                    let lifespan = nextDouble(&rng) * 1.5 + 1.5
                    guard age < lifespan else { continue }
                    let dp = age / lifespan
                    let dFade = dp < 0.1 ? dp / 0.1 : max(0, 1.0 - (dp - 0.1) / 0.9)
                    let dx = gust.x + cos(dAngle) * dDist
                    let dy = gust.y + sin(dAngle) * dDist * 0.5 - dRise * (1.0 - dp) + dp * 15
                    let ds = 1.5 * dFade
                    l.fill(Ellipse().path(in: CGRect(x: dx - ds, y: dy - ds, width: ds * 2, height: ds * 2)),
                        with: .color(Color(red: 0.5, green: 0.7, blue: 0.9).opacity(dFade * 0.35)))
                }
            }
        }
    }

    // MARK: - Humidity haze overlay

    private func drawHumidityHaze(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            l.opacity = 0.06 + sin(t * 0.04) * 0.02
            // Bottom haze
            l.fill(Ellipse().path(in: CGRect(x: -size.width * 0.2, y: size.height * 0.5,
                                              width: size.width * 1.4, height: size.height * 0.6)),
                with: .color(Color(red: 0.4, green: 0.6, blue: 0.5)))
        }
    }

    // MARK: - Gust helper

    private func currentGustAt(t: Double) -> (Double, Double) {
        var totalX = 0.0, totalY = 0.0
        for gust in gusts {
            let age = t - gust.birth
            guard age > 0 && age < 2.5 else { continue }
            let strength = max(0, 1.0 - age / 2.5)
            totalX += strength * 0.5
            totalY -= strength * 0.2
        }
        return (totalX, totalY)
    }
}
