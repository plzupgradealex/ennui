import SwiftUI

// Floating Kingdom — A sky kingdom above an ocean of clouds, inspired by
// the ethereal beauty of Zeal (Chrono Trigger, 12000 BC) and the Esper
// World (Final Fantasy VI). Crystalline spires rise from floating islands.
// Waterfalls cascade off the edges into luminous mist. Magical energy motes
// drift upward like prayers. Aurora-like bands of ancient power ripple
// across the sky. The palette is Zeal's signature blue-purple-gold with
// warm crystalline accents. Everything floats. Everything glows. Everything
// is at peace.
//
// Tap sends a pulse of magical energy rippling outward from the touch
// point — esper light, Mammon Machine resonance, whatever you want to
// call it. It's warm and it means no harm.
//
// Seed: 12000 (Zeal's era in Chrono Trigger).

struct FloatingKingdomScene: View {
    @ObservedObject var interaction: InteractionState

    private let startDate = Date()
    private let px: Double = 2.0

    // Procedural data
    @State private var stars: [StarData] = []
    @State private var islands: [FloatingIsland] = []
    @State private var spires: [CrystalSpire] = []
    @State private var waterfalls: [Waterfall] = []
    @State private var motes: [MagicMote] = []
    @State private var pulses: [EnergyPulse] = []
    @State private var ready = false

    struct StarData {
        let x, y, brightness, size, twinkleRate, twinklePhase: Double
    }

    struct FloatingIsland {
        let cx, cy: Double        // center position (normalized)
        let width, height: Double  // island dimensions
        let bobPhase: Double       // vertical bobbing phase offset
        let bobAmp: Double         // bobbing amplitude
        let grassSeed: UInt64
        let hasRuin: Bool          // small ruin on top
        let depth: Double          // 0=far, 1=near — parallax + size
    }

    struct CrystalSpire {
        let islandIndex: Int       // which island it sits on
        let offsetX: Double        // offset from island center
        let height: Double
        let width: Double
        let hue: Double            // blue-purple range
        let glowPhase: Double
        let facets: Int
    }

    struct Waterfall {
        let islandIndex: Int
        let side: Double           // -1 left, 1 right
        let width: Double
        let cascadeSpeed: Double
    }

    struct MagicMote {
        var x, y: Double
        let size: Double
        let hue: Double            // warm gold to cool blue range
        let speed: Double
        let drift: Double
        let phase: Double
        let brightness: Double
    }

    struct EnergyPulse {
        let cx, cy: Double
        let birth: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawAuroraBands(ctx: &ctx, size: size, t: t)
                drawCloudSea(ctx: &ctx, size: size, t: t)

                // Draw islands back to front (by depth)
                let sortedIndices = islands.indices.sorted { islands[$0].depth < islands[$1].depth }
                for idx in sortedIndices {
                    drawIsland(ctx: &ctx, size: size, t: t, index: idx)
                }

