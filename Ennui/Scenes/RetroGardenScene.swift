import SwiftUI

// Grey drizzly morning garden — Miffy simplicity meets Stardew warmth.
// Pixel-art flat fills (no blurs for perf), parallax rolling hills,
// dark ocean horizon, slowly turning windmill, gentle rain, dense
// simple flowers, swaying grass, butterflies, and tap-to-bloom.

struct RetroGardenScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()
    private let px: Double = 4.0

    struct FlowerData {
        let x, y, stemH: Double
        let r, g, b: Double
        let swayPhase, swaySpeed, size: Double
    }
    struct GrassData {
        let x, y, height, shade, swayPhase: Double
    }
    struct ButterflyData {
        let bx, by, r, g, b, phX, phY, wSpeed, wngSpeed: Double
    }
    struct CloudData {
        let baseY, w, h, speed, shade: Double
        var x: Double
    }
    struct Bloom: Identifiable {
        let id = UUID()
        let x, y, birth: Double
    }

    @State private var flowers: [FlowerData] = []
    @State private var grass: [GrassData] = []
    @State private var butterflies: [ButterflyData] = []
    @State private var clouds: [CloudData] = []
    @State private var blooms: [Bloom] = []
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawClouds(ctx: &ctx, size: size, t: t)
                drawOcean(ctx: &ctx, size: size, t: t)
                drawDistantHills(ctx: &ctx, size: size, t: t)
                drawWindmill(ctx: &ctx, size: size, t: t)
                drawMidHills(ctx: &ctx, size: size, t: t)
                drawGrass(ctx: &ctx, size: size, t: t)
                drawFlowers(ctx: &ctx, size: size, t: t)
                drawButterflies(ctx: &ctx, size: size, t: t)
                drawBlooms(ctx: &ctx, size: size, t: t)
                drawForeground(ctx: &ctx, size: size, t: t)
                drawRain(ctx: &ctx, size: size, t: t)
            }
        }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            guard let loc = interaction.tapLocation else { return }
            blooms.append(Bloom(x: loc.x, y: loc.y, birth: Date().timeIntervalSince(startDate)))
            if blooms.count > 6 { blooms.removeFirst() }
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 7742)
        let petalColors: [(Double, Double, Double)] = [
            (0.92, 0.45, 0.50), // rose pink
            (0.55, 0.70, 0.90), // sky blue
            (0.95, 0.75, 0.30), // golden
            (0.80, 0.50, 0.85), // lavender
            (0.95, 0.55, 0.55), // coral
            (0.60, 0.85, 0.65), // mint
            (0.90, 0.90, 0.50), // lemon
        ]
        flowers = (0..<55).map { i in
            let c = petalColors[i % petalColors.count]
            return FlowerData(
                x: nextDouble(&rng), y: 0.53 + nextDouble(&rng) * 0.38,
                stemH: 14 + nextDouble(&rng) * 24,
                r: c.0 + nextDouble(&rng) * 0.1 - 0.05,
                g: c.1 + nextDouble(&rng) * 0.1 - 0.05,
                b: c.2 + nextDouble(&rng) * 0.1 - 0.05,
                swayPhase: nextDouble(&rng) * .pi * 2,
                swaySpeed: 0.3 + nextDouble(&rng) * 0.5,
                size: 4 + nextDouble(&rng) * 5
            )
        }
        grass = (0..<140).map { _ in
            GrassData(
                x: nextDouble(&rng), y: 0.50 + nextDouble(&rng) * 0.42,
                height: 8 + nextDouble(&rng) * 18,
                shade: nextDouble(&rng),
                swayPhase: nextDouble(&rng) * .pi * 2
            )
        }
        butterflies = (0..<4).map { _ in
            ButterflyData(
                bx: 0.15 + nextDouble(&rng) * 0.7,
                by: 0.35 + nextDouble(&rng) * 0.25,
                r: 0.7 + nextDouble(&rng) * 0.3,
                g: 0.5 + nextDouble(&rng) * 0.5,
                b: 0.5 + nextDouble(&rng) * 0.5,
                phX: nextDouble(&rng) * .pi * 2,
                phY: nextDouble(&rng) * .pi * 2,
                wSpeed: 0.12 + nextDouble(&rng) * 0.15,
                wngSpeed: 3.0 + nextDouble(&rng) * 2.0
            )
        }
        clouds = (0..<7).map { _ in
            CloudData(
                baseY: 0.04 + nextDouble(&rng) * 0.18,
                w: 90 + nextDouble(&rng) * 140,
                h: 18 + nextDouble(&rng) * 28,
                speed: 3 + nextDouble(&rng) * 8,
                shade: 0.55 + nextDouble(&rng) * 0.18,
                x: nextDouble(&rng) * 1.4 - 0.2
            )
        }
        ready = true
    }

    // MARK: - Sky (luminous grey — bright overcast, sun behind clouds)

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let bands = 16
        for i in 0..<bands {
            let f = Double(i) / Double(bands)
            let y0 = h * f * 0.50
            let y1 = h * (f + 1.0 / Double(bands)) * 0.50
            // Top: grey-blue, bottom near horizon: luminous pearly white-grey
            let r = 0.50 + f * 0.22
            let g = 0.54 + f * 0.20
            let b = 0.60 + f * 0.14
            ctx.fill(Path(CGRect(x: 0, y: y0, width: w, height: y1 - y0 + 1)),
                     with: .color(Color(red: r, green: g, blue: b)))
        }
        // Subtle bright spot where sun hides behind clouds
        let sunX = w * 0.35
        let sunY = h * 0.12
        let sunR: Double = 50
        let rect = CGRect(x: sunX - sunR, y: sunY - sunR, width: sunR * 2, height: sunR * 2)
        ctx.fill(Path(ellipseIn: rect), with: .color(Color(red: 1.15, green: 1.1, blue: 1.0).opacity(0.3)))
    }

    // MARK: - Clouds (puffy grey, flat pixel fills)

    private func drawClouds(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for cloud in clouds {
            let cx = fmod(cloud.x + t * cloud.speed / w * 0.25 + 10, 1.6) - 0.2
            let x = cx * w
            let y = cloud.baseY * h
            let cw = cloud.w
            let ch = cloud.h
            let s = cloud.shade
            // Flat pixel-style cloud: overlapping rectangles
            let steps = Int(cw / (px * 2))
            for j in 0..<steps {
                let dx = Double(j) * px * 2 - cw * 0.5
                let frac = abs(dx) / (cw * 0.5)
                let localH = ch * max(0, 1.0 - frac * frac)
                let r = CGRect(x: snap(x + dx), y: snap(y - localH * 0.5),
                               width: px * 2, height: snap(localH))
                ctx.fill(Path(r), with: .color(Color(red: s, green: s + 0.01, blue: s + 0.03)))
            }
        }
    }

    // MARK: - Ocean (dark moody water at horizon)

    private func drawOcean(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let top = h * 0.33, bot = h * 0.44
        ctx.fill(Path(CGRect(x: 0, y: top, width: w, height: bot - top)),
                 with: .color(Color(red: 0.10, green: 0.12, blue: 0.16)))
        // Wave highlights (flat pixel lines)
        for row in 0..<6 {
            let wy = top + Double(row) * (bot - top) / 6.0
            var path = Path()
            path.move(to: CGPoint(x: 0, y: wy))
            for xi in stride(from: 0.0, through: w, by: px * 2) {
                let wave = sin(xi * 0.015 + t * 0.4 + Double(row) * 1.5) * 2
                path.addLine(to: CGPoint(x: xi, y: wy + wave))
            }
            ctx.stroke(path, with: .color(Color(red: 0.18, green: 0.20, blue: 0.26, opacity: 0.5)),
                       lineWidth: 1)
        }
    }

    // MARK: - Distant hills (dark green silhouettes)

    private func drawDistantHills(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.44))
        for xi in stride(from: 0.0, through: w, by: px) {
            let f = xi / w
            let hill = sin(f * 3.2 + 0.5) * 28 + sin(f * 7.0 + 1.3) * 12 + sin(f * 1.1) * 42
            path.addLine(to: CGPoint(x: xi, y: h * 0.40 - hill))
        }
        path.addLine(to: CGPoint(x: w, y: h * 0.55))
        path.addLine(to: CGPoint(x: 0, y: h * 0.55))
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(red: 0.16, green: 0.28, blue: 0.18)))
    }

    // MARK: - Windmill (modern, slowly turning)

    private func drawWindmill(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let baseX = w * 0.73
        let baseY = h * 0.40
        let towerH: Double = 80
        let towerW: Double = 14

        // Tower (tapered white-grey)
        var tower = Path()
        tower.move(to: CGPoint(x: snap(baseX - towerW * 0.55), y: snap(baseY)))
        tower.addLine(to: CGPoint(x: snap(baseX - towerW * 0.25), y: snap(baseY - towerH)))
        tower.addLine(to: CGPoint(x: snap(baseX + towerW * 0.25), y: snap(baseY - towerH)))
        tower.addLine(to: CGPoint(x: snap(baseX + towerW * 0.55), y: snap(baseY)))
        tower.closeSubpath()
        ctx.fill(tower, with: .color(Color(red: 0.82, green: 0.80, blue: 0.76)))

        // Nacelle
        let nac = CGRect(x: snap(baseX - 7), y: snap(baseY - towerH - 5), width: 14, height: 8)
        ctx.fill(Path(roundedRect: nac, cornerRadius: 2), with: .color(Color(red: 0.72, green: 0.70, blue: 0.66)))

        // 3 blades rotating
        let hubX = baseX, hubY = baseY - towerH
        let bladeLen: Double = 52
        for i in 0..<3 {
            let angle = t * 0.25 + Double(i) * (.pi * 2.0 / 3.0)
            let tipX = hubX + cos(angle) * bladeLen
            let tipY = hubY + sin(angle) * bladeLen
            let perpX = -sin(angle) * 4.0
            let perpY = cos(angle) * 4.0
            var blade = Path()
            blade.move(to: CGPoint(x: hubX, y: hubY))
            blade.addLine(to: CGPoint(x: tipX + perpX * 0.12, y: tipY + perpY * 0.12))
            blade.addLine(to: CGPoint(x: tipX - perpX * 0.12, y: tipY - perpY * 0.12))
            blade.closeSubpath()
            ctx.fill(blade, with: .color(Color(white: 0.87, opacity: 0.92)))
        }
        // Hub
        ctx.fill(Path(ellipseIn: CGRect(x: hubX - 3, y: hubY - 3, width: 6, height: 6)),
                 with: .color(Color(red: 0.55, green: 0.53, blue: 0.50)))
    }

    // MARK: - Mid hills (main grassy area, two layers for depth)

    private func drawMidHills(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Back mid hill
        var p1 = Path()
        p1.move(to: CGPoint(x: 0, y: h))
        for xi in stride(from: 0.0, through: w, by: px) {
            let f = xi / w
            let hill = sin(f * 2.0 + 0.7) * 32 + sin(f * 5.5 + 2.0) * 14 + cos(f * 0.9) * 22
            p1.addLine(to: CGPoint(x: xi, y: h * 0.54 - hill))
        }
        p1.addLine(to: CGPoint(x: w, y: h))
        p1.closeSubpath()
        ctx.fill(p1, with: .color(Color(red: 0.24, green: 0.48, blue: 0.26)))

        // Front mid hill (slightly lighter)
        var p2 = Path()
        p2.move(to: CGPoint(x: 0, y: h))
        for xi in stride(from: 0.0, through: w, by: px) {
            let f = xi / w
            let hill = sin(f * 1.8 + 1.5) * 24 + sin(f * 4.2 + 0.3) * 10 + sin(f * 0.6) * 18
            p2.addLine(to: CGPoint(x: xi, y: h * 0.60 - hill))
        }
        p2.addLine(to: CGPoint(x: w, y: h))
        p2.closeSubpath()
        ctx.fill(p2, with: .color(Color(red: 0.28, green: 0.55, blue: 0.30)))
    }

    // MARK: - Grass blades (swaying in breeze)

    private func drawGrass(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for g in grass {
            let x = g.x * w
            let y = g.y * h
            let sway = sin(t * 1.0 + g.swayPhase) * 4
            let green = 0.38 + g.shade * 0.22
            var path = Path()
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x + sway, y: y - g.height))
            path.addLine(to: CGPoint(x: x + px * 0.5, y: y))
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(red: 0.18, green: green, blue: 0.16)))
        }
    }

    // MARK: - Flowers (Miffy-simple: stem + 4 circle petals + center)

    private func drawFlowers(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for f in flowers {
            let x = f.x * w
            let y = f.y * h
            let sway = sin(t * f.swaySpeed + f.swayPhase) * 3
            let topX = x + sway
            let topY = y - f.stemH
            let s = f.size

            // Stem
            var stem = Path()
            stem.move(to: CGPoint(x: snap(x), y: snap(y)))
            stem.addLine(to: CGPoint(x: snap(topX), y: snap(topY)))
            ctx.stroke(stem, with: .color(Color(red: 0.18, green: 0.42, blue: 0.18)), lineWidth: 1.5)

            // Four petals (simple circles, Miffy style)
            let pc = Color(red: min(f.r, 1), green: min(f.g, 1), blue: min(f.b, 1))
            let offsets: [(Double, Double)] = [(-s * 0.55, 0), (s * 0.55, 0), (0, -s * 0.55), (0, s * 0.55)]
            for (dx, dy) in offsets {
                let pr = CGRect(x: snap(topX + dx - s * 0.4), y: snap(topY + dy - s * 0.4),
                                width: snap(s * 0.8), height: snap(s * 0.8))
                ctx.fill(Path(ellipseIn: pr), with: .color(pc))
            }
            // Yellow center
            let cr = CGRect(x: snap(topX - s * 0.22), y: snap(topY - s * 0.22),
                            width: snap(s * 0.44), height: snap(s * 0.44))
            ctx.fill(Path(ellipseIn: cr), with: .color(Color(red: 1.15, green: 1.05, blue: 0.4)))
        }
    }

    // MARK: - Butterflies (flat pixel style)

    private func drawButterflies(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for bf in butterflies {
            let wx = sin(t * bf.wSpeed + bf.phX) * w * 0.10
            let wy = sin(t * bf.wSpeed * 0.7 + bf.phY) * h * 0.05
            let x = bf.bx * w + wx
            let y = bf.by * h + wy
            let wing = abs(sin(t * bf.wngSpeed)) * 7
            let c = Color(red: bf.r, green: bf.g, blue: bf.b)
            // Wings (pixel ellipses)
            ctx.fill(Path(ellipseIn: CGRect(x: snap(x - wing - 3), y: snap(y - 2),
                                            width: snap(wing + 2), height: px)),
                     with: .color(c.opacity(0.85)))
            ctx.fill(Path(ellipseIn: CGRect(x: snap(x + 1), y: snap(y - 2),
                                            width: snap(wing + 2), height: px)),
                     with: .color(c.opacity(0.85)))
            // Body
            ctx.fill(Path(CGRect(x: snap(x), y: snap(y - 1), width: px * 0.25, height: px * 0.75)),
                     with: .color(Color(red: 0.2, green: 0.15, blue: 0.1)))
        }
    }

    // MARK: - Tap blooms (flowers burst out from tap point)

    private func drawBlooms(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for b in blooms {
            let age = t - b.birth
            guard age < 3.5 else { continue }
            let progress = age / 3.5
            let fade = max(0, 1.0 - progress)
            let petals = 10
            for i in 0..<petals {
                let angle = Double(i) / Double(petals) * .pi * 2 + age * 0.4
                let dist = progress * 65
                let px = b.x + cos(angle) * dist
                let py = b.y + sin(angle) * dist - progress * 20
                let s = 4.0 * fade
                let hueShift = Double(i) / Double(petals)
                let colors: [(Double, Double, Double)] = [
                    (1.15, 0.65, 0.70), (0.70, 0.90, 1.15), (1.2, 1.0, 0.5),
                    (1.0, 0.65, 1.1), (0.70, 1.1, 0.8),
                ]
                let c = colors[i % colors.count]
                let r = CGRect(x: px - s, y: py - s, width: s * 2, height: s * 2)
                ctx.fill(Path(ellipseIn: r), with: .color(
                    Color(red: c.0, green: c.1, blue: c.2).opacity(fade * 0.7)))
            }
        }
    }

    // MARK: - Foreground (darker bottom hill)

    private func drawForeground(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h))
        for xi in stride(from: 0.0, through: w, by: px) {
            let f = xi / w
            let hill = sin(f * 1.4 + 3.0) * 14 + sin(f * 4.5 + 0.5) * 7
            path.addLine(to: CGPoint(x: xi, y: h * 0.89 - hill))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.closeSubpath()
        ctx.fill(path, with: .color(Color(red: 0.20, green: 0.40, blue: 0.22)))
    }

    // MARK: - Rain (gentle drizzle, slight wind drift)

    private func drawRain(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        var rng = SplitMix64(seed: 9999)
        for i in 0..<70 {
            let baseX = nextDouble(&rng) * w
            let speed = 0.35 + nextDouble(&rng) * 0.4
            let length = 6 + nextDouble(&rng) * 10
            let y = fmod(nextDouble(&rng) + t * speed, 1.1) * h
            let x = baseX + sin(t * 0.3 + Double(i)) * 2 // wind drift
            var path = Path()
            path.move(to: CGPoint(x: snap(x), y: snap(y)))
            path.addLine(to: CGPoint(x: snap(x - 0.5), y: snap(y + length)))
            ctx.stroke(path, with: .color(Color(white: 0.72, opacity: 0.22)), lineWidth: 0.8)
        }
    }

    private func snap(_ v: Double) -> Double { (v / px).rounded() * px }
}
