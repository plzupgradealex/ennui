import SwiftUI
import Combine

// Shared interaction state that scenes can read
class InteractionState: ObservableObject {
    @Published var tapLocation: CGPoint? = nil
    @Published var tapCount: Int = 0
    @Published var magnification: Double = 1.0
}

struct ContentView: View {
    @State private var currentScene: SceneKind = .cosmicDrift
    @State private var previousScene: SceneKind? = nil
    @State private var crossfade: Double = 1.0    // 1 = fully showing current
    @State private var showPicker = false
    @State private var showHaiku = false
    @State private var showAbout = false
    @State private var showShareConsent = false
    @State private var pickerTimer: Timer? = nil
    @State private var launched = false
    @State private var isActive = true  // battery: false when window not focused
    @State private var warmingScenes: Set<SceneKind> = []  // preload on hover / adjacency
    @StateObject private var interaction = InteractionState()
    @StateObject private var audioEngine = AmbientAudioEngine()
    @EnvironmentObject var multipeerManager: MultipeerManager

    var body: some View {
        ZStack {
            // Black base
            Color.black.ignoresSafeArea()

            // Previous scene (for crossfade)
            if let prev = previousScene, crossfade < 1.0 {
                sceneView(for: prev)
                    .opacity(1.0 - crossfade)
                    .ignoresSafeArea()
            }

            // Current scene
            sceneView(for: currentScene)
                .opacity(crossfade)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(currentScene.displayName)
                .accessibilityValue(currentScene.accessibilityDescription)
                .accessibilityHint(currentScene.tapHint)
                .accessibilityAddTraits(.updatesFrequently)

            // Ethereal opening — breathing light that dissolves into the scene
            if !launched {
                ZStack {
                    Color.black
                    TimelineView(.animation) { timeline in
                        let t = timeline.date.timeIntervalSinceReferenceDate
                        let breathe = sin(t * 0.7) * 0.5 + 0.5
                        Canvas { ctx, size in
                            let cx = size.width / 2
                            let cy = size.height / 2
                            let r = 80.0 + breathe * 50.0
                            ctx.drawLayer { l in
                                l.addFilter(.blur(radius: r * 0.6))
                                let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                                l.fill(Ellipse().path(in: rect), with: .radialGradient(
                                    Gradient(colors: [
                                        Color(red: 0.4, green: 0.2, blue: 0.6).opacity(0.35 * breathe),
                                        Color(red: 0.3, green: 0.1, blue: 0.5).opacity(0.1 * breathe),
                                        Color.clear,
                                    ]),
                                    center: CGPoint(x: cx, y: cy), startRadius: 0, endRadius: r
                                ))
                            }
                            for i in 0..<6 {
                                let angle = Double(i) / 6.0 * .pi * 2 + t * 0.12
                                let dist = 25.0 + breathe * 18.0 + Double(i) * 5.0
                                let mx = cx + cos(angle) * dist
                                let my = cy + sin(angle) * dist
                                let a = breathe * 0.2 * (sin(t + Double(i)) * 0.5 + 0.5)
                                let s = 2.5 + breathe * 1.5
                                let mr = CGRect(x: mx - s, y: my - s, width: s * 2, height: s * 2)
                                ctx.drawLayer { l in
                                    l.addFilter(.blur(radius: 5))
                                    l.fill(Ellipse().path(in: mr), with: .color(.white.opacity(a)))
                                }
                            }
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            // Hidden preload layer — scenes rendered at 1×1 so their
            // generate() runs, Metal shaders compile, and SwiftUI caches
            // the view body.  Nearly zero GPU cost at this size.
            ForEach(Array(warmingScenes), id: \.self) { warming in
                if warming != currentScene && warming != previousScene {
                    sceneView(for: warming)
                        .frame(width: 1, height: 1)
                        .clipped()
                        .opacity(0.001)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            // Gentle vignette always on
            vignetteOverlay
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Haiku overlay
            if showHaiku {
                HaikuOverlayView(scene: currentScene)
                    .transition(.opacity)
            }

            // Ethereal scene picker
            if showPicker {
                etherealPicker
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.85)).combined(with: .offset(y: 20)),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
            }

            // Peer indicator
            if !multipeerManager.connectedPeers.isEmpty {
                VStack {
                    HStack { Spacer(); peerDots.padding(16) }
                    Spacer()
                }
            }

            // Mouse tracking for hover-near-bottom
            MouseTrackingView { location, size in
                if location.y > size.height - 70 && !showPicker {
                    showPickerBriefly(duration: 5.0)
                }
            }
            .allowsHitTesting(false)

            // About overlay
            if showAbout {
                AboutView(isPresented: $showAbout)
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
            }

            // Share consent overlay
            if showShareConsent {
                shareConsentOverlay
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
            }

            // Peer invitation overlay
            if multipeerManager.pendingInvitation != nil {
                peerInvitationOverlay
                    .transition(.opacity)
                    .accessibilityAddTraits(.isModal)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onTapGesture(count: 3) {
            withAnimation(.easeInOut(duration: 0.8)) { showHaiku.toggle() }
        }
        .onTapGesture(count: 2) {
            showPickerBriefly()
        }
        // Use simultaneousGesture so single-click fires instantly without
        // waiting for multi-tap disambiguation — feels natural, not clunky.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    interaction.tapLocation = value.location
                    interaction.tapCount += 1
                }
        )
        .gesture(
            MagnifyGesture()
                .onChanged { value in interaction.magnification = value.magnification }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: 1.0)) { interaction.magnification = 1.0 }
                }
        )
        .onKeyPress(.leftArrow) { switchScene(direction: -1); return .handled }
        .onKeyPress(.rightArrow) { switchScene(direction: 1); return .handled }
        .onKeyPress(.space) { showPickerBriefly(); return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "hH")) { _ in
            withAnimation(.easeInOut(duration: 0.8)) { showHaiku.toggle() }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "?")) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { showAbout.toggle() }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "sS")) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                if multipeerManager.isEnabled {
                    multipeerManager.stopSharing()
                } else {
                    showShareConsent = true
                }
            }
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "mM")) { _ in
            audioEngine.isMuted.toggle()
            return .handled
        }
        .onAppear {
            // Start generative ambient audio with the current scene's mood
            audioEngine.start(mood: currentScene.audioMood)
            // Breathing light for 2.5s, then slowly reveal scene over 3.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeInOut(duration: 3.5)) { launched = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                showPickerBriefly(duration: 6.0)
            }
        }
        // Battery: pause rendering when app goes to background
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            isActive = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAboutEnnui)) { _ in
            withAnimation(.easeInOut(duration: 0.5)) { showAbout = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSharing)) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                if multipeerManager.isEnabled {
                    multipeerManager.stopSharing()
                } else {
                    showShareConsent = true
                }
            }
        }
        // Listen for scene changes from connected peers
        .onChange(of: multipeerManager.receivedSceneID) { _, newID in
            guard let id = newID, let scene = SceneKind(rawValue: id) else { return }
            multipeerManager.receivedSceneID = nil
            transitionToScene(scene)
        }
        // Wrap scenes only when active — completely pauses rendering when inactive
        .allowsHitTesting(isActive)
    }

    // MARK: - Scene view builder

    @ViewBuilder
    private func sceneView(for scene: SceneKind) -> some View {
        switch scene {
        case .cosmicDrift: CosmicDriftScene(interaction: interaction)
        case .retroGarden: RetroGardenScene(interaction: interaction)
        case .deepOcean: DeepOceanScene(interaction: interaction)
        case .desertStarscape: DesertStarscapeScene(interaction: interaction)
        case .ancientRuins: AncientRuinsScene(interaction: interaction)
        case .saltLamp: SaltLampScene(interaction: interaction)
        case .conservatory: ConservatoryScene(interaction: interaction)
        case .nightTrain: NightTrainScene(interaction: interaction)
        case .greetingTheDay: GreetingTheDayScene(interaction: interaction)
        case .celShadedRainyDay: CelShadedRainyDayScene(interaction: interaction)
        case .voyagerNebula: VoyagerNebulaScene(interaction: interaction)
        case .retroPS1: RetroPS1Scene(interaction: interaction)
        case .auroraBorealis: AuroraBorealisScene(interaction: interaction)
        case .paperLanternFestival: PaperLanternFestivalScene(interaction: interaction)
        case .forgottenLibrary: ForgottenLibraryScene(interaction: interaction)
        case .lateNightRerun: LateNightRerunScene(interaction: interaction)
        case .medievalVillage: MedievalVillageScene(interaction: interaction)
        case .urbanDreamscape: UrbanDreamscapeScene(interaction: interaction)
        case .lushRuins: LushRuinsScene(interaction: interaction)
        case .enchantedArchives: EnchantedArchivesScene(interaction: interaction)
        case .celestialScrollHall: CelestialScrollHallScene(interaction: interaction)
        case .jeonjuNight: JeonjuNightScene(interaction: interaction)
        case .quietMeal: QuietMealScene(interaction: interaction)
        case .artDecoLA: ArtDecoLAScene(interaction: interaction)
        case .floatingKingdom: FloatingKingdomScene(interaction: interaction)
        case .ontarioCountryside: OntarioCountrysideScene(interaction: interaction)
        case .minnesotaSmallTown: MinnesotaSmallTownScene(interaction: interaction)
        case .shimizuEvening: ShimizuEveningScene(interaction: interaction)
        case .mystify: MystifyScene(interaction: interaction)
        case .midnightMotel: MidnightMotelScene(interaction: interaction)
        case .captainStar: CaptainStarScene(interaction: interaction)
        case .nonsenseLullabies: NonsenseLullabiesScene(interaction: interaction)
        case .gouraudSolarSystem: GouraudSolarSystemScene(interaction: interaction)
        case .medievalVillage3D: MedievalVillage3DScene(interaction: interaction)
        case .lateNightRerun3D: LateNightRerun3DScene(interaction: interaction)
        case .jeonjuNight3D: JeonjuNight3DScene(interaction: interaction)
        case .cosmicDrift3D: CosmicDrift3DScene(interaction: interaction)
        case .voyagerNebula3D: VoyagerNebula3DScene(interaction: interaction)
        case .desertStarscape3D: DesertStarscape3DScene(interaction: interaction)
        case .deepOcean3D: DeepOcean3DScene(interaction: interaction)
        case .ancientRuins3D: AncientRuins3DScene(interaction: interaction)
        case .auroraBorealis3D: AuroraBorealis3DScene(interaction: interaction)
        case .lushRuins3D: LushRuins3DScene(interaction: interaction)
        case .saltLamp3D: SaltLamp3DScene(interaction: interaction)
        case .conservatory3D: Conservatory3DScene(interaction: interaction)
        case .quietMeal3D: QuietMeal3DScene(interaction: interaction)
        case .nightTrain3D: NightTrain3DScene(interaction: interaction)
        case .midnightMotel3D: MidnightMotel3DScene(interaction: interaction)
        case .artDecoLA3D: ArtDecoLA3DScene(interaction: interaction)
        case .urbanDreamscape3D: UrbanDreamscape3DScene(interaction: interaction)
        case .shimizuEvening3D: ShimizuEvening3DScene(interaction: interaction)
        case .ontarioCountryside3D: OntarioCountryside3DScene(interaction: interaction)
        case .minnesotaSmallTown3D: MinnesotaSmallTown3DScene(interaction: interaction)
        case .forgottenLibrary3D: ForgottenLibrary3DScene(interaction: interaction)
        case .enchantedArchives3D: EnchantedArchives3DScene(interaction: interaction)
        case .celestialScrollHall3D: CelestialScrollHall3DScene(interaction: interaction)
        case .floatingKingdom3D: FloatingKingdom3DScene(interaction: interaction)
        case .paperLanternFestival3D: PaperLanternFestival3DScene(interaction: interaction)
        case .retroGarden3D: RetroGardenScene(interaction: interaction)
        case .celShadedRainyDay3D: CelShadedRainyDayScene(interaction: interaction)
        case .retroPS13D: RetroPS1Scene(interaction: interaction)
        case .greetingTheDay3D: GreetingTheDayScene(interaction: interaction)
        case .mystify3D: MystifyScene(interaction: interaction)
        case .nonsenseLullabies3D: NonsenseLullabiesScene(interaction: interaction)
        case .captainStar3D: CaptainStar3DScene(interaction: interaction)
        case .gouraudSolarSystem3D: GouraudSolarSystem3DScene(interaction: interaction)
        }
    }

    // MARK: - Vignette (adds dreamy edge darkening)

    private var vignetteOverlay: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height / 2
            let r = max(geo.size.width, geo.size.height) * 0.7
            Canvas { ctx, size in
                ctx.fill(
                    Rectangle().path(in: CGRect(origin: .zero, size: size)),
                    with: .radialGradient(
                        Gradient(colors: [
                            .clear,
                            .clear,
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.5),
                        ]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: r * 0.3,
                        endRadius: r
                    )
                )
            }
        }
    }

    // MARK: - Ethereal floating scene picker

    private var etherealPicker: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            VStack {
                Spacer()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(SceneKind.allCases.enumerated()), id: \.element.id) { idx, scene in
                            let isActive = scene == currentScene
                            let float = sin(t * 0.6 + Double(idx) * 1.1) * 3
                            let glow = sin(t * 0.8 + Double(idx) * 0.7) * 0.15 + 0.85

                            Button {
                                transitionToScene(scene)
                            } label: {
                                ZStack {
                                    // Outer glow ring
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    scene.tint.opacity(isActive ? 0.5 * glow : 0.1),
                                                    scene.tint.opacity(isActive ? 0.15 : 0.0),
                                                    .clear
                                                ],
                                                center: .center,
                                                startRadius: 4,
                                                endRadius: isActive ? 22 : 15
                                            )
                                        )
                                        .frame(width: isActive ? 40 : 30, height: isActive ? 40 : 30)

                                    // Inner orb
                                    Circle()
                                        .fill(
                                            RadialGradient(
                                                colors: [
                                                    scene.tint.opacity(isActive ? 0.95 : 0.35),
                                                    scene.tint.opacity(isActive ? 0.6 : 0.15),
                                                    .clear
                                                ],
                                                center: .center,
                                                startRadius: 0,
                                                endRadius: isActive ? 10 : 7
                                            )
                                        )
                                        .frame(width: isActive ? 20 : 14, height: isActive ? 20 : 14)

                                    // Bright core
                                    Circle()
                                        .fill(scene.tint.opacity(isActive ? 0.9 * glow : 0.3))
                                        .frame(width: isActive ? 6 : 3, height: isActive ? 6 : 3)
                                        .blur(radius: isActive ? 1.5 : 0.5)
                                }
                                .offset(y: float)
                                .animation(.easeInOut(duration: 0.6), value: isActive)
                            }
                            .buttonStyle(.plain)
                            .onHover { hovering in
                                if hovering && scene != currentScene {
                                    warmingScenes.insert(scene)
                                }
                            }
                            .accessibilityLabel(scene.displayName)
                            .accessibilityHint(isActive ? "Currently viewing" : "Switch to \(scene.displayName)")
                            .accessibilityAddTraits(isActive ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: 700)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(.black.opacity(0.25))
                        .blur(radius: 20)
                )
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Peer dots

    private var peerDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(multipeerManager.connectedPeers.count, 5), id: \.self) { _ in
                Circle().fill(.green.opacity(0.6)).frame(width: 5, height: 5)
            }
        }
        .padding(8)
        .background(.ultraThinMaterial.opacity(0.2), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(multipeerManager.connectedPeers.count) nearby \(multipeerManager.connectedPeers.count == 1 ? "person" : "people") sharing this moment")
    }

    // MARK: - Share consent overlay

    private var shareConsentOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeIn(duration: 0.35)) { showShareConsent = false }
                }

            VStack(spacing: 0) {
                Text("Share This Moment")
                    .font(.system(size: 22, weight: .thin, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84))
                    .tracking(2)
                    .padding(.bottom, 16)

                Text("Share your current scene with someone nearby on the same Wi-Fi network, so you can drift through the same world together.")
                    .font(.system(size: 13, weight: .light, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84).opacity(0.6))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 12)

                Text("Your name won't be shared — you'll appear anonymously. No personal data is ever sent. You can stop sharing at any time by pressing S again.")
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84).opacity(0.45))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                HStack(spacing: 20) {
                    Button {
                        withAnimation(.easeIn(duration: 0.35)) { showShareConsent = false }
                    } label: {
                        Text("Not now")
                            .font(.system(size: 13, weight: .light, design: .serif))
                            .foregroundStyle(Color(red: 0.65, green: 0.6, blue: 0.55).opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Not now")
                    .accessibilityHint("Dismiss without sharing")

                    Button {
                        multipeerManager.startSharing()
                        withAnimation(.easeIn(duration: 0.35)) { showShareConsent = false }
                    } label: {
                        Text("Share")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.2))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Share")
                    .accessibilityHint("Begin sharing your scene with nearby devices")
                }
            }
            .frame(maxWidth: 380)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.95))
                    .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Peer invitation overlay

    private var peerInvitationOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Text("Someone Nearby")
                    .font(.system(size: 22, weight: .thin, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84))
                    .tracking(2)
                    .padding(.bottom, 16)

                Text("Someone on your network would like to share a calm moment with you. Your scenes will stay in sync while connected.")
                    .font(.system(size: 13, weight: .light, design: .serif))
                    .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84).opacity(0.6))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                HStack(spacing: 20) {
                    Button {
                        multipeerManager.declineInvitation()
                    } label: {
                        Text("Decline")
                            .font(.system(size: 13, weight: .light, design: .serif))
                            .foregroundStyle(Color(red: 0.65, green: 0.6, blue: 0.55).opacity(0.7))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decline")
                    .accessibilityHint("Decline the connection request")

                    Button {
                        multipeerManager.acceptInvitation()
                    } label: {
                        Text("Accept")
                            .font(.system(size: 13, weight: .regular, design: .serif))
                            .foregroundStyle(Color(red: 0.95, green: 0.91, blue: 0.84))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.2))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Accept")
                    .accessibilityHint("Accept and share scenes with this person")
                }
            }
            .frame(maxWidth: 380)
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(red: 0.08, green: 0.07, blue: 0.06).opacity(0.95))
                    .shadow(color: .black.opacity(0.5), radius: 40, y: 10)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color(red: 0.78, green: 0.68, blue: 0.48).opacity(0.08), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Helpers

    private func showPickerBriefly(duration: TimeInterval = 4.5) {
        pickerTimer?.invalidate()
        withAnimation(.easeOut(duration: 0.6)) { showPicker = true }
        pickerTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 1.2)) { showPicker = false }
            }
        }
    }

    private func transitionToScene(_ scene: SceneKind) {
        guard scene != currentScene else { return }
        previousScene = currentScene
        crossfade = 0.0
        currentScene = scene
        warmingScenes.remove(scene) // no longer needs warming
        audioEngine.changeMood(scene.audioMood)
        withAnimation(.easeInOut(duration: 2.0)) { crossfade = 1.0 }
        // Clean up previous after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            previousScene = nil
            warmingScenes.removeAll() // clear stale preloads
        }
        // Preload adjacent scenes for arrow-key navigation
        preloadNeighbors(of: scene)
        multipeerManager.send(sceneID: scene.rawValue)
        showPickerBriefly()
    }

    /// Pre-warm the scenes immediately before and after the current one
    /// so left/right arrow key switches feel instant.
    private func preloadNeighbors(of scene: SceneKind) {
        let all = SceneKind.allCases
        guard let idx = all.firstIndex(of: scene) else { return }
        let prev = all[(idx - 1 + all.count) % all.count]
        let next = all[(idx + 1) % all.count]
        // Slight delay so the current transition isn't competing for resources
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            warmingScenes.insert(prev)
            warmingScenes.insert(next)
        }
    }

    private func switchScene(direction: Int) {
        let all = SceneKind.allCases
        guard let idx = all.firstIndex(of: currentScene) else { return }
        let next = (idx + direction + all.count) % all.count
        transitionToScene(all[next])
    }
}

// MARK: - Mouse tracking for hover-near-bottom detection

struct MouseTracker {
    var lastY: CGFloat = 0
}

#if os(macOS)
struct MouseTrackingView: NSViewRepresentable {
    let onMove: (CGPoint, CGSize) -> Void

    func makeNSView(context: Context) -> TrackingNSView {
        let view = TrackingNSView()
        view.onMove = onMove
        return view
    }

    func updateNSView(_ nsView: TrackingNSView, context: Context) {
        nsView.onMove = onMove
    }

    class TrackingNSView: NSView {
        var onMove: ((CGPoint, CGSize) -> Void)?
        private var trackingArea: NSTrackingArea?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let existing = trackingArea { removeTrackingArea(existing) }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            trackingArea = area
        }

        override func mouseMoved(with event: NSEvent) {
            let loc = convert(event.locationInWindow, from: nil)
            let flipped = CGPoint(x: loc.x, y: bounds.height - loc.y)
            onMove?(flipped, bounds.size)
        }
    }
}
#else
struct MouseTrackingView: View {
    let onMove: (CGPoint, CGSize) -> Void
    var body: some View { Color.clear }
}
#endif
