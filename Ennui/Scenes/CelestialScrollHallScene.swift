import SwiftUI

// Celestial Scroll Hall — A moonlit Chinese study hall in deep twilight.
// Red lacquered columns stretch upward. Hanging silk lanterns cast pools of
// warm amber light. Scroll shelves line the walls, bamboo scroll tubes neatly
// arranged. Lattice windows (ice-crack pattern) let in pale moonlight.
// A calligraphy desk in the foreground holds a brush and open scroll.
// Incense smoke curls lazily upward. Plum blossom petals drift through the air.
// Floating Chinese characters — all innocent, courageous, kind — rise
// from the scrolls like luminous ink, drifting upward and dissolving.
// Tap to release a burst of glowing characters from the calligraphy desk.
// Pure Canvas, 60fps, no state mutation inside Canvas closure.

struct CelestialScrollHallScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data

    struct ScrollShelf {
        let x: Double          // normalised left edge
        let depth: Double      // 0=near, 1=far
        let scrollCount: Int
        let scrollSeeds: [UInt64]
    }

    struct LanternData {
        let x, y: Double       // normalised
        let size: Double
        let brightness: Double
        let swayRate: Double
        let swayPhase: Double
        let flickerRate: Double
        let flickerPhase: Double
    }

    struct PlumPetal {
        let x, y: Double
        let driftX, driftY: Double
        let rotation: Double
        let rotationSpeed: Double
        let size: Double
        let phase: Double
        let hue: Double        // pink variation
    }

    struct IncenseWisp {
        let x: Double
        let baseY: Double
        let amplitude: Double
        let frequency: Double
        let phase: Double
        let alpha: Double
    }

    struct FloatingChar: Identifiable {
        let id = UUID()
        let x, y: Double
        let birth: Double
        let char: String
        let driftX: Double
        let size: Double
        let rotation: Double
    }

    struct LatticeWindow {
        let x, y: Double
        let width, height: Double
    }

    struct ColumnData {
        let x: Double
        let depth: Double
    }

    @State private var shelves: [ScrollShelf] = []
    @State private var lanterns: [LanternData] = []
    @State private var petals: [PlumPetal] = []
    @State private var incense: [IncenseWisp] = []
    @State private var windows: [LatticeWindow] = []
    @State private var columns: [ColumnData] = []
    @State private var tapChars: [FloatingChar] = []
    @State private var autoChars: [FloatingChar] = []
    @State private var ready = false

    // Every character is purely positive, kind, courageous, innocent —
    // impossible to misconstrue for negativity.
    private let hanzi: [String] = [
        "愛",  // love
        "善",  // goodness
        "勇",  // courage
        "仁",  // benevolence
        "和",  // harmony
        "福",  // blessing
        "夢",  // dream
        "光",  // light
        "星",  // star
        "花",  // flower
        "春",  // spring
        "心",  // heart
        "美",  // beauty
        "安",  // peace
        "暖",  // warmth
        "月",  // moon
        "靜",  // serenity
        "慧",  // wisdom
        "友",  // friendship
        "樂",  // joy
        "望",  // hope
        "笑",  // smile / laughter
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawBackground(ctx: &ctx, size: size, t: t)
                drawWindows(ctx: &ctx, size: size, t: t)
                drawShelves(ctx: &ctx, size: size, t: t)
                drawColumns(ctx: &ctx, size: size, t: t)
                drawCalligraphyDesk(ctx: &ctx, size: size, t: t)
                drawIncense(ctx: &ctx, size: size, t: t)
                drawLanterns(ctx: &ctx, size: size, t: t)
                drawAutoChars(ctx: &ctx, size: size, t: t)
                drawTapChars(ctx: &ctx, size: size, t: t)
                drawPetals(ctx: &ctx, size: size, t: t)
                drawFogOverlay(ctx: &ctx, size: size, t: t)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            let t = Date().timeIntervalSince(startDate)
            let screenW = max(NSScreen.main?.frame.width ?? 1200, 1)
            let screenH = max(NSScreen.main?.frame.height ?? 800, 1)
            spawnChars(at: loc.x / screenW, y: loc.y / screenH, t: t)
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 0xCE1E571A1)

        // Red lacquered columns
        for i in 0..<6 {
            let depth = Double(i) / 5.0
            columns.append(ColumnData(
                x: 0.08 + Double(i) * 0.17 + (rng.nextDouble() - 0.5) * 0.03,
                depth: depth
            ))
        }

        // Scroll shelves at varying depths
        for i in 0..<7 {
            let depth = Double(i) / 6.0
            let scrollCount = 8 + Int(rng.nextDouble() * 8)
            var seeds: [UInt64] = []
            for _ in 0..<scrollCount {
                seeds.append(UInt64(rng.nextDouble() * Double(UInt32.max)))
            }
            shelves.append(ScrollShelf(
                x: 0.06 + depth * 0.1 + rng.nextDouble() * 0.04,
                depth: depth,
                scrollCount: scrollCount,
                scrollSeeds: seeds
            ))
        }

        // Hanging silk lanterns
        for _ in 0..<7 {
            lanterns.append(LanternData(
                x: 0.1 + rng.nextDouble() * 0.8,
                y: 0.08 + rng.nextDouble() * 0.2,
                size: 0.03 + rng.nextDouble() * 0.025,
                brightness: 0.5 + rng.nextDouble() * 0.5,
                swayRate: 0.3 + rng.nextDouble() * 0.4,
                swayPhase: rng.nextDouble() * .pi * 2,
                flickerRate: 3.0 + rng.nextDouble() * 4.0,
                flickerPhase: rng.nextDouble() * .pi * 2
            ))
        }

        // Plum blossom petals
        for _ in 0..<60 {
            petals.append(PlumPetal(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                driftX: (rng.nextDouble() - 0.5) * 0.006,
                driftY: 0.002 + rng.nextDouble() * 0.004,
                rotation: rng.nextDouble() * .pi * 2,
                rotationSpeed: (rng.nextDouble() - 0.5) * 2.0,
                size: 2.0 + rng.nextDouble() * 3.5,
                phase: rng.nextDouble() * .pi * 2,
                hue: 0.9 + rng.nextDouble() * 0.15 // pink to rose
            ))
        }

        // Incense wisps
        for i in 0..<3 {
            incense.append(IncenseWisp(
                x: 0.45 + Double(i) * 0.05,
                baseY: 0.72,
                amplitude: 0.02 + rng.nextDouble() * 0.03,
                frequency: 0.8 + rng.nextDouble() * 0.6,
                phase: rng.nextDouble() * .pi * 2,
                alpha: 0.06 + rng.nextDouble() * 0.06
            ))
        }

        // Lattice windows on the left
        for i in 0..<3 {
            windows.append(LatticeWindow(
                x: 0.01 + Double(i) * 0.015,
                y: 0.1 + Double(i) * 0.22,
                width: 0.07,
                height: 0.16
            ))
        }

        // Ambient floating characters
        for _ in 0..<18 {
            autoChars.append(FloatingChar(
                x: 0.1 + rng.nextDouble() * 0.8,
                y: 0.2 + rng.nextDouble() * 0.5,
                birth: -rng.nextDouble() * 30.0,
                char: hanzi[Int(rng.nextDouble() * Double(hanzi.count))],
                driftX: (rng.nextDouble() - 0.5) * 0.004,
                size: 10.0 + rng.nextDouble() * 16.0,
                rotation: rng.nextDouble() * .pi * 2
            ))
        }

        ready = true
    }

    private func spawnChars(at nx: Double, y ny: Double, t: Double) {
        var rng = SplitMix64(seed: UInt64(t * 10000))
        for _ in 0..<10 {
            tapChars.append(FloatingChar(
                x: nx + (rng.nextDouble() - 0.5) * 0.1,
                y: ny + (rng.nextDouble() - 0.5) * 0.05,
                birth: t,
                char: hanzi[Int(rng.nextDouble() * Double(hanzi.count))],
                driftX: (rng.nextDouble() - 0.5) * 0.012,
                size: 12.0 + rng.nextDouble() * 18.0,
                rotation: rng.nextDouble() * .pi * 2
            ))
        }
        if tapChars.count > 60 { tapChars.removeFirst(10) }
    }

    // MARK: - Drawing

    private func drawBackground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Deep warm dark — dark mahogany / lacquer tone
        let steps = 12
        for i in 0..<steps {
            let frac = Double(i) / Double(steps)
            let y0 = frac * h
            let y1 = (frac + 1.0 / Double(steps)) * h + 1
            // Dark reddish-brown base — warm Chinese interior
            let r = 0.05 + frac * 0.02 + sin(frac * .pi) * 0.01
            let g = 0.03 + frac * 0.012
            let b = 0.025 + frac * 0.008
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0)),
                with: .color(Color(red: r, green: g, blue: b))
            )
        }

        // Subtle curved roof silhouette at top
        var roof = Path()
        let roofY = h * 0.03
        roof.move(to: CGPoint(x: 0, y: 0))
        roof.addLine(to: CGPoint(x: w, y: 0))
        roof.addLine(to: CGPoint(x: w, y: roofY))
        // Gentle upward curve at edges (Chinese roof style)
        roof.addCurve(
            to: CGPoint(x: 0, y: roofY),
            control1: CGPoint(x: w * 0.7, y: roofY + h * 0.015),
            control2: CGPoint(x: w * 0.3, y: roofY + h * 0.015)
        )
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.03, green: 0.02, blue: 0.015)))

        // Eave ornament lines
        var eave = Path()
        eave.move(to: CGPoint(x: 0, y: roofY))
        eave.addCurve(
            to: CGPoint(x: w, y: roofY),
            control1: CGPoint(x: w * 0.3, y: roofY + h * 0.012),
            control2: CGPoint(x: w * 0.7, y: roofY + h * 0.012)
        )
        ctx.stroke(eave, with: .color(Color(red: 0.35, green: 0.15, blue: 0.08).opacity(0.4)), lineWidth: 1.5)

        // Floor — dark polished wood
        let floorY = h * 0.88
        let floorRect = CGRect(x: 0, y: floorY, width: w, height: h - floorY)
        ctx.fill(Path(floorRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.06, green: 0.04, blue: 0.025),
                Color(red: 0.04, green: 0.025, blue: 0.015),
            ]),
            startPoint: CGPoint(x: 0, y: floorY),
            endPoint: CGPoint(x: 0, y: h)
        ))

        // Floor reflection shimmer
        let shimmer = sin(t * 0.3) * 0.005 + 0.015
        ctx.fill(
            Path(CGRect(x: 0, y: floorY, width: w, height: 2)),
            with: .color(Color(red: 0.15, green: 0.08, blue: 0.04).opacity(shimmer + 0.02))
        )
    }

    private func drawWindows(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for win in windows {
            let cx = win.x * w
            let cy = win.y * h
            let ww = win.width * w
            let wh = win.height * h

            // Window frame — dark wood
            let frameInset: Double = 3.0
            let frameRect = CGRect(x: cx - frameInset, y: cy - frameInset, width: ww + frameInset * 2, height: wh + frameInset * 2)
            ctx.fill(Path(frameRect), with: .color(Color(red: 0.06, green: 0.04, blue: 0.025)))

            // Glass — moonlit blue
            let glassRect = CGRect(x: cx, y: cy, width: ww, height: wh)
            ctx.fill(Path(glassRect), with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.1, green: 0.13, blue: 0.22).opacity(0.6),
                    Color(red: 0.06, green: 0.08, blue: 0.15).opacity(0.4),
                ]),
                startPoint: CGPoint(x: cx, y: cy),
                endPoint: CGPoint(x: cx, y: cy + wh)
            ))

            // Ice-crack lattice pattern (simplified geometric)
            let cellsX = 4
            let cellsY = 5
            let cellW = ww / Double(cellsX)
            let cellH = wh / Double(cellsY)

            for gx in 0...cellsX {
                let lx = cx + Double(gx) * cellW
                var line = Path()
                line.move(to: CGPoint(x: lx, y: cy))
                line.addLine(to: CGPoint(x: lx, y: cy + wh))
                ctx.stroke(line, with: .color(Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.7)), lineWidth: 1.2)
            }
            for gy in 0...cellsY {
                let ly = cy + Double(gy) * cellH
                var line = Path()
                line.move(to: CGPoint(x: cx, y: ly))
                line.addLine(to: CGPoint(x: cx + ww, y: ly))
                ctx.stroke(line, with: .color(Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.7)), lineWidth: 1.2)
            }

            // Diagonal lattice within each cell
            var rng = SplitMix64(seed: UInt64(win.x * 10000 + win.y * 100))
            for gx in 0..<cellsX {
                for gy in 0..<cellsY {
                    let ox = cx + Double(gx) * cellW
                    let oy = cy + Double(gy) * cellH
                    var diag = Path()
                    if rng.nextDouble() > 0.5 {
                        diag.move(to: CGPoint(x: ox, y: oy))
                        diag.addLine(to: CGPoint(x: ox + cellW, y: oy + cellH))
                    } else {
                        diag.move(to: CGPoint(x: ox + cellW, y: oy))
                        diag.addLine(to: CGPoint(x: ox, y: oy + cellH))
                    }
                    ctx.stroke(diag, with: .color(Color(red: 0.08, green: 0.05, blue: 0.03).opacity(0.5)), lineWidth: 0.8)
                }
            }

            // Moon visible through one window
            if win.y < 0.2 {
                let moonR = ww * 0.25
                let moonX = cx + ww * 0.6
                let moonY = cy + wh * 0.35
                ctx.drawLayer { layer in
                    layer.addFilter(.blur(radius: 3))
                    layer.fill(
                        Circle().path(in: CGRect(x: moonX - moonR, y: moonY - moonR, width: moonR * 2, height: moonR * 2)),
                        with: .color(Color(red: 0.7, green: 0.72, blue: 0.8).opacity(0.35))
                    )
                }
            }

            // Moonbeam cast into the room
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 50))
                var beam = Path()
                beam.move(to: CGPoint(x: cx + ww * 0.3, y: cy + wh * 0.2))
                beam.addLine(to: CGPoint(x: cx + ww * 8, y: h * 0.88))
                beam.addLine(to: CGPoint(x: cx + ww * 4, y: h * 0.88))
                beam.addLine(to: CGPoint(x: cx + ww * 0.1, y: cy + wh * 0.6))
                beam.closeSubpath()
                layer.fill(beam, with: .color(Color(red: 0.12, green: 0.14, blue: 0.28).opacity(0.025)))
            }
        }
    }

    private func drawColumns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        let sorted = columns.sorted { $0.depth > $1.depth }
        for col in sorted {
            let depth = col.depth
            let fogAlpha = depth * 0.5
            let scale = 1.0 - depth * 0.35
            let cx = col.x * w
            let colW = 14.0 * scale
            let colTop = h * (0.04 + depth * 0.04)
            let colBot = h * 0.88

            // Column body — deep red lacquer
            let colRect = CGRect(x: cx - colW / 2, y: colTop, width: colW, height: colBot - colTop)
            let lacquerR = 0.35 - depth * 0.12
            let lacquerG = 0.06 - depth * 0.02
            let lacquerB = 0.04
            ctx.fill(Path(colRect), with: .color(
                Color(red: lacquerR, green: lacquerG, blue: lacquerB).opacity(1.0 - fogAlpha * 0.6)
            ))

            // Gold trim band at top and bottom
            let bandH = 4.0 * scale
            for bandY in [colTop, colBot - bandH] {
                let bandRect = CGRect(x: cx - colW / 2 - 1, y: bandY, width: colW + 2, height: bandH)
                ctx.fill(Path(bandRect), with: .color(
                    Color(red: 0.6, green: 0.45, blue: 0.15).opacity(0.2 * (1.0 - fogAlpha))
                ))
            }

            // Subtle highlight on column (lacquer sheen)
            let sheenX = cx - colW * 0.15
            let sheenRect = CGRect(x: sheenX, y: colTop + 10, width: colW * 0.2, height: colBot - colTop - 20)
            ctx.fill(Path(sheenRect), with: .color(
                Color(red: 0.6, green: 0.15, blue: 0.08).opacity(0.06 * (1.0 - fogAlpha))
            ))
        }
    }

    private func drawShelves(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        let sortedShelves = shelves.sorted { $0.depth > $1.depth }

        for shelf in sortedShelves {
            let depth = shelf.depth
            let fogAlpha = depth * 0.55
            let scale = 1.0 - depth * 0.35
            let shade = 0.07 + (1.0 - depth) * 0.04

            let shelfX = shelf.x * w
            let shelfBaseY = h * 0.35
            let shelfTopY = h * 0.06
            let shelfWidth = w * 0.07 * scale
            let rowCount = 4

            // Shelf back panel
            let backRect = CGRect(x: shelfX, y: shelfTopY, width: shelfWidth, height: shelfBaseY - shelfTopY + h * 0.45)
            ctx.fill(Path(backRect), with: .color(
                Color(red: shade * 0.8, green: shade * 0.55, blue: shade * 0.35).opacity(1.0 - fogAlpha * 0.5)
            ))

            for row in 0..<rowCount {
                let rowFrac = Double(row) / Double(rowCount)
                let rowY = shelfTopY + rowFrac * (shelfBaseY - shelfTopY + h * 0.4)
                let rowH = (shelfBaseY - shelfTopY + h * 0.4) / Double(rowCount)

                // Shelf plank
                let plankRect = CGRect(x: shelfX - 1, y: rowY + rowH - 2, width: shelfWidth + 2, height: 2.5)
                ctx.fill(Path(plankRect), with: .color(
                    Color(red: shade, green: shade * 0.7, blue: shade * 0.4).opacity(1.0 - fogAlpha * 0.5)
                ))

                // Scroll tubes on shelf
                let scrollsOnRow = min(shelf.scrollCount / rowCount + 1, shelf.scrollSeeds.count - row * (shelf.scrollCount / rowCount))
                let startIdx = row * (shelf.scrollCount / rowCount)
                var scrollX = shelfX + 2

                for si in 0..<max(0, scrollsOnRow) {
                    let seedIdx = startIdx + si
                    guard seedIdx < shelf.scrollSeeds.count else { break }
                    var sRng = SplitMix64(seed: shelf.scrollSeeds[seedIdx])

                    let scrollW = (2.5 + sRng.nextDouble() * 3.0) * scale
                    let scrollH = (rowH * 0.65 + sRng.nextDouble() * rowH * 0.2)
                    let scrollY = rowY + rowH - scrollH - 3

                    // Scroll coloring — bamboo / paper tones
                    let tone = sRng.nextDouble()
                    let sr: Double, sg: Double, sb: Double
                    if tone < 0.3 {
                        // Bamboo green
                        sr = 0.12; sg = 0.15 + sRng.nextDouble() * 0.06; sb = 0.08
                    } else if tone < 0.6 {
                        // Warm parchment
                        sr = 0.2 + sRng.nextDouble() * 0.08; sg = 0.16; sb = 0.08
                    } else if tone < 0.8 {
                        // Deep crimson binding
                        sr = 0.22 + sRng.nextDouble() * 0.1; sg = 0.06; sb = 0.05
                    } else {
                        // Jade-tinged
                        sr = 0.08; sg = 0.14 + sRng.nextDouble() * 0.05; sb = 0.12
                    }

                    let scrollRect = CGRect(x: scrollX, y: scrollY, width: scrollW, height: scrollH)
                    ctx.fill(Path(scrollRect), with: .color(
                        Color(red: sr, green: sg, blue: sb).opacity(1.0 - fogAlpha * 0.6)
                    ))

                    // Scroll end-cap (small circle at top — the rolled part)
                    if scrollW > 2.5 {
                        let capR = scrollW * 0.35
                        let capY = scrollY - capR * 0.4
                        ctx.fill(
                            Circle().path(in: CGRect(x: scrollX + scrollW / 2 - capR, y: capY, width: capR * 2, height: capR * 1.5)),
                            with: .color(Color(red: sr + 0.05, green: sg + 0.03, blue: sb + 0.02).opacity(0.8 * (1.0 - fogAlpha)))
                        )
                    }

                    scrollX += scrollW + 1.5
                }
            }
        }
    }

    private func drawCalligraphyDesk(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let deskY = h * 0.76
        let deskW = w * 0.28
        let deskH = h * 0.025
        let deskX = w * 0.5 - deskW / 2

        // Desk legs — elegant tapered
        for side in [-1.0, 1.0] {
            let legX = w * 0.5 + side * deskW * 0.4
            var leg = Path()
            leg.move(to: CGPoint(x: legX - 3, y: deskY + deskH))
            leg.addLine(to: CGPoint(x: legX - 2 + side * 2, y: h * 0.88))
            leg.addLine(to: CGPoint(x: legX + 2 + side * 2, y: h * 0.88))
            leg.addLine(to: CGPoint(x: legX + 3, y: deskY + deskH))
            leg.closeSubpath()
            ctx.fill(leg, with: .color(Color(red: 0.1, green: 0.06, blue: 0.03)))
        }

        // Desk surface — dark wood with red-brown lacquer
        let deskRect = CGRect(x: deskX, y: deskY, width: deskW, height: deskH)
        ctx.fill(Path(deskRect), with: .color(Color(red: 0.14, green: 0.07, blue: 0.04)))
        // Surface highlight
        let highlightRect = CGRect(x: deskX + 2, y: deskY + 1, width: deskW - 4, height: 1.5)
        ctx.fill(Path(highlightRect), with: .color(Color(red: 0.25, green: 0.12, blue: 0.06).opacity(0.3)))

        // Open scroll on desk
        let scrollCX = w * 0.5
        let scrollW2 = w * 0.08
        let scrollH2 = h * 0.04
        let scrollY2 = deskY - scrollH2

        // Scroll paper
        let scrollRect = CGRect(x: scrollCX - scrollW2, y: scrollY2, width: scrollW2 * 2, height: scrollH2)
        ctx.fill(Path(scrollRect), with: .color(Color(red: 0.75, green: 0.68, blue: 0.55).opacity(0.25)))

        // Rolled ends of scroll
        for side in [-1.0, 1.0] {
            let rollX = scrollCX + side * scrollW2
            let rollR = 2.5
            ctx.fill(
                Ellipse().path(in: CGRect(x: rollX - rollR, y: scrollY2 - 1, width: rollR * 2, height: scrollH2 + 2)),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.04).opacity(0.5))
            )
        }

        // Faint ink strokes on scroll (calligraphy practice)
        var rng = SplitMix64(seed: 0xCA111)
        for _ in 0..<6 {
            let sx = scrollCX - scrollW2 * 0.7 + rng.nextDouble() * scrollW2 * 1.4
            let sy = scrollY2 + 3 + rng.nextDouble() * (scrollH2 - 6)
            let sw = 2.0 + rng.nextDouble() * 6.0
            let sh = 0.8
            ctx.fill(
                Path(CGRect(x: sx, y: sy, width: sw, height: sh)),
                with: .color(Color(red: 0.08, green: 0.06, blue: 0.04).opacity(0.08 + rng.nextDouble() * 0.06))
            )
        }

        // Ink stone (small dark rectangle)
        let inkX = scrollCX + scrollW2 + 12.0
        let inkY = deskY - 8.0
        ctx.fill(
            RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: inkX, y: inkY, width: 12, height: 8)),
            with: .color(Color(red: 0.04, green: 0.03, blue: 0.025).opacity(0.6))
        )
        // Ink well
        ctx.fill(
            Circle().path(in: CGRect(x: inkX + 2, y: inkY + 1, width: 8, height: 6)),
            with: .color(Color(red: 0.02, green: 0.015, blue: 0.01).opacity(0.7))
        )

        // Brush resting diagonally
        var brush = Path()
        let brushX1 = inkX + 14.0
        let brushY1 = deskY - 3.0
        let brushX2 = brushX1 + 18.0
        let brushY2 = brushY1 - 10.0
        brush.move(to: CGPoint(x: brushX1, y: brushY1))
        brush.addLine(to: CGPoint(x: brushX2, y: brushY2))
        ctx.stroke(brush, with: .color(Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.4)), lineWidth: 1.5)
        // Brush tip
        ctx.fill(
            Circle().path(in: CGRect(x: brushX1 - 1.5, y: brushY1 - 1, width: 3, height: 3)),
            with: .color(Color(red: 0.05, green: 0.03, blue: 0.02).opacity(0.5))
        )

        // Small incense holder on desk
        let incX = scrollCX - scrollW2 - 20.0
        let incY = deskY - 5.0
        ctx.fill(
            RoundedRectangle(cornerRadius: 1.5).path(in: CGRect(x: incX, y: incY, width: 8, height: 5)),
            with: .color(Color(red: 0.15, green: 0.1, blue: 0.06).opacity(0.4))
        )
        // Incense stick
        var stick = Path()
        stick.move(to: CGPoint(x: incX + 4, y: incY))
        stick.addLine(to: CGPoint(x: incX + 4.5, y: incY - 18))
        ctx.stroke(stick, with: .color(Color(red: 0.35, green: 0.2, blue: 0.1).opacity(0.25)), lineWidth: 0.8)
        // Glowing tip
        let tipGlow = sin(t * 2.0) * 0.15 + 0.85
        ctx.fill(
            Circle().path(in: CGRect(x: incX + 3, y: incY - 19.5, width: 3, height: 3)),
            with: .color(Color(red: 1.0 * tipGlow, green: 0.4 * tipGlow, blue: 0.1).opacity(0.5))
        )
    }

    private func drawIncense(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            for wisp in incense {
                // Draw rising curl of smoke
                let baseX = wisp.x * w
                let baseY = wisp.baseY * h
                let segments = 20
                for i in 0..<segments {
                    let frac = Double(i) / Double(segments)
                    let rise = frac * h * 0.3
                    let curl = sin(frac * .pi * 3 + t * wisp.frequency + wisp.phase) * wisp.amplitude * w * (1.0 + frac * 2.0)
                    let x = baseX + curl
                    let y = baseY - rise
                    let alpha = wisp.alpha * (1.0 - frac) * (0.5 + sin(t * 0.5 + frac * 4) * 0.2)
                    let r = 2.0 + frac * 8.0
                    layer.fill(
                        Circle().path(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                        with: .color(Color(red: 0.6, green: 0.55, blue: 0.5).opacity(alpha))
                    )
                }
            }
        }
    }

    private func drawLanterns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Global glow layer
        ctx.drawLayer { glowLayer in
            glowLayer.addFilter(.blur(radius: 40))
            for lantern in lanterns {
                let sway = sin(t * lantern.swayRate + lantern.swayPhase) * 8.0
                let cx = lantern.x * w + sway
                let cy = lantern.y * h
                let flicker = sin(t * lantern.flickerRate + lantern.flickerPhase) * 0.1 + 0.9
                let r = lantern.size * w * 1.5
                glowLayer.fill(
                    Circle().path(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 1.0, green: 0.5, blue: 0.12).opacity(0.06 * lantern.brightness * flicker))
                )
            }
        }

        for lantern in lanterns {
            let sway = sin(t * lantern.swayRate + lantern.swayPhase) * 8.0
            let cx = lantern.x * w + sway
            let cy = lantern.y * h
            let flicker = sin(t * lantern.flickerRate + lantern.flickerPhase) * 0.1 + 0.9
            let lw = lantern.size * w
            let lh = lantern.size * w * 1.4

            // String from ceiling
            var string = Path()
            string.move(to: CGPoint(x: lantern.x * w, y: 0))
            string.addLine(to: CGPoint(x: cx, y: cy - lh / 2))
            ctx.stroke(string, with: .color(Color(red: 0.25, green: 0.15, blue: 0.08).opacity(0.2)), lineWidth: 0.5)

            // Lantern body — soft red/crimson silk
            let lanternRect = CGRect(x: cx - lw / 2, y: cy - lh / 2, width: lw, height: lh)
            ctx.fill(
                Ellipse().path(in: lanternRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color(red: 0.7 * flicker, green: 0.25 * flicker, blue: 0.08).opacity(0.6 * lantern.brightness),
                        Color(red: 0.45 * flicker, green: 0.1, blue: 0.05).opacity(0.4 * lantern.brightness),
                    ]),
                    center: CGPoint(x: cx, y: cy),
                    startRadius: 0,
                    endRadius: lw * 0.6
                )
            )

            // Gold trim rings at top and bottom
            for yOff in [-lh / 2 + 2, lh / 2 - 2] {
                let ringW = lw * 0.4
                let ringRect = CGRect(x: cx - ringW / 2, y: cy + yOff - 1, width: ringW, height: 2)
                ctx.fill(Path(ringRect), with: .color(
                    Color(red: 0.6, green: 0.45, blue: 0.15).opacity(0.25 * lantern.brightness)
                ))
            }

            // Inner flame glow
            let flameR = lw * 0.15
            ctx.fill(
                Circle().path(in: CGRect(x: cx - flameR, y: cy - flameR, width: flameR * 2, height: flameR * 2)),
                with: .color(Color(red: 1.2 * flicker, green: 0.7 * flicker, blue: 0.2).opacity(0.4 * lantern.brightness))
            )

            // Tassel at bottom
            let tasselY = cy + lh / 2
            var tassel = Path()
            tassel.move(to: CGPoint(x: cx, y: tasselY))
            tassel.addLine(to: CGPoint(x: cx, y: tasselY + lh * 0.25))
            ctx.stroke(tassel, with: .color(Color(red: 0.5, green: 0.2, blue: 0.08).opacity(0.25 * lantern.brightness)), lineWidth: 0.8)
            // Tassel fringe
            for dx in [-2.0, 0.0, 2.0] {
                var fringe = Path()
                fringe.move(to: CGPoint(x: cx + dx, y: tasselY + lh * 0.25))
                fringe.addLine(to: CGPoint(x: cx + dx, y: tasselY + lh * 0.35))
                ctx.stroke(fringe, with: .color(Color(red: 0.5, green: 0.2, blue: 0.08).opacity(0.15 * lantern.brightness)), lineWidth: 0.5)
            }
        }
    }

    private func drawCharCommon(ctx: inout GraphicsContext, size: CGSize, t: Double, ch: FloatingChar, ambient: Bool) {
        let w = size.width, h = size.height
        let age = t - ch.birth
        let cycleDuration: Double = ambient ? 28.0 : 9.0
        let effectiveAge = ambient ? fmod(age + 50, cycleDuration) : age
        guard effectiveAge > 0, effectiveAge < cycleDuration else { return }
        let progress = effectiveAge / cycleDuration

        let rise = progress * 0.35
        let x = (ch.x + sin(effectiveAge * 0.4 + ch.rotation) * ch.driftX * 8) * w
        let y = (ch.y - rise) * h
        guard y > 0, y < h else { return }

        var alpha: Double = 0.55
        if progress < 0.12 { alpha = progress / 0.12 * 0.55 }
        if progress > 0.65 { alpha = (1.0 - progress) / 0.35 * 0.55 }
        alpha = max(0, alpha) * (ambient ? 0.35 : 0.7)

        let fontSize = ch.size
        let rot = sin(effectiveAge * 0.25 + ch.rotation) * 0.15

        // Ink glow behind character — warm gold-red
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 10))
            let gr = fontSize * 1.3
            layer.fill(
                Circle().path(in: CGRect(x: x - gr / 2, y: y - gr / 2, width: gr, height: gr)),
                with: .color(Color(red: 1.0, green: 0.55, blue: 0.15).opacity(alpha * 0.25))
            )
        }

        // The character itself — drawn in warm gold-ink color
        var textCtx = ctx
        textCtx.translateBy(x: x, y: y)
        textCtx.rotate(by: Angle(radians: rot))
        let text = Text(ch.char)
            .font(.system(size: fontSize, weight: .light, design: .serif))
            .foregroundColor(Color(red: 1.0, green: 0.8, blue: 0.35).opacity(alpha))
        textCtx.draw(text, at: .zero)
    }

    private func drawAutoChars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for ch in autoChars {
            drawCharCommon(ctx: &ctx, size: size, t: t, ch: ch, ambient: true)
        }
    }

    private func drawTapChars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for ch in tapChars {
            drawCharCommon(ctx: &ctx, size: size, t: t, ch: ch, ambient: false)
        }
    }

    private func drawPetals(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for petal in petals {
            let x = fmod(petal.x + petal.driftX * t + sin(t * 0.3 + petal.phase) * 0.01 + 1.0, 1.0) * w
            let y = fmod(petal.y + petal.driftY * t + 1.0, 1.0) * h
            let rot = petal.rotation + t * petal.rotationSpeed * 0.3
            let shimmer = sin(t * 1.2 + petal.phase) * 0.2 + 0.8
            let alpha = 0.2 * shimmer

            // Draw as a small petal shape (elongated ellipse)
            var petalCtx = ctx
            petalCtx.translateBy(x: x, y: y)
            petalCtx.rotate(by: Angle(radians: rot))

            let pw = petal.size
            let ph = petal.size * 0.6
            let petalPath = Ellipse().path(in: CGRect(x: -pw / 2, y: -ph / 2, width: pw, height: ph))

            // Soft pink
            let r = 0.85 + petal.hue * 0.15
            let g = 0.45 + petal.hue * 0.1
            let b = 0.5 + petal.hue * 0.1
            petalCtx.fill(petalPath, with: .color(Color(red: r, green: g, blue: b).opacity(alpha)))
        }
    }

    private func drawFogOverlay(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 70))

            // Depth fog at top
            let topRect = CGRect(x: 0, y: 0, width: w, height: h * 0.3)
            layer.fill(
                Path(topRect),
                with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.04, green: 0.025, blue: 0.02).opacity(0.6),
                        Color.clear,
                    ]),
                    startPoint: CGPoint(x: 0, y: 0),
                    endPoint: CGPoint(x: 0, y: h * 0.3)
                )
            )

            // Drifting mist wisps
            let driftX = sin(t * 0.04) * 25
            let fogRect = CGRect(x: -30 + driftX, y: h * 0.25, width: w * 0.25, height: h * 0.5)
            layer.fill(
                Ellipse().path(in: fogRect),
                with: .color(Color(red: 0.05, green: 0.03, blue: 0.025).opacity(0.12))
            )

            let driftX2 = sin(t * 0.05 + 2) * 30
            let fogRect2 = CGRect(x: w * 0.7 + driftX2, y: h * 0.3, width: w * 0.3, height: h * 0.4)
            layer.fill(
                Ellipse().path(in: fogRect2),
                with: .color(Color(red: 0.05, green: 0.03, blue: 0.025).opacity(0.08))
            )
        }
    }
}
