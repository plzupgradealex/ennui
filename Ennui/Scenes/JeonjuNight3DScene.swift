// JeonjuNight3DScene — SceneKit Korean neighbourhood at night.
// Hanok houses with warm windows, convenience store, sodium street lamp,
// telephone wires, moths, a cat on a wall. Camera drifts slowly down the street.
// Tap to toggle windows. Sodium lighting: warm orange-yellow atmosphere.

import SwiftUI
import SceneKit

struct JeonjuNight3DScene: View {
    @ObservedObject var interaction: InteractionState

    var body: some View {
        JeonjuNight3DRepresentable(interaction: interaction, tapCount: interaction.tapCount)
    }
}

// MARK: - NSViewRepresentable

private struct JeonjuNight3DRepresentable: NSViewRepresentable {
    var interaction: InteractionState
    var tapCount: Int

    final class Coordinator {
        var windowLights: [SCNNode] = []
        var windowPlanes: [SCNNode] = []
        var lastTapCount = 0
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
        guard tapCount != c.lastTapCount else { return }
        c.lastTapCount = tapCount

        // Toggle a random window
        guard !c.windowLights.isEmpty else { return }
        let idx = Int.random(in: 0..<c.windowLights.count)
        let isLit = (c.windowLights[idx].light?.intensity ?? 0) > 10

        SCNTransaction.begin()
        SCNTransaction.animationDuration = 1.5
        if isLit {
            c.windowLights[idx].light?.intensity = 0
            if idx < c.windowPlanes.count {
                c.windowPlanes[idx].geometry?.firstMaterial?.emission.contents = NSColor.black
            }
        } else {
            c.windowLights[idx].light?.intensity = 180
            let warm = NSColor(red: 0.95, green: 0.78, blue: 0.35, alpha: 1)
            if idx < c.windowPlanes.count {
                c.windowPlanes[idx].geometry?.firstMaterial?.emission.contents = warm
            }
        }
        SCNTransaction.commit()
    }

    // MARK: - Scene construction

    private func buildScene(_ scene: SCNScene, coord: Coordinator) {
        scene.fogStartDistance = 10
        scene.fogEndDistance = 40
        scene.fogColor = NSColor(red: 0.04, green: 0.03, blue: 0.06, alpha: 1)
        scene.background.contents = NSColor(red: 0.02, green: 0.015, blue: 0.04, alpha: 1)

        addLighting(to: scene)
        addGround(to: scene)
        addMountain(to: scene)
        addMoon(to: scene)
        addStars(to: scene)
        addHouses(to: scene, coord: coord)
        addConvenienceStore(to: scene)
        addStreetLamp(to: scene)
        addTelephoneWires(to: scene)
        addCat(to: scene)
        addMoths(to: scene)
        addCamera(to: scene)
    }

    // MARK: - Lighting

    private func addLighting(to scene: SCNScene) {
        // Dim ambient — night
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light!.type = .ambient
        ambient.light!.intensity = 35
        ambient.light!.color = NSColor(red: 0.08, green: 0.06, blue: 0.14, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        // Moonlight — faint blue directional
        let moonLight = SCNNode()
        moonLight.light = SCNLight()
        moonLight.light!.type = .directional
        moonLight.light!.intensity = 50
        moonLight.light!.color = NSColor(red: 0.25, green: 0.28, blue: 0.45, alpha: 1)
        moonLight.light!.castsShadow = true
        moonLight.light!.shadowRadius = 3
        moonLight.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        scene.rootNode.addChildNode(moonLight)
    }

    // MARK: - Ground

    private func addGround(to scene: SCNScene) {
        // Dark ground plane
        let ground = SCNFloor()
        ground.reflectivity = 0.04
        ground.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.08, alpha: 1)
        scene.rootNode.addChildNode(SCNNode(geometry: ground))

        // Road (slightly lighter strip)
        let road = SCNBox(width: 3.0, height: 0.005, length: 20, chamferRadius: 0)
        road.firstMaterial?.diffuse.contents = NSColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 1)
        let roadNode = SCNNode(geometry: road)
        roadNode.position = SCNVector3(0, 0.003, 0)
        scene.rootNode.addChildNode(roadNode)

