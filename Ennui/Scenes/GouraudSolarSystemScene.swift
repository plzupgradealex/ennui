import SwiftUI

struct GouraudSolarSystemScene: View {
    @ObservedObject var interaction: InteractionState
    private let startDate = Date()

    struct PlanetData: Identifiable {
        let id: Int
        let orbitRadius: Double      // fraction of view width
        let orbitSpeed: Double        // radians per second
        let orbitPhase: Double        // starting angle
        let size: Double              // radius in points
        let baseHue: Double
        let saturation: Double
        let brightness: Double
        let tilt: Double              // orbit ellipse squash (0.3–0.7)
        let hasRing: Bool
        let ringHue: Double
    }

    struct MoonData: Identifiable {
        let id: Int
        let parentId: Int
        let orbitRadius: Double
        let orbitSpeed: Double
        let orbitPhase: Double
        let size: Double
        let hue: Double
    }

    struct ShimmerEvent {
        let planetId: Int
        let birth: Double
    }

    @State private var planets: [PlanetData] = []
    @State private var moons: [MoonData] = []
    @State private var shimmers: [ShimmerEvent] = []
    @State private var moonIdCounter = 100
    @State private var ready = false

    // Light direction rotates very slowly
    private func lightAngle(_ t: Double) -> Double {
        t * 0.06
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSince(startDate)
            Canvas { ctx, size in
                guard ready else { return }
                let center = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
                drawSpace(ctx: &ctx, size: size, t: t)
                drawOrbitalGrid(ctx: &ctx, size: size, center: center, t: t)
                drawStar(ctx: &ctx, size: size, center: center, t: t)

                // Draw back-half orbits (planets behind the star), then star glow, then front-half
                let sorted = planets.sorted { planetAngle($0, t: t, tilt: $0.tilt) > planetAngle($1, t: t, tilt: $1.tilt) }
                for planet in sorted {
                    drawPlanet(ctx: &ctx, size: size, center: center, planet: planet, t: t)
                    for moon in moons.filter({ $0.parentId == planet.id }) {
                        drawMoon(ctx: &ctx, size: size, center: center, planet: planet, moon: moon, t: t)
                    }
                }
                drawShimmers(ctx: &ctx, size: size, center: center, t: t)
                drawScanlines(ctx: &ctx, size: size, t: t)
            }
        }
        .background(Color(red: 0.01, green: 0.005, blue: 0.03))
        .drawingGroup(opaque: false, colorMode: .extendedLinear)
        .allowedDynamicRange(.high)
        .onAppear(perform: generate)
        .onChange(of: interaction.tapCount) { _, _ in handleTap() }
    }

    private func planetAngle(_ p: PlanetData, t: Double, tilt: Double) -> Double {
        sin(t * p.orbitSpeed + p.orbitPhase) * tilt
    }

    private func planetPosition(_ p: PlanetData, center: CGPoint, size: CGSize, t: Double) -> CGPoint {
        let angle = t * p.orbitSpeed + p.orbitPhase
        let rx = p.orbitRadius * size.width * 0.42
        let ry = rx * p.tilt
        return CGPoint(
            x: center.x + cos(angle) * rx,
            y: center.y + sin(angle) * ry
        )
    }

    private func generate() {
        var rng = SplitMix64(seed: 2001)

        let planetDefs: [(orbit: Double, speed: Double, sz: Double, hue: Double, sat: Double, bri: Double, ring: Bool)] = [
            (0.12, 0.45,  8,  0.08, 0.50, 0.70, false),  // hot inner rocky
            (0.20, 0.30, 12,  0.12, 0.55, 0.65, false),  // warm amber
            (0.30, 0.20, 16,  0.55, 0.50, 0.55, false),  // blue-green
            (0.42, 0.12, 22,  0.08, 0.65, 0.60, true),   // ringed gas giant
            (0.54, 0.08, 14,  0.75, 0.40, 0.50, false),  // purple ice
            (0.66, 0.05, 18,  0.58, 0.45, 0.45, true),   // teal ringed
            (0.80, 0.03, 10,  0.90, 0.30, 0.40, false),  // distant pink
        ]

        planets = planetDefs.enumerated().map { (i, def) in
            PlanetData(
                id: i,
                orbitRadius: def.orbit,
                orbitSpeed: def.speed,
                orbitPhase: nextDouble(&rng) * .pi * 2,
                size: def.sz,
                baseHue: def.hue,
                saturation: def.sat,
                brightness: def.bri,
                tilt: 0.35 + nextDouble(&rng) * 0.25,
                hasRing: def.ring,
                ringHue: def.hue + 0.05
            )
        }

        // A few starter moons
        for planet in planets where planet.size > 14 {
            let m = MoonData(
                id: moonIdCounter,
                parentId: planet.id,
                orbitRadius: planet.size * 1.8 + nextDouble(&rng) * 10,
                orbitSpeed: 1.5 + nextDouble(&rng) * 2.0,
                orbitPhase: nextDouble(&rng) * .pi * 2,
                size: 2 + nextDouble(&rng) * 3,
                hue: planet.baseHue + (nextDouble(&rng) - 0.5) * 0.15
            )
            moons.append(m)
            moonIdCounter += 1
        }

        ready = true
    }

    private func handleTap() {
        var rng = SplitMix64(seed: UInt64(interaction.tapCount * 53 + 7))
        let action = nextDouble(&rng)

        if action < 0.5, !planets.isEmpty {
            // Shimmer a random planet
            let idx = Int(nextDouble(&rng) * Double(planets.count)) % planets.count
            let shimmer = ShimmerEvent(
                planetId: planets[idx].id,
                birth: Date().timeIntervalSince(startDate)
            )
            shimmers.append(shimmer)
            if shimmers.count > 8 { shimmers.removeFirst() }
        } else if !planets.isEmpty {
            // Add a moon to a random planet
            let idx = Int(nextDouble(&rng) * Double(planets.count)) % planets.count
            let parent = planets[idx]
            let existingMoons = moons.filter { $0.parentId == parent.id }.count
            let m = MoonData(
                id: moonIdCounter,
                parentId: parent.id,
                orbitRadius: parent.size * 1.5 + Double(existingMoons) * 8 + nextDouble(&rng) * 8,
                orbitSpeed: 1.2 + nextDouble(&rng) * 2.5,
                orbitPhase: nextDouble(&rng) * .pi * 2,
                size: 1.5 + nextDouble(&rng) * 3,
                hue: parent.baseHue + (nextDouble(&rng) - 0.5) * 0.2
            )
            moons.append(m)
            moonIdCounter += 1
            // Also shimmer the parent
            shimmers.append(ShimmerEvent(planetId: parent.id, birth: Date().timeIntervalSince(startDate)))
            if shimmers.count > 8 { shimmers.removeFirst() }
        }
    }

    // MARK: - Deep space background

    private func drawSpace(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        // Very faint nebula washes
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 80))
            let pulse1 = sin(t * 0.015) * 0.01
            l.fill(Ellipse().path(in: CGRect(x: size.width * 0.2, y: size.height * 0.1,
                                              width: size.width * 0.5, height: size.height * 0.4)),
                   with: .color(Color(red: 0.06 + pulse1, green: 0.02, blue: 0.10 + pulse1).opacity(0.2)))
            l.fill(Ellipse().path(in: CGRect(x: size.width * 0.5, y: size.height * 0.5,
                                              width: size.width * 0.4, height: size.height * 0.3)),
                   with: .color(Color(red: 0.03, green: 0.04 + pulse1, blue: 0.08).opacity(0.15)))
        }

        // Stars
        var rng = SplitMix64(seed: 9876)
        for _ in 0..<120 {
            let sx = nextDouble(&rng) * size.width
            let sy = nextDouble(&rng) * size.height
            let ss = 0.3 + nextDouble(&rng) * 1.5
            let twinkle = sin(t * (0.4 + nextDouble(&rng) * 1.5) + nextDouble(&rng) * 6.28) * 0.25 + 0.75
            let brightness = (0.25 + nextDouble(&rng) * 0.5) * twinkle
            ctx.fill(Ellipse().path(in: CGRect(x: sx - ss / 2, y: sy - ss / 2, width: ss, height: ss)),
                     with: .color(Color(red: brightness * 0.9, green: brightness * 0.95, blue: brightness * 1.1).opacity(0.5)))
        }
    }

    // MARK: - Orbital grid lines (subtle T&L tech-demo feel)

    private func drawOrbitalGrid(ctx: inout GraphicsContext, size: CGSize, center: CGPoint, t: Double) {
        for planet in planets {
            let rx = planet.orbitRadius * size.width * 0.42
            let ry = rx * planet.tilt
            let orbitRect = CGRect(x: center.x - rx, y: center.y - ry, width: rx * 2, height: ry * 2)
            ctx.stroke(Ellipse().path(in: orbitRect),
                       with: .color(Color(red: 0.15, green: 0.12, blue: 0.25).opacity(0.10)),
                       lineWidth: 0.5)
        }
    }

    // MARK: - Central star (Gouraud-shaded sphere with HDR bloom)

    private func drawStar(ctx: inout GraphicsContext, size: CGSize, center: CGPoint, t: Double) {
        let starR: Double = 28
        let pulse = sin(t * 0.3) * 0.08 + 0.92

        // Outer corona glow
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 50))
            let glowR = starR * 5
            l.fill(Ellipse().path(in: CGRect(x: center.x - glowR, y: center.y - glowR,
                                              width: glowR * 2, height: glowR * 2)),
                   with: .color(Color(red: 1.2 * pulse, green: 0.7 * pulse, blue: 0.2).opacity(0.15)))
        }

        // Inner bloom
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 15))
            let bloomR = starR * 2
            l.fill(Ellipse().path(in: CGRect(x: center.x - bloomR, y: center.y - bloomR,
                                              width: bloomR * 2, height: bloomR * 2)),
                   with: .color(Color(red: 1.5 * pulse, green: 1.0 * pulse, blue: 0.4).opacity(0.3)))
        }

        // Star disc — Gouraud shaded (radial gradient simulating lit sphere)
        let discRect = CGRect(x: center.x - starR, y: center.y - starR, width: starR * 2, height: starR * 2)
        ctx.fill(Ellipse().path(in: discRect), with: .radialGradient(
            Gradient(colors: [
                Color(red: 2.0 * pulse, green: 1.6 * pulse, blue: 0.8),      // HDR white-hot center
                Color(red: 1.5 * pulse, green: 1.0 * pulse, blue: 0.3),      // warm yellow
                Color(red: 1.0 * pulse, green: 0.5 * pulse, blue: 0.1),      // orange rim
            ]),
            center: CGPoint(x: center.x - starR * 0.15, y: center.y - starR * 0.15),
            startRadius: 0,
            endRadius: starR
        ))
    }

    // MARK: - Gouraud-shaded planet

    private func drawPlanet(ctx: inout GraphicsContext, size: CGSize, center: CGPoint, planet: PlanetData, t: Double) {
        let pos = planetPosition(planet, center: center, size: size, t: t)
        let r = planet.size
        let la = lightAngle(t)

        // Light direction offset for this planet
        let lightX = cos(la) * 0.35
        let lightY = sin(la) * 0.35

        // Depth-based scaling (further = smaller, as basic perspective)
        let depthFactor = 0.85 + planetAngle(planet, t: t, tilt: planet.tilt) * 0.15 + 0.15
        let scaledR = r * depthFactor

        // Ring behind planet
        if planet.hasRing {
            drawRing(ctx: &ctx, pos: pos, planet: planet, scaledR: scaledR, t: t, behind: true)
        }

        let discRect = CGRect(x: pos.x - scaledR, y: pos.y - scaledR, width: scaledR * 2, height: scaledR * 2)

        // Gouraud shading: radial gradient offset toward light source
        let highlightCenter = CGPoint(
            x: pos.x + lightX * scaledR,
            y: pos.y + lightY * scaledR
        )

        let litH = planet.baseHue
        let litS = planet.saturation * 0.7
        let litB = min(planet.brightness + 0.35, 1.0)
        let midS = planet.saturation
        let midB = planet.brightness
        let darkS = planet.saturation * 1.1
        let darkB = max(planet.brightness - 0.25, 0.05)

        ctx.fill(Ellipse().path(in: discRect), with: .radialGradient(
            Gradient(colors: [
                Color(hue: litH, saturation: litS, brightness: litB),       // lit highlight
                Color(hue: litH, saturation: midS, brightness: midB),       // mid tone
                Color(hue: litH + 0.02, saturation: darkS, brightness: darkB),  // terminator
                Color(hue: litH + 0.03, saturation: darkS, brightness: darkB * 0.3),  // shadow
            ]),
            center: highlightCenter,
            startRadius: 0,
            endRadius: scaledR * 1.3
        ))

        // Specular highlight (T&L style hot spot)
        let specX = pos.x + lightX * scaledR * 0.7
        let specY = pos.y + lightY * scaledR * 0.7
        let specR = scaledR * 0.25
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: specR * 0.5))
            l.fill(Ellipse().path(in: CGRect(x: specX - specR, y: specY - specR,
                                              width: specR * 2, height: specR * 2)),
                   with: .color(Color.white.opacity(0.25)))
        }

        // Atmospheric rim (fresnel-like glow at the edge)
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 3))
            let rimRect = CGRect(x: pos.x - scaledR - 1, y: pos.y - scaledR - 1,
                                 width: (scaledR + 1) * 2, height: (scaledR + 1) * 2)
            l.stroke(Ellipse().path(in: rimRect),
                     with: .color(Color(hue: planet.baseHue, saturation: 0.3, brightness: 0.8).opacity(0.15)),
                     lineWidth: 1.5)
        }

        // Surface detail bands (like Jupiter's stripes — Gouraud-style color bands)
        if planet.size > 14 {
            let bandCount = Int(planet.size / 5)
            for b in 0..<bandCount {
                let bandY = pos.y - scaledR + Double(b + 1) * (scaledR * 2) / Double(bandCount + 1)
                let bandHalfW = sqrt(max(0, scaledR * scaledR - pow(bandY - pos.y, 2)))
                let bandAlpha = 0.06 + sin(Double(b) * 2.1 + planet.orbitPhase) * 0.03
                ctx.fill(Rectangle().path(in: CGRect(x: pos.x - bandHalfW, y: bandY - 0.5,
                                                      width: bandHalfW * 2, height: 1)),
                         with: .color(Color(hue: planet.baseHue + 0.05, saturation: 0.4, brightness: 0.5).opacity(bandAlpha)))
            }
        }

        // Ring in front
        if planet.hasRing {
            drawRing(ctx: &ctx, pos: pos, planet: planet, scaledR: scaledR, t: t, behind: false)
        }
    }

    // MARK: - Planet rings (with Gouraud banding)

    private func drawRing(ctx: inout GraphicsContext, pos: CGPoint, planet: PlanetData, scaledR: Double, t: Double, behind: Bool) {
        let innerR = scaledR * 1.4
        let outerR = scaledR * 2.2
        let squash = 0.2 + planet.tilt * 0.15
        let la = lightAngle(t)
        let ringBright = 0.4 + cos(la - planet.orbitPhase) * 0.15

        let bands = 5
        for b in 0..<bands {
            let frac = Double(b) / Double(bands)
            let r = innerR + (outerR - innerR) * frac
            let w = (outerR - innerR) / Double(bands) * 0.8
            let ry = r * squash
            let rx = r

            if behind {
                // Only draw top half (behind planet)
                var arc = Path()
                arc.addArc(center: pos, radius: 1, startAngle: .radians(.pi), endAngle: .radians(0), clockwise: false,
                           transform: CGAffineTransform(scaleX: rx, y: ry))
                ctx.stroke(arc, with: .color(Color(hue: planet.ringHue + frac * 0.04, saturation: 0.3,
                                                    brightness: ringBright - frac * 0.08).opacity(0.2)),
                           lineWidth: w)
            } else {
                // Only bottom half (in front)
                var arc = Path()
                arc.addArc(center: pos, radius: 1, startAngle: .radians(0), endAngle: .radians(.pi), clockwise: false,
                           transform: CGAffineTransform(scaleX: rx, y: ry))
                ctx.stroke(arc, with: .color(Color(hue: planet.ringHue + frac * 0.04, saturation: 0.3,
                                                    brightness: ringBright - frac * 0.08).opacity(0.2)),
                           lineWidth: w)
            }
        }
    }

    // MARK: - Moon (small Gouraud sphere orbiting its parent)

    private func drawMoon(ctx: inout GraphicsContext, size: CGSize, center: CGPoint, planet: PlanetData, moon: MoonData, t: Double) {
        let parentPos = planetPosition(planet, center: center, size: size, t: t)
        let moonAngle = t * moon.orbitSpeed + moon.orbitPhase
        let mx = parentPos.x + cos(moonAngle) * moon.orbitRadius
        let my = parentPos.y + sin(moonAngle) * moon.orbitRadius * 0.45
        let r = moon.size

        let la = lightAngle(t)
        let lx = cos(la) * 0.35
        let ly = sin(la) * 0.35

        let discRect = CGRect(x: mx - r, y: my - r, width: r * 2, height: r * 2)
        ctx.fill(Ellipse().path(in: discRect), with: .radialGradient(
            Gradient(colors: [
                Color(hue: moon.hue, saturation: 0.3, brightness: 0.7),
                Color(hue: moon.hue, saturation: 0.4, brightness: 0.35),
                Color(hue: moon.hue, saturation: 0.3, brightness: 0.08),
            ]),
            center: CGPoint(x: mx + lx * r, y: my + ly * r),
            startRadius: 0,
            endRadius: r * 1.2
        ))

        // Tiny specular
        let specR = r * 0.3
        ctx.drawLayer { l in
            l.addFilter(.blur(radius: 2))
            l.fill(Ellipse().path(in: CGRect(x: mx + lx * r * 0.6 - specR / 2,
                                              y: my + ly * r * 0.6 - specR / 2,
                                              width: specR, height: specR)),
                   with: .color(Color.white.opacity(0.2)))
        }
    }

    // MARK: - Shimmer effects

    private func drawShimmers(ctx: inout GraphicsContext, size: CGSize, center: CGPoint, t: Double) {
        for shimmer in shimmers {
            let age = t - shimmer.birth
            guard age < 2.5 else { continue }
            guard let planet = planets.first(where: { $0.id == shimmer.planetId }) else { continue }
            let pos = planetPosition(planet, center: center, size: size, t: t)
            let fade = 1.0 - age / 2.5
            let expand = planet.size + age * 20

            ctx.drawLayer { l in
                l.addFilter(.blur(radius: 12 + age * 8))
                l.fill(Ellipse().path(in: CGRect(x: pos.x - expand, y: pos.y - expand,
                                                  width: expand * 2, height: expand * 2)),
                       with: .color(Color(hue: planet.baseHue, saturation: 0.4, brightness: 1.2).opacity(0.18 * fade)))
            }

            // Sparkle ring
            let sparkleCount = 8
            for s in 0..<sparkleCount {
                let sa = Double(s) / Double(sparkleCount) * .pi * 2 + age * 1.5
                let sr = expand * 0.9
                let sx = pos.x + cos(sa) * sr
                let sy = pos.y + sin(sa) * sr * 0.5
                let ss = 1.5 * fade
                ctx.fill(Ellipse().path(in: CGRect(x: sx - ss, y: sy - ss, width: ss * 2, height: ss * 2)),
                         with: .color(Color.white.opacity(0.3 * fade)))
            }
        }
    }

    // MARK: - Scanlines (subtle retro CRT/demo feel)

    private func drawScanlines(ctx: inout GraphicsContext, size: CGSize, t: Double) {
        let spacing: Double = 3
        var y: Double = 0
        while y < size.height {
            ctx.fill(Rectangle().path(in: CGRect(x: 0, y: y, width: size.width, height: 1)),
                     with: .color(Color.black.opacity(0.04)))
            y += spacing
        }
    }
}
