// AncientRuins3DScene — SceneKit ancient ruins at night.
// Columns, fallen slabs, aurora planes, firefly particles, moon.
// Tap to spike firefly birth rate briefly.

import SwiftUI
import SceneKit

struct AncientRuins3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        AncientRuins3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct AncientRuins3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var fireflySystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 1)
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
        guard let ps = c.fireflySystem else { return }
        ps.birthRate = 50
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ps.birthRate = 5
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.01, green: 0.02, blue: 0.04, alpha: 1)
        scene.fogStartDistance = 15
        scene.fogEndDistance = 40
        scene.fogColor = NSColor(red: 0.01, green: 0.02, blue: 0.06, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addColumns(to: scene)
        addSlabs(to: scene)
        addAurora(to: scene)
        addMoon(to: scene)
        addFireflies(to: scene, coord: coord)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        // Dim purple ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 30
        ambient.light!.color = NSColor(red: 0.15, green: 0.08, blue: 0.25, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Blue-white moonlight directional
        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light!.type = .directional
        moonLight.light!.intensity = 90
        moonLight.light!.color = NSColor(red: 0.55, green: 0.6, blue: 0.9, alpha: 1)
        moonLight.light!.castsShadow = true
        moonLight.light!.shadowRadius = 3
        moonLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 6, 0)
        scene.rootNode.addChildNode(moonLight)
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.12, green: 0.18, blue: 0.1, alpha: 1)
        mat.lightingModel = .lambert
        floor.firstMaterial = mat
        floor.reflectivity = 0
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Columns

    private func addColumns(to scene: SCNScene) {
        let positions: [(Float, Float, Float)] = [
            (-4, 1.75, -3), (-2, 1.75, -5), (0, 1.75, -4),
            (2, 1.75, -3), (4, 1.75, -5), (-1, 1.75, -2)
        ]
        let tilts: [(Float, Float, Float)] = [
            (0, 0, 0.04), (0, 0, -0.06), (0.03, 0, 0),
            (0, 0, 0.07), (0, 0, -0.04), (0.05, 0, 0)
        ]

        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.68, green: 0.64, blue: 0.55, alpha: 1)
        mat.lightingModel = .lambert

        for (i, pos) in positions.enumerated() {
            let geo = SCNCylinder(radius: 0.25, height: 3.5)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(pos.0, pos.1, pos.2)
            let t = tilts[i]
            node.eulerAngles = SCNVector3(t.0, t.1, t.2)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Fallen slabs

    private func addSlabs(to scene: SCNScene) {
        let configs: [(Float, Float, Float, Float, Float, Float)] = [
            (-5, 0.15, -4, 0, 0.3, 0),
            (1, 0.15, -6, 0.1, -0.2, 0.05),
            (3, 0.15, -2, 0, 0.5, 0),
        ]

        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.55, green: 0.52, blue: 0.48, alpha: 1)
        mat.lightingModel = .lambert

        for cfg in configs {
            let geo = SCNBox(width: 2, height: 0.3, length: 0.8, chamferRadius: 0.02)
            geo.firstMaterial = mat
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(cfg.0, cfg.1, cfg.2)
            node.eulerAngles = SCNVector3(cfg.3, cfg.4, cfg.5)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Aurora planes

    private func addAurora(to scene: SCNScene) {
        let configs: [(SCNVector3, NSColor)] = [
            (SCNVector3(0, 5, -15),  NSColor(red: 0.0, green: 0.8, blue: 0.35, alpha: 1)),
            (SCNVector3(-8, 5, -12), NSColor(red: 0.55, green: 0.0, blue: 0.8, alpha: 1)),
            (SCNVector3(8, 5, -12),  NSColor(red: 0.0, green: 0.65, blue: 0.7, alpha: 1)),
        ]

        for (i, cfg) in configs.enumerated() {
            let (pos, color) = cfg
            let geo = SCNPlane(width: 12, height: 6)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor.black
            mat.emission.contents = color
            mat.lightingModel = .constant
            mat.transparency = 0.7
            mat.isDoubleSided = true
            mat.blendMode = .add
            mat.writesToDepthBuffer = false
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = pos
            scene.rootNode.addChildNode(node)

            // Gentle ripple (y position oscillation)
            let ripple = CABasicAnimation(keyPath: "position.y")
            ripple.fromValue = pos.y - 0.4
            ripple.toValue = pos.y + 0.4
            ripple.duration = 5.0 + Double(i) * 1.2
            ripple.autoreverses = true
            ripple.repeatCount = .infinity
            ripple.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(ripple, forKey: "aurora\(i)")
        }
    }

    // MARK: - Moon

    private func addMoon(to scene: SCNScene) {
        let geo = SCNSphere(radius: 1.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.9, green: 0.9, blue: 0.95, alpha: 1)
        mat.emission.contents = NSColor(red: 0.75, green: 0.75, blue: 0.8, alpha: 1)
        mat.lightingModel = .constant
        geo.firstMaterial = mat
        let moonNode = SCNNode(geometry: geo)
        moonNode.position = SCNVector3(6, 15, -20)
        scene.rootNode.addChildNode(moonNode)
    }

    // MARK: - Fireflies

    private func addFireflies(to scene: SCNScene, coord: Coordinator) {
        let ps = SCNParticleSystem()
        ps.birthRate = 5
        ps.particleLifeSpan = 8
        ps.particleLifeSpanVariation = 3
        ps.particleSize = 0.04
        ps.particleColor = NSColor(red: 0.75, green: 1.0, blue: 0.2, alpha: 0.9)
        ps.particleColorVariation = SCNVector4(0.1, 0.1, 0.05, 0.2)
        ps.emitterShape = SCNBox(width: 12, height: 4, length: 10, chamferRadius: 0)
        ps.spreadingAngle = 60
        ps.particleVelocity = 0.4
        ps.particleVelocityVariation = 0.3
        ps.acceleration = SCNVector3(0, 0.05, 0)
        ps.isLightingEnabled = false
        ps.blendMode = .additive

        let psNode = SCNNode()
        psNode.position = SCNVector3(0, 1.5, -5)
        psNode.addParticleSystem(ps)
        scene.rootNode.addChildNode(psNode)
        coord.fireflySystem = ps
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraPivot = SCNNode()
        cameraPivot.position = SCNVector3(0, 2.5, 0)
        scene.rootNode.addChildNode(cameraPivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 65
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 80
        cameraNode.position = SCNVector3(0, 0, 9)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 16, 0, 0)
        cameraPivot.addChildNode(cameraNode)

        let orbit = CABasicAnimation(keyPath: "rotation")
        orbit.fromValue = SCNVector4(0, 1, 0, 0)
        orbit.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
        orbit.duration = 90
        orbit.repeatCount = .infinity
        orbit.timingFunction = CAMediaTimingFunction(name: .linear)
        cameraPivot.addAnimation(orbit, forKey: "camOrbit")
    }
}
