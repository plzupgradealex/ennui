import SwiftUI
import SceneKit

// Quiet Meal 3D — You stand on a wet sidewalk outside a small restaurant at dusk.
// Through the plate-glass window you see two friends at a table under a warm hanging
// lamp. Bowls of food, water glasses, a neon OPEN sign in the corner. An awning
// overhead. Rain slides down the glass. They don't notice you. They don't need to.

struct QuietMeal3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { QuietMeal3DRepresentable(interaction: interaction) }
}

private struct QuietMeal3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var rainSystem: SCNParticleSystem?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)
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
        guard let rain = c.rainSystem else { return }
        rain.birthRate = 400
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            rain.birthRate = 60
        }
    }

    // MARK: - Helpers

    private func mat(_ r: Double, _ g: Double, _ b: Double, emission: NSColor? = nil, lit: Bool = true) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = NSColor(red: r, green: g, blue: b, alpha: 1)
        m.lightingModel = lit ? .blinn : .constant
        if let e = emission { m.emission.contents = e }
        return m
    }

    private func addBox(_ scene: SCNScene, w: CGFloat, h: CGFloat, l: CGFloat, x: Float, y: Float, z: Float, m: SCNMaterial, chamfer: CGFloat = 0.005) {
        let geo = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer)
        geo.firstMaterial = m
        let n = SCNNode(geometry: geo)
        n.position = SCNVector3(x, y, z)
        scene.rootNode.addChildNode(n)
    }

    // MARK: - Build

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        let root = scene.rootNode
        var rng = SplitMix64(seed: 2024)

        // ── Exterior wall (dark brick) ──
        let brickMat = mat(0.18, 0.14, 0.12)
        // Left wall panel
        addBox(scene, w: 1.6, h: 3.5, l: 0.15, x: -2.0, y: 0.75, z: 0, m: brickMat)
        // Right wall panel
        addBox(scene, w: 1.6, h: 3.5, l: 0.15, x: 2.0, y: 0.75, z: 0, m: brickMat)
        // Wall above window
        addBox(scene, w: 2.8, h: 0.8, l: 0.15, x: 0, y: 2.3, z: 0, m: brickMat)
        // Wall below window (knee wall)
        addBox(scene, w: 2.8, h: 0.6, l: 0.15, x: 0, y: -0.6, z: 0, m: brickMat)

        // ── Window frame (dark metal) ──
        let frameMat = mat(0.14, 0.14, 0.16)
        let frameD: Float = 0.04
        // Top frame
        addBox(scene, w: 2.65, h: 0.08, l: 0.1, x: 0, y: 1.88, z: Float(frameD), m: frameMat)
        // Bottom frame
        addBox(scene, w: 2.65, h: 0.08, l: 0.1, x: 0, y: -0.28, z: Float(frameD), m: frameMat)
        // Left frame
        addBox(scene, w: 0.08, h: 2.24, l: 0.1, x: -1.28, y: 0.8, z: Float(frameD), m: frameMat)
        // Right frame
        addBox(scene, w: 0.08, h: 2.24, l: 0.1, x: 1.28, y: 0.8, z: Float(frameD), m: frameMat)
        // Center vertical mullion
        addBox(scene, w: 0.05, h: 2.16, l: 0.1, x: 0, y: 0.8, z: Float(frameD), m: frameMat)

        // ── Interior — back wall ──
        let backWallMat = mat(0.42, 0.38, 0.32,
                              emission: NSColor(red: 0.12, green: 0.10, blue: 0.06, alpha: 1))
        addBox(scene, w: 3.2, h: 3.0, l: 0.1, x: 0, y: 0.5, z: -2.5, m: backWallMat)

        // Interior side walls (warm shadow)
        let sideWallMat = mat(0.32, 0.28, 0.22,
                              emission: NSColor(red: 0.06, green: 0.04, blue: 0.02, alpha: 1))
        addBox(scene, w: 0.1, h: 3.0, l: 2.5, x: -1.5, y: 0.5, z: -1.25, m: sideWallMat)
        addBox(scene, w: 0.1, h: 3.0, l: 2.5, x: 1.5, y: 0.5, z: -1.25, m: sideWallMat)

        // Interior floor
        let floorMat = mat(0.22, 0.18, 0.15,
                           emission: NSColor(red: 0.04, green: 0.03, blue: 0.02, alpha: 1))
        addBox(scene, w: 3.2, h: 0.05, l: 2.8, x: 0, y: -0.9, z: -1.2, m: floorMat)

        // Interior ceiling
        let ceilMat = mat(0.38, 0.35, 0.30)
        addBox(scene, w: 3.2, h: 0.05, l: 2.8, x: 0, y: 2.0, z: -1.2, m: ceilMat)

        // ── Table ──
        let tableMat = mat(0.40, 0.28, 0.16)
        addBox(scene, w: 1.0, h: 0.06, l: 0.55, x: 0, y: 0.0, z: -1.4, m: tableMat)
        // Table legs
        for lx in [-0.4, 0.4] as [Float] {
            for lz in [-1.2, -1.6] as [Float] {
                addBox(scene, w: 0.04, h: 0.85, l: 0.04, x: lx, y: -0.45, z: lz, m: tableMat, chamfer: 0)
            }
        }

        // ── Food on table ──
        let bowlWhite = mat(0.92, 0.90, 0.86)
        let brothAmber = mat(0.70, 0.40, 0.15,
                             emission: NSColor(red: 0.30, green: 0.15, blue: 0.05, alpha: 0.5))

        for bx in [-0.25, 0.25] as [Float] {
            // Bowl
            let bowl = SCNCylinder(radius: 0.10, height: 0.07)
            bowl.firstMaterial = bowlWhite
            let bowlNode = SCNNode(geometry: bowl)
            bowlNode.position = SCNVector3(bx, 0.07, -1.4)
            root.addChildNode(bowlNode)

            // Food inside
            let food = SCNCylinder(radius: 0.08, height: 0.02)
            food.firstMaterial = brothAmber
            let foodNode = SCNNode(geometry: food)
            foodNode.position = SCNVector3(bx, 0.09, -1.4)
            root.addChildNode(foodNode)

            // Steam wisps (tiny particle system per bowl)
            let steam = SCNParticleSystem()
            steam.birthRate = 6
            steam.particleLifeSpan = 2.5
            steam.particleSize = 0.03
            steam.particleSizeVariation = 0.015
            steam.particleColor = NSColor(red: 0.95, green: 0.90, blue: 0.80, alpha: 0.12)
            steam.emittingDirection = SCNVector3(0, 1, 0)
            steam.spreadingAngle = 15
            steam.particleVelocity = 0.04
            steam.particleVelocityVariation = 0.01
            steam.isAffectedByGravity = false
            steam.loops = true
            steam.blendMode = .additive
            let steamNode = SCNNode()
            steamNode.position = SCNVector3(bx, 0.12, -1.4)
            steamNode.addParticleSystem(steam)
            root.addChildNode(steamNode)
        }

        // Water glasses
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents = NSColor(red: 0.60, green: 0.75, blue: 0.88, alpha: 0.3)
        glassMat.lightingModel = .blinn
        glassMat.transparency = 0.5
        for gx in [-0.05, 0.42] as [Float] {
            let glass = SCNCylinder(radius: 0.025, height: 0.09)
            glass.firstMaterial = glassMat
            let glassNode = SCNNode(geometry: glass)
            glassNode.position = SCNVector3(gx, 0.08, -1.3)
            root.addChildNode(glassNode)
        }

        // ── Two friends (simplified figures) ──
        buildFriend(scene, x: -0.35, z: -1.7, shirtR: 0.30, shirtG: 0.35, shirtB: 0.52,
                    hairR: 0.12, hairG: 0.10, hairB: 0.08, gesture: true)
        buildFriend(scene, x: 0.35, z: -1.1, shirtR: 0.48, shirtG: 0.32, shirtB: 0.28,
                    hairR: 0.08, hairG: 0.06, hairB: 0.05, gesture: false)

        // ── Chairs ──
        let chairMat = mat(0.18, 0.13, 0.09)
        for cx in [-0.35, 0.35] as [Float] {
            let cz: Float = cx < 0 ? -1.7 : -1.1
            // Seat
            addBox(scene, w: 0.30, h: 0.04, l: 0.30, x: cx, y: -0.40, z: cz, m: chairMat)
            // Chair legs
            for lx2 in [-0.12, 0.12] as [Float] {
                for lz2 in [-0.12, 0.12] as [Float] {
                    addBox(scene, w: 0.03, h: 0.48, l: 0.03, x: cx + lx2, y: -0.66, z: cz + lz2, m: chairMat, chamfer: 0)
                }
            }
            // Chair back
            addBox(scene, w: 0.30, h: 0.35, l: 0.03, x: cx, y: -0.17, z: cz + (cx < 0 ? -0.14 : 0.14), m: chairMat)
        }

        // ── Hanging lamp ──
        let lampShade = SCNCylinder(radius: 0.12, height: 0.08)
        let lampShadeMat = mat(0.15, 0.12, 0.08,
                               emission: NSColor(red: 0.55, green: 0.40, blue: 0.20, alpha: 0.4))
        lampShade.firstMaterial = lampShadeMat
        let lampShadeNode = SCNNode(geometry: lampShade)
        lampShadeNode.position = SCNVector3(0, 1.3, -1.4)
        root.addChildNode(lampShadeNode)

        // Lamp cord
        addBox(scene, w: 0.01, h: 0.65, l: 0.01, x: 0, y: 1.65, z: -1.4, m: mat(0.1, 0.1, 0.1), chamfer: 0)

        // Lamp bulb (warm glow sphere)
        let bulb = SCNSphere(radius: 0.04)
        let bulbMat = mat(1.0, 0.82, 0.45,
                          emission: NSColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 1.0))
        bulb.firstMaterial = bulbMat
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(0, 1.24, -1.4)
        root.addChildNode(bulbNode)

        // ── OPEN neon sign ──
        let signBacking = SCNBox(width: 0.30, height: 0.10, length: 0.02, chamferRadius: 0.005)
        signBacking.firstMaterial = mat(0.05, 0.05, 0.07, lit: false)
        let signNode = SCNNode(geometry: signBacking)
        signNode.position = SCNVector3(0.85, 0.6, -0.15)
        root.addChildNode(signNode)

        // Neon letters (simplified as glowing boxes)
        let neonMat = mat(1.0, 0.25, 0.18,
                          emission: NSColor(red: 1.2, green: 0.3, blue: 0.2, alpha: 1.0), lit: false)
        let letterWidth: CGFloat = 0.05
        let letterHeight: CGFloat = 0.06
        let startX: Float = 0.73
        for (i, _) in ["O", "P", "E", "N"].enumerated() {
            let lx = startX + Float(i) * 0.07
            let letter = SCNBox(width: letterWidth, height: letterHeight, length: 0.01, chamferRadius: 0.002)
            letter.firstMaterial = neonMat
            let ln = SCNNode(geometry: letter)
            ln.position = SCNVector3(lx, 0.6, -0.13)
            root.addChildNode(ln)
        }
        // Neon glow light
        let neonLight = SCNLight()
        neonLight.type = .omni
        neonLight.color = NSColor(red: 1.0, green: 0.25, blue: 0.15, alpha: 1)
        neonLight.intensity = 40
        neonLight.attenuationStartDistance = 0.1
        neonLight.attenuationEndDistance = 1.0
        let neonLightNode = SCNNode()
        neonLightNode.light = neonLight
        neonLightNode.position = SCNVector3(0.85, 0.6, -0.05)
        root.addChildNode(neonLightNode)

        // ── Awning ──
        let awningMat = mat(0.35, 0.14, 0.10,
                            emission: NSColor(red: 0.08, green: 0.03, blue: 0.02, alpha: 1))
        let awning = SCNBox(width: 3.2, height: 0.04, length: 0.6, chamferRadius: 0.01)
        awning.firstMaterial = awningMat
        let awningNode = SCNNode(geometry: awning)
        awningNode.position = SCNVector3(0, 2.05, 0.3)
        awningNode.eulerAngles.x = CGFloat(Float.pi * 0.06) // slight tilt
        root.addChildNode(awningNode)

        // Awning support brackets
        for bx in [-1.2, 1.2] as [Float] {
            let bracket = SCNBox(width: 0.03, height: 0.25, length: 0.03, chamferRadius: 0)
            bracket.firstMaterial = mat(0.12, 0.12, 0.14)
            let bn = SCNNode(geometry: bracket)
            bn.position = SCNVector3(bx, 2.02, 0.12)
            bn.eulerAngles.x = CGFloat(Float.pi * 0.15)
            root.addChildNode(bn)
        }

        // ── Sidewalk ──
        let sidewalkMat = mat(0.20, 0.19, 0.22,
                              emission: NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1))
        addBox(scene, w: 5.0, h: 0.05, l: 3.0, x: 0, y: -0.95, z: 1.5, m: sidewalkMat)

        // Wet reflection on sidewalk (bright plane)
        let wetMat = SCNMaterial()
        wetMat.diffuse.contents = NSColor(red: 0.25, green: 0.22, blue: 0.20, alpha: 0.3)
        wetMat.emission.contents = NSColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 0.15)
        wetMat.lightingModel = .blinn
        wetMat.specular.contents = NSColor(red: 0.8, green: 0.7, blue: 0.5, alpha: 0.4)
        wetMat.shininess = 0.8
        let wetPlane = SCNPlane(width: 2.8, height: 2.0)
        wetPlane.firstMaterial = wetMat
        let wetNode = SCNNode(geometry: wetPlane)
        wetNode.eulerAngles.x = CGFloat(-Float.pi / 2)
        wetNode.position = SCNVector3(0, -0.91, 1.8)
        root.addChildNode(wetNode)

        // ── Glass pane (faintly visible, reacts to light) ──
        let glassPaneMat = SCNMaterial()
        glassPaneMat.diffuse.contents = NSColor(red: 0.30, green: 0.38, blue: 0.50, alpha: 0.08)
        glassPaneMat.lightingModel = .blinn
        glassPaneMat.specular.contents = NSColor(red: 0.6, green: 0.7, blue: 0.9, alpha: 0.3)
        glassPaneMat.shininess = 0.9
        glassPaneMat.transparency = 0.92
        glassPaneMat.isDoubleSided = true
        let pane = SCNPlane(width: 2.5, height: 2.12)
        pane.firstMaterial = glassPaneMat
        let paneNode = SCNNode(geometry: pane)
        paneNode.position = SCNVector3(0, 0.8, 0.03)
        root.addChildNode(paneNode)

        // ── Rain on glass ──
        let rain = SCNParticleSystem()
        rain.birthRate = 60
        rain.particleLifeSpan = 2.0
        rain.particleLifeSpanVariation = 0.5
        rain.particleSize = 0.008
        rain.particleSizeVariation = 0.004
        rain.particleColor = NSColor(red: 0.60, green: 0.70, blue: 0.90, alpha: 0.45)
        rain.emittingDirection = SCNVector3(0, -1, 0)
        rain.spreadingAngle = 5
        rain.particleVelocity = 0.6
        rain.particleVelocityVariation = 0.2
        rain.isAffectedByGravity = false
        rain.loops = true
        rain.blendMode = .additive
        rain.emitterShape = SCNBox(width: 2.4, height: 0.01, length: 0.01, chamferRadius: 0)
        coord.rainSystem = rain
        let rainNode = SCNNode()
        rainNode.position = SCNVector3(0, 1.9, 0.04)
        rainNode.addParticleSystem(rain)
        root.addChildNode(rainNode)

        // ── Background rain (falling in the street behind you) ──
        let bgRain = SCNParticleSystem()
        bgRain.birthRate = 120
        bgRain.particleLifeSpan = 1.5
        bgRain.particleSize = 0.005
        bgRain.particleColor = NSColor(red: 0.50, green: 0.55, blue: 0.70, alpha: 0.2)
        bgRain.emittingDirection = SCNVector3(0, -1, 0)
        bgRain.spreadingAngle = 8
        bgRain.particleVelocity = 2.5
        bgRain.isAffectedByGravity = false
        bgRain.loops = true
        bgRain.emitterShape = SCNBox(width: 5.0, height: 0.01, length: 3.0, chamferRadius: 0)
        let bgRainNode = SCNNode()
        bgRainNode.position = SCNVector3(0, 4.0, 1.5)
        bgRainNode.addParticleSystem(bgRain)
        root.addChildNode(bgRainNode)

        // ── Condensation dots on glass edges ──
        let condensMat = mat(0.80, 0.85, 0.90,
                             emission: NSColor(red: 0.20, green: 0.22, blue: 0.25, alpha: 0.08), lit: false)
        for _ in 0..<50 {
            let edge = Int(nextDouble(&rng) * 4)
            var cx: Float = 0; var cy: Float = 0
            switch edge {
            case 0: cx = Float(-1.2 + nextDouble(&rng) * 2.4); cy = Float(1.7 + nextDouble(&rng) * 0.15)
            case 1: cx = Float(-1.2 + nextDouble(&rng) * 2.4); cy = Float(-0.15 + nextDouble(&rng) * 0.15)
            case 2: cx = Float(-1.2 + nextDouble(&rng) * 0.15); cy = Float(-0.1 + nextDouble(&rng) * 1.9)
            default: cx = Float(1.05 + nextDouble(&rng) * 0.15); cy = Float(-0.1 + nextDouble(&rng) * 1.9)
            }
            let dotR = CGFloat(0.008 + nextDouble(&rng) * 0.012)
            let dot = SCNSphere(radius: dotR)
            dot.firstMaterial = condensMat
            let dn = SCNNode(geometry: dot)
            dn.position = SCNVector3(cx, cy, 0.04)
            root.addChildNode(dn)
        }

        // ── Lighting ──

        // Main interior warm light (from the hanging lamp)
        let warmLight = SCNLight()
        warmLight.type = .omni
        warmLight.color = NSColor(red: 1.0, green: 0.72, blue: 0.38, alpha: 1)
        warmLight.intensity = 400
        warmLight.attenuationStartDistance = 0.5
        warmLight.attenuationEndDistance = 5.0
        warmLight.castsShadow = true
        warmLight.shadowMode = .deferred
        warmLight.shadowRadius = 4
        warmLight.shadowSampleCount = 8
        let warmLightNode = SCNNode()
        warmLightNode.light = warmLight
        warmLightNode.position = SCNVector3(0, 1.2, -1.4)
        root.addChildNode(warmLightNode)

        // Secondary fill light inside (dimmer, higher)
        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.color = NSColor(red: 0.90, green: 0.80, blue: 0.60, alpha: 1)
        fillLight.intensity = 120
        fillLight.attenuationStartDistance = 0.5
        fillLight.attenuationEndDistance = 4.0
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.position = SCNVector3(0, 1.8, -1.0)
        root.addChildNode(fillNode)

        // Cool ambient for exterior (blue dusk)
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = NSColor(red: 0.06, green: 0.07, blue: 0.14, alpha: 1)
        ambient.intensity = 200
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        root.addChildNode(ambientNode)

        // Subtle directional from above (moonlight/street light)
        let moonDir = SCNLight()
        moonDir.type = .directional
        moonDir.color = NSColor(red: 0.25, green: 0.30, blue: 0.45, alpha: 1)
        moonDir.intensity = 80
        let moonNode = SCNNode()
        moonNode.light = moonDir
        moonNode.eulerAngles = SCNVector3(-Float.pi * 0.4, Float.pi * 0.1, 0)
        root.addChildNode(moonNode)

        // ── Camera ──
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 50
        cameraNode.camera?.fieldOfView = 50
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.bloomIntensity = 0.3
        cameraNode.camera?.bloomBlurRadius = 6
        cameraNode.camera?.bloomThreshold = 0.7
        cameraNode.camera?.wantsDepthOfField = true
        cameraNode.camera?.focusDistance = 3.0
        cameraNode.camera?.fStop = 2.8
        cameraNode.camera?.apertureBladeCount = 6
        cameraNode.camera?.vignettingIntensity = 0.4
        cameraNode.camera?.vignettingPower = 1.2
        // Position: standing on sidewalk looking at window, slightly off-center
        cameraNode.position = SCNVector3(0.15, 0.55, 2.8)
        root.addChildNode(cameraNode)

        let lookTarget = SCNNode()
        lookTarget.position = SCNVector3(0, 0.6, -0.5)
        root.addChildNode(lookTarget)
        let lookAt = SCNLookAtConstraint(target: lookTarget)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        // Gentle breathing sway
        let swayUp = SCNAction.moveBy(x: 0, y: 0.015, z: 0, duration: 6.0)
        swayUp.timingMode = .easeInEaseOut
        let swayDown = SCNAction.moveBy(x: 0, y: -0.015, z: 0, duration: 6.0)
        swayDown.timingMode = .easeInEaseOut
        cameraNode.runAction(.repeatForever(.sequence([swayUp, swayDown])))

        // ── Fog ──
        scene.fogStartDistance = 4.0
        scene.fogEndDistance = 10.0
        scene.fogColor = NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)
        scene.fogDensityExponent = 1.5
    }

    // MARK: - Friend builder

    private func buildFriend(_ scene: SCNScene, x: Float, z: Float,
                              shirtR: Double, shirtG: Double, shirtB: Double,
                              hairR: Double, hairG: Double, hairB: Double,
                              gesture: Bool) {
        let root = scene.rootNode
        let skinMat = mat(0.82, 0.68, 0.52)
        let shirtMat = mat(shirtR, shirtG, shirtB)
        let hairMat = mat(hairR, hairG, hairB)

        // Torso (box)
        let torso = SCNBox(width: 0.22, height: 0.35, length: 0.15, chamferRadius: 0.02)
        torso.firstMaterial = shirtMat
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(x, 0.12, z)
        root.addChildNode(torsoNode)

        // Head (sphere)
        let head = SCNSphere(radius: 0.09)
        head.firstMaterial = skinMat
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(x, 0.42, z)
        root.addChildNode(headNode)

        // Hair cap (flattened sphere on top)
        let hair = SCNSphere(radius: 0.095)
        hair.firstMaterial = hairMat
        let hairNode = SCNNode(geometry: hair)
        hairNode.position = SCNVector3(x, 0.45, z)
        hairNode.scale = SCNVector3(1.0, 0.5, 1.0)
        root.addChildNode(hairNode)

        // Arms (thin boxes reaching toward table)
        let armMat = shirtMat
        if gesture {
            // Gesturing arm — angled up slightly
            let arm = SCNBox(width: 0.25, height: 0.06, length: 0.06, chamferRadius: 0.01)
            arm.firstMaterial = armMat
            let armNode = SCNNode(geometry: arm)
            armNode.position = SCNVector3(x + 0.18, 0.10, z + 0.08)
            armNode.eulerAngles.z = CGFloat(-Float.pi * 0.12)
            root.addChildNode(armNode)

            // Gentle gesture animation
            let up = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(Float.pi * 0.04), duration: 2.5)
            up.timingMode = .easeInEaseOut
            let down = SCNAction.rotateBy(x: 0, y: 0, z: CGFloat(-Float.pi * 0.04), duration: 2.5)
            down.timingMode = .easeInEaseOut
            armNode.runAction(.repeatForever(.sequence([up, down])))
        } else {
            // Resting arm
            let arm = SCNBox(width: 0.22, height: 0.06, length: 0.06, chamferRadius: 0.01)
            arm.firstMaterial = armMat
            let armNode = SCNNode(geometry: arm)
            armNode.position = SCNVector3(x - 0.12, 0.05, z - 0.06)
            root.addChildNode(armNode)

            // Subtle head bob (laughing)
            let bobUp = SCNAction.moveBy(x: 0, y: 0.01, z: 0, duration: 1.8)
            bobUp.timingMode = .easeInEaseOut
            let bobDown = SCNAction.moveBy(x: 0, y: -0.01, z: 0, duration: 1.8)
            bobDown.timingMode = .easeInEaseOut
            let pause = SCNAction.wait(duration: 3.0)
            headNode.runAction(.repeatForever(.sequence([bobUp, bobDown, pause])))
        }
    }
}
