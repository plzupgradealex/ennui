import SwiftUI
import FoundationModels

@available(macOS 26.0, *)
actor HaikuGenerator {
    private var session: LanguageModelSession?

    func generate(for scene: SceneKind) async -> String? {
        let themes: [SceneKind: String] = [
            .cosmicDrift: "gently drifting through warm nebulae and twinkling stars",
            .retroGarden: "a peaceful pixel-art garden with flowers and butterflies",
            .deepOcean: "bioluminescent creatures glowing softly in the deep ocean",
            .desertStarscape: "warm desert dunes beneath a vast starry sky",
            .ancientRuins: "ancient stone ruins bathed in soft aurora light with fireflies",
            .saltLamp: "the warm amber glow of a himalayan salt lamp",
            .conservatory: "rain on greenhouse windows with plants swaying and steam from old pipes",
            .nightTrain: "a gentle night train journey through moonlit countryside with warm glowing windows",
            .greetingTheDay: "a city waking up at sunrise with buildings growing and a feeling of calm readiness",
            .celShadedRainyDay: "bright flowers thriving in gentle rain, fat raindrops on petals, puddles forming, a cosy rainy day in a cartoon world",
            .voyagerNebula: "drifting through a magnificent nebula in deep space, swirling colours of teal and magenta, stellar nurseries glowing warmly",
        ]
        let theme = themes[scene] ?? "a peaceful calming moment"

        do {
            let session = LanguageModelSession()
            self.session = session

            let prompt = """
            Write a single short calming haiku (3 lines, 5-7-5 syllables) about: \(theme). \
            It must be innocent, kind, gentle, and comforting. Nothing dark or sad. \
            Only output the haiku, nothing else. No title, no quotes.
            """

            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}

struct HaikuOverlayView: View {
    let scene: SceneKind
    @State private var currentHaiku: String = ""
    @State private var opacity: Double = 0

    private static let fallbackHaiku: [SceneKind: [String]] = [
        .cosmicDrift: [
            "Stars drift through the void\nSilent rivers of pale light\nBreathing with the dark",
            "Nebula exhales\nColors born from ancient dust\nTime forgets itself",
            "Soft light finds its way\nThrough the gentle cosmic dust\nWarmth in endless space",
        ],
        .retroGarden: [
            "Pixel petals fall\nEight-bit breeze through blocky leaves\nSimple joy returns",
            "Butterflies of light\nDancing over mossy tiles\nSunset renders slow",
            "Small garden grows bright\nEvery square a tiny world\nPeace in simple shapes",
        ],
        .deepOcean: [
            "Quiet pressure holds\nJellyfish like drifting moons\nGlowing in the deep",
            "Currents carry me\nPast creatures without names yet\nPeace lives far below",
            "Soft light pulses here\nThe ocean hums a lullaby\nAll is held by blue",
        ],
        .desertStarscape: [
            "Dunes hold ancient warmth\nA billion stars lean closer\nSand remembers rain",
            "One grain, one bright star\nBoth patient beyond measure\nNight stretches between",
            "Warm wind tells a tale\nOf patience and gentle time\nStars listen and glow",
        ],
        .ancientRuins: [
            "Columns hold up sky\nAurora drapes like soft cloth\nStone dreams of the past",
            "Fireflies attend\nThe ceremony of dusk\nRuins softly glow",
            "Moss reclaims the steps\nGreen light dances on old walls\nTime moves like water",
        ],
        .saltLamp: [
            "Amber glow holds still\nWarm crystal breathes with the room\nNothing needs to change",
            "Soft orange light hums\nSalt remembers ancient seas\nComfort in the glow",
            "A gentle warm light\nStill and patient through the night\nEverything is fine",
        ],
        .conservatory: [
            "Rain taps on the glass\nWarm earth breathes beneath the ferns\nSteam curls like a thought",
            "Droplets find their way\nDown the greenhouse windowpanes\nPlants sway, slow and kind",
            "Grey sky holds the world\nInside, green and warm and still\nRain sings us to sleep",
        ],
        .nightTrain: [
            "Wheels hum on the tracks\nMoonlight paints the sleeping fields\nWarm light rocks me home",
            "Telegraph poles pass\nCounting moments until dawn\nThe journey is peace",
            "Steam dissolves in dark\nWindows glow like amber stars\nMoving through the night",
        ],
        .greetingTheDay: [
            "The city awakens\nEach window a gentle eye\nSunrise says begin",
            "Buildings reach for light\nNew day stretches, safe and warm\nReady for the world",
            "Morning paints the town\nEvery corner holds a hope\nSteady as the sun",
        ],
        .celShadedRainyDay: [
            "Bright petals hold rain\nDroplets slide from leaf to ground\nPuddles bloom below",
            "Grey clouds roll above\nFlowers dance in gentle storms\nColour fills the world",
            "Fat drops tap the leaves\nEvery petal wears a gem\nThe garden drinks deep",
        ],
        .voyagerNebula: [
            "Teal and rose entwine\nGas clouds birth a thousand suns\nSilence paints the sky",
            "Dust lanes curve like roads\nStarlight finds its way between\nThe nebula breathes",
            "Colours without name\nSwirl through ancient cosmic dust\nWe drift, warm and still",
        ],
    ]

    var body: some View {
        VStack {
            Spacer()
            if !currentHaiku.isEmpty {
                Text(currentHaiku)
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 40)
                    .padding(.vertical, 16)
                    .background(.ultraThinMaterial.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    .opacity(opacity)
                    .padding(.bottom, 60)
            }
        }
        .allowsHitTesting(false)
        .task(id: scene) {
            await cycleHaiku()
        }
    }

    private func cycleHaiku() async {
        withAnimation(.easeOut(duration: 1.0)) { opacity = 0 }
        try? await Task.sleep(for: .seconds(1.5))

        var newHaiku: String? = nil

        if #available(macOS 26.0, *) {
            let generator = HaikuGenerator()
            newHaiku = await generator.generate(for: scene)
        }

        if newHaiku == nil {
            let pool = Self.fallbackHaiku[scene] ?? ["Stillness surrounds me\nA gentle world without rush\nJust this, nothing more"]
            newHaiku = pool.randomElement()
        }

        currentHaiku = newHaiku ?? ""

        withAnimation(.easeIn(duration: 2.0)) { opacity = 1.0 }

        try? await Task.sleep(for: .seconds(30))
        guard !Task.isCancelled else { return }
        await cycleHaiku()
    }
}
