import SwiftUI

// Windows 95 "Mystify Your Mind" — bouncing line segments leaving
// phosphor-glow trails on a CRT-dark screen.  Pure ambient nostalgia.

struct MystifyScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // MARK: - State

    @State private var ribbons: [RibbonData] = []
    @State private var stars: [StarData] = []
    @State private var tapBursts: [TapBurst] = []
    @State private var ready = false

    // MARK: - Data types

    struct RibbonData {
        // Sinusoidal motion parameters for endpoints A and B
        let fax: Double; let fay: Double; let pax: Double; let pay: Double
        let fbx: Double; let fby: Double; let pbx: Double; let pby: Double
        let r: Double; let g: Double; let b: Double
    }

    struct StarData {
        let x: Double; let y: Double
        let brightness: Double; let rate: Double
    }

    struct TapBurst {
        let birth: Double
        let fax: Double; let fay: Double; let fbx: Double; let fby: Double
        let pax: Double; let pay: Double; let pbx: Double; let pby: Double
        let r: Double; let g: Double; let b: Double
    }

    // Trail config
    private let trailCount = 28
    private let trailStep: Double = 0.045

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let now = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }

                // ── Background: deep CRT blue-black ──
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(Color(red: 0.012, green: 0.012, blue: 0.04))
                )

                // ── Stars ──
                for star in stars {
                    let twinkle = 0.5 + 0.5 * sin(now * star.rate)
                    let alpha = star.brightness * (0.3 + 0.7 * twinkle)
                    let sz = 1.0 + star.brightness
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: star.x * size.width - sz * 0.5,
                            y: star.y * size.height - sz * 0.5,
                            width: sz, height: sz)),
                        with: .color(Color(red: 0.65, green: 0.7, blue: 0.85).opacity(alpha))
                    )
                }

                // ── Mystify ribbons ──
                for ribbon in ribbons {
                    drawRibbon(ctx: ctx, size: size, r: ribbon, t: now, fade: 1)
                }

                // ── Tap bursts (short-lived extra ribbons) ──
                for burst in tapBursts {
                    let age = now - burst.birth
                    guard age < 5 else { continue }
                    let f = max(0, 1 - age / 5)
                    let rd = RibbonData(
                        fax: burst.fax, fay: burst.fay, pax: burst.pax, pay: burst.pay,
                        fbx: burst.fbx, fby: burst.fby, pbx: burst.pbx, pby: burst.pby,
                        r: burst.r, g: burst.g, b: burst.b)
                    drawRibbon(ctx: ctx, size: size, r: rd, t: now, fade: f)
                }

                // ── CRT vignette ──
                let dim = min(size.width, size.height)
                ctx.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            .clear,
                            .clear,
                            Color.black.opacity(0.45),
                        ]),
                        center: CGPoint(x: size.width * 0.5, y: size.height * 0.5),
                        startRadius: dim * 0.32,
                        endRadius: dim * 0.78
                    )
                )

                // ── Faint CRT scanlines ──
                var scanY = 0.0
                while scanY < size.height {
                    ctx.fill(
                        Path(CGRect(x: 0, y: scanY, width: size.width, height: 1)),
                        with: .color(Color.black.opacity(0.04))
                    )
                    scanY += 3
                }
            }
            .drawingGroup(opaque: false, colorMode: .extendedLinear)
            .allowedDynamicRange(.high)
        }
        .onAppear { generate() }
        .onChange(of: interaction.tapCount) { _, _ in handleTap() }
    }

    // MARK: - Draw a single ribbon with trail

    private func drawRibbon(ctx: GraphicsContext, size: CGSize,
                            r: RibbonData, t: Double, fade: Double) {
        let color = Color(red: r.r, green: r.g, blue: r.b)

        for i in 0..<trailCount {
            let st = t - Double(i) * trailStep
            let progress = Double(i) / Double(trailCount)
            let alpha = (1.0 - progress) * fade

            let ax = size.width  * (0.5 + 0.45 * sin(r.fax * st + r.pax))
            let ay = size.height * (0.5 + 0.45 * sin(r.fay * st + r.pay))
            let bx = size.width  * (0.5 + 0.45 * sin(r.fbx * st + r.pbx))
            let by = size.height * (0.5 + 0.45 * sin(r.fby * st + r.pby))

            var path = Path()
            path.move(to: CGPoint(x: ax, y: ay))
            path.addLine(to: CGPoint(x: bx, y: by))

            // Glow layer (wide, soft)
            ctx.stroke(path,
                       with: .color(color.opacity(alpha * 0.25)),
                       style: StrokeStyle(lineWidth: 5, lineCap: .round))

            // Core layer (thin, bright)
            ctx.stroke(path,
                       with: .color(color.opacity(alpha * 0.85)),
                       style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        }
    }

    // MARK: - Generate (runs once)

    private func generate() {
        var rng = SplitMix64(seed: 1995)

        // CRT phosphor palette — vivid but warm
        let colors: [(Double, Double, Double)] = [
            (0.20, 0.85, 0.90),   // cyan
            (0.95, 0.35, 0.50),   // warm pink
            (1.00, 0.82, 0.22),   // amber
            (0.35, 0.88, 0.45),   // green
            (0.65, 0.40, 0.95),   // lavender
        ]

        ribbons = colors.map { c in
            RibbonData(
                fax: 0.25 + Double.random(in: 0...0.45, using: &rng),
                fay: 0.20 + Double.random(in: 0...0.50, using: &rng),
                pax: Double.random(in: 0 ... .pi * 2, using: &rng),
                pay: Double.random(in: 0 ... .pi * 2, using: &rng),
                fbx: 0.25 + Double.random(in: 0...0.45, using: &rng),
                fby: 0.20 + Double.random(in: 0...0.50, using: &rng),
                pbx: Double.random(in: 0 ... .pi * 2, using: &rng),
                pby: Double.random(in: 0 ... .pi * 2, using: &rng),
                r: c.0, g: c.1, b: c.2
            )
        }

        stars = (0..<70).map { _ in
            StarData(
                x: Double.random(in: 0...1, using: &rng),
                y: Double.random(in: 0...1, using: &rng),
                brightness: Double.random(in: 0.08...0.40, using: &rng),
                rate: Double.random(in: 0.4...2.0, using: &rng)
            )
        }

        ready = true
    }

    // MARK: - Tap interaction: spawn a brief extra ribbon

    private func handleTap() {
        var rng = SplitMix64(seed: UInt64(interaction.tapCount) &+ 9595)
        let colors: [(Double, Double, Double)] = [
            (0.20, 0.85, 0.90), (0.95, 0.35, 0.50), (1.00, 0.82, 0.22),
            (0.35, 0.88, 0.45), (0.65, 0.40, 0.95),
        ]
        let c = colors[Int.random(in: 0..<colors.count, using: &rng)]
        let now = Date().timeIntervalSince(startDate)

        tapBursts.append(TapBurst(
            birth: now,
            fax: 0.4 + Double.random(in: 0...0.6, using: &rng),
            fay: 0.35 + Double.random(in: 0...0.55, using: &rng),
            fbx: 0.4 + Double.random(in: 0...0.6, using: &rng),
            fby: 0.35 + Double.random(in: 0...0.55, using: &rng),
            pax: Double.random(in: 0 ... .pi * 2, using: &rng),
            pay: Double.random(in: 0 ... .pi * 2, using: &rng),
            pbx: Double.random(in: 0 ... .pi * 2, using: &rng),
            pby: Double.random(in: 0 ... .pi * 2, using: &rng),
            r: c.0, g: c.1, b: c.2
        ))
        tapBursts = tapBursts.filter { now - $0.birth < 6.0 }
    }
}
