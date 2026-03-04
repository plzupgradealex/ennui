import SwiftUI
import SceneKit

struct NightTrain3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { NightTrain3DRepresentable(interaction: interaction) }
}

private struct NightTrain3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var windowLights: [SCNNode] = []
        var nextWindow = 0
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.02, green: 0.03, blue: 0.08, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = true
        buildScene(scene, coord: context.coordinator)
        return view
    }

    func updateNSView(_ nsView: SCNView, context: Context) {
        let c = context.coordinator
        guard interaction.tapCount != c.lastTapCount else { return }
        c.lastTapCount = interaction.tapCount
        // Cycle through window lights with intensity spike
        guard !c.windowLights.isEmpty else { return }
        let lightNode = c.windowLights[c.nextWindow % c.windowLights.count]
        c.nextWindow += 1
        let spike = SCNAction.customAction(duration: 1.0) { node, elapsed in
            let t = Float(elapsed / 1.0)
            let intensity: CGFloat = t < 0.1
                ? CGFloat(80 + 320 * (t / 0.1))
                : CGFloat(400 - 320 * ((t - 0.1) / 0.9))
            node.light?.intensity = intensity
        }
        lightNode.runAction(spike)
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        let carriageColor = NSColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1)
        let fabricColor = NSColor(red: 0.10, green: 0.12, blue: 0.20, alpha: 1)
        let seatColor = NSColor(red: 0.18, green: 0.20, blue: 0.30, alpha: 1)

        // Floor
        let floor = SCNBox(width: 3, height: 0.05, length: 6, chamferRadius: 0)
        floor.firstMaterial?.diffuse.contents = carriageColor
        let floorNode = SCNNode(geometry: floor)
        floorNode.position = SCNVector3(0, 0, 0)
        scene.rootNode.addChildNode(floorNode)

        // Ceiling
        let ceiling = SCNBox(width: 3, height: 0.05, length: 6, chamferRadius: 0)
        ceiling.firstMaterial?.diffuse.contents = carriageColor
        let ceilingNode = SCNNode(geometry: ceiling)
        ceilingNode.position = SCNVector3(0, 2, 0)
        scene.rootNode.addChildNode(ceilingNode)

        // Side walls
        for sx in [-1.5, 1.5] as [Float] {
            let wall = SCNBox(width: 0.1, height: 2, length: 6, chamferRadius: 0)
            wall.firstMaterial?.diffuse.contents = fabricColor
            let wallNode = SCNNode(geometry: wall)
            wallNode.position = SCNVector3(sx, 1.0, 0)
            scene.rootNode.addChildNode(wallNode)
        }

        // 3 seat rows
        let seatZPositions: [Float] = [-1.5, 0, 1.5]
        for rz in seatZPositions {
            for sx in [-0.85, 0.85] as [Float] {
                // Seat
                let seat = SCNBox(width: 0.5, height: 0.4, length: 0.45, chamferRadius: 0.02)
                seat.firstMaterial?.diffuse.contents = seatColor
                let seatNode = SCNNode(geometry: seat)
                seatNode.position = SCNVector3(sx, 0.45, rz)
                scene.rootNode.addChildNode(seatNode)

                // Backrest
                let back = SCNBox(width: 0.5, height: 0.5, length: 0.08, chamferRadius: 0.02)
                back.firstMaterial?.diffuse.contents = seatColor
                let backNode = SCNNode(geometry: back)
                backNode.position = SCNVector3(sx, 0.9, rz - 0.2)
                scene.rootNode.addChildNode(backNode)
            }
        }

        // 3 windows on right wall (x = 1.5)
        let windowZPositions: [Float] = [-1.5, 0, 1.5]
        for wz in windowZPositions {
            let window = SCNPlane(width: 0.6, height: 0.5)
            window.firstMaterial?.diffuse.contents = NSColor(red: 0.05, green: 0.08, blue: 0.15, alpha: 1)
            window.firstMaterial?.emission.contents = NSColor(red: 0.08, green: 0.12, blue: 0.22, alpha: 0.5)
            window.firstMaterial?.lightingModel = .constant
            window.firstMaterial?.isDoubleSided = true
            let windowNode = SCNNode(geometry: window)
            windowNode.position = SCNVector3(1.45, 1.1, wz)
            windowNode.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
            scene.rootNode.addChildNode(windowNode)

            // Amber light above window
            let wLight = SCNLight()
            wLight.type = .omni
            wLight.color = NSColor(red: 1.0, green: 0.75, blue: 0.45, alpha: 1)
            wLight.intensity = 80
            wLight.attenuationStartDistance = 0.3
            wLight.attenuationEndDistance = 2.0
            let wLightNode = SCNNode()
            wLightNode.light = wLight
            wLightNode.position = SCNVector3(1.2, 1.45, wz)
            scene.rootNode.addChildNode(wLightNode)
            coord.windowLights.append(wLightNode)
        }

        // Moving landscape particles from middle window
        let landscape = SCNParticleSystem()
        landscape.birthRate = 8
        landscape.particleLifeSpan = 4.0
        landscape.particleSize = 0.04
        landscape.particleColor = NSColor.white.withAlphaComponent(0.7)
        landscape.emittingDirection = SCNVector3(-1, 0, 1)
        landscape.spreadingAngle = 20
        landscape.particleVelocity = 1.5
        landscape.isAffectedByGravity = false
        landscape.loops = true
        let landscapeEmitter = SCNNode()
        landscapeEmitter.position = SCNVector3(1.4, 1.1, 0)
        landscapeEmitter.addParticleSystem(landscape)
        scene.rootNode.addChildNode(landscapeEmitter)

        // Overhead lights: 3 small amber spheres along ceiling
        let overheadZPositions: [Float] = [-1.5, 0, 1.5]
        for oz in overheadZPositions {
            let bulb = SCNSphere(radius: 0.05)
            bulb.firstMaterial?.diffuse.contents = NSColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 1)
            bulb.firstMaterial?.emission.contents = NSColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 0.9)
            let bulbNode = SCNNode(geometry: bulb)
            bulbNode.position = SCNVector3(0, 1.9, oz)
            scene.rootNode.addChildNode(bulbNode)

            let overheadLight = SCNLight()
            overheadLight.type = .omni
            overheadLight.color = NSColor(red: 1.0, green: 0.8, blue: 0.5, alpha: 1)
            overheadLight.intensity = 120
            overheadLight.attenuationStartDistance = 0.5
            overheadLight.attenuationEndDistance = 3.5
            let overheadLightNode = SCNNode()
            overheadLightNode.light = overheadLight
            overheadLightNode.position = SCNVector3(0, 1.9, oz)
            scene.rootNode.addChildNode(overheadLightNode)
        }

        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.06, green: 0.07, blue: 0.12, alpha: 1)
        ambientLight.intensity = 200
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Camera: first-person from seat area, looking forward (-z)
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 30
        cameraNode.camera?.fieldOfView = 75
        cameraNode.position = SCNVector3(0, 1.2, 2)
        cameraNode.eulerAngles = SCNVector3(0, Float.pi, 0)
        scene.rootNode.addChildNode(cameraNode)

        // Gentle rocking: ±0.5° around Z over 4s
        let rockRight = SCNAction.rotateBy(x: 0, y: 0, z: -0.5 * CGFloat.pi / 180, duration: 4.0)
        rockRight.timingMode = SCNActionTimingMode.easeInEaseOut
        let rockLeft = SCNAction.rotateBy(x: 0, y: 0, z: 0.5 * CGFloat.pi / 180, duration: 4.0)
        rockLeft.timingMode = SCNActionTimingMode.easeInEaseOut
        cameraNode.runAction(SCNAction.repeatForever(SCNAction.sequence([rockRight, rockLeft])))
    }
}
