import SwiftUI
import SceneKit

struct SaltLamp3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { SaltLamp3DRepresentable(interaction: interaction) }
}

private struct SaltLamp3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var lampLight: SCNNode?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.03, green: 0.02, blue: 0.01, alpha: 1)
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
        // Flash lamp to intensity 800, fade back over 1.5s
        guard let lampNode = c.lampLight else { return }
        let flash = SCNAction.customAction(duration: 1.5) { node, elapsed in
            let t = CGFloat(elapsed / 1.5)
            let intensity: CGFloat
            if t < 0.1 {
                intensity = 280 + (800 - 280) * (t / 0.1)
            } else {
                intensity = 800 - (800 - 280) * ((t - 0.1) / 0.9)
            }
            node.light?.intensity = intensity
        }
        lampNode.runAction(flash)
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.1
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.18, green: 0.10, blue: 0.06, alpha: 1)
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        // Back wall
        let wallGeo = SCNPlane(width: 5, height: 4)
        wallGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1)
        wallGeo.firstMaterial?.isDoubleSided = true
        let backWall = SCNNode(geometry: wallGeo)
        backWall.position = SCNVector3(0, 2, -2)
        scene.rootNode.addChildNode(backWall)

        // Left wall
        let leftWallGeo = SCNPlane(width: 5, height: 4)
        leftWallGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1)
        leftWallGeo.firstMaterial?.isDoubleSided = true
        let leftWall = SCNNode(geometry: leftWallGeo)
        leftWall.position = SCNVector3(-2.5, 2, 0)
        leftWall.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        scene.rootNode.addChildNode(leftWall)

        // Right wall
        let rightWallGeo = SCNPlane(width: 5, height: 4)
        rightWallGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.07, blue: 0.04, alpha: 1)
        rightWallGeo.firstMaterial?.isDoubleSided = true
        let rightWall = SCNNode(geometry: rightWallGeo)
        rightWall.position = SCNVector3(2.5, 2, 0)
        rightWall.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
        scene.rootNode.addChildNode(rightWall)

        // Wooden table
        let tableTop = SCNBox(width: 1.5, height: 0.1, length: 0.8, chamferRadius: 0.02)
        tableTop.firstMaterial?.diffuse.contents = NSColor(red: 0.35, green: 0.22, blue: 0.10, alpha: 1)
        let tableNode = SCNNode(geometry: tableTop)
        tableNode.position = SCNVector3(0, 0.8, 0)
        scene.rootNode.addChildNode(tableNode)

        // Table legs
        let legPositions: [(Float, Float)] = [(-0.65, -0.35), (0.65, -0.35), (-0.65, 0.35), (0.65, 0.35)]
        for (lx, lz) in legPositions {
            let leg = SCNCylinder(radius: 0.04, height: 0.8)
            leg.firstMaterial?.diffuse.contents = NSColor(red: 0.30, green: 0.18, blue: 0.08, alpha: 1)
            let legNode = SCNNode(geometry: leg)
            legNode.position = SCNVector3(lx, 0.4, lz)
            scene.rootNode.addChildNode(legNode)
        }

        // Salt lamp body
        let lampBody = SCNSphere(radius: 0.35)
        lampBody.firstMaterial?.diffuse.contents = NSColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 1)
        lampBody.firstMaterial?.emission.contents = NSColor(red: 0.95, green: 0.45, blue: 0.2, alpha: 0.9)
        lampBody.firstMaterial?.lightingModel = .phong
        let lampBodyNode = SCNNode(geometry: lampBody)
        lampBodyNode.position = SCNVector3(0, 1.1, 0)
        scene.rootNode.addChildNode(lampBodyNode)

        // Lamp omni light
        let lampLight = SCNLight()
        lampLight.type = .omni
        lampLight.color = NSColor(red: 1.0, green: 0.55, blue: 0.25, alpha: 1)
        lampLight.intensity = 280
        lampLight.attenuationStartDistance = 0.5
        lampLight.attenuationEndDistance = 5.0
        let lampLightNode = SCNNode()
        lampLightNode.light = lampLight
        lampLightNode.position = SCNVector3(0, 1.1, 0)
        scene.rootNode.addChildNode(lampLightNode)
        coord.lampLight = lampLightNode

        // Breathing animation on lamp (intensity oscillates 220-340)
        let breathe = SCNAction.repeatForever(
            SCNAction.customAction(duration: 3.0) { node, elapsed in
                let t = Float(elapsed / 3.0) * Float.pi * 2
                let intensity = CGFloat(280 + 60 * sin(t))
                node.light?.intensity = intensity
            }
        )
        lampLightNode.runAction(breathe)

        // Gentle sway on lamp body
        let swayUp = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 4.0)
        swayUp.timingMode = .easeInEaseOut
        let swayDown = SCNAction.moveBy(x: 0, y: -0.02, z: 0, duration: 4.0)
        swayDown.timingMode = .easeInEaseOut
        lampBodyNode.runAction(SCNAction.repeatForever(SCNAction.sequence([swayUp, swayDown])))

        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.08, green: 0.05, blue: 0.03, alpha: 1)
        ambientLight.intensity = 100
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Camera: static, looking at lamp
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 50
        cameraNode.position = SCNVector3(1.5, 1.8, 2.5)
        scene.rootNode.addChildNode(cameraNode)

        let lookAt = SCNLookAtConstraint(target: lampBodyNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
    }
}
