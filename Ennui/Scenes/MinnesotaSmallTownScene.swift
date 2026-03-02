import SwiftUI

// Minnesota Small Town — A calm summer evening in a tiny fictional
// town somewhere on the Minnesota prairie. Main Street stretches out
// under an enormous sky going pink and gold. There's a steeple,
// a water tower, a grain elevator, a little diner with a neon sign,
// a general store. A dog is probably asleep on someone's porch. The
// wind barely moves. Nothing happens and that's the whole point.
//
// Tap to send a slow firefly drifting across the scene.
//
// Seed: 1936.

struct MinnesotaSmallTownScene: View {
    @ObservedObject var interaction: InteractionState

    private let startDate = Date()

    // Procedural data (generated once)
    @State private var stars: [StarData] = []
    @State private var buildings: [BuildingData] = []
    @State private var trees: [TreeData] = []
    @State private var fireflies: [FireflyData] = []
    @State private var extraFireflies: [ExtraFirefly] = []
    @State private var ready = false

    struct StarData {
        let x, y, brightness, size, twinkleRate, phase: Double
    }

    struct BuildingData {
        let x, width, height: Double
        let roofPeak: Double        // 0 = flat, >0 = peaked
        let hue: Double             // warm palette shift
        let hasLitWindow: Bool
        let windowRows: Int
        let windowCols: Int
    }

    struct TreeData {
        let x: Double
        let trunkH: Double
        let canopyR: Double
        let swayPhase: Double
        let depth: Double           // 0 far, 1 near
    }

    struct FireflyData {
        let baseX, baseY, driftR, blinkRate, phase, driftPX, driftPY: Double
    }

