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
            .retroPS1: "a nostalgic PS1/N64 nighttime scene with low-poly mountains, a glowing cabin, fireflies, and chunky pixel stars",
            .auroraBorealis: "the northern lights dancing in green and violet curtains over a frozen lake with silhouetted pine trees and a distant warm cabin",
            .paperLanternFestival: "hundreds of warm glowing paper lanterns rising gently into the twilight sky over a dark reflective lake, fireflies dancing between them",
            .forgottenLibrary: "an infinite twilight library with towering bookshelves, candlelight, floating golden letters drifting upward like embers, and moonlight through arched windows",
            .lateNightRerun: "falling asleep to late-night TV reruns in a cozy 90s bedroom, CRT glow, lava lamp, glow-in-the-dark stars on the ceiling, rain on the window",
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
        .retroPS1: [
            "Pixels hold the night\nA cabin glows in the dark\nFireflies remember",
            "Low-poly mountains\nReflected in quiet lakes\nNostalgia is warm",
            "Vertex jitter dreams\nChunky stars above the pines\nThe old world still hums",
        ],
        .auroraBorealis: [
            "Green curtains unfold\nThe frozen lake holds its breath\nLight dances alone",
            "Violet ribbons\nStitch the dark sky back together\nPines stand and witness",
            "Cold air carries light\nThe aurora hums in silence\nSnow remembers warmth",
        ],
        .paperLanternFestival: [
            "A hundred small suns\nRise slowly from the water\nWishes float like light",
            "Warm paper and flame\nDrifting through the evening sky\nThe lake holds their glow",
            "Lanterns climb the dark\nEach one a quiet prayer\nThe night leans in close",
        ],
        .forgottenLibrary: [
            "Dust motes catch the flame\nOld pages breathe forgotten\nWords still drift upward",
            "Moonlight through the arch\nA thousand spines lean and wait\nSilence reads itself",
            "Candle flickers soft\nLetters rise from open books\nKnowledge turns to light",
        ],
        .lateNightRerun: [
            "Static hums goodnight\nThe lava lamp keeps its watch\nGlow stars guard the dark",
            "Reruns play for none\nRain and television light\nSafe beneath the sheets",
            "Twelve fifteen glows red\nThe world outside falls asleep\nThis room holds me close",
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
