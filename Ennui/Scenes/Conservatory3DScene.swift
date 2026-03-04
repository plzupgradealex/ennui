import SwiftUI
import SceneKit

struct Conservatory3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { Conservatory3DRepresentable(interaction: interaction) }
}

private struct Conservatory3DRepresentable: NSViewRepresentable {
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
        view.backgroundColor = NSColor(red: 0.02, green: 0.04, blue: 0.02, alpha: 1)
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
        // Rain birthRate spike to 300 for 2s
        guard let rain = c.rainSystem else { return }
        rain.birthRate = 300
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            rain.birthRate = 80
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Ground
        let floor = SCNFloor()
        floor.reflectivity = 0.08
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1)
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        let ironColor = NSColor(red: 0.25, green: 0.27, blue: 0.28, alpha: 1)

        // 4 corner posts
        let corners: [(Float, Float)] = [(-3, -3), (3, -3), (-3, 3), (3, 3)]
        for (cx, cz) in corners {
            let post = SCNCylinder(radius: 0.05, height: 3.5)
            post.firstMaterial?.diffuse.contents = ironColor
            let postNode = SCNNode(geometry: post)
            postNode.position = SCNVector3(cx, 1.75, cz)
            scene.rootNode.addChildNode(postNode)
        }

        // Horizontal rails at heights 1, 2, 3
        let railHeights: [Float] = [1, 2, 3]
        for ry in railHeights {
            // X-axis rails
            let railX = SCNBox(width: 6, height: 0.05, length: 0.05, chamferRadius: 0)
            railX.firstMaterial?.diffuse.contents = ironColor
            for rz in [-3, 3] as [Float] {
                let node = SCNNode(geometry: railX)
                node.position = SCNVector3(0, ry, rz)
                scene.rootNode.addChildNode(node)
            }
            // Z-axis rails
            let railZ = SCNBox(width: 0.05, height: 0.05, length: 6, chamferRadius: 0)
            railZ.firstMaterial?.diffuse.contents = ironColor
            for rx in [-3, 3] as [Float] {
                let node = SCNNode(geometry: railZ)
                node.position = SCNVector3(rx, ry, 0)
                scene.rootNode.addChildNode(node)
            }
        }

        // Glass roof
        let roof = SCNPlane(width: 6, height: 6)
        roof.firstMaterial?.diffuse.contents = NSColor(red: 0.6, green: 0.7, blue: 0.75, alpha: 1)
        roof.firstMaterial?.transparency = 0.7
        roof.firstMaterial?.lightingModel = .constant
        roof.firstMaterial?.isDoubleSided = true
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(0, 3.5, 0)
        roofNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(roofNode)

        // 6 plants using SplitMix64(seed:6001)
        var rng = SplitMix64(seed: 6001)
        let potColor = NSColor(red: 0.65, green: 0.35, blue: 0.22, alpha: 1)
        let plantColor = NSColor(red: 0.12, green: 0.52, blue: 0.15, alpha: 1)
        for _ in 0..<6 {
            let x = Float(rng.nextDouble()) * 4.5 - 2.25
            let z = Float(rng.nextDouble()) * 4.5 - 2.25

            let pot = SCNCylinder(radius: 0.15, height: 0.2)
            pot.firstMaterial?.diffuse.contents = potColor
            let potNode = SCNNode(geometry: pot)
            potNode.position = SCNVector3(x, 0.1, z)
            scene.rootNode.addChildNode(potNode)

            let canopy = SCNSphere(radius: 0.4)
            canopy.firstMaterial?.diffuse.contents = plantColor
            let canopyNode = SCNNode(geometry: canopy)
            canopyNode.position = SCNVector3(x, 0.65, z)
            scene.rootNode.addChildNode(canopyNode)

            // Steam particles from each plant
            let steam = SCNParticleSystem()
            steam.birthRate = 5
            steam.particleLifeSpan = 2.0
            steam.particleSize = 0.015
            steam.particleColor = NSColor.white.withAlphaComponent(0.5)
            steam.emittingDirection = SCNVector3(0, 1, 0)
            steam.spreadingAngle = 30
            steam.particleVelocity = 0.3
            steam.isAffectedByGravity = false
            steam.loops = true
            canopyNode.addParticleSystem(steam)
        }

        // Rain particles from above
        let rain = SCNParticleSystem()
        rain.birthRate = 80
        rain.particleLifeSpan = 3.0
        rain.particleSize = 0.02
        rain.particleColor = NSColor(red: 0.7, green: 0.8, blue: 1.0, alpha: 0.7)
        rain.emittingDirection = SCNVector3(0, -1, 0)
        rain.spreadingAngle = 5
        rain.particleVelocity = 4.0
        rain.isAffectedByGravity = false
        rain.loops = true
        coord.rainSystem = rain
        let rainEmitter = SCNNode()
        rainEmitter.position = SCNVector3(0, 3.4, 0)
        rainEmitter.addParticleSystem(rain)
        scene.rootNode.addChildNode(rainEmitter)

        // Ambient light (warm green)
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.15, green: 0.25, blue: 0.12, alpha: 1)
        ambientLight.intensity = 350
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Point light from above
        let topLight = SCNLight()
        topLight.type = .omni
        topLight.color = NSColor(red: 0.95, green: 1.0, blue: 0.9, alpha: 1)
        topLight.intensity = 600
        let topLightNode = SCNNode()
        topLightNode.light = topLight
        topLightNode.position = SCNVector3(0, 3.2, 0)
        scene.rootNode.addChildNode(topLightNode)

        // Camera orbiting inside (70s)
        let pivotNode = SCNNode()
        pivotNode.position = SCNVector3(0, 1.5, 0)
        scene.rootNode.addChildNode(pivotNode)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 60
        cameraNode.camera?.fieldOfView = 70
        cameraNode.position = SCNVector3(5, 1.5, 0)
        scene.rootNode.addChildNode(cameraNode)

        let lookAt = SCNLookAtConstraint(target: pivotNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        let orbit = SCNAction.repeatForever(
            SCNAction.customAction(duration: 70) { node, elapsed in
                let angle = Float(elapsed / 70) * Float.pi * 2
                let r: Float = 5
                node.position = SCNVector3(cos(angle) * r, 1.5, sin(angle) * r)
            }
        )
        cameraNode.runAction(orbit)
    }
}
