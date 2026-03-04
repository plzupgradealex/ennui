// CaptainStar3DScene — Alien desert planet with floating rocks and glass outpost.
// Ochre floor, floating rocks, glass outpost, planetary rings, dust particles, stars.
// Tap to luminous pulse (flash all lights).

import SwiftUI
import SceneKit

struct CaptainStar3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        CaptainStar3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct CaptainStar3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var allLights: [SCNNode] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.12, green: 0.09, blue: 0.04, alpha: 1)
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
        // Flash all lights to 3x intensity then fade back
        for lightNode in c.allLights {
            guard let light = lightNode.light else { continue }
            let originalIntensity = light.intensity
            let flash = SCNAction.customAction(duration: 1.5) { _, elapsed in
                let t = Float(elapsed / 1.5)
                light.intensity = CGFloat(originalIntensity) * CGFloat(1.0 + 2.0 * (1.0 - t))
            }
            lightNode.runAction(flash)
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.12, green: 0.09, blue: 0.04, alpha: 1)
        scene.fogStartDistance = 18
        scene.fogEndDistance = 35
        scene.fogColor = NSColor(red: 0.14, green: 0.10, blue: 0.05, alpha: 1)
        addLighting(to: scene, coord: coord)
        addFloor(to: scene)
        addFloatingRocks(to: scene)
        addGlassOutpost(to: scene, coord: coord)
        addPlanetaryRings(to: scene)
        addDust(to: scene)
        addStars(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene, coord: Coordinator) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 50
        ambient.light!.color = NSColor(red: 0.7, green: 0.55, blue: 0.3, alpha: 1)
        scene.rootNode.addChildNode(ambient)
        coord.allLights.append(ambient)

        // Low-angle golden directional sun
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light!.type = .directional
        sun.light!.intensity = 300
        sun.light!.color = NSColor(red: 1.0, green: 0.78, blue: 0.35, alpha: 1)
        sun.eulerAngles = SCNVector3(-Float.pi / 8, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)
        coord.allLights.append(sun)
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        floor.reflectivity = 0.01
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.55, green: 0.35, blue: 0.15, alpha: 1)
        mat.roughness.contents = 0.95
        floor.materials = [mat]
        scene.rootNode.addChildNode(SCNNode(geometry: floor))
    }

    // MARK: - Floating Rocks

    private func addFloatingRocks(to scene: SCNScene) {
        var rng = SplitMix64(seed: 1111)
        let rockColors: [NSColor] = [
            NSColor(red: 0.55, green: 0.48, blue: 0.38, alpha: 1),
            NSColor(red: 0.48, green: 0.42, blue: 0.30, alpha: 1),
            NSColor(red: 0.60, green: 0.50, blue: 0.35, alpha: 1),
        ]
        for i in 0..<5 {
            let size = Float(0.5 + rng.nextDouble() * 1.0)
            let rock = SCNBox(
                width: CGFloat(size),
                height: CGFloat(size * (0.7 + Float(rng.nextDouble()) * 0.6)),
                length: CGFloat(size * (0.7 + Float(rng.nextDouble()) * 0.6)),
                chamferRadius: CGFloat(size * 0.3)
            )
            let mat = SCNMaterial()
            mat.diffuse.contents = rockColors[i % rockColors.count]
            rock.materials = [mat]
            let rockNode = SCNNode(geometry: rock)
            let x = Float(rng.nextDouble() * 10 - 5)
            let y = Float(1.0 + rng.nextDouble() * 3.0)
            let z = Float(-3.0 - rng.nextDouble() * 5.0)
            rockNode.position = SCNVector3(x, y, z)
            rockNode.eulerAngles = SCNVector3(
                Float(rng.nextDouble() * Double.pi),
                Float(rng.nextDouble() * Double.pi),
                Float(rng.nextDouble() * Double.pi * 0.3)
            )
            scene.rootNode.addChildNode(rockNode)

            // Slow rotation
            let rotDur = 12.0 + rng.nextDouble() * 10.0
            let rot = SCNAction.rotateBy(x: CGFloat(rng.nextDouble() * 0.5),
                                          y: CGFloat(Double.pi * 2),
                                          z: CGFloat(rng.nextDouble() * 0.3),
                                          duration: rotDur)
            rockNode.runAction(SCNAction.repeatForever(rot))

            // Gentle bob
            let bobAmt = Float(0.15 + rng.nextDouble() * 0.2)
            let bobDur = 3.0 + rng.nextDouble() * 3.0
            let bob = SCNAction.sequence([
                SCNAction.moveBy(x: 0, y: CGFloat(bobAmt), z: 0, duration: bobDur),
                SCNAction.moveBy(x: 0, y: CGFloat(-bobAmt), z: 0, duration: bobDur)
            ])
            rockNode.runAction(SCNAction.repeatForever(bob))
        }
    }

    // MARK: - Glass Outpost

    private func addGlassOutpost(to scene: SCNScene, coord: Coordinator) {
        let box = SCNBox(width: 2, height: 2.5, length: 2, chamferRadius: 0.05)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.7, green: 0.85, blue: 0.9, alpha: 0.4)
        mat.transparency = 0.6
        mat.lightingModel = .constant
        mat.isDoubleSided = true
        box.materials = [mat]
        let outpostNode = SCNNode(geometry: box)
        outpostNode.position = SCNVector3(3, 1.25, -5)
        scene.rootNode.addChildNode(outpostNode)

        // Interior warm light
        let interiorLight = SCNNode()
        interiorLight.light = SCNLight()
        interiorLight.light!.type = .omni
        interiorLight.light!.intensity = 150
        interiorLight.light!.color = NSColor(red: 1.0, green: 0.78, blue: 0.45, alpha: 1)
        interiorLight.light!.attenuationStartDistance = 0.5
        interiorLight.light!.attenuationEndDistance = 4.0
        interiorLight.position = SCNVector3(3, 1.5, -5)
        scene.rootNode.addChildNode(interiorLight)
        coord.allLights.append(interiorLight)
    }

    // MARK: - Planetary Rings

    private func addPlanetaryRings(to scene: SCNScene) {
        let torus = SCNTorus(ringRadius: 25, pipeRadius: 0.3)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.42, green: 0.35, blue: 0.25, alpha: 0.55)
        mat.isDoubleSided = true
        torus.materials = [mat]
        let torusNode = SCNNode(geometry: torus)
        torusNode.position = SCNVector3(0, -22, -30)
        torusNode.eulerAngles = SCNVector3(Float.pi / 16, 0, Float.pi / 20)
        scene.rootNode.addChildNode(torusNode)
    }

    // MARK: - Dust

    private func addDust(to scene: SCNScene) {
        let ps = SCNParticleSystem()
        ps.birthRate = 15
        ps.particleLifeSpan = 5.0
        ps.emitterShape = SCNBox(width: 12, height: 2, length: 12, chamferRadius: 0)
        ps.particleSize = 0.05
        ps.particleColor = NSColor(red: 0.75, green: 0.6, blue: 0.38, alpha: 0.6)
        ps.isAffectedByGravity = false
        ps.particleVelocity = 0.4
        ps.particleVelocityVariation = 0.3
        ps.spreadingAngle = 60
        let dustNode = SCNNode()
        dustNode.position = SCNVector3(0, 1.5, -4)
        scene.rootNode.addChildNode(dustNode)
        dustNode.addParticleSystem(ps)
    }

    // MARK: - Stars

    private func addStars(to scene: SCNScene) {
        var rng = SplitMix64(seed: 1112)
        for _ in 0..<100 {
            let plane = SCNPlane(width: 0.06, height: 0.06)
            let mat = SCNMaterial()
            let brightness = Float(0.7 + rng.nextDouble() * 0.3)
            mat.diffuse.contents = NSColor(red: CGFloat(brightness), green: CGFloat(brightness), blue: CGFloat(brightness * 0.9), alpha: 1)
            mat.emission.contents = NSColor(red: CGFloat(brightness), green: CGFloat(brightness), blue: CGFloat(brightness), alpha: 1)
            mat.lightingModel = .constant
            mat.isDoubleSided = true
            plane.materials = [mat]
            let starNode = SCNNode(geometry: plane)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = .all
            starNode.constraints = [constraint]
            starNode.position = SCNVector3(
                Float(rng.nextDouble() * 60 - 30),
                Float(rng.nextDouble() * 20 + 5),
                Float(rng.nextDouble() * -40 - 5)
            )
            scene.rootNode.addChildNode(starNode)
        }
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera!.zFar = 60
        cameraNode.camera!.fieldOfView = 75
        cameraNode.position = SCNVector3(0, 1.8, 6.0)
        cameraNode.eulerAngles = SCNVector3(-0.1, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Drift forward slowly
        let drift = SCNAction.customAction(duration: 60) { node, time in
            let t = Float(time / 60)
            node.position = SCNVector3(0, 1.8, 6.0 - t * 8.0)
        }
        let reset = SCNAction.customAction(duration: 0) { node, _ in
            node.position = SCNVector3(0, 1.8, 6.0)
        }
        cameraNode.runAction(SCNAction.repeatForever(SCNAction.sequence([drift, reset])))
    }
}
