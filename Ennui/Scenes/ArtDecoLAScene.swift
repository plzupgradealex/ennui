import SwiftUI

// Art Deco Los Angeles — Golden hour fading into violet dusk over a
// streamline moderne boulevard. Griffith Observatory on the hills,
// palm trees swaying, warm neon signs, a vintage Pacific Electric
// red car gliding past. Stars appear as the sky deepens. Searchlight
// beams sweep lazily. Tap sends a new searchlight pulse.
// Seed: 1926 (the year of LA's art deco boom).

struct ArtDecoLAScene: View {
    @ObservedObject var interaction: InteractionState

    private let startDate = Date()
    private let px: Double = 2.0 // Fine deco detail

    // Procedural data
    @State private var stars: [StarData] = []
    @State private var palms: [PalmData] = []
    @State private var buildings: [DecoBuilding] = []
    @State private var neonSigns: [NeonSign] = []
    @State private var searchlights: [Searchlight] = []
    @State private var ready = false

    struct StarData {
        let x, y, brightness, size, twinkleRate, twinklePhase: Double
    }

    struct PalmData {
        let x, trunkHeight, lean: Double
        let frondCount: Int
        let frondSeed: UInt64
    }

    struct DecoBuilding {
        let x, width, height: Double
        let style: Int // 0=streamline, 1=stepped, 2=tower
        let hasPorthole: Bool
        let hasSpire: Bool
        let warmth: Double // window warmth tint
        let windowSeed: UInt64
    }

    struct NeonSign {
        let x, y: Double
        let text: String
        let hue: Double // 0-1 mapped to warm neon colors
        let flickerPhase: Double
    }

