import SwiftUI

// Shimizu Evening — A quiet residential neighbourhood in a small
// Japanese city on a rainy evening. Inspired by the warm, gentle
// aesthetic of 1970s Shizuoka anime backgrounds: deep blue dusk, a
// peaked wooden house behind a concrete block wall, a corner shop
// with a striped awning, utility poles strung with wires, rounded
// bushes drawn with scratchy leaf marks, warm yellow windows glowing
// behind rain, puddles collecting on the street, and that particular
// deep-blue-to-indigo sky you only see in hand-painted cel animation.
//
// Tap to send a splash rippling through the nearest puddle.
//
// Seed: 1990.

struct ShimizuEveningScene: View {
    @ObservedObject var interaction: InteractionState

    @State private var startDate = Date()

    @State private var stars: [StarData] = []
    @State private var raindrops: [RaindropData] = []
    @State private var bushes: [BushData] = []
    @State private var puddleSplashes: [PuddleSplash] = []
    @State private var ready = false

    struct StarData {
        let x, y, brightness, size, phase: Double
    }

    struct RaindropData {
        let x, speed, length, phase: Double
    }

    struct BushData {
        let x, y, rx, ry: Double
        let scratches: [(dx: Double, dy: Double, angle: Double)]
    }

    struct PuddleSplash {
        let birth: Double
        let x, y: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                let w = size.width
                let h = size.height
                drawSky(ctx: ctx, w: w, h: h, t: now)
                drawClouds(ctx: ctx, w: w, h: h, t: now)
                drawStars(ctx: ctx, w: w, h: h, t: now)
                drawDistantCity(ctx: ctx, w: w, h: h)
                drawUtilityPoles(ctx: ctx, w: w, h: h)
                drawWires(ctx: ctx, w: w, h: h, t: now)
                drawMainHouse(ctx: ctx, w: w, h: h, t: now)
                drawWall(ctx: ctx, w: w, h: h)
                drawShop(ctx: ctx, w: w, h: h, t: now)
                drawBushes(ctx: ctx, w: w, h: h, t: now)
                drawGround(ctx: ctx, w: w, h: h, t: now)
                drawPuddles(ctx: ctx, w: w, h: h, t: now)
                drawRain(ctx: ctx, w: w, h: h, t: now)
                drawStreetLamp(ctx: ctx, w: w, h: h, t: now)
                drawVignette(ctx: ctx, w: w, h: h)
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .allowedDynamicRange(.high)
        }
        .onAppear { generate() }
        .onChange(of: interaction.tapCount) { _, _ in addSplash() }
    }

    // MARK: - Generation

    private func generate() {
        var rng = SplitMix64(seed: 1990)

        // Stars (faintly visible through clouds)
        var s: [StarData] = []
        for _ in 0..<60 {
            s.append(StarData(
                x: .random(in: 0...1, using: &rng),
                y: .random(in: 0...0.35, using: &rng),
                brightness: .random(in: 0.05...0.25, using: &rng),
                size: .random(in: 0.4...1.2, using: &rng),
                phase: .random(in: 0...(.pi * 2), using: &rng)
            ))
        }
        stars = s

        // Raindrops
        var rd: [RaindropData] = []
        for _ in 0..<200 {
            rd.append(RaindropData(
                x: .random(in: -0.1...1.1, using: &rng),
                speed: .random(in: 0.6...1.4, using: &rng),
                length: .random(in: 12...30, using: &rng),
                phase: .random(in: 0...1, using: &rng)
            ))
        }
        raindrops = rd

        // Bushes
        var b: [BushData] = []
        let bushPositions: [(Double, Double, Double, Double)] = [
            (0.12, 0.68, 35, 28), (0.20, 0.69, 28, 22),
            (0.62, 0.67, 32, 26), (0.72, 0.68, 38, 30),
            (0.88, 0.67, 30, 24),
        ]
        for (bx, by, brx, bry) in bushPositions {
            var scratches: [(dx: Double, dy: Double, angle: Double)] = []
            for _ in 0..<Int.random(in: 6...12, using: &rng) {
                scratches.append((
                    dx: .random(in: -0.7...0.7, using: &rng),
                    dy: .random(in: -0.6...0.6, using: &rng),
                    angle: .random(in: -0.4...0.4, using: &rng)
                ))
            }
            b.append(BushData(x: bx, y: by, rx: brx, ry: bry, scratches: scratches))
        }
        bushes = b

        ready = true
    }

    private func addSplash() {
        let loc = interaction.tapLocation ?? CGPoint(x: 0.5, y: 0.8)
        let now = Date().timeIntervalSince(startDate)
        puddleSplashes.append(PuddleSplash(birth: now, x: loc.x, y: loc.y))
        if puddleSplashes.count > 12 { puddleSplashes.removeFirst() }
    }

    // MARK: - Sky

    private func drawSky(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        // Deep blue gradient — the particular Chibi Maruko blue dusk
        let skyGrad = Gradient(colors: [
            Color(red: 0.14, green: 0.18, blue: 0.42),  // deep indigo top
            Color(red: 0.20, green: 0.26, blue: 0.52),  // mid blue
            Color(red: 0.28, green: 0.36, blue: 0.58),  // lighter blue
            Color(red: 0.35, green: 0.42, blue: 0.58),  // hazy horizon
        ])
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(skyGrad, startPoint: .init(x: w / 2, y: 0), endPoint: .init(x: w / 2, y: h * 0.55))
        )
    }

    // MARK: - Clouds (wavy layered rain clouds like the anime)

    private func drawClouds(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        // Thick wavy cloud bank — draw several overlapping bumpy rows
        let cloudColor = Color(red: 0.32, green: 0.38, blue: 0.52)
        let drift = t * 3.0

        for row in 0..<3 {
            let baseY = h * (0.05 + Double(row) * 0.06)
            let alpha = 0.6 - Double(row) * 0.15
            var path = Path()
            path.move(to: CGPoint(x: -20, y: baseY + 40))
            // Wavy top edge
            let step = 30.0
            var x = -20.0
            while x <= w + 40 {
                let wobble = sin((x + drift + Double(row) * 80) * 0.018) * 18
                    + sin((x + drift * 0.7 + Double(row) * 120) * 0.032) * 10
                path.addLine(to: CGPoint(x: x, y: baseY + wobble))
                x += step
            }
            // Close along bottom
            path.addLine(to: CGPoint(x: w + 40, y: baseY + 60))
            path.addLine(to: CGPoint(x: -20, y: baseY + 60))
            path.closeSubpath()
            ctx.fill(path, with: .color(cloudColor.opacity(alpha)))
        }
    }

    // MARK: - Stars (simple shapes with circular halos, barely visible)

    private func drawStars(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for star in stars {
            let sx = star.x * w
            let sy = star.y * h
            let twinkle = sin(t * 0.5 + star.phase) * 0.5 + 0.5
            let alpha = star.brightness * twinkle

            // Halo circle
            let haloR = star.size * 4
            let haloRect = CGRect(x: sx - haloR, y: sy - haloR, width: haloR * 2, height: haloR * 2)
            ctx.fill(Ellipse().path(in: haloRect), with: .color(Color(red: 0.6, green: 0.7, blue: 0.9).opacity(alpha * 0.3)))

            // Star dot
            let sr = star.size
            let rect = CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)
            ctx.fill(Ellipse().path(in: rect), with: .color(Color(red: 0.75, green: 0.82, blue: 1.0).opacity(alpha)))
        }
    }

    // MARK: - Distant city silhouette

    private func drawDistantCity(ctx: GraphicsContext, w: Double, h: Double) {
        let baseY = h * 0.42
        let cityColor = Color(red: 0.22, green: 0.28, blue: 0.48)

        var path = Path()
        path.move(to: CGPoint(x: 0, y: baseY + 20))

        // Simple blocky silhouette of distant buildings
        let buildings: [(x: Double, bw: Double, bh: Double)] = [
            (0.02, 0.04, 25), (0.07, 0.03, 35), (0.11, 0.05, 20),
            (0.17, 0.03, 40), (0.21, 0.04, 30), (0.27, 0.06, 18),
            (0.35, 0.03, 45), (0.39, 0.05, 28), (0.46, 0.04, 35),
            (0.52, 0.03, 42), (0.57, 0.05, 22), (0.63, 0.04, 38),
            (0.68, 0.03, 30), (0.74, 0.06, 25), (0.82, 0.03, 48),
            (0.86, 0.05, 32), (0.93, 0.04, 28),
        ]
        for b in buildings {
            let bx = b.x * w
            let bWidth = b.bw * w
            path.addLine(to: CGPoint(x: bx, y: baseY + 20))
            path.addLine(to: CGPoint(x: bx, y: baseY + 20 - b.bh))
            path.addLine(to: CGPoint(x: bx + bWidth, y: baseY + 20 - b.bh))
            path.addLine(to: CGPoint(x: bx + bWidth, y: baseY + 20))
        }
        path.addLine(to: CGPoint(x: w, y: baseY + 20))
        path.addLine(to: CGPoint(x: w, y: baseY + 40))
        path.addLine(to: CGPoint(x: 0, y: baseY + 40))
        path.closeSubpath()

        ctx.fill(path, with: .color(cityColor.opacity(0.4)))
    }

    // MARK: - Utility poles

    private func drawUtilityPoles(ctx: GraphicsContext, w: Double, h: Double) {
        let poleColor = Color(red: 0.35, green: 0.32, blue: 0.28)

        // Left pole
        let p1x = w * 0.15
        let p1Top = h * 0.22
        let p1Bot = h * 0.76
        // Main pole shaft
        ctx.fill(Rectangle().path(in: CGRect(x: p1x - 2.5, y: p1Top, width: 5, height: p1Bot - p1Top)),
                 with: .color(poleColor))
        // Crossbar
        let cbY = p1Top + 12
        ctx.fill(Rectangle().path(in: CGRect(x: p1x - 22, y: cbY, width: 44, height: 3)),
                 with: .color(poleColor))
        // Insulators (small bumps)
        for dx in [-18.0, -8.0, 8.0, 18.0] {
            let ir = CGRect(x: p1x + dx - 2, y: cbY - 4, width: 4, height: 4)
            ctx.fill(Ellipse().path(in: ir), with: .color(Color(red: 0.5, green: 0.55, blue: 0.45)))
        }

        // Right pole
        let p2x = w * 0.82
        let p2Top = h * 0.25
        let p2Bot = h * 0.76
        ctx.fill(Rectangle().path(in: CGRect(x: p2x - 2.5, y: p2Top, width: 5, height: p2Bot - p2Top)),
                 with: .color(poleColor))
        let cb2Y = p2Top + 10
        ctx.fill(Rectangle().path(in: CGRect(x: p2x - 20, y: cb2Y, width: 40, height: 3)),
                 with: .color(poleColor))
        for dx in [-16.0, -6.0, 6.0, 16.0] {
            let ir = CGRect(x: p2x + dx - 2, y: cb2Y - 4, width: 4, height: 4)
            ctx.fill(Ellipse().path(in: ir), with: .color(Color(red: 0.5, green: 0.55, blue: 0.45)))
        }
    }

    // MARK: - Wires between poles (slight sag, gentle sway)

    private func drawWires(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let p1x = w * 0.15
        let p2x = w * 0.82
        let wireColor = Color(red: 0.25, green: 0.25, blue: 0.30)

        for i in 0..<3 {
            let y1 = h * 0.22 + 14 + Double(i) * 8
            let y2 = h * 0.25 + 12 + Double(i) * 8
            var path = Path()
            path.move(to: CGPoint(x: p1x, y: y1))
            let steps = 30
            for s in 1...steps {
                let frac = Double(s) / Double(steps)
                let wx = p1x + (p2x - p1x) * frac
                let baseY = y1 + (y2 - y1) * frac
                // Catenary sag
                let sag = sin(frac * .pi) * 20
                // Gentle wind sway
                let sway = sin(t * 0.8 + frac * 4 + Double(i)) * 1.5
                path.addLine(to: CGPoint(x: wx, y: baseY + sag + sway))
            }
            ctx.stroke(path, with: .color(wireColor.opacity(0.6)), lineWidth: 1.2)
        }
    }

    // MARK: - Main house (peaked gable, vertical wood planks, blue roof)

    private func drawMainHouse(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let houseX = w * 0.35
        let houseW = w * 0.32
        let houseTop = h * 0.38
        let houseBot = h * 0.72
        let roofPeak = h * 0.28
        let roofExtrude = 18.0

        // House body (warm tan wood)
        let bodyColor = Color(red: 0.55, green: 0.48, blue: 0.38)
        ctx.fill(Rectangle().path(in: CGRect(x: houseX, y: houseTop, width: houseW, height: houseBot - houseTop)),
                 with: .color(bodyColor))

        // Vertical plank lines
        let plankColor = Color(red: 0.42, green: 0.36, blue: 0.28)
        var px = houseX + 12
        while px < houseX + houseW - 5 {
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: px, y: houseTop + 2))
                p.addLine(to: CGPoint(x: px, y: houseBot))
            }, with: .color(plankColor.opacity(0.4)), lineWidth: 0.8)
            px += 14
        }

        // Roof (dark blue-grey, peaked gable)
        let roofColor = Color(red: 0.25, green: 0.32, blue: 0.48)
        var roof = Path()
        roof.move(to: CGPoint(x: houseX - roofExtrude, y: houseTop + 4))
        roof.addLine(to: CGPoint(x: houseX + houseW / 2, y: roofPeak))
        roof.addLine(to: CGPoint(x: houseX + houseW + roofExtrude, y: houseTop + 4))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(roofColor))

        // Roof shingle marks (thin lighter lines in a grid)
        let shingleColor = Color(red: 0.45, green: 0.52, blue: 0.65)
        // Horizontal rows
        let roofH = houseTop + 4 - roofPeak
        for row in stride(from: 0.15, through: 0.95, by: 0.12) {
            let ry = roofPeak + roofH * row
            // Left slope
            let leftFrac = (ry - roofPeak) / roofH
            let lx1 = houseX + houseW / 2 - (houseW / 2 + roofExtrude) * leftFrac
            let lx2 = houseX + houseW / 2
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: lx1, y: ry))
                p.addLine(to: CGPoint(x: lx2 - 5, y: ry))
            }, with: .color(shingleColor.opacity(0.3)), lineWidth: 0.6)
            // Right slope
            let rx2 = houseX + houseW / 2 + (houseW / 2 + roofExtrude) * leftFrac
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: lx2 + 5, y: ry))
                p.addLine(to: CGPoint(x: rx2, y: ry))
            }, with: .color(shingleColor.opacity(0.3)), lineWidth: 0.6)
        }

        // Awning over lower window area
        let awningY = h * 0.52
        let awningColor = Color(red: 0.45, green: 0.55, blue: 0.62)
        ctx.fill(Rectangle().path(in: CGRect(x: houseX - 4, y: awningY, width: houseW + 8, height: 5)),
                 with: .color(awningColor))

        // Windows (warm yellow glow)
        let windowColor = Color(red: 0.85, green: 0.75, blue: 0.30)
        let winFlicker = sin(t * 0.3) * 0.05

        // Upper windows (two, in the gable triangle area)
        let gableWinY = houseTop - 15
        let gableWinW = 20.0
        let gableWinH = 14.0
        for i in 0..<3 {
            let wx = houseX + houseW * 0.25 + Double(i) * (houseW * 0.22)
            ctx.fill(Rectangle().path(in: CGRect(x: wx, y: gableWinY, width: gableWinW, height: gableWinH)),
                     with: .color(windowColor.opacity(0.0))) // dark upper windows
        }

        // Lower large window (warm glow)
        let lWinX = houseX + houseW * 0.15
        let lWinW = houseW * 0.7
        let lWinH = 32.0
        let lWinY = awningY + 10
        let winRect = CGRect(x: lWinX, y: lWinY, width: lWinW, height: lWinH)
        ctx.fill(Rectangle().path(in: winRect), with: .color(windowColor.opacity(0.75 + winFlicker)))

        // Window frame lines
        let frameColor = Color(red: 0.55, green: 0.50, blue: 0.35)
        // Vertical divider
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: lWinX + lWinW / 2, y: lWinY))
            p.addLine(to: CGPoint(x: lWinX + lWinW / 2, y: lWinY + lWinH))
        }, with: .color(frameColor.opacity(0.6)), lineWidth: 1.5)

        // Gable triangle fill (lighter tan)
        let gableColor = Color(red: 0.62, green: 0.56, blue: 0.45)
        var gable = Path()
        gable.move(to: CGPoint(x: houseX + 3, y: houseTop + 2))
        gable.addLine(to: CGPoint(x: houseX + houseW / 2, y: roofPeak + 6))
        gable.addLine(to: CGPoint(x: houseX + houseW - 3, y: houseTop + 2))
        gable.closeSubpath()
        ctx.fill(gable, with: .color(gableColor.opacity(0.4)))

        // Small vent in gable peak
        let ventX = houseX + houseW / 2
        let ventY = roofPeak + 22
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: ventX - 5, y: ventY))
            p.addLine(to: CGPoint(x: ventX - 2, y: ventY))
            p.move(to: CGPoint(x: ventX, y: ventY))
            p.addLine(to: CGPoint(x: ventX + 2, y: ventY))
            p.move(to: CGPoint(x: ventX + 5, y: ventY))
            p.addLine(to: CGPoint(x: ventX + 7, y: ventY))
        }, with: .color(plankColor.opacity(0.6)), lineWidth: 1.5)
    }

    // MARK: - Concrete block wall

    private func drawWall(ctx: GraphicsContext, w: Double, h: Double) {
        let wallY = h * 0.66
        let wallH = h * 0.10
        let wallColor = Color(red: 0.50, green: 0.58, blue: 0.58)

        // Wall body
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: wallY, width: w, height: wallH)),
                 with: .color(wallColor))

        // Block grid lines
        let blockW = 28.0
        let blockH = wallH / 3.0
        let lineColor = Color(red: 0.40, green: 0.48, blue: 0.50)

        // Horizontal lines
        for row in 0..<4 {
            let ly = wallY + Double(row) * blockH
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: ly))
                p.addLine(to: CGPoint(x: w, y: ly))
            }, with: .color(lineColor.opacity(0.4)), lineWidth: 0.8)
        }

        // Vertical lines (staggered like real block wall)
        for row in 0..<3 {
            let ly = wallY + Double(row) * blockH
            let offset = (row % 2 == 0) ? 0.0 : blockW / 2.0
            var vx = offset
            while vx < w {
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: vx, y: ly))
                    p.addLine(to: CGPoint(x: vx, y: ly + blockH))
                }, with: .color(lineColor.opacity(0.3)), lineWidth: 0.6)
                vx += blockW
            }
        }

        // Wall cap
        let capColor = Color(red: 0.42, green: 0.48, blue: 0.50)
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: wallY - 3, width: w, height: 4)),
                 with: .color(capColor))

        // Gate opening (center gap in wall)
        let gateX = w * 0.48
        let gateW = w * 0.08
        let gateColor = Color(red: 0.22, green: 0.28, blue: 0.38)
        ctx.fill(Rectangle().path(in: CGRect(x: gateX, y: wallY - 3, width: gateW, height: wallH + 3)),
                 with: .color(gateColor.opacity(0.7)))
        // Gate bars
        for i in 0..<4 {
            let bx = gateX + 6 + Double(i) * (gateW - 12) / 3.0
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: bx, y: wallY + 2))
                p.addLine(to: CGPoint(x: bx, y: wallY + wallH - 2))
            }, with: .color(Color(red: 0.18, green: 0.18, blue: 0.22).opacity(0.7)), lineWidth: 1.5)
        }
    }

    // MARK: - Corner shop (striped awning, colourful panels)

    private func drawShop(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let shopX = w * 0.72
        let shopW = w * 0.24
        let shopTop = h * 0.40
        let shopBot = h * 0.66

        // Shop body
        let bodyColor = Color(red: 0.62, green: 0.58, blue: 0.52)
        ctx.fill(Rectangle().path(in: CGRect(x: shopX, y: shopTop, width: shopW, height: shopBot - shopTop)),
                 with: .color(bodyColor))

        // Colourful upper panels (green, yellow, orange like the anime)
        let panelY = shopTop + 5
        let panelH = 30.0
        let panelColors: [Color] = [
            Color(red: 0.55, green: 0.75, blue: 0.50), // green
            Color(red: 0.88, green: 0.80, blue: 0.40), // yellow
            Color(red: 0.90, green: 0.55, blue: 0.25), // orange
        ]
        let panelW = shopW / 3.0
        for (i, col) in panelColors.enumerated() {
            let px = shopX + Double(i) * panelW
            ctx.fill(Rectangle().path(in: CGRect(x: px + 2, y: panelY, width: panelW - 4, height: panelH)),
                     with: .color(col.opacity(0.65)))
        }

        // Striped awning
        let awningY = shopTop + panelH + 10
        let awningH = 16.0
        let stripeCount = 14
        let stripeW = shopW / Double(stripeCount)
        for i in 0..<stripeCount {
            let sx = shopX + Double(i) * stripeW
            let col = i % 2 == 0
                ? Color(red: 0.85, green: 0.25, blue: 0.20)   // red
                : Color(red: 0.95, green: 0.95, blue: 0.90)    // white
            ctx.fill(Rectangle().path(in: CGRect(x: sx, y: awningY, width: stripeW, height: awningH)),
                     with: .color(col.opacity(0.8)))
        }
        // Awning scalloped bottom edge
        let scW = shopW / 8.0
        for i in 0..<8 {
            let cx = shopX + Double(i) * scW + scW / 2
            let cy = awningY + awningH
            let semicircle = CGRect(x: cx - scW / 2, y: cy - 3, width: scW, height: 8)
            ctx.fill(Ellipse().path(in: semicircle), with: .color(Color(red: 0.85, green: 0.25, blue: 0.20).opacity(0.7)))
        }

        // Shop display window (blue-tinted with stuff inside)
        let dispY = awningY + awningH + 4
        let dispH = shopBot - dispY - 12
        let dispColor = Color(red: 0.35, green: 0.50, blue: 0.70)
        ctx.fill(Rectangle().path(in: CGRect(x: shopX + 8, y: dispY, width: shopW - 16, height: dispH)),
                 with: .color(dispColor.opacity(0.5)))
        // Warm interior glow
        let glowFlicker = sin(t * 0.4 + 1.0) * 0.05
        ctx.fill(Rectangle().path(in: CGRect(x: shopX + 10, y: dispY + 2, width: shopW - 20, height: dispH - 4)),
                 with: .color(Color(red: 0.80, green: 0.70, blue: 0.35).opacity(0.25 + glowFlicker)))

        // Bunting / triangle flags under awning
        let flagY = awningY + awningH + 1
        let flagColors: [Color] = [
            Color(red: 0.9, green: 0.5, blue: 0.6),
            Color(red: 0.5, green: 0.8, blue: 0.9),
            Color(red: 0.9, green: 0.85, blue: 0.5),
            Color(red: 0.6, green: 0.8, blue: 0.5),
        ]
        let flagStep = shopW / 7.0
        for i in 0..<6 {
            let fx = shopX + 8 + Double(i) * flagStep
            let col = flagColors[i % flagColors.count]
            var tri = Path()
            tri.move(to: CGPoint(x: fx, y: flagY))
            tri.addLine(to: CGPoint(x: fx + flagStep * 0.5, y: flagY + 8))
            tri.addLine(to: CGPoint(x: fx + flagStep, y: flagY))
            tri.closeSubpath()
            ctx.fill(tri, with: .color(col.opacity(0.5)))
        }

        // Peaked roof
        let roofColor = Color(red: 0.55, green: 0.58, blue: 0.62)
        var roof = Path()
        roof.move(to: CGPoint(x: shopX - 5, y: shopTop + 2))
        roof.addLine(to: CGPoint(x: shopX + shopW / 2, y: shopTop - 15))
        roof.addLine(to: CGPoint(x: shopX + shopW + 5, y: shopTop + 2))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(roofColor))
    }

    // MARK: - Bushes (rounded with scratchy leaf marks)

    private func drawBushes(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for bush in bushes {
            let bx = bush.x * w
            let by = bush.y * h
            let sway = sin(t * 0.4 + bush.x * 10) * 1.5

            // Main bush shape
            let bushColor = Color(red: 0.28, green: 0.52, blue: 0.35)
            let bushRect = CGRect(x: bx - bush.rx + sway, y: by - bush.ry, width: bush.rx * 2, height: bush.ry * 2)
            ctx.fill(Ellipse().path(in: bushRect), with: .color(bushColor))

            // Darker bottom half
            let darkBush = Color(red: 0.20, green: 0.40, blue: 0.28)
            let lowerRect = CGRect(x: bx - bush.rx * 0.9 + sway, y: by, width: bush.rx * 1.8, height: bush.ry * 0.9)
            ctx.fill(Ellipse().path(in: lowerRect), with: .color(darkBush.opacity(0.4)))

            // Scratchy leaf marks (the distinctive Chibi Maruko-chan bush texture)
            let scratchColor = Color(red: 0.18, green: 0.35, blue: 0.22)
            for scratch in bush.scratches {
                let sx = bx + scratch.dx * bush.rx * 0.8 + sway
                let sy = by + scratch.dy * bush.ry * 0.7
                let angle = scratch.angle
                let len = 6.0
                // Small V-shape (like a bird or leaf scratch)
                var mark = Path()
                mark.move(to: CGPoint(x: sx - len * cos(angle - 0.4), y: sy - len * sin(angle - 0.4)))
                mark.addLine(to: CGPoint(x: sx, y: sy))
                mark.addLine(to: CGPoint(x: sx - len * cos(angle + 0.4), y: sy - len * sin(angle + 0.4)))
                ctx.stroke(mark, with: .color(scratchColor.opacity(0.5)), lineWidth: 1.2)
            }
        }
    }

    // MARK: - Ground (dark grey-blue with slight grass tufts)

    private func drawGround(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let groundY = h * 0.76
        // Ground fill
        let groundGrad = Gradient(colors: [
            Color(red: 0.32, green: 0.38, blue: 0.42),
            Color(red: 0.25, green: 0.30, blue: 0.35),
        ])
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: groundY, width: w, height: h - groundY)),
            with: .linearGradient(groundGrad, startPoint: .init(x: w / 2, y: groundY), endPoint: .init(x: w / 2, y: h))
        )

        // Grass tufts along the wall base
        let grassColor = Color(red: 0.30, green: 0.48, blue: 0.32)
        var gx = 5.0
        var rng = SplitMix64(seed: 1990_42)
        while gx < w {
            if .random(in: 0...1, using: &rng) < 0.3 {
                let gh = Double.random(in: 4...10, using: &rng)
                let sway = sin(t * 0.6 + gx * 0.1) * 1.5
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: gx, y: groundY))
                    p.addLine(to: CGPoint(x: gx + sway, y: groundY - gh))
                }, with: .color(grassColor.opacity(0.5)), lineWidth: 1.0)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: gx + 2, y: groundY))
                    p.addLine(to: CGPoint(x: gx + 3 + sway * 0.8, y: groundY - gh * 0.7))
                }, with: .color(grassColor.opacity(0.4)), lineWidth: 0.8)
            }
            gx += Double.random(in: 8...18, using: &rng)
        }
    }

    // MARK: - Puddles

    private func drawPuddles(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let groundY = h * 0.76
        let puddleColor = Color(red: 0.28, green: 0.35, blue: 0.48)

        // Static puddles
        let puddlePositions: [(x: Double, y: Double, rx: Double, ry: Double)] = [
            (0.20, 0.82, 40, 8), (0.45, 0.84, 55, 10), (0.70, 0.80, 35, 7),
            (0.35, 0.88, 30, 6), (0.80, 0.86, 45, 9),
        ]
        for puddle in puddlePositions {
            let px = puddle.x * w
            let py = puddle.y * h
            let pr = CGRect(x: px - puddle.rx, y: py - puddle.ry, width: puddle.rx * 2, height: puddle.ry * 2)
            ctx.fill(Ellipse().path(in: pr), with: .color(puddleColor.opacity(0.4)))

            // Ripples from raindrops
            let ripplePhase = fmod(t * 1.2 + puddle.x * 7, 3.0) / 3.0
            let rippleR = puddle.rx * 0.3 + ripplePhase * puddle.rx * 0.7
            let rippleAlpha = (1.0 - ripplePhase) * 0.3
            ctx.stroke(Ellipse().path(in: CGRect(x: px - rippleR, y: py - rippleR * 0.3, width: rippleR * 2, height: rippleR * 0.6)),
                       with: .color(Color(red: 0.5, green: 0.6, blue: 0.7).opacity(rippleAlpha)), lineWidth: 0.8)
        }

        // Tap splashes
        for splash in puddleSplashes {
            let age = t - splash.birth
            guard age > 0 && age < 2.0 else { continue }
            let frac = age / 2.0
            let alpha = (1.0 - frac) * 0.5
            for ring in 0..<3 {
                let delay = Double(ring) * 0.15
                let rFrac = max(0, min(1, (age - delay) / 1.5))
                let r = 5 + rFrac * 40
                let rAlpha = alpha * (1.0 - rFrac)
                ctx.stroke(Ellipse().path(in: CGRect(x: splash.x - r, y: splash.y - r * 0.3, width: r * 2, height: r * 0.6)),
                           with: .color(Color(red: 0.6, green: 0.7, blue: 0.8).opacity(rAlpha)), lineWidth: 1.0)
            }
        }
    }

    // MARK: - Rain

    private func drawRain(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let rainColor = Color(red: 0.55, green: 0.65, blue: 0.80)

        for drop in raindrops {
            // Loop the drop vertically
            let period = 1.8 / drop.speed
            let phase = fmod(t + drop.phase * period, period) / period
            let y = h * (-0.1 + phase * 1.2)
            let x = drop.x * w + sin(t * 0.3 + drop.phase * 10) * 3 // slight wind

            // Rain streak
            let alpha = 0.15 + drop.speed * 0.12
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - 1.5, y: y + drop.length))
            }, with: .color(rainColor.opacity(alpha)), lineWidth: 0.8)
        }
    }

    // MARK: - Street lamp

    private func drawStreetLamp(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let poleX = w * 0.15
        let lampY = h * 0.35

        // Lamp arm extending from the utility pole
        let armEndX = poleX + 18
        ctx.stroke(Path { p in
            p.move(to: CGPoint(x: poleX, y: lampY))
            p.addLine(to: CGPoint(x: armEndX, y: lampY - 5))
        }, with: .color(Color(red: 0.35, green: 0.32, blue: 0.28)), lineWidth: 2)

        // Lamp shade (downward facing)
        var shade = Path()
        shade.move(to: CGPoint(x: armEndX - 8, y: lampY - 5))
        shade.addLine(to: CGPoint(x: armEndX + 8, y: lampY - 5))
        shade.addLine(to: CGPoint(x: armEndX + 5, y: lampY + 2))
        shade.addLine(to: CGPoint(x: armEndX - 5, y: lampY + 2))
        shade.closeSubpath()
        ctx.fill(shade, with: .color(Color(red: 0.25, green: 0.25, blue: 0.28)))

        // Warm glow orb
        let glowPulse = sin(t * 0.5) * 0.05
        let glowR = 12.0
        let glowCenter = CGPoint(x: armEndX, y: lampY + 1)
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 18))
            let gr = CGRect(x: glowCenter.x - glowR * 2, y: glowCenter.y - glowR * 2, width: glowR * 4, height: glowR * 4)
            layer.fill(Ellipse().path(in: gr), with: .color(Color(red: 0.85, green: 0.80, blue: 0.55).opacity(0.35 + glowPulse)))
        }
        // Bright center
        let cr = CGRect(x: glowCenter.x - glowR * 0.6, y: glowCenter.y - glowR * 0.6, width: glowR * 1.2, height: glowR * 1.2)
        ctx.fill(Ellipse().path(in: cr), with: .color(Color(red: 0.95, green: 0.92, blue: 0.75).opacity(0.7 + glowPulse)))

        // Light cone on ground
        let coneY = h * 0.76
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 30))
            var cone = Path()
            cone.move(to: CGPoint(x: armEndX - 6, y: lampY + 4))
            cone.addLine(to: CGPoint(x: armEndX - 50, y: coneY))
            cone.addLine(to: CGPoint(x: armEndX + 50, y: coneY))
            cone.addLine(to: CGPoint(x: armEndX + 6, y: lampY + 4))
            cone.closeSubpath()
            layer.fill(cone, with: .color(Color(red: 0.85, green: 0.80, blue: 0.55).opacity(0.06)))
        }
    }

    // MARK: - Vignette

    private func drawVignette(ctx: GraphicsContext, w: Double, h: Double) {
        let cx = w / 2
        let cy = h / 2
        let r = max(w, h) * 0.75
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
            with: .radialGradient(
                Gradient(colors: [.clear, .clear, Color.black.opacity(0.25), Color.black.opacity(0.55)]),
                center: CGPoint(x: cx, y: cy),
                startRadius: r * 0.3,
                endRadius: r
            )
        )
    }
}
