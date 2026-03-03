import SwiftUI

// Forgotten Library — a warm infinite library at twilight.
// A few tall shelves recede into amber shadow. One candle on a reading desk
// casts a generous pool of light. Pale windows glow faintly. Golden glyphs
// drift upward like embers. Dust motes float slowly in the warmth.
// Tap to release a shower of luminous glyphs.
// Pure Canvas, 60fps, no state mutation inside Canvas closure.

struct ForgottenLibraryScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data

    struct BookshelfRow {
        let x: Double
        let depth: Double       // 0=near, 1=far
        let bookCount: Int
        let bookSeeds: [UInt64]
    }

    struct DustMote {
        let x, y: Double
        let driftX, driftY: Double
        let brightness: Double
        let size: Double
        let phase: Double
    }

    struct CandleData {
        let x, y: Double
        let brightness: Double
        let flickerRate: Double
        let flickerPhase: Double
    }

    struct FloatingGlyph: Identifiable {
        let id = UUID()
        let x, y: Double
        let birth: Double
        let char: String
        let driftX: Double
        let size: Double
        let rotation: Double
    }

    @State private var shelves: [BookshelfRow] = []
    @State private var dust: [DustMote] = []
    @State private var candles: [CandleData] = []
    @State private var glyphs: [FloatingGlyph] = []
    @State private var autoGlyphs: [FloatingGlyph] = []
    @State private var ready = false
    @State private var viewSize: CGSize = CGSize(width: 1200, height: 800)

    private let glyphChars = ["α", "β", "γ", "δ", "ε", "ζ", "η", "θ",
                               "λ", "μ", "π", "σ", "φ", "ψ", "ω",
                               "∞", "∑", "∫", "√", "☽", "✦", "✧"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawWindows(ctx: &ctx, size: size, t: t)
                drawShelves(ctx: &ctx, size: size, t: t)
                drawReadingDesk(ctx: &ctx, size: size, t: t)
                drawCandleGlow(ctx: &ctx, size: size, t: t)
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

        // Five bookshelves at varying depths — fewer, more readable
        for i in 0..<5 {
            let depth = Double(i) / 4.0
            let bookCount = 12 + Int(rng.nextDouble() * 6)
            var seeds: [UInt64] = []
            for _ in 0..<bookCount {
                seeds.append(UInt64(rng.nextDouble() * Double(UInt32.max)))
            }
            shelves.append(BookshelfRow(
                x: 0.06 + Double(i) * 0.16 + rng.nextDouble() * 0.04,
                depth: depth,
                bookCount: bookCount,
                bookSeeds: seeds
            ))
        }

        // Dust motes — fewer, slower
        for _ in 0..<50 {
            dust.append(DustMote(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                driftX: (rng.nextDouble() - 0.5) * 0.004,
                driftY: -0.001 - rng.nextDouble() * 0.002,
                brightness: 0.3 + rng.nextDouble() * 0.4,
                size: 0.5 + rng.nextDouble() * 1.0,
                phase: rng.nextDouble() * .pi * 2
            ))
        }

        // One main candle on the desk, two distant ones — all slow-flickering
        candles.append(CandleData(x: 0.5, y: 0.80, brightness: 1.0, flickerRate: 1.2, flickerPhase: 0))
        candles.append(CandleData(
            x: 0.18 + rng.nextDouble() * 0.06,
            y: 0.38 + rng.nextDouble() * 0.1,
            brightness: 0.35,
            flickerRate: 0.9 + rng.nextDouble() * 0.6,
            flickerPhase: rng.nextDouble() * .pi * 2
        ))
        candles.append(CandleData(
            x: 0.72 + rng.nextDouble() * 0.06,
            y: 0.42 + rng.nextDouble() * 0.1,
            brightness: 0.3,
            flickerRate: 1.0 + rng.nextDouble() * 0.5,
            flickerPhase: rng.nextDouble() * .pi * 2
        ))

        // Ambient floating glyphs — fewer, gentler
        for _ in 0..<10 {
            autoGlyphs.append(FloatingGlyph(
                x: 0.15 + rng.nextDouble() * 0.7,
                y: 0.3 + rng.nextDouble() * 0.4,
                birth: -rng.nextDouble() * 40.0,
                char: glyphChars[Int(rng.nextDouble() * Double(glyphChars.count))],
                driftX: (rng.nextDouble() - 0.5) * 0.003,
                size: 10.0 + rng.nextDouble() * 12.0,
                rotation: rng.nextDouble() * .pi * 2
            ))
        }

        ready = true
    }

    private func spawnGlyphs(at nx: Double, y ny: Double, t: Double) {
        var rng = SplitMix64(seed: UInt64(t * 10000))
        for _ in 0..<8 {
            glyphs.append(FloatingGlyph(
                x: nx + (rng.nextDouble() - 0.5) * 0.06,
                y: ny + (rng.nextDouble() - 0.5) * 0.03,
                birth: t,
                char: glyphChars[Int(rng.nextDouble() * Double(glyphChars.count))],
                driftX: (rng.nextDouble() - 0.5) * 0.006,
                size: 10.0 + rng.nextDouble() * 14.0,
                rotation: rng.nextDouble() * .pi * 2
            ))
        }
        if glyphs.count > 40 { glyphs.removeFirst(8) }
    }

    // MARK: - Drawing

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Warm dark amber-brown gradient — readable, not pitch black
        let steps = 10
        for i in 0..<steps {
            let frac = Double(i) / Double(steps)
            let y0 = frac * h
            let y1 = (frac + 1.0 / Double(steps)) * h + 1
            let r = 0.06 + frac * 0.03
            let g = 0.045 + frac * 0.025
            let b = 0.03 + frac * 0.015
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0)),
                with: .color(Color(red: r, green: g, blue: b))
            )
        }
    }

    private func drawWindows(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Two tall windows on the left — soft warm moonlight, no beams
        let windowPositions: [(x: Double, y: Double)] = [(0.03, 0.18), (0.04, 0.48)]
        let ww = w * 0.05
        let wh = h * 0.16

        for win in windowPositions {
            let cx = win.x * w
            let cy = win.y * h

            // Frame
            let frameRect = CGRect(x: cx - ww * 0.55, y: cy - wh * 0.5, width: ww * 1.1, height: wh)
            ctx.fill(
                RoundedRectangle(cornerRadius: ww * 0.08).path(in: frameRect),
                with: .color(Color(red: 0.07, green: 0.06, blue: 0.05))
            )

            // Glass — pale warm blue
            let glassRect = CGRect(x: cx - ww * 0.42, y: cy - wh * 0.44, width: ww * 0.84, height: wh * 0.88)
            ctx.fill(
                RoundedRectangle(cornerRadius: ww * 0.06).path(in: glassRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.14, green: 0.16, blue: 0.22).opacity(0.6),
                        Color(red: 0.10, green: 0.12, blue: 0.18).opacity(0.4),
                    ]),
                    startPoint: CGPoint(x: cx, y: glassRect.minY),
                    endPoint: CGPoint(x: cx, y: glassRect.maxY)
                )
            )

            // Soft spill of light on the floor near the window — no geometric beam
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 60))
                let spillR = wh * 1.2
                let spillRect = CGRect(x: cx + ww * 0.3 - spillR * 0.3, y: cy + wh * 0.2, width: spillR, height: spillR * 0.6)
                layer.fill(
                    Ellipse().path(in: spillRect),
                    with: .color(Color(red: 0.12, green: 0.14, blue: 0.22).opacity(0.06))
                )
            }
        }
    }

    private func drawShelves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        let sortedShelves = shelves.sorted { $0.depth > $1.depth }

        for shelf in sortedShelves {
            let depth = shelf.depth
            let fogAlpha = depth * 0.5
            let scale = 1.0 - depth * 0.35
            let shade = 0.10 + (1.0 - depth) * 0.06

            let shelfX = shelf.x * w
            let shelfBaseY = h * 0.32
            let shelfTopY = h * 0.04
            let shelfWidth = w * 0.09 * scale
            let rowCount = 4

            // Shelf back panel
            let backRect = CGRect(x: shelfX, y: shelfTopY, width: shelfWidth, height: shelfBaseY - shelfTopY + h * 0.55)
            ctx.fill(Path(backRect), with: .color(Color(red: shade * 0.7, green: shade * 0.6, blue: shade * 0.4).opacity(1.0 - fogAlpha * 0.5)))

            for row in 0..<rowCount {
                let rowFrac = Double(row) / Double(rowCount)
                let rowY = shelfTopY + rowFrac * (shelfBaseY - shelfTopY + h * 0.45)
                let rowH = (shelfBaseY - shelfTopY + h * 0.45) / Double(rowCount)

                // Shelf plank
                let plankRect = CGRect(x: shelfX - 1, y: rowY + rowH - 2, width: shelfWidth + 2, height: 2)
                ctx.fill(Path(plankRect), with: .color(Color(red: shade, green: shade * 0.85, blue: shade * 0.6).opacity(1.0 - fogAlpha * 0.5)))

                // Books
                let booksOnRow = min(shelf.bookCount / rowCount + 1, shelf.bookSeeds.count - row * (shelf.bookCount / rowCount))
                let startIdx = row * (shelf.bookCount / rowCount)
                var bookX = shelfX + 2

                for bi in 0..<max(0, booksOnRow) {
                    let seedIdx = startIdx + bi
                    guard seedIdx < shelf.bookSeeds.count else { break }
                    var bRng = SplitMix64(seed: shelf.bookSeeds[seedIdx])

                    let bookW = (2.5 + bRng.nextDouble() * 4.0) * scale
                    let bookH = (rowH * 0.65 + bRng.nextDouble() * rowH * 0.25)
                    let bookY = rowY + rowH - bookH - 2

                    // Muted jewel tones
                    let hue = bRng.nextDouble()
                    let r: Double, g: Double, b: Double
                    if hue < 0.25 {
                        r = 0.22 + bRng.nextDouble() * 0.1; g = 0.08; b = 0.07
                    } else if hue < 0.5 {
                        r = 0.09; g = 0.14 + bRng.nextDouble() * 0.08; b = 0.07
                    } else if hue < 0.75 {
                        r = 0.09; g = 0.09; b = 0.18 + bRng.nextDouble() * 0.1
                    } else {
                        r = 0.18 + bRng.nextDouble() * 0.08; g = 0.13; b = 0.06
                    }

                    let bookRect = CGRect(x: bookX, y: bookY, width: bookW, height: bookH)
                    ctx.fill(
                        Path(bookRect),
                        with: .color(Color(red: r, green: g, blue: b).opacity(1.0 - fogAlpha * 0.6))
                    )

                    bookX += bookW + 1
                }
            }
        }
    }

    private func drawReadingDesk(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let deskY = h * 0.78
        let deskW = w * 0.22
        let deskH = h * 0.025
        let deskX = w * 0.5 - deskW / 2

        // Desk surface
        ctx.fill(
            Path(CGRect(x: deskX, y: deskY, width: deskW, height: deskH)),
            with: .color(Color(red: 0.14, green: 0.10, blue: 0.06))
        )

        // Open book on desk
        let bookCenterX = w * 0.48
        let bookY = deskY - 1
        let pageW = w * 0.035
        let pageH = h * 0.02

        // Pages
        ctx.fill(
            Path(CGRect(x: bookCenterX - pageW, y: bookY - pageH, width: pageW, height: pageH)),
            with: .color(Color(red: 0.7, green: 0.65, blue: 0.55).opacity(0.25))
        )
        ctx.fill(
            Path(CGRect(x: bookCenterX, y: bookY - pageH, width: pageW, height: pageH)),
            with: .color(Color(red: 0.72, green: 0.67, blue: 0.57).opacity(0.25))
        )

        // Spine
        var spine = Path()
        spine.move(to: CGPoint(x: bookCenterX, y: bookY - pageH))
        spine.addLine(to: CGPoint(x: bookCenterX, y: bookY))
        ctx.stroke(spine, with: .color(Color(red: 0.3, green: 0.22, blue: 0.12).opacity(0.3)), lineWidth: 1)

        // Desk legs
        for side in [-1.0, 1.0] {
            let legX = w * 0.5 + side * deskW * 0.4
            ctx.fill(
                Path(CGRect(x: legX - 2, y: deskY + deskH, width: 4, height: h * 0.14)),
                with: .color(Color(red: 0.09, green: 0.07, blue: 0.04))
            )
        }

        // Candle body on desk
        let candleX = w * 0.5
        let candleBaseY = deskY
        let stickW: Double = 4
        let stickH: Double = 16

        // Candle stick
        ctx.fill(
            Path(CGRect(x: candleX - stickW / 2, y: candleBaseY - stickH, width: stickW, height: stickH)),
            with: .color(Color(red: 0.8, green: 0.75, blue: 0.65).opacity(0.5))
        )

        // Flame — slow breathing
        let flicker = sin(t * 1.2) * 0.08 + sin(t * 0.7) * 0.04 + 0.88
        let flameH = 5.0 + flicker * 2.0
        let flameW = 2.5 + flicker * 0.5
        let flameY = candleBaseY - stickH - flameH
        ctx.fill(
            Ellipse().path(in: CGRect(x: candleX - flameW, y: flameY, width: flameW * 2, height: flameH)),
            with: .color(Color(red: 1.4 * flicker, green: 0.85 * flicker, blue: 0.25).opacity(0.9))
        )
    }

    private func drawCandleGlow(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Large warm glow from all candles — one blurred layer
        ctx.drawLayer { glowLayer in
            glowLayer.addFilter(.blur(radius: 50))
            for candle in candles {
                let flicker = sin(t * candle.flickerRate + candle.flickerPhase) * 0.06 +
                              sin(t * candle.flickerRate * 0.6 + candle.flickerPhase) * 0.03 + 0.91
                let cx = candle.x * w
                let cy = candle.y * h
                let r = 90.0 * candle.brightness
                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                glowLayer.fill(
                    Ellipse().path(in: rect),
                    with: .color(Color(red: 1.0, green: 0.7, blue: 0.25).opacity(0.14 * candle.brightness * flicker))
                )
            }
        }

        // Distant candle flames (the two background ones)
        for candle in candles where candle.brightness < 1.0 {
            let flicker = sin(t * candle.flickerRate + candle.flickerPhase) * 0.06 + 0.9
            let cx = candle.x * w
            let cy = candle.y * h
            let stickW = 2.0
            let stickH = 8.0

            ctx.fill(
                Path(CGRect(x: cx - stickW / 2, y: cy - stickH, width: stickW, height: stickH)),
                with: .color(Color(red: 0.75, green: 0.7, blue: 0.6).opacity(0.25))
            )

            let flameH = 3.0 * flicker
            let flameW = 1.5
            ctx.fill(
                Ellipse().path(in: CGRect(x: cx - flameW, y: cy - stickH - flameH, width: flameW * 2, height: flameH)),
                with: .color(Color(red: 1.3 * flicker, green: 0.8 * flicker, blue: 0.25).opacity(0.7))
            )
        }
    }

    private func drawGlyphCommon(ctx: inout GraphicsContext, size: CGSize, t: Double, glyph: FloatingGlyph, ambient: Bool) {
        let w = size.width, h = size.height
        let age = t - glyph.birth
        let cycleDuration: Double = ambient ? 30.0 : 10.0
        let effectiveAge = ambient ? fmod(age + 60, cycleDuration) : age
        guard effectiveAge > 0, effectiveAge < cycleDuration else { return }
        let progress = effectiveAge / cycleDuration

        let rise = progress * 0.25
        let x = (glyph.x + sin(effectiveAge * 0.3 + glyph.rotation) * glyph.driftX * 8) * w
        let y = (glyph.y - rise) * h
        guard y > 0, y < h else { return }

        var alpha: Double = 0.4
        if progress < 0.15 { alpha = progress / 0.15 * 0.4 }
        if progress > 0.65 { alpha = (1.0 - progress) / 0.35 * 0.4 }
        alpha = max(0, alpha) * (ambient ? 0.35 : 0.6)

        let fontSize = glyph.size
        let rot = sin(effectiveAge * 0.2 + glyph.rotation) * 0.15

        // Soft glow behind glyph
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 10))
            let gr = fontSize * 1.3
            layer.fill(
                Circle().path(in: CGRect(x: x - gr / 2, y: y - gr / 2, width: gr, height: gr)),
                with: .color(Color(red: 1.0, green: 0.8, blue: 0.35).opacity(alpha * 0.25))
            )
        }

        var textCtx = ctx
        textCtx.translateBy(x: x, y: y)
        textCtx.rotate(by: Angle(radians: rot))
        let text = Text(glyph.char)
            .font(.system(size: fontSize, weight: .light, design: .serif))
            .foregroundColor(Color(red: 1.0, green: 0.85, blue: 0.45).opacity(alpha))
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
            let shimmer = sin(t * 0.8 + mote.phase) * 0.2 + 0.8
            let alpha = mote.brightness * shimmer * 0.18
            let r = mote.size

            ctx.fill(
                Circle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 1.0, green: 0.9, blue: 0.65).opacity(alpha))
            )
        }
    }

    private func drawFogOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Warm fog — thicker at top (depth) and sides
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 80))

            // Top fog — warm dark, representing depth
            let topRect = CGRect(x: 0, y: 0, width: w, height: h * 0.3)
            layer.fill(
                Path(topRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.05, green: 0.04, blue: 0.03).opacity(0.6),
                        Color.clear,
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h * 0.3)
                )
            )

            // Gentle side wisp — slow drift
            let driftOffset = sin(t * 0.03) * 20
            let fogRect = CGRect(x: -30 + driftOffset, y: h * 0.25, width: w * 0.25, height: h * 0.5)
            layer.fill(
                Ellipse().path(in: fogRect),
                with: .color(Color(red: 0.06, green: 0.05, blue: 0.03).opacity(0.1))
            )
        }
    }
}
