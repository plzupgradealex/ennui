// DeepOcean3DScene — SceneKit deep ocean scene.
// Jellyfish with pulsing bodies, kelp, bioluminescent particles, blue-green omni lights.
// Tap to spike bioluminescent particle birth rate.

import SwiftUI
import SceneKit

struct DeepOcean3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        DeepOcean3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct DeepOcean3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var glowSystem: SCNParticleSystem?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.0, green: 0.02, blue: 0.08, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        guard let ps = c.glowSystem else { return }
        ps.birthRate = 200
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ps.birthRate = 20
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.0, green: 0.02, blue: 0.08, alpha: 1)
        scene.fogStartDistance = 8
        scene.fogEndDistance = 25
        scene.fogColor = NSColor(red: 0.0, green: 0.03, blue: 0.12, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addJellyfish(to: scene)
        addKelp(to: scene)
        addParticles(to: scene, coord: coord)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 20
        ambient.light!.color = NSColor(red: 0.0, green: 0.08, blue: 0.2, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // 8 scattered faint blue-green point lights
        let lightPositions: [(Float, Float, Float)] = [
            (-3, 2.5, -5), (2, 3.5, -4), (-1, 2, -7), (4, 2.5, -3),
            (-5, 1.5, -3), (1, 4, -6), (3, 1.5, -8), (-2, 3, -2)
        ]
        for (i, pos) in lightPositions.enumerated() {
            let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light!.type = .omni
            lightNode.light!.intensity = CGFloat(60 + i * 5)
            lightNode.light!.color = NSColor(red: 0.05, green: 0.55 + Double(i % 3) * 0.08, blue: 0.5 + Double(i % 2) * 0.1, alpha: 1)
            lightNode.light!.attenuationStartDistance = 0.5
            lightNode.light!.attenuationEndDistance = 8
            lightNode.position = SCNVector3(pos.0, pos.1, pos.2)
            scene.rootNode.addChildNode(lightNode)
        }
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.03, green: 0.06, blue: 0.2, alpha: 1)
        mat.lightingModel = .lambert
        floor.firstMaterial = mat
        floor.reflectivity = 0.05
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Jellyfish

    private func addJellyfish(to scene: SCNScene) {
        let positions: [(Float, Float, Float)] = [
            (-3, 2, -5), (2, 3, -4), (-1, 1.5, -7), (4, 2, -3)
        ]

        let tentacleMat = SCNMaterial()
        tentacleMat.diffuse.contents = NSColor(red: 0.65, green: 0.85, blue: 1.0, alpha: 0.7)
        tentacleMat.emission.contents = NSColor(red: 0.3, green: 0.5, blue: 0.8, alpha: 0.5)
        tentacleMat.lightingModel = .constant
        tentacleMat.transparency = 0.3

        for (i, pos) in positions.enumerated() {
            let jellyNode = SCNNode()
            jellyNode.position = SCNVector3(pos.0, pos.1, pos.2)

            // Bell (body)
            let bodyGeo = SCNSphere(radius: 0.3)
            let bodyMat = SCNMaterial()
            bodyMat.diffuse.contents = NSColor(red: 0.7, green: 0.88, blue: 1.0, alpha: 0.55)
            bodyMat.emission.contents = NSColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 0.4)
            bodyMat.lightingModel = .constant
            bodyMat.transparency = 0.45
            bodyGeo.firstMaterial = bodyMat
            let bodyNode = SCNNode(geometry: bodyGeo)
            jellyNode.addChildNode(bodyNode)

            // Pulse animation on body
            let pulse = CABasicAnimation(keyPath: "scale")
            pulse.fromValue = SCNVector3(0.9, 0.9, 0.9)
            pulse.toValue = SCNVector3(1.1, 1.1, 1.1)
            pulse.duration = 2.0 + Double(i) * 0.3
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            bodyNode.addAnimation(pulse, forKey: "jellyPulse")

            // 3 tentacles
            for t in 0..<3 {
                let tentGeo = SCNCylinder(radius: 0.02, height: 0.8)
                tentGeo.firstMaterial = tentacleMat
                let tentNode = SCNNode(geometry: tentGeo)
                let angle = Float(t) * Float.pi * 2 / 3
                tentNode.position = SCNVector3(0.12 * cos(angle), -0.7, 0.12 * sin(angle))
                jellyNode.addChildNode(tentNode)

                // Sway tentacles
                let sway = CABasicAnimation(keyPath: "eulerAngles.z")
                sway.fromValue = Float(-0.2)
                sway.toValue = Float(0.2)
                sway.duration = 2.5 + Double(t) * 0.4
                sway.autoreverses = true
                sway.repeatCount = .infinity
                sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                tentNode.addAnimation(sway, forKey: "tentSway\(t)")
            }

            // Bob up/down
            let bob = CABasicAnimation(keyPath: "position.y")
            bob.fromValue = pos.1 - 0.3
            bob.toValue = pos.1 + 0.3
            bob.duration = 3.5 + Double(i) * 0.7
            bob.autoreverses = true
            bob.repeatCount = .infinity
            bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            jellyNode.addAnimation(bob, forKey: "bob\(i)")

            scene.rootNode.addChildNode(jellyNode)
        }
    }

    // MARK: - Kelp

    private func addKelp(to scene: SCNScene) {
        var rng = SplitMix64(seed: 9901)
        let kelpMat = SCNMaterial()
        kelpMat.diffuse.contents = NSColor(red: 0.05, green: 0.3, blue: 0.12, alpha: 1)
        kelpMat.lightingModel = .lambert

        for i in 0..<6 {
            let x = Float(Double.random(in: -5...5, using: &rng))
            let z = Float(Double.random(in: -8...(-2), using: &rng))

            let geo = SCNCylinder(radius: 0.04, height: 3)
            geo.firstMaterial = kelpMat

            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(x, 1.5, z)
            scene.rootNode.addChildNode(node)

            // Gentle sway
            let sway = CABasicAnimation(keyPath: "eulerAngles.z")
            sway.fromValue = Float(-0.15)
            sway.toValue = Float(0.15)
            sway.duration = 4.0 + Double(i) * 0.6
            sway.autoreverses = true
            sway.repeatCount = .infinity
            sway.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.addAnimation(sway, forKey: "kelpSway\(i)")
        }
    }

    // MARK: - Bioluminescent particles

    private func addParticles(to scene: SCNScene, coord: Coordinator) {
        let ps = SCNParticleSystem()
        ps.birthRate = 20
        ps.particleLifeSpan = 6
        ps.particleSize = 0.03
        ps.particleColor = NSColor(red: 0.2, green: 0.9, blue: 0.7, alpha: 0.7)
        ps.particleColorVariation = SCNVector4(0.1, 0.2, 0.1, 0.2)
        ps.emitterShape = SCNBox(width: 14, height: 0.5, length: 12, chamferRadius: 0)
        ps.spreadingAngle = 15
        ps.particleVelocity = 0.3
        ps.particleVelocityVariation = 0.2
        ps.acceleration = SCNVector3(0, 0.1, 0)
        ps.isLightingEnabled = false
        ps.blendMode = .additive

        let psNode = SCNNode()
        psNode.position = SCNVector3(0, 0.5, -5)
        psNode.addParticleSystem(ps)
        scene.rootNode.addChildNode(psNode)
        coord.glowSystem = ps
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraPivot = SCNNode()
        cameraPivot.position = SCNVector3(0, 2, 0)
        scene.rootNode.addChildNode(cameraPivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 70
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 60
        cameraNode.position = SCNVector3(0, 0, 10)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 18, 0, 0)
        cameraPivot.addChildNode(cameraNode)

        let orbit = CABasicAnimation(keyPath: "rotation")
        orbit.fromValue = SCNVector4(0, 1, 0, 0)
        orbit.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
        orbit.duration = 180
        orbit.repeatCount = .infinity
        orbit.timingFunction = CAMediaTimingFunction(name: .linear)
        cameraPivot.addAnimation(orbit, forKey: "camOrbit")
    }
}
