import SwiftUI

// Ontario Countryside — A warm summer evening settling over the rural
// countryside of southern Ontario, sometime in the early 1990s. Golden
// wheat fields roll toward a distant treeline of maples and oaks. An
// old red barn stands against the fading sky. Power lines trace the
// gravel road. Hay bales dot the stubble. Fireflies are just beginning
// to blink in the blue hour. The air smells like cut grass and warm
// earth. You drove past this a thousand times with the window down.
// You didn't know it was beautiful until you couldn't go back.
//
// Tap releases a wave through the wheat, like a gust of August wind.
//
// Seed: 1989.

struct OntarioCountrysideScene: View {
    @ObservedObject var interaction: InteractionState

    private let startDate = Date()
    private let px: Double = 2.0

    // Procedural data
    @State private var stars: [StarData] = []
    @State private var clouds: [CloudData] = []
    @State private var powerPoles: [PowerPole] = []
    @State private var hayBales: [HayBale] = []
    @State private var fireflies: [Firefly] = []
    @State private var wildflowers: [Wildflower] = []
    @State private var fencePosts: [FencePost] = []
    @State private var windGusts: [WindGust] = []
    @State private var ready = false

    struct StarData {
        let x, y, brightness, size, twinkleRate, twinklePhase: Double
    }

    struct CloudData {
        let x, y, width, height, speed, opacity: Double
    }

    struct PowerPole {
        let x: Double         // screen‐normalised
        let height: Double
    }

    struct HayBale {
        let cx, cy: Double    // centre (normalised)
        let radius: Double
        let rotation: Double  // slight tilt
        let depth: Double     // 0 far, 1 near
    }

    struct Firefly {
        let baseX, baseY: Double
        let driftRadius: Double
        let blinkRate: Double
        let blinkPhase: Double
        let driftPhaseX, driftPhaseY: Double
        let brightness: Double
    }

    struct Wildflower {
        let x, y: Double
        let petalCount: Int
        let size: Double
        let hue: Double       // gold / white / purple
        let swayPhase: Double
    }

    struct FencePost {
        let x: Double
        let height: Double
    }

