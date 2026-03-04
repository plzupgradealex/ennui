// ShimizuEvening3DScene — SceneKit Japanese residential street, rainy evening.
// House, block wall, corner shop, utility poles, sodium lamp, rain puddles.
// Tap to trigger puddle splash burst.

import SwiftUI
import SceneKit

struct ShimizuEvening3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        ShimizuEvening3DRepresentable(interaction: interaction)
    }
}

private struct ShimizuEvening3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var splashEmitter: SCNNode?
        var scene: SCNScene?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
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
        guard let sc = c.scene else { return }
        let splash = SCNParticleSystem()
        splash.birthRate = 80
        splash.particleLifeSpan = 0.6
        splash.emissionDuration = 0.15
        splash.loops = false
        splash.particleSize = 0.04
        splash.particleVelocity = 1.5
        splash.particleVelocityVariation = 0.8
        splash.spreadingAngle = 60
        splash.emittingDirection = SCNVector3(0, 1, 0)
        splash.particleColor = NSColor(red: 0.5, green: 0.55, blue: 0.7, alpha: 0.8)
        splash.isAffectedByGravity = true
        let burstNode = SCNNode()
        burstNode.position = SCNVector3(-1, 0.01, -1)
        sc.rootNode.addChildNode(burstNode)
        burstNode.addParticleSystem(splash)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            burstNode.removeFromParentNode()
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        coord.scene = scene

        // Blue-indigo ambient
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.05, green: 0.06, blue: 0.16, alpha: 1)
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Wet pavement floor
        let floor = SCNFloor()
        floor.reflectivity = 0.06
        floor.firstMaterial?.diffuse.contents = NSColor(white: 0.15, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Main house body
        let houseBody = SCNBox(width: 3, height: 2, length: 2.5, chamferRadius: 0)
        let houseMat = SCNMaterial()
        houseMat.diffuse.contents = NSColor(red: 0.72, green: 0.70, blue: 0.64, alpha: 1)
        houseBody.firstMaterial = houseMat
        let houseNode = SCNNode(geometry: houseBody)
        houseNode.position = SCNVector3(-3, 1, -2)
        scene.rootNode.addChildNode(houseNode)

        // House roof
        let roof = SCNPyramid(width: 3.3, height: 1.2, length: 2.8)
        let roofMat = SCNMaterial()
        roofMat.diffuse.contents = NSColor(white: 0.22, alpha: 1)
        roof.firstMaterial = roofMat
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(-3, 2.6, -2)
        scene.rootNode.addChildNode(roofNode)

        // House windows (warm)
        let winPositions: [(Float, Float, Float)] = [(-4.2, 1.1, -0.74), (-3, 1.1, -0.74), (-1.8, 1.1, -0.74)]
        for wp in winPositions {
            let win = SCNBox(width: 0.45, height: 0.5, length: 0.04, chamferRadius: 0)
            let wm = SCNMaterial()
            wm.diffuse.contents = NSColor(red: 0.95, green: 0.82, blue: 0.45, alpha: 1)
            wm.emission.contents = NSColor(red: 0.7, green: 0.5, blue: 0.1, alpha: 1)
            win.firstMaterial = wm
            let wNode = SCNNode(geometry: win)
            wNode.position = SCNVector3(wp.0, wp.1, wp.2)
            scene.rootNode.addChildNode(wNode)
        }

        // Concrete block wall (12 blocks)
        for k in 0..<12 {
            let block = SCNBox(width: 0.38, height: 0.28, length: 0.05, chamferRadius: 0)
            block.firstMaterial?.diffuse.contents = NSColor(white: 0.45, alpha: 1)
            let bNode = SCNNode(geometry: block)
            bNode.position = SCNVector3(Float(k) * 0.42 - 4.5, 0.15, -1.5)
            scene.rootNode.addChildNode(bNode)
        }

        // Corner shop
        let shop = SCNBox(width: 2, height: 1.8, length: 1.5, chamferRadius: 0)
        shop.firstMaterial?.diffuse.contents = NSColor(white: 0.55, alpha: 1)
        let shopNode = SCNNode(geometry: shop)
        shopNode.position = SCNVector3(3, 0.9, -2)
        scene.rootNode.addChildNode(shopNode)

        // Striped awning
        let awning = SCNBox(width: 2.2, height: 0.1, length: 0.8, chamferRadius: 0)
        let awMat = SCNMaterial()
        awMat.diffuse.contents = NSColor(red: 0.85, green: 0.2, blue: 0.2, alpha: 1)
        awning.firstMaterial = awMat
        let awNode = SCNNode(geometry: awning)
        awNode.position = SCNVector3(3, 1.85, -1.35)
        scene.rootNode.addChildNode(awNode)

        // Shop window light
        let shopWin = SCNBox(width: 0.6, height: 0.5, length: 0.04, chamferRadius: 0)
        let swm = SCNMaterial()
        swm.diffuse.contents = NSColor(red: 1.0, green: 0.9, blue: 0.6, alpha: 1)
        swm.emission.contents = NSColor(red: 0.7, green: 0.55, blue: 0.1, alpha: 1)
        shopWin.firstMaterial = swm
        let swNode = SCNNode(geometry: shopWin)
        swNode.position = SCNVector3(3, 0.85, -1.23)
        scene.rootNode.addChildNode(swNode)

        // Utility poles
        let polePositions: [Float] = [-5, 0, 5]
        for px in polePositions {
            let pole = SCNCylinder(radius: 0.04, height: 4)
            pole.firstMaterial?.diffuse.contents = NSColor(white: 0.2, alpha: 1)
            let pNode = SCNNode(geometry: pole)
            pNode.position = SCNVector3(px, 2, -3.5)
            scene.rootNode.addChildNode(pNode)
        }

        // Sodium street lamp
        let lampPole = SCNCylinder(radius: 0.04, height: 3)
        lampPole.firstMaterial?.diffuse.contents = NSColor(white: 0.3, alpha: 1)
        let lampPoleNode = SCNNode(geometry: lampPole)
        lampPoleNode.position = SCNVector3(1, 1.5, -1)
        scene.rootNode.addChildNode(lampPoleNode)

        let housing = SCNBox(width: 0.3, height: 0.15, length: 0.2, chamferRadius: 0)
        housing.firstMaterial?.diffuse.contents = NSColor(white: 0.5, alpha: 1)
        let hNode = SCNNode(geometry: housing)
        hNode.position = SCNVector3(1, 3.1, -1)
        scene.rootNode.addChildNode(hNode)

        let lampLightNode = SCNNode()
        lampLightNode.position = SCNVector3(1, 3.0, -1)
        let lampLight = SCNLight(); lampLight.type = .omni
        lampLight.color = NSColor(red: 1.0, green: 0.78, blue: 0.3, alpha: 1)
        lampLight.intensity = 300
        lampLight.attenuationStartDistance = 0.5
        lampLight.attenuationEndDistance = 6
        lampLightNode.light = lampLight
        scene.rootNode.addChildNode(lampLightNode)

        // Rain particles
        let rain = SCNParticleSystem()
        rain.birthRate = 100
        rain.particleLifeSpan = 1.5
        rain.particleSize = 0.018
        rain.particleColor = NSColor(red: 0.5, green: 0.55, blue: 0.7, alpha: 0.5)
        rain.particleVelocity = 7
        rain.emittingDirection = SCNVector3(0, -1, 0)
        rain.spreadingAngle = 4
        rain.emitterShape = SCNBox(width: 20, height: 0, length: 20, chamferRadius: 0)
        rain.isAffectedByGravity = false
        let rainNode = SCNNode()
        rainNode.position = SCNVector3(0, 10, -3)
        rainNode.addParticleSystem(rain)
        scene.rootNode.addChildNode(rainNode)

        // Puddles
        for (px, pz) in [(Float(-2), Float(-0.8)), (Float(1.5), Float(-0.5))] {
            let puddle = SCNBox(width: 0.7, height: 0.004, length: 0.45, chamferRadius: 0)
            let pm = SCNMaterial()
            pm.diffuse.contents = NSColor(white: 0.05, alpha: 1)
            pm.specular.contents = NSColor(white: 0.25, alpha: 1)
            pm.shininess = 60
            puddle.firstMaterial = pm
            let pNode = SCNNode(geometry: puddle)
            pNode.position = SCNVector3(px, 0.003, pz)
            scene.rootNode.addChildNode(pNode)
        }

        // Camera slow drift
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 58; cam.zFar = 60
        camNode.camera = cam
        camNode.position = SCNVector3(0, 2.0, 4)
        camNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let drift = SCNAction.customAction(duration: 20) { node, elapsed in
            let t = CGFloat(elapsed / 20)
            node.position.x = sin(t * CGFloat.pi * 2) * 0.8
        }
        camNode.runAction(SCNAction.repeatForever(drift))
    }
}
