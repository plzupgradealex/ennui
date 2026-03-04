// PotterGardenScene — A watercolour English cottage garden in the style of
// Beatrix Potter. Rows of cabbages and lettuces on brown earth paths,
// a stone wall, a little wooden gate, a distant cottage, butterflies,
// bees, and soft afternoon light. Tap to release a butterfly.

import SwiftUI

struct PotterGardenScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - Data types

    struct CabbageData {
        let x, y, size: Double
        let hue, saturation, brightness: Double
        let leafCount: Int
        let phase, wobbleSpeed: Double
    }

    struct PathSegment {
        let x, width, yStart, yEnd: Double
    }

    struct StoneData {
        let x, y, w, h: Double
        let grey: Double
    }

    struct FlowerData {
        let x, y, size: Double
        let hue: Double
        let petalCount: Int
        let phase: Double
    }

    struct ButterflyData {
        let startX, startY: Double
        let hue, size: Double
        let speed, phaseX, phaseY: Double
    }

    struct TapButterfly {
        let x, y, birth, hue, size: Double
    }

    @State private var cabbages: [CabbageData] = []
    @State private var paths: [PathSegment] = []
    @State private var stones: [StoneData] = []
    @State private var flowers: [FlowerData] = []
    @State private var butterflies: [ButterflyData] = []
    @State private var tapButterflies: [TapButterfly] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawDistantHills(ctx: &ctx, size: size, t: t)
                drawCottage(ctx: &ctx, size: size)
                drawStoneWall(ctx: &ctx, size: size)
                drawGardenBed(ctx: &ctx, size: size, t: t)
                drawPaths(ctx: &ctx, size: size)
                drawCabbages(ctx: &ctx, size: size, t: t)
                drawFlowers(ctx: &ctx, size: size, t: t)
                drawButterflies(ctx: &ctx, size: size, t: t)
                drawTapButterflies(ctx: &ctx, size: size, t: t)
                drawVignette(ctx: &ctx, size: size)
            }
        }
        .background(Color(red: 0.94, green: 0.93, blue: 0.88))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: generate)
        .onChange(of: interaction.tapCount) { _, _ in handleTap() }
    }

    // MARK: - Generate

    private func generate() {
        var rng = SplitMix64(seed: 1893) // The year of Peter Rabbit's first letter

        // Earth paths between the rows
        paths = [
            PathSegment(x: 0.42, width: 0.16, yStart: 0.45, yEnd: 1.0),
            PathSegment(x: 0.22, width: 0.08, yStart: 0.55, yEnd: 0.82),
            PathSegment(x: 0.7, width: 0.08, yStart: 0.52, yEnd: 0.85),
        ]

        // Cabbages — lush rows
        var cabs: [CabbageData] = []
        for row in 0..<5 {
            let rowY = 0.48 + Double(row) * 0.1
            let count = 5 + row
            for col in 0..<count {
                let cx = 0.08 + Double(col) / Double(count) * 0.84
                // Skip if on a path
                let onPath = paths.contains { cx > $0.x - $0.width / 2 && cx < $0.x + $0.width / 2 && rowY > $0.yStart }
                if onPath { continue }
                let cabSize = 25 + rng.nextDouble() * 18
                cabs.append(CabbageData(
                    x: cx + (rng.nextDouble() - 0.5) * 0.03,
                    y: rowY + (rng.nextDouble() - 0.5) * 0.02,
                    size: cabSize,
                    hue: 0.28 + rng.nextDouble() * 0.08,
                    saturation: 0.35 + rng.nextDouble() * 0.2,
                    brightness: 0.55 + rng.nextDouble() * 0.2,
                    leafCount: 5 + Int(rng.nextDouble() * 5),
                    phase: rng.nextDouble() * .pi * 2,
                    wobbleSpeed: 0.2 + rng.nextDouble() * 0.3
                ))
            }
        }
        cabbages = cabs

        // Stone wall across the top of the garden
        var stns: [StoneData] = []
        var sx = 0.0
        while sx < 1.0 {
            let sw = 0.03 + rng.nextDouble() * 0.04
            let sh = 0.015 + rng.nextDouble() * 0.012
            stns.append(StoneData(
                x: sx, y: 0.41 + (rng.nextDouble() - 0.5) * 0.006,
                w: sw, h: sh,
                grey: 0.55 + rng.nextDouble() * 0.2
            ))
            sx += sw + 0.002
        }
        // Second row of stones
        sx = 0.01
        while sx < 1.0 {
            let sw = 0.025 + rng.nextDouble() * 0.035
            let sh = 0.012 + rng.nextDouble() * 0.01
            stns.append(StoneData(
                x: sx, y: 0.395 + (rng.nextDouble() - 0.5) * 0.005,
                w: sw, h: sh,
                grey: 0.5 + rng.nextDouble() * 0.22
            ))
            sx += sw + 0.002
        }
        stones = stns

        // Small wildflowers scattered around edges
        flowers = (0..<16).map { _ in
            FlowerData(
                x: rng.nextDouble(),
                y: 0.46 + rng.nextDouble() * 0.5,
                size: 3 + rng.nextDouble() * 5,
                hue: [0.0, 0.08, 0.12, 0.6, 0.75, 0.85][Int(rng.nextDouble() * 6)],
                petalCount: 4 + Int(rng.nextDouble() * 3),
                phase: rng.nextDouble() * .pi * 2
            )
        }

        // Ambient butterflies
        butterflies = (0..<4).map { _ in
            ButterflyData(
                startX: 0.1 + rng.nextDouble() * 0.8,
                startY: 0.3 + rng.nextDouble() * 0.35,
                hue: [0.08, 0.12, 0.58, 0.8][Int(rng.nextDouble() * 4)],
                size: 4 + rng.nextDouble() * 5,
                speed: 0.015 + rng.nextDouble() * 0.01,
                phaseX: rng.nextDouble() * .pi * 2,
                phaseY: rng.nextDouble() * .pi * 2
            )
        }

        ready = true
    }

    private func handleTap() {
        var rng = SplitMix64(seed: UInt64(interaction.tapCount * 73 + 19))
        let tb = TapButterfly(
            x: 0.2 + rng.nextDouble() * 0.6,
            y: 0.3 + rng.nextDouble() * 0.4,
            birth: Date().timeIntervalSince(startDate),
            hue: rng.nextDouble(),
            size: 6 + rng.nextDouble() * 4
        )
        tapButterflies.append(tb)
        if tapButterflies.count > 8 { tapButterflies.removeFirst() }
    }

    // MARK: - Drawing

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let warmShift = sin(t * 0.015) * 0.01
        // Warm English afternoon sky
        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.62 + warmShift, green: 0.72, blue: 0.82),
                        Color(red: 0.78, green: 0.82 + warmShift, blue: 0.85),
                        Color(red: 0.88, green: 0.88, blue: 0.84),
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: 0),
                    endPoint: CGPoint(x: size.width / 2, y: size.height * 0.45)
                 ))

        // Soft watercolour clouds
        var rng = SplitMix64(seed: 4444)
        for _ in 0..<5 {
            let cx = rng.nextDouble() * size.width
            let cy = rng.nextDouble() * size.height * 0.25 + size.height * 0.02
            let cw = 60 + rng.nextDouble() * 120
            let ch = 20 + rng.nextDouble() * 30
            let drift = sin(t * 0.008 + rng.nextDouble() * 6) * 15
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: cw * 0.35))
                l.fill(Ellipse().path(in: CGRect(x: cx + drift - cw / 2, y: cy - ch / 2, width: cw, height: ch)),
                       with: .color(Color.white.opacity(0.15)))
            }
        }
    }

    private func drawDistantHills(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Soft green rolling hills behind the wall
        let hillY = size.height * 0.38
        var hill = Path()
        hill.move(to: CGPoint(x: 0, y: hillY + 10))
        for x in stride(from: 0.0, through: size.width, by: 4) {
            let y = hillY + sin(x * 0.008 + 1.5) * 18 + cos(x * 0.013) * 10
            hill.addLine(to: CGPoint(x: x, y: y))
        }
        hill.addLine(to: CGPoint(x: size.width, y: size.height * 0.45))
        hill.addLine(to: CGPoint(x: 0, y: size.height * 0.45))
        hill.closeSubpath()

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 3))
            l.fill(hill, with: .color(Color(red: 0.45, green: 0.58, blue: 0.38).opacity(0.5)))
        }

        // Distant trees as soft blobs
        var rng = SplitMix64(seed: 3333)
        for _ in 0..<8 {
            let tx = rng.nextDouble() * size.width
            let ty = hillY - 5 + sin(tx * 0.01) * 12
            let ts = 12 + rng.nextDouble() * 20
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: ts * 0.4))
                l.fill(Ellipse().path(in: CGRect(x: tx - ts / 2, y: ty - ts * 0.6, width: ts, height: ts * 0.8)),
                       with: .color(Color(red: 0.3, green: 0.48, blue: 0.3).opacity(0.35)))
            }
        }
    }

    private func drawCottage(ctx: inout GraphicsContext, size: CGSize) {
        // Small distant cottage above the wall
        let cx = size.width * 0.78
        let cy = size.height * 0.34
        let cw: Double = 45
        let ch: Double = 30

        // Walls
        ctx.fill(Rectangle().path(in: CGRect(x: cx - cw / 2, y: cy - ch / 2, width: cw, height: ch)),
                 with: .color(Color(red: 0.82, green: 0.75, blue: 0.65).opacity(0.6)))

        // Roof
        var roof = Path()
        roof.move(to: CGPoint(x: cx - cw * 0.6, y: cy - ch / 2))
        roof.addLine(to: CGPoint(x: cx, y: cy - ch))
        roof.addLine(to: CGPoint(x: cx + cw * 0.6, y: cy - ch / 2))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.55, green: 0.35, blue: 0.25).opacity(0.5)))

        // Door
        ctx.fill(Rectangle().path(in: CGRect(x: cx - 4, y: cy, width: 8, height: ch / 2)),
                 with: .color(Color(red: 0.35, green: 0.25, blue: 0.18).opacity(0.45)))

        // Window
        ctx.fill(Rectangle().path(in: CGRect(x: cx + 7, y: cy - 8, width: 8, height: 7)),
                 with: .color(Color(red: 0.65, green: 0.72, blue: 0.8).opacity(0.4)))

        // Chimney
        ctx.fill(Rectangle().path(in: CGRect(x: cx + cw * 0.25, y: cy - ch - 8, width: 6, height: 14)),
                 with: .color(Color(red: 0.55, green: 0.38, blue: 0.3).opacity(0.45)))
    }

    private func drawStoneWall(ctx: inout GraphicsContext, size: CGSize) {
        for stone in stones {
            let sx = stone.x * size.width
            let sy = stone.y * size.height
            let sw = stone.w * size.width
            let sh = stone.h * size.height
            let g = stone.grey
            ctx.fill(RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: sx, y: sy, width: sw, height: sh)),
                     with: .color(Color(red: g, green: g - 0.02, blue: g - 0.05).opacity(0.7)))
        }

        // Wooden gate in the centre
        let gateX = size.width * 0.42
        let gateY = size.height * 0.39
        let gateW: Double = size.width * 0.1
        let gateH: Double = size.height * 0.06
        let woodCol = Color(red: 0.45, green: 0.32, blue: 0.2).opacity(0.65)

        // Posts
        ctx.fill(Rectangle().path(in: CGRect(x: gateX - 3, y: gateY, width: 5, height: gateH + 4)),
                 with: .color(woodCol))
        ctx.fill(Rectangle().path(in: CGRect(x: gateX + gateW - 2, y: gateY, width: 5, height: gateH + 4)),
                 with: .color(woodCol))

        // Horizontal bars
        for barY in [gateY + 4, gateY + gateH - 6] {
            ctx.fill(Rectangle().path(in: CGRect(x: gateX, y: barY, width: gateW, height: 3)),
                     with: .color(woodCol))
        }
        // Vertical slats
        for i in 0..<5 {
            let slX = gateX + 4 + Double(i) * (gateW - 8) / 4
            ctx.fill(Rectangle().path(in: CGRect(x: slX, y: gateY + 3, width: 2, height: gateH - 3)),
                     with: .color(woodCol))
        }
    }

    private func drawGardenBed(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Rich brown earth
        let bedRect = CGRect(x: 0, y: size.height * 0.44, width: size.width, height: size.height * 0.56)
        ctx.fill(Rectangle().path(in: bedRect),
                 with: .linearGradient(
                    Gradient(colors: [
                        Color(red: 0.42, green: 0.3, blue: 0.2),
                        Color(red: 0.38, green: 0.26, blue: 0.16),
                        Color(red: 0.32, green: 0.22, blue: 0.13),
                    ]),
                    startPoint: CGPoint(x: size.width / 2, y: bedRect.minY),
                    endPoint: CGPoint(x: size.width / 2, y: bedRect.maxY)
                 ))

        // Earth texture — small speckles
        var rng = SplitMix64(seed: 6666)
        for _ in 0..<80 {
            let ex = rng.nextDouble() * size.width
            let ey = size.height * 0.45 + rng.nextDouble() * size.height * 0.55
            let es = 1 + rng.nextDouble() * 3
            let eb = 0.25 + rng.nextDouble() * 0.15
            ctx.fill(Ellipse().path(in: CGRect(x: ex, y: ey, width: es, height: es * 0.7)),
                     with: .color(Color(red: eb, green: eb * 0.75, blue: eb * 0.5).opacity(0.25)))
        }
    }

    private func drawPaths(ctx: inout GraphicsContext, size: CGSize) {
        for path in paths {
            let px = path.x * size.width - path.width * size.width / 2
            let pw = path.width * size.width
            let py = path.yStart * size.height
            let ph = (path.yEnd - path.yStart) * size.height

            // Lighter earth for the path
            ctx.fill(Rectangle().path(in: CGRect(x: px, y: py, width: pw, height: ph)),
                     with: .color(Color(red: 0.52, green: 0.4, blue: 0.28).opacity(0.45)))

            // Path edges — slightly darker
            ctx.fill(Rectangle().path(in: CGRect(x: px - 1, y: py, width: 2, height: ph)),
                     with: .color(Color(red: 0.35, green: 0.25, blue: 0.15).opacity(0.2)))
            ctx.fill(Rectangle().path(in: CGRect(x: px + pw - 1, y: py, width: 2, height: ph)),
                     with: .color(Color(red: 0.35, green: 0.25, blue: 0.15).opacity(0.2)))
        }
    }

    // MARK: - Cabbages (the heart of the scene)

    private func drawCabbages(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for cab in cabbages {
            let cx = cab.x * size.width
            let cy = cab.y * size.height
            let s = cab.size
            let wobble = sin(t * cab.wobbleSpeed + cab.phase) * 1.2

            // Outer leaves — large, ruffled, darker green
            for i in 0..<cab.leafCount {
                let angle = Double(i) / Double(cab.leafCount) * .pi * 2 + wobble * 0.05
                let leafDist = s * 0.4 + sin(Double(i) * 2.3 + cab.phase) * s * 0.1
                let lx = cx + cos(angle) * leafDist
                let ly = cy + sin(angle) * leafDist * 0.65
                let leafW = s * 0.45 + sin(Double(i) * 1.7) * s * 0.08
                let leafH = s * 0.3 + cos(Double(i) * 2.1) * s * 0.06

                // Leaf body
                let leafHue = cab.hue + sin(Double(i) * 0.8) * 0.03
                let leafBri = cab.brightness - 0.08 + sin(Double(i) * 1.3) * 0.05
                ctx.fill(Ellipse().path(in: CGRect(x: lx - leafW / 2, y: ly - leafH / 2, width: leafW, height: leafH)),
                         with: .color(Color(hue: leafHue, saturation: cab.saturation, brightness: leafBri).opacity(0.7)))

                // Leaf vein (subtle dark line)
                var vein = Path()
                vein.move(to: CGPoint(x: lx, y: ly - leafH * 0.3))
                vein.addLine(to: CGPoint(x: lx + cos(angle) * leafW * 0.15, y: ly + leafH * 0.25))
                ctx.stroke(vein, with: .color(Color(hue: cab.hue, saturation: 0.4, brightness: 0.35).opacity(0.2)),
                           lineWidth: 0.6)
            }

            // Inner heart — brighter, tighter leaves curling inward
            let heartSize = s * 0.35
            for ring in 0..<3 {
                let ringR = heartSize * (1.0 - Double(ring) * 0.25)
                let ringBri = cab.brightness + Double(ring) * 0.06
                let ringSat = cab.saturation - Double(ring) * 0.04
                ctx.fill(Ellipse().path(in: CGRect(x: cx - ringR / 2, y: cy - ringR * 0.35, width: ringR, height: ringR * 0.7)),
                         with: .color(Color(hue: cab.hue + 0.02, saturation: ringSat, brightness: ringBri).opacity(0.65)))
            }

            // Dark outline strokes on the outer leaves (Beatrix Potter ink lines)
            for i in 0..<cab.leafCount {
                let angle = Double(i) / Double(cab.leafCount) * .pi * 2 + wobble * 0.05
                let leafDist = s * 0.4 + sin(Double(i) * 2.3 + cab.phase) * s * 0.1
                let lx = cx + cos(angle) * leafDist
                let ly = cy + sin(angle) * leafDist * 0.65
                let leafW = s * 0.45 + sin(Double(i) * 1.7) * s * 0.08
                let leafH = s * 0.3 + cos(Double(i) * 2.1) * s * 0.06

                ctx.stroke(Ellipse().path(in: CGRect(x: lx - leafW / 2, y: ly - leafH / 2, width: leafW, height: leafH)),
                           with: .color(Color(red: 0.15, green: 0.2, blue: 0.1).opacity(0.2)),
                           lineWidth: 0.8)
            }
        }
    }

    private func drawFlowers(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for flower in flowers {
            let fx = flower.x * size.width
            let fy = flower.y * size.height
            let s = flower.size
            let bob = sin(t * 0.4 + flower.phase) * 1.5

            // Stem
            ctx.fill(Rectangle().path(in: CGRect(x: fx - 0.5, y: fy + bob, width: 1.2, height: s * 1.5)),
                     with: .color(Color(red: 0.3, green: 0.45, blue: 0.25).opacity(0.5)))

            // Petals
            for p in 0..<flower.petalCount {
                let pAngle = Double(p) / Double(flower.petalCount) * .pi * 2 + t * 0.03
                let px = fx + cos(pAngle) * s * 0.4
                let py = fy + bob + sin(pAngle) * s * 0.35
                ctx.fill(Ellipse().path(in: CGRect(x: px - s * 0.2, y: py - s * 0.15, width: s * 0.4, height: s * 0.3)),
                         with: .color(Color(hue: flower.hue, saturation: 0.45, brightness: 0.75).opacity(0.55)))
            }
            // Centre
            ctx.fill(Ellipse().path(in: CGRect(x: fx - s * 0.12, y: fy + bob - s * 0.1, width: s * 0.24, height: s * 0.2)),
                     with: .color(Color(red: 0.85, green: 0.75, blue: 0.3).opacity(0.5)))
        }
    }

    // MARK: - Butterflies

    private func drawButterflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for bf in butterflies {
            let bx = (bf.startX + sin(t * bf.speed * 3.0 + bf.phaseX) * 0.12) * size.width
            let by = (bf.startY + cos(t * bf.speed * 2.3 + bf.phaseY) * 0.08) * size.height
            drawOneButterfly(ctx: &ctx, x: bx, y: by, size: bf.size, hue: bf.hue, t: t, phase: bf.phaseX)
        }
    }

    private func drawTapButterflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for tb in tapButterflies {
            let age = t - tb.birth
            guard age < 10.0 else { continue }
            let fade = 1.0 - age / 10.0
            let bx = (tb.x + sin(age * 0.4) * 0.08) * size.width
            let by = (tb.y - age * 0.015) * size.height
            ctx.opacity = fade
            drawOneButterfly(ctx: &ctx, x: bx, y: by, size: tb.size, hue: tb.hue, t: t, phase: age)
            ctx.opacity = 1.0
        }
    }

    private func drawOneButterfly(ctx: inout GraphicsContext, x: Double, y: Double, size: Double, hue: Double, t: Double, phase: Double) {
        let wingFlap = sin(t * 5.0 + phase) * 0.4
        let wingW = size * (0.7 + wingFlap * 0.3)
        let wingH = size * 0.8

        // Left wing
        ctx.fill(Ellipse().path(in: CGRect(x: x - wingW - 1, y: y - wingH / 2, width: wingW, height: wingH)),
                 with: .color(Color(hue: hue, saturation: 0.5, brightness: 0.7).opacity(0.55)))
        // Right wing
        ctx.fill(Ellipse().path(in: CGRect(x: x + 1, y: y - wingH / 2, width: wingW, height: wingH)),
                 with: .color(Color(hue: hue, saturation: 0.5, brightness: 0.7).opacity(0.55)))
        // Body
        ctx.fill(Ellipse().path(in: CGRect(x: x - 0.8, y: y - size * 0.3, width: 1.6, height: size * 0.6)),
                 with: .color(Color(red: 0.2, green: 0.15, blue: 0.1).opacity(0.5)))
    }

    // MARK: - Vignette (book page edge feel)

    private func drawVignette(ctx: inout GraphicsContext, size: CGSize) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            let edge: Double = 25
            l.fill(Rectangle().path(in: CGRect(x: 0, y: -15, width: size.width, height: edge)),
                   with: .color(Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.15)))
            l.fill(Rectangle().path(in: CGRect(x: 0, y: size.height - edge + 15, width: size.width, height: edge)),
                   with: .color(Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.2)))
            l.fill(Rectangle().path(in: CGRect(x: -15, y: 0, width: edge, height: size.height)),
                   with: .color(Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.12)))
            l.fill(Rectangle().path(in: CGRect(x: size.width - edge + 15, y: 0, width: edge, height: size.height)),
                   with: .color(Color(red: 0.82, green: 0.78, blue: 0.72).opacity(0.12)))
        }
    }
}
