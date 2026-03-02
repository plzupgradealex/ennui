import SwiftUI

// Forgotten Library — an infinite twilight library stretching into darkness.
// Towering bookshelves recede into fog. Warm candlelight pools on old wood.
// Occasionally a book flutters open and releases glowing golden letters that
// drift upward like embers. Dust motes catch the light. Tall arched windows
// on one side let in pale blue moonlight. A reading desk with a single
// flickering candle anchors the foreground.
// Tap to open a book and release a shower of luminous glyphs.
// Pure Canvas, 60fps, no state mutation inside Canvas closure.

struct ForgottenLibraryScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data

    struct BookshelfRow {
        let x: Double           // normalised left edge
        let depth: Double       // 0=near, 1=far (affects scale, fog, shade)
        let bookCount: Int
        let bookSeeds: [UInt64] // seed per book for colour/height
    }

    struct DustMote {
        let x, y: Double
        let driftX, driftY: Double
        let brightness: Double
        let size: Double
        let phase: Double
    }

    struct CandleData {
        let x, y: Double       // normalised
        let brightness: Double
        let flickerRate: Double
        let flickerPhase: Double
    }

    struct FloatingGlyph: Identifiable {
        let id = UUID()
        let x, y: Double       // spawn position
        let birth: Double
        let char: String        // the glyph character
        let driftX: Double
        let size: Double
        let rotation: Double
    }

    struct WindowData {
        let x, y: Double       // normalised centre
        let width, height: Double
        let archHeight: Double
    }

    @State private var shelves: [BookshelfRow] = []
    @State private var dust: [DustMote] = []
    @State private var candles: [CandleData] = []
    @State private var windows: [WindowData] = []
    @State private var glyphs: [FloatingGlyph] = []
    @State private var autoGlyphs: [FloatingGlyph] = []
    @State private var ready = false
    @State private var viewSize: CGSize = CGSize(width: 1200, height: 800)

    private let glyphChars = ["α", "β", "γ", "δ", "ε", "ζ", "η", "θ",
                               "λ", "μ", "π", "σ", "φ", "ψ", "ω",
                               "∞", "∑", "∫", "√", "♪", "☽", "✦", "✧",
                               "あ", "の", "を", "は", "か", "き"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawWindows(ctx: &ctx, size: size, t: t)
                drawShelves(ctx: &ctx, size: size, t: t)
                drawReadingDesk(ctx: &ctx, size: size, t: t)
                drawCandles(ctx: &ctx, size: size, t: t)
                drawAutoGlyphs(ctx: &ctx, size: size, t: t)
                drawGlyphs(ctx: &ctx, size: size, t: t)
                drawDust(ctx: &ctx, size: size, t: t)
                drawFogOverlay(ctx: &ctx, size: size, t: t)
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
            let screenH = max(viewSize.height, 1)
            spawnGlyphs(at: loc.x / screenW, y: loc.y / screenH, t: t)
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 0xB00C11B)

        // Bookshelves at varying depths
        for i in 0..<8 {
            let depth = Double(i) / 7.0
            let bookCount = 15 + Int(rng.nextDouble() * 10)
            var seeds: [UInt64] = []
            for _ in 0..<bookCount {
                seeds.append(UInt64(rng.nextDouble() * Double(UInt32.max)))
            }
            shelves.append(BookshelfRow(
                x: 0.05 + depth * 0.12 + rng.nextDouble() * 0.05,
                depth: depth,
                bookCount: bookCount,
                bookSeeds: seeds
            ))
        }

        // Dust motes
        for _ in 0..<100 {
            dust.append(DustMote(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                driftX: (rng.nextDouble() - 0.5) * 0.008,
                driftY: -0.002 - rng.nextDouble() * 0.004,
                brightness: 0.2 + rng.nextDouble() * 0.5,
                size: 0.5 + rng.nextDouble() * 1.5,
                phase: rng.nextDouble() * .pi * 2
            ))
        }

        // Candles
        candles.append(CandleData(x: 0.5, y: 0.82, brightness: 1.0, flickerRate: 6.0, flickerPhase: 0))
        for _ in 0..<4 {
            candles.append(CandleData(
                x: 0.1 + rng.nextDouble() * 0.8,
                y: 0.3 + rng.nextDouble() * 0.4,
                brightness: 0.3 + rng.nextDouble() * 0.3,
                flickerRate: 3.0 + rng.nextDouble() * 5.0,
                flickerPhase: rng.nextDouble() * .pi * 2
            ))
        }

        // Arched windows on the left side
        for i in 0..<3 {
            let yPos = 0.15 + Double(i) * 0.25
            windows.append(WindowData(
                x: 0.02 + Double(i) * 0.01,
                y: yPos,
                width: 0.06,
                height: 0.18,
                archHeight: 0.04
            ))
        }

        // Auto-generated floating glyphs (ambient)
        for _ in 0..<20 {
            autoGlyphs.append(FloatingGlyph(
                x: 0.1 + rng.nextDouble() * 0.8,
                y: 0.3 + rng.nextDouble() * 0.5,
                birth: -rng.nextDouble() * 30.0,
                char: glyphChars[Int(rng.nextDouble() * Double(glyphChars.count))],
                driftX: (rng.nextDouble() - 0.5) * 0.005,
                size: 8.0 + rng.nextDouble() * 14.0,
                rotation: rng.nextDouble() * .pi * 2
            ))
        }

        ready = true
    }

    private func spawnGlyphs(at nx: Double, y ny: Double, t: Double) {
        var rng = SplitMix64(seed: UInt64(t * 10000))
        for _ in 0..<12 {
            glyphs.append(FloatingGlyph(
                x: nx + (rng.nextDouble() - 0.5) * 0.08,
                y: ny + (rng.nextDouble() - 0.5) * 0.04,
                birth: t,
                char: glyphChars[Int(rng.nextDouble() * Double(glyphChars.count))],
                driftX: (rng.nextDouble() - 0.5) * 0.01,
                size: 10.0 + rng.nextDouble() * 16.0,
                rotation: rng.nextDouble() * .pi * 2
            ))
        }
        if glyphs.count > 60 { glyphs.removeFirst(12) }
    }

    // MARK: - Drawing

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Warm dark wood tones
        let steps = 15
        for i in 0..<steps {
            let frac = Double(i) / Double(steps)
            let y0 = frac * h
            let y1 = (frac + 1.0 / Double(steps)) * h + 1
            let r = 0.04 + frac * 0.02
            let g = 0.03 + frac * 0.015
            let b = 0.02 + frac * 0.01
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0)),
                with: .color(Color(red: r, green: g, blue: b))
            )
        }
    }

    private func drawWindows(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for win in windows {
            let cx = win.x * w
            let cy = win.y * h
            let ww = win.width * w
            let wh = win.height * h

            // Window frame — darker outline
            var frame = Path()
            let frameRect = CGRect(x: cx - ww * 0.55, y: cy - wh * 0.5, width: ww * 1.1, height: wh)
            frame.addRoundedRect(in: frameRect, cornerSize: CGSize(width: ww * 0.1, height: ww * 0.1))
            ctx.fill(frame, with: .color(Color(red: 0.06, green: 0.05, blue: 0.04)))

            // Window glass — pale moonlight blue
            let glassRect = CGRect(x: cx - ww * 0.45, y: cy - wh * 0.45, width: ww * 0.9, height: wh * 0.9)
            ctx.fill(
                RoundedRectangle(cornerRadius: ww * 0.08).path(in: glassRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.12, green: 0.15, blue: 0.25).opacity(0.7),
                        Color(red: 0.08, green: 0.1, blue: 0.18).opacity(0.5),
                    ]),
                    startPoint: CGPoint(x: cx, y: glassRect.minY),
                    endPoint: CGPoint(x: cx, y: glassRect.maxY)
                )
            )

            // Moonlight beam casting in
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 40))
                var beam = Path()
                beam.move(to: CGPoint(x: cx + ww * 0.3, y: cy - wh * 0.3))
                beam.addLine(to: CGPoint(x: cx + ww * 6, y: h * 0.9))
                beam.addLine(to: CGPoint(x: cx + ww * 3, y: h * 0.9))
                beam.addLine(to: CGPoint(x: cx, y: cy + wh * 0.3))
                beam.closeSubpath()
                layer.fill(beam, with: .color(Color(red: 0.15, green: 0.18, blue: 0.35).opacity(0.04)))
            }
        }
    }

    private func drawShelves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        let sortedShelves = shelves.sorted { $0.depth > $1.depth }

        for shelf in sortedShelves {
            let depth = shelf.depth
            let fogAlpha = depth * 0.6      // far = more fog
            let scale = 1.0 - depth * 0.4   // far = smaller
            let shade = 0.08 + (1.0 - depth) * 0.06  // near = lighter

            // Bookshelf vertical position
            let shelfX = shelf.x * w
            let shelfBaseY = h * 0.3
            let shelfTopY = h * 0.02
            let shelfWidth = w * 0.08 * scale
            let rowCount = 5

            // Shelf back
            let backRect = CGRect(x: shelfX, y: shelfTopY, width: shelfWidth, height: shelfBaseY - shelfTopY + h * 0.6)
            ctx.fill(Path(backRect), with: .color(Color(red: shade * 0.7, green: shade * 0.6, blue: shade * 0.4).opacity(1.0 - fogAlpha * 0.5)))

            // Shelf planks and books
            for row in 0..<rowCount {
                let rowFrac = Double(row) / Double(rowCount)
                let rowY = shelfTopY + rowFrac * (shelfBaseY - shelfTopY + h * 0.5)
                let rowH = (shelfBaseY - shelfTopY + h * 0.5) / Double(rowCount)

                // Shelf plank
                let plankRect = CGRect(x: shelfX - 2, y: rowY + rowH - 2, width: shelfWidth + 4, height: 3)
                ctx.fill(Path(plankRect), with: .color(Color(red: shade, green: shade * 0.85, blue: shade * 0.6).opacity(1.0 - fogAlpha * 0.5)))

                // Books on this shelf
                let booksOnRow = min(shelf.bookCount / rowCount + 1, shelf.bookSeeds.count - row * (shelf.bookCount / rowCount))
                let startIdx = row * (shelf.bookCount / rowCount)
                var bookX = shelfX + 2

                for bi in 0..<max(0, booksOnRow) {
                    let seedIdx = startIdx + bi
                    guard seedIdx < shelf.bookSeeds.count else { break }
                    var bRng = SplitMix64(seed: shelf.bookSeeds[seedIdx])

                    let bookW = (2.0 + bRng.nextDouble() * 4.0) * scale
                    let bookH = (rowH * 0.7 + bRng.nextDouble() * rowH * 0.25)
                    let bookY = rowY + rowH - bookH - 2

                    // Book colour — muted jewel tones
                    let hue = bRng.nextDouble()
                    let r: Double, g: Double, b: Double
                    if hue < 0.2 {
                        r = 0.25 + bRng.nextDouble() * 0.15; g = 0.08; b = 0.08  // deep red
                    } else if hue < 0.4 {
                        r = 0.1; g = 0.15 + bRng.nextDouble() * 0.1; b = 0.08    // forest green
                    } else if hue < 0.6 {
                        r = 0.1; g = 0.1; b = 0.2 + bRng.nextDouble() * 0.15     // midnight blue
                    } else if hue < 0.8 {
                        r = 0.2 + bRng.nextDouble() * 0.1; g = 0.15; b = 0.05    // leather brown
                    } else {
                        r = 0.18; g = 0.1; b = 0.18 + bRng.nextDouble() * 0.1    // plum
                    }

                    let bookRect = CGRect(x: bookX, y: bookY, width: bookW, height: bookH)
                    ctx.fill(
                        Path(bookRect),
                        with: .color(Color(red: r, green: g, blue: b).opacity(1.0 - fogAlpha * 0.6))
                    )

                    // Spine accent line
                    if bookW > 3 {
                        let accentRect = CGRect(x: bookX + bookW * 0.15, y: bookY + bookH * 0.2, width: bookW * 0.08, height: bookH * 0.6)
                        ctx.fill(
                            Path(accentRect),
                            with: .color(Color(red: 0.6, green: 0.5, blue: 0.3).opacity(0.15 * (1.0 - fogAlpha)))
                        )
                    }

                    bookX += bookW + 1
                }
            }
        }
    }

    private func drawReadingDesk(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let deskY = h * 0.78
        let deskW = w * 0.25
        let deskH = h * 0.03
        let deskX = w * 0.5 - deskW / 2

        // Desk surface
        let deskRect = CGRect(x: deskX, y: deskY, width: deskW, height: deskH)
        ctx.fill(Path(deskRect), with: .color(Color(red: 0.12, green: 0.08, blue: 0.05)))

        // Open book on desk
        let bookX = w * 0.48
        let bookY = deskY - 2
        let pageW = w * 0.04
        let pageH = h * 0.025

        // Left page
        let leftPage = CGRect(x: bookX - pageW, y: bookY - pageH, width: pageW, height: pageH)
        ctx.fill(Path(leftPage), with: .color(Color(red: 0.75, green: 0.7, blue: 0.6).opacity(0.3)))

        // Right page
        let rightPage = CGRect(x: bookX, y: bookY - pageH, width: pageW, height: pageH)
        ctx.fill(Path(rightPage), with: .color(Color(red: 0.8, green: 0.75, blue: 0.65).opacity(0.3)))

        // Spine line
        var spine = Path()
        spine.move(to: CGPoint(x: bookX, y: bookY - pageH))
        spine.addLine(to: CGPoint(x: bookX, y: bookY))
        ctx.stroke(spine, with: .color(Color(red: 0.35, green: 0.25, blue: 0.15).opacity(0.4)), lineWidth: 1)

        // Faint text lines on pages
        var rng = SplitMix64(seed: 0xEE100)
        for page in 0..<2 {
            let px = page == 0 ? bookX - pageW + 3 : bookX + 3
            for line in 0..<4 {
                let ly = bookY - pageH + 3 + Double(line) * (pageH / 5.0)
                let lineW = pageW * 0.7 * (0.5 + rng.nextDouble() * 0.5)
                let lineRect = CGRect(x: px, y: ly, width: lineW, height: 0.5)
                ctx.fill(Path(lineRect), with: .color(Color(red: 0.3, green: 0.25, blue: 0.2).opacity(0.15)))
            }
        }

        // Desk legs
        for side in [-1.0, 1.0] {
            let legX = w * 0.5 + side * deskW * 0.4
            let legRect = CGRect(x: legX - 2, y: deskY + deskH, width: 4, height: h * 0.15)
            ctx.fill(Path(legRect), with: .color(Color(red: 0.08, green: 0.06, blue: 0.04)))
        }
    }

    private func drawCandles(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Shared glow layer
        ctx.drawLayer { glowLayer in
            glowLayer.addFilter(.blur(radius: 35))
            for candle in candles {
                let flicker = sin(t * candle.flickerRate + candle.flickerPhase) * 0.12 +
                              sin(t * candle.flickerRate * 1.7 + candle.flickerPhase) * 0.06 + 0.82
                let cx = candle.x * w
                let cy = candle.y * h
                let r = 60.0 * candle.brightness
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                glowLayer.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color(red: 1.0, green: 0.65, blue: 0.2).opacity(0.08 * candle.brightness * flicker))
                )
            }
        }

        // Candle bodies and flames
        for candle in candles {
            let flicker = sin(t * candle.flickerRate + candle.flickerPhase) * 0.12 +
                          sin(t * candle.flickerRate * 1.7 + candle.flickerPhase) * 0.06 + 0.82
            let cx = candle.x * w
            let cy = candle.y * h

            // Candle stick
            let stickW = 3.0 * candle.brightness + 1
            let stickH = 12.0 * candle.brightness + 3
            ctx.fill(
                Path(CGRect(x: cx - stickW / 2, y: cy - stickH, width: stickW, height: stickH)),
                with: .color(Color(red: 0.8, green: 0.75, blue: 0.65).opacity(0.4 * candle.brightness))
            )

            // Flame
            let flameH = (4.0 + flicker * 2.0) * candle.brightness
            let flameW = (2.0 + flicker) * candle.brightness
            let flameY = cy - stickH - flameH
            let flamePath = CGRect(x: cx - flameW, y: flameY, width: flameW * 2, height: flameH)
            ctx.fill(
                Ellipse().path(in: flamePath),
                with: .color(Color(red: 1.5 * flicker, green: 0.9 * flicker, blue: 0.3).opacity(0.9 * candle.brightness))
            )
        }
    }

    private func drawGlyphCommon(ctx: inout GraphicsContext, size: CGSize, t: Double, glyph: FloatingGlyph, ambient: Bool) {
        let w = size.width, h = size.height
        let age = t - glyph.birth
        let cycleDuration: Double = ambient ? 25.0 : 8.0
        let effectiveAge = ambient ? fmod(age + 50, cycleDuration) : age
        guard effectiveAge > 0, effectiveAge < cycleDuration else { return }
        let progress = effectiveAge / cycleDuration

        let rise = progress * 0.3
        let x = (glyph.x + sin(effectiveAge * 0.5 + glyph.rotation) * glyph.driftX * 10) * w
        let y = (glyph.y - rise) * h
        guard y > 0, y < h else { return }

        var alpha: Double = 0.5
        if progress < 0.1 { alpha = progress / 0.1 * 0.5 }
        if progress > 0.7 { alpha = (1.0 - progress) / 0.3 * 0.5 }
        alpha = max(0, alpha) * (ambient ? 0.4 : 0.7)

        let fontSize = glyph.size
        let rot = sin(effectiveAge * 0.3 + glyph.rotation) * 0.2

        // Glow behind glyph
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 8))
            let gr = fontSize * 1.2
            layer.fill(
                Circle().path(in: CGRect(x: x - gr / 2, y: y - gr / 2, width: gr, height: gr)),
                with: .color(Color(red: 1.0, green: 0.8, blue: 0.3).opacity(alpha * 0.3))
            )
        }

        // The glyph itself
        var textCtx = ctx
        textCtx.translateBy(x: x, y: y)
        textCtx.rotate(by: Angle(radians: rot))
        let text = Text(glyph.char)
            .font(.system(size: fontSize, weight: .light, design: .serif))
            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(alpha))
        textCtx.draw(text, at: .zero)
    }

    private func drawAutoGlyphs(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for glyph in autoGlyphs {
            drawGlyphCommon(ctx: &ctx, size: size, t: t, glyph: glyph, ambient: true)
        }
    }

    private func drawGlyphs(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for glyph in glyphs {
            drawGlyphCommon(ctx: &ctx, size: size, t: t, glyph: glyph, ambient: false)
        }
    }

    private func drawDust(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for mote in dust {
            let x = fmod(mote.x + mote.driftX * t + 1.0, 1.0) * w
            let y = fmod(mote.y + mote.driftY * t + 2.0, 1.0) * h
            let shimmer = sin(t * 1.5 + mote.phase) * 0.3 + 0.7
            let alpha = mote.brightness * shimmer * 0.25
            let r = mote.size

            ctx.fill(
                Circle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 1.0, green: 0.9, blue: 0.6).opacity(alpha))
            )
        }
    }

    private func drawFogOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Atmospheric fog — thicker at the back (top) and sides
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 80))

            // Top fog (representing depth — far shelves fade)
            let topRect = CGRect(x: 0, y: 0, width: w, height: h * 0.35)
            layer.fill(
                Path(topRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.04, green: 0.03, blue: 0.05).opacity(0.7),
                        Color.clear,
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h * 0.35)
                )
            )

            // Side fog wisps that drift
            let driftOffset = sin(t * 0.05) * 30
            let fogRect = CGRect(x: -40 + driftOffset, y: h * 0.2, width: w * 0.3, height: h * 0.6)
            layer.fill(
                Ellipse().path(in: fogRect),
                with: .color(Color(red: 0.05, green: 0.04, blue: 0.06).opacity(0.15))
            )
        }
    }
}
