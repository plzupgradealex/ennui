// AuroraBorealis3DScene — SceneKit aurora over frozen lake.
// The blocky aurora curtain planes are preserved as a beautiful contrast
// against thousands of fine mist particles that dance and drift.
// The ground is blanketed in tiny reflective snowflakes.
// Tap creates a localized aurora flare near the click position.

import SwiftUI
import SceneKit

struct AuroraBorealis3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        AuroraBorealis3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct AuroraBorealis3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator: NSObject {
        var lastTapCount = 0
        var auroraMaterials: [SCNMaterial] = []
        var auroraBaseColors: [NSColor] = []
        var auroraNodes: [SCNNode] = []
        var flareNodes: [SCNNode] = []
        var scnView: SCNView?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        context.coordinator.scnView = view
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount

        // Localized flare: pick nearest 1-2 aurora curtains and flash them,
        // leave the rest untouched
        let flareIndex = interaction.tapCount % c.auroraMaterials.count
        let nearIndices = [flareIndex, (flareIndex + 1) % c.auroraMaterials.count]

        for idx in nearIndices {
            guard idx < c.auroraMaterials.count else { continue }
            let mat = c.auroraMaterials[idx]
            let base = c.auroraBaseColors[idx]

            // Bright flash
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.12
            mat.emission.contents = NSColor(
                red: min(1.0, base.redComponent * 0.3 + 0.7),
                green: min(1.0, base.greenComponent * 0.3 + 0.7),
                blue: min(1.0, base.blueComponent * 0.3 + 0.7),
                alpha: 1)
            mat.emission.intensity = 2.5
            SCNTransaction.commit()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 2.5
                mat.emission.contents = base
                mat.emission.intensity = 1.0
                SCNTransaction.commit()
            }
        }

        // Spawn a localized mist burst near the flared curtain
        if let scene = nsView.scene, flareIndex < c.auroraNodes.count {
            let auroraPos = c.auroraNodes[flareIndex].position
            spawnFlareBurst(scene: scene, at: auroraPos, color: c.auroraBaseColors[flareIndex])
        }
    }

    // MARK: - Flare burst (localized mist explosion on tap)

    private func spawnFlareBurst(scene: SCNScene, at pos: SCNVector3, color: NSColor) {
        let burst = SCNParticleSystem()
        burst.birthRate = 800
        burst.emissionDuration = 0.3
        burst.loops = false
        burst.particleLifeSpan = 2.5
        burst.particleLifeSpanVariation = 1.0
        burst.particleSize = 0.15
        burst.particleSizeVariation = 0.08
        burst.particleColor = color
        burst.particleColorVariation = SCNVector4(0.1, 0.15, 0.1, 0)
        burst.emittingDirection = SCNVector3(0, 0.5, 1)
        burst.spreadingAngle = 120
        burst.particleVelocity = 1.5
        burst.particleVelocityVariation = 0.8
        burst.isAffectedByGravity = false
        burst.dampingFactor = 0.3
        burst.blendMode = .additive
        burst.particleImage = nil

        let emitter = SCNNode()
        emitter.position = pos
        emitter.addParticleSystem(burst)
        scene.rootNode.addChildNode(emitter)

        // Clean up after particles die
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            emitter.removeFromParentNode()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        addLighting(to: scene)
        addSnowGround(to: scene)
        addFrozenLake(to: scene)
        addSnowflakeField(to: scene)
        addPineTrees(to: scene)
        addAuroraCurtains(to: scene, coord: coord)
        addAuroraMist(to: scene)
        addStarField(to: scene)
        addMoon(to: scene)
        addCamera(to: scene)

        // Atmospheric fog
        scene.fogStartDistance = 20
        scene.fogEndDistance = 55
        scene.fogColor = NSColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1)
        scene.fogDensityExponent = 1.2
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        // Cool ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 30
        ambient.light!.color = NSColor(red: 0.06, green: 0.12, blue: 0.25, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Moonlight directional
        let moon = SCNNode()
        moon.light = SCNLight()
        moon.light!.type = .directional
        moon.light!.intensity = 120
        moon.light!.color = NSColor(red: 0.65, green: 0.72, blue: 0.95, alpha: 1)
        moon.light!.castsShadow = true
        moon.light!.shadowMode = .deferred
        moon.light!.shadowRadius = 4
        moon.light!.shadowSampleCount = 8
        moon.eulerAngles = SCNVector3(CGFloat(-Float.pi / 4), CGFloat(-Float.pi / 8), 0)
        scene.rootNode.addChildNode(moon)

        // Aurora glow — green-tinted uplighting from horizon
        let auroraGlow = SCNNode()
        auroraGlow.light = SCNLight()
        auroraGlow.light!.type = .directional
        auroraGlow.light!.intensity = 25
        auroraGlow.light!.color = NSColor(red: 0.1, green: 0.6, blue: 0.35, alpha: 1)
        auroraGlow.eulerAngles = SCNVector3(CGFloat(Float.pi / 6), 0, 0)
        scene.rootNode.addChildNode(auroraGlow)
    }

    // MARK: - Snow ground

    private func addSnowGround(to scene: SCNScene) {
        let floor = SCNFloor()
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.78, green: 0.82, blue: 0.88, alpha: 1)
        mat.specular.contents = NSColor(red: 0.5, green: 0.6, blue: 0.8, alpha: 0.5)
        mat.shininess = 20
        mat.lightingModel = .blinn
        floor.firstMaterial = mat
        floor.reflectivity = 0.08
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Snowflake field (thousands of tiny reflective crystals on ground)

    private func addSnowflakeField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 4003)

        // Snowflake billboard material — tiny bright specks
        let snowMat = SCNMaterial()
        snowMat.lightingModel = .constant
        snowMat.diffuse.contents = NSColor(red: 0.85, green: 0.90, blue: 0.98, alpha: 1)
        snowMat.emission.contents = NSColor(red: 0.25, green: 0.30, blue: 0.45, alpha: 1)
        snowMat.emission.intensity = 0.5
        snowMat.isDoubleSided = true
        snowMat.blendMode = .add

        // 2500 snowflakes scattered across the ground
        for _ in 0..<2500 {
            let x = Float(-18 + nextDouble(&rng) * 36)
            let z = Float(-12 + nextDouble(&rng) * 20)
            let size = CGFloat(0.01 + nextDouble(&rng) * 0.025)

            let flake = SCNPlane(width: size, height: size)
            flake.firstMaterial = snowMat

            let node = SCNNode(geometry: flake)
            node.position = SCNVector3(x, Float(0.005 + nextDouble(&rng) * 0.02), z)

            // Lie flat on ground
            node.eulerAngles = SCNVector3(CGFloat(-Float.pi / 2), 0, CGFloat(nextDouble(&rng) * Double.pi * 2))

            scene.rootNode.addChildNode(node)
        }

        // Falling snowflake particles (gentle drift from above)
        let fallingSnow = SCNParticleSystem()
        fallingSnow.birthRate = 200
        fallingSnow.particleLifeSpan = 12
        fallingSnow.particleLifeSpanVariation = 4
        fallingSnow.particleSize = 0.012
        fallingSnow.particleSizeVariation = 0.008
        fallingSnow.particleColor = NSColor(red: 0.88, green: 0.92, blue: 1.0, alpha: 0.7)
        fallingSnow.emittingDirection = SCNVector3(0, -1, 0)
        fallingSnow.spreadingAngle = 25
        fallingSnow.particleVelocity = 0.15
        fallingSnow.particleVelocityVariation = 0.08
        fallingSnow.particleAngularVelocity = 0.5
        fallingSnow.particleAngularVelocityVariation = 0.3
        fallingSnow.isAffectedByGravity = false
        fallingSnow.loops = true
        fallingSnow.blendMode = .additive
        fallingSnow.emitterShape = SCNBox(width: 30, height: 0.1, length: 20, chamferRadius: 0)

        let snowEmitter = SCNNode()
        snowEmitter.position = SCNVector3(0, 12, -4)
        snowEmitter.addParticleSystem(fallingSnow)
        scene.rootNode.addChildNode(snowEmitter)
    }

    // MARK: - Frozen lake

    private func addFrozenLake(to scene: SCNScene) {
        let geo = SCNBox(width: 14, height: 0.03, length: 10, chamferRadius: 0)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.65, green: 0.78, blue: 0.92, alpha: 1)
        mat.specular.contents = NSColor(white: 0.9, alpha: 0.8)
        mat.shininess = 100
        mat.lightingModel = .blinn
        mat.transparency = 0.2
        mat.isDoubleSided = true
        geo.firstMaterial = mat
        let lakeNode = SCNNode(geometry: geo)
        lakeNode.position = SCNVector3(0, 0.015, -4)
        scene.rootNode.addChildNode(lakeNode)

        // Ice surface shimmer — reflective plane
        let shimmer = SCNPlane(width: 13.5, height: 9.5)
        let shimmerMat = SCNMaterial()
        shimmerMat.lightingModel = .blinn
        shimmerMat.diffuse.contents = NSColor(red: 0.3, green: 0.5, blue: 0.7, alpha: 0.06)
        shimmerMat.specular.contents = NSColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.4)
        shimmerMat.shininess = 120
        shimmerMat.isDoubleSided = true
        shimmerMat.blendMode = .add
        shimmer.firstMaterial = shimmerMat
        let shimmerNode = SCNNode(geometry: shimmer)
        shimmerNode.eulerAngles = SCNVector3(CGFloat(-Float.pi / 2), 0, 0)
        shimmerNode.position = SCNVector3(0, 0.04, -4)
        scene.rootNode.addChildNode(shimmerNode)
    }

    // MARK: - Pine trees

    private func addPineTrees(to scene: SCNScene) {
        var rng = SplitMix64(seed: 4001)

        let trunkMat = SCNMaterial()
        trunkMat.diffuse.contents = NSColor(red: 0.30, green: 0.18, blue: 0.08, alpha: 1)
        trunkMat.lightingModel = .lambert

        let foliageMat = SCNMaterial()
        foliageMat.diffuse.contents = NSColor(red: 0.06, green: 0.22, blue: 0.10, alpha: 1)
        foliageMat.lightingModel = .lambert

        // Snow cap on trees
        let snowCapMat = SCNMaterial()
        snowCapMat.diffuse.contents = NSColor(red: 0.85, green: 0.90, blue: 0.95, alpha: 0.7)
        snowCapMat.lightingModel = .blinn
        snowCapMat.specular.contents = NSColor(white: 0.5, alpha: 0.3)

        for _ in 0..<14 {
            let x = Float(-9 + nextDouble(&rng) * 18)
            let z = Float(-2 + nextDouble(&rng) * 5)
            let scale = Float(0.6 + nextDouble(&rng) * 0.7)

            let treeNode = SCNNode()
            treeNode.position = SCNVector3(x, 0, z)

            // Trunk
            let trunk = SCNCylinder(radius: CGFloat(0.10 * scale), height: CGFloat(0.7 * scale))
            trunk.firstMaterial = trunkMat
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(0, 0.35 * scale, 0)
            treeNode.addChildNode(trunkNode)

            // Foliage — two stacked cones for fullness
            for (coneScale, yOff) in [(1.0, 0.7), (0.75, 1.5)] as [(Float, Float)] {
                let cone = SCNCone(
                    topRadius: 0,
                    bottomRadius: CGFloat(0.7 * scale * coneScale),
                    height: CGFloat(2.2 * scale * coneScale))
                cone.firstMaterial = foliageMat
                let coneNode = SCNNode(geometry: cone)
                coneNode.position = SCNVector3(0, (yOff + 1.1 * coneScale) * scale, 0)
                treeNode.addChildNode(coneNode)
            }

            // Snow cap on top
            let cap = SCNCone(topRadius: 0, bottomRadius: CGFloat(0.5 * scale), height: CGFloat(0.4 * scale))
            cap.firstMaterial = snowCapMat
            let capNode = SCNNode(geometry: cap)
            capNode.position = SCNVector3(0, (2.6 + 0.2) * scale, 0)
            treeNode.addChildNode(capNode)

            scene.rootNode.addChildNode(treeNode)
        }
    }

    // MARK: - Aurora curtains (THE BLOCKY PANELS — preserved as contrast)

    private func addAuroraCurtains(to scene: SCNScene, coord: Coordinator) {
        let configs: [(pos: SCNVector3, color: NSColor, w: CGFloat, h: CGFloat)] = [
            (SCNVector3(-2, 7, -20),  NSColor(red: 0.0, green: 0.85, blue: 0.40, alpha: 1), 14, 6),
            (SCNVector3(-8, 8, -17),  NSColor(red: 0.60, green: 0.0, blue: 0.90, alpha: 1), 10, 5),
            (SCNVector3(7,  6, -18),  NSColor(red: 0.0, green: 0.70, blue: 0.75, alpha: 1), 12, 5),
            (SCNVector3(3,  9, -22),  NSColor(red: 0.30, green: 0.0, blue: 0.80, alpha: 1), 11, 4),
            (SCNVector3(-5, 5, -15),  NSColor(red: 0.0, green: 0.60, blue: 0.55, alpha: 1), 8, 3.5),
            (SCNVector3(10, 7, -19),  NSColor(red: 0.45, green: 0.0, blue: 0.70, alpha: 1), 9, 4.5),
        ]

        for (i, cfg) in configs.enumerated() {
            let geo = SCNPlane(width: cfg.w, height: cfg.h)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.black
            mat.emission.contents = cfg.color
            mat.emission.intensity = 1.0
            mat.lightingModel = .constant
            mat.transparency = 0.65
            mat.isDoubleSided = true
            mat.blendMode = .add
            mat.writesToDepthBuffer = false
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = cfg.pos
            node.renderingOrder = -10
            scene.rootNode.addChildNode(node)

            coord.auroraMaterials.append(mat)
            coord.auroraBaseColors.append(cfg.color)
            coord.auroraNodes.append(node)

            // Ripple oscillation
            let ripple = CABasicAnimation(keyPath: "position.y")
            ripple.fromValue = cfg.pos.y - 0.6
            ripple.toValue = cfg.pos.y + 0.6
            ripple.duration = 3.5 + Double(i) * 0.7
            ripple.autoreverses = true
            ripple.repeatCount = .infinity
            ripple.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(ripple, forKey: "ripple\(i)")

            // Scale shimmer
            let shimmer = CABasicAnimation(keyPath: "scale.x")
            shimmer.fromValue = Float(0.92)
            shimmer.toValue = Float(1.08)
            shimmer.duration = 2.8 + Double(i) * 0.5
            shimmer.autoreverses = true
            shimmer.repeatCount = .infinity
            shimmer.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(shimmer, forKey: "shimmer\(i)")

            // Rotation drift
            let drift = CABasicAnimation(keyPath: "eulerAngles.y")
            drift.fromValue = Float(-0.06)
            drift.toValue = Float(0.06)
            drift.duration = 5.0 + Double(i) * 1.2
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(drift, forKey: "drift\(i)")
        }
    }

    // MARK: - Aurora mist (fine particle curtains dancing through the sky)

    private func addAuroraMist(to scene: SCNScene) {
        // Multiple particle systems — each a different aurora color band
        let mistConfigs: [(y: Float, z: Float, color: NSColor, rate: CGFloat, vel: CGFloat, spread: CGFloat)] = [
            // Main green curtain mist
            (7, -18, NSColor(red: 0.05, green: 0.85, blue: 0.35, alpha: 0.5), 600, 0.8, 45),
            (8, -20, NSColor(red: 0.10, green: 0.70, blue: 0.30, alpha: 0.4), 400, 0.6, 50),
            // Purple wisps
            (9, -19, NSColor(red: 0.50, green: 0.10, blue: 0.80, alpha: 0.35), 350, 0.5, 55),
            (6, -16, NSColor(red: 0.40, green: 0.05, blue: 0.70, alpha: 0.3), 250, 0.7, 40),
            // Cyan ribbons
            (5.5, -17, NSColor(red: 0.05, green: 0.65, blue: 0.70, alpha: 0.35), 300, 0.65, 48),
            // High altitude faint green veil
            (11, -22, NSColor(red: 0.08, green: 0.55, blue: 0.25, alpha: 0.2), 500, 0.4, 60),
            // Low altitude green glow
            (4.5, -14, NSColor(red: 0.06, green: 0.50, blue: 0.30, alpha: 0.25), 200, 0.5, 35),
        ]

        for (i, cfg) in mistConfigs.enumerated() {
            let mist = SCNParticleSystem()
            mist.birthRate = cfg.rate
            mist.particleLifeSpan = 6.0
            mist.particleLifeSpanVariation = 2.5
            mist.particleSize = 0.18
            mist.particleSizeVariation = 0.10
            mist.particleColor = cfg.color
            mist.particleColorVariation = SCNVector4(0.08, 0.12, 0.08, 0)
            mist.emittingDirection = SCNVector3(1, 0.2, 0.3)
            mist.spreadingAngle = cfg.spread
            mist.particleVelocity = cfg.vel
            mist.particleVelocityVariation = cfg.vel * 0.4
            mist.particleAngularVelocity = 0.3
            mist.particleAngularVelocityVariation = 0.2
            mist.isAffectedByGravity = false
            mist.dampingFactor = 0.15
            mist.loops = true
            mist.blendMode = .additive
            mist.emitterShape = SCNBox(width: 20, height: 2.0, length: 3.0, chamferRadius: 0)
            mist.particleImage = nil

            let emitter = SCNNode()
            emitter.position = SCNVector3(Float(i % 2 == 0 ? -12 : -8), cfg.y, cfg.z)
            emitter.addParticleSystem(mist)
            scene.rootNode.addChildNode(emitter)
        }
    }

    // MARK: - Star field

    private func addStarField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 4002)

        let starMat = SCNMaterial()
        starMat.lightingModel = .constant
        starMat.isDoubleSided = true
        starMat.blendMode = .add

        for _ in 0..<180 {
            let theta = nextDouble(&rng) * Double.pi * 2
            let phi = nextDouble(&rng) * Double.pi * 0.45
            let r = 22 + nextDouble(&rng) * 8
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(abs(r * cos(phi))) + 5
            let z = Float(r * sin(phi) * sin(theta)) - 10

            let brightness = 0.3 + nextDouble(&rng) * 0.7
            let size = CGFloat(0.02 + nextDouble(&rng) * 0.04)

            let m = starMat.copy() as! SCNMaterial
            m.emission.contents = NSColor(white: brightness, alpha: 1)
            m.diffuse.contents = NSColor(white: brightness * 0.3, alpha: 1)

            let star = SCNPlane(width: size, height: size)
            star.firstMaterial = m

            let node = SCNNode(geometry: star)
            node.position = SCNVector3(x, y, z)
            let bill = SCNBillboardConstraint()
            bill.freeAxes = .all
            node.constraints = [bill]
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Moon

    private func addMoon(to scene: SCNScene) {
        let geo = SCNSphere(radius: 1.0)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.92, green: 0.92, blue: 0.96, alpha: 1)
        mat.emission.contents = NSColor(red: 0.75, green: 0.78, blue: 0.85, alpha: 1)
        mat.emission.intensity = 0.8
        mat.lightingModel = .constant
        geo.firstMaterial = mat
        let moonNode = SCNNode(geometry: geo)
        moonNode.position = SCNVector3(9, 18, -22)
        scene.rootNode.addChildNode(moonNode)

        // Moon glow halo
        let halo = SCNPlane(width: 4, height: 4)
        let haloMat = SCNMaterial()
        haloMat.lightingModel = .constant
        haloMat.diffuse.contents = NSColor(red: 0.70, green: 0.75, blue: 0.90, alpha: 0.08)
        haloMat.emission.contents = NSColor(red: 0.50, green: 0.55, blue: 0.70, alpha: 0.06)
        haloMat.isDoubleSided = true
        haloMat.blendMode = .add
        haloMat.writesToDepthBuffer = false
        halo.firstMaterial = haloMat
        let haloNode = SCNNode(geometry: halo)
        haloNode.position = SCNVector3(9, 18, -21.5)
        let bill = SCNBillboardConstraint()
        bill.freeAxes = .all
        haloNode.constraints = [bill]
        scene.rootNode.addChildNode(haloNode)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 65
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 80
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 0.4
        cameraNode.camera!.bloomThreshold = 0.6
        cameraNode.camera!.bloomBlurRadius = 8
        cameraNode.camera!.vignettingIntensity = 0.3
        cameraNode.camera!.vignettingPower = 1.2
        cameraNode.camera!.wantsDepthOfField = true
        cameraNode.camera!.focusDistance = 8
        cameraNode.camera!.fStop = 4.0
        cameraNode.camera!.apertureBladeCount = 6
        cameraNode.position = SCNVector3(0, 3.5, 10)
        cameraNode.eulerAngles = SCNVector3(CGFloat(-Float.pi / 10), 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Slow panoramic sweep
        cameraNode.runAction(.repeatForever(.customAction(duration: 150) { n, t in
            let elapsed = Double(t)
            let x = 5.0 * sin(elapsed * 0.042)
            let y = 3.5 + 0.5 * sin(elapsed * 0.028)
            let yaw = 0.08 * sin(elapsed * 0.035)
            let pitch = -Float.pi / 10 + 0.03 * Float(sin(elapsed * 0.022))
            n.position = SCNVector3(CGFloat(x), CGFloat(y), 10)
            n.eulerAngles = SCNVector3(CGFloat(pitch), CGFloat(yaw), 0)
        }))
    }
}