                drawMotes(ctx: &ctx, size: size, t: t)
                drawPulses(ctx: &ctx, size: size, t: t)
                drawVignette(ctx: &ctx, size: size)
            }
        }
        .background(Color(red: 0.04, green: 0.02, blue: 0.1))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            let t = Date().timeIntervalSince(startDate)
            guard let loc = interaction.tapLocation else { return }
            // Energy pulse from tap
            let nx = loc.x / max(1, loc.x + 200) // approximate normalize
            let ny = loc.y / max(1, loc.y + 200)
            pulses.append(EnergyPulse(cx: nx, cy: ny, birth: t))
            if pulses.count > 8 { pulses.removeFirst() }
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 12000)

        // Stars in the deep sky
        for _ in 0..<200 {
            stars.append(StarData(
                x: rng.nextDouble(),
                y: rng.nextDouble() * 0.55,
                brightness: 0.15 + rng.nextDouble() * 0.85,
                size: 0.4 + rng.nextDouble() * 1.6,
                twinkleRate: 0.3 + rng.nextDouble() * 2.5,
                twinklePhase: rng.nextDouble() * .pi * 2
            ))
        }

        // Main central island (the palace island)
        islands.append(FloatingIsland(
            cx: 0.5, cy: 0.42,
            width: 0.3, height: 0.06,
            bobPhase: 0, bobAmp: 0.003,
            grassSeed: UInt64(rng.nextDouble() * Double(UInt32.max)),
            hasRuin: true,
            depth: 0.6
        ))

        // Surrounding islands
        let positions: [(Double, Double, Double, Double, Double)] = [
            (0.18, 0.38, 0.12, 0.035, 0.3),
            (0.82, 0.40, 0.10, 0.030, 0.35),
            (0.35, 0.52, 0.08, 0.025, 0.7),
            (0.68, 0.50, 0.09, 0.028, 0.65),
            (0.12, 0.55, 0.06, 0.020, 0.8),
            (0.88, 0.54, 0.07, 0.022, 0.75),
            (0.50, 0.60, 0.05, 0.018, 0.9),
        ]
        for (cx, cy, w, h, depth) in positions {
            islands.append(FloatingIsland(
                cx: cx + (rng.nextDouble() - 0.5) * 0.04,
                cy: cy + (rng.nextDouble() - 0.5) * 0.02,
                width: w + (rng.nextDouble() - 0.5) * 0.02,
                height: h,
                bobPhase: rng.nextDouble() * .pi * 2,
                bobAmp: 0.002 + rng.nextDouble() * 0.003,
                grassSeed: UInt64(rng.nextDouble() * Double(UInt32.max)),
                hasRuin: rng.nextDouble() > 0.6,
                depth: depth
            ))
        }

        // Crystal spires on islands
        for i in 0..<islands.count {
            let count = i == 0 ? 5 : (rng.nextDouble() > 0.4 ? 2 : 1)
            for _ in 0..<count {
                spires.append(CrystalSpire(
                    islandIndex: i,
                    offsetX: (rng.nextDouble() - 0.5) * 0.6,
                    height: (i == 0 ? 60 : 25) + rng.nextDouble() * (i == 0 ? 50 : 30),
                    width: 4 + rng.nextDouble() * 8,
                    hue: 0.55 + rng.nextDouble() * 0.2, // blue to purple
                    glowPhase: rng.nextDouble() * .pi * 2,
                    facets: 3 + Int(rng.nextDouble() * 3)
                ))
            }
        }

        // Waterfalls from larger islands
        for i in 0..<min(5, islands.count) {
            if rng.nextDouble() > 0.3 {
                waterfalls.append(Waterfall(
                    islandIndex: i,
                    side: rng.nextDouble() > 0.5 ? 1 : -1,
                    width: 3 + rng.nextDouble() * 5,
                    cascadeSpeed: 40 + rng.nextDouble() * 30
                ))
            }
        }

        // Magic motes drifting upward
        for _ in 0..<80 {
            motes.append(MagicMote(
                x: rng.nextDouble(),
                y: rng.nextDouble(),
                size: 1.0 + rng.nextDouble() * 3.0,
                hue: rng.nextDouble(), // full range — gold through blue
                speed: 0.008 + rng.nextDouble() * 0.015,
                drift: (rng.nextDouble() - 0.5) * 0.003,
                phase: rng.nextDouble() * .pi * 2,
                brightness: 0.3 + rng.nextDouble() * 0.7
            ))
        }

        ready = true
    }

    // MARK: - Sky

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Deep ethereal gradient — Zeal's signature palette
        let breathe = sin(t * 0.02) * 0.5 + 0.5

        let top = Color(red: 0.03 + breathe * 0.02,
                       green: 0.01 + breathe * 0.01,
                       blue: 0.12 + breathe * 0.05)
        let mid = Color(red: 0.08 + breathe * 0.04,
                       green: 0.04 + breathe * 0.03,
                       blue: 0.22 + breathe * 0.08)
        let low = Color(red: 0.12 + breathe * 0.06,
                       green: 0.06 + breathe * 0.04,
                       blue: 0.28 + breathe * 0.06)

        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(
                Gradient(colors: [top, mid, low]),
                startPoint: CGPoint(x: w / 2, y: 0),
                endPoint: CGPoint(x: w / 2, y: h * 0.65)
            )
        )
    }

    // MARK: - Stars

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        for s in stars {
            let twinkle = sin(t * s.twinkleRate + s.twinklePhase) * 0.3 + 0.7
            let a = s.brightness * twinkle * 0.6
            let sx = snap(s.x * w)
            let sy = snap(s.y * h)
            // Warm white to pale blue stars
            let c = Color(red: 0.8 + s.brightness * 0.2,
                         green: 0.8 + s.brightness * 0.15,
                         blue: 0.9 + s.brightness * 0.1)
            ctx.fill(
                Circle().path(in: CGRect(x: sx - s.size * px / 2,
                                        y: sy - s.size * px / 2,
                                        width: s.size * px,
                                        height: s.size * px)),
                with: .color(c.opacity(a))
            )
            // Soft glow on brighter stars
            if s.brightness > 0.6 {
                let gs = s.size * px * 4
                ctx.fill(
                    Circle().path(in: CGRect(x: sx - gs / 2, y: sy - gs / 2,
                                            width: gs, height: gs)),
                    with: .color(c.opacity(a * 0.08))
                )
            }
        }
    }

    // MARK: - Aurora / Magic Bands

    private func drawAuroraBands(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Shimmering bands of magical energy across the sky — like Zeal's
        // ambient aurora, like the esper gate opening
        for band in 0..<4 {
            let bf = Double(band)
            let baseY = 0.1 + bf * 0.08
            let drift = sin(t * 0.03 + bf * 1.5) * 0.02

            var path = Path()
            path.move(to: CGPoint(x: 0, y: (baseY + drift) * h))

            for step in stride(from: 0.0, through: 1.0, by: 0.02) {
                let wave = sin(step * .pi * 3 + t * 0.08 + bf * 2.0) * 0.015
                let wave2 = sin(step * .pi * 7 + t * 0.12 + bf * 3.5) * 0.005
                let y = (baseY + drift + wave + wave2) * h
                path.addLine(to: CGPoint(x: step * w, y: y))
            }

            // Complete the closed shape
            let bandHeight = (0.025 + sin(t * 0.015 + bf) * 0.008) * h
            for step in stride(from: 1.0, through: 0.0, by: -0.02) {
                let wave = sin(step * .pi * 3 + t * 0.08 + bf * 2.0) * 0.015
                let wave2 = sin(step * .pi * 7 + t * 0.12 + bf * 3.5) * 0.005
                let y = (baseY + drift + wave + wave2) * h + bandHeight
                path.addLine(to: CGPoint(x: step * w, y: y))
            }
            path.closeSubpath()

            // Zeal palette: warm purple, deep blue, golden
            let hues: [(Double, Double, Double)] = [
                (0.35, 0.15, 0.7),   // purple
                (0.15, 0.25, 0.65),  // deep blue
                (0.5, 0.35, 0.85),   // lavender
                (0.7, 0.55, 0.3),    // golden
            ]
            let (r, g, b) = hues[band % hues.count]
            let pulse = sin(t * 0.05 + bf * 1.2) * 0.3 + 0.5
            let alpha = 0.06 + pulse * 0.06

            ctx.fill(path, with: .color(Color(red: r, green: g, blue: b).opacity(alpha)))
        }
    }

    // MARK: - Cloud Sea

    private func drawCloudSea(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // The sea of clouds below — luminous, layered, drifting
        for layer in 0..<5 {
            let lf = Double(layer)
            let baseY = 0.62 + lf * 0.06
            let speed = 0.005 + lf * 0.003
            let offset = t * speed + lf * 100

            var path = Path()
            path.move(to: CGPoint(x: 0, y: h))

            for step in stride(from: 0.0, through: 1.0, by: 0.01) {
                let wave1 = sin((step + offset) * .pi * 2 + lf * 1.3) * 0.02
                let wave2 = sin((step + offset) * .pi * 5 + lf * 2.7) * 0.008
                let wave3 = sin((step + offset) * .pi * 11 + lf * 0.7) * 0.003
                let y = (baseY + wave1 + wave2 + wave3) * h
                path.addLine(to: CGPoint(x: step * w, y: y))
            }
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()

            // Luminous purple-blue clouds with golden highlights
            let warmth = sin(t * 0.01 + lf * 0.5) * 0.5 + 0.5
            let r = 0.15 + warmth * 0.12 + lf * 0.02
            let g = 0.10 + warmth * 0.06 + lf * 0.01
            let b = 0.25 + warmth * 0.05 - lf * 0.01
            let alpha = 0.4 + lf * 0.1

            ctx.fill(path, with: .color(Color(red: r, green: g, blue: b).opacity(alpha)))
        }

        // Golden light blooming up from the cloud sea center
        let bloomY = 0.68 * h
        let bloomR = 80 + sin(t * 0.03) * 15
        let bloomAlpha = 0.04 + sin(t * 0.02) * 0.015
        ctx.fill(
            Circle().path(in: CGRect(x: w * 0.5 - bloomR * 2,
                                    y: bloomY - bloomR,
                                    width: bloomR * 4,
                                    height: bloomR * 2)),
            with: .color(Color(red: 0.8, green: 0.65, blue: 0.3).opacity(bloomAlpha))
        )
    }

    // MARK: - Islands

    private func drawIsland(ctx: inout GraphicsContext, size: CGSize, t: Double, index: Int) {
        let w = size.width, h = size.height
        let island = islands[index]

        let bob = sin(t * 0.3 + island.bobPhase) * island.bobAmp
        let cx = island.cx * w
        let cy = (island.cy + bob) * h
        let iw = island.width * w
        let ih = island.height * h
        let scale = 0.6 + island.depth * 0.5

        // Island body — rocky underside with a flat grassy top
        var bodyPath = Path()
        // Top edge (flat-ish with slight undulation)
        let topY = cy - ih * 0.3
        bodyPath.move(to: CGPoint(x: cx - iw / 2, y: topY))

        var islandRng = SplitMix64(seed: island.grassSeed)
        let steps = 20
        for i in 0...steps {
            let frac = Double(i) / Double(steps)
            let x = cx - iw / 2 + frac * iw
            let bump = sin(frac * .pi * 4 + Double(island.grassSeed & 0xFF)) * ih * 0.12
            bodyPath.addLine(to: CGPoint(x: x, y: topY + bump))
        }

        // Rocky underside (tapers to a point)
        let underDepth = ih * (2.5 + island.depth)
        bodyPath.addLine(to: CGPoint(x: cx + iw * 0.2, y: cy + underDepth * 0.6))
        bodyPath.addLine(to: CGPoint(x: cx + iw * 0.05, y: cy + underDepth))
        bodyPath.addLine(to: CGPoint(x: cx - iw * 0.05, y: cy + underDepth * 0.95))
        bodyPath.addLine(to: CGPoint(x: cx - iw * 0.2, y: cy + underDepth * 0.55))
        bodyPath.closeSubpath()

        // Rock color — dark purple-grey with depth variation
        let rockR = 0.12 + island.depth * 0.03
        let rockG = 0.08 + island.depth * 0.02
        let rockB = 0.18 + island.depth * 0.04
        ctx.fill(bodyPath, with: .color(Color(red: rockR, green: rockG, blue: rockB).opacity(0.9)))

        // Grass/top layer — rich emerald-teal
        var topPath = Path()
        topPath.move(to: CGPoint(x: cx - iw / 2, y: topY + ih * 0.1))
        for i in 0...steps {
            let frac = Double(i) / Double(steps)
            let x = cx - iw / 2 + frac * iw
            let bump = sin(frac * .pi * 4 + Double(island.grassSeed & 0xFF)) * ih * 0.12
            topPath.addLine(to: CGPoint(x: x, y: topY + bump))
        }
        topPath.addLine(to: CGPoint(x: cx + iw / 2, y: topY + ih * 0.2))
        topPath.addLine(to: CGPoint(x: cx - iw / 2, y: topY + ih * 0.2))
        topPath.closeSubpath()

        let grassPulse = sin(t * 0.04 + island.bobPhase) * 0.05
        ctx.fill(topPath, with: .color(Color(red: 0.1 + grassPulse,
                                             green: 0.3 + grassPulse * 2,
                                             blue: 0.2 + grassPulse).opacity(0.85)))

        // Draw waterfalls for this island
        for wf in waterfalls where wf.islandIndex == index {
            drawWaterfall(ctx: &ctx, size: size, t: t, waterfall: wf, island: island, bob: bob)
        }

        // Draw crystal spires on this island
        for spire in spires where spire.islandIndex == index {
            drawSpire(ctx: &ctx, size: size, t: t, spire: spire, island: island, bob: bob)
        }

        // Small ruin silhouette if flagged
        if island.hasRuin && index != 0 {
            let ruinX = cx + (islandRng.nextDouble() - 0.5) * iw * 0.3
            let ruinH = ih * (1.5 + islandRng.nextDouble())
            let ruinW = iw * 0.08

            var ruinPath = Path()
            let ruinBase = topY - 2
            ruinPath.move(to: CGPoint(x: ruinX - ruinW, y: ruinBase))
            ruinPath.addLine(to: CGPoint(x: ruinX - ruinW * 0.8, y: ruinBase - ruinH * 0.7))
            ruinPath.addLine(to: CGPoint(x: ruinX - ruinW * 0.3, y: ruinBase - ruinH))
            ruinPath.addLine(to: CGPoint(x: ruinX + ruinW * 0.3, y: ruinBase - ruinH * 0.9))
            ruinPath.addLine(to: CGPoint(x: ruinX + ruinW * 0.8, y: ruinBase - ruinH * 0.6))
            ruinPath.addLine(to: CGPoint(x: ruinX + ruinW, y: ruinBase))
            ruinPath.closeSubpath()

            ctx.fill(ruinPath, with: .color(Color(red: 0.15, green: 0.1, blue: 0.2).opacity(0.7)))
        }

        // Palace on main island (index 0)
        if index == 0 {
            drawPalace(ctx: &ctx, size: size, t: t, island: island, bob: bob)
        }
    }

    // MARK: - Palace (main island)

    private func drawPalace(ctx: inout GraphicsContext, size: CGSize, t: Double, island: FloatingIsland, bob: Double) {
        let w = size.width, h = size.height
        let cx = island.cx * w
        let baseY = (island.cy + bob) * h - island.height * h * 0.3

        let palaceW = island.width * w * 0.4
        let palaceH = 55.0

        // Main hall — rounded dome shape like Zeal's central palace
        var hallPath = Path()
        hallPath.move(to: CGPoint(x: cx - palaceW / 2, y: baseY))
        // Dome
        hallPath.addQuadCurve(
            to: CGPoint(x: cx + palaceW / 2, y: baseY),
            control: CGPoint(x: cx, y: baseY - palaceH)
        )
        hallPath.closeSubpath()

        // Deep crystalline blue, pulsing gently
        let domePulse = sin(t * 0.06) * 0.1
        ctx.fill(hallPath, with: .color(Color(
            red: 0.12 + domePulse,
            green: 0.10 + domePulse * 0.5,
            blue: 0.35 + domePulse
        ).opacity(0.85)))

        // Golden trim lines
        let trimAlpha = 0.4 + sin(t * 0.04) * 0.15
        ctx.stroke(hallPath, with: .color(Color(red: 0.8, green: 0.65, blue: 0.3).opacity(trimAlpha)),
                   lineWidth: 1.5)

        // Side towers
        for side in [-1.0, 1.0] {
            let towerX = cx + side * palaceW * 0.55
            let towerW = palaceW * 0.15
            let towerH = palaceH * 0.7
            let towerRect = CGRect(x: towerX - towerW / 2, y: baseY - towerH,
                                  width: towerW, height: towerH)
            ctx.fill(Rectangle().path(in: towerRect),
                    with: .color(Color(red: 0.1, green: 0.08, blue: 0.3).opacity(0.8)))

            // Tower cap (small dome)
            var capPath = Path()
            capPath.move(to: CGPoint(x: towerX - towerW / 2, y: baseY - towerH))
            capPath.addQuadCurve(
                to: CGPoint(x: towerX + towerW / 2, y: baseY - towerH),
                control: CGPoint(x: towerX, y: baseY - towerH - towerW * 0.8)
            )
            ctx.fill(capPath, with: .color(Color(red: 0.2, green: 0.15, blue: 0.45).opacity(0.8)))
            ctx.stroke(capPath, with: .color(Color(red: 0.75, green: 0.6, blue: 0.25).opacity(trimAlpha * 0.8)),
                      lineWidth: 1)
        }

        // Palace windows — warm golden light
        let windowGlow = 0.5 + sin(t * 0.035) * 0.2
        for i in 0..<5 {
            let frac = Double(i) / 4.0
            let wx = cx - palaceW * 0.3 + frac * palaceW * 0.6
            let archProgress = 1.0 - abs(frac - 0.5) * 2 // higher near center
            let wy = baseY - 8 - archProgress * palaceH * 0.4
            let ws = 3.0 + archProgress * 2
            ctx.fill(
                Circle().path(in: CGRect(x: wx - ws, y: wy - ws, width: ws * 2, height: ws * 2)),
                with: .color(Color(red: 0.9, green: 0.75, blue: 0.35).opacity(windowGlow * (0.5 + archProgress * 0.5)))
            )
            // Window glow halo
            let haloS = ws * 3
            ctx.fill(
                Circle().path(in: CGRect(x: wx - haloS / 2, y: wy - haloS / 2, width: haloS, height: haloS)),
                with: .color(Color(red: 0.9, green: 0.7, blue: 0.3).opacity(windowGlow * 0.06))
            )
        }

        // Central Mammon Machine glow — the warm heart of the palace
        let mammonPulse = sin(t * 0.07) * 0.5 + 0.5
        let mammonR = 8 + mammonPulse * 4
        let mammonY = baseY - palaceH * 0.35
        ctx.fill(
            Circle().path(in: CGRect(x: cx - mammonR, y: mammonY - mammonR,
                                    width: mammonR * 2, height: mammonR * 2)),
            with: .color(Color(red: 1.0, green: 0.8, blue: 0.3).opacity(0.15 + mammonPulse * 0.15))
        )
        // Inner bright core
        let coreR = mammonR * 0.4
        ctx.fill(
            Circle().path(in: CGRect(x: cx - coreR, y: mammonY - coreR,
                                    width: coreR * 2, height: coreR * 2)),
            with: .color(Color(red: 1.0, green: 0.9, blue: 0.5).opacity(0.4 + mammonPulse * 0.3))
        )
    }

    // MARK: - Crystal Spires

    private func drawSpire(ctx: inout GraphicsContext, size: CGSize, t: Double,
                          spire: CrystalSpire, island: FloatingIsland, bob: Double) {
        let w = size.width, h = size.height
        let cx = island.cx * w
        let baseY = (island.cy + bob) * h - island.height * h * 0.3

        let sx = cx + spire.offsetX * island.width * w
        let spireH = spire.height * (0.6 + island.depth * 0.5)

        // Crystal body — elongated triangle
        var path = Path()
        path.move(to: CGPoint(x: sx - spire.width / 2, y: baseY))
        path.addLine(to: CGPoint(x: sx + spire.width * 0.1, y: baseY - spireH))
        path.addLine(to: CGPoint(x: sx + spire.width / 2, y: baseY))
        path.closeSubpath()

        // Crystal color — varies from blue to purple with inner glow
        let glowCycle = sin(t * 0.08 + spire.glowPhase) * 0.5 + 0.5
        let r = 0.2 + (1 - spire.hue) * 0.3 + glowCycle * 0.1
        let g = 0.15 + glowCycle * 0.1
        let b = 0.5 + spire.hue * 0.3 + glowCycle * 0.15

        ctx.fill(path, with: .color(Color(red: r, green: g, blue: b).opacity(0.6 + glowCycle * 0.2)))

        // Inner glow line
        var innerPath = Path()
        innerPath.move(to: CGPoint(x: sx, y: baseY - 2))
        innerPath.addLine(to: CGPoint(x: sx + spire.width * 0.05, y: baseY - spireH + 3))
        ctx.stroke(innerPath, with: .color(Color(red: 0.7, green: 0.6, blue: 1.0).opacity(0.2 + glowCycle * 0.15)),
                  lineWidth: 1)

        // Tip glow
        let tipR = 2 + glowCycle * 2
        ctx.fill(
            Circle().path(in: CGRect(x: sx + spire.width * 0.1 - tipR,
                                    y: baseY - spireH - tipR,
                                    width: tipR * 2, height: tipR * 2)),
            with: .color(Color(red: 0.8, green: 0.7, blue: 1.0).opacity(0.15 + glowCycle * 0.2))
        )
    }

    // MARK: - Waterfalls

    private func drawWaterfall(ctx: inout GraphicsContext, size: CGSize, t: Double,
                              waterfall: Waterfall, island: FloatingIsland, bob: Double) {
        let w = size.width, h = size.height
        let cx = island.cx * w
        let cy = (island.cy + bob) * h

        let wfX = cx + waterfall.side * island.width * w * 0.4
        let wfTop = cy + island.height * h * 0.3
        let wfLen = 60 + island.depth * 40

        // Cascading water segments
        let segments = 12
        for i in 0..<segments {
            let frac = Double(i) / Double(segments)
            let segY = wfTop + frac * wfLen
            let wobble = sin(t * 2.5 + frac * 8) * 1.5
            let fadeAlpha = (1.0 - frac) * 0.3

            let segW = waterfall.width * (1.0 + frac * 0.5)
            ctx.fill(
                Ellipse().path(in: CGRect(x: wfX + wobble - segW / 2,
                                         y: segY,
                                         width: segW,
                                         height: 3)),
                with: .color(Color(red: 0.6, green: 0.7, blue: 0.95).opacity(fadeAlpha))
            )
        }

        // Mist at the bottom
        let mistR = 10 + sin(t * 0.5) * 3
        let mistY = wfTop + wfLen
        ctx.fill(
            Circle().path(in: CGRect(x: wfX - mistR, y: mistY - mistR / 2,
                                    width: mistR * 2, height: mistR)),
            with: .color(Color(red: 0.5, green: 0.55, blue: 0.8).opacity(0.08))
        )
    }

    // MARK: - Magic Motes

    private func drawMotes(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for mote in motes {
            // Motes drift upward and wrap
            let wrappedY = (mote.y - t * mote.speed).truncatingRemainder(dividingBy: 1.0)
            let my = wrappedY < 0 ? wrappedY + 1.0 : wrappedY
            let mx = mote.x + sin(t * 0.5 + mote.phase) * 0.02

            let pulse = sin(t * 1.2 + mote.phase) * 0.3 + 0.7
            let alpha = mote.brightness * pulse * 0.4

            // Color varies: gold (hue < 0.3), teal (0.3-0.6), blue-purple (> 0.6)
            let r: Double, g: Double, b: Double
            if mote.hue < 0.3 {
                r = 0.9; g = 0.7; b = 0.25  // gold — esper energy
            } else if mote.hue < 0.6 {
                r = 0.3; g = 0.7; b = 0.6   // teal — Zeal magic
            } else {
                r = 0.5; g = 0.35; b = 0.8  // purple — dream energy
            }

            let sx = snap(mx * w)
            let sy = snap(my * h)
            let ms = mote.size * px

            ctx.fill(
                Circle().path(in: CGRect(x: sx - ms / 2, y: sy - ms / 2,
                                        width: ms, height: ms)),
                with: .color(Color(red: r, green: g, blue: b).opacity(alpha))
            )

            // Soft glow halo
            let haloS = ms * 3.5
            ctx.fill(
                Circle().path(in: CGRect(x: sx - haloS / 2, y: sy - haloS / 2,
                                        width: haloS, height: haloS)),
                with: .color(Color(red: r, green: g, blue: b).opacity(alpha * 0.1))
            )
        }
    }

    // MARK: - Energy Pulses (tap response)

    private func drawPulses(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for pulse in pulses {
            let age = t - pulse.birth
            guard age >= 0 && age < 6.0 else { continue }
            let progress = age / 6.0

            // Central flash — golden burst
            let flashFade = age < 0.4 ? age / 0.4 : max(0, 1.0 - (age - 0.4) / 2.0)
            if flashFade > 0 {
                ctx.drawLayer { l in
                    l.addFilter(.blur(radius: 25 + progress * 30))
                    let r = 20 + progress * 60
                    let cx = pulse.cx * w
                    let cy = pulse.cy * h
                    l.fill(Ellipse().path(in: CGRect(x: cx - r, y: cy - r,
                                                     width: r * 2, height: r * 2)),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.4, green: 1.1, blue: 0.5).opacity(0.30 * flashFade),
                                Color(red: 0.9, green: 0.6, blue: 1.2).opacity(0.10 * flashFade),
                                .clear
                            ]),
                            center: CGPoint(x: cx, y: cy),
                            startRadius: 0, endRadius: r))
                }
            }

            // Concentric energy rings — gold to purple
            let radius = progress * min(w, h) * 0.45
            for ring in 0..<4 {
                let rf = Double(ring)
                let delay = rf * 0.25
                let ringAge = age - delay
                guard ringAge > 0 else { continue }
                let rp = min(ringAge / 4.5, 1.0)
                let ringR = rp * min(w, h) * (0.15 + rf * 0.1)
                let ringAlpha = max(0, 1.0 - rp) * (1.0 - rf * 0.2) * 0.3

                let ringRect = CGRect(x: pulse.cx * w - ringR,
                                     y: pulse.cy * h - ringR,
                                     width: ringR * 2,
                                     height: ringR * 2)

                let r = 0.9 - rf * 0.15
                let g = 0.7 - rf * 0.1
                let b = 0.3 + rf * 0.25

                ctx.stroke(Circle().path(in: ringRect),
                    with: .color(Color(red: r, green: g, blue: b).opacity(ringAlpha)),
                    lineWidth: 2 - rf * 0.3)
            }

            // Magical mote particles drifting outward
            let seed = UInt64(pulse.birth * 1000) & 0xFFFFFF
            var rng = SplitMix64(seed: seed)
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 4))
                for _ in 0..<14 {
                    let angle = nextDouble(&rng) * .pi * 2
                    let drift = nextDouble(&rng) * 0.5 + 0.3
                    let riseRate = nextDouble(&rng) * 12 + 6
                    let wobblePhase = nextDouble(&rng) * .pi * 2
                    let sz = nextDouble(&rng) * 2.5 + 1.5
                    let lifespan = nextDouble(&rng) * 2.5 + 3.0
                    guard age < lifespan else { continue }
                    let mp = age / lifespan
                    let moteFade = mp < 0.1 ? mp / 0.1 : max(0, 1.0 - (mp - 0.1) / 0.9)
                    let dist = mp * drift * 100
                    let mx = pulse.cx * w + cos(angle) * dist + sin(age * 0.8 + wobblePhase) * 12
                    let my = pulse.cy * h + sin(angle) * dist * 0.7 - age * riseRate
                    let pulse2 = sin(age * 2.5 + wobblePhase) * 0.3 + 0.7
                    let s = sz * moteFade * pulse2
                    let warmth = nextDouble(&rng)
                    let color = warmth > 0.5
                        ? Color(red: 1.3, green: 1.0, blue: 0.4)
                        : Color(red: 0.7, green: 0.5, blue: 1.2)
                    l.fill(Ellipse().path(in: CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)),
                        with: .color(color.opacity(moteFade * 0.5 * pulse2)))
                }
            }
        }
    }

    // MARK: - Vignette

    private func drawVignette(ctx: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height

        // Soft edge darkening
        let edgeSize = min(w, h) * 0.3
        // Top
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: edgeSize)),
            with: .linearGradient(
                Gradient(colors: [Color.black.opacity(0.2), .clear]),
                startPoint: CGPoint(x: w / 2, y: 0),
                endPoint: CGPoint(x: w / 2, y: edgeSize)
            )
        )
        // Bottom
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: h - edgeSize, width: w, height: edgeSize)),
            with: .linearGradient(
                Gradient(colors: [.clear, Color.black.opacity(0.3)]),
                startPoint: CGPoint(x: w / 2, y: h - edgeSize),
                endPoint: CGPoint(x: w / 2, y: h)
            )
        )
    }

    // MARK: - Helpers

    private func snap(_ v: Double) -> Double {
        (v / px).rounded() * px
    }
}
