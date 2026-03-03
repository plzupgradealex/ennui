// OldCarScene — You're behind the wheel of a big American land yacht from
// the mid-1950s — an Oldsmobile or Chevy with a bench seat like a church pew.
// It's night, a snowstorm, and you're gliding down a rural highway. The snow
// rushes at the windshield like the Millennium Falcon entering hyperspace.
// Wiper blades sweep back and forth. Chrome radio knobs glow amber. The
// dashboard is lit with little incandescent bulbs — warm orange-yellow.
// Utility poles tick past in the dark. Barns and silos stand against the sky.
//
// Tap to give a little honk of the horn (flash the dash lights, briefly).
//
// Seed: 1956.

import SwiftUI

struct OldCarScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    // Procedurally generated content
    @State private var snowflakes: [SnowflakeData] = []
    @State private var poles: [PoleData] = []
    @State private var barns: [BarnData] = []
    @State private var ready = false

    // Tap flash
    @State private var hornFlash: Double = 0.0

    struct SnowflakeData {
        let lane: Double    // 0…1, horizontal spread
        let depth: Double   // 0 = far/small, 1 = near/big
        let speed: Double   // relative speed multiplier
        let phase: Double   // time offset
        let wobble: Double  // lateral drift amplitude
    }

    struct PoleData {
        let offset: Double  // horizontal cycle offset (0…1)
        let height: Double  // relative pole height
        let wires: Int
    }

    struct BarnData {
        let xFrac: Double   // 0…1 across background
        let widthFrac: Double
        let heightFrac: Double
        let isSilo: Bool
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t = tl.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready, size.width > 50, size.height > 50 else { return }
                let w = size.width
                let h = size.height

                drawStormySky(ctx: &ctx, w: w, h: h, t: t)
                drawRoad(ctx: &ctx, w: w, h: h, t: t)
                drawDistantSilhouettes(ctx: &ctx, w: w, h: h)
                drawUtilityPoles(ctx: &ctx, w: w, h: h, t: t)
                drawSnow(ctx: &ctx, w: w, h: h, t: t)
                drawWindshieldFrame(ctx: &ctx, w: w, h: h)
                drawWipers(ctx: &ctx, w: w, h: h, t: t)
                drawDashboard(ctx: &ctx, w: w, h: h, t: t, flash: hornFlash)
                drawRadio(ctx: &ctx, w: w, h: h, t: t)
                drawSteeringWheel(ctx: &ctx, w: w, h: h, t: t)
                drawBenchSeat(ctx: &ctx, w: w, h: h)
                drawWindshieldGlass(ctx: &ctx, w: w, h: h, t: t)
            }
        }
        .background(Color(red: 0.04, green: 0.03, blue: 0.02))
        .onAppear { setup() }
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            hornFlash = 1.0
            // Fade horn flash back out
            withAnimation(.easeOut(duration: 0.6)) {
                hornFlash = 0.0
            }
        }
    }

    // MARK: - Setup

    private func setup() {
        var rng = SplitMix64(seed: 1956)
        snowflakes = (0..<320).map { _ in
            SnowflakeData(
                lane:   Double.random(in: 0...1,    using: &rng),
                depth:  Double.random(in: 0...1,    using: &rng),
                speed:  Double.random(in: 0.6...1.4, using: &rng),
                phase:  Double.random(in: 0...60,   using: &rng),
                wobble: Double.random(in: 0.2...1.2, using: &rng)
            )
        }
        poles = (0..<8).map { i in
            PoleData(
                offset: Double(i) / 8.0,
                height: Double.random(in: 0.55...0.70, using: &rng),
                wires:  Int.random(in: 2...4, using: &rng)
            )
        }
        barns = (0..<6).map { _ in
            BarnData(
                xFrac:     Double.random(in: 0.05...0.92, using: &rng),
                widthFrac: Double.random(in: 0.06...0.12, using: &rng),
                heightFrac: Double.random(in: 0.07...0.14, using: &rng),
                isSilo:    Double.random(in: 0...1, using: &rng) < 0.35
            )
        }
        ready = true
    }

    // MARK: - Drawing layers

    // Stormy night sky — deep blue-black with faint cloud masses
    private func drawStormySky(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let horizon = h * 0.42
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: 0, width: w, height: horizon)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.04, green: 0.05, blue: 0.08),
                    Color(red: 0.07, green: 0.07, blue: 0.10),
                ]),
                startPoint: .zero,
                endPoint: CGPoint(x: 0, y: horizon)
            )
        )
        // Rolling storm clouds — subtle dark blobs
        var rng = SplitMix64(seed: 42)
        for i in 0..<12 {
            let cx = (Double(i) / 12.0 + t * 0.003) * w * 1.4 - w * 0.2
            let cy = Double.random(in: 0.05...0.30, using: &rng) * horizon
            let rw = Double.random(in: 0.10...0.22, using: &rng) * w
            let rh = Double.random(in: 0.05...0.12, using: &rng) * horizon
            ctx.drawLayer { l in
                l.addFilter(.blur(radius: rh * 0.8))
                l.fill(
                    Ellipse().path(in: CGRect(x: cx - rw / 2, y: cy - rh / 2,
                                              width: rw, height: rh)),
                    with: .color(Color(red: 0.10, green: 0.10, blue: 0.14).opacity(0.55))
                )
            }
        }
    }

    // Road vanishing toward center
    private func drawRoad(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let horizon = h * 0.42
        let roadBottom = h * 0.72   // where road meets dash
        let vanX = w * 0.5
        let roadW: Double = 300.0    // road half-width at base

        // Road surface
        var road = Path()
        road.move(to: CGPoint(x: vanX, y: horizon))
        road.addLine(to: CGPoint(x: w * 0.5 + roadW, y: roadBottom))
        road.addLine(to: CGPoint(x: w * 0.5 - roadW, y: roadBottom))
        road.closeSubpath()
        ctx.fill(road, with: .color(Color(red: 0.12, green: 0.11, blue: 0.10)))

        // Snowy road surface — lighter overlay
        ctx.fill(road, with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.22, green: 0.22, blue: 0.24).opacity(0.0),
                Color(red: 0.30, green: 0.29, blue: 0.32).opacity(0.55),
            ]),
            startPoint: CGPoint(x: vanX, y: horizon),
            endPoint: CGPoint(x: vanX, y: roadBottom)
        ))

        // Centre line dashes scrolling toward viewer
        let dashCycle: Double = 60.0
        let dashFrac = (t * 12.0).truncatingRemainder(dividingBy: dashCycle) / dashCycle
        for i in 0..<8 {
            let frac = (Double(i) / 8.0 + dashFrac).truncatingRemainder(dividingBy: 1.0)
            let yPos = horizon + frac * (roadBottom - horizon)
            let perspScale = frac
            let lw = 2.0 + perspScale * 8.0
            let dashLen = 6.0 + perspScale * 24.0
            let x = vanX
            var dash = Path()
            dash.move(to: CGPoint(x: x, y: yPos))
            dash.addLine(to: CGPoint(x: x, y: yPos + dashLen))
            ctx.stroke(dash, with: .color(Color(red: 0.85, green: 0.82, blue: 0.68).opacity(0.4 + perspScale * 0.3)),
                       lineWidth: lw)
        }
    }

    // Dark silhouettes of barns and silos on the horizon
    private func drawDistantSilhouettes(ctx: inout GraphicsContext, w: Double, h: Double) {
        let horizon = h * 0.42
        for barn in barns {
            let bx = barn.xFrac * w
            let bw = barn.widthFrac * w
            let bh = barn.heightFrac * h * 0.6
            if barn.isSilo {
                // Silo — tall cylinder shape
                let siloW = bw * 0.45
                let siloH = bh * 1.6
                var silo = Path()
                silo.addRoundedRect(
                    in: CGRect(x: bx - siloW / 2, y: horizon - siloH,
                               width: siloW, height: siloH),
                    cornerSize: CGSize(width: siloW / 2, height: siloW / 2)
                )
                ctx.fill(silo, with: .color(Color(red: 0.07, green: 0.06, blue: 0.06).opacity(0.85)))
            } else {
                // Barn — rectangle with a peaked roof
                var barn2 = Path()
                barn2.move(to: CGPoint(x: bx - bw / 2, y: horizon))
                barn2.addLine(to: CGPoint(x: bx - bw / 2, y: horizon - bh))
                barn2.addLine(to: CGPoint(x: bx, y: horizon - bh - bh * 0.4))
                barn2.addLine(to: CGPoint(x: bx + bw / 2, y: horizon - bh))
                barn2.addLine(to: CGPoint(x: bx + bw / 2, y: horizon))
                barn2.closeSubpath()
                ctx.fill(barn2, with: .color(Color(red: 0.07, green: 0.06, blue: 0.06).opacity(0.85)))
            }
        }
    }

    // Utility poles scrolling from right side to left
    private func drawUtilityPoles(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let horizon = h * 0.42
        let poleAreaX = w * 0.65   // poles are on the right shoulder
        let poleAreaWidth = w * 0.28

        for pole in poles {
            // Each pole cycles from right edge to near-right of view
            let cycleDur: Double = 6.0
            let rawFrac = (pole.offset + t / cycleDur).truncatingRemainder(dividingBy: 1.0)
            let frac = rawFrac  // 0 = just entered right, 1 = passed center
            let depth = frac    // perspective: 0=far, 1=near
            let x = poleAreaX + poleAreaWidth * (1.0 - frac)
            let poleHeight = pole.height * h * 0.35 * (0.2 + depth * 0.8)
            let poleBase = horizon + poleHeight * 0.15
            let poleTop = poleBase - poleHeight
            let poleWidth = 1.5 + depth * 3.5
            let alpha = 0.4 + depth * 0.4

            // Pole shaft
            var shaft = Path()
            shaft.move(to: CGPoint(x: x, y: poleBase))
            shaft.addLine(to: CGPoint(x: x, y: poleTop))
            ctx.stroke(shaft, with: .color(Color(red: 0.18, green: 0.15, blue: 0.12).opacity(alpha)),
                       lineWidth: poleWidth)

            // Cross-arm
            let armW = poleWidth * 8.0
            var arm = Path()
            arm.move(to: CGPoint(x: x - armW / 2, y: poleTop + 4))
            arm.addLine(to: CGPoint(x: x + armW / 2, y: poleTop + 4))
            ctx.stroke(arm, with: .color(Color(red: 0.18, green: 0.15, blue: 0.12).opacity(alpha)),
                       lineWidth: poleWidth * 0.6)

            // Wires going toward vanishing point
            for wi in 0..<pole.wires {
                let wireY = poleTop + Double(wi + 1) * 6.0
                var wire = Path()
                wire.move(to: CGPoint(x: x, y: wireY))
                wire.addLine(to: CGPoint(x: w * 0.5, y: horizon + 4))
                ctx.stroke(wire, with: .color(Color(red: 0.15, green: 0.12, blue: 0.10).opacity(alpha * 0.6)),
                           lineWidth: max(0.5, poleWidth * 0.25))
            }
        }
    }

    // Snow rushing toward viewer — Star Wars hyperspace feel
    private func drawSnow(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let horizon = h * 0.42
        let viewBottom = h * 0.72

        for flake in snowflakes {
            // Flakes cycle from far (tiny, near horizon) to near (large, fills glass)
            let cycleDur = 2.2 / flake.speed
            let raw = (t / cycleDur + flake.phase).truncatingRemainder(dividingBy: 1.0)
            let depth = raw   // 0=far, 1=near

            // Streaks: x starts near centre, fans out to sides as they approach
            let xStart = w * 0.5 + (flake.lane - 0.5) * w * 0.12
            let xEnd   = w * 0.5 + (flake.lane - 0.5) * w * 1.25
            let x = xStart + (xEnd - xStart) * depth + sin(t * 2.1 + flake.phase) * flake.wobble * depth * 4

            let yStart = horizon + (flake.lane - 0.5).magnitude * 30
            let yEnd   = viewBottom - 20
            let y = yStart + (yEnd - yStart) * depth

            // Streak length grows with depth
            let streakLen = 2.0 + depth * 16.0
            let brightness = 0.2 + depth * 0.65
            let alpha = brightness * (depth < 0.05 ? depth / 0.05 : 1.0)
                                    * (depth > 0.92 ? (1.0 - depth) / 0.08 : 1.0)

            var streak = Path()
            streak.move(to: CGPoint(x: x, y: y))
            streak.addLine(to: CGPoint(x: x, y: y - streakLen * (0.3 + depth * 0.7)))
            ctx.stroke(streak,
                       with: .color(Color(red: 0.88, green: 0.90, blue: 0.98).opacity(alpha)),
                       lineWidth: 0.6 + depth * 1.4)
        }
    }

    // A-pillars and windshield frame
    private func drawWindshieldFrame(ctx: inout GraphicsContext, w: Double, h: Double) {
        let dashTop = h * 0.72
        let frameColor = Color(red: 0.06, green: 0.05, blue: 0.04)

        // Left A-pillar
        var leftPillar = Path()
        leftPillar.move(to: CGPoint(x: 0, y: 0))
        leftPillar.addLine(to: CGPoint(x: 0, y: h * 0.75))
        leftPillar.addLine(to: CGPoint(x: w * 0.15, y: dashTop))
        leftPillar.addLine(to: CGPoint(x: w * 0.10, y: 0))
        leftPillar.closeSubpath()
        ctx.fill(leftPillar, with: .color(frameColor))

        // Right A-pillar
        var rightPillar = Path()
        rightPillar.move(to: CGPoint(x: w, y: 0))
        rightPillar.addLine(to: CGPoint(x: w, y: h * 0.75))
        rightPillar.addLine(to: CGPoint(x: w * 0.85, y: dashTop))
        rightPillar.addLine(to: CGPoint(x: w * 0.90, y: 0))
        rightPillar.closeSubpath()
        ctx.fill(rightPillar, with: .color(frameColor))

        // Top frame
        var topFrame = Path()
        topFrame.move(to: CGPoint(x: 0, y: 0))
        topFrame.addLine(to: CGPoint(x: w, y: 0))
        topFrame.addLine(to: CGPoint(x: w * 0.90, y: h * 0.10))
        topFrame.addLine(to: CGPoint(x: w * 0.10, y: h * 0.10))
        topFrame.closeSubpath()
        ctx.fill(topFrame, with: .color(frameColor))

        // Hood / cowl at bottom of windshield
        var cowl = Path()
        cowl.move(to: CGPoint(x: w * 0.15, y: dashTop))
        cowl.addLine(to: CGPoint(x: w * 0.85, y: dashTop))
        cowl.addLine(to: CGPoint(x: w * 0.80, y: dashTop - h * 0.04))
        cowl.addLine(to: CGPoint(x: w * 0.20, y: dashTop - h * 0.04))
        cowl.closeSubpath()
        ctx.fill(cowl, with: .color(Color(red: 0.05, green: 0.04, blue: 0.03)))
    }

    // Sweeping wiper blades
    private func drawWipers(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let wiperSpeed: Double = 0.8  // sweeps per second
        // Ping-pong 0…1
        let raw = (t * wiperSpeed).truncatingRemainder(dividingBy: 2.0)
        let frac = raw <= 1.0 ? raw : 2.0 - raw

        let dashTop = h * 0.72
        let pivotY = dashTop - h * 0.03

        // Left wiper — pivots from lower-left of glass
        let leftPivotX = w * 0.25
        let leftSweepMin: Double = -0.25  // radians from vertical
        let leftSweepMax: Double = 0.75
        let leftAngle = leftSweepMin + (leftSweepMax - leftSweepMin) * frac
        drawSingleWiper(ctx: &ctx, pivotX: leftPivotX, pivotY: pivotY,
                        angle: leftAngle, length: w * 0.32, lineWidth: 3.0)

        // Right wiper — pivots from lower-right of glass
        let rightPivotX = w * 0.75
        let rightSweepMin: Double = -.pi + 0.25
        let rightSweepMax: Double = -.pi - 0.75
        let rightAngle = rightSweepMin + (rightSweepMax - rightSweepMin) * frac
        drawSingleWiper(ctx: &ctx, pivotX: rightPivotX, pivotY: pivotY,
                        angle: rightAngle, length: w * 0.32, lineWidth: 3.0)
    }

    private func drawSingleWiper(ctx: inout GraphicsContext,
                                  pivotX: Double, pivotY: Double,
                                  angle: Double, length: Double, lineWidth: Double) {
        let endX = pivotX + sin(angle) * length
        let endY = pivotY - cos(angle) * length
        var wiper = Path()
        wiper.move(to: CGPoint(x: pivotX, y: pivotY))
        wiper.addLine(to: CGPoint(x: endX, y: endY))
        ctx.stroke(wiper,
                   with: .color(Color(red: 0.22, green: 0.20, blue: 0.18).opacity(0.95)),
                   style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

        // Rubber blade — slightly wider end
        var blade = Path()
        blade.move(to: CGPoint(x: pivotX + sin(angle) * length * 0.08,
                                y: pivotY - cos(angle) * length * 0.08))
        blade.addLine(to: CGPoint(x: endX, y: endY))
        ctx.stroke(blade,
                   with: .color(Color(red: 0.12, green: 0.10, blue: 0.10).opacity(0.85)),
                   style: StrokeStyle(lineWidth: lineWidth * 1.4, lineCap: .round))
    }

    // Dashboard — dark bakelite/metal with incandescent gauge glow
    private func drawDashboard(ctx: inout GraphicsContext, w: Double, h: Double, t: Double, flash: Double) {
        let dashTop = h * 0.72
        let dashH = h - dashTop

        // Main dash surface — dark olive-black
        ctx.fill(
            Rectangle().path(in: CGRect(x: 0, y: dashTop, width: w, height: dashH)),
            with: .color(Color(red: 0.07, green: 0.06, blue: 0.05))
        )

        // Padded dash edge — rounded top rail
        var rail = Path()
        rail.addRoundedRect(
            in: CGRect(x: 0, y: dashTop, width: w, height: h * 0.025),
            cornerSize: CGSize(width: 4, height: 4)
        )
        ctx.fill(rail, with: .color(Color(red: 0.11, green: 0.09, blue: 0.07)))

        // Incandescent ambient glow on dash surface (warm orange-yellow)
        let ambientAlpha = 0.28 + flash * 0.45
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 60))
            l.fill(
                Rectangle().path(in: CGRect(x: w * 0.1, y: dashTop, width: w * 0.8, height: dashH * 0.5)),
                with: .color(Color(red: 0.85, green: 0.55, blue: 0.18).opacity(ambientAlpha))
            )
        }

        // Speedometer cluster — left of centre
        let spdCX = w * 0.30
        let spdCY = dashTop + dashH * 0.38
        let spdR  = dashH * 0.32
        drawGauge(ctx: &ctx, cx: spdCX, cy: spdCY, radius: spdR,
                  value: 0.35 + sin(t * 0.07) * 0.02, // ~55 mph, gentle cruise
                  label: "mph", t: t, flash: flash)

        // Fuel / temp gauges — small, right of speedometer
        let smallR = spdR * 0.45
        drawGauge(ctx: &ctx, cx: w * 0.50, cy: spdCY + spdR * 0.15, radius: smallR,
                  value: 0.62, label: "fuel", t: t, flash: flash)
        drawGauge(ctx: &ctx, cx: w * 0.50 + smallR * 2.4, cy: spdCY + spdR * 0.15, radius: smallR,
                  value: 0.45, label: "temp", t: t, flash: flash)

        // Vent slots (decorative horizontal lines)
        for vi in 0..<6 {
            let vy = dashTop + dashH * 0.70 + Double(vi) * dashH * 0.045
            var vent = Path()
            vent.move(to: CGPoint(x: w * 0.10, y: vy))
            vent.addLine(to: CGPoint(x: w * 0.45, y: vy))
            ctx.stroke(vent, with: .color(Color(red: 0.13, green: 0.11, blue: 0.09).opacity(0.9)),
                       lineWidth: 1.5)
        }
    }

    // Draws a single round gauge with incandescent backlit needle
    private func drawGauge(ctx: inout GraphicsContext, cx: Double, cy: Double, radius: Double,
                            value: Double, label: String, t: Double, flash: Double) {
        // Bezel
        ctx.fill(
            Circle().path(in: CGRect(x: cx - radius, y: cy - radius,
                                      width: radius * 2, height: radius * 2)),
            with: .color(Color(red: 0.14, green: 0.12, blue: 0.10))
        )
        // Glass face glow (incandescent backlit)
        let glowAlpha = 0.55 + flash * 0.30
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: radius * 0.5))
            l.fill(
                Circle().path(in: CGRect(x: cx - radius * 0.85, y: cy - radius * 0.85,
                                          width: radius * 1.7, height: radius * 1.7)),
                with: .color(Color(red: 0.88, green: 0.62, blue: 0.22).opacity(glowAlpha * 0.45))
            )
        }
        // Inner face — dark amber tint
        ctx.fill(
            Circle().path(in: CGRect(x: cx - radius * 0.88, y: cy - radius * 0.88,
                                      width: radius * 1.76, height: radius * 1.76)),
            with: .color(Color(red: 0.06, green: 0.05, blue: 0.03))
        )
        // Tick marks
        for tick in 0..<9 {
            let angle = -2.35 + Double(tick) / 8.0 * 4.7
            let innerR = radius * (tick % 2 == 0 ? 0.62 : 0.72)
            let outerR = radius * 0.83
            let tx1 = cx + cos(angle) * innerR
            let ty1 = cy + sin(angle) * innerR
            let tx2 = cx + cos(angle) * outerR
            let ty2 = cy + sin(angle) * outerR
            var tick2 = Path()
            tick2.move(to: CGPoint(x: tx1, y: ty1))
            tick2.addLine(to: CGPoint(x: tx2, y: ty2))
            ctx.stroke(tick2,
                       with: .color(Color(red: 0.75, green: 0.60, blue: 0.35).opacity(0.75)),
                       lineWidth: tick % 2 == 0 ? 1.5 : 0.8)
        }
        // Needle
        let needleAngle = -2.35 + value * 4.7
        let nx = cx + cos(needleAngle) * radius * 0.75
        let ny = cy + sin(needleAngle) * radius * 0.75
        var needle = Path()
        needle.move(to: CGPoint(x: cx, y: cy))
        needle.addLine(to: CGPoint(x: nx, y: ny))
        ctx.stroke(needle, with: .color(Color(red: 0.95, green: 0.85, blue: 0.55).opacity(0.95)),
                   style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        // Centre pin
        ctx.fill(
            Circle().path(in: CGRect(x: cx - 2.5, y: cy - 2.5, width: 5, height: 5)),
            with: .color(Color(red: 0.55, green: 0.40, blue: 0.25))
        )
    }

    // Chrome AM/FM radio with lit-up tuner
    private func drawRadio(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let dashTop = h * 0.72
        let dashH = h - dashTop

        // Radio body — centred in dash, lower half
        let rw = w * 0.32
        let rh = dashH * 0.22
        let rx = (w - rw) / 2.0
        let ry = dashTop + dashH * 0.55

        // Body — brushed metal / dark chrome
        ctx.fill(
            RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: rx, y: ry, width: rw, height: rh)),
            with: .color(Color(red: 0.12, green: 0.10, blue: 0.09))
        )

        // Tuner window — amber glowing strip
        let tunerW = rw * 0.52
        let tunerH = rh * 0.38
        let tunerX = rx + (rw - tunerW) / 2.0
        let tunerY = ry + rh * 0.12
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            l.fill(
                RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: tunerX, y: tunerY,
                                                                    width: tunerW, height: tunerH)),
                with: .color(Color(red: 0.90, green: 0.65, blue: 0.20).opacity(0.85))
            )
        }
        ctx.fill(
            RoundedRectangle(cornerRadius: 2).path(in: CGRect(x: tunerX, y: tunerY,
                                                                width: tunerW, height: tunerH)),
            with: .color(Color(red: 0.78, green: 0.55, blue: 0.16))
        )

        // Tuner tick marks and station needle
        let stationFrac = 0.42 + sin(t * 0.015) * 0.04  // slowly drifting
        let needleX = tunerX + stationFrac * tunerW
        for ti in 0..<12 {
            let tx = tunerX + Double(ti) / 11.0 * tunerW
            let th = ti % 3 == 0 ? tunerH * 0.7 : tunerH * 0.4
            var mark = Path()
            mark.move(to: CGPoint(x: tx, y: tunerY + tunerH - th))
            mark.addLine(to: CGPoint(x: tx, y: tunerY + tunerH))
            ctx.stroke(mark, with: .color(Color(red: 0.35, green: 0.25, blue: 0.10).opacity(0.85)),
                       lineWidth: 0.8)
        }
        // Station needle
        var tneedle = Path()
        tneedle.move(to: CGPoint(x: needleX, y: tunerY))
        tneedle.addLine(to: CGPoint(x: needleX, y: tunerY + tunerH))
        ctx.stroke(tneedle, with: .color(Color(red: 0.95, green: 0.30, blue: 0.20).opacity(0.9)),
                   lineWidth: 1.2)

        // AM / FM labels
        let labelColor = Color(red: 0.40, green: 0.30, blue: 0.12).opacity(0.85)
        ctx.draw(
            Text("AM").font(.system(size: tunerH * 0.55, weight: .bold)).foregroundStyle(labelColor),
            at: CGPoint(x: tunerX - rw * 0.08, y: tunerY + tunerH * 0.5)
        )
        ctx.draw(
            Text("FM").font(.system(size: tunerH * 0.55, weight: .bold)).foregroundStyle(labelColor),
            at: CGPoint(x: tunerX + tunerW + rw * 0.08, y: tunerY + tunerH * 0.5)
        )

        // Chrome knobs — left and right of tuner
        let knobR: Double = rh * 0.28
        let knobY = ry + rh * 0.65
        for (sign, kx) in [(-1.0, rx + rw * 0.14), (1.0, rx + rw * 0.86)] {
            _ = sign
            drawChromeKnob(ctx: &ctx, cx: kx, cy: knobY, radius: knobR, t: t)
        }

        // Chrome border trim
        ctx.stroke(
            RoundedRectangle(cornerRadius: 4).path(in: CGRect(x: rx, y: ry, width: rw, height: rh)),
            with: .color(Color(red: 0.52, green: 0.48, blue: 0.42).opacity(0.7)),
            lineWidth: 1.5
        )
    }

    private func drawChromeKnob(ctx: inout GraphicsContext, cx: Double, cy: Double,
                                  radius: Double, t: Double) {
        // Base
        ctx.fill(
            Circle().path(in: CGRect(x: cx - radius, y: cy - radius,
                                      width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    Color(red: 0.75, green: 0.70, blue: 0.62),
                    Color(red: 0.28, green: 0.25, blue: 0.22),
                ]),
                center: CGPoint(x: cx - radius * 0.25, y: cy - radius * 0.25),
                startRadius: 0,
                endRadius: radius
            )
        )
        // Specular highlight
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: radius * 0.3))
            l.fill(
                Circle().path(in: CGRect(x: cx - radius * 0.55, y: cy - radius * 0.60,
                                          width: radius * 0.65, height: radius * 0.45)),
                with: .color(Color.white.opacity(0.55))
            )
        }
        // Indicator line (shows knob position)
        let lineAngle = t * 0.05
        let lx = cx + sin(lineAngle) * radius * 0.65
        let ly = cy - cos(lineAngle) * radius * 0.65
        var indicator = Path()
        indicator.move(to: CGPoint(x: cx, y: cy))
        indicator.addLine(to: CGPoint(x: lx, y: ly))
        ctx.stroke(indicator, with: .color(Color(red: 0.15, green: 0.12, blue: 0.10).opacity(0.7)),
                   lineWidth: 1.2)
    }

    // Steering wheel — large, thin-rimmed, classic
    private func drawSteeringWheel(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        let cx = w * 0.50
        let cy = h * 0.93
        let outerR = w * 0.17
        let innerR = outerR * 0.12
        let rimW: Double = 5.0

        // Slight sway with road vibration
        let sway = sin(t * 1.7) * 0.012

        ctx.withCGContext { cg in
            cg.translateBy(x: cx, y: cy)
            cg.rotate(by: sway)

            // Outer rim
            cg.setStrokeColor(NSColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 0.95).cgColor)
            cg.setLineWidth(rimW)
            cg.addEllipse(in: CGRect(x: -outerR, y: -outerR,
                                      width: outerR * 2, height: outerR * 2))
            cg.strokePath()

            // Rim highlight
            cg.setStrokeColor(NSColor(red: 0.28, green: 0.22, blue: 0.17, alpha: 0.6).cgColor)
            cg.setLineWidth(2)
            let highlightR = outerR - rimW * 0.3
            cg.addEllipse(in: CGRect(x: -highlightR, y: -highlightR,
                                      width: highlightR * 2, height: highlightR * 2))
            cg.strokePath()

            // Three spokes
            cg.setStrokeColor(NSColor(red: 0.14, green: 0.11, blue: 0.09, alpha: 0.9).cgColor)
            cg.setLineWidth(4)
            for s in 0..<3 {
                let a = Double(s) * (2 * .pi / 3) - .pi / 2
                cg.move(to: CGPoint(x: cos(a) * innerR * 3, y: sin(a) * innerR * 3))
                cg.addLine(to: CGPoint(x: cos(a) * outerR * 0.88, y: sin(a) * outerR * 0.88))
            }
            cg.strokePath()

            // Hub / horn button
            cg.setFillColor(NSColor(red: 0.10, green: 0.08, blue: 0.07, alpha: 1).cgColor)
            cg.fillEllipse(in: CGRect(x: -innerR * 3, y: -innerR * 3,
                                       width: innerR * 6, height: innerR * 6))
            // Horn button chrome ring
            cg.setStrokeColor(NSColor(red: 0.45, green: 0.40, blue: 0.32, alpha: 0.7).cgColor)
            cg.setLineWidth(1.5)
            cg.addEllipse(in: CGRect(x: -innerR * 3, y: -innerR * 3,
                                      width: innerR * 6, height: innerR * 6))
            cg.strokePath()
        }
    }

    // Bench seat — dark upholstered bench visible at very bottom
    private func drawBenchSeat(ctx: inout GraphicsContext, w: Double, h: Double) {
        let seatTop = h * 0.88
        // Seat cushion
        var seat = Path()
        seat.addRoundedRect(
            in: CGRect(x: -w * 0.05, y: seatTop, width: w * 1.10, height: h * 0.16),
            cornerSize: CGSize(width: 12, height: 12)
        )
        ctx.fill(seat, with: .color(Color(red: 0.08, green: 0.06, blue: 0.05)))

        // Seat button tufts
        let tuftRows = 2
        let tuftCols = 7
        for row in 0..<tuftRows {
            for col in 0..<tuftCols {
                let tx = w * 0.08 + Double(col) / Double(tuftCols - 1) * w * 0.84
                let ty = seatTop + h * 0.04 + Double(row) * h * 0.05
                ctx.fill(
                    Circle().path(in: CGRect(x: tx - 2, y: ty - 2, width: 4, height: 4)),
                    with: .color(Color(red: 0.13, green: 0.10, blue: 0.08))
                )
            }
        }

        // Seat seam
        var seam = Path()
        seam.move(to: CGPoint(x: w * 0.1, y: seatTop + h * 0.01))
        seam.addLine(to: CGPoint(x: w * 0.9, y: seatTop + h * 0.01))
        ctx.stroke(seam, with: .color(Color(red: 0.12, green: 0.10, blue: 0.08)),
                   lineWidth: 2)
    }

    // Windshield glass sheen — subtle reflection / condensation at edges
    private func drawWindshieldGlass(ctx: inout GraphicsContext, w: Double, h: Double, t: Double) {
        // Corner condensation
        let cond = 0.08 + sin(t * 0.04) * 0.02
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 30))
            l.fill(
                Rectangle().path(in: CGRect(x: 0, y: 0, width: w * 0.18, height: h * 0.42)),
                with: .color(Color(red: 0.70, green: 0.75, blue: 0.82).opacity(cond))
            )
            l.fill(
                Rectangle().path(in: CGRect(x: w * 0.82, y: 0, width: w * 0.18, height: h * 0.42)),
                with: .color(Color(red: 0.70, green: 0.75, blue: 0.82).opacity(cond))
            )
        }
        // Subtle glare band across the glass
        ctx.fill(
            Rectangle().path(in: CGRect(x: w * 0.10, y: h * 0.06, width: w * 0.80, height: h * 0.04)),
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.80, green: 0.82, blue: 0.90).opacity(0.0),
                    Color(red: 0.80, green: 0.82, blue: 0.90).opacity(0.04),
                    Color(red: 0.80, green: 0.82, blue: 0.90).opacity(0.0),
                ]),
                startPoint: CGPoint(x: w * 0.1, y: 0),
                endPoint: CGPoint(x: w * 0.9, y: 0)
            )
        )
    }
}