    struct ExtraFirefly {
        let birth: Double
        let originX, originY: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                let w = size.width
                let h = size.height
                drawSky(ctx: ctx, w: w, h: h, t: now)
                drawStars(ctx: ctx, w: w, h: h, t: now)
                drawClouds(ctx: ctx, w: w, h: h, t: now)
                drawDistantPrairie(ctx: ctx, w: w, h: h, t: now)
                drawWaterTower(ctx: ctx, w: w, h: h)
                drawGrainElevator(ctx: ctx, w: w, h: h)
                drawChurch(ctx: ctx, w: w, h: h, t: now)
                drawMainStreet(ctx: ctx, w: w, h: h)
                drawBuildings(ctx: ctx, w: w, h: h, t: now)
                drawDiner(ctx: ctx, w: w, h: h, t: now)
                drawTrees(ctx: ctx, w: w, h: h, t: now)
                drawStreetLamps(ctx: ctx, w: w, h: h, t: now)
                drawFireflies(ctx: ctx, w: w, h: h, t: now)
                drawVignette(ctx: ctx, w: w, h: h)
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .allowedDynamicRange(.high)
        }
        .onAppear { generate() }
        .onChange(of: interaction.tapCount) { _, _ in addFirefly() }
    }

    // MARK: - Generation

    private func generate() {
        var rng = SplitMix64(seed: 1936)

        // Stars
        var s: [StarData] = []
        for _ in 0..<200 {
            s.append(StarData(
                x: .random(in: 0...1, using: &rng),
                y: .random(in: 0...0.38, using: &rng),
                brightness: .random(in: 0.15...1.0, using: &rng),
                size: .random(in: 0.3...1.6, using: &rng),
                twinkleRate: .random(in: 0.3...1.5, using: &rng),
                phase: .random(in: 0...Double.pi * 2, using: &rng)
            ))
        }
        stars = s

        // Buildings on main street
        var b: [BuildingData] = []
        var bx = 0.12
        for _ in 0..<7 {
            let bw = Double.random(in: 0.06...0.10, using: &rng)
            b.append(BuildingData(
                x: bx,
                width: bw,
                height: .random(in: 0.08...0.18, using: &rng),
                roofPeak: Bool.random(using: &rng) ? .random(in: 0.02...0.05, using: &rng) : 0,
                hue: .random(in: 0.04...0.12, using: &rng),
                hasLitWindow: .random(using: &rng),
                windowRows: Int.random(in: 1...3, using: &rng),
                windowCols: Int.random(in: 2...4, using: &rng)
            ))
            bx += bw + .random(in: 0.01...0.03, using: &rng)
        }
        buildings = b

        // Trees
        var tr: [TreeData] = []
        for _ in 0..<12 {
            tr.append(TreeData(
                x: .random(in: 0.0...1.0, using: &rng),
                trunkH: .random(in: 0.04...0.09, using: &rng),
                canopyR: .random(in: 0.02...0.05, using: &rng),
                swayPhase: .random(in: 0...Double.pi * 2, using: &rng),
                depth: .random(in: 0...1, using: &rng)
            ))
        }
        tr.sort { $0.depth < $1.depth }
        trees = tr

        // Fireflies
        var ff: [FireflyData] = []
        for _ in 0..<25 {
            ff.append(FireflyData(
                baseX: .random(in: 0...1, using: &rng),
                baseY: .random(in: 0.40...0.80, using: &rng),
                driftR: .random(in: 0.01...0.04, using: &rng),
                blinkRate: .random(in: 0.4...1.2, using: &rng),
                phase: .random(in: 0...Double.pi * 2, using: &rng),
                driftPX: .random(in: 0...Double.pi * 2, using: &rng),
                driftPY: .random(in: 0...Double.pi * 2, using: &rng)
            ))
        }
        fireflies = ff
        ready = true
    }

    // MARK: - Tap

    private func addFirefly() {
        guard let loc = interaction.tapLocation else { return }
        let now = Date().timeIntervalSince(startDate)
        extraFireflies.append(ExtraFirefly(birth: now, originX: loc.x, originY: loc.y))
        if extraFireflies.count > 12 { extraFireflies.removeFirst() }
    }

    // MARK: - Sky

    private func drawSky(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let breath = sin(t * 0.03) * 0.02
        let colors: [Color] = [
            Color(red: 0.08, green: 0.06, blue: 0.18),         // zenith — deep blue
            Color(red: 0.18 + breath, green: 0.12, blue: 0.30), // upper mid
            Color(red: 0.45 + breath, green: 0.25, blue: 0.35), // pink band
            Color(red: 0.75, green: 0.45, blue: 0.25),          // gold horizon band
            Color(red: 0.85, green: 0.55, blue: 0.20),          // warm amber
        ]
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(
                Gradient(colors: colors),
                startPoint: CGPoint(x: w / 2, y: 0),
                endPoint: CGPoint(x: w / 2, y: h * 0.55)
            )
        )
    }

    // MARK: - Stars

    private func drawStars(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for star in stars {
            let twinkle = sin(t * star.twinkleRate + star.phase) * 0.35 + 0.65
            let alpha = star.brightness * twinkle * 0.7
            let r = star.size
            let sx = star.x * w
            let sy = star.y * h
            ctx.fill(
                Circle().path(in: CGRect(x: sx - r, y: sy - r, width: r * 2, height: r * 2)),
                with: .color(Color(red: 0.95, green: 0.92, blue: 0.85).opacity(alpha))
            )
        }
    }

    // MARK: - Clouds

    private func drawClouds(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        // A few wispy clouds lit gold from below
        let cloudData: [(cx: Double, cy: Double, rw: Double, rh: Double, speed: Double)] = [
            (0.20, 0.15, 0.14, 0.025, 0.003),
            (0.55, 0.10, 0.18, 0.020, 0.002),
            (0.80, 0.20, 0.10, 0.018, 0.004),
        ]
        for c in cloudData {
            let cx = fmod(c.cx + t * c.speed, 1.3) - 0.15
            let rw = c.rw * w
            let rh = c.rh * h
            let rect = CGRect(x: cx * w - rw / 2, y: c.cy * h - rh / 2, width: rw, height: rh)
            ctx.fill(Ellipse().path(in: rect),
                     with: .color(Color(red: 0.85, green: 0.60, blue: 0.35).opacity(0.12)))
        }
    }

    // MARK: - Distant prairie

    private func drawDistantPrairie(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let horizonY = h * 0.46
        // Flat prairie below horizon
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: horizonY, width: w, height: h - horizonY)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.30, green: 0.35, blue: 0.15),
                    Color(red: 0.18, green: 0.22, blue: 0.10),
                    Color(red: 0.12, green: 0.15, blue: 0.08),
                ]),
                startPoint: CGPoint(x: 0, y: horizonY),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        // Distant treeline silhouette at horizon
        var treePath = Path()
        treePath.move(to: CGPoint(x: 0, y: horizonY))
        var x = 0.0
        while x < w + 10 {
            let bump = sin(x * 0.02 + 1.5) * 6 + sin(x * 0.07 + 0.3) * 3 + sin(x * 0.15) * 2
            treePath.addLine(to: CGPoint(x: x, y: horizonY - 4 - abs(bump)))
            x += 3
        }
        treePath.addLine(to: CGPoint(x: w, y: horizonY))
        treePath.closeSubpath()
        ctx.fill(treePath, with: .color(Color(red: 0.08, green: 0.10, blue: 0.06).opacity(0.7)))
    }

    // MARK: - Water tower

    private func drawWaterTower(ctx: GraphicsContext, w: Double, h: Double) {
        let cx = w * 0.82
        let baseY = h * 0.46
        let tankY = baseY - h * 0.15

        // Legs
        let legW = 2.0
        for dx in [-12.0, 0.0, 12.0] {
            ctx.fill(
                Rectangle().path(in: CGRect(x: cx + dx - legW / 2, y: tankY + 10, width: legW, height: baseY - tankY - 10)),
                with: .color(Color(red: 0.25, green: 0.22, blue: 0.20).opacity(0.6))
            )
        }
        // Tank
        let tankW = 32.0
        let tankH = 18.0
        let tankRect = CGRect(x: cx - tankW / 2, y: tankY, width: tankW, height: tankH)
        ctx.fill(Ellipse().path(in: tankRect),
                 with: .color(Color(red: 0.50, green: 0.48, blue: 0.45).opacity(0.5)))
        // Dome top
        let domeRect = CGRect(x: cx - tankW / 2 + 4, y: tankY - 6, width: tankW - 8, height: 10)
        ctx.fill(Ellipse().path(in: domeRect),
                 with: .color(Color(red: 0.45, green: 0.43, blue: 0.40).opacity(0.5)))
    }

    // MARK: - Grain elevator

    private func drawGrainElevator(ctx: GraphicsContext, w: Double, h: Double) {
        let cx = w * 0.25
        let baseY = h * 0.46
        let elW = 24.0
        let elH = h * 0.14

        // Main body
        ctx.fill(
            Rectangle().path(in: CGRect(x: cx - elW / 2, y: baseY - elH, width: elW, height: elH)),
            with: .color(Color(red: 0.35, green: 0.32, blue: 0.28).opacity(0.55))
        )
        // Peaked cap
        var cap = Path()
        cap.move(to: CGPoint(x: cx - elW / 2 - 2, y: baseY - elH))
        cap.addLine(to: CGPoint(x: cx, y: baseY - elH - 14))
        cap.addLine(to: CGPoint(x: cx + elW / 2 + 2, y: baseY - elH))
        cap.closeSubpath()
        ctx.fill(cap, with: .color(Color(red: 0.30, green: 0.28, blue: 0.25).opacity(0.55)))
    }

    // MARK: - Church

    private func drawChurch(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let cx = w * 0.40
        let baseY = h * 0.46
        let bodyW = 28.0
        let bodyH = h * 0.10
        let steepleW = 8.0
        let steepleH = h * 0.09

        // Body
        ctx.fill(
            Rectangle().path(in: CGRect(x: cx - bodyW / 2, y: baseY - bodyH, width: bodyW, height: bodyH)),
            with: .color(Color(red: 0.85, green: 0.82, blue: 0.75).opacity(0.35))
        )

        // Steeple
        ctx.fill(
            Rectangle().path(in: CGRect(x: cx - steepleW / 2, y: baseY - bodyH - steepleH, width: steepleW, height: steepleH)),
            with: .color(Color(red: 0.80, green: 0.78, blue: 0.72).opacity(0.40))
        )

        // Spire
        var spire = Path()
        let spireBase = baseY - bodyH - steepleH
        spire.move(to: CGPoint(x: cx - steepleW / 2, y: spireBase))
        spire.addLine(to: CGPoint(x: cx, y: spireBase - 16))
        spire.addLine(to: CGPoint(x: cx + steepleW / 2, y: spireBase))
        spire.closeSubpath()
        ctx.fill(spire, with: .color(Color(red: 0.70, green: 0.68, blue: 0.65).opacity(0.45)))

        // Warm window glow
        let glowAlpha = sin(t * 0.15) * 0.1 + 0.25
        let winRect = CGRect(x: cx - 4, y: baseY - bodyH + 6, width: 8, height: 12)
        ctx.fill(
            RoundedRectangle(cornerRadius: 1).path(in: winRect),
            with: .color(Color(red: 1.0, green: 0.85, blue: 0.4).opacity(glowAlpha))
        )
    }

    // MARK: - Main Street

    private func drawMainStreet(ctx: GraphicsContext, w: Double, h: Double) {
        let streetY = h * 0.65
        let streetH = h * 0.10
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: streetY, width: w, height: streetH)),
            with: .color(Color(red: 0.20, green: 0.19, blue: 0.17).opacity(0.4))
        )
        // Centre line
        var lineX = 10.0
        while lineX < w {
            ctx.fill(
                Rectangle().path(in: CGRect(x: lineX, y: streetY + streetH / 2 - 0.5, width: 12, height: 1)),
                with: .color(Color(red: 0.80, green: 0.75, blue: 0.50).opacity(0.12))
            )
            lineX += 24
        }
    }

    // MARK: - Buildings

    private func drawBuildings(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let streetTop = h * 0.65
        for b in buildings {
            let bx = b.x * w
            let bw = b.width * w
            let bh = b.height * h
            let by = streetTop - bh

            // Wall
            let wallColor = Color(red: 0.55 + b.hue, green: 0.48 + b.hue * 0.5, blue: 0.40)
            ctx.fill(
                Rectangle().path(in: CGRect(x: bx, y: by, width: bw, height: bh)),
                with: .color(wallColor.opacity(0.35))
            )

            // Peaked roof
            if b.roofPeak > 0 {
                var roof = Path()
                roof.move(to: CGPoint(x: bx - 2, y: by))
                roof.addLine(to: CGPoint(x: bx + bw / 2, y: by - b.roofPeak * h))
                roof.addLine(to: CGPoint(x: bx + bw + 2, y: by))
                roof.closeSubpath()
                ctx.fill(roof, with: .color(Color(red: 0.40, green: 0.30, blue: 0.25).opacity(0.35)))
            }

            // Windows
            if b.hasLitWindow {
                let cellW = bw / Double(b.windowCols + 1)
                let cellH = bh / Double(b.windowRows + 1)
                for row in 1...b.windowRows {
                    for col in 1...b.windowCols {
                        let wx = bx + cellW * Double(col) - 2
                        let wy = by + cellH * Double(row) - 2
                        let litAlpha = sin(t * 0.1 + Double(row + col) * 0.8) * 0.08 + 0.22
                        ctx.fill(
                            Rectangle().path(in: CGRect(x: wx, y: wy, width: 4, height: 4)),
                            with: .color(Color(red: 1.0, green: 0.88, blue: 0.45).opacity(litAlpha))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Diner

    private func drawDiner(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let dx = w * 0.62
        let streetTop = h * 0.65
        let dw = w * 0.12
        let dh = h * 0.07

        // Body — slightly rounded feel
        ctx.fill(
            RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: dx, y: streetTop - dh, width: dw, height: dh)),
            with: .color(Color(red: 0.50, green: 0.25, blue: 0.25).opacity(0.35))
        )

        // Big front window glow
        let glow = sin(t * 0.12) * 0.05 + 0.25
        ctx.fill(
            RoundedRectangle(cornerRadius: 1).path(in: CGRect(x: dx + 4, y: streetTop - dh + 4, width: dw - 8, height: dh * 0.5)),
            with: .color(Color(red: 1.0, green: 0.90, blue: 0.55).opacity(glow))
        )

        // Neon sign — small glowing rectangle above
        let neonFlicker = sin(t * 3.0) > -0.2 ? 0.6 : 0.2
        ctx.fill(
            RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: dx + dw * 0.25, y: streetTop - dh - 8, width: dw * 0.5, height: 6)),
            with: .color(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(neonFlicker))
        )
        // Neon glow halo
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 8))
            layer.fill(
                RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: dx + dw * 0.25 - 3, y: streetTop - dh - 11, width: dw * 0.5 + 6, height: 12)),
                with: .color(Color(red: 1.0, green: 0.25, blue: 0.25).opacity(neonFlicker * 0.3))
            )
        }
    }

    // MARK: - Trees

    private func drawTrees(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let groundY = h * 0.75
        for tree in trees {
            let tx = tree.x * w
            let sway = sin(t * 0.4 + tree.swayPhase) * 2
            let scale = 0.6 + tree.depth * 0.4
            let ty = groundY - tree.trunkH * h * scale + tree.depth * h * 0.05

            // Trunk
            let tw = 3.0 * scale
            ctx.fill(
                Rectangle().path(in: CGRect(x: tx - tw / 2, y: ty, width: tw, height: tree.trunkH * h * scale)),
                with: .color(Color(red: 0.25, green: 0.20, blue: 0.15).opacity(0.4 * scale))
            )

            // Canopy
            let cr = tree.canopyR * w * scale
            let canopyRect = CGRect(x: tx - cr + sway, y: ty - cr * 0.8, width: cr * 2, height: cr * 1.6)
            ctx.fill(
                Ellipse().path(in: canopyRect),
                with: .color(Color(red: 0.12, green: 0.20, blue: 0.10).opacity(0.40 * scale))
            )
        }
    }

    // MARK: - Street lamps

    private func drawStreetLamps(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let positions: [Double] = [0.18, 0.35, 0.52, 0.70, 0.88]
        let streetTop = h * 0.65
        let poleH = h * 0.08

        for px in positions {
            let lx = px * w
            let ly = streetTop - poleH

            // Pole
            ctx.fill(
                Rectangle().path(in: CGRect(x: lx - 1, y: ly, width: 2, height: poleH)),
                with: .color(Color(red: 0.30, green: 0.28, blue: 0.25).opacity(0.4))
            )

            // Light
            let flicker = sin(t * 0.5 + px * 10) * 0.05 + 0.35
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 12))
                layer.fill(
                    Circle().path(in: CGRect(x: lx - 10, y: ly - 10, width: 20, height: 20)),
                    with: .color(Color(red: 1.0, green: 0.88, blue: 0.55).opacity(flicker))
                )
            }
            ctx.fill(
                Circle().path(in: CGRect(x: lx - 3, y: ly - 3, width: 6, height: 6)),
                with: .color(Color(red: 1.0, green: 0.92, blue: 0.65).opacity(flicker + 0.2))
            )
        }
    }

    // MARK: - Fireflies

    private func drawFireflies(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for ff in fireflies {
            let blink = max(0, sin(t * ff.blinkRate + ff.phase))
            let alpha = blink * 0.7
            guard alpha > 0.05 else { continue }
            let fx = (ff.baseX + sin(t * 0.3 + ff.driftPX) * ff.driftR) * w
            let fy = (ff.baseY + cos(t * 0.25 + ff.driftPY) * ff.driftR) * h

            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 5))
                layer.fill(
                    Circle().path(in: CGRect(x: fx - 4, y: fy - 4, width: 8, height: 8)),
                    with: .color(Color(red: 0.95, green: 0.90, blue: 0.40).opacity(alpha * 0.4))
                )
            }
            ctx.fill(
                Circle().path(in: CGRect(x: fx - 1.5, y: fy - 1.5, width: 3, height: 3)),
                with: .color(Color(red: 0.98, green: 0.95, blue: 0.55).opacity(alpha))
            )
        }

        // Tap-spawned fireflies
        for ef in extraFireflies {
            let age = t - ef.birth
            guard age > 0, age < 8 else { continue }
            let fadeIn = min(age / 0.5, 1)
            let fadeOut = max(0, 1 - (age - 6) / 2)
            let alpha = fadeIn * fadeOut * 0.8
            let drift = sin(age * 0.6) * 20
            let rise = age * 8
            let fx = ef.originX + drift
            let fy = ef.originY - rise

            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 6))
                layer.fill(
                    Circle().path(in: CGRect(x: fx - 5, y: fy - 5, width: 10, height: 10)),
                    with: .color(Color(red: 0.95, green: 0.90, blue: 0.40).opacity(alpha * 0.35))
                )
            }
            ctx.fill(
                Circle().path(in: CGRect(x: fx - 2, y: fy - 2, width: 4, height: 4)),
                with: .color(Color(red: 0.98, green: 0.95, blue: 0.55).opacity(alpha))
            )
        }
    }

    // MARK: - Vignette

    private func drawVignette(ctx: GraphicsContext, w: Double, h: Double) {
        let center = CGPoint(x: w / 2, y: h / 2)
        let maxR = sqrt(w * w + h * h) / 2
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
            with: .radialGradient(
                Gradient(colors: [.clear, .clear, .black.opacity(0.35)]),
                center: center,
                startRadius: maxR * 0.5,
                endRadius: maxR
            )
        )
    }
}
