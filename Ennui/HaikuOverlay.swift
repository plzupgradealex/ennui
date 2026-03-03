import SwiftUI
import FoundationModels

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
            .paperLanternFestival: "a serene lake at dusk, each click releasing a single warm lantern carrying a kind message into the quiet night sky, fireflies drifting gently",
            .forgottenLibrary: "an infinite twilight library with towering bookshelves, candlelight, floating golden letters drifting upward like embers, and moonlight through arched windows",
            .lateNightRerun: "falling asleep to late-night TV reruns in a cozy 90s bedroom, CRT glow, lava lamp, glow-in-the-dark stars on the ceiling, rain on the window",
            .medievalVillage: "a peaceful medieval village settling down for the night, fires extinguished one by one, chimney smoke, moonlight on thatched roofs, aurora appearing as the village sleeps",
            .urbanDreamscape: "a dreamy cel-shaded city blending Paris, Tokyo, Rome, Istanbul, and New York at night, neon signs reflecting in rain puddles, an elevated train passing, PS1-style lo-fi aesthetic",
            .lushRuins: "ancient moss-covered temple ruins in a lush humid tropical jungle, waterfalls cascading over carved stone, god rays through dense canopy, butterflies, dripping water, Borobudur-inspired",
            .enchantedArchives: "a wild magical library where books fly open and paper origami birds soar between living shelves, lightning arcs between bookcases, stained glass rosette windows cast kaleidoscopic light, golden glyphs orbit in galaxies",
            .celestialScrollHall: "a moonlit Chinese study hall with calligraphy scrolls, ink stones, and positive characters glowing softly like lanterns in a quiet courtyard",
            .jeonjuNight: "a quiet Korean neighbourhood at night in the 1990s, hanok rooftops, a convenience store glowing, telephone wires against a lavender sky, a cat on a wall, moths around a street lamp",
            .quietMeal: "two friends sharing a quiet meal in a small restaurant, seen through the window from outside on a rainy evening, warmth inside, blue dusk outside, the simple joy of being together",
            .artDecoLA: "a golden hour art deco Los Angeles boulevard with palm tree silhouettes, streamline moderne buildings, warm neon signs, a vintage red Pacific Electric streetcar, and searchlight beams sweeping a coral and violet sky",
            .floatingKingdom: "a sky kingdom floating above luminous clouds, crystalline spires catching ancient light, waterfalls cascading off floating islands into golden mist, motes of warm magical energy drifting upward like prayers, the peaceful heart of an eternal dream",
            .ontarioCountryside: "a warm summer evening in the rural countryside of southern Ontario in the early 1990s, golden wheat fields rolling toward a distant treeline, an old red barn and silo, a gravel road vanishing to the horizon, fireflies blinking in the blue hour, power lines tracing the road, the last amber light on everything",
            .minnesotaSmallTown: "a calm summer evening in a tiny Minnesota prairie town, an enormous pink and gold sky over Main Street, a white church steeple, a water tower, a grain elevator, a diner with a flickering neon sign, street lamps coming on, fireflies over the flat quiet land, nothing happens and that is the whole point",
            .shimizuEvening: "a quiet rainy evening in a small Japanese residential neighbourhood in Shizuoka, warm yellow windows glowing behind a concrete block wall, rain falling on a street with puddles, a corner shop with a striped awning, utility poles and wires, rounded bushes, the gentle sound of rain on everything, a feeling of being safely home while the world is soft and wet outside",
            .mystify: "glowing coloured lines bouncing gently across a dark CRT screen, leaving fading phosphor trails, the hypnotic comfort of a Windows 95 screensaver running late at night in a quiet house, warmth in geometry, nostalgia in every pixel",
            .midnightMotel: "a quiet motel room somewhere in America in 1968, wood-paneled walls, a neon vacancy sign bleeding pink light through thin curtains, a warm table lamp, a rotary phone on the nightstand, a patterned bedspread, headlights from the highway sweeping across the ceiling, dust motes floating in the lamplight, the gentle solitude of being safely nowhere",
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
            "One gentle click\nA kind word lifts into dusk\nThe lake holds its glow",
            "Be still says the flame\nRising slow through violet air\nThe water remembers",
            "Each lantern a wish\nDrifting upward without haste\nThe night leans in close",
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
        .medievalVillage: [
            "Candles dim one more\nThe blacksmith rests his hammer\nMoonlight takes the watch",
            "Thatched roofs catch the dew\nChimney smoke curls into stars\nThe village dreams now",
            "One by one lights fade\nFireflies replace the torches\nAurora whispers",
        ],
        .urbanDreamscape: [
            "Neon writes on rain\nTokyo blurs into Paris\nThe train hums past Rome",
            "Puddles hold the sky\nA thousand cities in one\nPixels softly glow",
            "Minarets and spires\nMeet beneath the scanline haze\nDreams in low-res light",
        ],
        .lushRuins: [
            "Stone exhales green mist\nWater finds its ancient path\nThe jungle reclaims",
            "Wet leaves catch the light\nTemple steps dissolve in moss\nButterflies keep time",
            "Rain on carved Buddha\nVines embrace what hands once built\nSteam rises like prayer",
        ],
        .enchantedArchives: [
            "Lightning finds the page\nPaper birds scatter like thoughts\nInk becomes the sky",
            "Glyphs orbit in gold\nThe shelves breathe and lean toward\nKnowledge made of light",
            "Books open and fly\nStained glass casts a thousand hues\nMagic reads itself",
        ],
        .celestialScrollHall: [
            "Ink meets moonlit silk\nCharacters glow like lanterns\nWisdom breathes in light",
            "Scrolls unfurl in dark\nBrush strokes hold a thousand years\nThe hall remembers",
            "Quiet courtyard waits\nMoonlight paints the empty page\nWords find their own way",
        ],
        .jeonjuNight: [
            "Hanok roofs hold dew\nA convenience store still glows\nThe cat watches on",
            "Telephone wires hum\nMoth wings catch the lamplight's glow\nSummer in Jeonju",
            "One window goes dark\nAnother flickers awake\nThe neighbourhood breathes",
        ],
        .quietMeal: [
            "Rain on window glass\nTwo friends laugh over their bowls\nWarmth needs no reason",
            "Steam rises between\nTwo people who chose each day\nTo simply show up",
            "Through the foggy pane\nA meal shared is all it takes\nThe world feels smaller",
        ],
        .artDecoLA: [
            "Golden light descends\nPalm trees frame the boulevard\nNeon hums goodnight",
            "Deco spires catch\nThe last warm breath of the sun\nThe streetcar rolls on",
            "Searchlights trace the sky\nWarm windows in streamline walls\nLos Angeles dreams",
        ],
        .floatingKingdom: [
            "Crystal spires rise\nAbove the clouds a kingdom\nDreams in ancient light",
            "Waterfalls descend\nFrom floating islands to mist\nMagic drifts like prayer",
            "The palace glows warm\nAbove an endless cloud sea\nNothing here can fall",
        ],
        .ontarioCountryside: [
            "Wheat bends in the wind\nThe barn holds the last amber\nFireflies begin",
            "Gravel under tires\nPower lines hum the same song\nAugust never ends",
            "The window glows warm\nFields darken toward the treeline\nSomeone is still home",
        ],
        .minnesotaSmallTown: [
            "The steeple holds still\nMain Street darkens by degrees\nNeon hums alone",
            "Water tower stands\nAbove the quiet prairie\nNothing needs to change",
            "A dog sleeps on the porch\nThe diner light stays on late\nSomeone knows your name",
        ],
        .shimizuEvening: [
            "Rain taps the grey wall\nWarm light through the window glass\nSupper must be soon",
            "Puddles on the street\nThe shop awning drips a tune\nEvening settles in",
            "Wires hum with rain\nA window glows behind the fence\nSomeone is still home",
        ],
        .mystify: [
            "Lines trace the dark glass\nPhosphor trails fade to nothing\nThe screen dreams for us",
            "Cyan meets amber\nBouncing through the quiet night\nNinety-five glows on",
            "Colours never rest\nThey wander the CRT\nWarm geometry",
        ],
        .midnightMotel: [
            "Neon bleeds through lace\nThe highway hums a lullaby\nDust floats in the light",
            "Wood walls hold the dark\nA rotary phone waits still\nHeadlights cross the room",
            "Vacancy sign glows\nSomeone rests between two towns\nThe lamp breathes for them",
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
                    .accessibilityLabel("Haiku: \\(currentHaiku.replacingOccurrences(of: \"\\n\", with: \". \"))")
                    .accessibilityAddTraits(.updatesFrequently)
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

        // Apple's on-device FoundationModels include built-in safety —
        // we trust the model to produce innocent, kind haiku.
        let generator = HaikuGenerator()
        newHaiku = await generator.generate(for: scene)

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
