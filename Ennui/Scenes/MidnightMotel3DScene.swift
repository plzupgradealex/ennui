import SwiftUI
import SceneKit

struct MidnightMotel3DScene: View {
    @ObservedObject var interaction: InteractionState
    var body: some View { MidnightMotel3DRepresentable(interaction: interaction) }
}

private struct MidnightMotel3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var headlight: SCNNode?
    }
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> SCNView {
        let view = SCNView()
        let scene = SCNScene()
        view.scene = scene
        view.backgroundColor = NSColor(red: 0.03, green: 0.02, blue: 0.02, alpha: 1)
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
        triggerHeadlightSweep(coord: c)
    }

    private func triggerHeadlightSweep(coord: Coordinator) {
        guard let headlightNode = coord.headlight else { return }
        let sweep = SCNAction.sequence([
            SCNAction.customAction(duration: 3.0) { node, elapsed in
                let t = Float(elapsed / 3.0)
                // Fade in quickly, sweep, fade out
                let intensity: CGFloat
                if t < 0.15 {
                    intensity = CGFloat(800 * (t / 0.15))
                } else if t < 0.85 {
                    intensity = 800
                } else {
                    intensity = CGFloat(800 * (1.0 - (t - 0.85) / 0.15))
                }
                node.light?.intensity = intensity
                // Sweep position across ceiling
                let sweepT = (t - 0.15) / 0.7
                let clampedT = max(0, min(1, sweepT))
                node.position = SCNVector3(-2.5 + clampedT * 5, 1.9, 1.0)
            }
        ])
        headlightNode.runAction(sweep)
    }

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        let wallColor = NSColor(red: 0.18, green: 0.10, blue: 0.06, alpha: 1)

        // Floor
        let floor = SCNFloor()
        floor.reflectivity = 0.05
        floor.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.10, blue: 0.06, alpha: 1)
        let floorNode = SCNNode(geometry: floor)
        scene.rootNode.addChildNode(floorNode)

        // Back wall
        let backWallGeo = SCNPlane(width: 5, height: 3)
        backWallGeo.firstMaterial?.diffuse.contents = wallColor
        backWallGeo.firstMaterial?.isDoubleSided = true
        let backWall = SCNNode(geometry: backWallGeo)
        backWall.position = SCNVector3(0, 1.5, -1.5)
        scene.rootNode.addChildNode(backWall)

        // Left wall
        let leftWallGeo = SCNPlane(width: 5, height: 3)
        leftWallGeo.firstMaterial?.diffuse.contents = wallColor
        leftWallGeo.firstMaterial?.isDoubleSided = true
        let leftWall = SCNNode(geometry: leftWallGeo)
        leftWall.position = SCNVector3(-2.5, 1.5, 0)
        leftWall.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
        scene.rootNode.addChildNode(leftWall)

        // Right wall
        let rightWallGeo = SCNPlane(width: 5, height: 3)
        rightWallGeo.firstMaterial?.diffuse.contents = wallColor
        rightWallGeo.firstMaterial?.isDoubleSided = true
        let rightWall = SCNNode(geometry: rightWallGeo)
        rightWall.position = SCNVector3(2.5, 1.5, 0)
        rightWall.eulerAngles = SCNVector3(0, -Float.pi / 2, 0)
        scene.rootNode.addChildNode(rightWall)

        // Bed
        let bed = SCNBox(width: 1.8, height: 0.3, length: 2, chamferRadius: 0.03)
        bed.firstMaterial?.diffuse.contents = NSColor(red: 0.35, green: 0.08, blue: 0.10, alpha: 1)
        let bedNode = SCNNode(geometry: bed)
        bedNode.position = SCNVector3(0, 0.15, 0.5)
        scene.rootNode.addChildNode(bedNode)

        // Pillow
        let pillow = SCNBox(width: 0.5, height: 0.1, length: 0.35, chamferRadius: 0.04)
        pillow.firstMaterial?.diffuse.contents = NSColor(red: 0.9, green: 0.88, blue: 0.85, alpha: 1)
        let pillowNode = SCNNode(geometry: pillow)
        pillowNode.position = SCNVector3(0, 0.35, -0.45)
        scene.rootNode.addChildNode(pillowNode)

        // Bedside lamp base
        let lampBase = SCNCylinder(radius: 0.08, height: 0.3)
        lampBase.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.20, blue: 0.15, alpha: 1)
        let lampBaseNode = SCNNode(geometry: lampBase)
        lampBaseNode.position = SCNVector3(1.2, 0.45, -0.5)
        scene.rootNode.addChildNode(lampBaseNode)

        // Bedside lamp shade
        let lampShade = SCNSphere(radius: 0.12)
        lampShade.firstMaterial?.diffuse.contents = NSColor(red: 0.95, green: 0.70, blue: 0.35, alpha: 1)
        lampShade.firstMaterial?.emission.contents = NSColor(red: 0.95, green: 0.70, blue: 0.35, alpha: 0.8)
        let lampShadeNode = SCNNode(geometry: lampShade)
        lampShadeNode.position = SCNVector3(1.2, 0.72, -0.5)
        scene.rootNode.addChildNode(lampShadeNode)

        // Bedside omni light
        let bedsideLight = SCNLight()
        bedsideLight.type = .omni
        bedsideLight.color = NSColor(red: 1.0, green: 0.65, blue: 0.30, alpha: 1)
        bedsideLight.intensity = 80
        bedsideLight.attenuationStartDistance = 0.3
        bedsideLight.attenuationEndDistance = 3.0
        let bedsideLightNode = SCNNode()
        bedsideLightNode.light = bedsideLight
        bedsideLightNode.position = SCNVector3(1.2, 0.72, -0.5)
        scene.rootNode.addChildNode(bedsideLightNode)

        // Window on back wall
        let windowGeo = SCNPlane(width: 1.0, height: 1.2)
        windowGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
        windowGeo.firstMaterial?.lightingModel = .constant
        let windowNode = SCNNode(geometry: windowGeo)
        windowNode.position = SCNVector3(0, 1.6, -1.49)
        scene.rootNode.addChildNode(windowNode)

        // Curtains on each side of window
        let curtainColor = NSColor(red: 0.35, green: 0.07, blue: 0.09, alpha: 1)
        for cx in [-0.78, 0.78] as [Float] {
            let curtain = SCNPlane(width: 0.55, height: 1.2)
            curtain.firstMaterial?.diffuse.contents = curtainColor
            curtain.firstMaterial?.isDoubleSided = true
            let curtainNode = SCNNode(geometry: curtain)
            curtainNode.position = SCNVector3(cx, 1.6, -1.48)
            scene.rootNode.addChildNode(curtainNode)
        }

        // Neon sign glow near window
        let neonLight = SCNLight()
        neonLight.type = .omni
        neonLight.color = NSColor(red: 0.9, green: 0.15, blue: 0.3, alpha: 1)
        neonLight.intensity = 60
        neonLight.attenuationStartDistance = 0.2
        neonLight.attenuationEndDistance = 3.0
        let neonLightNode = SCNNode()
        neonLightNode.light = neonLight
        neonLightNode.position = SCNVector3(0, 1.8, -1.4)
        scene.rootNode.addChildNode(neonLightNode)

        // Neon pulse animation
        let neonPulse = SCNAction.repeatForever(
            SCNAction.customAction(duration: 2.0) { node, elapsed in
                let t = Float(elapsed / 2.0) * Float.pi * 2
                node.light?.intensity = CGFloat(60 + 25 * sin(t))
            }
        )
        neonLightNode.runAction(neonPulse)

        // Headlight spotlight
        let headlightLight = SCNLight()
        headlightLight.type = .spot
        headlightLight.color = NSColor.white
        headlightLight.intensity = 0
        headlightLight.spotInnerAngle = 15
        headlightLight.spotOuterAngle = 35
        let headlightNode = SCNNode()
        headlightNode.light = headlightLight
        headlightNode.position = SCNVector3(-2.5, 1.9, 1.0)
        headlightNode.eulerAngles = SCNVector3(-Float.pi / 6, 0, 0)
        scene.rootNode.addChildNode(headlightNode)
        coord.headlight = headlightNode

        // Automatic headlight sweep every 10s
        let autoSweep = SCNAction.repeatForever(SCNAction.sequence([
            SCNAction.wait(duration: 10.0),
            SCNAction.customAction(duration: 3.0) { node, elapsed in
                let t = Float(elapsed / 3.0)
                let intensity: CGFloat
                if t < 0.15 {
                    intensity = CGFloat(800 * (t / 0.15))
                } else if t < 0.85 {
                    intensity = 800
                } else {
                    intensity = CGFloat(800 * (1.0 - (t - 0.85) / 0.15))
                }
                node.light?.intensity = intensity
                let sweepT = max(0, min(1, (t - 0.15) / 0.7))
                node.position = SCNVector3(-2.5 + sweepT * 5, 1.9, 1.0)
            }
        ]))
        headlightNode.runAction(autoSweep)

        // Ambient light
        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = NSColor(red: 0.05, green: 0.03, blue: 0.03, alpha: 1)
        ambientLight.intensity = 120
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Camera: first-person from bed looking toward window/back wall
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.zFar = 30
        cameraNode.camera?.fieldOfView = 72
        cameraNode.position = SCNVector3(0, 0.8, 2.2)
        scene.rootNode.addChildNode(cameraNode)

        let lookAt = SCNLookAtConstraint(target: backWall)
        lookAt.isGimbalLockEnabled = true
        cameraNode.constraints = [lookAt]
    }
}
