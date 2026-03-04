// DesertStarscape3DScene — SceneKit desert night scene.
// Sandy floor, dunes, moon, cactus, billboard star field.
// Tap triggers a dust-devil particle burst.

import SwiftUI
import SceneKit

struct DesertStarscape3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        DesertStarscape3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct DesertStarscape3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var lastTapCount = 0
        var scene: SCNScene?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        context.coordinator.scene = scene
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount
        guard let scene = c.scene else { return }

        // Dust devil particle burst
        let ps = SCNParticleSystem()
        ps.birthRate = 200
        ps.particleLifeSpan = 1.5
        ps.particleSize = 0.06
        ps.emissionDuration = 0.3
        ps.loops = false
        ps.spreadingAngle = 35
        ps.emitterShape = SCNSphere(radius: 0.3)
        ps.particleColor = NSColor(red: 0.72, green: 0.55, blue: 0.28, alpha: 0.7)
        ps.particleColorVariation = SCNVector4(0.1, 0.1, 0.05, 0.2)
        ps.particleVelocity = 2.5
        ps.particleVelocityVariation = 1.5
        ps.acceleration = SCNVector3(0, 1.5, 0)
        ps.isLightingEnabled = false

        let burstNode = SCNNode()
        burstNode.position = SCNVector3(3, 0.5, 0)
        scene.rootNode.addChildNode(burstNode)
        burstNode.addParticleSystem(ps)

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            burstNode.removeFromParentNode()
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
        addLighting(to: scene)
        addFloor(to: scene)
        addDunes(to: scene)
        addMoon(to: scene)
        addCactus(to: scene)
        addStarField(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 25
        ambient.light!.color = NSColor(red: 0.06, green: 0.06, blue: 0.14, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Moonlight — faint blue-white directional
        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light!.type = .directional
        moonLight.light!.intensity = 120
        moonLight.light!.color = NSColor(red: 0.7, green: 0.75, blue: 1.0, alpha: 1)
        moonLight.light!.castsShadow = true
        moonLight.light!.shadowRadius = 4
        moonLight.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(moonLight)
    }

    // MARK: - Floor

    private func addFloor(to scene: SCNScene) {
        let floor = SCNFloor()
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.62, green: 0.52, blue: 0.32, alpha: 1)
        mat.lightingModel = .lambert
        floor.firstMaterial = mat
        floor.reflectivity = 0
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)
    }

    // MARK: - Dunes

    private func addDunes(to scene: SCNScene) {
        let positions: [(Float, Float, Float)] = [
            (-8, 0, -5), (-3, 0, -8), (2, 0, -6), (7, 0, -4), (0, 0, -10), (-5, 0, -12)
        ]
        for (i, pos) in positions.enumerated() {
            let geo = SCNPyramid(width: 4, height: 1.5, length: 3)
            let mat = SCNMaterial()
            mat.diffuse.contents = NSColor(red: 0.7 + CGFloat(i % 3) * 0.03, green: 0.58, blue: 0.35, alpha: 1)
            mat.lightingModel = .lambert
            geo.firstMaterial = mat

            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(pos.0, 0, pos.2)
            scene.rootNode.addChildNode(node)
        }
    }

    // MARK: - Moon

    private func addMoon(to scene: SCNScene) {
        let geo = SCNSphere(radius: 1.5)
        let mat = SCNMaterial()
        mat.diffuse.contents = NSColor(red: 0.88, green: 0.88, blue: 0.9, alpha: 1)
        mat.emission.contents = NSColor(red: 0.7, green: 0.7, blue: 0.75, alpha: 1)
        mat.lightingModel = .constant
        geo.firstMaterial = mat

        let moonNode = SCNNode(geometry: geo)
        moonNode.position = SCNVector3(10, 15, -20)
        scene.rootNode.addChildNode(moonNode)

        // Subtle glow pulse
        let pulse = CABasicAnimation(keyPath: "scale")
        pulse.fromValue = SCNVector3(1, 1, 1)
        pulse.toValue = SCNVector3(1.04, 1.04, 1.04)
        pulse.duration = 4
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        moonNode.addAnimation(pulse, forKey: "moonPulse")
    }

    // MARK: - Cactus

    private func addCactus(to scene: SCNScene) {
        let cactusNode = SCNNode()
        cactusNode.position = SCNVector3(3, 0, 0)

        let greenMat = SCNMaterial()
        greenMat.diffuse.contents = NSColor(red: 0.15, green: 0.45, blue: 0.18, alpha: 1)
        greenMat.lightingModel = .lambert

        // Main trunk
        let trunkGeo = SCNCylinder(radius: 0.1, height: 2)
        trunkGeo.firstMaterial = greenMat
        let trunkNode = SCNNode(geometry: trunkGeo)
        trunkNode.position = SCNVector3(0, 1, 0)
        cactusNode.addChildNode(trunkNode)

        // Left arm
        let leftArmGeo = SCNCylinder(radius: 0.07, height: 0.8)
        leftArmGeo.firstMaterial = greenMat
        let leftArm = SCNNode(geometry: leftArmGeo)
        leftArm.position = SCNVector3(-0.35, 1.2, 0)
        leftArm.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        cactusNode.addChildNode(leftArm)

        // Right arm
        let rightArmGeo = SCNCylinder(radius: 0.07, height: 0.8)
        rightArmGeo.firstMaterial = greenMat
        let rightArm = SCNNode(geometry: rightArmGeo)
        rightArm.position = SCNVector3(0.35, 1.5, 0)
        rightArm.eulerAngles = SCNVector3(0, 0, -Float.pi / 2)
        cactusNode.addChildNode(rightArm)

        scene.rootNode.addChildNode(cactusNode)
    }

    // MARK: - Star field (upper hemisphere)

    private func addStarField(to scene: SCNScene) {
        var rng = SplitMix64(seed: 3001)
        for _ in 0..<300 {
            let theta = Double.random(in: 0...(2 * .pi), using: &rng)
            // Upper hemisphere: phi in 0..pi/2
            let phi = Double.random(in: 0.05...(Double.pi / 2), using: &rng)
            let r   = Double.random(in: 18...25, using: &rng)
            let x = Float(r * sin(phi) * cos(theta))
            let y = Float(abs(r * cos(phi))) + 2
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
        cameraNode.camera!.fieldOfView = 68
        cameraNode.camera!.zNear = 0.1
        cameraNode.camera!.zFar = 100
        cameraNode.position = SCNVector3(0, 2.5, 8)
        cameraNode.eulerAngles = SCNVector3(-Float.pi / 14, 0, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Side-to-side pan
        let pan = CABasicAnimation(keyPath: "position.x")
        pan.fromValue = Float(-5)
        pan.toValue = Float(5)
        pan.duration = 120
        pan.autoreverses = true
        pan.repeatCount = .infinity
        pan.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.addAnimation(pan, forKey: "camPan")
    }
}
