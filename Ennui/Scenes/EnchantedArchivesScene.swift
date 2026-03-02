import SwiftUI

// Enchanted Archives — The Forgotten Library's wilder sibling.
// Where the Forgotten Library is hushed reverence, this is raw magic unleashed.
// The shelves are alive — books breathe, pages flutter out on their own,
// forming origami birds that soar through vast cathedral spaces. Ink runs
// like rivers along the floor, forming fractal patterns. Constellations of
// golden glyphs orbit in slow galaxies. Lightning flickers between shelves.
// The architecture shifts — staircases that lead sideways, Escher-like arches.
// Massive stained-glass rosette windows cast kaleidoscopic light pools.
// Tap to summon a lightning arc between shelves that illuminates everything
// in a flash, sending a flock of paper birds scattering.

struct EnchantedArchivesScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()
    @State private var ready = false
    @State private var lightningStrikes: [(x: Double, birth: Double)] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawVoid(ctx: &ctx, size: size, t: t)
                drawRosette(ctx: &ctx, size: size, t: t)
                drawArches(ctx: &ctx, size: size, t: t)
                drawShelves(ctx: &ctx, size: size, t: t)
                drawInkRivers(ctx: &ctx, size: size, t: t)
                drawFloatingBooks(ctx: &ctx, size: size, t: t)
                drawPaperBirds(ctx: &ctx, size: size, t: t)
                drawGlyphGalaxies(ctx: &ctx, size: size, t: t)
                drawLightning(ctx: &ctx, size: size, t: t)
                drawLightningFlash(ctx: &ctx, size: size, t: t)
                drawCandlelight(ctx: &ctx, size: size, t: t)
                drawDustAndEmbers(ctx: &ctx, size: size, t: t)
                drawStainedGlassLight(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear { ready = true }
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            lightningStrikes.append((x: loc.x, birth: Date().timeIntervalSince(startDate)))
            if lightningStrikes.count > 4 { lightningStrikes.removeFirst() }
        }
    }

    // MARK: - Infinite void background

    private func drawVoid(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let breathe = sin(t * 0.03) * 0.01
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: 0.02 + breathe, green: 0.01, blue: 0.04 + breathe),
                Color(red: 0.04, green: 0.02 + breathe, blue: 0.08),
                Color(red: 0.03, green: 0.02, blue: 0.06),
                Color(red: 0.01, green: 0.01, blue: 0.03),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
    }

    // MARK: - Stained glass rosette windows

    private func drawRosette(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let windows: [(x: Double, y: Double, r: Double)] = [
            (0.2, 0.15, 65), (0.75, 0.12, 55),
        ]

        for win in windows {
            let cx = win.x * size.width
            let cy = win.y * size.height
            let r = win.r

            // Frame
            ctx.stroke(Ellipse().path(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.15, green: 0.12, blue: 0.08).opacity(0.5)), lineWidth: 4)

            // Kaleidoscopic wedges
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 8))
                let segments = 12
                let rosetteColors: [(Double, Double, Double)] = [
                    (0.8, 0.2, 0.2), (0.2, 0.4, 0.9), (0.9, 0.7, 0.1),
                    (0.3, 0.8, 0.3), (0.7, 0.2, 0.8), (0.9, 0.4, 0.1),
                ]
                for i in 0..<segments {
                    let angle = (Double(i) / Double(segments)) * .pi * 2 + t * 0.02
                    let nextAngle = angle + .pi * 2 / Double(segments)
                    let col = rosetteColors[i % rosetteColors.count]
                    let glow = sin(t * 0.3 + Double(i) * 0.8) * 0.15 + 0.25

                    var wedge = Path()
                    wedge.move(to: CGPoint(x: cx, y: cy))
                    wedge.addLine(to: CGPoint(x: cx + cos(angle) * r * 0.9, y: cy + sin(angle) * r * 0.9))
                    wedge.addLine(to: CGPoint(x: cx + cos(nextAngle) * r * 0.9, y: cy + sin(nextAngle) * r * 0.9))
                    wedge.closeSubpath()
                    l.fill(wedge, with: .color(Color(red: col.0, green: col.1, blue: col.2).opacity(glow)))
                }
            }
        }
    }

    // MARK: - Gothic arches (Escher-like)

    private func drawArches(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let archColor = Color(red: 0.10, green: 0.08, blue: 0.06)

        // Main arches
        for i in 0..<5 {
            let cx = size.width * (0.1 + Double(i) * 0.2)
            let baseY = size.height * 0.9
            let archW = 60 + sin(t * 0.02 + Double(i)) * 5
            let archH = 200 + Double(i) * 15

            // Columns
            ctx.fill(Rectangle().path(in: CGRect(x: cx - archW / 2 - 6, y: baseY - archH, width: 6, height: archH)),
                with: .color(archColor))
            ctx.fill(Rectangle().path(in: CGRect(x: cx + archW / 2, y: baseY - archH, width: 6, height: archH)),
                with: .color(archColor))

            // Pointed arch
            var arch = Path()
            arch.move(to: CGPoint(x: cx - archW / 2, y: baseY - archH))
            arch.addQuadCurve(to: CGPoint(x: cx, y: baseY - archH - 40),
                             control: CGPoint(x: cx - archW / 4, y: baseY - archH - 50))
            arch.addQuadCurve(to: CGPoint(x: cx + archW / 2, y: baseY - archH),
                             control: CGPoint(x: cx + archW / 4, y: baseY - archH - 50))
            ctx.stroke(arch, with: .color(archColor.opacity(0.7)), lineWidth: 4)

            // Depth recession: smaller arches behind
            for d in 1...2 {
                let scale = 1.0 - Double(d) * 0.25
                let fade = 0.3 - Double(d) * 0.1
                let dx = cx + Double(d) * 3
                let dw = archW * scale
                let dh = archH * scale
                ctx.fill(Rectangle().path(in: CGRect(x: dx - dw / 2 - 3, y: baseY - dh, width: 3, height: dh)),
                    with: .color(archColor.opacity(fade)))
                ctx.fill(Rectangle().path(in: CGRect(x: dx + dw / 2, y: baseY - dh, width: 3, height: dh)),
                    with: .color(archColor.opacity(fade)))
            }
        }
    }

    // MARK: - Towering bookshelves

    private func drawShelves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0x500EE15)
        let shelfPositions: [(x: Double, w: Double, h: Double)] = [
            (0.02, 50, 500), (0.08, 45, 460), (0.88, 55, 520), (0.94, 40, 440),
            (0.40, 30, 350), (0.58, 35, 380),
        ]

        for shelf in shelfPositions {
            let sx = shelf.x * size.width
            let sw = shelf.w
            let sh = shelf.h
            let sy = size.height * 0.92 - sh

            // Shelf frame
            ctx.fill(Rectangle().path(in: CGRect(x: sx, y: sy, width: sw, height: sh)),
                with: .color(Color(red: 0.08, green: 0.06, blue: 0.04)))

            // Individual shelves with books
            let shelfRows = Int(sh / 28)
            for row in 0..<shelfRows {
                let rowY = sy + Double(row) * 28
                // Shelf plank
                ctx.fill(Rectangle().path(in: CGRect(x: sx, y: rowY + 24, width: sw, height: 3)),
                    with: .color(Color(red: 0.12, green: 0.09, blue: 0.06)))
                // Books
                var bookX = sx + 2.0
                while bookX < sx + sw - 3 {
                    let bw = 3 + nextDouble(&rng) * 5
                    let bh = 18 + nextDouble(&rng) * 5
                    let booky = rowY + 24 - bh
                    let hue = nextDouble(&rng)
                    let sat = 0.3 + nextDouble(&rng) * 0.5
                    let bri = 0.12 + nextDouble(&rng) * 0.15
                    ctx.fill(Rectangle().path(in: CGRect(x: bookX, y: booky, width: bw, height: bh)),
                        with: .color(Color(hue: hue, saturation: sat, brightness: bri)))
                    bookX += bw + 0.5
                }
            }
        }
    }

    // MARK: - Ink rivers on the floor

    private func drawInkRivers(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 10))
            let floorY = size.height * 0.88
            for i in 0..<4 {
                let startX = Double(i) * size.width * 0.25 + sin(t * 0.05 + Double(i)) * 20
                var ink = Path()
                ink.move(to: CGPoint(x: startX, y: floorY))
                for step in 0..<8 {
                    let nx = startX + Double(step) * 25 + sin(t * 0.1 + Double(step + i * 3)) * 15
                    let ny = floorY + sin(t * 0.08 + Double(step) * 0.5) * 6 + Double(step) * 3
                    ink.addLine(to: CGPoint(x: nx, y: ny))
                }
                l.stroke(ink, with: .color(Color(red: 0.05, green: 0.02, blue: 0.15).opacity(0.2)), lineWidth: 4)
            }
        }
    }

    // MARK: - Floating open books

    private func drawFloatingBooks(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xB00B500)
        for _ in 0..<8 {
            let bx = nextDouble(&rng) * 0.8 + 0.1
            let by = nextDouble(&rng) * 0.5 + 0.2
            let sp = nextDouble(&rng) * 0.1 + 0.03
            let ph = nextDouble(&rng) * .pi * 2
            let x = (bx + sin(t * sp + ph) * 0.03) * size.width
            let y = (by + cos(t * sp * 0.7 + ph) * 0.02) * size.height
            let openAngle = sin(t * 0.3 + ph) * 0.2 + 0.5

            // Open book — two page spreads
            let pageW = 10.0, pageH = 7.0
            // Left page
            var left = Path()
            left.move(to: CGPoint(x: x, y: y))
            left.addLine(to: CGPoint(x: x - pageW, y: y - openAngle * 3))
            left.addLine(to: CGPoint(x: x - pageW, y: y + pageH - openAngle * 3))
            left.addLine(to: CGPoint(x: x, y: y + pageH))
            left.closeSubpath()
            ctx.fill(left, with: .color(Color(red: 0.9, green: 0.85, blue: 0.7).opacity(0.25)))
            // Right page
            var right = Path()
            right.move(to: CGPoint(x: x, y: y))
            right.addLine(to: CGPoint(x: x + pageW, y: y - openAngle * 3))
            right.addLine(to: CGPoint(x: x + pageW, y: y + pageH - openAngle * 3))
            right.addLine(to: CGPoint(x: x, y: y + pageH))
            right.closeSubpath()
            ctx.fill(right, with: .color(Color(red: 0.85, green: 0.80, blue: 0.65).opacity(0.25)))
            // Spine
            ctx.fill(Rectangle().path(in: CGRect(x: x - 0.5, y: y, width: 1, height: pageH)),
                with: .color(Color(red: 0.5, green: 0.3, blue: 0.15).opacity(0.3)))
        }
    }

    // MARK: - Paper origami birds

    private func drawPaperBirds(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xA1AEB1D)
        let currentT = Date().timeIntervalSince(startDate)

        for i in 0..<12 {
            let bx = nextDouble(&rng) * 0.9 + 0.05
            let by = nextDouble(&rng) * 0.6 + 0.1
            let sp = nextDouble(&rng) * 0.015 + 0.008
            let ph = nextDouble(&rng) * .pi * 2

            // Lightning scatter effect
            var scatter = 0.0
            for strike in lightningStrikes {
                let age = currentT - strike.birth
                if age > 0 && age < 2.0 {
                    scatter = max(scatter, (1.0 - age / 2.0) * 0.05)
                }
            }

            let x = (bx + t * sp + sin(t * 0.3 + ph) * 0.02 + sin(currentT * 3 + Double(i)) * scatter).truncatingRemainder(dividingBy: 1.1)
            let y = (by + cos(t * sp * 0.5 + ph) * 0.015 - scatter * sin(Double(i)) * 2) * size.height
            let wingAngle = sin(t * 2.5 + ph) * 0.3
            let px = x * size.width

            let wingSpan = 8.0
            let alpha = 0.25 + sin(t * 0.2 + ph) * 0.08

            // V-shape bird (origami crane silhouette)
            var bird = Path()
            bird.move(to: CGPoint(x: px - wingSpan, y: y + wingAngle * 5))
            bird.addQuadCurve(to: CGPoint(x: px, y: y), control: CGPoint(x: px - wingSpan * 0.4, y: y - 3))
            bird.addQuadCurve(to: CGPoint(x: px + wingSpan, y: y + wingAngle * 5), control: CGPoint(x: px + wingSpan * 0.4, y: y - 3))
            ctx.stroke(bird, with: .color(Color(red: 0.9, green: 0.85, blue: 0.7).opacity(alpha)), lineWidth: 1.2)
        }
    }

    // MARK: - Glyph galaxies (orbiting golden symbols)

    private func drawGlyphGalaxies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let glyphs: [String] = ["α", "Ω", "∞", "λ", "φ", "δ", "π", "ψ", "θ", "Σ",
                                 "の", "光", "夢", "風", "星",
                                 "✦", "◆", "△", "○", "☽"]

        // Two galaxy centres
        let centres: [(x: Double, y: Double, r: Double, speed: Double)] = [
            (0.3, 0.35, 100, 0.08),
            (0.7, 0.45, 80, -0.06),
        ]

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 3))
            var rng = SplitMix64(seed: 0x611A5B0)
            for center in centres {
                let cx = center.x * size.width
                let cy = center.y * size.height
                for i in 0..<15 {
                    let orbitR = center.r * (0.3 + nextDouble(&rng) * 0.7)
                    let angle = Double(i) / 15.0 * .pi * 2 + t * center.speed + nextDouble(&rng) * 0.5
                    let gx = cx + cos(angle) * orbitR
                    let gy = cy + sin(angle) * orbitR * 0.6 // elliptical orbit
                    let pulse = sin(t * 0.5 + Double(i) * 0.8) * 0.2 + 0.5
                    let glyph = glyphs[Int(nextDouble(&rng) * Double(glyphs.count)) % glyphs.count]

                    let text = Text(glyph).font(.system(size: 10, weight: .light, design: .serif))
                        .foregroundColor(Color(red: 1.3, green: 1.1, blue: 0.5).opacity(pulse))
                    let resolved = ctx.resolve(text)
                    l.draw(resolved, at: CGPoint(x: gx, y: gy))
                }
            }
        }
    }

    // MARK: - Lightning between shelves

    private func drawLightning(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let currentT = Date().timeIntervalSince(startDate)
        for strike in lightningStrikes {
            let age = currentT - strike.birth
            guard age < 0.8 else { continue }
            let fade = age < 0.1 ? age / 0.1 : max(0, 1.0 - (age - 0.1) / 0.7)

            var rng = SplitMix64(seed: UInt64(strike.birth * 10000) & 0xFFFFFF)
            let sx = strike.x
            let sy = size.height * 0.15

            // Main bolt
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                var bolt = Path()
                bolt.move(to: CGPoint(x: sx, y: sy))
                var bx = sx, by = sy
                let target = size.height * 0.85
                while by < target {
                    bx += (nextDouble(&rng) - 0.5) * 30
                    by += 15 + nextDouble(&rng) * 25
                    bolt.addLine(to: CGPoint(x: bx, y: by))
                }
                l.stroke(bolt, with: .color(Color(red: 1.5, green: 1.3, blue: 2.0).opacity(fade * 0.6)), lineWidth: 2)
            }

            // Branching
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 2))
                for _ in 0..<3 {
                    let branchY = sy + nextDouble(&rng) * (size.height * 0.5)
                    let branchX = sx + (nextDouble(&rng) - 0.5) * 60
                    var branch = Path()
                    branch.move(to: CGPoint(x: branchX, y: branchY))
                    for _ in 0..<4 {
                        let dx = (nextDouble(&rng) - 0.5) * 25
                        let dy = 10 + nextDouble(&rng) * 15
                        branch.addLine(to: CGPoint(x: branchX + dx, y: branchY + dy))
                    }
                    l.stroke(branch, with: .color(Color(red: 1.3, green: 1.1, blue: 1.8).opacity(fade * 0.3)), lineWidth: 1)
                }
            }
        }
    }

    // MARK: - Flash illumination on lightning

    private func drawLightningFlash(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let currentT = Date().timeIntervalSince(startDate)
        var totalFlash = 0.0
        for strike in lightningStrikes {
            let age = currentT - strike.birth
            if age < 0.15 {
                totalFlash += (1.0 - age / 0.15) * 0.15
            }
        }
        guard totalFlash > 0 else { return }
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .color(Color(red: 0.6, green: 0.5, blue: 0.8).opacity(min(totalFlash, 0.2))))
    }

    // MARK: - Candlelight pools

    private func drawCandlelight(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let candles: [(x: Double, y: Double)] = [
            (0.15, 0.75), (0.35, 0.82), (0.55, 0.78), (0.80, 0.80), (0.50, 0.55),
        ]

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 25))
            for (i, candle) in candles.enumerated() {
                let cx = candle.x * size.width
                let cy = candle.y * size.height
                let flicker = sin(t * 3 + Double(i) * 1.7) * 0.1 + 0.9
                l.fill(Ellipse().path(in: CGRect(x: cx - 30, y: cy - 20, width: 60, height: 40)),
                    with: .color(Color(red: 1.3 * flicker, green: 0.8 * flicker, blue: 0.3).opacity(0.08)))
            }
        }

        // Candle flames
        for (i, candle) in candles.enumerated() {
            let cx = candle.x * size.width
            let cy = candle.y * size.height
            let flick = sin(t * 5 + Double(i) * 2.1) * 2
            // Stick
            ctx.fill(Rectangle().path(in: CGRect(x: cx - 1, y: cy - 8, width: 2, height: 10)),
                with: .color(Color(red: 0.25, green: 0.20, blue: 0.12)))
            // Flame
            var flame = Path()
            flame.move(to: CGPoint(x: cx, y: cy - 14))
            flame.addQuadCurve(to: CGPoint(x: cx + 2, y: cy - 8), control: CGPoint(x: cx + 3 + flick, y: cy - 11))
            flame.addQuadCurve(to: CGPoint(x: cx, y: cy - 14), control: CGPoint(x: cx - 3 + flick, y: cy - 11))
            ctx.fill(flame, with: .color(Color(red: 1.3, green: 0.8, blue: 0.25).opacity(0.7)))
        }
    }

    // MARK: - Dust motes and ember particles

    private func drawDustAndEmbers(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        var rng = SplitMix64(seed: 0xD050ABE)
        // Dust motes
        for _ in 0..<40 {
            let bx = nextDouble(&rng)
            let by = nextDouble(&rng)
            let sp = nextDouble(&rng) * 0.006 + 0.002
            let ph = nextDouble(&rng) * .pi * 2
            let x = (bx + sin(t * sp * 10 + ph) * 0.02) * size.width
            let y = fmod(by - t * sp + 1.0, 1.0) * size.height
            let pulse = sin(t * 0.8 + ph) * 0.3 + 0.5
            let s = 1.0 + nextDouble(&rng) * 1.5
            ctx.fill(Ellipse().path(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                with: .color(.white.opacity(pulse * 0.12)))
        }

        // Rising embers (from candles)
        for _ in 0..<15 {
            let bx = nextDouble(&rng)
            let phase = nextDouble(&rng) * 100
            let speed = nextDouble(&rng) * 0.02 + 0.01
            let y = fmod(1.0 - (t * speed + phase).truncatingRemainder(dividingBy: 1.0), 1.0) * size.height
            let x = (bx + sin(t * 0.2 + phase) * 0.02) * size.width
            let s = 1.5
            let glow = sin(t * 1.5 + phase) * 0.3 + 0.6
            ctx.fill(Ellipse().path(in: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                with: .color(Color(red: 1.3, green: 0.7, blue: 0.2).opacity(glow * 0.25)))
        }
    }

    // MARK: - Stained glass projected light

    private func drawStainedGlassLight(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 40))
            l.opacity = 0.06 + sin(t * 0.04) * 0.02

            // Projected color pools on the floor
            let colors: [Color] = [
                Color(red: 0.8, green: 0.2, blue: 0.2),
                Color(red: 0.2, green: 0.4, blue: 0.9),
                Color(red: 0.9, green: 0.7, blue: 0.1),
                Color(red: 0.3, green: 0.8, blue: 0.3),
            ]
            for (i, color) in colors.enumerated() {
                let angle = t * 0.01 + Double(i) * 1.5
                let x = size.width * (0.2 + Double(i) * 0.2) + sin(angle) * 20
                let y = size.height * 0.75 + cos(angle * 0.7) * 10
                let w = 80 + sin(t * 0.05 + Double(i)) * 15
                l.fill(Ellipse().path(in: CGRect(x: x - w / 2, y: y - w * 0.3, width: w, height: w * 0.6)),
                    with: .color(color))
            }
        }
    }
}
