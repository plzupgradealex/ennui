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

    final class Coordinator: NSObject {
        var lastTapCount = 0
        var planetNodes: [SCNNode] = []
        var sceneRef: SCNScene?
        var nextOrbitRadius: Float = 19.0
        var idCounter = 100
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
        context.coordinator.sceneRef = scene

        // Configure camera controller for tidally-locked star orbit
        let cc = view.defaultCameraController
        cc.interactionMode = .orbitTurntable
        cc.inertiaEnabled = true
        cc.minimumVerticalAngle = -60
        cc.maximumVerticalAngle = 60
        cc.automaticTarget = false  // lock orbit center to star at origin
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount

        var rng = SplitMix64(seed: UInt64(tapCount * 53 + 7))
        let roll = rng.nextDouble()

        if roll < 0.80 {
            // ~80%: shimmer all planets
            for planet in c.planetNodes {
                let shimmer = SCNAction.sequence([
                    SCNAction.scale(to: 1.2, duration: 0.15),
                    SCNAction.scale(to: 0.9, duration: 0.1),
                    SCNAction.scale(to: 1.0, duration: 0.15)
                ])
                planet.runAction(shimmer)
            }
        } else if roll < 0.90, let scene = c.sceneRef {
            // ~10%: add a new planet
            let hue = rng.nextDouble()
            let radius = CGFloat(0.2 + rng.nextDouble() * 0.55)
            let orbitR = c.nextOrbitRadius
            c.nextOrbitRadius += Float(1.5 + rng.nextDouble() * 2.0)
            let orbitDur = Double(20 + rng.nextDouble() * 80)
            let hasRing = rng.nextDouble() > 0.6

            let pivot = SCNNode()
            pivot.eulerAngles.y = CGFloat(rng.nextDouble() * Double.pi * 2)
            scene.rootNode.addChildNode(pivot)
            pivot.runAction(SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: orbitDur)
            ))

            let sphere = SCNSphere(radius: radius)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(
                hue: CGFloat(hue), saturation: CGFloat(0.3 + rng.nextDouble() * 0.4),
                brightness: CGFloat(0.4 + rng.nextDouble() * 0.4), alpha: 1)
            mat.lightingModel = .phong; mat.shininess = 80
            sphere.materials = [mat]
            let pn = SCNNode(geometry: sphere)
            pn.position = SCNVector3(orbitR, 0, 0)
            pivot.addChildNode(pn)
            c.planetNodes.append(pn)

            pn.runAction(SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 5 + rng.nextDouble() * 6)
            ))

            if hasRing {
                let torus = SCNTorus(ringRadius: radius * 1.8, pipeRadius: radius * 0.12)
                let rm = SCNMaterial()
                rm.diffuse.contents = NSColor(
                    hue: CGFloat(hue + 0.05), saturation: 0.3, brightness: 0.5, alpha: 0.6)
                rm.isDoubleSided = true
                torus.materials = [rm]
                let rn = SCNNode(geometry: torus)
                rn.eulerAngles = SCNVector3(CGFloat.pi / 6, 0, CGFloat.pi / 10)
                pn.addChildNode(rn)
            }

            // Shimmer the new planet
            pn.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.3, duration: 0.15),
                SCNAction.scale(to: 1.0, duration: 0.2)
            ]))
        } else if !c.planetNodes.isEmpty, let scene = c.sceneRef {
            // ~10%: add a moon to a random planet
            let idx = Int(rng.nextDouble() * Double(c.planetNodes.count)) % c.planetNodes.count
            let parent = c.planetNodes[idx]
            let parentRadius = (parent.geometry as? SCNSphere)?.radius ?? 0.4
            let moonR = CGFloat(0.06 + rng.nextDouble() * 0.12)
            let moonOrbitR = parentRadius * CGFloat(2.0 + rng.nextDouble() * 2.0)

            let moonPivot = SCNNode()
            moonPivot.eulerAngles.y = CGFloat(rng.nextDouble() * Double.pi * 2)
            parent.addChildNode(moonPivot)
            moonPivot.runAction(SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: CGFloat(Double.pi * 2), z: 0, duration: 3 + rng.nextDouble() * 5)
            ))

            let moonSphere = SCNSphere(radius: moonR)
            let mm = SCNMaterial()
            mm.diffuse.contents = NSColor(white: CGFloat(0.5 + rng.nextDouble() * 0.3), alpha: 1)
            mm.lightingModel = .phong; mm.shininess = 60
            moonSphere.materials = [mm]
            let mn = SCNNode(geometry: moonSphere)
            mn.position = SCNVector3(moonOrbitR, 0, 0)
            moonPivot.addChildNode(mn)

            // Shimmer the parent
            parent.runAction(SCNAction.sequence([
                SCNAction.scale(to: 1.15, duration: 0.12),
                SCNAction.scale(to: 1.0, duration: 0.15)
            ]))
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
        starNode.name = "star"
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
            pivot.eulerAngles.y = CGFloat(rng.nextDouble() * Double.pi * 2)
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
                ringNode.eulerAngles = SCNVector3(CGFloat.pi / 6, 0, CGFloat.pi / 10)
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

    // MARK: - Camera (tidally locked to star)

    private func addCamera(to scene: SCNScene) {
        // Find the star node for the look-at constraint
        let starNode = scene.rootNode.childNode(withName: "star", recursively: false)

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zNear = 0.5
        cameraNode.camera!.zFar = 100
        cameraNode.camera!.fieldOfView = 60
        cameraNode.camera!.wantsHDR = true
        cameraNode.camera!.bloomIntensity = 0.3
        cameraNode.camera!.bloomThreshold = 0.8
        cameraNode.camera!.bloomBlurRadius = 6
        cameraNode.camera!.vignettingIntensity = 0.2
        cameraNode.camera!.vignettingPower = 1.0
        cameraNode.position = SCNVector3(0, 6, 20)
        scene.rootNode.addChildNode(cameraNode)

        // Tidally locked: always face the star
        if let star = starNode {
            let lookAt = SCNLookAtConstraint(target: star)
            lookAt.isGimbalLockEnabled = true
            cameraNode.constraints = [lookAt]
        }
    }
}
