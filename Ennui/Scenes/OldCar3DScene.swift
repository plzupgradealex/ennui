// OldCar3DScene — SceneKit version of the vintage car snowstorm.
// First-person view from inside a 1950s land yacht: bench seat like a
// church pew, big chrome-knobbed radio, incandescent dash lights, a wide
// windshield with sweeping wiper blades. Snow rushes at the glass.
// Utility poles and barn silhouettes pass in the dark.
// Tap to flash the dash lights (honk) and release a burst of snow.

import SwiftUI
import SceneKit

struct OldCar3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        OldCar3DRepresentable(interaction: interaction)
    }
}

// MARK: - NSViewRepresentable

private struct OldCar3DRepresentable: NSViewRepresentable {
    @ObservedObject var interaction: InteractionState

    final class Coordinator {
        var lastTapCount = 0
        var dashLight: SCNNode?
        var wiperLeft: SCNNode?
        var wiperRight: SCNNode?
        var snowSystem: SCNNode?
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
        // Horn flash — briefly brighten dash light
        if let dl = c.dashLight {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.0
            dl.light?.intensity = 320
            SCNTransaction.commit()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.4
                dl.light?.intensity = 80
                SCNTransaction.commit()
            }
        }
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.background.contents = NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)
        addExteriorEnvironment(to: scene)
        addCarInterior(to: scene, coord: coord)
        addWindshieldAndWipers(to: scene, coord: coord)
        addDashboard(to: scene, coord: coord)
        addRadio(to: scene)
        addBenchSeat(to: scene)
        addSnowParticles(to: scene, coord: coord)
        addLighting(to: scene, coord: coord)
        addCamera(to: scene)
    }

    // MARK: - Exterior (stormy sky, road, poles, barn)

    private func addExteriorEnvironment(to scene: SCNScene) {
        // Sky dome — dark stormy blue-black
        let skyDome = SCNSphere(radius: 40)
        skyDome.segmentCount = 24
        let skyMat = SCNMaterial()
        skyMat.diffuse.contents = NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1)
        skyMat.isDoubleSided = true
        skyDome.firstMaterial = skyMat
        let skyNode = SCNNode(geometry: skyDome)
        scene.rootNode.addChildNode(skyNode)

        // Cloud masses — large dark translucent planes
        for i in 0..<8 {
            let angle = Double(i) / 8.0 * .pi * 2
            let r: Float = 20
            let cloud = SCNPlane(width: 14, height: 6)
            let cloudMat = SCNMaterial()
            cloudMat.diffuse.contents = NSColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 0.45)
            cloudMat.isDoubleSided = true
            cloudMat.blendMode = .alpha
            cloud.firstMaterial = cloudMat
            let cloudNode = SCNNode(geometry: cloud)
            cloudNode.position = SCNVector3(
                Float(cos(angle)) * r,
                Float.random(in: 3...8),
                Float(sin(angle)) * r
            )
            cloudNode.eulerAngles = SCNVector3(Float(-0.2), Float(angle), 0)
            scene.rootNode.addChildNode(cloudNode)

            // Slow drift animation
            let drift = SCNAction.repeatForever(.sequence([
                .moveBy(x: 0.3, y: 0, z: 0, duration: 8),
                .moveBy(x: -0.3, y: 0, z: 0, duration: 8),
            ]))
            cloudNode.runAction(drift)
        }

        // Road — long flat plane stretching ahead
        let road = SCNPlane(width: 12, height: 80)
        let roadMat = SCNMaterial()
        roadMat.diffuse.contents = NSColor(red: 0.14, green: 0.13, blue: 0.12, alpha: 1)
        road.firstMaterial = roadMat
        let roadNode = SCNNode(geometry: road)
        roadNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        roadNode.position = SCNVector3(0, -1.5, -18)
        scene.rootNode.addChildNode(roadNode)

        // Road centre dashes — scroll toward viewer
        for i in 0..<12 {
            let dash = SCNBox(width: 0.15, height: 0.01, length: 1.5, chamferRadius: 0)
            dash.firstMaterial?.diffuse.contents = NSColor(red: 0.80, green: 0.76, blue: 0.60, alpha: 0.55)
            let dashNode = SCNNode(geometry: dash)
            dashNode.position = SCNVector3(0, -1.49, Float(-3 - i * 5))
            scene.rootNode.addChildNode(dashNode)

            // Scroll animation: move from z=-3 to z=10 then teleport back
            let scroll = SCNAction.repeatForever(.sequence([
                .moveBy(x: 0, y: 0, z: 58, duration: 4.5),
                .move(to: SCNVector3(0, -1.49, Float(-3 - i * 5)), duration: 0),
            ]))
            dashNode.runAction(scroll)
        }

        // Snowy road surface overlay — white tint on road
        let snowRoad = SCNPlane(width: 12, height: 80)
        let snowMat = SCNMaterial()
        snowMat.diffuse.contents = NSColor(red: 0.55, green: 0.55, blue: 0.60, alpha: 0.35)
        snowMat.blendMode = .alpha
        snowRoad.firstMaterial = snowMat
        let snowRoadNode = SCNNode(geometry: snowRoad)
        snowRoadNode.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        snowRoadNode.position = SCNVector3(0, -1.48, -18)
        scene.rootNode.addChildNode(snowRoadNode)

        // Utility poles on right shoulder, scrolling past
        for i in 0..<6 {
            addUtilityPole(to: scene, at: SCNVector3(5.5, -1.5, Float(-4 - i * 8)), index: i)
        }

        // Barn silhouettes far left and right
        addBarnSilhouette(to: scene, at: SCNVector3(-14, 0, -30))
        addBarnSilhouette(to: scene, at: SCNVector3(18, 2, -45))
        addSiloSilhouette(to: scene, at: SCNVector3(-22, 1, -38))
    }

    private func addUtilityPole(to scene: SCNScene, at position: SCNVector3, index: Int) {
        let poleH: Float = 7.0
        let pole = SCNCylinder(radius: 0.06, height: CGFloat(poleH))
        pole.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(position.x, position.y + poleH / 2, position.z)
        scene.rootNode.addChildNode(poleNode)

        // Cross-arm
        let arm = SCNCylinder(radius: 0.04, height: 1.4)
        arm.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.12, blue: 0.10, alpha: 1)
        let armNode = SCNNode(geometry: arm)
        armNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        armNode.position = SCNVector3(position.x, position.y + poleH - 0.8, position.z)
        scene.rootNode.addChildNode(armNode)

        // Wires to vanishing point
        for w in 0..<3 {
            let wireGeo = SCNCylinder(radius: 0.012, height: 18)
            wireGeo.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 0.7)
            let wireNode = SCNNode(geometry: wireGeo)
            let wireOffX = Float(-0.5 + Double(w) * 0.5)
            let wireStartY = position.y + poleH - 0.6 - Float(w) * 0.3
            wireNode.position = SCNVector3(wireOffX, wireStartY, 0)
            wireNode.eulerAngles = SCNVector3(Float.pi / 6, 0, 0)
            scene.rootNode.addChildNode(wireNode)
        }

        // Scroll toward viewer
        let cycleDur = 5.0 + Double(index) * 0.3
        let scroll = SCNAction.repeatForever(.sequence([
            .moveBy(x: 0, y: 0, z: 55, duration: cycleDur),
            .move(to: SCNVector3(position.x, position.y, position.z - 6), duration: 0),
        ]))
        poleNode.runAction(scroll)
        armNode.runAction(scroll.copy() as! SCNAction)
    }

    private func addBarnSilhouette(to scene: SCNScene, at position: SCNVector3) {
        let barnW: Float = 8, barnH: Float = 4
        let body = SCNBox(width: CGFloat(barnW), height: CGFloat(barnH), length: 2, chamferRadius: 0)
        body.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(position.x, position.y + barnH / 2, position.z)
        scene.rootNode.addChildNode(bodyNode)

        // Peaked roof
        let roof = SCNPyramid(width: CGFloat(barnW * 1.1), height: 3, length: 2.2)
        roof.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1)
        let roofNode = SCNNode(geometry: roof)
        roofNode.position = SCNVector3(position.x, position.y + barnH + 1.5, position.z)
        scene.rootNode.addChildNode(roofNode)
    }

    private func addSiloSilhouette(to scene: SCNScene, at position: SCNVector3) {
        let siloH: Float = 10, siloR: Float = 1.5
        let silo = SCNCylinder(radius: CGFloat(siloR), height: CGFloat(siloH))
        silo.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1)
        let siloNode = SCNNode(geometry: silo)
        siloNode.position = SCNVector3(position.x, position.y + siloH / 2, position.z)
        scene.rootNode.addChildNode(siloNode)

        let dome = SCNSphere(radius: CGFloat(siloR * 1.1))
        dome.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.05, alpha: 1)
        let domeNode = SCNNode(geometry: dome)
        domeNode.position = SCNVector3(position.x, position.y + siloH, position.z)
        scene.rootNode.addChildNode(domeNode)
    }

    // MARK: - Car interior

    private func addCarInterior(to scene: SCNScene, coord: Coordinator) {
        let headlinerColor = NSColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
        let panelColor     = NSColor(red: 0.09, green: 0.07, blue: 0.06, alpha: 1)

        // Headliner (ceiling fabric)
        let headliner = SCNBox(width: 6, height: 0.06, length: 4, chamferRadius: 0.04)
        headliner.firstMaterial?.diffuse.contents = headlinerColor
        let headNode = SCNNode(geometry: headliner)
        headNode.position = SCNVector3(0, 1.5, 0.5)
        scene.rootNode.addChildNode(headNode)

        // Left door panel
        let leftDoor = SCNBox(width: 0.06, height: 1.8, length: 3.5, chamferRadius: 0.02)
        leftDoor.firstMaterial?.diffuse.contents = panelColor
        let leftNode = SCNNode(geometry: leftDoor)
        leftNode.position = SCNVector3(-2.98, 0.2, 0.5)
        scene.rootNode.addChildNode(leftNode)

        // Right door panel
        let rightDoor = SCNBox(width: 0.06, height: 1.8, length: 3.5, chamferRadius: 0.02)
        rightDoor.firstMaterial?.diffuse.contents = panelColor
        let rightNode = SCNNode(geometry: rightDoor)
        rightNode.position = SCNVector3(2.98, 0.2, 0.5)
        scene.rootNode.addChildNode(rightNode)

        // A-pillars (thick, angled toward windshield)
        for side: Float in [-1, 1] {
            let pillar = SCNBox(width: 0.18, height: 1.8, length: 0.18, chamferRadius: 0.04)
            pillar.firstMaterial?.diffuse.contents = NSColor(red: 0.07, green: 0.06, blue: 0.05, alpha: 1)
            let pNode = SCNNode(geometry: pillar)
            pNode.position = SCNVector3(side * 2.5, 0.6, -1.2)
            pNode.eulerAngles = SCNVector3(0.35, 0, 0)
            scene.rootNode.addChildNode(pNode)
        }
    }

    // MARK: - Windshield and wiper blades

    private func addWindshieldAndWipers(to scene: SCNScene, coord: Coordinator) {
        // Glass — semi-transparent dark blue-grey plane
        let glass = SCNPlane(width: 5.4, height: 2.4)
        let glassMat = SCNMaterial()
        glassMat.diffuse.contents  = NSColor(red: 0.04, green: 0.05, blue: 0.07, alpha: 0.12)
        glassMat.emission.contents = NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1)
        glassMat.isDoubleSided = true
        glassMat.blendMode = .alpha
        glass.firstMaterial = glassMat
        let glassNode = SCNNode(geometry: glass)
        glassNode.position = SCNVector3(0, 0.55, -1.35)
        glassNode.eulerAngles = SCNVector3(-0.28, 0, 0)
        scene.rootNode.addChildNode(glassNode)

        // Wiper left
        let leftPivot = SCNNode()
        leftPivot.position = SCNVector3(-1.2, -0.6, -1.28)
        scene.rootNode.addChildNode(leftPivot)
        let leftBlade = buildWiperBlade(length: 1.4)
        leftBlade.position = SCNVector3(0, 0, 0)
        leftPivot.addChildNode(leftBlade)
        coord.wiperLeft = leftPivot

        // Wiper right
        let rightPivot = SCNNode()
        rightPivot.position = SCNVector3(1.2, -0.6, -1.28)
        scene.rootNode.addChildNode(rightPivot)
        let rightBlade = buildWiperBlade(length: 1.4)
        rightBlade.position = SCNVector3(0, 0, 0)
        rightPivot.addChildNode(rightBlade)
        coord.wiperRight = rightPivot

        // Wiper sweep animations (ping-pong)
        let swingLeft = SCNAction.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z: -0.9, duration: 0.65, usesShortestUnitArc: true),
            .rotateTo(x: 0, y: 0, z:  0.4, duration: 0.65, usesShortestUnitArc: true),
        ]))
        leftPivot.runAction(swingLeft)

        let swingRight = SCNAction.repeatForever(.sequence([
            .rotateTo(x: 0, y: 0, z:  0.9, duration: 0.65, usesShortestUnitArc: true),
            .rotateTo(x: 0, y: 0, z: -0.4, duration: 0.65, usesShortestUnitArc: true),
        ]))
        rightPivot.runAction(swingRight)
    }

    private func buildWiperBlade(length: CGFloat) -> SCNNode {
        let arm = SCNCylinder(radius: 0.018, height: length)
        arm.firstMaterial?.diffuse.contents = NSColor(red: 0.18, green: 0.14, blue: 0.12, alpha: 1)
        let armNode = SCNNode(geometry: arm)
        // Pivot at bottom of arm: offset arm so it rotates from one end
        armNode.position = SCNVector3(0, Float(length / 2), 0)
        return armNode
    }

    // MARK: - Dashboard

    private func addDashboard(to scene: SCNScene, coord: Coordinator) {
        // Main dash body
        let dash = SCNBox(width: 6.2, height: 0.55, length: 0.80, chamferRadius: 0.06)
        let dashMat = SCNMaterial()
        dashMat.diffuse.contents = NSColor(red: 0.08, green: 0.07, blue: 0.06, alpha: 1)
        dashMat.specular.contents = NSColor(white: 0.12, alpha: 1)
        dash.firstMaterial = dashMat
        let dashNode = SCNNode(geometry: dash)
        dashNode.position = SCNVector3(0, -0.72, -0.85)
        scene.rootNode.addChildNode(dashNode)

        // Padded top rail
        let rail = SCNBox(width: 6.2, height: 0.09, length: 0.12, chamferRadius: 0.04)
        rail.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.10, blue: 0.08, alpha: 1)
        let railNode = SCNNode(geometry: rail)
        railNode.position = SCNVector3(0, -0.47, -0.85)
        scene.rootNode.addChildNode(railNode)

        // Instrument cluster housing — behind glass
        let cluster = SCNBox(width: 2.0, height: 0.38, length: 0.12, chamferRadius: 0.04)
        cluster.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.04, alpha: 1)
        let clusterNode = SCNNode(geometry: cluster)
        clusterNode.position = SCNVector3(-0.8, -0.60, -0.52)
        scene.rootNode.addChildNode(clusterNode)

        // Gauge glass faces (emissive amber)
        for gx: Float in [-1.45, -0.60] {
            let face = SCNPlane(width: 0.50, height: 0.38)
            let faceMat = SCNMaterial()
            faceMat.diffuse.contents  = NSColor(red: 0.04, green: 0.03, blue: 0.02, alpha: 1)
            faceMat.emission.contents = NSColor(red: 0.55, green: 0.35, blue: 0.10, alpha: 1)
            faceMat.isDoubleSided = true
            face.firstMaterial = faceMat
            let faceNode = SCNNode(geometry: face)
            faceNode.position = SCNVector3(gx, -0.60, -0.46)
            scene.rootNode.addChildNode(faceNode)
        }

        // Incandescent dash light (diffuse, warm)
        let dashLight = SCNNode()
        dashLight.light = SCNLight()
        dashLight.light!.type = .omni
        dashLight.light!.intensity = 80
        dashLight.light!.color = NSColor(red: 0.85, green: 0.55, blue: 0.20, alpha: 1)
        dashLight.light!.attenuationStartDistance = 0
        dashLight.light!.attenuationEndDistance = 2.5
        dashLight.position = SCNVector3(0, -0.50, -0.55)
        scene.rootNode.addChildNode(dashLight)
        coord.dashLight = dashLight

        // Gentle pulse on dash light (bulb flicker)
        let flicker = SCNAction.repeatForever(.customAction(duration: 3.0) { node, t in
            let wobble = CGFloat(1.0 + 0.06 * sin(Double(t) * 11.0) + 0.03 * sin(Double(t) * 7.3))
            node.light?.intensity = 80 * wobble
        })
        dashLight.runAction(flicker)

        // Steering column
        let column = SCNCylinder(radius: 0.05, height: 1.0)
        column.firstMaterial?.diffuse.contents = NSColor(red: 0.12, green: 0.10, blue: 0.09, alpha: 1)
        let columnNode = SCNNode(geometry: column)
        columnNode.position = SCNVector3(-0.3, -1.0, -0.65)
        columnNode.eulerAngles = SCNVector3(0.55, 0, 0)
        scene.rootNode.addChildNode(columnNode)

        // Steering wheel
        addSteeringWheel(to: scene, at: SCNVector3(-0.3, -0.45, -1.05))
    }

    private func addSteeringWheel(to scene: SCNScene, at position: SCNVector3) {
        let rimColor = NSColor(red: 0.13, green: 0.10, blue: 0.08, alpha: 1)
        let outerR: CGFloat = 0.38
        let segments = 32

        // Rim — torus approximated with thin torus geometry
        let rim = SCNTorus(ringRadius: outerR, pipeRadius: 0.025)
        rim.firstMaterial?.diffuse.contents = rimColor
        let rimNode = SCNNode(geometry: rim)
        rimNode.position = position
        rimNode.eulerAngles = SCNVector3(-0.30, 0, 0)
        scene.rootNode.addChildNode(rimNode)
        _ = segments

        // Three spokes
        for s in 0..<3 {
            let a = Double(s) * (2 * .pi / 3) - .pi / 2
            let spoke = SCNCylinder(radius: 0.018, height: outerR * 0.92)
            spoke.firstMaterial?.diffuse.contents = rimColor
            let spokeNode = SCNNode(geometry: spoke)
            let midX = Float(cos(a)) * Float(outerR * 0.46)
            let midY = Float(sin(a)) * Float(outerR * 0.46)
            spokeNode.position = SCNVector3(position.x + midX, position.y + midY, position.z)
            spokeNode.eulerAngles = SCNVector3(-0.30, 0, Float(a + .pi / 2))
            scene.rootNode.addChildNode(spokeNode)
        }

        // Hub
        let hub = SCNCylinder(radius: 0.07, height: 0.04)
        hub.firstMaterial?.diffuse.contents = NSColor(red: 0.10, green: 0.08, blue: 0.07, alpha: 1)
        let hubNode = SCNNode(geometry: hub)
        hubNode.position = SCNVector3(position.x, position.y, position.z + 0.01)
        hubNode.eulerAngles = SCNVector3(-0.30, 0, 0)
        scene.rootNode.addChildNode(hubNode)

        // Gentle sway
        let sway = SCNAction.repeatForever(.sequence([
            .rotateTo(x: -0.30, y: -0.015, z: 0, duration: 3.0, usesShortestUnitArc: true),
            .rotateTo(x: -0.30, y:  0.015, z: 0, duration: 3.0, usesShortestUnitArc: true),
        ]))
        rimNode.runAction(sway)
    }

    // MARK: - Radio

    private func addRadio(to scene: SCNScene) {
        // Radio body
        let body = SCNBox(width: 1.20, height: 0.28, length: 0.14, chamferRadius: 0.025)
        let bodyMat = SCNMaterial()
        bodyMat.diffuse.contents  = NSColor(red: 0.10, green: 0.08, blue: 0.07, alpha: 1)
        bodyMat.specular.contents = NSColor(white: 0.30, alpha: 1)
        body.firstMaterial = bodyMat
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0.85, -0.72, -0.52)
        scene.rootNode.addChildNode(bodyNode)

        // Tuner window — amber emissive
        let tuner = SCNBox(width: 0.64, height: 0.12, length: 0.02, chamferRadius: 0.01)
        let tunerMat = SCNMaterial()
        tunerMat.diffuse.contents  = NSColor(red: 0.20, green: 0.12, blue: 0.04, alpha: 1)
        tunerMat.emission.contents = NSColor(red: 0.82, green: 0.58, blue: 0.14, alpha: 1)
        tuner.firstMaterial = tunerMat
        let tunerNode = SCNNode(geometry: tuner)
        tunerNode.position = SCNVector3(0.85, -0.68, -0.46)
        scene.rootNode.addChildNode(tunerNode)

        // Tuner glow light
        let tunerLight = SCNNode()
        tunerLight.light = SCNLight()
        tunerLight.light!.type = .omni
        tunerLight.light!.intensity = 30
        tunerLight.light!.color = NSColor(red: 0.85, green: 0.58, blue: 0.14, alpha: 1)
        tunerLight.light!.attenuationStartDistance = 0
        tunerLight.light!.attenuationEndDistance = 0.8
        tunerLight.position = SCNVector3(0.85, -0.68, -0.40)
        scene.rootNode.addChildNode(tunerLight)

        // Chrome knobs
        for kx: Float in [0.20, 1.50] {
            addChromeKnob(to: scene, at: SCNVector3(kx, -0.76, -0.46))
        }

        // Chrome trim border
        let trim = SCNBox(width: 1.22, height: 0.30, length: 0.06, chamferRadius: 0.02)
        let trimMat = SCNMaterial()
        trimMat.diffuse.contents  = NSColor(red: 0.50, green: 0.45, blue: 0.40, alpha: 1)
        trimMat.specular.contents = NSColor(white: 0.80, alpha: 1)
        trimMat.metalness.contents = NSNumber(value: 0.9)
        trim.firstMaterial = trimMat
        let trimNode = SCNNode(geometry: trim)
        trimNode.position = SCNVector3(0.85, -0.72, -0.48)
        scene.rootNode.addChildNode(trimNode)
    }

    private func addChromeKnob(to scene: SCNScene, at position: SCNVector3) {
        let knob = SCNCylinder(radius: 0.07, height: 0.06)
        let mat = SCNMaterial()
        mat.diffuse.contents  = NSColor(red: 0.45, green: 0.40, blue: 0.35, alpha: 1)
        mat.specular.contents = NSColor(white: 0.95, alpha: 1)
        mat.metalness.contents = NSNumber(value: 0.95)
        mat.roughness.contents = NSNumber(value: 0.15)
        knob.firstMaterial = mat
        let knobNode = SCNNode(geometry: knob)
        knobNode.position = position
        knobNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(knobNode)
    }

    // MARK: - Bench seat

    private func addBenchSeat(to scene: SCNScene) {
        let seatColor = NSColor(red: 0.09, green: 0.07, blue: 0.06, alpha: 1)

        // Seat cushion
        let cushion = SCNBox(width: 5.8, height: 0.22, length: 1.80, chamferRadius: 0.06)
        cushion.firstMaterial?.diffuse.contents = seatColor
        let cushionNode = SCNNode(geometry: cushion)
        cushionNode.position = SCNVector3(0, -1.30, 1.2)
        scene.rootNode.addChildNode(cushionNode)

        // Seat back
        let back = SCNBox(width: 5.8, height: 0.85, length: 0.14, chamferRadius: 0.06)
        back.firstMaterial?.diffuse.contents = seatColor
        let backNode = SCNNode(geometry: back)
        backNode.position = SCNVector3(0, -0.85, 1.95)
        scene.rootNode.addChildNode(backNode)

        // Horizontal pleat lines on seat back
        for i in 0..<4 {
            let pleat = SCNBox(width: 5.82, height: 0.012, length: 0.012, chamferRadius: 0)
            pleat.firstMaterial?.diffuse.contents = NSColor(red: 0.13, green: 0.10, blue: 0.09, alpha: 1)
            let pleatNode = SCNNode(geometry: pleat)
            pleatNode.position = SCNVector3(0, -1.14 + Float(i) * 0.14, 1.955)
            scene.rootNode.addChildNode(pleatNode)
        }
    }

    // MARK: - Snow particles

    private func addSnowParticles(to scene: SCNScene, coord: Coordinator) {
        let snow = SCNParticleSystem()
        snow.birthRate             = 900
        snow.emitterShape          = SCNPlane(width: 12, height: 8)
        snow.particleLifeSpan      = 1.6
        snow.particleLifeSpanVariation = 0.6
        snow.particleVelocity      = 18
        snow.particleVelocityVariation = 6
        snow.particleSize          = 0.04
        snow.particleSizeVariation = 0.03
        snow.particleColor         = NSColor(red: 0.88, green: 0.90, blue: 0.98, alpha: 0.80)
        snow.particleColorVariation = SCNVector4(0, 0, 0.1, 0.15)
        snow.isAffectedByGravity   = false
        snow.stretchFactor         = 0.12
        snow.blendMode             = .additive

        let snowNode = SCNNode()
        snowNode.position = SCNVector3(0, 1, -18)
        snowNode.eulerAngles = SCNVector3(Float.pi / 2, 0, 0)
        snowNode.addParticleSystem(snow)
        scene.rootNode.addChildNode(snowNode)
        coord.snowSystem = snowNode
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene, coord: Coordinator) {
        // Dim ambient (very dark — we want the dash and snow to be the main light)
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 8
        ambient.light!.color = NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Faint moonlight from above-front
        let moon = SCNNode()
        moon.light = SCNLight()
        moon.light!.type = .directional
        moon.light!.intensity = 12
        moon.light!.color = NSColor(red: 0.30, green: 0.35, blue: 0.55, alpha: 1)
        moon.eulerAngles = SCNVector3(-Float.pi / 4, 0.3, 0)
        scene.rootNode.addChildNode(moon)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 72
        camera.zNear = 0.05
        camera.zFar  = 80
        camera.wantsHDR = true
        camera.bloomIntensity = 0.5
        camera.bloomThreshold = 0.6

        let camNode = SCNNode()
        camNode.camera = camera
        // Seated in the car, looking forward through the windshield
        camNode.position = SCNVector3(0, 0.10, 0.85)
        camNode.look(at: SCNVector3(0, 0.05, -20))
        scene.rootNode.addChildNode(camNode)

        // Gentle road-vibration sway
        let sway = SCNAction.repeatForever(.sequence([
            .customAction(duration: 4.0) { node, t in
                let bump = 0.008 * sin(Double(t) * 13.5) + 0.004 * sin(Double(t) * 7.2)
                node.position = SCNVector3(
                    Float(0.005 * sin(Double(t) * 4.3)),
                    Float(0.10 + bump),
                    0.85
                )
            }
        ]))
        camNode.runAction(sway)
    }
}
