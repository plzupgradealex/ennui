import SwiftUI

// Medieval Village Bedtime — A Busy Town / Richard Scarry–inspired medieval hamlet
// settling down for the night. Thatched-roof cottages, a stone church tower, a mill,
// tavern, blacksmith, well, market stalls. Warm firelight glows in windows and
// chimneys. Each tap puts out one more fire — a villager appears briefly, carrying
// a bucket or snuffing a candle. Gradually the village darkens, chimney smoke fades,
// and moonlight takes over. When all lights are out the village shimmers under stars
// and a gentle aurora. The user paces the whole ritual.

struct MedievalVillageScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // ── Data ──

    struct Building {
        let x, width, height: Double       // normalised x; pixel w/h
        let roofPeakExtra: Double           // how much roof extends above body
        let kind: BuildingKind
        let hasChimney: Bool
        let windowCols, windowRows: Int
        let hueShift: Double                // subtle variety
    }

    enum BuildingKind: Int { case cottage, tavern, church, blacksmith, mill, barn }

    struct TreeData {
        let x, scale, sway: Double
    }

    // Each "light source" is something the player can extinguish
    struct LightSource: Identifiable {
        let id: Int
        let buildingIndex: Int
        let kind: LightKind
        let nx, ny: Double       // normalised position relative to building
    }
    enum LightKind { case window, chimney, torch, forge }

    @State private var buildings: [Building] = []
    @State private var trees: [TreeData] = []
    @State private var lights: [LightSource] = []
    @State private var extinguished: Set<Int> = []
    @State private var snuffAnimations: [(x: Double, y: Double, birth: Double)] = []
    @State private var ready = false

    // Derived
    private var totalLights: Int { lights.count }
    private func lightsOut(_ t: Double) -> Int { extinguished.count }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            let progress = totalLights > 0 ? Double(extinguished.count) / Double(totalLights) : 0
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t, progress: progress)
                drawMoon(ctx: &ctx, size: size, t: t, progress: progress)
                drawStars(ctx: &ctx, size: size, t: t, progress: progress)
                drawDistantHills(ctx: &ctx, size: size, t: t, progress: progress)
                drawTrees(ctx: &ctx, size: size, t: t, back: true)
                drawGround(ctx: &ctx, size: size, t: t, progress: progress)
                drawBuildings(ctx: &ctx, size: size, t: t, progress: progress)
                drawTrees(ctx: &ctx, size: size, t: t, back: false)
                drawWell(ctx: &ctx, size: size, t: t)
                drawSmoke(ctx: &ctx, size: size, t: t, progress: progress)
                drawSnuffAnimations(ctx: &ctx, size: size, t: t)
                drawFireflies(ctx: &ctx, size: size, t: t, progress: progress)
                drawFog(ctx: &ctx, size: size, t: t, progress: progress)
            }
        }
        .background(.black)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            extinguishNext()
        }
    }

    // ── Setup ──

    private func setup() {
        var rng = SplitMix64(seed: 0xBED714E)

        // Place 8 buildings across the scene
        let kinds: [BuildingKind] = [.cottage, .tavern, .church, .cottage, .blacksmith, .mill, .barn, .cottage]
        var lightId = 0

        buildings = kinds.enumerated().map { i, kind in
            let nx = 0.06 + Double(i) * 0.115 + nextDouble(&rng) * 0.02
            let w = kind == .church ? 70.0 : (40 + nextDouble(&rng) * 30)
            let h: Double
            switch kind {
            case .church: h = 160 + nextDouble(&rng) * 30
            case .tavern: h = 80 + nextDouble(&rng) * 25
            case .mill: h = 100 + nextDouble(&rng) * 20
            case .barn: h = 70 + nextDouble(&rng) * 15
            case .blacksmith: h = 55 + nextDouble(&rng) * 15
            case .cottage: h = 45 + nextDouble(&rng) * 25
            }
            let roofExtra: Double = kind == .church ? 40 : (15 + nextDouble(&rng) * 15)
            let wCols = kind == .church ? 3 : (1 + Int(nextDouble(&rng) * 3))
            let wRows = max(1, Int(h / 45))
            let hasChimney = kind != .mill && nextDouble(&rng) > 0.2
            return Building(x: nx, width: w, height: h, roofPeakExtra: roofExtra,
                           kind: kind, hasChimney: hasChimney,
                           windowCols: wCols, windowRows: wRows,
                           hueShift: nextDouble(&rng) * 0.06)
        }

        // Generate light sources for each building
        for (bi, b) in buildings.enumerated() {
            for row in 0..<b.windowRows {
                for col in 0..<b.windowCols {
                    let nx = 0.15 + Double(col) / Double(max(b.windowCols, 1)) * 0.7
                    let ny = 0.2 + Double(row) / Double(max(b.windowRows, 1)) * 0.6
                    lights.append(LightSource(id: lightId, buildingIndex: bi, kind: .window, nx: nx, ny: ny))
                    lightId += 1
                }
            }
            if b.hasChimney {
                lights.append(LightSource(id: lightId, buildingIndex: bi, kind: .chimney, nx: 0.75, ny: -0.1))
                lightId += 1
            }
            if b.kind == .blacksmith {
                lights.append(LightSource(id: lightId, buildingIndex: bi, kind: .forge, nx: 0.5, ny: 0.85))
                lightId += 1
            }
            if b.kind == .tavern {
                lights.append(LightSource(id: lightId, buildingIndex: bi, kind: .torch, nx: 0.05, ny: 0.5))
                lightId += 1
                lights.append(LightSource(id: lightId, buildingIndex: bi, kind: .torch, nx: 0.95, ny: 0.5))
                lightId += 1
            }
        }

        // Trees
        trees = (0..<14).map { _ in
            TreeData(x: nextDouble(&rng), scale: 0.6 + nextDouble(&rng) * 0.5,
                     sway: nextDouble(&rng) * .pi * 2)
        }

        ready = true
    }

    private func extinguishNext() {
        // Find next lit light source and extinguish it
        let lit = lights.filter { !extinguished.contains($0.id) }
        guard let next = lit.first else { return }
        extinguished.insert(next.id)

        // Spawn snuff animation
        let bi = next.buildingIndex
        guard bi < buildings.count else { return }
        let b = buildings[bi]
        let bx = b.x
        let by = 0.72 - b.height / 800.0
        snuffAnimations.append((x: bx + next.nx * b.width / 800.0, y: by + next.ny * b.height / 800.0,
                                birth: Date().timeIntervalSince(startDate)))
        if snuffAnimations.count > 12 { snuffAnimations.removeFirst() }
    }

    // ── Drawing ──

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        // Transition from dusk amber to deep night blue as lights go out
        let duskR = 0.18, duskG = 0.10, duskB = 0.22
        let nightR = 0.02, nightG = 0.02, nightB = 0.08
        let horizDuskR = 0.35, horizDuskG = 0.18, horizDuskB = 0.12
        let horizNightR = 0.03, horizNightG = 0.03, horizNightB = 0.10

        let p = progress
        let topR = duskR + (nightR - duskR) * p
        let topG = duskG + (nightG - duskG) * p
        let topB = duskB + (nightB - duskB) * p
        let botR = horizDuskR + (horizNightR - horizDuskR) * p
        let botG = horizDuskG + (horizNightG - horizDuskG) * p
        let botB = horizDuskB + (horizNightB - horizDuskB) * p

        ctx.fill(Rectangle().path(in: CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: [
                Color(red: topR, green: topG, blue: topB),
                Color(red: (topR + botR) / 2, green: (topG + botG) / 2, blue: (topB + botB) / 2),
                Color(red: botR, green: botG, blue: botB),
            ]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height * 0.7)))
    }

    private func drawMoon(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        let moonAlpha = progress * 0.9 + 0.1
        let mx = size.width * 0.8 + sin(t * 0.01) * 10
        let my = size.height * 0.12 - progress * size.height * 0.03
        let mr = 28.0

        // Glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 40))
            l.fill(Ellipse().path(in: CGRect(x: mx - 60, y: my - 60, width: 120, height: 120)),
                with: .color(Color(red: 0.7, green: 0.75, blue: 1.2).opacity(0.15 * moonAlpha)))
        }

        // Disc
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 2))
            l.fill(Ellipse().path(in: CGRect(x: mx - mr, y: my - mr, width: mr * 2, height: mr * 2)),
                with: .color(Color(red: 1.1, green: 1.05, blue: 0.95).opacity(moonAlpha * 0.9)))
        }

        // Crescent shadow
        ctx.fill(Ellipse().path(in: CGRect(x: mx - mr * 0.6, y: my - mr * 0.9, width: mr * 1.4, height: mr * 1.8)),
            with: .color(Color(red: 0.02, green: 0.02, blue: 0.08).opacity(moonAlpha * 0.3)))
    }

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        let starAlpha: Double = progress * 0.8 + 0.05
        var rng = SplitMix64(seed: 0xBEDDABE)
        for _ in 0..<200 {
            let x: Double = nextDouble(&rng) * size.width
            let y: Double = nextDouble(&rng) * size.height * 0.55
            let s: Double = nextDouble(&rng) * 1.8 + 0.4
            let b: Double = nextDouble(&rng) * 0.5 + 0.3
            let twSpeed: Double = 0.5 + nextDouble(&rng) * 1.5
            let twPhase: Double = nextDouble(&rng) * 6.28
            let tw: Double = sin(t * twSpeed + twPhase) * 0.25 + 0.75
            let rect = CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)
            ctx.fill(Ellipse().path(in: rect),
                with: .color(.white.opacity(b * tw * starAlpha)))
        }

        // Aurora that strengthens as village sleeps
        if progress > 0.5 {
            drawAurora(ctx: &ctx, size: size, t: t, progress: progress)
        }
    }

    private func drawAurora(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        let auroraAlpha: Double = (progress - 0.5) * 2.0 * 0.25
        let auroraColors: [Color] = [
            Color(red: 0.2, green: 1.2, blue: 0.5),
            Color(red: 0.3, green: 0.6, blue: 1.3),
            Color(red: 0.5, green: 0.3, blue: 1.2),
        ]
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            l.opacity = auroraAlpha
            for i in 0..<3 {
                var p = Path()
                let yBase: Double = size.height * 0.08 + Double(i) * 20
                p.move(to: CGPoint(x: 0, y: yBase))
                for xi in stride(from: 0, through: Int(size.width), by: 6) {
                    let nx: Double = Double(xi) / size.width
                    let py: Double = yBase + sin(nx * .pi * 4 + t * 0.08 + Double(i) * 0.8) * 25
                    p.addLine(to: CGPoint(x: Double(xi), y: py))
                }
                for xi in stride(from: Int(size.width), through: 0, by: -6) {
                    let nx: Double = Double(xi) / size.width
                    let py: Double = yBase + 35 + sin(nx * .pi * 3 + t * 0.05 + Double(i) * 1.2) * 20
                    p.addLine(to: CGPoint(x: Double(xi), y: py))
                }
                p.closeSubpath()
                l.fill(p, with: .color(auroraColors[i % auroraColors.count]))
            }
        }
    }

    private func drawDistantHills(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        for layer in 0..<3 {
            var rng = SplitMix64(seed: UInt64(700 + layer * 13))
            let baseY = size.height * (0.5 + Double(layer) * 0.08)
            let shade = 0.04 + Double(layer) * 0.02 - progress * 0.02
            var p = Path()
            p.move(to: CGPoint(x: 0, y: baseY))
            for x in stride(from: 0.0, through: size.width, by: 6) {
                let h = nextDouble(&rng) * 60 + sin(x * 0.003 + Double(layer)) * 40
                p.addLine(to: CGPoint(x: x, y: baseY - h))
            }
            p.addLine(to: CGPoint(x: size.width, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
            ctx.fill(p, with: .color(Color(red: shade, green: shade + 0.01, blue: shade + 0.03)))
        }
    }

    private func drawGround(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        let gy = size.height * 0.72
        // Grass that goes from warm dusk to cool moonlit
        let warmth = 1.0 - progress
        let gr = 0.04 + warmth * 0.06
        let gg = 0.08 + warmth * 0.04 + progress * 0.04
        let gb = 0.04 + progress * 0.06
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: gy, width: size.width, height: size.height - gy)),
            with: .linearGradient(Gradient(colors: [
                Color(red: gr, green: gg, blue: gb),
                Color(red: gr * 0.5, green: gg * 0.6, blue: gb * 0.8),
            ]), startPoint: CGPoint(x: 0, y: gy), endPoint: CGPoint(x: 0, y: size.height)))

        // Path/road through village
        let roadY = gy + 8
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: roadY, width: size.width, height: 14)),
            with: .color(Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.5)))
    }

    private func drawBuildings(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        let gy = size.height * 0.72

        for (bi, b) in buildings.enumerated() {
            let bx = b.x * size.width
            let bw = b.width
            let bh = b.height
            let by = gy - bh
            let hue = b.hueShift

            // Wall color — warm stone/timber that cools as night deepens
            let warmth = 1.0 - progress * 0.6
            let wallR = (0.22 + hue) * warmth + 0.04
            let wallG = (0.18 + hue * 0.5) * warmth + 0.03
            let wallB = 0.12 * warmth + 0.03 + progress * 0.02

            // Building body
            ctx.fill(Rectangle().path(in: CGRect(x: bx, y: by, width: bw, height: bh)),
                with: .color(Color(red: wallR, green: wallG, blue: wallB)))

            // Timber frame lines
            if b.kind == .cottage || b.kind == .tavern {
                let frameColor = Color(red: 0.15, green: 0.10, blue: 0.06).opacity(0.4)
                // Cross beams
                for row in 0..<b.windowRows + 1 {
                    let ly = by + Double(row) * bh / Double(b.windowRows + 1)
                    ctx.fill(Rectangle().path(in: CGRect(x: bx, y: ly - 1, width: bw, height: 2)), with: .color(frameColor))
                }
                // Vertical beams
                ctx.fill(Rectangle().path(in: CGRect(x: bx, y: by, width: 3, height: bh)), with: .color(frameColor))
                ctx.fill(Rectangle().path(in: CGRect(x: bx + bw - 3, y: by, width: 3, height: bh)), with: .color(frameColor))
                ctx.fill(Rectangle().path(in: CGRect(x: bx + bw / 2 - 1, y: by, width: 2, height: bh)), with: .color(frameColor))
            }

            // Roof — thatched triangle
            let roofExtra = b.roofPeakExtra
            var roof = Path()
            let roofOverhang = 8.0
            roof.move(to: CGPoint(x: bx - roofOverhang, y: by))
            roof.addLine(to: CGPoint(x: bx + bw / 2, y: by - roofExtra))
            roof.addLine(to: CGPoint(x: bx + bw + roofOverhang, y: by))
            roof.closeSubpath()
            let roofR = 0.14 + hue * 0.4
            let roofG = 0.10 + hue * 0.2
            let roofB = 0.06
            ctx.fill(roof, with: .color(Color(red: roofR, green: roofG, blue: roofB)))

            // Thatch texture lines
            for ti in 0..<Int(bw / 5) {
                let tx = bx + Double(ti) * 5 + 2
                guard tx < bx + bw else { continue }
                let fraction = (tx - bx) / bw
                let topY = by - roofExtra * (1 - abs(fraction - 0.5) * 2)
                var line = Path()
                line.move(to: CGPoint(x: tx, y: topY + 3))
                line.addLine(to: CGPoint(x: tx, y: by))
                ctx.stroke(line, with: .color(Color(red: roofR - 0.03, green: roofG - 0.02, blue: roofB).opacity(0.3)), lineWidth: 0.5)
            }

            // Church tower details
            if b.kind == .church {
                // Cross on top
                let crossX = bx + bw / 2
                let crossY = by - roofExtra - 12
                ctx.fill(Rectangle().path(in: CGRect(x: crossX - 1, y: crossY, width: 2, height: 12)), with: .color(.white.opacity(0.4)))
                ctx.fill(Rectangle().path(in: CGRect(x: crossX - 5, y: crossY + 3, width: 10, height: 2)), with: .color(.white.opacity(0.4)))
                // Arched window
                let archW = 14.0, archH = 22.0
                let archX = bx + bw / 2 - archW / 2
                let archY = by + 15
                var arch = Path()
                arch.addArc(center: CGPoint(x: archX + archW / 2, y: archY + archH - archW / 2), radius: archW / 2,
                           startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                arch.addLine(to: CGPoint(x: archX + archW, y: archY + archH))
                arch.addLine(to: CGPoint(x: archX, y: archY + archH))
                arch.closeSubpath()
                let churchLit = !lights.filter { $0.buildingIndex == bi && extinguished.contains($0.id) }.isEmpty
                let archAlpha = churchLit ? 0.2 : 0.5
                ctx.fill(arch, with: .color(Color(red: 1.1, green: 0.85, blue: 0.4).opacity(archAlpha)))
            }

            // Door
            let doorW = min(bw * 0.25, 14)
            let doorH = min(bh * 0.3, 24)
            let doorX = bx + bw / 2 - doorW / 2
            let doorY = gy - doorH
            ctx.fill(Rectangle().path(in: CGRect(x: doorX, y: doorY, width: doorW, height: doorH)),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.05)))

            // Windows with warm glow that extinguishes
            for light in lights where light.buildingIndex == bi && light.kind == .window {
                let isLit = !extinguished.contains(light.id)
                let wx = bx + light.nx * bw
                let wy = by + light.ny * bh
                let ww = 8.0, wh = 10.0
                let wr = CGRect(x: wx - ww / 2, y: wy - wh / 2, width: ww, height: wh)

                if isLit {
                    let flicker = sin(t * 2.5 + Double(light.id) * 1.3) * 0.08 + 0.92
                    // Warm window glow spill
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 12))
                        l.fill(Ellipse().path(in: wr.insetBy(dx: -8, dy: -8)),
                            with: .color(Color(red: 1.3, green: 0.8, blue: 0.3).opacity(0.12 * flicker)))
                    }
                    ctx.fill(Rectangle().path(in: wr),
                        with: .color(Color(red: 1.2 * flicker, green: 0.85 * flicker, blue: 0.35).opacity(0.85)))
                    // Window cross
                    ctx.fill(Rectangle().path(in: CGRect(x: wx - 0.5, y: wy - wh / 2, width: 1, height: wh)),
                        with: .color(Color(red: 0.15, green: 0.1, blue: 0.06).opacity(0.6)))
                    ctx.fill(Rectangle().path(in: CGRect(x: wx - ww / 2, y: wy - 0.5, width: ww, height: 1)),
                        with: .color(Color(red: 0.15, green: 0.1, blue: 0.06).opacity(0.6)))
                } else {
                    // Dark window reflecting moonlight
                    let moonRef = progress * 0.15
                    ctx.fill(Rectangle().path(in: wr),
                        with: .color(Color(red: 0.05 + moonRef, green: 0.06 + moonRef, blue: 0.10 + moonRef * 1.5).opacity(0.6)))
                }
            }

            // Torches (tavern)
            for light in lights where light.buildingIndex == bi && light.kind == .torch {
                let isLit = !extinguished.contains(light.id)
                let tx = bx + light.nx * bw
                let ty = by + light.ny * bh
                // Bracket
                ctx.fill(Rectangle().path(in: CGRect(x: tx - 1, y: ty - 8, width: 2, height: 12)),
                    with: .color(Color(red: 0.2, green: 0.15, blue: 0.1).opacity(0.6)))
                if isLit {
                    let flick = sin(t * 5 + Double(light.id) * 2) * 0.15 + 0.85
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 15))
                        l.fill(Ellipse().path(in: CGRect(x: tx - 12, y: ty - 20, width: 24, height: 24)),
                            with: .color(Color(red: 1.4, green: 0.7, blue: 0.2).opacity(0.2 * flick)))
                    }
                    // Flame
                    var flame = Path()
                    flame.move(to: CGPoint(x: tx, y: ty - 12))
                    flame.addQuadCurve(to: CGPoint(x: tx + 3, y: ty - 4), control: CGPoint(x: tx + 4, y: ty - 8))
                    flame.addQuadCurve(to: CGPoint(x: tx, y: ty - 12), control: CGPoint(x: tx - 4, y: ty - 8))
                    ctx.fill(flame, with: .color(Color(red: 1.3 * flick, green: 0.6, blue: 0.15).opacity(0.9)))
                }
            }

            // Forge glow (blacksmith)
            for light in lights where light.buildingIndex == bi && light.kind == .forge {
                let isLit = !extinguished.contains(light.id)
                if isLit {
                    let fx = bx + light.nx * bw
                    let fy = by + light.ny * bh
                    let pulse = sin(t * 3 + Double(light.id)) * 0.15 + 0.85
                    ctx.drawLayer { l in
                        l.addFilter(.blur(radius: 20))
                        l.fill(Ellipse().path(in: CGRect(x: fx - 25, y: fy - 20, width: 50, height: 30)),
                            with: .color(Color(red: 1.5, green: 0.5, blue: 0.1).opacity(0.15 * pulse)))
                    }
                }
            }

            // Chimney
            if b.hasChimney {
                let cx = bx + bw * 0.75
                let cy = by - roofExtra * 0.3
                ctx.fill(Rectangle().path(in: CGRect(x: cx - 4, y: cy - 14, width: 8, height: 18)),
                    with: .color(Color(red: 0.15, green: 0.12, blue: 0.10)))
            }
        }
    }

    private func drawSmoke(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 14))
            for (bi, b) in buildings.enumerated() where b.hasChimney {
                // Check if chimney light is still lit
                let chimneyLit = lights.first(where: { $0.buildingIndex == bi && $0.kind == .chimney })
                    .map { !extinguished.contains($0.id) } ?? false
                guard chimneyLit else { continue }

                let bx = b.x * size.width + b.width * 0.75
                let by = size.height * 0.72 - b.height - b.roofPeakExtra * 0.3 - 14

                for i in 0..<6 {
                    let age = fmod(t * 0.3 + Double(i) * 0.4, 2.4)
                    let rise = age * 35
                    let drift = sin(t * 0.2 + Double(i)) * 12 + age * 5
                    let fade = max(0, 1.0 - age / 2.4)
                    let sz = 10 + age * 12
                    l.fill(Ellipse().path(in: CGRect(x: bx + drift - sz / 2, y: by - rise - sz / 2, width: sz, height: sz * 0.6)),
                        with: .color(.white.opacity(0.06 * fade)))
                }
            }
        }
    }

    private func drawTrees(ctx: inout GraphicsContext, size: CGSize, t: Double, back: Bool) {
        let gy = size.height * 0.72
        for tree in trees {
            let isBack = tree.x < 0.15 || tree.x > 0.85
            guard isBack == back else { continue }
            let tx = tree.x * size.width
            let sc = tree.scale
            let sway = sin(t * 0.4 + tree.sway) * 3

            // Trunk
            ctx.fill(Rectangle().path(in: CGRect(x: tx - 3 * sc, y: gy - 45 * sc, width: 6 * sc, height: 45 * sc)),
                with: .color(Color(red: 0.12, green: 0.08, blue: 0.05)))

            // Foliage — 3 circles
            for (ox, oy, r) in [(-8.0, -50.0, 18.0), (5.0, -55.0, 15.0), (-2.0, -62.0, 13.0)] {
                let fx = tx + ox * sc + sway
                let fy = gy + oy * sc
                let fr = r * sc
                ctx.fill(Ellipse().path(in: CGRect(x: fx - fr, y: fy - fr, width: fr * 2, height: fr * 2)),
                    with: .color(Color(red: 0.06, green: 0.12, blue: 0.06).opacity(isBack ? 0.6 : 0.85)))
            }
        }
    }

    private func drawWell(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let wx = size.width * 0.58
        let wy = size.height * 0.72 + 2
        // Stone base
        ctx.fill(Ellipse().path(in: CGRect(x: wx - 12, y: wy - 4, width: 24, height: 10)),
            with: .color(Color(red: 0.15, green: 0.13, blue: 0.12)))
        ctx.fill(Rectangle().path(in: CGRect(x: wx - 10, y: wy - 14, width: 20, height: 14)),
            with: .color(Color(red: 0.13, green: 0.11, blue: 0.10)))
        // Roof posts
        ctx.fill(Rectangle().path(in: CGRect(x: wx - 9, y: wy - 28, width: 2, height: 16)),
            with: .color(Color(red: 0.12, green: 0.08, blue: 0.05)))
        ctx.fill(Rectangle().path(in: CGRect(x: wx + 7, y: wy - 28, width: 2, height: 16)),
            with: .color(Color(red: 0.12, green: 0.08, blue: 0.05)))
        // Tiny roof
        var roof = Path()
        roof.move(to: CGPoint(x: wx - 14, y: wy - 28))
        roof.addLine(to: CGPoint(x: wx, y: wy - 34))
        roof.addLine(to: CGPoint(x: wx + 14, y: wy - 28))
        roof.closeSubpath()
        ctx.fill(roof, with: .color(Color(red: 0.14, green: 0.10, blue: 0.06)))
    }

    private func drawSnuffAnimations(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        for anim in snuffAnimations {
            let age = t - anim.birth
            guard age < 2.0 else { continue }
            let p = age / 2.0
            let fade = (1 - p) * (1 - p)

            // Little puff of smoke where light was extinguished
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 8))
                let px = anim.x * size.width
                let py = anim.y * size.height - p * 30
                let sz = 10 + p * 20
                l.fill(Ellipse().path(in: CGRect(x: px - sz / 2, y: py - sz / 2, width: sz, height: sz)),
                    with: .color(.white.opacity(0.15 * fade)))
            }

            // Tiny villager silhouette walking away
            let vx = anim.x * size.width + (age - 0.5) * 15
            let vy = size.height * 0.72 - 8
            if age > 0.3 && age < 1.8 {
                let vFade = min((age - 0.3) / 0.3, 1.0) * max(0, (1.8 - age) / 0.5)
                // Head
                ctx.fill(Ellipse().path(in: CGRect(x: vx - 2, y: vy - 10, width: 4, height: 4)),
                    with: .color(Color(red: 0.08, green: 0.06, blue: 0.04).opacity(vFade * 0.6)))
                // Body
                ctx.fill(Rectangle().path(in: CGRect(x: vx - 2, y: vy - 6, width: 4, height: 6)),
                    with: .color(Color(red: 0.08, green: 0.06, blue: 0.04).opacity(vFade * 0.6)))
            }
        }
    }

    private func drawFireflies(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        guard progress > 0.3 else { return }
        let ffAlpha = (progress - 0.3) / 0.7

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 8))
            var rng = SplitMix64(seed: 0xF10EF11)
            for _ in 0..<Int(30 * ffAlpha) {
                let bx = nextDouble(&rng)
                let by = 0.5 + nextDouble(&rng) * 0.3
                let sp = nextDouble(&rng) * 0.4 + 0.2
                let ph = nextDouble(&rng) * .pi * 2
                let x = (bx + sin(t * sp + ph) * 0.04) * size.width
                let y = by * size.height + cos(t * sp * 0.7 + ph) * 15
                let pulse = sin(t * 1.5 + ph) * 0.5 + 0.5
                l.fill(Ellipse().path(in: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)),
                    with: .color(Color(red: 1.2, green: 1.15, blue: 0.5).opacity(pulse * 0.2 * ffAlpha)))
            }
        }
    }

    private func drawFog(ctx: inout GraphicsContext, size: CGSize, t: Double, progress: Double) {
        guard progress > 0.4 else { return }
        let fogAlpha = (progress - 0.4) / 0.6 * 0.12

        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 45))
            for i in 0..<5 {
                let off = Double(i) * size.width * 0.25
                let x = fmod(off - t * 4 + size.width * 2, size.width + 200) - 100
                let y = size.height * 0.68 + sin(t * 0.1 + Double(i)) * 10
                let w = 200 + sin(t * 0.08 + Double(i) * 1.5) * 40
                l.fill(Ellipse().path(in: CGRect(x: x, y: y, width: w, height: 35)),
                    with: .color(.white.opacity(fogAlpha)))
            }
        }
    }
}
