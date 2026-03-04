// LastAndFirstMen3DScene — Abstract art deco retelling of Olaf Stapledon's
// Last and First Men (1930). Eighteen human species across two billion years,
// migrating from Earth to Venus to Neptune, ascending through the Kardashev
// scale from a single world to the stars. Peaceful, contemplative, eternal.
// Tap to awaken the next human species in the long chain of becoming.

import SwiftUI
import SceneKit

struct LastAndFirstMen3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        LastAndFirstMen3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct LastAndFirstMen3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject {
        var lastTapCount = 0
        var speciesNodes: [SCNNode] = []
        var speciesIndex = 0
        var kardashevRings: [SCNNode] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.02, green: 0.01, blue: 0.06, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount

        // Awaken the next species in the chain of becoming
        guard !c.speciesNodes.isEmpty else { return }
        let idx = c.speciesIndex % c.speciesNodes.count
        c.speciesIndex += 1
        let node = c.speciesNodes[idx]
        node.runAction(.sequence([
            .customAction(duration: 0.0) { n, _ in
                n.geometry?.firstMaterial?.emission.intensity = 4.0
            },
            .customAction(duration: 2.5) { n, t in
                let frac = CGFloat(t / 2.5)
                n.geometry?.firstMaterial?.emission.intensity = 4.0 - (4.0 - 0.8) * frac
            }
        ]))

