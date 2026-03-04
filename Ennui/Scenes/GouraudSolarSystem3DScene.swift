// GouraudSolarSystem3DScene — Retro solar system with 6 orbiting planets.
// Central star, phong-lit planets with rings, 200 stars, camera orbit.
// Tap to shimmer all planets (scale pulse).

import SwiftUI
import SceneKit

struct GouraudSolarSystem3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        GouraudSolarSystem3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct GouraudSolarSystem3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var planetNodes: [SCNNode] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1)
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
        for planet in c.planetNodes {
            let shimmer = SCNAction.sequence([
                SCNAction.scale(to: 1.2, duration: 0.15),
                SCNAction.scale(to: 0.9, duration: 0.1),
                SCNAction.scale(to: 1.0, duration: 0.15)
            ])
            planet.runAction(shimmer)
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.0, green: 0.0, blue: 0.02, alpha: 1)
        addStar(to: scene)
        addPlanets(to: scene, coord: coord)
        addStars(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Central Star

    private func addStar(to scene: SCNScene) {
        let sphere = SCNSphere(radius: 1.2)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 1.0, green: 0.82, blue: 0.3, alpha: 1)
        mat.emission.contents = NSColor(red: 1.0, green: 0.65, blue: 0.15, alpha: 1)
        mat.lightingModel = .constant
        sphere.materials = [mat]
        let starNode = SCNNode(geometry: sphere)
        starNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(starNode)

        // Self-rotation
        let rot = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 20)
        starNode.runAction(SCNAction.repeatForever(rot))

        // Strong omni light from star
        let starLight = SCNNode()
        starLight.light = SCNLight()
        starLight.light!.type = .omni
        starLight.light!.intensity = 1200
        starLight.light!.color = NSColor(red: 1.0, green: 0.92, blue: 0.7, alpha: 1)
        starLight.light!.attenuationStartDistance = 1.5
        starLight.light!.attenuationEndDistance = 30
        starLight.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(starLight)

        // Faint ambient
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 15
        ambient.light!.color = NSColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    // MARK: - Planets

    private struct PlanetConfig {
        let radius: CGFloat
        let color: NSColor
        let orbitRadius: Float
        let orbitDuration: Double
        let hasRing: Bool
        let ringRadius: CGFloat
        let pipeRadius: CGFloat
    }

    private func addPlanets(to scene: SCNScene, coord: Coordinator) {
        let configs: [PlanetConfig] = [
            PlanetConfig(radius: 0.35,
                         color: NSColor(red: 0.5, green: 0.55, blue: 0.65, alpha: 1),
                         orbitRadius: 3.5, orbitDuration: 18,
                         hasRing: false, ringRadius: 0, pipeRadius: 0),
            PlanetConfig(radius: 0.55,
                         color: NSColor(red: 0.65, green: 0.3, blue: 0.2, alpha: 1),
                         orbitRadius: 5.5, orbitDuration: 28,
                         hasRing: false, ringRadius: 0, pipeRadius: 0),
            PlanetConfig(radius: 0.45,
                         color: NSColor(red: 0.2, green: 0.5, blue: 0.55, alpha: 1),
                         orbitRadius: 7.5, orbitDuration: 40,
                         hasRing: true, ringRadius: 0.7, pipeRadius: 0.05),
            PlanetConfig(radius: 0.70,
                         color: NSColor(red: 0.75, green: 0.65, blue: 0.38, alpha: 1),
                         orbitRadius: 10.0, orbitDuration: 55,
                         hasRing: true, ringRadius: 1.1, pipeRadius: 0.08),
            PlanetConfig(radius: 0.30,
                         color: NSColor(red: 0.6, green: 0.78, blue: 0.95, alpha: 1),
                         orbitRadius: 13.0, orbitDuration: 75,
                         hasRing: false, ringRadius: 0, pipeRadius: 0),
            PlanetConfig(radius: 0.25,
                         color: NSColor(red: 0.5, green: 0.4, blue: 0.6, alpha: 1),
                         orbitRadius: 16.0, orbitDuration: 100,
                         hasRing: false, ringRadius: 0, pipeRadius: 0),
        ]

        var rng = SplitMix64(seed: 2222)
        for (i, cfg) in configs.enumerated() {
            let pivot = SCNNode()
            pivot.position = SCNVector3(0, 0, 0)
            // Random start angle
            pivot.eulerAngles.y = Float(rng.nextDouble() * Double.pi * 2)
            scene.rootNode.addChildNode(pivot)

            // Orbit action
            let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: cfg.orbitDuration)
            pivot.runAction(SCNAction.repeatForever(orbit))

            // Planet node as child of pivot
            let sphere = SCNSphere(radius: cfg.radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = cfg.color
            mat.lightingModel = .phong
            mat.shininess = 80
            sphere.materials = [mat]
            let planetNode = SCNNode(geometry: sphere)
            planetNode.position = SCNVector3(cfg.orbitRadius, 0, 0)
            pivot.addChildNode(planetNode)
            coord.planetNodes.append(planetNode)

            // Planet self-rotation
            let selfRot = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0,
                                              duration: 4.0 + Double(i) * 1.5)
            planetNode.runAction(SCNAction.repeatForever(selfRot))

            // Optional ring
            if cfg.hasRing {
                let torus = SCNTorus(ringRadius: cfg.ringRadius, pipeRadius: cfg.pipeRadius)
                let ringMat = SCNMaterial()
                ringMat.diffuse.contents = cfg.color.withAlphaComponent(0.6)
                ringMat.isDoubleSided = true
                torus.materials = [ringMat]
                let ringNode = SCNNode(geometry: torus)
                ringNode.eulerAngles = SCNVector3(Float.pi / 6, 0, Float.pi / 10)
                planetNode.addChildNode(ringNode)
            }
        }
    }

    // MARK: - Background Stars

    private func addStars(to scene: SCNScene) {
        var rng = SplitMix64(seed: 2222)
        for _ in 0..<200 {
            let plane = SCNPlane(width: 0.04, height: 0.04)
            let mat = SCNMaterial()
            let brightness = Float(0.65 + rng.nextDouble() * 0.35)
            let blueShift = Float(rng.nextDouble() * 0.2)
            mat.diffuse.contents = NSColor(
                red: CGFloat(brightness),
                green: CGFloat(brightness),
                blue: CGFloat(min(1.0, brightness + blueShift)),
                alpha: 1
            )
            mat.emission.contents = mat.diffuse.contents
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            plane.materials = [mat]
            let starNode = SCNNode(geometry: plane)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            starNode.constraints = [constraint]
            starNode.position = SCNVector3(
                Float(rng.nextDouble() * 80 - 40),
                Float(rng.nextDouble() * 60 - 20),
                Float(rng.nextDouble() * -60 - 20)
            )
            scene.rootNode.addChildNode(starNode)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let pivot = SCNNode()
        pivot.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(pivot)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 80
        cameraNode.camera!.fieldOfView = 65
        cameraNode.position = SCNVector3(0, 8, 18)
        cameraNode.eulerAngles = SCNVector3(-0.42, 0, 0)
        pivot.addChildNode(cameraNode)

        let orbit = SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 90)
        pivot.runAction(SCNAction.repeatForever(orbit))
    }
}