        // Center dashes
        var rng = SplitMix64(seed: 3333)
        var dz: Float = -9.0
        while dz < 9.0 {
            let dash = SCNBox(width: 0.08, height: 0.002, length: 0.4, chamferRadius: 0)
            dash.firstMaterial?.diffuse.contents = NSColor(red: 0.35, green: 0.30, blue: 0.25, alpha: 0.25)
            let dNode = SCNNode(geometry: dash)
            dNode.position = SCNVector3(0, 0.006, dz)
            scene.rootNode.addChildNode(dNode)
            dz += 1.2
        }
    }

    // MARK: - Mountain

    private func addMountain(to scene: SCNScene) {
        // Large dark box in background representing the distant mountain range
        var rng = SplitMix64(seed: 7777)
        for _ in 0..<8 {
            let mx = Float(Double.random(in: -12...12, using: &rng))
            let mh = Float(2.0 + Double.random(in: 0..<4, using: &rng))
            let mw = Float(2.0 + Double.random(in: 0..<3, using: &rng))
            let peak = SCNBox(width: CGFloat(mw), height: CGFloat(mh), length: 2, chamferRadius: 0.3)
            peak.firstMaterial?.diffuse.contents = NSColor(red: 0.06, green: 0.05, blue: 0.12, alpha: 1)
            let pNode = SCNNode(geometry: peak)
            pNode.position = SCNVector3(mx, mh / 2, -12)
            scene.rootNode.addChildNode(pNode)
        }
    }

    // MARK: - Moon

    private func addMoon(to scene: SCNScene) {
        let moonGeo = SCNSphere(radius: 1.2)
        let moonMat = SCNMaterial()
        moonMat.diffuse.contents = NSColor.black
        moonMat.emission.contents = NSColor(red: 0.95, green: 0.92, blue: 0.80, alpha: 1)
        moonMat.emission.intensity = 2.0
        moonMat.lightingModel = .constant
        moonGeo.firstMaterial = moonMat

        let moonNode = SCNNode(geometry: moonGeo)
        moonNode.position = SCNVector3(8, 18, -15)
        moonNode.castsShadow = false
        scene.rootNode.addChildNode(moonNode)

        // Crescent shadow (dark sphere overlapping to create crescent shape)
        let shadow = SCNSphere(radius: 1.15)
        let sMat = SCNMaterial()
        sMat.diffuse.contents = NSColor(red: 0.02, green: 0.015, blue: 0.04, alpha: 1)
        sMat.lightingModel = .constant
        shadow.firstMaterial = sMat
        let sNode = SCNNode(geometry: shadow)
        sNode.position = SCNVector3(8.6, 18.1, -14.8)
        sNode.castsShadow = false
        scene.rootNode.addChildNode(sNode)

        // Halo glow
        let haloGeo = SCNSphere(radius: 2.5)
        let hMat = SCNMaterial()
        hMat.diffuse.contents = NSColor.clear
        hMat.emission.contents = NSColor(red: 0.75, green: 0.72, blue: 0.55, alpha: 1)
        hMat.emission.intensity = 0.08
        hMat.lightingModel = .constant
        hMat.isDoubleSided = true
        hMat.transparency = 0.08
        haloGeo.firstMaterial = hMat
        let hNode = SCNNode(geometry: haloGeo)
        hNode.position = SCNVector3(8, 18, -15)
        hNode.castsShadow = false
        scene.rootNode.addChildNode(hNode)
    }

    // MARK: - Stars

    private func addStars(to scene: SCNScene) {
        var rng = SplitMix64(seed: 8888)
        for _ in 0..<60 {
            let sx = Float(Double.random(in: -15...15, using: &rng))
            let sy = Float(8 + Double.random(in: 0..<12, using: &rng))
            let sz = Float(-10 + Double.random(in: -5..<0, using: &rng))
            let size = CGFloat(0.03 + Double.random(in: 0..<0.05, using: &rng))

            let star = SCNPlane(width: size, height: size)
            let sMat = SCNMaterial()
            sMat.emission.contents = NSColor(red: 0.9, green: 0.85, blue: 0.7, alpha: 1)
            sMat.emission.intensity = 0.6
            sMat.diffuse.contents = NSColor.black
            sMat.lightingModel = .constant
            sMat.isDoubleSided = true
            star.firstMaterial = sMat

            let sNode = SCNNode(geometry: star)
            sNode.position = SCNVector3(sx, sy, sz)
            // Billboard constraint so stars always face camera
            let billboard = SCNBillboardConstraint()
            sNode.constraints = [billboard]
            scene.rootNode.addChildNode(sNode)
        }
    }

    // MARK: - Hanok houses

    private func addHouses(to scene: SCNScene, coord: Coordinator) {
        var rng = SplitMix64(seed: 1988)

        struct HouseSpec {
            let x: Float; let z: Float
            let w: Float; let h: Float; let d: Float
            let isHanok: Bool
        }

        let specs: [HouseSpec] = [
            HouseSpec(x: -4.5, z: -2.0, w: 1.4, h: 1.2, d: 1.0, isHanok: true),
            HouseSpec(x: -2.8, z: -2.5, w: 1.2, h: 1.0, d: 0.9, isHanok: true),
            HouseSpec(x: -1.2, z: -2.2, w: 1.3, h: 1.1, d: 1.0, isHanok: true),
            HouseSpec(x: 2.0,  z: -2.3, w: 1.1, h: 1.05, d: 0.85, isHanok: false),
            HouseSpec(x: 3.5,  z: -1.8, w: 1.5, h: 1.3, d: 1.1, isHanok: true),
            HouseSpec(x: 5.0,  z: -2.5, w: 1.2, h: 1.0, d: 0.9, isHanok: true),
        ]

        for spec in specs {
            let isHanok = spec.isHanok
            let wallR = isHanok ? 0.85 * 0.25 : 0.5 * 0.25
            let wallG = isHanok ? 0.78 * 0.22 : 0.48 * 0.22
            let wallB = isHanok ? 0.65 * 0.20 : 0.45 * 0.20

            // Wall
            let wall = SCNBox(width: CGFloat(spec.w), height: CGFloat(spec.h),
                              length: CGFloat(spec.d), chamferRadius: 0)
            wall.firstMaterial?.diffuse.contents = NSColor(red: wallR, green: wallG, blue: wallB, alpha: 1)
            let wallNode = SCNNode(geometry: wall)
            wallNode.position = SCNVector3(spec.x, spec.h / 2, spec.z)
            wallNode.castsShadow = true
            scene.rootNode.addChildNode(wallNode)

            // Roof — hanok has wider overhang
            let overhang: Float = isHanok ? 0.25 : 0.08
            let roofH: Float = spec.h * 0.25
            let roofR = isHanok ? 0.25 : 0.35
            let roofG = isHanok ? 0.20 : 0.30
            let roofB = isHanok ? 0.18 : 0.32
            let pyramid = SCNPyramid(width: CGFloat(spec.w + overhang * 2),
                                     height: CGFloat(roofH),
                                     length: CGFloat(spec.d + overhang * 2))
            pyramid.firstMaterial?.diffuse.contents = NSColor(red: roofR, green: roofG, blue: roofB, alpha: 1)
            let roofNode = SCNNode(geometry: pyramid)
            roofNode.position = SCNVector3(spec.x, spec.h + roofH / 2, spec.z)
            roofNode.castsShadow = true
            scene.rootNode.addChildNode(roofNode)

            // 2-3 windows per house
            let winCount = 2 + Int(Double.random(in: 0..<1.5, using: &rng))
            for wi in 0..<winCount {
                let nx = Float(Double(wi) + 0.5) / Float(winCount)
                let isLit = Double.random(in: 0...1, using: &rng) > 0.35

                let winW: CGFloat = CGFloat(spec.w * 0.15)
                let winH: CGFloat = CGFloat(spec.h * 0.22)
                let warmth = 0.6 + Double.random(in: 0..<0.4, using: &rng)

                let winGeo = SCNPlane(width: winW, height: winH)
                let warmColor = NSColor(red: 0.95 * warmth, green: 0.78 * warmth, blue: 0.35 * warmth, alpha: 1)
                let winMat = SCNMaterial()
                winMat.emission.contents = isLit ? warmColor : NSColor.black
                winMat.diffuse.contents = NSColor.black
                winMat.isDoubleSided = true
                winGeo.firstMaterial = winMat

                let wx = spec.x - spec.w / 2 + nx * spec.w
                let wy = spec.h * 0.45
                let wz = spec.z + spec.d / 2 + 0.01
                let winNode = SCNNode(geometry: winGeo)
                winNode.position = SCNVector3(wx, wy, wz)
                scene.rootNode.addChildNode(winNode)
                coord.windowPlanes.append(winNode)

                // Window cross frame
                let crossH = SCNBox(width: winW, height: 0.01, length: 0.005, chamferRadius: 0)
                crossH.firstMaterial?.diffuse.contents = NSColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 1)
                let chNode = SCNNode(geometry: crossH)
                chNode.position = SCNVector3(wx, wy, wz + 0.005)
                scene.rootNode.addChildNode(chNode)
                let crossV = SCNBox(width: 0.01, height: winH, length: 0.005, chamferRadius: 0)
                crossV.firstMaterial?.diffuse.contents = NSColor(red: 0.10, green: 0.08, blue: 0.12, alpha: 1)
                let cvNode = SCNNode(geometry: crossV)
                cvNode.position = SCNVector3(wx, wy, wz + 0.005)
                scene.rootNode.addChildNode(cvNode)

                // Light
                let light = SCNNode()
                light.light = SCNLight()
                light.light!.type = .omni
                light.light!.intensity = isLit ? 180 : 0
                light.light!.color = warmColor
                light.light!.attenuationStartDistance = 0
                light.light!.attenuationEndDistance = 2.0
                light.position = SCNVector3(wx, wy, wz + 0.15)
                scene.rootNode.addChildNode(light)
                coord.windowLights.append(light)
            }

            // TV antenna on some houses
            if Double.random(in: 0...1, using: &rng) > 0.5 {
                let pole = SCNCylinder(radius: 0.01, height: CGFloat(spec.h * 0.35))
                pole.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.22, blue: 0.30, alpha: 1)
                let poleNode = SCNNode(geometry: pole)
                poleNode.position = SCNVector3(spec.x + spec.w * 0.3,
                                               spec.h + roofH + spec.h * 0.175,
                                               spec.z)
                scene.rootNode.addChildNode(poleNode)

                // Arms
                let arm = SCNBox(width: CGFloat(spec.w * 0.3), height: 0.01, length: 0.01, chamferRadius: 0)
                arm.firstMaterial?.diffuse.contents = NSColor(red: 0.25, green: 0.22, blue: 0.30, alpha: 1)
                let aNode = SCNNode(geometry: arm)
                aNode.position = SCNVector3(spec.x + spec.w * 0.3,
                                            spec.h + roofH + spec.h * 0.35,
                                            spec.z)
                scene.rootNode.addChildNode(aNode)
            }
        }
    }

    // MARK: - Convenience store

    private func addConvenienceStore(to scene: SCNScene) {
        let sx: Float = 0.8, sz: Float = -2.4
        let sw: Float = 1.5, sh: Float = 1.3, sd: Float = 1.0

        // Building
        let building = SCNBox(width: CGFloat(sw), height: CGFloat(sh), length: CGFloat(sd), chamferRadius: 0)
        building.firstMaterial?.diffuse.contents = NSColor(red: 0.30, green: 0.32, blue: 0.34, alpha: 1)
        let bNode = SCNNode(geometry: building)
        bNode.position = SCNVector3(sx, sh / 2, sz)
        bNode.castsShadow = true
        scene.rootNode.addChildNode(bNode)

        // Fluorescent sign
        let sign = SCNBox(width: CGFloat(sw - 0.1), height: 0.18, length: 0.04, chamferRadius: 0)
        let signMat = SCNMaterial()
        signMat.emission.contents = NSColor(red: 0.3, green: 0.7, blue: 0.95, alpha: 1)
        signMat.emission.intensity = 1.2
        signMat.diffuse.contents = NSColor.black
        signMat.lightingModel = .constant
        sign.firstMaterial = signMat
        let signNode = SCNNode(geometry: sign)
        signNode.position = SCNVector3(sx, sh + 0.1, sz + sd / 2 + 0.02)
        scene.rootNode.addChildNode(signNode)

        // Sign flicker
        signNode.runAction(.repeatForever(.sequence([
            .customAction(duration: 0.8) { node, elapsed in
                let flicker = sin(Double(elapsed) * 12.0) > -0.8 ? 1.0 : 0.3
                node.geometry?.firstMaterial?.emission.intensity = CGFloat(flicker * 1.2)
            },
        ])))

        // Store window (brighter interior)
        let storeWin = SCNPlane(width: CGFloat(sw - 0.2), height: CGFloat(sh - 0.3))
        let winMat = SCNMaterial()
        winMat.emission.contents = NSColor(red: 0.55, green: 0.68, blue: 0.72, alpha: 1)
        winMat.emission.intensity = 0.3
        winMat.diffuse.contents = NSColor.black
        winMat.isDoubleSided = true
        storeWin.firstMaterial = winMat
        let winNode = SCNNode(geometry: storeWin)
        winNode.position = SCNVector3(sx, sh * 0.45, sz + sd / 2 + 0.01)
        scene.rootNode.addChildNode(winNode)

        // Fluorescent interior light
        let fluoro = SCNNode()
        fluoro.light = SCNLight()
        fluoro.light!.type = .omni
        fluoro.light!.intensity = 120
        fluoro.light!.color = NSColor(red: 0.6, green: 0.75, blue: 0.85, alpha: 1)
        fluoro.light!.attenuationStartDistance = 0
        fluoro.light!.attenuationEndDistance = 3
        fluoro.position = SCNVector3(sx, sh + 0.3, sz + sd / 2 + 0.3)
        scene.rootNode.addChildNode(fluoro)

        // Ground light spill
        let spill = SCNNode()
        spill.light = SCNLight()
        spill.light!.type = .omni
        spill.light!.intensity = 30
        spill.light!.color = NSColor(red: 0.5, green: 0.65, blue: 0.75, alpha: 1)
        spill.light!.attenuationStartDistance = 0
        spill.light!.attenuationEndDistance = 2.5
        spill.position = SCNVector3(sx, 0.1, sz + sd / 2 + 0.5)
        scene.rootNode.addChildNode(spill)
    }

    // MARK: - Sodium street lamp

    private func addStreetLamp(to scene: SCNScene) {
        let lx: Float = 2.5, lz: Float = 0.5
        let poleH: Float = 3.2

        // Pole
        let pole = SCNCylinder(radius: 0.04, height: CGFloat(poleH))
        pole.firstMaterial?.diffuse.contents = NSColor(red: 0.22, green: 0.20, blue: 0.28, alpha: 1)
        let poleNode = SCNNode(geometry: pole)
        poleNode.position = SCNVector3(lx, poleH / 2, lz)
        scene.rootNode.addChildNode(poleNode)

        // Lamp head (horizontal arm + housing)
        let arm = SCNCylinder(radius: 0.02, height: 0.5)
        arm.firstMaterial?.diffuse.contents = NSColor(red: 0.22, green: 0.20, blue: 0.28, alpha: 1)
        let armNode = SCNNode(geometry: arm)
        armNode.eulerAngles = SCNVector3(0, 0, Float.pi / 2)
        armNode.position = SCNVector3(lx - 0.2, poleH, lz)
        scene.rootNode.addChildNode(armNode)

        let housing = SCNBox(width: 0.25, height: 0.08, length: 0.12, chamferRadius: 0.02)
        housing.firstMaterial?.diffuse.contents = NSColor(red: 0.28, green: 0.25, blue: 0.32, alpha: 1)
        let housingNode = SCNNode(geometry: housing)
        housingNode.position = SCNVector3(lx - 0.45, poleH - 0.04, lz)
        scene.rootNode.addChildNode(housingNode)

        // Sodium bulb (warm amber emissive)
        let bulb = SCNSphere(radius: 0.03)
        let bulbMat = SCNMaterial()
        bulbMat.emission.contents = NSColor(red: 0.95, green: 0.75, blue: 0.3, alpha: 1)
        bulbMat.emission.intensity = 2.0
        bulbMat.diffuse.contents = NSColor.black
        bulbMat.lightingModel = .constant
        bulb.firstMaterial = bulbMat
        let bulbNode = SCNNode(geometry: bulb)
        bulbNode.position = SCNVector3(lx - 0.45, poleH - 0.09, lz)
        scene.rootNode.addChildNode(bulbNode)

        // SODIUM LIGHT — the defining character of this scene
        // Warm orange-yellow, characteristic of sodium vapour lamps
        let sodium = SCNNode()
        sodium.light = SCNLight()
        sodium.light!.type = .spot
        sodium.light!.intensity = 600
        sodium.light!.color = NSColor(red: 0.95, green: 0.75, blue: 0.3, alpha: 1)
        sodium.light!.castsShadow = true
        sodium.light!.shadowRadius = 4
        sodium.light!.shadowSampleCount = 4
        sodium.light!.attenuationStartDistance = 0
        sodium.light!.attenuationEndDistance = 8
        sodium.light!.spotInnerAngle = 35
        sodium.light!.spotOuterAngle = 70
        sodium.position = SCNVector3(lx - 0.45, poleH - 0.1, lz)
        sodium.eulerAngles = SCNVector3(-Float.pi / 2, 0, 0)
        scene.rootNode.addChildNode(sodium)

        // Secondary wider sodium fill for ambient warmth
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light!.type = .omni
        fill.light!.intensity = 80
        fill.light!.color = NSColor(red: 0.90, green: 0.65, blue: 0.25, alpha: 1)
        fill.light!.attenuationStartDistance = 0
        fill.light!.attenuationEndDistance = 6
        fill.position = SCNVector3(lx - 0.45, poleH - 0.2, lz)
        scene.rootNode.addChildNode(fill)

        // Subtle flicker
        sodium.runAction(.repeatForever(.sequence([
            .customAction(duration: 3.0) { node, elapsed in
                let flicker = 580.0 + sin(Double(elapsed) * 7.1) * 15.0 + sin(Double(elapsed) * 11.3) * 8.0
                node.light?.intensity = CGFloat(flicker)
            },
        ])))
    }

    // MARK: - Telephone wires

    private func addTelephoneWires(to scene: SCNScene) {
        let wireColor = NSColor(red: 0.12, green: 0.10, blue: 0.16, alpha: 1)

        for i in 0..<3 {
            let baseY = Float(3.4) + Float(i) * 0.12
            // Each wire is a series of thin box segments approximating a catenary
            let segments = 20
            let startX: Float = -8, endX: Float = 8
            let sagAmount: Float = 0.15 + Float(i) * 0.05
            for s in 0..<segments {
                let frac1 = Float(s) / Float(segments)
                let frac2 = Float(s + 1) / Float(segments)
                let x1 = startX + frac1 * (endX - startX)
                let x2 = startX + frac2 * (endX - startX)
                let y1 = baseY + sin(Float.pi * frac1) * sagAmount
                let y2 = baseY + sin(Float.pi * frac2) * sagAmount
                let midX = (x1 + x2) / 2
                let midY = (y1 + y2) / 2 - sagAmount
                let length = sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2))

                let seg = SCNBox(width: CGFloat(length), height: 0.008, length: 0.008, chamferRadius: 0)
                seg.firstMaterial?.diffuse.contents = wireColor
                let segNode = SCNNode(geometry: seg)
                segNode.position = SCNVector3(midX, midY + sagAmount, -2.0)
                let angle = atan2(y2 - y1, x2 - x1)
                segNode.eulerAngles = SCNVector3(0, 0, angle)
                scene.rootNode.addChildNode(segNode)
            }
        }
    }

    // MARK: - Cat

    private func addCat(to scene: SCNScene) {
        // Cat sitting on the wall of the last house
        let cx: Float = 5.5, cy: Float = 1.25, cz: Float = -1.95

        // Body
        let body = SCNBox(width: 0.12, height: 0.08, length: 0.06, chamferRadius: 0.01)
        body.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.13, blue: 0.20, alpha: 1)
        let bNode = SCNNode(geometry: body)
        bNode.position = SCNVector3(cx, cy, cz)
        scene.rootNode.addChildNode(bNode)

        // Head
        let head = SCNBox(width: 0.07, height: 0.07, length: 0.05, chamferRadius: 0.01)
        head.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.13, blue: 0.20, alpha: 1)
        let hNode = SCNNode(geometry: head)
        hNode.position = SCNVector3(cx + 0.05, cy + 0.06, cz)
        scene.rootNode.addChildNode(hNode)

        // Ears (two tiny pyramids)
        for side in [-1.0, 1.0] {
            let ear = SCNPyramid(width: 0.02, height: 0.03, length: 0.02)
            ear.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.13, blue: 0.20, alpha: 1)
            let eNode = SCNNode(geometry: ear)
            eNode.position = SCNVector3(cx + 0.05, cy + 0.11, cz + Float(side) * 0.02)
            scene.rootNode.addChildNode(eNode)
        }

        // Eyes (tiny green emissive spheres)
        for side in [-1.0, 1.0] {
            let eye = SCNSphere(radius: 0.006)
            let eyeMat = SCNMaterial()
            eyeMat.emission.contents = NSColor(red: 0.5, green: 0.8, blue: 0.3, alpha: 1)
            eyeMat.emission.intensity = 0.7
            eyeMat.diffuse.contents = NSColor.black
            eyeMat.lightingModel = .constant
            eye.firstMaterial = eyeMat
            let eNode = SCNNode(geometry: eye)
            eNode.position = SCNVector3(cx + 0.08, cy + 0.065, cz + Float(side) * 0.015)
            scene.rootNode.addChildNode(eNode)
        }

        // Tail
        let tail = SCNCylinder(radius: 0.01, height: 0.12)
        tail.firstMaterial?.diffuse.contents = NSColor(red: 0.15, green: 0.13, blue: 0.20, alpha: 1)
        let tNode = SCNNode(geometry: tail)
        tNode.eulerAngles = SCNVector3(0, 0, Float.pi / 4)
        tNode.position = SCNVector3(cx - 0.08, cy + 0.04, cz)
        scene.rootNode.addChildNode(tNode)
    }

    // MARK: - Moths (particle system near sodium lamp)

    private func addMoths(to scene: SCNScene) {
        let moths = SCNParticleSystem()
        moths.birthRate = 4
        moths.particleLifeSpan = 5
        moths.particleSize = 0.015
        moths.particleColor = NSColor(red: 0.8, green: 0.75, blue: 0.6, alpha: 0.7)
        moths.particleColorVariation = SCNVector4(0.05, 0.05, 0, 0.2)
        moths.blendMode = .additive
        moths.spreadingAngle = 360
        moths.emittingDirection = SCNVector3(0, 0, 0)
        moths.particleVelocity = 0.15
        moths.particleVelocityVariation = 0.1
        moths.particleAngularVelocity = 2.0
        moths.emitterShape = SCNSphere(radius: 0.3)

        let emitter = SCNNode()
        emitter.position = SCNVector3(2.05, 3.0, 0.5)
        emitter.addParticleSystem(moths)
        scene.rootNode.addChildNode(emitter)
    }

    // MARK: - Camera

    private func addCamera(to scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 52
        camera.zNear = 0.1
        camera.zFar = 60
        camera.wantsHDR = true
        camera.bloomIntensity = 0.35
        camera.bloomThreshold = 0.75

        let camNode = SCNNode()
        camNode.camera = camera
        camNode.position = SCNVector3(0, 2.0, 4.0)
        camNode.look(at: SCNVector3(0, 1.0, -2.0))

        let dolly = SCNNode()
        dolly.addChildNode(camNode)
        scene.rootNode.addChildNode(dolly)

        // Very slow drift along the street
        dolly.runAction(.repeatForever(.sequence([
            .customAction(duration: 60.0) { node, elapsed in
                let t = Double(elapsed)
                let x = Float(sin(t / 60 * .pi * 2) * 2.5)
                let z = Float(cos(t / 60 * .pi * 2) * 1.5 + 4.0)
                node.position = SCNVector3(x, 0, z)
            },
        ])))
    }
}
