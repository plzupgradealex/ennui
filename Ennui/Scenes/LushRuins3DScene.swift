import SwiftUI
import SceneKit

struct LushRuins3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { LushRuins3DRepresentable(interaction: interaction) }
}

private struct LushRuins3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var scene: SCNScene?
        var butterflies: [SCNNode] = []
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        context.coordinator.scene = scene
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.04, blue: 0.02, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        // Butterfly particle burst on tap
        guard let scene = c.scene else { return }
        let burstNode = SCNNode()
        let tapPos = interaction.tapLocation ?? CGPoint(x: 0.5, y: 0.5)
        burstNode.position = SCNVector3(
            Float(tapPos.x - 0.5) * 4,
            1.5,
            Float(0.5 - tapPos.y) * 4
        )
        scene.rootNode.addChildNode(burstNode)
        let burst = SCNParticleSystem()
        burst.birthRate = 80
        burst.particleLifeSpan = 1.5
        burst.particleSize = 0.06
        burst.emissionDuration = 0.3
        burst.spreadingAngle = 160
        burst.particleVelocity = 2.5
        burst.particleColor = NSColor.systemPink
        burst.isAffectedByGravity = true
        burst.loops = false
        burstNode.addParticleSystem(burst)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            burstNode.removeFromParentNode()
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.05
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.05, green: 0.15, blue: 0.05, alpha: 1)
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        // Temple pyramid: 4 stacked slabs
        let slabSizes: [(Float, Float, Float)] = [(4, 0.3, 4), (3, 0.3, 3), (2, 0.3, 2), (1, 0.3, 1)]
        let slabYPositions: [Float] = [0.15, 0.45, 0.75, 1.05]
        let stoneColor = NSColor(red: 0.35, green: 0.32, blue: 0.25, alpha: 1)
        for (i, size) in slabSizes.enumerated() {
            let box = SCNBox(width: CGFloat(size.0), height: CGFloat(size.1), length: CGFloat(size.2), chamferRadius: 0.02)
            box.firstMaterial?.diffuse.contents = stoneColor
            box.firstMaterial?.roughness.contents = 0.85
            let node = SCNNode(geometry: box)
            node.position = SCNVector3(0, slabYPositions[i], 0)
            scene.rootNode.addChildNode(node)
        }

        // 8 tropical trees using SplitMix64(seed:5001)
        var rng = SplitMix64(seed: 5001)
        let trunkColor = NSColor(red: 0.28, green: 0.18, blue: 0.08, alpha: 1)
        let canopyColor = NSColor(red: 0.05, green: 0.28, blue: 0.07, alpha: 1)
        for _ in 0..<8 {
            let x = Float(rng.nextDouble()) * 12 - 6
            let z = Float(rng.nextDouble()) * 6 - 2

            let trunk = SCNCylinder(radius: 0.12, height: 2.5)
            trunk.firstMaterial?.diffuse.contents = trunkColor
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(x, 1.25, z)
            scene.rootNode.addChildNode(trunkNode)

            let canopy = SCNSphere(radius: 0.9)
            canopy.firstMaterial?.diffuse.contents = canopyColor
            let canopyNode = SCNNode(geometry: canopy)
            canopyNode.position = SCNVector3(x, 2.85, z)
            scene.rootNode.addChildNode(canopyNode)
        }

        // Waterfall plane
        let waterfall = SCNPlane(width: 0.6, height: 3)
        waterfall.firstMaterial?.diffuse.contents = NSColor.white
        waterfall.firstMaterial?.transparency = 0.7
        waterfall.firstMaterial?.isDoubleSided = true
        let waterfallNode = SCNNode(geometry: waterfall)
        waterfallNode.position = SCNVector3(-5, 1.5, -3)
        scene.rootNode.addChildNode(waterfallNode)

        // Waterfall falling particles
        let waterParticles = SCNParticleSystem()
        waterParticles.birthRate = 120
        waterParticles.particleLifeSpan = 1.2
        waterParticles.particleSize = 0.03
        waterParticles.particleVelocity = 3.0
        waterParticles.particleVelocityVariation = 0.3
        waterParticles.particleColor = NSColor.white
        waterParticles.emittingDirection = SCNVector3(0, -1, 0)
        waterParticles.spreadingAngle = 8
        waterParticles.isAffectedByGravity = false
        waterParticles.loops = true
        waterfallNode.addParticleSystem(waterParticles)

        // 6 butterflies with circular orbit
        let butterflyColors: [NSColor] = [
            NSColor.systemPink, NSColor.orange, NSColor.systemBlue,
            NSColor.yellow, NSColor.purple, NSColor.green
        ]
        for (i, color) in butterflyColors.enumerated() {
            let wing = SCNBox(width: 0.15, height: 0.1, length: 0.01, chamferRadius: 0)
            wing.firstMaterial?.diffuse.contents = color
            wing.firstMaterial?.emission.contents = color.withAlphaComponent(0.6)
            let butterflyNode = SCNNode(geometry: wing)
            let angle = CGFloat(i) * CGFloat.pi * 2 / 6
            let radius: CGFloat = 2.5
            butterflyNode.position = SCNVector3(
                cos(angle) * radius,
                1.5 + CGFloat(i) * 0.15,
                sin(angle) * radius
            )
            scene.rootNode.addChildNode(butterflyNode)
            coord.butterflies.append(butterflyNode)

            let orbitDuration = Double(7 + i) * 0.8
            let orbit = SCNAction.repeatForever(
                SCNAction.customAction(duration: orbitDuration) { node, elapsed in
                    let t = CGFloat(elapsed / orbitDuration) * CGFloat.pi * 2
                    let cx = cos(t + angle) * radius
                    let cy: CGFloat = 1.5 + sin(t * 2) * 0.3 + CGFloat(i) * 0.15
                    let cz = sin(t + angle) * radius
                    node.position = SCNVector3(cx, cy, cz)
                    node.eulerAngles.y = -(t + angle)
                }
            )
            butterflyNode.runAction(orbit)
        }

        // Ambient light (warm tropical)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.2, green: 0.28, blue: 0.15, alpha: 1)
        ambientLight.intensity = 400
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Directional warm light from above
        let dirLight = SCNLight()
        dirLight.type = .directional
        dirLight.color = NSColor(red: 0.9, green: 0.8, blue: 0.5, alpha: 1)
        dirLight.intensity = 800
        let dirNode = SCNNode()
        dirNode.light = dirLight
        dirNode.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 4, 0)
        scene.rootNode.addChildNode(dirNode)

        // Camera orbiting
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 100
        cameraNode.position = SCNVector3(8, 4, 8)
        scene.rootNode.addChildNode(cameraNode)

        let lookAt = SCNLookAtConstraint(target: floorNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        let orbit = SCNAction.repeatForever(
            SCNAction.customAction(duration: 100) { node, elapsed in
                let angle = Float(elapsed / 100) * Float.pi * 2
                let r: Float = 10
                node.position = SCNVector3(cos(angle) * r, 4, sin(angle) * r)
            }
        )
        cameraNode.runAction(orbit)
    }
}
