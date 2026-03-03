// MedievalVillage3DScene — SceneKit experiment.
// Low-poly diorama of the same medieval hamlet, viewed from above.
// Camera slowly orbits. Warm point lights in windows. Tap to snuff a light.
// Fireflies drift. Fog rolls in. Moon casts blue directional light.

import SwiftUI
import SceneKit

struct MedievalVillage3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        MedievalVillage3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct MedievalVillage3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var windowLights: [SCNNode] = []
        var lastTapCount = 0
        var extinguishedIndex = 0
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = .black
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
        guard c.extinguishedIndex < c.windowLights.count else { return }

        let light = c.windowLights[c.extinguishedIndex]
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 2.0
        light.light?.intensity = 0
        SCNTransaction.commit()
        c.extinguishedIndex += 1
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        // Atmosphere
        scene.fogStartDistance = 12
        scene.fogEndDistance = 35
        scene.fogColor = NSColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 1)
        scene.background.contents = NSColor(red: 0.015, green: 0.015, blue: 0.04, alpha: 1)

        addLighting(to: scene)
        addGround(to: scene)
        addBuildings(to: scene, coord: coord)
        addTrees(to: scene)
        addFireflies(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        // Dim ambient — moonlit night
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 60
        ambient.light!.color = NSColor(red: 0.12, green: 0.10, blue: 0.22, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Moonlight — blue-silver directional
        let moon = SCNNode()
        moon.light = SCNLight()
        moon.light!.type = .directional
        moon.light!.intensity = 120
        moon.light!.color = NSColor(red: 0.35, green: 0.38, blue: 0.55, alpha: 1)
        moon.light!.castsShadow = true
        moon.light!.shadowRadius = 3
        moon.light!.shadowSampleCount = 4
        moon.eulerAngles = SCNVector3(-Float.pi / 3.5, Float.pi / 5, 0)
        scene.rootNode.addChildNode(moon)
    }

    // MARK: - Ground

    private func addGround(to scene: SCNScene) {
        let ground = SCNFloor()
        ground.reflectivity = 0.02
        ground.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.10, blue: 0.04, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: ground))

        // Slight path through village (flattened box)
        let path = SCNBox(width: 1.0, height: 0.01, length: 14, chamferRadius: 0)
        path.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.09, blue: 0.06, alpha: 1)
        let pathNode = SCNNode(geometry: path)
        pathNode.position = SCNVector3(0, 0.005, 0)
        scene.rootNode.addChildNode(pathNode)
    }

    // MARK: - Buildings

    private func addBuildings(to scene: SCNScene, coord: Coordinator) {
        var rng = SplitMix64(seed: 1350)

        struct Spot { let x: Float; let z: Float; let s: Float; let isChurch: Bool }
        let spots: [Spot] = [
            Spot(x: -3.2, z: -2.0, s: 1.0, isChurch: false),
            Spot(x: -1.0, z: -3.2, s: 0.8, isChurch: false),
            Spot(x:  1.2, z: -2.5, s: 1.1, isChurch: false),
            Spot(x:  3.0, z: -1.0, s: 0.9, isChurch: false),
            Spot(x: -2.2, z:  1.2, s: 0.85, isChurch: false),
            Spot(x:  0.5, z:  0.5, s: 1.15, isChurch: true),
            Spot(x:  2.5, z:  1.8, s: 0.95, isChurch: false),
        ]

        let wallColor = NSColor(red: 0.20, green: 0.16, blue: 0.10, alpha: 1)
        let roofColor = NSColor(red: 0.28, green: 0.18, blue: 0.08, alpha: 1)

        for spot in spots {
            let h = Float(spot.isChurch ? 2.8 : (1.0 + Double.random(in: 0...0.7, using: &rng)))
            let w = Float(spot.isChurch ? 1.3 : (0.7 + Double.random(in: 0...0.5, using: &rng)))
            let d = Float(spot.isChurch ? 1.3 : (0.6 + Double.random(in: 0...0.4, using: &rng)))
            let sw = w * spot.s
            let sh = h * spot.s
            let sd = d * spot.s

            // Body
            let box = SCNBox(width: CGFloat(sw), height: CGFloat(sh),
                             length: CGFloat(sd), chamferRadius: 0.02)
            box.firstMaterial?.diffuse.contents = wallColor
            let body = SCNNode(geometry: box)
            body.position = SCNVector3(spot.x, sh / 2, spot.z)
            body.castsShadow = true
            scene.rootNode.addChildNode(body)

            // Roof
            let roofH: Float = 0.55 * spot.s
            let pyramid = SCNPyramid(width: CGFloat(sw + 0.15),
                                     height: CGFloat(roofH),
                                     length: CGFloat(sd + 0.15))
            pyramid.firstMaterial?.diffuse.contents = roofColor
            let roof = SCNNode(geometry: pyramid)
            roof.position = SCNVector3(spot.x, sh + roofH / 2, spot.z)
            roof.castsShadow = true
            scene.rootNode.addChildNode(roof)

            // Window glow (small emissive plane + omni light)
            let windowW: CGFloat = CGFloat(sw * 0.22)
            let windowH: CGFloat = CGFloat(sh * 0.2)
            let winGeo = SCNPlane(width: windowW, height: windowH)
            let warmAmber = NSColor(red: 0.95, green: 0.7, blue: 0.3, alpha: 1)
            winGeo.firstMaterial?.emission.contents = warmAmber
            winGeo.firstMaterial?.diffuse.contents = NSColor.black
            winGeo.firstMaterial?.isDoubleSided = true
            let winNode = SCNNode(geometry: winGeo)
            winNode.position = SCNVector3(spot.x, sh * 0.4, spot.z + sd / 2 + 0.01)
            scene.rootNode.addChildNode(winNode)

            // Point light bleeding from window
            let light = SCNNode()
            light.light = SCNLight()
            light.light!.type = .omni
            light.light!.intensity = 250
            light.light!.color = warmAmber
            light.light!.attenuationStartDistance = 0
            light.light!.attenuationEndDistance = 2.5
            light.position = SCNVector3(spot.x, sh * 0.4, spot.z + sd / 2 + 0.15)
            scene.rootNode.addChildNode(light)
            coord.windowLights.append(light)
        }
    }

    // MARK: - Trees

    private func addTrees(to scene: SCNScene) {
        var rng = SplitMix64(seed: 1351)
        let trunkColor = NSColor(red: 0.18, green: 0.10, blue: 0.05, alpha: 1)
        let leafColor = NSColor(red: 0.05, green: 0.14, blue: 0.05, alpha: 1)

        for _ in 0..<12 {
            let tx = Float(Double.random(in: -6...6, using: &rng))
            let tz = Float(Double.random(in: -5...5, using: &rng))
            let ts = Float(0.5 + Double.random(in: 0...0.5, using: &rng))

            let trunk = SCNCylinder(radius: CGFloat(0.06 * ts), height: CGFloat(0.5 * ts))
            trunk.firstMaterial?.diffuse.contents = trunkColor
            let trunkNode = SCNNode(geometry: trunk)
            trunkNode.position = SCNVector3(tx, 0.25 * ts, tz)
            scene.rootNode.addChildNode(trunkNode)

            let canopy = SCNCone(topRadius: 0,
                                 bottomRadius: CGFloat(0.4 * ts),
                                 height: CGFloat(0.9 * ts))
            canopy.firstMaterial?.diffuse.contents = leafColor
            let canopyNode = SCNNode(geometry: canopy)
            canopyNode.position = SCNVector3(tx, 0.5 * ts + 0.45 * ts, tz)
            canopyNode.castsShadow = true
            scene.rootNode.addChildNode(canopyNode)
        }
    }

    // MARK: - Fireflies (particle system)

    private func addFireflies(to scene: SCNScene) {
        let sys = SCNParticleSystem()
        sys.birthRate = 3
        sys.particleLifeSpan = 7
        sys.particleSize = 0.025
        sys.particleColor = NSColor(red: 0.9, green: 0.8, blue: 0.3, alpha: 0.85)
        sys.particleColorVariation = SCNVector4(0.05, 0.1, 0, 0.15)
        sys.blendMode = .additive
        sys.spreadingAngle = 180
        sys.emittingDirection = SCNVector3(0, 1, 0)
        sys.particleVelocity = 0.08
        sys.particleVelocityVariation = 0.04
        sys.emitterShape = SCNBox(width: 10, height: 0.5, length: 8, chamferRadius: 0)

        let emitter = SCNNode()
        emitter.position = SCNVector3(0, 0.8, 0)
        emitter.addParticleSystem(sys)
        scene.rootNode.addChildNode(emitter)
    }

    // MARK: - Camera (slow orbit)

    private func addCamera(to scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 48
        camera.zNear = 0.1
        camera.zFar = 80
        // Slight bloom for a dreamy feel
        camera.wantsHDR = true
        camera.bloomIntensity = 0.3
        camera.bloomThreshold = 0.8

        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 7, 11)
        camNode.look(at: SCNVector3(0, 0.5, 0))

        let orbit = SCNNode()
        orbit.addChildNode(camNode)
        scene.rootNode.addChildNode(orbit)

        // Full revolution in 120 seconds — glacially slow
        orbit.runAction(.repeatForever(
            .rotateBy(x: 0, y: .pi * 2, z: 0, duration: 120)
        ))
    }
}