    struct WindGust {
        let startTime: Double
        let originX: Double
        let strength: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                let w = size.width
                let h = size.height
                drawSky(ctx: ctx, w: w, h: h, t: now)
                drawClouds(ctx: ctx, w: w, h: h, t: now)
                drawStars(ctx: ctx, w: w, h: h, t: now)
                drawDistantTreeline(ctx: ctx, w: w, h: h, t: now)
                drawFields(ctx: ctx, w: w, h: h, t: now)
                drawGravelRoad(ctx: ctx, w: w, h: h)
                drawFencePosts(ctx: ctx, w: w, h: h)
                drawPowerLines(ctx: ctx, w: w, h: h)
                drawBarn(ctx: ctx, w: w, h: h)
                drawFarmhouse(ctx: ctx, w: w, h: h, t: now)
                drawHayBales(ctx: ctx, w: w, h: h)
                drawWildflowers(ctx: ctx, w: w, h: h, t: now)
                drawFireflies(ctx: ctx, w: w, h: h, t: now)
                drawVignette(ctx: ctx, w: w, h: h)
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .allowedDynamicRange(.high)
        }
        .onAppear { generate() }
        .onChange(of: interaction.tapCount) { _, _ in addWindGust() }
    }

    // MARK: - Generation

    private func generate() {
        var rng = SplitMix64(seed: 1989)

        // Stars (visible as sky darkens)
        var s: [StarData] = []
        for _ in 0..<120 {
            s.append(StarData(
                x: .random(in: 0...1, using: &rng),
                y: .random(in: 0...0.35, using: &rng),
                brightness: .random(in: 0.3...1.0, using: &rng),
                size: .random(in: 0.5...1.8, using: &rng),
                twinkleRate: .random(in: 0.3...1.2, using: &rng),
                twinklePhase: .random(in: 0...Double.pi * 2, using: &rng)
            ))
        }
        stars = s

        // Clouds
        var cl: [CloudData] = []
        for _ in 0..<6 {
            cl.append(CloudData(
                x: .random(in: -0.1...1.1, using: &rng),
                y: .random(in: 0.08...0.3, using: &rng),
                width: .random(in: 0.12...0.28, using: &rng),
                height: .random(in: 0.02...0.05, using: &rng),
                speed: .random(in: 0.002...0.006, using: &rng),
                opacity: .random(in: 0.15...0.4, using: &rng)
            ))
        }
        clouds = cl

        // Power poles along the road
        var pp: [PowerPole] = []
        for i in 0..<5 {
            let baseX = 0.52 + Double(i) * 0.10
            pp.append(PowerPole(
                x: baseX + .random(in: -0.01...0.01, using: &rng),
                height: .random(in: 0.10...0.14, using: &rng)
            ))
        }
        powerPoles = pp

        // Hay bales scattered in the field
        var hb: [HayBale] = []
        for _ in 0..<8 {
            hb.append(HayBale(
                cx: .random(in: 0.05...0.95, using: &rng),
                cy: .random(in: 0.52...0.68, using: &rng),
                radius: .random(in: 0.012...0.022, using: &rng),
                rotation: .random(in: -0.15...0.15, using: &rng),
                depth: .random(in: 0.0...1.0, using: &rng)
            ))
        }
        // Sort by cy so that further bales draw first
        hb.sort { $0.cy < $1.cy }
        hayBales = hb

        // Fireflies
        var ff: [Firefly] = []
        for _ in 0..<40 {
            ff.append(Firefly(
                baseX: .random(in: 0.0...1.0, using: &rng),
                baseY: .random(in: 0.38...0.75, using: &rng),
                driftRadius: .random(in: 0.01...0.04, using: &rng),
                blinkRate: .random(in: 0.4...1.4, using: &rng),
                blinkPhase: .random(in: 0...Double.pi * 2, using: &rng),
                driftPhaseX: .random(in: 0...Double.pi * 2, using: &rng),
                driftPhaseY: .random(in: 0...Double.pi * 2, using: &rng),
                brightness: .random(in: 0.5...1.0, using: &rng)
            ))
        }
        fireflies = ff

        // Wildflowers along the road edge and foreground
        var wf: [Wildflower] = []
        for _ in 0..<50 {
            wf.append(Wildflower(
                x: .random(in: 0.0...1.0, using: &rng),
                y: .random(in: 0.70...0.92, using: &rng),
                petalCount: Int.random(in: 4...7, using: &rng),
                size: .random(in: 2.0...5.0, using: &rng),
                hue: [0.12, 0.15, 0.0, 0.75, 0.85].randomElement(using: &rng)!,
                swayPhase: .random(in: 0...Double.pi * 2, using: &rng)
            ))
        }
        wildflowers = wf

        // Fence posts along the road
        var fp: [FencePost] = []
        for i in 0..<12 {
            fp.append(FencePost(
                x: 0.42 + Double(i) * 0.05,
                height: .random(in: 0.025...0.035, using: &rng)
            ))
        }
        fencePosts = fp

        ready = true
    }

    // MARK: - Wind Gust (tap interaction)

    private func addWindGust() {
        let gust = WindGust(
            startTime: Date().timeIntervalSince(startDate),
            originX: Double.random(in: 0.2...0.8),
            strength: 1.0
        )
        windGusts.append(gust)
        // Trim old gusts
        let now = Date().timeIntervalSince(startDate)
        windGusts.removeAll { now - $0.startTime > 4.0 }
    }

    // MARK: - Sky

    private func drawSky(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        // Warm sunset gradient — amber at horizon, dusty rose, fading to deep blue-purple
        let horizonY = h * 0.42

        // Deep sky (top) — darkening twilight
        let topColor = Color(red: 0.12, green: 0.08, blue: 0.22)
        // Mid sky — dusty rose/mauve
        let midColor = Color(red: 0.55, green: 0.28, blue: 0.35)
        // Horizon — golden amber
        let horizonColor = Color(red: 0.92, green: 0.62, blue: 0.25)
        // Below horizon glow
        let belowColor = Color(red: 0.85, green: 0.50, blue: 0.18)

        // Top band
        ctx.fill(
            Path(CGRect(x: 0, y: 0, width: w, height: h * 0.15)),
            with: .color(topColor)
        )

        // Middle gradient band (0.15 → 0.42)
        let midSteps = 30
        for i in 0..<midSteps {
            let frac = Double(i) / Double(midSteps)
            let y0 = h * (0.15 + frac * 0.27)
            let y1 = h * (0.15 + (frac + 1.0 / Double(midSteps)) * 0.27)
            let r = lerp(0.12, 0.55, frac) + lerp(0.0, 0.37, max(0, frac - 0.6) / 0.4)
            let g = lerp(0.08, 0.28, frac) + lerp(0.0, 0.34, max(0, frac - 0.5) / 0.5)
            let b = lerp(0.22, 0.35, frac) - lerp(0.0, 0.10, max(0, frac - 0.7) / 0.3)
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0 + 1)),
                with: .color(Color(red: min(r, 0.92), green: min(g, 0.62), blue: max(b, 0.25)))
            )
        }

        // Horizon glow
        let glowSteps = 15
        for i in 0..<glowSteps {
            let frac = Double(i) / Double(glowSteps)
            let y0 = horizonY - h * 0.06 * (1.0 - frac)
            let y1 = horizonY + h * 0.04 * frac
            let alpha = (1.0 - frac) * 0.6
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0 + 1)),
                with: .color(horizonColor.opacity(alpha))
            )
        }
    }

    // MARK: - Clouds

    private func drawClouds(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for cloud in clouds {
            let cx = ((cloud.x + cloud.speed * t).truncatingRemainder(dividingBy: 1.4)) - 0.2
            let cy = cloud.y
            let cw = cloud.width * w
            let ch = cloud.height * h

            // Warm-lit underside colour
            let baseColor = Color(red: 0.9, green: 0.55, blue: 0.3)
            let topColor = Color(red: 0.6, green: 0.35, blue: 0.45)

            // Draw as a series of overlapping ellipses
            for j in 0..<5 {
                let frac = Double(j) / 4.0
                let offX = (frac - 0.5) * cw * 0.8
                let offY = sin(frac * .pi) * ch * 0.3
                let blobW = cw * (0.3 + sin(frac * .pi) * 0.25)
                let blobH = ch * (0.6 + frac * 0.2)
                let blobColor = frac < 0.5 ? topColor : baseColor
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: cx * w + offX - blobW / 2,
                        y: cy * h + offY - blobH / 2,
                        width: blobW,
                        height: blobH
                    )),
                    with: .color(blobColor.opacity(cloud.opacity * 0.6))
                )
            }
        }
    }

    // MARK: - Stars

    private func drawStars(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for star in stars {
            let twinkle = 0.4 + 0.6 * sin(t * star.twinkleRate + star.twinklePhase) * 0.5 + 0.5
            let alpha = star.brightness * twinkle * 0.5 // subtle in twilight
            let sz = star.size * px
            ctx.fill(
                Path(ellipseIn: CGRect(
                    x: star.x * w - sz / 2,
                    y: star.y * h - sz / 2,
                    width: sz,
                    height: sz
                )),
                with: .color(Color(red: 0.95, green: 0.92, blue: 0.85).opacity(alpha))
            )
        }
    }

    // MARK: - Distant Treeline

    private func drawDistantTreeline(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let treelineY = h * 0.42

        // Dark silhouette treeline — deciduous canopy (maples, oaks)
        var treePath = Path()
        treePath.move(to: CGPoint(x: 0, y: treelineY))

        var rng = SplitMix64(seed: 1989_42)
        let segments = 80
        for i in 0...segments {
            let frac = Double(i) / Double(segments)
            let x = frac * w
            // Canopy undulation — mix of frequencies for organic tree shapes
            let base = treelineY
            let canopyH = h * 0.04
            let y = base
                - canopyH * (0.5 + 0.3 * sin(frac * 18 + 0.3) + 0.2 * sin(frac * 37 + 1.7))
                - Double.random(in: 0...h * 0.012, using: &rng)
                + sin(t * 0.15 + frac * 6) * h * 0.002  // gentle sway
            treePath.addLine(to: CGPoint(x: x, y: y))
        }
        treePath.addLine(to: CGPoint(x: w, y: treelineY + h * 0.02))
        treePath.addLine(to: CGPoint(x: 0, y: treelineY + h * 0.02))
        treePath.closeSubpath()

        // Dark blue-green silhouette
        ctx.fill(treePath, with: .color(Color(red: 0.06, green: 0.10, blue: 0.08)))

        // Slightly lighter second layer (closer trees, partial)
        var nearTrees = Path()
        nearTrees.move(to: CGPoint(x: 0, y: treelineY + h * 0.01))
        var rng2 = SplitMix64(seed: 1989_43)
        for i in 0...segments {
            let frac = Double(i) / Double(segments)
            let x = frac * w
            let y = treelineY + h * 0.01
                - h * 0.025 * (0.3 + 0.4 * sin(frac * 22 + 2.1) + 0.3 * sin(frac * 41 + 0.5))
                - Double.random(in: 0...h * 0.008, using: &rng2)
            nearTrees.addLine(to: CGPoint(x: x, y: y))
        }
        nearTrees.addLine(to: CGPoint(x: w, y: treelineY + h * 0.03))
        nearTrees.addLine(to: CGPoint(x: 0, y: treelineY + h * 0.03))
        nearTrees.closeSubpath()
        ctx.fill(nearTrees, with: .color(Color(red: 0.08, green: 0.13, blue: 0.10).opacity(0.7)))
    }

    // MARK: - Fields

    private func drawFields(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        let fieldTop = h * 0.43
        let fieldBottom = h

        // Base field colour — golden wheat at dusk
        let fieldSteps = 25
        for i in 0..<fieldSteps {
            let frac = Double(i) / Double(fieldSteps)
            let y0 = fieldTop + frac * (fieldBottom - fieldTop)
            let y1 = fieldTop + (frac + 1.0 / Double(fieldSteps)) * (fieldBottom - fieldTop)
            // Golden near treeline, darker warm brown in foreground
            let r = lerp(0.52, 0.22, frac)
            let g = lerp(0.38, 0.15, frac)
            let b = lerp(0.12, 0.06, frac)
            ctx.fill(
                Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0 + 1)),
                with: .color(Color(red: r, green: g, blue: b))
            )
        }

        // Wheat texture — vertical strokes with wind animation
        var rng = SplitMix64(seed: 1989_07)
        let wheatCount = 300
        for _ in 0..<wheatCount {
            let fx = Double.random(in: 0...1, using: &rng)
            let fy = Double.random(in: 0.44...0.88, using: &rng)
            let stalkH = Double.random(in: 8...20, using: &rng) * (1.0 + (1.0 - fy) * 0.5)
            let stalkW = Double.random(in: 0.5...1.5, using: &rng)

            // Wind from gusts
            var windOffset = sin(t * 0.8 + fx * 12 + fy * 5) * 2.0
            for gust in windGusts {
                let gustAge = t - gust.startTime
                if gustAge > 0 && gustAge < 3.0 {
                    let dist = abs(fx - gust.originX)
                    let wave = max(0, 1.0 - dist * 3.0) * sin(gustAge * 4.0 - dist * 8.0)
                    let fade = max(0, 1.0 - gustAge / 3.0)
                    windOffset += wave * 12.0 * fade * gust.strength
                }
            }

            let x = fx * w
            let y = fy * h
            let alpha = Double.random(in: 0.2...0.6, using: &rng)
            let gold = Color(red: 0.75, green: 0.58, blue: 0.18)

            var stalk = Path()
            stalk.move(to: CGPoint(x: x, y: y))
            stalk.addLine(to: CGPoint(x: x + windOffset, y: y - stalkH))
            ctx.stroke(stalk, with: .color(gold.opacity(alpha)), lineWidth: stalkW)

            // Wheat head at the top
            if stalkH > 12 {
                let headW = stalkW * 2.5
                let headH = stalkH * 0.15
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: x + windOffset - headW / 2,
                        y: y - stalkH - headH / 2,
                        width: headW,
                        height: headH
                    )),
                    with: .color(Color(red: 0.82, green: 0.65, blue: 0.22).opacity(alpha * 1.2))
                )
            }
        }
    }

    // MARK: - Gravel Road

    private func drawGravelRoad(ctx: GraphicsContext, w: Double, h: Double) {
        // Road receding from bottom-center toward vanishing point at treeline
        var road = Path()
        let vanishX = w * 0.55
        let vanishY = h * 0.44
        let bottomLeftX = w * 0.38
        let bottomRightX = w * 0.62
        let bottom = h

        road.move(to: CGPoint(x: vanishX - w * 0.01, y: vanishY))
        road.addLine(to: CGPoint(x: bottomLeftX, y: bottom))
        road.addLine(to: CGPoint(x: bottomRightX, y: bottom))
        road.addLine(to: CGPoint(x: vanishX + w * 0.01, y: vanishY))
        road.closeSubpath()

        // Gravel colour — warm grey-brown
        ctx.fill(road, with: .color(Color(red: 0.35, green: 0.30, blue: 0.24)))

        // Centre line — faded, overgrown
        var centreLine = Path()
        centreLine.move(to: CGPoint(x: vanishX, y: vanishY + h * 0.05))
        centreLine.addLine(to: CGPoint(x: w * 0.50, y: bottom))
        ctx.stroke(centreLine, with: .color(Color(red: 0.30, green: 0.35, blue: 0.18).opacity(0.3)), lineWidth: 1.5)

        // Road edges — slightly lighter
        var leftEdge = Path()
        leftEdge.move(to: CGPoint(x: vanishX - w * 0.008, y: vanishY))
        leftEdge.addLine(to: CGPoint(x: bottomLeftX - 2, y: bottom))
        ctx.stroke(leftEdge, with: .color(Color(red: 0.45, green: 0.38, blue: 0.28).opacity(0.4)), lineWidth: 1)

        var rightEdge = Path()
        rightEdge.move(to: CGPoint(x: vanishX + w * 0.008, y: vanishY))
        rightEdge.addLine(to: CGPoint(x: bottomRightX + 2, y: bottom))
        ctx.stroke(rightEdge, with: .color(Color(red: 0.45, green: 0.38, blue: 0.28).opacity(0.4)), lineWidth: 1)
    }

    // MARK: - Fence Posts

    private func drawFencePosts(ctx: GraphicsContext, w: Double, h: Double) {
        let vanishX = w * 0.55
        let vanishY = h * 0.44

        for post in fencePosts {
            // Interpolate along the right side of the road
            let frac = (post.x - 0.42) / 0.55
            if frac < 0 || frac > 1 { continue }

            let px = lerp(vanishX + w * 0.012, w * 0.64, frac)
            let py = lerp(vanishY, h, frac)
            let postH = post.height * h * (0.3 + frac * 0.7)
            let postW = 1.5 + frac * 2.0

            // Wooden post
            ctx.fill(
                Path(CGRect(x: px - postW / 2, y: py - postH, width: postW, height: postH)),
                with: .color(Color(red: 0.28, green: 0.22, blue: 0.14).opacity(0.7 + frac * 0.3))
            )
        }

        // Wire between posts (single strand)
        var wirePath = Path()
        var started = false
        for post in fencePosts {
            let frac = (post.x - 0.42) / 0.55
            if frac < 0 || frac > 1 { continue }
            let px = lerp(vanishX + w * 0.012, w * 0.64, frac)
            let py = lerp(vanishY, h, frac) - post.height * h * (0.3 + frac * 0.7) * 0.7
            if !started {
                wirePath.move(to: CGPoint(x: px, y: py))
                started = true
            } else {
                wirePath.addLine(to: CGPoint(x: px, y: py))
            }
        }
        ctx.stroke(wirePath, with: .color(Color(red: 0.30, green: 0.25, blue: 0.18).opacity(0.3)), lineWidth: 0.5)
    }

    // MARK: - Power Lines

    private func drawPowerLines(ctx: GraphicsContext, w: Double, h: Double) {
        let vanishX = w * 0.55
        let vanishY = h * 0.44

        for pole in powerPoles {
            let frac = (pole.x - 0.52) / 0.50
            if frac < -0.1 || frac > 1.1 { continue }

            // Position along road perspective
            let px = lerp(vanishX - w * 0.02, w * 0.48, frac)
            let groundY = lerp(vanishY, h * 0.95, frac)
            let poleH = pole.height * h * (0.4 + frac * 0.6)
            let poleW = 1.0 + frac * 1.5

            // Dark pole
            ctx.fill(
                Path(CGRect(x: px - poleW / 2, y: groundY - poleH, width: poleW, height: poleH)),
                with: .color(Color(red: 0.12, green: 0.10, blue: 0.08))
            )

            // Crossarm
            let armW = 6.0 + frac * 10.0
            let armY = groundY - poleH + poleH * 0.05
            ctx.fill(
                Path(CGRect(x: px - armW / 2, y: armY, width: armW, height: poleW * 0.5)),
                with: .color(Color(red: 0.12, green: 0.10, blue: 0.08))
            )
        }

        // Wires between poles — catenary curves
        for wireIndex in 0..<2 {
            let wireOffY = Double(wireIndex) * 4.0
            var wirePath = Path()
            var started = false
            for pole in powerPoles {
                let frac = (pole.x - 0.52) / 0.50
                if frac < -0.1 || frac > 1.1 { continue }
                let px = lerp(vanishX - w * 0.02, w * 0.48, frac)
                let groundY = lerp(vanishY, h * 0.95, frac)
                let poleH = pole.height * h * (0.4 + frac * 0.6)
                let armY = groundY - poleH + poleH * 0.05 + wireOffY
                if !started {
                    wirePath.move(to: CGPoint(x: px, y: armY))
                    started = true
                } else {
                    wirePath.addLine(to: CGPoint(x: px, y: armY))
                }
            }
            ctx.stroke(wirePath, with: .color(Color.black.opacity(0.25)), lineWidth: 0.5)
        }
    }

    // MARK: - Barn

    private func drawBarn(ctx: GraphicsContext, w: Double, h: Double) {
        // Classic Ontario red barn, left side of road
        let barnX = w * 0.18
        let barnY = h * 0.48
        let barnW = w * 0.10
        let barnH = h * 0.08
        let roofH = h * 0.04

        // Barn body — dark red
        ctx.fill(
            Path(CGRect(x: barnX, y: barnY - barnH, width: barnW, height: barnH)),
            with: .color(Color(red: 0.42, green: 0.10, blue: 0.08))
        )

        // Gambrel roof
        var roof = Path()
        roof.move(to: CGPoint(x: barnX - barnW * 0.05, y: barnY - barnH))
        roof.addLine(to: CGPoint(x: barnX + barnW * 0.2, y: barnY - barnH - roofH * 0.7))
        roof.addLine(to: CGPoint(x: barnX + barnW * 0.5, y: barnY - barnH - roofH))
        roof.addLine(to: CGPoint(x: barnX + barnW * 0.8, y: barnY - barnH - roofH * 0.7))
        roof.addLine(to: CGPoint(x: barnX + barnW * 1.05, y: barnY - barnH))
        roof.closeSubpath()

        ctx.fill(roof, with: .color(Color(red: 0.30, green: 0.08, blue: 0.06)))

        // Barn door (dark)
        let doorW = barnW * 0.25
        let doorH = barnH * 0.6
        ctx.fill(
            Path(CGRect(x: barnX + barnW * 0.5 - doorW / 2, y: barnY - doorH, width: doorW, height: doorH)),
            with: .color(Color(red: 0.18, green: 0.06, blue: 0.04))
        )

        // Silo next to barn
        let siloX = barnX + barnW + barnW * 0.08
        let siloW = barnW * 0.2
        let siloH = barnH * 1.3
        ctx.fill(
            Path(CGRect(x: siloX, y: barnY - siloH, width: siloW, height: siloH)),
            with: .color(Color(red: 0.45, green: 0.42, blue: 0.38))
        )
        // Silo cap
        ctx.fill(
            Path(ellipseIn: CGRect(x: siloX - siloW * 0.05, y: barnY - siloH - siloW * 0.3, width: siloW * 1.1, height: siloW * 0.6)),
            with: .color(Color(red: 0.35, green: 0.32, blue: 0.28))
        )
    }

    // MARK: - Farmhouse

    private func drawFarmhouse(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        // Small white farmhouse, right side, further away
        let houseX = w * 0.72
        let houseY = h * 0.47
        let houseW = w * 0.05
        let houseH = h * 0.035

        // White clapboard walls
        ctx.fill(
            Path(CGRect(x: houseX, y: houseY - houseH, width: houseW, height: houseH)),
            with: .color(Color(red: 0.75, green: 0.72, blue: 0.65))
        )

        // Peaked roof
        var roof = Path()
        roof.move(to: CGPoint(x: houseX - houseW * 0.05, y: houseY - houseH))
        roof.addLine(to: CGPoint(x: houseX + houseW * 0.5, y: houseY - houseH - houseH * 0.5))
        roof.addLine(to: CGPoint(x: houseX + houseW * 1.05, y: houseY - houseH))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.25, green: 0.22, blue: 0.20)))

        // Warm lit window — the heart of the scene
        let winW = houseW * 0.2
        let winH = houseH * 0.35
        let winX = houseX + houseW * 0.35
        let winY = houseY - houseH * 0.65

        // Window glow (warm HDR)
        let glowPulse = 0.85 + 0.15 * sin(t * 0.4)
        let glowColor = Color(red: 1.2 * glowPulse, green: 0.85 * glowPulse, blue: 0.35 * glowPulse)
        ctx.fill(
            Path(ellipseIn: CGRect(
                x: winX - winW * 1.5,
                y: winY - winH * 1.5,
                width: winW * 4,
                height: winH * 4
            )),
            with: .color(glowColor.opacity(0.08))
        )
        ctx.fill(
            Path(CGRect(x: winX, y: winY, width: winW, height: winH)),
            with: .color(glowColor.opacity(0.9))
        )
    }

    // MARK: - Hay Bales

    private func drawHayBales(ctx: GraphicsContext, w: Double, h: Double) {
        for bale in hayBales {
            let x = bale.cx * w
            let y = bale.cy * h
            let r = bale.radius * w

            // Round hay bale
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.7, width: r * 2, height: r * 1.4)),
                with: .color(Color(red: 0.55, green: 0.42, blue: 0.18))
            )

            // Highlight on top
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r * 0.6, y: y - r * 0.7, width: r * 1.2, height: r * 0.5)),
                with: .color(Color(red: 0.68, green: 0.52, blue: 0.22).opacity(0.4))
            )

            // Shadow underneath
            ctx.fill(
                Path(ellipseIn: CGRect(x: x - r * 1.2, y: y + r * 0.4, width: r * 2.4, height: r * 0.4)),
                with: .color(Color.black.opacity(0.15))
            )
        }
    }

    // MARK: - Wildflowers

    private func drawWildflowers(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for flower in wildflowers {
            let sway = sin(t * 1.2 + flower.swayPhase) * 1.5
            let x = flower.x * w + sway
            let y = flower.y * h
            let s = flower.size

            if flower.hue < 0.01 {
                // White — Queen Anne's lace (tiny dot cluster)
                for i in 0..<flower.petalCount {
                    let angle = Double(i) / Double(flower.petalCount) * .pi * 2
                    let dx = cos(angle) * s * 0.5
                    let dy = sin(angle) * s * 0.3
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x + dx - 0.5, y: y + dy - 0.5, width: 1, height: 1)),
                        with: .color(Color.white.opacity(0.5))
                    )
                }
            } else {
                // Coloured petals (goldenrod, aster)
                let petalColor: Color
                if flower.hue > 0.5 {
                    petalColor = Color(red: 0.55, green: 0.35, blue: 0.65) // purple aster
                } else {
                    petalColor = Color(red: 0.85, green: 0.70, blue: 0.15) // goldenrod
                }
                for i in 0..<flower.petalCount {
                    let angle = Double(i) / Double(flower.petalCount) * .pi * 2
                    let dx = cos(angle) * s * 0.4
                    let dy = sin(angle) * s * 0.25
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: x + dx - s * 0.15, y: y + dy - s * 0.1, width: s * 0.3, height: s * 0.2)),
                        with: .color(petalColor.opacity(0.6))
                    )
                }
            }
        }
    }

    // MARK: - Fireflies

    private func drawFireflies(ctx: GraphicsContext, w: Double, h: Double, t: Double) {
        for fly in fireflies {
            let dx = sin(t * 0.3 + fly.driftPhaseX) * fly.driftRadius
            let dy = cos(t * 0.25 + fly.driftPhaseY) * fly.driftRadius * 0.6
            let x = (fly.baseX + dx) * w
            let y = (fly.baseY + dy) * h

            // Blink pattern — long dark, brief glow
            let phase = (t * fly.blinkRate + fly.blinkPhase).truncatingRemainder(dividingBy: .pi * 2)
            let blink: Double
            if phase < 0.8 {
                blink = max(0, sin(phase / 0.8 * .pi)) * fly.brightness
            } else {
                blink = 0
            }

            if blink > 0.05 {
                // Warm yellow-green glow (HDR)
                let glowColor = Color(red: 0.7 * blink, green: 1.1 * blink, blue: 0.2 * blink)

                // Outer glow
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)),
                    with: .color(glowColor.opacity(blink * 0.15))
                )
                // Core
                ctx.fill(
                    Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)),
                    with: .color(glowColor.opacity(blink * 0.9))
                )
            }
        }
    }

    // MARK: - Vignette

    private func drawVignette(ctx: GraphicsContext, w: Double, h: Double) {
        let edgeDark = Color(red: 0.04, green: 0.03, blue: 0.02)

        // Bottom third — foreground fading to dark earth
        for i in 0..<15 {
            let frac = Double(i) / 14.0
            let y = h * (0.82 + frac * 0.18)
            ctx.fill(
                Path(CGRect(x: 0, y: y, width: w, height: h * 0.02 + 1)),
                with: .color(edgeDark.opacity(frac * 0.5))
            )
        }

        // Top — subtle darkening
        for i in 0..<8 {
            let frac = Double(i) / 7.0
            let y = h * (1.0 - frac) * 0.06
            ctx.fill(
                Path(CGRect(x: 0, y: y, width: w, height: h * 0.01 + 1)),
                with: .color(edgeDark.opacity((1.0 - frac) * 0.3))
            )
        }

        // Side vignette
        for i in 0..<10 {
            let frac = Double(i) / 9.0
            let stripW = w * 0.05
            ctx.fill(
                Path(CGRect(x: frac * stripW, y: 0, width: stripW * 0.3, height: h)),
                with: .color(edgeDark.opacity((1.0 - frac) * 0.15))
            )
            ctx.fill(
                Path(CGRect(x: w - frac * stripW - stripW * 0.3, y: 0, width: stripW * 0.3, height: h)),
                with: .color(edgeDark.opacity((1.0 - frac) * 0.15))
            )
        }
    }

    // MARK: - Utility

    private func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }
}
