import SwiftUI
import Combine

struct GreetingTheDayScene: View {
    @ObservedObject var interaction: InteractionState
    @State private var startDate = Date()

    struct BuildingData: Identifiable {
        let id: Int
        let x, width, targetHeight: Double
        let floors: Int
        let style: BuildingStyle
        let hue, saturation, brightness: Double
        let birthTime: Double
        let windowRows, windowCols: Int
        let hasAntenna: Bool
        let hasRoofGarden: Bool
    }

    enum BuildingStyle: CaseIterable {
        case house, apartment, office, skyscraper, shop, warehouse
    }

    struct CloudData {
        let x, y, width, speed: Double
        let puffs: Int
    }

    struct BirdData {
        let phase, speed, amplitude, yBase: Double
    }

    @State private var buildings: [BuildingData] = []
    @State private var clouds: [CloudData] = []
    @State private var birds: [BirdData] = []
    @State private var buildingIdCounter = 0
    @State private var ready = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                let sunProgress = min(t / 120.0, 1.0) // Sun rises over 2 minutes
                drawSky(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawSun(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawClouds(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawBirds(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawDistantCity(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawBuildings(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawRoad(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
                drawCars(ctx: &ctx, size: size, t: t)
                drawGround(ctx: &ctx, size: size, sunProgress: sunProgress)
                drawCommuterTrain(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
            }
        }
        .background(Color(red: 0.12, green: 0.08, blue: 0.18))
        .onAppear(perform: setup)
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onChange(of: interaction.tapCount) { _, _ in
            guard buildings.count < 80 else { return }
            addBuilding()
        }
        .onReceive(Timer.publish(every: 3.5, on: .main, in: .common).autoconnect()) { _ in
            guard ready, buildings.count < 80 else { return }
            addBuilding()
        }
    }

    private func setup() {
        var rng = SplitMix64(seed: 2026)

        clouds = (0..<8).map { _ in
            CloudData(
                x: nextDouble(&rng) * 1.5 - 0.25,
                y: 0.05 + nextDouble(&rng) * 0.25,
                width: 60 + nextDouble(&rng) * 100,
                speed: 0.002 + nextDouble(&rng) * 0.004,
                puffs: 3 + Int(nextDouble(&rng) * 4)
            )
        }

        birds = (0..<5).map { _ in
            BirdData(
                phase: nextDouble(&rng) * .pi * 2,
                speed: 0.01 + nextDouble(&rng) * 0.008,
                amplitude: 0.02 + nextDouble(&rng) * 0.03,
                yBase: 0.08 + nextDouble(&rng) * 0.2
            )
        }

        // Start with a cluster of buildings
        for _ in 0..<8 {
            addBuildingInternal(rng: &rng)
        }

        ready = true
    }

    private func addBuilding() {
        var rng = SplitMix64(seed: UInt64(buildingIdCounter * 37 + 999))
        addBuildingInternal(rng: &rng)
    }

    private func addBuildingInternal(rng: inout SplitMix64) {
        let style = BuildingStyle.allCases[min(Int(nextDouble(&rng) * Double(BuildingStyle.allCases.count)), BuildingStyle.allCases.count - 1)]
        let (minH, maxH, minW, maxW, minFloors, maxFloors): (Double, Double, Double, Double, Int, Int) = {
            switch style {
            case .house: return (40, 70, 35, 50, 1, 2)
            case .apartment: return (60, 130, 40, 55, 3, 6)
            case .office: return (80, 180, 45, 65, 4, 10)
            case .skyscraper: return (150, 280, 35, 55, 10, 20)
            case .shop: return (30, 55, 40, 60, 1, 1)
            case .warehouse: return (35, 60, 50, 75, 1, 2)
            }
        }()

        let w = minW + nextDouble(&rng) * (maxW - minW)
        let h = minH + nextDouble(&rng) * (maxH - minH)
        let floors = minFloors + Int(nextDouble(&rng) * Double(maxFloors - minFloors + 1))

        // Place building — find a gap or stack next to existing
        let x: Double
        if buildings.isEmpty {
            x = 0.3 + nextDouble(&rng) * 0.4
        } else {
            // Place near existing buildings, growing outward
            let spread = Double(buildings.count) * 0.03
            x = 0.5 + (nextDouble(&rng) - 0.5) * min(0.8, 0.2 + spread)
        }

        let building = BuildingData(
            id: buildingIdCounter,
            x: x,
            width: w,
            targetHeight: h,
            floors: floors,
            style: style,
            hue: nextDouble(&rng) * 0.12 + 0.55, // blues, teals, muted
            saturation: 0.15 + nextDouble(&rng) * 0.25,
            brightness: 0.2 + nextDouble(&rng) * 0.15,
            birthTime: Date().timeIntervalSince(startDate),
            windowRows: floors,
            windowCols: 2 + Int(nextDouble(&rng) * 4),
            hasAntenna: style == .skyscraper && nextDouble(&rng) > 0.4,
            hasRoofGarden: (style == .apartment || style == .office) && nextDouble(&rng) > 0.6
        )

        buildings.append(building)
        buildingIdCounter += 1
    }

    // MARK: - Drawing

    private func drawSky(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        // Transition from pre-dawn purple/navy to warm sunrise to bright morning
        let nightR = 0.06, nightG = 0.04, nightB = 0.14
        let dawnR = 0.85, dawnG = 0.45, dawnB = 0.25
        let dayR = 0.45, dayG = 0.65, dayB = 0.85

        let topR = nightR + (dayR - nightR) * sunProgress
        let topG = nightG + (dayG - nightG) * sunProgress
        let topB = nightB + (dayB - nightB) * sunProgress

        let horizonPhase = min(sunProgress * 2, 1.0) // horizon warms first
        let botR = nightR + (dawnR - nightR) * horizonPhase * (1.0 - sunProgress * 0.3)
        let botG = nightG + (dawnG - nightG) * horizonPhase * (1.0 - sunProgress * 0.2)
        let botB = nightB + (dawnB - nightB) * horizonPhase * 0.5

        let skyRect = CGRect(origin: .zero, size: size)
        ctx.fill(Rectangle().path(in: skyRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: topR, green: topG, blue: topB),
                Color(red: (topR + botR) / 2, green: (topG + botG) / 2, blue: (topB + botB) / 2),
                Color(red: botR, green: botG, blue: botB),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: 0),
            endPoint: CGPoint(x: size.width / 2, y: size.height * 0.7)
        ))

        // Pre-dawn stars that fade out
        if sunProgress < 0.5 {
            let starAlpha = 1.0 - sunProgress * 2
            var rng = SplitMix64(seed: 8888)
            for _ in 0..<60 {
                let sx = nextDouble(&rng) * size.width
                let sy = nextDouble(&rng) * size.height * 0.5
                let sb = nextDouble(&rng) * 0.6 + 0.2
                let ss = 0.5 + nextDouble(&rng) * 1.5
                let twinkle = sin(t * (1.0 + nextDouble(&rng) * 2.0) + nextDouble(&rng) * 6.28) * 0.3 + 0.7
                let rect = CGRect(x: sx - ss / 2, y: sy - ss / 2, width: ss, height: ss)
                ctx.fill(Ellipse().path(in: rect), with: .color(Color.white.opacity(sb * twinkle * starAlpha)))
            }
        }
    }

    private func drawSun(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        let sunX = size.width * 0.6
        // Sun rises from below horizon to upper area
        let startY = size.height * 0.75
        let endY = size.height * 0.15
        let sunY = startY + (endY - startY) * sunProgress
        let sunR: Double = 30 + sunProgress * 10

        // Warm HDR glow
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 60 + sunProgress * 30))
            let glowSize = sunR * 6
            let glowRect = CGRect(x: sunX - glowSize, y: sunY - glowSize, width: glowSize * 2, height: glowSize * 2)
            let warmth = 0.5 + sunProgress * 0.5
            layer.fill(Ellipse().path(in: glowRect), with: .color(
                Color(red: 1.3 * warmth, green: 0.7 * warmth, blue: 0.2 * warmth).opacity(0.3 + sunProgress * 0.2)
            ))
        }

        // Sun disc — HDR bright
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 3))
            let disc = CGRect(x: sunX - sunR, y: sunY - sunR, width: sunR * 2, height: sunR * 2)
            let brightness = 1.0 + sunProgress * 0.8
            layer.fill(Ellipse().path(in: disc), with: .color(
                Color(red: 1.5 * brightness, green: 1.1 * brightness, blue: 0.5)
            ))
        }

        // Horizon glow band
        if sunProgress < 0.6 {
            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 40))
                let bandH: Double = 80
                let bandRect = CGRect(x: 0, y: sunY - bandH / 2, width: size.width, height: bandH)
                layer.fill(Rectangle().path(in: bandRect), with: .color(
                    Color(red: 1.2, green: 0.6, blue: 0.2).opacity(0.15 * (1.0 - sunProgress / 0.6))
                ))
            }
        }
    }

    private func drawClouds(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        for cloud in clouds {
            let cx = ((cloud.x + t * cloud.speed).truncatingRemainder(dividingBy: 1.5))
            let px = (cx < -0.25 ? cx + 1.75 : cx) * size.width
            let py = cloud.y * size.height

            ctx.drawLayer { layer in
                layer.addFilter(.blur(radius: 12))
                for p in 0..<cloud.puffs {
                    let pOffset = Double(p) * (cloud.width / Double(cloud.puffs))
                    let pY = py + sin(Double(p) * 1.5) * 8
                    let pSize = cloud.width * 0.4 + sin(Double(p) * 2.3) * 10
                    let rect = CGRect(x: px + pOffset - pSize / 2, y: pY - pSize * 0.3, width: pSize, height: pSize * 0.6)

                    // Clouds get warmer with sunrise
                    let warmth = sunProgress * 0.4
                    layer.fill(Ellipse().path(in: rect), with: .color(
                        Color(red: 0.9 + warmth * 0.3, green: 0.85 + warmth * 0.1, blue: 0.9 - warmth * 0.2).opacity(0.2 + sunProgress * 0.15)
                    ))
                }
            }
        }
    }

    private func drawBirds(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        guard sunProgress > 0.3 else { return } // birds appear as sun rises
        let birdAlpha = min((sunProgress - 0.3) / 0.2, 1.0)

        for bird in birds {
            let bx = ((bird.phase + t * bird.speed).truncatingRemainder(dividingBy: 1.3)) * size.width
            let by = bird.yBase * size.height + sin(t * 2.0 + bird.phase) * bird.amplitude * size.height
            let wingAngle = sin(t * 6.0 + bird.phase * 3) * 0.4

            var path = Path()
            let wingSpan: Double = 8
            path.move(to: CGPoint(x: bx - wingSpan, y: by + wingAngle * 6))
            path.addQuadCurve(to: CGPoint(x: bx, y: by), control: CGPoint(x: bx - wingSpan * 0.5, y: by - 4 + wingAngle * 4))
            path.addQuadCurve(to: CGPoint(x: bx + wingSpan, y: by + wingAngle * 6), control: CGPoint(x: bx + wingSpan * 0.5, y: by - 4 + wingAngle * 4))

            ctx.stroke(path, with: .color(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.5 * birdAlpha)), lineWidth: 1.5)
        }
    }

    private func drawDistantCity(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        // Faint distant skyline silhouette
        let horizonY = size.height * 0.6
        var rng = SplitMix64(seed: 5555)
        let alpha = 0.08 + sunProgress * 0.06

        for _ in 0..<30 {
            let bx = nextDouble(&rng) * size.width
            let bw = 4 + nextDouble(&rng) * 12
            let bh = 10 + nextDouble(&rng) * 40
            let rect = CGRect(x: bx, y: horizonY - bh, width: bw, height: bh)
            ctx.fill(Rectangle().path(in: rect), with: .color(Color(red: 0.15, green: 0.15, blue: 0.2).opacity(alpha)))
        }
    }

    private func drawBuildings(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        let groundY = size.height * 0.75

        // Sort by x for depth-ish overlap
        let sorted = buildings.sorted { $0.x < $1.x }

        for building in sorted {
            let age = t - building.birthTime
            // Grow-in animation over 1.5 seconds
            let growProgress = min(age / 1.5, 1.0)
            let eased = growProgress < 1.0 ? 1.0 - pow(1.0 - growProgress, 3) : 1.0 // ease-out cubic
            let currentHeight = building.targetHeight * eased

            let bx = building.x * size.width - building.width / 2
            let by = groundY - currentHeight

            // Building body
            let bodyRect = CGRect(x: bx, y: by, width: building.width, height: currentHeight)
            let baseColor = Color(hue: building.hue, saturation: building.saturation, brightness: building.brightness)
            ctx.fill(Rectangle().path(in: bodyRect), with: .color(baseColor))

            // Subtle lighter side face
            let sideRect = CGRect(x: bx + building.width * 0.7, y: by, width: building.width * 0.3, height: currentHeight)
            ctx.fill(Rectangle().path(in: sideRect), with: .color(baseColor.opacity(0.6)))

            guard growProgress > 0.3 else { continue } // windows appear after building partially up

            // Windows
            let windowAlpha = min((growProgress - 0.3) / 0.5, 1.0)
            let winMarginX: Double = 5
            let winMarginY: Double = 5
            let drawableW = building.width - winMarginX * 2
            let drawableH = currentHeight - winMarginY * 2
            let wSpacing = drawableW / Double(building.windowCols)
            let hSpacing = drawableH / Double(max(building.windowRows, 1))

            for row in 0..<min(building.windowRows, Int(currentHeight / 12)) {
                for col in 0..<building.windowCols {
                    let wx = bx + winMarginX + Double(col) * wSpacing + wSpacing * 0.2
                    let wy = by + winMarginY + Double(row) * hSpacing + hSpacing * 0.2
                    let ww = wSpacing * 0.55
                    let wh = hSpacing * 0.5
                    let wRect = CGRect(x: wx, y: wy, width: ww, height: wh)

                    // Some windows lit (warm), some dark (reflecting sky)
                    let seed = building.id * 100 + row * 10 + col
                    var wRng = SplitMix64(seed: UInt64(seed))
                    let isLit = nextDouble(&wRng) > (0.7 - sunProgress * 0.4) // more lights on at dawn

                    if isLit {
                        // Warm interior light — HDR
                        let warmFlicker = sin(t * 0.5 + Double(seed) * 0.3) * 0.05 + 0.95
                        ctx.fill(Rectangle().path(in: wRect), with: .color(
                            Color(red: 1.1 * warmFlicker, green: 0.85 * warmFlicker, blue: 0.4 * warmFlicker).opacity(windowAlpha * 0.8)
                        ))
                    } else {
                        // Dark/sky reflection
                        let skyRef = 0.15 + sunProgress * 0.2
                        ctx.fill(Rectangle().path(in: wRect), with: .color(
                            Color(red: skyRef * 0.7, green: skyRef * 0.8, blue: skyRef * 1.1).opacity(windowAlpha * 0.5)
                        ))
                    }
                }
            }

            // Roof details
            if building.hasAntenna && growProgress > 0.9 {
                let antennaX = bx + building.width / 2
                let antennaH: Double = 15 + building.targetHeight * 0.05
                let antennaRect = CGRect(x: antennaX - 1, y: by - antennaH, width: 2, height: antennaH)
                ctx.fill(Rectangle().path(in: antennaRect), with: .color(Color(red: 0.3, green: 0.3, blue: 0.35).opacity(0.6)))

                // Blinking light on antenna — HDR
                let blink = sin(t * 3.0 + Double(building.id)) > 0.7
                if blink {
                    let dotRect = CGRect(x: antennaX - 2, y: by - antennaH - 2, width: 4, height: 4)
                    ctx.drawLayer { layer in
                        layer.addFilter(.blur(radius: 4))
                        let glowR = CGRect(x: antennaX - 6, y: by - antennaH - 6, width: 12, height: 12)
                        layer.fill(Ellipse().path(in: glowR), with: .color(Color(red: 1.4, green: 0.2, blue: 0.2).opacity(0.5)))
                    }
                    ctx.fill(Ellipse().path(in: dotRect), with: .color(Color(red: 1.3, green: 0.1, blue: 0.1)))
                }
            }

            if building.hasRoofGarden && growProgress > 0.8 {
                // Little green tufts on roof
                for g in 0..<3 {
                    let gx = bx + 8 + Double(g) * (building.width - 16) / 2
                    let gRect = CGRect(x: gx - 4, y: by - 5, width: 8, height: 6)
                    ctx.fill(Ellipse().path(in: gRect), with: .color(Color(red: 0.2, green: 0.45, blue: 0.2).opacity(0.5)))
                }
            }
        }
    }

    private func drawRoad(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        let roadY = size.height * 0.76
        let roadH: Double = 24

        // Road surface
        let roadRect = CGRect(x: 0, y: roadY, width: size.width, height: roadH)
        ctx.fill(Rectangle().path(in: roadRect), with: .color(Color(red: 0.12, green: 0.12, blue: 0.13)))

        // Dashed center line
        let dashW: Double = 20
        let gapW: Double = 15
        let scrollOffset = (t * 30).truncatingRemainder(dividingBy: dashW + gapW)
        var dx = -scrollOffset
        while dx < size.width + dashW {
            let dashRect = CGRect(x: dx, y: roadY + roadH / 2.0 - 1.0, width: dashW, height: 2)
            ctx.fill(Rectangle().path(in: dashRect), with: .color(Color(red: 0.5, green: 0.45, blue: 0.3).opacity(0.4)))
            dx += dashW + gapW
        }

        // Sidewalk
        let sidewalkRect = CGRect(x: 0, y: roadY - 4, width: size.width, height: 4)
        ctx.fill(Rectangle().path(in: sidewalkRect), with: .color(Color(red: 0.18, green: 0.17, blue: 0.16).opacity(0.5)))
    }

    private func drawCars(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let roadY = size.height * 0.76
        // Procedural cars — each car is a pure function of time, no state mutation
        let carInterval: Double = 3.0 // one car every 3 seconds
        let carCount = 12 // total car "slots" cycling

        for i in 0..<carCount {
            var cRng = SplitMix64(seed: UInt64(i * 13 + 42))
            let goingRight = nextDouble(&cRng) > 0.5
            let speed = 40 + nextDouble(&cRng) * 30
            let length = 18 + nextDouble(&cRng) * 14
            let height = 7 + nextDouble(&cRng) * 4
            let cr = 0.1 + nextDouble(&cRng) * 0.3
            let cg = 0.1 + nextDouble(&cRng) * 0.2
            let cb = 0.15 + nextDouble(&cRng) * 0.3
            let lane = goingRight ? 4.0 : 14.0

            // Each car appears at its interval offset and crosses the screen
            let birthTime = Double(i) * carInterval
            let age = t - birthTime
            // Repeat cycle: car reappears every carCount * carInterval seconds
            let cycle = Double(carCount) * carInterval
            let effectiveAge = fmod(age, cycle)
            guard effectiveAge > 0 else { continue }

            let direction: Double = goingRight ? 1.0 : -1.0
            let cx = (goingRight ? -length : size.width + length) + direction * effectiveAge * speed

            guard cx > -length * 2 && cx < size.width + length * 2 else { continue }

            let cy = roadY + lane
            let carRect = CGRect(x: cx, y: cy - height, width: length, height: height)
            ctx.fill(RoundedRectangle(cornerRadius: 2).path(in: carRect), with: .color(Color(red: cr, green: cg, blue: cb)))

            // Windshield
            let wsW = length * 0.25
            let wsX = goingRight ? cx + length * 0.6 : cx + length * 0.15
            let wsRect = CGRect(x: wsX, y: cy - height + 1, width: wsW, height: height * 0.5)
            ctx.fill(Rectangle().path(in: wsRect), with: .color(Color(red: 0.3, green: 0.4, blue: 0.5).opacity(0.5)))

            // Headlights (tiny)
            let hlX = goingRight ? cx + length - 2 : cx
            let hlRect = CGRect(x: hlX, y: cy - height * 0.4, width: 3, height: 2)
            ctx.fill(Rectangle().path(in: hlRect), with: .color(Color(red: 1.2, green: 1.1, blue: 0.8).opacity(0.6)))
        }
    }

    private func drawGround(ctx: inout GraphicsContext, size: CGSize, sunProgress: Double) {
        let groundY = size.height * 0.8
        let groundRect = CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)

        let greenAmount = sunProgress * 0.15
        ctx.fill(Rectangle().path(in: groundRect), with: .linearGradient(
            Gradient(colors: [
                Color(red: 0.08 + greenAmount * 0.3, green: 0.1 + greenAmount, blue: 0.06),
                Color(red: 0.04, green: 0.05 + greenAmount * 0.5, blue: 0.03),
            ]),
            startPoint: CGPoint(x: size.width / 2, y: groundY),
            endPoint: CGPoint(x: size.width / 2, y: size.height)
        ))
    }

    // MARK: - Trains (commuter, elevated, express)

    private func drawCommuterTrain(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        guard buildings.count >= 3 else { return }

        // Draw elevated train first (appears after 15 buildings)
        if buildings.count >= 15 {
            drawElevatedTrain(ctx: &ctx, size: size, t: t, sunProgress: sunProgress)
        }

        let trackY = size.height * 0.92

        // Track rails
        for offset in [0.0, 6.0] {
            var rail = Path()
            rail.move(to: CGPoint(x: 0, y: trackY + offset))
            rail.addLine(to: CGPoint(x: size.width, y: trackY + offset))
            ctx.stroke(rail, with: .color(Color(red: 0.18, green: 0.15, blue: 0.12).opacity(0.5)), lineWidth: 1.5)
        }

        // Sleepers
        let sleeperScroll = (t * 40).truncatingRemainder(dividingBy: 18.0)
        var sx = -sleeperScroll
        while sx < size.width + 18 {
            ctx.fill(Rectangle().path(in: CGRect(x: sx - 5, y: trackY - 1, width: 10, height: 8)),
                     with: .color(Color(red: 0.12, green: 0.1, blue: 0.08).opacity(0.3)))
            sx += 18
        }

        // Multiple trains: frequency increases with city size
        let trainCount = min(1 + buildings.count / 12, 4)
        for trainIdx in 0..<trainCount {
            drawSingleTrain(ctx: &ctx, size: size, t: t, sunProgress: sunProgress,
                           trackY: trackY, trainIndex: trainIdx)
        }
    }

    private func drawSingleTrain(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double, trackY: Double, trainIndex: Int) {
        let carW: Double = 48, carH: Double = 16, carCount = 3 + trainIndex % 3
        let locoW = carW * 0.55
        let totalLen = Double(carCount) * (carW + 3) + locoW
        let cycle = size.width + totalLen + 80
        let speed: Double = 40 + Double(trainIndex) * 12
        let offset: Double = Double(trainIndex) * cycle * 0.35
        let tx = (t * speed + offset).truncatingRemainder(dividingBy: cycle) - totalLen

        let bright = 0.2 + sunProgress * 0.25
        // Slightly different colours per train
        let hueShift = Double(trainIndex) * 0.04
        let trainCol = Color(red: bright + 0.05 + hueShift, green: bright, blue: bright + 0.1 - hueShift)

        // Locomotive
        let locoX = tx + Double(carCount) * (carW + 3)
        ctx.fill(RoundedRectangle(cornerRadius: 3)
                    .path(in: CGRect(x: locoX, y: trackY - carH * 1.1, width: locoW, height: carH * 1.1)),
                 with: .color(trainCol))

        // Headlight — HDR
        let headY: Double = trackY - carH * 0.7 - 3.0
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 7))
            l.fill(Ellipse().path(in: CGRect(x: locoX + locoW - 5.0, y: headY, width: 7.0, height: 7.0)),
                   with: .color(Color(red: 1.4, green: 1.2, blue: 0.8).opacity(0.55)))
        }

        // Passenger cars
        for i in 0..<carCount {
            let cx = tx + Double(i) * (carW + 3)
            ctx.fill(RoundedRectangle(cornerRadius: 2)
                        .path(in: CGRect(x: cx, y: trackY - carH, width: carW, height: carH)),
                     with: .color(trainCol))
            // Windows with warm glow
            let wSpace = (carW - 8) / 5
            for w in 0..<5 {
                let wx = cx + 4 + Double(w) * wSpace
                let warmth = sin(t * 0.4 + Double(w + i * 5 + trainIndex * 17)) * 0.1 + 0.9
                ctx.fill(Rectangle().path(in: CGRect(x: wx, y: trackY - carH * 0.75, width: 4, height: 4)),
                         with: .color(Color(red: 1.15 * warmth, green: 0.88 * warmth, blue: 0.45).opacity(0.7)))
            }
            // Wheels
            for wi in 0..<3 {
                let wheelX = cx + Double(wi + 1) * carW / 4
                ctx.fill(Ellipse().path(in: CGRect(x: wheelX - 2, y: trackY, width: 4, height: 4)),
                         with: .color(Color(red: 0.1, green: 0.08, blue: 0.06)))
            }
        }
    }

    // MARK: - Elevated Train (appears above the skyline)

    private func drawElevatedTrain(ctx: inout GraphicsContext, size: CGSize, t: Double, sunProgress: Double) {
        let elevY = size.height * 0.55

        // Elevated track pillars
        let pillarSpacing: Double = 60
        let pillarScroll = (t * 35).truncatingRemainder(dividingBy: pillarSpacing)
        var px = -pillarScroll
        while px < size.width + pillarSpacing {
            let pillarRect = CGRect(x: px - 2, y: elevY, width: 4, height: size.height * 0.2)
            ctx.fill(Rectangle().path(in: pillarRect),
                     with: .color(Color(red: 0.15, green: 0.14, blue: 0.16).opacity(0.25)))
            px += pillarSpacing
        }

        // Track beam
        ctx.fill(Rectangle().path(in: CGRect(x: 0, y: elevY - 2, width: size.width, height: 3)),
                 with: .color(Color(red: 0.15, green: 0.14, blue: 0.16).opacity(0.3)))

        // Elevated train (sleek, goes opposite direction)
        let eCarW: Double = 36, eCarH: Double = 12, eCarCount = 5
        let eTotalLen = Double(eCarCount) * (eCarW + 2)
        let eCycle = size.width + eTotalLen + 60
        let eSpeed: Double = 55
        // Goes right to left
        let ePos = size.width - (t * eSpeed).truncatingRemainder(dividingBy: eCycle) + eTotalLen

        let eBright = 0.55 + sunProgress * 0.2
        let eTrainCol = Color(red: eBright - 0.1, green: eBright, blue: eBright + 0.05)

        for i in 0..<eCarCount {
            let cx = ePos + Double(i) * (eCarW + 2)
            ctx.fill(RoundedRectangle(cornerRadius: 3)
                        .path(in: CGRect(x: cx, y: elevY - eCarH - 2, width: eCarW, height: eCarH)),
                     with: .color(eTrainCol))
            // Windows — bright warm row
            let wCount = 6
            let wSpace = (eCarW - 6) / Double(wCount)
            for w in 0..<wCount {
                let wx = cx + 3 + Double(w) * wSpace
                let glow = sin(t * 0.3 + Double(w + i * 6)) * 0.08 + 0.92
                ctx.fill(Rectangle().path(in: CGRect(x: wx, y: elevY - eCarH + 2, width: 3, height: 3)),
                         with: .color(Color(red: 1.1 * glow, green: 0.9 * glow, blue: 0.5).opacity(0.6)))
            }
        }
    }
}