    struct Searchlight {
        let x: Double
        let birth: Double
        let angle0: Double
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                drawSky(ctx: &ctx, size: size, t: t)
                drawDistantHills(ctx: &ctx, size: size, t: t)
                drawObservatory(ctx: &ctx, size: size, t: t)
                drawStars(ctx: &ctx, size: size, t: t)
                drawSearchlights(ctx: &ctx, size: size, t: t)
                drawPalms(ctx: &ctx, size: size, t: t)
                drawBuildings(ctx: &ctx, size: size, t: t)
                drawNeonSigns(ctx: &ctx, size: size, t: t)
                drawBoulevard(ctx: &ctx, size: size, t: t)
                drawRedCar(ctx: &ctx, size: size, t: t)
                drawScanlines(ctx: &ctx, size: size)
            }
        }
        .background(Color(red: 0.12, green: 0.06, blue: 0.14))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: setup)
        .onChange(of: interaction.tapCount) { _, _ in
            let t = Date().timeIntervalSince(startDate)
            guard let loc = interaction.tapLocation else { return }
            // Searchlight bursts from tap position
            let nx = loc.x / 1200.0 // approximate
            searchlights.append(Searchlight(x: nx, birth: t, angle0: Double.random(in: -0.3...0.3)))
            if searchlights.count > 4 { searchlights.removeFirst() }
        }
    }

    // MARK: - Setup

    private func setup() {
        guard !ready else { return }
        var rng = SplitMix64(seed: 1926)

        // Stars
        for _ in 0..<160 {
            stars.append(StarData(
                x: rng.nextDouble(),
                y: rng.nextDouble() * 0.45,
                brightness: 0.2 + rng.nextDouble() * 0.8,
                size: 0.5 + rng.nextDouble() * 1.5,
                twinkleRate: 0.5 + rng.nextDouble() * 2.0,
                twinklePhase: rng.nextDouble() * .pi * 2
            ))
        }

        // Palm trees along the boulevard
        for i in 0..<7 {
            let spacing = 1.0 / 8.0
            palms.append(PalmData(
                x: 0.08 + Double(i) * spacing + (rng.nextDouble() - 0.5) * 0.02,
                trunkHeight: 80 + rng.nextDouble() * 40,
                lean: (rng.nextDouble() - 0.5) * 0.15,
                frondCount: 6 + Int(rng.nextDouble() * 4),
                frondSeed: UInt64(rng.nextDouble() * Double(UInt32.max))
            ))
        }

        // Deco buildings skyline
        let buildingCount = 12
        for i in 0..<buildingCount {
            let bx = Double(i) / Double(buildingCount) + (rng.nextDouble() - 0.5) * 0.03
            let style = Int(rng.nextDouble() * 3)
            let bw = 40 + rng.nextDouble() * 50
            let bh: Double
            switch style {
            case 0: bh = 80 + rng.nextDouble() * 60  // streamline (shorter, wider)
            case 1: bh = 100 + rng.nextDouble() * 80  // stepped
            default: bh = 130 + rng.nextDouble() * 100 // tower
            }
            buildings.append(DecoBuilding(
                x: bx, width: bw, height: bh,
                style: style,
                hasPorthole: rng.nextDouble() > 0.6,
                hasSpire: style == 2 && rng.nextDouble() > 0.4,
                warmth: 0.7 + rng.nextDouble() * 0.3,
                windowSeed: UInt64(rng.nextDouble() * Double(UInt32.max))
            ))
        }

        // Neon signs
        let signTexts = ["HOTEL", "DINER", "LOUNGE", "CINEMA", "PALMS", "ROXY"]
        for i in 0..<4 {
            neonSigns.append(NeonSign(
                x: 0.15 + Double(i) * 0.2 + (rng.nextDouble() - 0.5) * 0.06,
                y: 0.48 + rng.nextDouble() * 0.08,
                text: signTexts[Int(rng.nextDouble() * Double(signTexts.count))],
                hue: rng.nextDouble(),
                flickerPhase: rng.nextDouble() * .pi * 2
            ))
        }

        ready = true
    }

    // MARK: - Sky

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        // Golden hour gradient that slowly deepens
        let cycle = sin(t * 0.015) * 0.5 + 0.5 // slow day/dusk cycle
        let topR = 0.15 + cycle * 0.1
        let topG = 0.05 + cycle * 0.05
        let topB = 0.25 + cycle * 0.08
        let midR = 0.7 + (1 - cycle) * 0.2
        let midG = 0.35 + (1 - cycle) * 0.15
        let midB = 0.15 + cycle * 0.1
        let botR = 0.95 - cycle * 0.2
        let botG = 0.65 - cycle * 0.15
        let botB = 0.25 + cycle * 0.1

        let top = Color(red: topR, green: topG, blue: topB)
        let mid = Color(red: midR, green: midG, blue: midB)
        let bot = Color(red: botR, green: botG, blue: botB)

        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: h)),
            with: .linearGradient(
                Gradient(colors: [top, mid, bot]),
                startPoint: CGPoint(x: w / 2, y: 0),
                endPoint: CGPoint(x: w / 2, y: h * 0.7)
            )
        )
    }

    // MARK: - Stars

    private func drawStars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        // Stars only visible as sky deepens
        let cycle = sin(t * 0.015) * 0.5 + 0.5
        let starAlpha = max(0, cycle - 0.3) * 1.4 // fade in as night deepens

        guard starAlpha > 0.01 else { return }

        for s in stars {
            let twinkle = sin(t * s.twinkleRate + s.twinklePhase) * 0.3 + 0.7
            let a = s.brightness * twinkle * starAlpha
            let sx = snap(s.x * w)
            let sy = snap(s.y * h)
            let sz = snap(s.size)
            ctx.fill(
                Ellipse().path(in: CGRect(x: sx, y: sy, width: sz, height: sz)),
                with: .color(Color(red: 1, green: 0.95, blue: 0.85).opacity(a))
            )
        }
    }

    // MARK: - Distant hills (Hollywood Hills silhouette)

    private func drawDistantHills(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let hillY = h * 0.42

        var path = Path()
        path.move(to: CGPoint(x: 0, y: hillY))
        let segments = 60
        for i in 0...segments {
            let frac = Double(i) / Double(segments)
            let x = frac * w
            // Layered sine for natural ridge line
            let ridge = sin(frac * .pi * 3.0) * 18
                + sin(frac * .pi * 7.0 + 1.2) * 8
                + sin(frac * .pi * 1.5) * 25
            let y = hillY - abs(ridge) - 10
            path.addLine(to: CGPoint(x: snap(x), y: snap(y)))
        }
        path.addLine(to: CGPoint(x: w, y: h))
        path.addLine(to: CGPoint(x: 0, y: h))
        path.closeSubpath()

        ctx.fill(path, with: .color(Color(red: 0.12, green: 0.08, blue: 0.15).opacity(0.9)))
    }

    // MARK: - Griffith Observatory

    private func drawObservatory(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let cx = w * 0.72
        let baseY = h * 0.38

        // Main dome
        let domeW: Double = 50
        let domeH: Double = 22
        let domeRect = CGRect(x: snap(cx - domeW / 2), y: snap(baseY - domeH), width: snap(domeW), height: snap(domeH))
        ctx.fill(
            Ellipse().path(in: domeRect),
            with: .color(Color(red: 0.85, green: 0.78, blue: 0.65).opacity(0.3))
        )

        // Building body
        let bodyW: Double = 80
        let bodyH: Double = 16
        let bodyRect = CGRect(x: snap(cx - bodyW / 2), y: snap(baseY - 4), width: snap(bodyW), height: snap(bodyH))
        ctx.fill(
            Rectangle().path(in: bodyRect),
            with: .color(Color(red: 0.8, green: 0.72, blue: 0.58).opacity(0.25))
        )

        // Side domes
        for side in [-1.0, 1.0] {
            let sdx = cx + side * 32
            let sdW: Double = 20
            let sdH: Double = 10
            let sdRect = CGRect(x: snap(sdx - sdW / 2), y: snap(baseY - sdH + 2), width: snap(sdW), height: snap(sdH))
            ctx.fill(
                Ellipse().path(in: sdRect),
                with: .color(Color(red: 0.85, green: 0.78, blue: 0.65).opacity(0.25))
            )
        }

        // Warm glow from dome (observatory light)
        let pulse = sin(t * 0.3) * 0.05 + 0.15
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 12))
            layer.fill(
                Ellipse().path(in: CGRect(x: cx - 8, y: baseY - domeH + 2, width: 16, height: 10)),
                with: .color(Color(red: 1, green: 0.9, blue: 0.6).opacity(pulse))
            )
        }
    }

    // MARK: - Searchlights

    private func drawSearchlights(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for sl in searchlights {
            let age = t - sl.birth
            guard age < 8.0 else { continue }
            let fade = age < 1.0 ? age : max(0, 1.0 - (age - 6.0) / 2.0)

            let sweep = sl.angle0 + sin(t * 0.4 + sl.birth) * 0.5
            let baseX = sl.x * w
            let baseY = h * 0.65

            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 6))
                var beamPath = Path()
                let beamLen = h * 0.8
                let spread: Double = 12
                let tipX = baseX + sin(sweep) * beamLen
                let tipY = baseY - cos(sweep) * beamLen
                beamPath.move(to: CGPoint(x: baseX - spread, y: baseY))
                beamPath.addLine(to: CGPoint(x: tipX, y: tipY))
                beamPath.addLine(to: CGPoint(x: baseX + spread, y: baseY))
                beamPath.closeSubpath()
                layer.fill(
                    beamPath,
                    with: .color(Color(red: 1, green: 0.95, blue: 0.8).opacity(0.06 * fade))
                )
            }
        }
    }

    // MARK: - Palm trees

    private func drawPalms(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for palm in palms {
            let baseX = snap(palm.x * w)
            let baseY = snap(h * 0.68)
            let topY = snap(baseY - palm.trunkHeight)
            let sway = sin(t * 0.4 + palm.x * 10) * 3

            // Trunk — slight curve
            let trunkW: Double = 4
            var trunkPath = Path()
            trunkPath.move(to: CGPoint(x: baseX - trunkW / 2, y: baseY))
            trunkPath.addQuadCurve(
                to: CGPoint(x: baseX + sway - trunkW / 2 + palm.lean * 20, y: topY),
                control: CGPoint(x: baseX + palm.lean * 40 + sway * 0.5, y: baseY - palm.trunkHeight * 0.5)
            )
            trunkPath.addLine(to: CGPoint(x: baseX + sway + trunkW / 2 + palm.lean * 20, y: topY))
            trunkPath.addQuadCurve(
                to: CGPoint(x: baseX + trunkW / 2, y: baseY),
                control: CGPoint(x: baseX + palm.lean * 40 + sway * 0.5 + trunkW, y: baseY - palm.trunkHeight * 0.5)
            )
            trunkPath.closeSubpath()

            // Dark silhouette trunk
            ctx.fill(trunkPath, with: .color(Color(red: 0.08, green: 0.05, blue: 0.1).opacity(0.85)))

            // Fronds — silhouette fan
            let crownX = baseX + sway + palm.lean * 20
            let crownY = topY
            var frondRng = SplitMix64(seed: palm.frondSeed)

            for i in 0..<palm.frondCount {
                let angle = Double(i) / Double(palm.frondCount) * .pi * 2 + frondRng.nextDouble() * 0.3
                let frondLen = 30 + frondRng.nextDouble() * 25
                let frondSway = sin(t * 0.6 + Double(i) * 1.1 + palm.x * 5) * 4

                let leafTipX = crownX + cos(angle) * frondLen + frondSway
                let leafTipY = crownY + sin(angle) * frondLen * 0.4 - frondLen * 0.2

                // Simple frond as a tapered path
                var frondPath = Path()
                frondPath.move(to: CGPoint(x: snap(crownX), y: snap(crownY)))
                frondPath.addQuadCurve(
                    to: CGPoint(x: snap(leafTipX), y: snap(leafTipY)),
                    control: CGPoint(x: snap(crownX + cos(angle) * frondLen * 0.6 + frondSway * 0.5),
                                     y: snap(crownY + sin(angle) * frondLen * 0.2 - frondLen * 0.3))
                )
                frondPath.addQuadCurve(
                    to: CGPoint(x: snap(crownX), y: snap(crownY)),
                    control: CGPoint(x: snap(crownX + cos(angle + 0.15) * frondLen * 0.4),
                                     y: snap(crownY - 5))
                )
                ctx.fill(frondPath, with: .color(Color(red: 0.06, green: 0.04, blue: 0.08).opacity(0.9)))
            }
        }
    }

    // MARK: - Art Deco buildings

    private func drawBuildings(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let groundY = h * 0.68

        for bldg in buildings {
            let bx = snap(bldg.x * w)
            let bw = snap(bldg.width)
            let bh = snap(bldg.height)
            let by = snap(groundY - bh)

            // Building body — warm concrete
            let bodyColor = Color(red: 0.22 + bldg.warmth * 0.08,
                                  green: 0.18 + bldg.warmth * 0.06,
                                  blue: 0.15 + bldg.warmth * 0.03)

            switch bldg.style {
            case 0:
                // Streamline Moderne — rounded top corners
                let r: Double = 8
                var p = Path()
                p.move(to: CGPoint(x: bx, y: groundY))
                p.addLine(to: CGPoint(x: bx, y: by + r))
                p.addQuadCurve(to: CGPoint(x: bx + r, y: by), control: CGPoint(x: bx, y: by))
                p.addLine(to: CGPoint(x: bx + bw - r, y: by))
                p.addQuadCurve(to: CGPoint(x: bx + bw, y: by + r), control: CGPoint(x: bx + bw, y: by))
                p.addLine(to: CGPoint(x: bx + bw, y: groundY))
                p.closeSubpath()
                ctx.fill(p, with: .color(bodyColor))

                // Horizontal speed lines (streamline detail)
                for j in stride(from: by + 15, through: groundY - 10, by: 12) {
                    ctx.fill(
                        Rectangle().path(in: CGRect(x: bx + 2, y: snap(j), width: bw - 4, height: 1)),
                        with: .color(Color.white.opacity(0.03))
                    )
                }

            case 1:
                // Stepped / ziggurat top
                let steps = 3
                let stepH: Double = 8
                let stepInset: Double = 6
                var p = Path()
                p.move(to: CGPoint(x: bx, y: groundY))
                p.addLine(to: CGPoint(x: bx, y: by + Double(steps) * stepH))
                for s in (0..<steps).reversed() {
                    let inset = Double(steps - s) * stepInset
                    let sy = by + Double(s) * stepH
                    p.addLine(to: CGPoint(x: bx + inset, y: sy + stepH))
                    p.addLine(to: CGPoint(x: bx + inset, y: sy))
                }
                let topInset = Double(steps) * stepInset
                p.addLine(to: CGPoint(x: bx + bw - topInset, y: by))
                for s in 0..<steps {
                    let inset = Double(steps - s) * stepInset
                    let sy = by + Double(s) * stepH
                    p.addLine(to: CGPoint(x: bx + bw - inset, y: sy))
                    p.addLine(to: CGPoint(x: bx + bw - inset, y: sy + stepH))
                }
                p.addLine(to: CGPoint(x: bx + bw, y: by + Double(steps) * stepH))
                p.addLine(to: CGPoint(x: bx + bw, y: groundY))
                p.closeSubpath()
                ctx.fill(p, with: .color(bodyColor))

            default:
                // Tower with optional spire
                ctx.fill(
                    Rectangle().path(in: CGRect(x: bx, y: by, width: bw, height: bh)),
                    with: .color(bodyColor)
                )
                if bldg.hasSpire {
                    let spireH: Double = 25
                    var sp = Path()
                    sp.move(to: CGPoint(x: bx + bw / 2 - 3, y: by))
                    sp.addLine(to: CGPoint(x: bx + bw / 2, y: by - spireH))
                    sp.addLine(to: CGPoint(x: bx + bw / 2 + 3, y: by))
                    sp.closeSubpath()
                    ctx.fill(sp, with: .color(bodyColor))
                    // Spire light
                    let blink = sin(t * 2.0 + bldg.x * 10) * 0.5 + 0.5
                    ctx.fill(
                        Ellipse().path(in: CGRect(x: bx + bw / 2 - 1.5, y: by - spireH - 1, width: 3, height: 3)),
                        with: .color(Color(red: 1, green: 0.3, blue: 0.2).opacity(0.3 + blink * 0.4))
                    )
                }
            }

            // Porthole windows (streamline moderne detail)
            if bldg.hasPorthole {
                let phY = by + 12
                for px_i in stride(from: bx + 8, through: bx + bw - 8, by: 14) {
                    let pw: Double = 6
                    ctx.fill(
                        Ellipse().path(in: CGRect(x: snap(px_i), y: snap(phY), width: pw, height: pw)),
                        with: .color(Color(red: 0.9, green: 0.8, blue: 0.5).opacity(0.15))
                    )
                }
            }

            // Regular windows — warm amber glow
            var wRng = SplitMix64(seed: bldg.windowSeed)
            let winW: Double = 4
            let winH: Double = 6
            let startY = by + (bldg.hasPorthole ? 24 : 10)
            for wy in stride(from: startY, through: groundY - 12, by: 14) {
                for wx in stride(from: bx + 6, through: bx + bw - 10, by: 10) {
                    let lit = wRng.nextDouble() > 0.4
                    if lit {
                        let flicker = sin(t * 0.5 + wRng.nextDouble() * 10) * 0.05
                        let warmth = 0.15 + flicker + wRng.nextDouble() * 0.1
                        ctx.fill(
                            Rectangle().path(in: CGRect(x: snap(wx), y: snap(wy), width: winW, height: winH)),
                            with: .color(Color(red: 0.95, green: 0.8, blue: 0.4).opacity(warmth))
                        )
                    }
                }
            }

            // Art deco chevron ornament at top of building
            let chevY = by + 3
            let chevW: Double = min(bw * 0.3, 16)
            var chevPath = Path()
            let chevCx = bx + bw / 2
            chevPath.move(to: CGPoint(x: chevCx - chevW / 2, y: chevY + 6))
            chevPath.addLine(to: CGPoint(x: chevCx, y: chevY))
            chevPath.addLine(to: CGPoint(x: chevCx + chevW / 2, y: chevY + 6))
            ctx.stroke(chevPath, with: .color(Color(red: 0.85, green: 0.7, blue: 0.4).opacity(0.2)), lineWidth: 1)
        }
    }

    // MARK: - Neon signs

    private func drawNeonSigns(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height

        for sign in neonSigns {
            let sx = snap(sign.x * w)
            let sy = snap(sign.y * h)

            // Flicker
            let flicker = sin(t * 4.0 + sign.flickerPhase) * sin(t * 7.3 + sign.flickerPhase * 2.1)
            let on = flicker > -0.8  // mostly on, occasional flicker off

            guard on else { continue }

            // Neon color based on hue — warm range only (red, pink, gold, warm white)
            let r: Double, g: Double, b: Double
            if sign.hue < 0.25 {
                r = 1.0; g = 0.3; b = 0.2 // warm red
            } else if sign.hue < 0.5 {
                r = 1.0; g = 0.6; b = 0.3 // warm orange
            } else if sign.hue < 0.75 {
                r = 0.95; g = 0.85; b = 0.6 // warm gold
            } else {
                r = 1.0; g = 0.4; b = 0.5 // warm pink
            }

            let neonColor = Color(red: r, green: g, blue: b)
            let intensity = 0.4 + sin(t * 0.8 + sign.flickerPhase) * 0.1

            // Glow halo
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 8))
                let glowRect = CGRect(x: sx - 5, y: sy - 3, width: Double(sign.text.count) * 8 + 10, height: 16)
                layer.fill(
                    Rectangle().path(in: glowRect),
                    with: .color(neonColor.opacity(intensity * 0.3))
                )
            }

            // Letter by letter (simple pixel text)
            for (i, _) in sign.text.enumerated() {
                let lx = sx + Double(i) * 8
                // Each "letter" is a small bright rectangle with character shape approximated
                ctx.fill(
                    Rectangle().path(in: CGRect(x: snap(lx), y: snap(sy), width: 6, height: 8)),
                    with: .color(neonColor.opacity(intensity))
                )
                // Bright core
                ctx.fill(
                    Rectangle().path(in: CGRect(x: snap(lx + 1), y: snap(sy + 1), width: 4, height: 6)),
                    with: .color(Color.white.opacity(intensity * 0.4))
                )
            }
        }
    }

    // MARK: - Boulevard (road)

    private func drawBoulevard(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let roadY = snap(h * 0.68)

        // Sidewalk
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: roadY, width: w, height: snap(h * 0.04))),
            with: .color(Color(red: 0.25, green: 0.22, blue: 0.2))
        )

        // Road surface
        let roadTop = roadY + h * 0.04
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: roadTop, width: w, height: h - roadTop)),
            with: .color(Color(red: 0.1, green: 0.08, blue: 0.1))
        )

        // Center line — dashed
        let lineY = snap(roadTop + (h - roadTop) * 0.4)
        for dx in stride(from: 0.0, through: w, by: 24) {
            ctx.fill(
                Rectangle().path(in: CGRect(x: snap(dx), y: lineY, width: 12, height: 2)),
                with: .color(Color(red: 0.9, green: 0.8, blue: 0.3).opacity(0.25))
            )
        }

        // Warm street lamp pools on sidewalk
        for i in 0..<6 {
            let lx = Double(i) * w / 5.0 + 30
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 20))
                layer.fill(
                    Ellipse().path(in: CGRect(x: lx - 25, y: roadY - 5, width: 50, height: 15)),
                    with: .color(Color(red: 1, green: 0.85, blue: 0.5).opacity(0.08))
                )
            }
        }
    }

    // MARK: - Pacific Electric Red Car

    private func drawRedCar(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let w = size.width, h = size.height
        let roadTop = h * 0.68 + h * 0.04
        let carY = snap(roadTop + 8)

        // Car moves slowly across — loops
        let period: Double = 45 // seconds for one crossing
        let carProgress = fmod(t / period, 1.0)
        let carX = snap(-80 + carProgress * (w + 160))

        let carW: Double = 70
        let carH: Double = 22

        // Car body — warm red
        ctx.fill(
            RoundedRectangle(cornerRadius: 3).path(in: CGRect(x: carX, y: carY, width: carW, height: carH)),
            with: .color(Color(red: 0.75, green: 0.15, blue: 0.12))
        )

        // Roof
        ctx.fill(
            RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: carX + 8, y: carY - 8, width: carW - 16, height: 10)),
            with: .color(Color(red: 0.65, green: 0.12, blue: 0.1))
        )

        // Windows — warm interior glow
        for wx in stride(from: carX + 12, through: carX + carW - 14, by: 10) {
            ctx.fill(
                Rectangle().path(in: CGRect(x: snap(wx), y: snap(carY - 5), width: 7, height: 7)),
                with: .color(Color(red: 0.95, green: 0.85, blue: 0.5).opacity(0.5))
            )
        }

        // Headlight
        let headDir = 1.0 // moving right
        let hlX = headDir > 0 ? carX + carW : carX
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 6))
            layer.fill(
                Ellipse().path(in: CGRect(x: hlX - 3, y: carY + 6, width: 8, height: 6)),
                with: .color(Color(red: 1, green: 0.95, blue: 0.7).opacity(0.4))
            )
        }

        // Trolley pole (pantograph)
        var polePath = Path()
        polePath.move(to: CGPoint(x: carX + carW * 0.6, y: carY - 8))
        polePath.addLine(to: CGPoint(x: carX + carW * 0.55, y: carY - 28))
        ctx.stroke(polePath, with: .color(Color(red: 0.4, green: 0.35, blue: 0.3).opacity(0.6)), lineWidth: 1.5)
    }

    // MARK: - Scanlines (subtle CRT / film grain feel)

    private func drawScanlines(ctx: inout GraphicsContext, size: CGSize) {
        let h = size.height
        let w = size.width
        for y in stride(from: 0.0, through: h, by: px * 2) {
            ctx.fill(
                Rectangle().path(in: CGRect(x: 0, y: y, width: w, height: 1)),
                with: .color(Color.black.opacity(0.03))
            )
        }
    }

    // MARK: - Helpers

    private func snap(_ v: Double) -> Double {
        (v / px).rounded(.down) * px
    }
}
