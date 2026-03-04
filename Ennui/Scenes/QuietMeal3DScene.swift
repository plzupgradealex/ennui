import SwiftUI
import SceneKit

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
        view.backgroundColor = NSColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)
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
        // Rain burst
        guard let rain = c.rainSystem else { return }
        rain.birthRate = 300
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            rain.birthRate = 50
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Window frame pieces (dark wood)
        let woodColor = NSColor(red: 0.22, green: 0.14, blue: 0.07, alpha: 1)

        // Top bar
        let topBar = SCNBox(width: 1.4, height: 0.12, length: 0.12, chamferRadius: 0.01)
        topBar.firstMaterial?.diffuse.contents = woodColor
        let topBarNode = SCNNode(geometry: topBar)
        topBarNode.position = SCNVector3(0, 1.26, 0)
        scene.rootNode.addChildNode(topBarNode)

        // Bottom bar
        let bottomBar = SCNBox(width: 1.4, height: 0.12, length: 0.12, chamferRadius: 0.01)
        bottomBar.firstMaterial?.diffuse.contents = woodColor
        let bottomBarNode = SCNNode(geometry: bottomBar)
        bottomBarNode.position = SCNVector3(0, -0.26, 0)
        scene.rootNode.addChildNode(bottomBarNode)

        // Left bar
        let leftBar = SCNBox(width: 0.12, height: 1.4, length: 0.12, chamferRadius: 0.01)
        leftBar.firstMaterial?.diffuse.contents = woodColor
        let leftBarNode = SCNNode(geometry: leftBar)
        leftBarNode.position = SCNVector3(-0.64, 0.5, 0)
        scene.rootNode.addChildNode(leftBarNode)

        // Right bar
        let rightBar = SCNBox(width: 0.12, height: 1.4, length: 0.12, chamferRadius: 0.01)
        rightBar.firstMaterial?.diffuse.contents = woodColor
        let rightBarNode = SCNNode(geometry: rightBar)
        rightBarNode.position = SCNVector3(0.64, 0.5, 0)
        scene.rootNode.addChildNode(rightBarNode)

        // Glass pane
        let glass = SCNPlane(width: 1.2, height: 1.2)
        glass.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.20, blue: 0.28, alpha: 1)
        glass.firstMaterial?.transparency = 0.6
        glass.firstMaterial?.isDoubleSided = true
        glass.firstMaterial?.lightingModel = .constant
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(0, 0.5, 0.01)
        scene.rootNode.addChildNode(glassNode)

        // Rain on glass
        let rain = SCNParticleSystem()
        rain.birthRate = 50
        rain.particleLifeSpan = 1.2
        rain.particleSize = 0.012
        rain.particleColor = NSColor(red: 0.55, green: 0.65, blue: 0.9, alpha: 0.7)
        rain.emittingDirection = SCNVector3(0, -1, 0)
        rain.spreadingAngle = 3
        rain.particleVelocity = 1.0
        rain.isAffectedByGravity = false
        rain.loops = true
        coord.rainSystem = rain
        let rainEmitterNode = SCNNode()
        rainEmitterNode.position = SCNVector3(0, 1.2, 0.02)
        rainEmitterNode.addParticleSystem(rain)
        scene.rootNode.addChildNode(rainEmitterNode)

        // Inside scene (behind glass, z < 0)
        // Table
        let table = SCNBox(width: 1.4, height: 0.1, length: 0.8, chamferRadius: 0.02)
        table.firstMaterial?.diffuse.contents = NSColor(red: 0.30, green: 0.20, blue: 0.12, alpha: 1)
        let tableNode = SCNNode(geometry: table)
        tableNode.position = SCNVector3(0, -0.3, -1.5)
        scene.rootNode.addChildNode(tableNode)

        // Two ramen bowls
        let bowlColor = NSColor(red: 0.92, green: 0.90, blue: 0.88, alpha: 1)
        let brothColor = NSColor(red: 0.65, green: 0.35, blue: 0.15, alpha: 1)
        let bowlXPositions: [Float] = [-0.3, 0.3]
        for bx in bowlXPositions {
            let bowl = SCNCylinder(radius: 0.18, height: 0.12)
            bowl.firstMaterial?.diffuse.contents = bowlColor
            let bowlNode = SCNNode(geometry: bowl)
            bowlNode.position = SCNVector3(bx, -0.19, -1.5)
            scene.rootNode.addChildNode(bowlNode)

            let broth = SCNSphere(radius: 0.15)
            broth.firstMaterial?.diffuse.contents = brothColor
            broth.firstMaterial?.emission.contents = NSColor(red: 0.5, green: 0.25, blue: 0.08, alpha: 0.6)
            let brothNode = SCNNode(geometry: broth)
            brothNode.position = SCNVector3(bx, -0.16, -1.5)
            brothNode.scale = SCNVector3(1.0, 0.3, 1.0)
            scene.rootNode.addChildNode(brothNode)
        }

        // Two chairs
        let chairColor = NSColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1)
        for cx in [-0.5, 0.5] as [Float] {
            let seat = SCNBox(width: 0.4, height: 0.05, length: 0.4, chamferRadius: 0.01)
            seat.firstMaterial?.diffuse.contents = chairColor
            let seatNode = SCNNode(geometry: seat)
            seatNode.position = SCNVector3(cx, -0.52, -1.1)
            scene.rootNode.addChildNode(seatNode)

            let back = SCNBox(width: 0.4, height: 0.5, length: 0.05, chamferRadius: 0.01)
            back.firstMaterial?.diffuse.contents = chairColor
            let backNode = SCNNode(geometry: back)
            backNode.position = SCNVector3(cx, -0.27, -1.3)
            scene.rootNode.addChildNode(backNode)
        }

        // Overhead lamp (small amber sphere)
        let lampGeo = SCNSphere(radius: 0.07)
        lampGeo.firstMaterial?.diffuse.contents = NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 1)
        lampGeo.firstMaterial?.emission.contents = NSColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.9)
        let lampNode = SCNNode(geometry: lampGeo)
        lampNode.position = SCNVector3(0, 0.5, -1.5)
        scene.rootNode.addChildNode(lampNode)

        // Interior warm light (behind glass)
        let interiorLight = SCNLight()
        interiorLight.type = .omni
        interiorLight.color = NSColor(red: 1.0, green: 0.65, blue: 0.35, alpha: 1)
        interiorLight.intensity = 200
        interiorLight.attenuationStartDistance = 0.3
        interiorLight.attenuationEndDistance = 4.0
        let interiorLightNode = SCNNode()
        interiorLightNode.light = interiorLight
        interiorLightNode.position = SCNVector3(0, 0.5, -1.5)
        scene.rootNode.addChildNode(interiorLightNode)

        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.04, green: 0.05, blue: 0.10, alpha: 1)
        ambientLight.intensity = 150
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Camera: static outside looking at window
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 50
        cameraNode.position = SCNVector3(0, 1.5, 3)
        scene.rootNode.addChildNode(cameraNode)

        let lookAt = SCNLookAtConstraint(target: glassNode)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]

        // Breathing sway
        let swayUp = SCNAction.moveBy(x: 0, y: 0.01, z: 0, duration: 5.0)
        swayUp.timingMode = .easeInEaseOut
        let swayDown = SCNAction.moveBy(x: 0, y: -0.01, z: 0, duration: 5.0)
        swayDown.timingMode = .easeInEaseOut
        cameraNode.runAction(SCNAction.repeatForever(SCNAction.sequence([swayUp, swayDown])))
    }
}