        // Ripple the Kardashev rings outward
        for (i, ring) in c.kardashevRings.enumerated() {
            let delay = Double(i) * 0.5
            ring.runAction(.sequence([
                .wait(duration: delay),
                .customAction(duration: 0.0) { n, _ in
                    n.geometry?.firstMaterial?.emission.intensity = 2.8
                },
                .customAction(duration: 1.8) { n, t in
                    let frac = CGFloat(t / 1.8)
                    n.geometry?.firstMaterial?.emission.intensity = 2.8 - (2.8 - 0.5) * frac
                }
            ]))
        }
    }

    // MARK: - Build scene

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.02, green: 0.01, blue: 0.06, alpha: 1)
        scene.fogStartDistance = 38
        scene.fogEndDistance = 80
        scene.fogColor = NSColor(red: 0.02, green: 0.01, blue: 0.06, alpha: 1)

        addStarField(to: scene)
        addLighting(to: scene)
        addTimelineSpire(to: scene)
        addWorlds(to: scene)
        addKardashevRings(to: scene, coord: coord)
        addSpeciesChain(to: scene, coord: coord)
        addSeedParticles(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Star field

    private func addStarField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 2030)
        for _ in 0..<350 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let phi   = Double.random(in: 0...(.pi), using: &rng)
            let r     = Double.random(in: 45...70, using: &rng)
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(r * cos(phi))
            let z = Float(r * sin(phi) * sin(theta))
            let size       = CGFloat(Double.random(in: 0.04...0.14, using: &rng))
            let brightness = Double.random(in: 0.25...1.0, using: &rng)

            let geo = SCNPlane(width: size, height: size)
            let mat = SCNMaterial()
            mat.lightingModel = .constant
            mat.emission.contents = NSColor(white: brightness, alpha: 1)
            mat.diffuse.contents = NSColor.black
            mat.isDoubleSided = true
            mat.blendMode = .add
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(x, y, z)
            let billboard = SCNBillboardConstraint()
            billboard.freeAxes = .all
            node.constraints = [billboard]
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 12
        ambient.light!.color = NSColor(red: 0.08, green: 0.06, blue: 0.16, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Warm directional fill, like a distant sun
        let solar = SCNNode()
        solar.light = SCNLight()
        solar.light!.type = .directional
        solar.light!.intensity = 180
        solar.light!.color = NSColor(red: 1.0, green: 0.90, blue: 0.65, alpha: 1)
        solar.eulerAngles = SCNVector3(-Float.pi / 6, Float.pi / 5, 0)
        scene.rootNode.addChildNode(solar)
    }

    // MARK: - Central art deco obelisk (axis of time)

    private func addTimelineSpire(to scene: SCNScene) {
        let gold = NSColor(red: 0.88, green: 0.70, blue: 0.25, alpha: 1)

        // Stepped plinth base — art deco pyramid steps
        let steps: [(CGFloat, CGFloat)] = [(3.2, 0.28), (2.3, 0.28), (1.5, 0.28)]
        var yOff: CGFloat = -5.0
        for (w, h) in steps {
            let box = SCNBox(width: w, height: h, length: w, chamferRadius: 0)
            let m = SCNMaterial()
            m.diffuse.contents = gold
            m.emission.contents = gold
            m.emission.intensity = 0.22
            box.firstMaterial = m
            let n = SCNNode(geometry: box)
            n.position = SCNVector3(0, yOff + h / 2, 0)
            scene.rootNode.addChildNode(n)
            yOff += h
        }

        // Slender shaft
        let shaft = SCNBox(width: 0.55, height: 11.5, length: 0.55, chamferRadius: 0.02)
        let sm = SCNMaterial()
        sm.diffuse.contents = NSColor(red: 0.72, green: 0.58, blue: 0.18, alpha: 1)
        sm.emission.contents = NSColor(red: 0.88, green: 0.70, blue: 0.25, alpha: 1)
        sm.emission.intensity = 0.35
        shaft.firstMaterial = sm
        let shaftNode = SCNNode(geometry: shaft)
        shaftNode.position = SCNVector3(0, yOff + 11.5 / 2, 0)
        scene.rootNode.addChildNode(shaftNode)

        // Pyramid cap
        let capTop = yOff + 11.5
        let cap = SCNPyramid(width: 0.85, height: 1.6, length: 0.85)
        let cm = SCNMaterial()
        cm.diffuse.contents = gold
        cm.emission.contents = gold
        cm.emission.intensity = 0.65
        cap.firstMaterial = cm
        let capNode = SCNNode(geometry: cap)
        capNode.position = SCNVector3(0, capTop + 0.8, 0)
        scene.rootNode.addChildNode(capNode)

        // Art deco sunburst halo at the top of the shaft
        addSunburst(at: SCNVector3(0, capTop, 0),
                    radius: 2.2, spokes: 16, color: gold, to: scene)

        // The cap breathes with light — epochs passing
        capNode.runAction(.repeatForever(.customAction(duration: 6.0) { n, t in
            let pulse = 0.65 + 0.28 * sin(Double(t) * 1.05)
            n.geometry?.firstMaterial?.emission.intensity = CGFloat(pulse)
        }))
    }

    // MARK: - Sunburst (art deco motif: ring + radiating spokes)

    private func addSunburst(at pos: SCNVector3, radius: CGFloat,
                              spokes: Int, color: NSColor, to scene: SCNScene) {
        // Outer ring
        let ring = SCNTorus(ringRadius: radius, pipeRadius: 0.04)
        let rm = SCNMaterial()
        rm.diffuse.contents = color
        rm.emission.contents = color
        rm.emission.intensity = 0.45
        rm.lightingModel = .constant
        ring.firstMaterial = rm
        let rn = SCNNode(geometry: ring)
        rn.position = pos
        rn.eulerAngles = SCNVector3(CGFloat.pi / 2, 0, 0)
        scene.rootNode.addChildNode(rn)

        // Spokes radiating from center to ring
        for i in 0..<spokes {
            let angle = CGFloat(i) / CGFloat(spokes) * 2 * .pi
            let spoke = SCNBox(width: radius, height: 0.022, length: 0.022, chamferRadius: 0)
            let sm2 = SCNMaterial()
            sm2.diffuse.contents = color
            sm2.emission.contents = color
            sm2.emission.intensity = 0.28
            sm2.lightingModel = .constant
            spoke.firstMaterial = sm2
            let sn = SCNNode(geometry: spoke)
            // Center the spoke: it extends from pos to pos + radius in the angle direction
            sn.position = SCNVector3(
                pos.x + cos(angle) * radius / 2,
                pos.y,
                pos.z + sin(angle) * radius / 2
            )
            sn.eulerAngles = SCNVector3(0, -angle, 0)
            scene.rootNode.addChildNode(sn)
        }
    }

    // MARK: - Three worlds

    private func addWorlds(to scene: SCNScene) {
        // Earth — the First Men, blue-green, on the left
        addWorld(
            position:   SCNVector3(-9, 1, -5),
            radius:     1.4,
            color:      NSColor(red: 0.15, green: 0.45, blue: 0.75, alpha: 1),
            emitColor:  NSColor(red: 0.10, green: 0.30, blue: 0.55, alpha: 1),
            haloColor:  NSColor(red: 0.40, green: 0.75, blue: 0.95, alpha: 1),
            ringColor:  NSColor(red: 0.55, green: 0.80, blue: 0.30, alpha: 1),
            to: scene
        )

        // Venus — the middle generations, golden
        addWorld(
            position:   SCNVector3(0, 2, -9),
            radius:     1.2,
            color:      NSColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 1),
            emitColor:  NSColor(red: 0.70, green: 0.48, blue: 0.10, alpha: 1),
            haloColor:  NSColor(red: 1.0,  green: 0.85, blue: 0.45, alpha: 1),
            ringColor:  NSColor(red: 0.95, green: 0.75, blue: 0.30, alpha: 1),
            to: scene
        )

        // Neptune — the Last Men, icy blue, on the right
        addWorld(
            position:   SCNVector3(9, 0, -4),
            radius:     1.6,
            color:      NSColor(red: 0.22, green: 0.48, blue: 0.82, alpha: 1),
            emitColor:  NSColor(red: 0.12, green: 0.28, blue: 0.62, alpha: 1),
            haloColor:  NSColor(red: 0.55, green: 0.78, blue: 1.0,  alpha: 1),
            ringColor:  NSColor(red: 0.58, green: 0.80, blue: 1.0,  alpha: 1),
            to: scene
        )
    }

    private func addWorld(position: SCNVector3, radius: CGFloat,
                           color: NSColor, emitColor: NSColor,
                           haloColor: NSColor, ringColor: NSColor,
                           to scene: SCNScene) {
        // Planet sphere
        let geo = SCNSphere(radius: radius)
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = emitColor
        mat.emission.intensity = 0.5
        mat.lightingModel = .phong
        mat.specular.contents = NSColor.white
        geo.firstMaterial = mat

        let planet = SCNNode(geometry: geo)
        planet.position = position
        scene.rootNode.addChildNode(planet)

        // Slow axial rotation
        planet.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0.08, duration: 28)))

        // Sunburst halo behind the planet (art deco motif)
        addSunburst(at: position, radius: radius * 2.4,
                    spokes: 12, color: haloColor, to: scene)

        // Civilization ring — tilted torus orbiting the world
        let torus = SCNTorus(ringRadius: radius * 2.6, pipeRadius: 0.06)
        let tm = SCNMaterial()
        tm.diffuse.contents = ringColor
        tm.emission.contents = ringColor
        tm.emission.intensity = 0.65
        tm.lightingModel = .constant
        tm.blendMode = .add
        torus.firstMaterial = tm

        let torusNode = SCNNode(geometry: torus)
        torusNode.position = position
        torusNode.eulerAngles = SCNVector3(CGFloat.pi / 5, 0, CGFloat.pi / 8)
        scene.rootNode.addChildNode(torusNode)
        torusNode.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0, duration: 22)))

        // Gentle glow breathing on the planet
        planet.runAction(.repeatForever(.customAction(duration: 8.0) { n, t in
            let v = 0.5 + 0.18 * sin(Double(t) * 0.79)
            n.geometry?.firstMaterial?.emission.intensity = CGFloat(v)
        }))
    }

    // MARK: - Kardashev scale rings

    private func addKardashevRings(to scene: SCNScene, coord: Coordinator) {
        // Type I — planetary energy, warm gold, innermost
        let k1 = makeKardashevRing(
            radius:    6.5,
            pipeR:     0.12,
            color:     NSColor(red: 0.90, green: 0.70, blue: 0.20, alpha: 1),
            intensity: 0.55,
            period:    42,
            tilt:      SCNVector3(0.20, 0.0, 0.10)
        )
        k1.position = SCNVector3(0, -2, -5)
        scene.rootNode.addChildNode(k1)
        coord.kardashevRings.append(k1)

        // Type II — stellar energy, solar amber, mid ring
        let k2 = makeKardashevRing(
            radius:    14,
            pipeR:     0.10,
            color:     NSColor(red: 1.0, green: 0.82, blue: 0.35, alpha: 1),
            intensity: 0.42,
            period:    72,
            tilt:      SCNVector3(0.15, 0.08, 0.05)
        )
        k2.position = SCNVector3(0, -1, -5)
        scene.rootNode.addChildNode(k2)
        coord.kardashevRings.append(k2)

        // Type III — galactic energy, cool white-blue, outermost
        let k3 = makeKardashevRing(
            radius:    24,
            pipeR:     0.08,
            color:     NSColor(red: 0.68, green: 0.84, blue: 1.0, alpha: 1),
            intensity: 0.30,
            period:    130,
            tilt:      SCNVector3(0.10, 0.05, 0.08)
        )
        k3.position = SCNVector3(0, 0, -5)
        scene.rootNode.addChildNode(k3)
        coord.kardashevRings.append(k3)
    }

    private func makeKardashevRing(radius: CGFloat, pipeR: CGFloat,
                                    color: NSColor, intensity: CGFloat,
                                    period: Double, tilt: SCNVector3) -> SCNNode {
        let torus = SCNTorus(ringRadius: radius, pipeRadius: pipeR)
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = intensity
        m.lightingModel = .constant
        m.blendMode = .add
        torus.firstMaterial = m

        let n = SCNNode(geometry: torus)
        n.eulerAngles = tilt
        n.runAction(.repeatForever(.rotateBy(x: 0.04, y: CGFloat(2 * Double.pi), z: 0, duration: period)))
        // Gentle pulse
        n.runAction(.repeatForever(.customAction(duration: 9.0) { node, t in
            let pulse = intensity + intensity * 0.35 * CGFloat(sin(Double(t) * 0.70))
            node.geometry?.firstMaterial?.emission.intensity = pulse
        }))
        return n
    }

    // MARK: - 18 Human Species — arc from Earth to Neptune

    private func addSpeciesChain(to scene: SCNScene, coord: Coordinator) {
        // Warm-to-cool gradient: Earth blue → Venus gold → Neptune ice
        let speciesColors: [NSColor] = [
            NSColor(red: 0.38, green: 0.72, blue: 0.95, alpha: 1),  //  1 First Men (Earth)
            NSColor(red: 0.48, green: 0.76, blue: 0.88, alpha: 1),  //  2
            NSColor(red: 0.60, green: 0.80, blue: 0.76, alpha: 1),  //  3
            NSColor(red: 0.70, green: 0.82, blue: 0.60, alpha: 1),  //  4
            NSColor(red: 0.80, green: 0.84, blue: 0.48, alpha: 1),  //  5
            NSColor(red: 0.90, green: 0.82, blue: 0.38, alpha: 1),  //  6
            NSColor(red: 0.96, green: 0.76, blue: 0.30, alpha: 1),  //  7 Venus era begins
            NSColor(red: 0.97, green: 0.70, blue: 0.26, alpha: 1),  //  8
            NSColor(red: 0.95, green: 0.62, blue: 0.26, alpha: 1),  //  9
            NSColor(red: 0.92, green: 0.54, blue: 0.30, alpha: 1),  // 10
            NSColor(red: 0.88, green: 0.48, blue: 0.38, alpha: 1),  // 11
            NSColor(red: 0.80, green: 0.46, blue: 0.52, alpha: 1),  // 12
            NSColor(red: 0.70, green: 0.50, blue: 0.68, alpha: 1),  // 13
            NSColor(red: 0.60, green: 0.52, blue: 0.82, alpha: 1),  // 14 Neptune era begins
            NSColor(red: 0.52, green: 0.60, blue: 0.92, alpha: 1),  // 15
            NSColor(red: 0.48, green: 0.68, blue: 0.97, alpha: 1),  // 16
            NSColor(red: 0.44, green: 0.74, blue: 1.00, alpha: 1),  // 17
            NSColor(red: 0.40, green: 0.80, blue: 1.00, alpha: 1),  // 18 Last Men (Neptune)
        ]

        // Quadratic Bézier arc: Earth → high point → Neptune
        let p0 = SIMD3<Float>(-9, 1, -5)
        let p1 = SIMD3<Float>(0,  6, -12)   // apex lifts up and back for depth
        let p2 = SIMD3<Float>(9,  0, -4)

        for i in 0..<18 {
            let t = Float(i) / 17.0
            let pos = bezier(t: t, p0: p0, p1: p1, p2: p2)

            let geo = SCNSphere(radius: 0.24)
            geo.segmentCount = 6  // low-poly faceted feel
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 0.02, green: 0.01, blue: 0.04, alpha: 1)
            mat.emission.contents = speciesColors[i]
            mat.emission.intensity = 0.80
            mat.lightingModel = .constant
            mat.blendMode = .add
            mat.isDoubleSided = true
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(CGFloat(pos.x), CGFloat(pos.y), CGFloat(pos.z))
            scene.rootNode.addChildNode(node)
            coord.speciesNodes.append(node)

            // Slow spin and gentle bob
            let bobPhase = Double(i) * 0.35
            let baseY = CGFloat(pos.y)
            node.runAction(.repeatForever(.customAction(duration: 10.0) { n, elapsed in
                let bob = 0.20 * sin(Double(elapsed) * 0.63 + bobPhase)
                n.position.y = baseY + CGFloat(bob)
            }))
            node.runAction(.repeatForever(.rotateBy(x: 0, y: 2 * .pi, z: 0.25, duration: Double(11 + i))))

            // Filament connecting to the next species
            if i < 17 {
                let nextT = Float(i + 1) / 17.0
                let nextPos = bezier(t: nextT, p0: p0, p1: p1, p2: p2)
                let blended = speciesColors[i].blended(withFraction: 0.5,
                                                        of: speciesColors[i + 1])
                              ?? speciesColors[i]
                addSpeciesFilament(from: pos, to: nextPos, color: blended, to: scene)
            }
        }
    }

    // Quadratic Bézier
    private func bezier(t: Float,
                         p0: SIMD3<Float>, p1: SIMD3<Float>, p2: SIMD3<Float>) -> SIMD3<Float> {
        let mt = 1.0 - t
        return mt * mt * p0 + 2 * mt * t * p1 + t * t * p2
    }

    private func addSpeciesFilament(from a: SIMD3<Float>, to b: SIMD3<Float>,
                                     color: NSColor, to scene: SCNScene) {
        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z
        let dist = CGFloat(sqrt(dx * dx + dy * dy + dz * dz))
        let mid = SIMD3<Float>((a.x + b.x) / 2, (a.y + b.y) / 2, (a.z + b.z) / 2)

        let cyl = SCNCylinder(radius: 0.016, height: dist)
        let fm = SCNMaterial()
        fm.diffuse.contents = NSColor.clear
        fm.emission.contents = color
        fm.emission.intensity = 0.32
        fm.lightingModel = .constant
        fm.blendMode = .add
        fm.isDoubleSided = true
        cyl.firstMaterial = fm

        let node = SCNNode(geometry: cyl)
        node.position = SCNVector3(CGFloat(mid.x), CGFloat(mid.y), CGFloat(mid.z))
        node.look(at: SCNVector3(CGFloat(b.x), CGFloat(b.y), CGFloat(b.z)))
        node.eulerAngles.x += .pi / 2
        scene.rootNode.addChildNode(node)

        let phase = Double(mid.x + mid.y)
        node.runAction(.repeatForever(.customAction(duration: 7.0) { n, elapsed in
            let p = 0.22 + 0.14 * sin(Double(elapsed) * 0.90 + phase)
            n.geometry?.firstMaterial?.emission.intensity = CGFloat(p)
        }))
    }

    // MARK: - Seed particles — the Last Men cast life into the cosmos

    private func addSeedParticles(to scene: SCNScene) {
        let seeds = SCNParticleSystem()
        seeds.birthRate = 7
        seeds.emitterShape = SCNSphere(radius: 1.8)
        seeds.particleLifeSpan = 14.0
        seeds.particleLifeSpanVariation = 5.0
        seeds.particleVelocity = 0.45
        seeds.particleVelocityVariation = 0.22
        seeds.particleSize = 0.05
        seeds.particleSizeVariation = 0.025
        seeds.particleColor = NSColor(red: 0.52, green: 0.74, blue: 1.0, alpha: 0.65)
        seeds.particleColorVariation = SCNVector4(0.08, 0.08, 0.04, 0.18)
        seeds.isAffectedByGravity = false
        seeds.blendMode = .additive
        seeds.spreadingAngle = 50

        let emitter = SCNNode()
        emitter.position = SCNVector3(9, 0, -4)  // at Neptune
        emitter.addParticleSystem(seeds)
        scene.rootNode.addChildNode(emitter)
    }

    // MARK: - Camera — cinematic journey through the epochs

    private func addCamera(to scene: SCNScene) {
        let cam = SCNCamera()
        cam.fieldOfView = 58
        cam.zNear = 0.1
        cam.zFar = 110
        cam.wantsHDR = true
        cam.bloomIntensity = 0.75
        cam.bloomThreshold = 0.32
        cam.bloomBlurRadius = 5
        cam.vignettingIntensity = 0.55
        cam.vignettingPower = 1.8

        let camNode = SCNNode()
        camNode.camera = cam
        scene.rootNode.addChildNode(camNode)

        // Five-phase 120-second loop — directed like an art film:
        //   Phase 1 (  0–25s): Close on Earth — the First Men, a single blue world
        //   Phase 2 ( 25–50s): Pull back — Venus and Neptune revealed, the epic scope
        //   Phase 3 ( 50–75s): Slow orbit — the arc of 18 species, the chain of becoming
        //   Phase 4 ( 75–100s): Drift toward Neptune — the Last Men, the long farewell
        //   Phase 5 (100–120s): Ascend to cosmic — all three Kardashev rings visible
        let journey = SCNAction.repeatForever(.customAction(duration: 120.0) { n, elapsed in
            let t = Double(elapsed)
            // Inline smooth-step easing (3t²–2t³)
            func ss(_ raw: Double) -> Double { let x = max(0, min(1, raw)); return x * x * (3 - 2 * x) }

            let camX: Double
            let camY: Double
            let camZ: Double
            let tgtX: Double
            let tgtY: Double
            let tgtZ: Double
            let fov: Double

            if t < 25 {
                // Phase 1: intimate view of Earth
                let f = ss(t / 25.0)
                camX = -9.0 + f * 2.5
                camY = 3.5  - f * 1.0
                camZ = 4.5  - f * 2.5
                tgtX = -9;  tgtY = 1;  tgtZ = -5
                fov = 54
            } else if t < 50 {
                // Phase 2: grand pull-back revealing all three worlds
                let f = ss((t - 25) / 25.0)
                camX = -6.5 + f * 6.5
                camY = 2.5  + f * 5.5
                camZ = 2.0  + f * 9.0
                tgtX = 0;   tgtY = 1;  tgtZ = -6
                fov = 54 + f * 10
            } else if t < 75 {
                // Phase 3: slow orbit, following the species chain
                let f = ss((t - 50) / 25.0)
                let angle = f * Double.pi * 1.4
                camX = 15 * sin(angle)
                camY = 8  + 2 * sin(angle * 0.35)
                camZ = 11 + 4 * cos(angle)
                tgtX = 0;   tgtY = 2;  tgtZ = -6
                fov = 62
            } else if t < 100 {
                // Phase 4: slow approach to Neptune — the last chapter
                let f = ss((t - 75) / 25.0)
                camX = 15 * sin(Double.pi * 1.4) * (1 - f) + 3.0 * f
                camY = 10 * (1 - f) + 2.5 * f
                camZ = 11 + 4 * cos(Double.pi * 1.4) * (1 - f) + 2.0 * f
                tgtX = 9;   tgtY = 0;  tgtZ = -4
                fov = 62 - f * 10
            } else {
                // Phase 5: ascend to cosmic — the Kardashev rings fill the sky
                let f = ss((t - 100) / 20.0)
                camX = 3.0  * (1 - f) + 0.0  * f
                camY = 2.5  * (1 - f) + 22.0 * f
                camZ = 2.0  * (1 - f) + 24.0 * f
                tgtX = 0;   tgtY = 0;  tgtZ = -5
                fov = 52 + f * 22
            }

            n.position = SCNVector3(CGFloat(camX), CGFloat(camY), CGFloat(camZ))

            // Point camera at target
            let dx = tgtX - camX
            let dy = tgtY - camY
            let dz = tgtZ - camZ
            let dist = sqrt(dx * dx + dy * dy + dz * dz)
            if dist > 0.001 {
                let yaw   = atan2(dx, dz)
                let pitch = -atan2(dy, sqrt(dx * dx + dz * dz))
                n.eulerAngles = SCNVector3(CGFloat(pitch), CGFloat(yaw), 0)
            }

            n.camera?.fieldOfView = CGFloat(fov)
        })
        camNode.runAction(journey)
    }
}
