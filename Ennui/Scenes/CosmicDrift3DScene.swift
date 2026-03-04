// CosmicDrift3DScene — SceneKit deep-space scene.
// Central star with orbiting planets, billboard stars, camera orbit.
// Tap to flash the central star's omni light.

import SwiftUI
import SceneKit

struct CosmicDrift3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        CosmicDrift3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct CosmicDrift3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var starLight: SCNNode?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1)
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
        guard let starLightNode = c.starLight else { return }
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.1
        starLightNode.light?.intensity = 3000
        SCNTransaction.commit()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 1.5
            starLightNode.light?.intensity = 1000
            SCNTransaction.commit()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.01, green: 0.01, blue: 0.04, alpha: 1)
        addLighting(to: scene, coord: coord)
        addCentralStar(to: scene, coord: coord)
        addPlanets(to: scene)
        addStarField(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene, coord: Coordinator) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 15
        ambient.light!.color = NSColor(red: 0.05, green: 0.05, blue: 0.15, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Central star

    private func addCentralStar(to scene: SCNScene, coord: Coordinator) {
        let starGeo = SCNSphere(radius: 0.8)
        let starMat = SCNMaterial()
        starMat.diffuse.contents = NSColor(red: 1.0, green: 0.95, blue: 0.7, alpha: 1)
        starMat.emission.contents = NSColor(red: 1.0, green: 0.9, blue: 0.5, alpha: 1)
        starMat.lightingModel = .constant
        starGeo.firstMaterial = starMat
        let starNode = SCNNode(geometry: starGeo)
        starNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(starNode)

        // Omni light from the star
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.light!.intensity = 1000
        lightNode.light!.color = NSColor(red: 1.0, green: 0.92, blue: 0.6, alpha: 1)
        lightNode.light!.attenuationStartDistance = 1
        lightNode.light!.attenuationEndDistance = 40
        lightNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(lightNode)
        coord.starLight = lightNode

        // Gentle pulse on the star itself
        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = SCNVector3(1, 1, 1)
        pulse.toValue = SCNVector3(1.08, 1.08, 1.08)
        pulse.duration = 2.5
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        starNode.addAnimation(pulse, forKey: "pulse")
    }

    // MARK: - Planets

    private func addPlanets(to scene: SCNScene) {
        let configs: [(Float, Float, Double, NSColor, NSColor)] = [
            (3,  0.3, 20, NSColor(red: 0.2, green: 0.4, blue: 0.9, alpha: 1),  NSColor(red: 0.1, green: 0.2, blue: 0.6, alpha: 1)),
            (5,  0.5, 35, NSColor(red: 0.8, green: 0.35, blue: 0.15, alpha: 1), NSColor(red: 0.6, green: 0.2, blue: 0.1, alpha: 1)),
            (7,  0.4, 50, NSColor(red: 0.1, green: 0.6, blue: 0.55, alpha: 1),  NSColor(red: 0.05, green: 0.4, blue: 0.4, alpha: 1)),
            (9,  0.55, 42, NSColor(red: 0.55, green: 0.2, blue: 0.75, alpha: 1), NSColor(red: 0.4, green: 0.1, blue: 0.6, alpha: 1)),
            (11, 0.45, 60, NSColor(red: 0.8, green: 0.7, blue: 0.45, alpha: 1),  NSColor(red: 0.6, green: 0.5, blue: 0.3, alpha: 1)),
        ]

        for (i, cfg) in configs.enumerated() {
            let (dist, radius, period, diffColor, emitColor) = cfg

            // Pivot node for orbit
            let pivot = SCNNode()
            pivot.position = SCNVector3(0, 0, 0)
            scene.rootNode.addChildNode(pivot)

            // Tilt each orbit slightly
            pivot.eulerAngles = SCNVector3(Float(i) * 0.15, 0, Float(i) * 0.08)

            let planetGeo = SCNSphere(radius: CGFloat(radius))
            let planetMat = SCNMaterial()
            planetMat.diffuse.contents = diffColor
            planetMat.emission.contents = emitColor
            planetMat.lightingModel = .phong
            planetMat.specular.contents = NSColor.white
            planetGeo.firstMaterial = planetMat
            let planetNode = SCNNode(geometry: planetGeo)
            planetNode.position = SCNVector3(dist, 0, 0)
            pivot.addChildNode(planetNode)

            // Orbit rotation
            let orbit = CABasicAnimation(keyPath: "rotation")
            orbit.fromValue = SCNVector4(0, 1, 0, 0)
            orbit.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
            orbit.duration = period
            orbit.repeatCount = .infinity
            orbit.timingFunction = CAMediaTimingFunction(name: .linear)
            pivot.addAnimation(orbit, forKey: "orbit\(i)")
        }
    }

    // MARK: - Star field (billboard planes)

    private func addStarField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 1001)
        for _ in 0..<200 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            let phi   = Double.random(in: 0...(.pi), using: &rng)
            let r     = Double.random(in: 15...20, using: &rng)
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(r * cos(phi))
            let z = Float(r * sin(phi) * sin(theta))

            let planeGeo = SCNPlane(width: 0.05, height: 0.05)
            let mat = SCNMaterial()
            let brightness = Double.random(in: 0.5...1.0, using: &rng)
            mat.emission.contents = NSColor(white: brightness, alpha: 1)
            mat.diffuse.contents = NSColor.black
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            planeGeo.firstMaterial = mat

            let starNode = SCNNode(geometry: planeGeo)
            starNode.position = SCNVector3(x, y, z)
            // Billboard: always face camera via constraint
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            starNode.constraints = [constraint]
            scene.rootNode.addChildNode(starNode)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.fieldOfView = 65
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 100

        // Put camera on a pivot for orbit
        let cameraPivot = SCNNode()
        cameraPivot.position = SCNVector3(0, 5, 0)
        scene.rootNode.addChildNode(cameraPivot)

        cameraNode.position = SCNVector3(0, 0, 15)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 14, 0, 0)
        cameraPivot.addChildNode(cameraNode)

        let orbit = CABasicAnimation(keyPath: "rotation")
        orbit.fromValue = SCNVector4(0, 1, 0, 0)
        orbit.toValue = SCNVector4(0, 1, 0, Float.pi * 2)
        orbit.duration = 80
        orbit.repeatCount = .infinity
        orbit.timingFunction = CAMediaTimingFunction(name: .linear)
        cameraPivot.addAnimation(orbit, forKey: "cameraOrbit")
    }
}
