// PaperLanternFestival3DScene — SceneKit lantern festival on lake at dusk.
// Floating lanterns, moon, stars. Tap to spawn new lantern.

import SwiftUI
import SceneKit

struct PaperLanternFestival3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View {
        PaperLanternFestival3DRepresentable(interaction: interaction)
    }
}

private struct PaperLanternFestival3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var scnScene: SCNScene?
        var rng = SplitMix64(seed: 9999)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.02, green: 0.03, blue: 0.06, alpha: 1)
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
        guard let sc = c.scnScene else { return }
        let lx = Float(Double.random(in: -6...6, using: &c.rng))
        let lz = Float(Double.random(in: -8 ... -2, using: &c.rng))
        spawnLantern(in: sc, x: lx, y: 0.2, z: lz, driftDuration: Double.random(in: 20...35, using: &c.rng))
    }

    private func spawnLantern(in scene: SCNScene, x: Float, y: Float, z: Float, driftDuration: Double) {
        let box = SCNBox(width: 0.3, height: 0.4, length: 0.3, chamferRadius: 0.05)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 1.0, green: 0.62, blue: 0.15, alpha: 1)
        mat.emission.contents = NSColor(red: 0.9, green: 0.45, blue: 0.05, alpha: 1)
        box.firstMaterial = mat
        let lNode = SCNNode(geometry: box)
        lNode.position = SCNVector3(x, y, z)
        scene.rootNode.addChildNode(lNode)

        let lightNode = SCNNode()
        lightNode.position = SCNVector3(0, 0, 0)
        let light = SCNLight(); light.type = .omni
        light.color = NSColor(red: 1.0, green: 0.65, blue: 0.25, alpha: 1)
        light.intensity = 60
        light.attenuationStartDistance = 0.1
        light.attenuationEndDistance = 3.0
        lightNode.light = light
        lNode.addChildNode(lightNode)

        // Gentle sway + upward drift
        let drift = SCNAction.customAction(duration: driftDuration) { node, elapsed in
            let t = Float(elapsed / driftDuration)
            node.position.y = y + t * 5
            node.position.x = x + sin(Float(elapsed) * 0.6) * 0.3
            node.eulerAngles.z = sin(Float(elapsed) * 0.4) * 0.12
        }
        lNode.runAction(drift) {
            lNode.removeFromParentNode()
        }
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        coord.scnScene = scene

        // Blue-purple ambient
        let ambNode = SCNNode()
        let amb = SCNLight(); amb.type = .ambient
        amb.color = NSColor(red: 0.06, green: 0.04, blue: 0.14, alpha: 1)
        ambNode.light = amb
        scene.rootNode.addChildNode(ambNode)

        // Faint directional moonlight
        let moonLightNode = SCNNode()
        let moonLight = SCNLight(); moonLight.type = .directional
        moonLight.color = NSColor(red: 0.55, green: 0.55, blue: 0.75, alpha: 1)
        moonLight.intensity = 150
        moonLightNode.light = moonLight
        moonLightNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 8, 0)
        scene.rootNode.addChildNode(moonLightNode)

        // Dark lake floor
        let floor = SCNFloor()
        floor.reflectivity = 0.05
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.04, green: 0.06, blue: 0.12, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: floor))

        // Moon
        let moonSphere = SCNSphere(radius: 1.5)
        let mm = SCNMaterial()
        mm.diffuse.contents = NSColor(red: 0.92, green: 0.92, blue: 0.88, alpha: 1)
        mm.emission.contents = NSColor(red: 0.7, green: 0.7, blue: 0.65, alpha: 1)
        moonSphere.firstMaterial = mm
        let moonNode = SCNNode(geometry: moonSphere)
        moonNode.position = SCNVector3(0, 20, -20)
        scene.rootNode.addChildNode(moonNode)

        // Stars (80 billboard planes, seeded)
        var rng1 = SplitMix64(seed: 1002)
        for _ in 0..<80 {
            let sx = Float(Double.random(in: -30...30, using: &rng1))
            let sy = Float(Double.random(in: 8...30, using: &rng1))
            let sz = Float(Double.random(in: -35 ... -5, using: &rng1))
            let sr = CGFloat(Double.random(in: 0.02...0.08, using: &rng1))
            let star = SCNPlane(width: sr, height: sr)
            let sm = SCNMaterial()
            let br = Double.random(in: 0.5...1.0, using: &rng1)
            sm.diffuse.contents = NSColor(white: br, alpha: 1)
            sm.emission.contents = NSColor(white: br, alpha: 1)
            sm.isDoubleSided = true
            star.firstMaterial = sm
            let sNode = SCNNode(geometry: star)
            sNode.position = SCNVector3(sx, sy, sz)
            let bb = SCNBillboardConstraint()
            sNode.constraints = [bb]
            scene.rootNode.addChildNode(sNode)
        }

        // Initial 20 lanterns
        var rng2 = SplitMix64(seed: 1001)
        for _ in 0..<20 {
            let lx = Float(Double.random(in: -8...8, using: &rng2))
            let lz = Float(Double.random(in: -12 ... -2, using: &rng2))
            let ly = Float(Double.random(in: 0.5...4, using: &rng2))
            let dur = Double.random(in: 20...40, using: &rng2)
            spawnLantern(in: scene, x: lx, y: ly, z: lz, driftDuration: dur)
        }

        // Camera slowly pans across lake
        let camNode = SCNNode()
        let cam = SCNCamera(); cam.fieldOfView = 65; cam.zFar = 80
        camNode.camera = cam
        camNode.position = SCNVector3(0, 3, 6)
        camNode.eulerAngles = SCNVector3(-0.15, 0, 0)
        scene.rootNode.addChildNode(camNode)
        let pan = SCNAction.customAction(duration: 30) { node, elapsed in
            let t = Float(elapsed / 30)
            node.eulerAngles.y = sin(t * Float.pi * 2) * 0.35
            node.position.x = sin(t * Float.pi * 2) * 1.5
        }
        camNode.runAction(SCNAction.repeatForever(pan))
    }
}
