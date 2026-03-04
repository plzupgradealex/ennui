// VoyagerNebula3DScene — SceneKit deep-space nebula with drifting probe.
// Semi-transparent nebula volumes, probe with antenna, billboard stars.
// Tap to flash central omni light.

import SwiftUI
import SceneKit

struct VoyagerNebula3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        VoyagerNebula3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct VoyagerNebula3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var flashLight: SCNNode?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        guard let fl = c.flashLight else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.08
        fl.light?.intensity = 3000
        SCNTransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            fl.light?.intensity = 0
            SCNTransaction.commit()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.01, green: 0.02, blue: 0.05, alpha: 1)
        addLighting(to: scene, coord: coord)
        addNebulae(to: scene)
        addProbe(to: scene)
        addStarField(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene, coord: Coordinator) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 20
        ambient.light!.color = NSColor(red: 0.05, green: 0.08, blue: 0.18, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Flash omni at center (starts at 0)
        let flash = SCNNode()
        flash.light = SCNLight()
        flash.light!.type = .omni
        flash.light!.intensity = 0
        flash.light!.color = NSColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        flash.light!.attenuationStartDistance = 1
        flash.light!.attenuationEndDistance = 30
        flash.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(flash)
        coord.flashLight = flash

        // Dim teal fill light
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light!.type = .omni
        fill.light!.intensity = 80
        fill.light!.color = NSColor(red: 0.1, green: 0.5, blue: 0.5, alpha: 1)
        fill.position = SCNVector3(-5, 3, 5)
        scene.rootNode.addChildNode(fill)
    }

    // MARK: - Nebulae

    private func addNebulae(to scene: SCNScene) {
        let configs: [(SCNVector3, CGFloat, NSColor)] = [
            (SCNVector3(-8, 2, -5),  7, NSColor(red: 0.0, green: 0.55, blue: 0.55, alpha: 1)),
            (SCNVector3(3, 4, -8),   5, NSColor(red: 0.7, green: 0.0, blue: 0.7, alpha: 1)),
            (SCNVector3(6, -2, -3),  4, NSColor(red: 0.05, green: 0.6, blue: 0.6, alpha: 1)),
            (SCNVector3(-4, -3, -6), 6, NSColor(red: 0.65, green: 0.0, blue: 0.55, alpha: 1)),
            (SCNVector3(0, 6, -4),   8, NSColor(red: 0.1, green: 0.45, blue: 0.65, alpha: 1)),
        ]

        for (i, cfg) in configs.enumerated() {
            let (pos, radius, color) = cfg
            let geo = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.clear
            mat.emission.contents = color
            mat.lightingModel = .constant
            mat.transparency = 0.85
            mat.writesToDepthBuffer = false
            mat.readsFromDepthBuffer = true
            mat.blendMode = .add
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = pos
            scene.rootNode.addChildNode(node)

            // Slow rotation
            let rot = CABasicAnimation(keyPath: "rotation")
            rot.fromValue = SCNVector4(0, 1, 0, 0)
            rot.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
            rot.duration = 60 + Double(i) * 12
            rot.repeatCount = .infinity
            rot.timingFunction = CAMediaTimingFunction(name: .linear)
            node.addAnimation(rot, forKey: "nebRot\(i)")
        }
    }

    // MARK: - Probe

    private func addProbe(to scene: SCNScene) {
        let probeNode = SCNNode()
        probeNode.position = SCNVector3(2, 1, 2)

        // Body
        let bodyGeo = SCNBox(width: 0.4, height: 0.2, length: 0.8, chamferRadius: 0.02)
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents = NSColor(red: 0.3, green: 0.3, blue: 0.35, alpha: 1)
        bodyMat.specular.contents = NSColor.white
        bodyMat.lightingModel = .phong
        bodyGeo.firstMaterial = bodyMat
        let bodyNode = SCNNode(geometry: bodyGeo)
        probeNode.addChildNode(bodyNode)

        // Antenna
        let antGeo = SCNCylinder(radius: 0.02, height: 1.5)
        let antMat = SCNMaterial()
        antMat.diffuse.contents = NSColor(red: 0.6, green: 0.6, blue: 0.65, alpha: 1)
        antMat.lightingModel = .phong
        antGeo.firstMaterial = antMat
        let antNode = SCNNode(geometry: antGeo)
        antNode.position = SCNVector3(0, 0.85, 0)
        probeNode.addChildNode(antNode)

        // Solar panel arm (flat box)
        let panelGeo = SCNBox(width: 1.6, height: 0.02, length: 0.3, chamferRadius: 0)
        let panelMat = SCNMaterial()
        panelMat.diffuse.contents = NSColor(red: 0.1, green: 0.15, blue: 0.5, alpha: 1)
        panelMat.lightingModel = .phong
        panelGeo.firstMaterial = panelMat
        let panelNode = SCNNode(geometry: panelGeo)
        panelNode.position = SCNVector3(0, 0, 0)
        probeNode.addChildNode(panelNode)

        scene.rootNode.addChildNode(probeNode)

        // Drift forward (z decreasing)
        let drift = CABasicAnimation(keyPath: "position.z")
        drift.fromValue = Float(2)
        drift.toValue = Float(2) - 10
        drift.duration = 60
        drift.autoreverses = true
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        probeNode.addAnimation(drift, forKey: "drift")

        // Gentle rotation
        let spin = CABasicAnimation(keyPath: "eulerAngles.y")
        spin.fromValue = Float(0)
        spin.toValue = Float.pi * 2
        spin.duration = 40
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        probeNode.addAnimation(spin, forKey: "spin")
    }

    // MARK: - Star field

    private func addStarField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 2001)
        for _ in 0..<150 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let phi   = Double.random(in: 0...(.pi), using: &rng)
            let r     = Double.random(in: 16...22, using: &rng)
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(r * cos(phi))
            let z = Float(r * sin(phi) * sin(theta))

            let planeGeo = SCNPlane(width: 0.04, height: 0.04)
            let mat = SCNMaterial()
            let brightness = Double.random(in: 0.4...1.0, using: &rng)
            mat.emission.contents = NSColor(white: brightness, alpha: 1)
            mat.diffuse.contents = NSColor.black
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            planeGeo.firstMaterial = mat

            let starNode = SCNNode(geometry: planeGeo)
            starNode.position = SCNVector3(x, y, z)
            let bill = SCNBillboardConstraint()
            bill.freeAxes = .all
            starNode.constraints = [bill]
            scene.rootNode.addChildNode(starNode)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 70
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 80
        cameraNode.position = SCNVector3(0, 2, 12)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 20, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Slow forward drift of camera (z decreasing then back)
        let drift = CABasicAnimation(keyPath: "position.z")
        drift.fromValue = Float(12)
        drift.toValue = Float(4)
        drift.duration = 60
        drift.autoreverses = true
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.addAnimation(drift, forKey: "camDrift")
    }
}
