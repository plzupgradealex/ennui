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
            .captainStar: "a barren desert planet at the very edge of the universe, yellow and ochre skies stretching forever, floating rocks defying gravity, a lone glass and crystal outpost catching distant starlight, dust motes drifting through warm emptiness, stars visible through the haze, cosmic desolation that is somehow peaceful and beautiful",
            .nonsenseLullabies: "a hand-painted watercolour world like a page from a beloved picture book, soft washes of colour bleeding into warm paper, simple nursery shapes drifting gently — moons, stars, cats, little houses, birds, flowers — paint drips running slowly down the page, the gentle nonsense of lullabies and bedtime stories",
            .gouraudSolarSystem: "an imaginary solar system rendered in retro Gouraud-shaded 3D, a warm star at the centre, smooth-lit planets with specular highlights orbiting in ellipses, ring systems catching the light, tiny moons tracing paths around gas giants, faint scanlines and orbital grid lines giving it the feel of a late-nineties tech demo running at two in the morning",
            .medievalVillage3D: "a low-poly three-dimensional medieval village diorama viewed from above like a tabletop model, warm amber window lights, moonlit thatched roofs, firefly particles drifting between cottages, a church steeple, fog rolling in, the camera orbiting slowly as if you were an owl circling the sleeping hamlet",
            .lateNightRerun3D: "a three-dimensional nineties bedroom seen from the perspective of lying in bed, a CRT television casting shifting colored light across purple walls, green glow-in-the-dark stars on the ceiling, a lava lamp pulsing pink on the nightstand, the cozy geometry of a room you fell asleep in a thousand times",
            .jeonjuNight3D: "a three-dimensional quiet Korean neighbourhood at night, hanok houses with warm lit windows, a sodium vapour street lamp casting warm orange light onto the road, moths orbiting the lamp, a cat sitting on a wall with green eyes, telephone wires against the deep blue sky, the crescent moon",
            .oldCar: "behind the wheel of a big 1950s American land yacht driving through a snowstorm at night, windshield wipers sweeping, incandescent dash glowing amber, chrome radio knobs, utility poles and barns drifting past in the dark, the warmth of the heater against the cold outside",
            .oldCar3D: "a three-dimensional view from inside a 1950s bench-seat land yacht driving through a blizzard at night, snow rushing at the windshield, wipers sweeping, the warm dash glow reflected on the glass, barns and utility poles in the dark, the comforting rumble of the engine",
            .cosmicDrift3D: "a three-dimensional journey through warm nebulae and twinkling star fields, gas clouds rendered as translucent volumes, the camera drifting slowly through gentle cosmic space, depth giving the dust lanes a velvet softness",
            .voyagerNebula3D: "a three-dimensional passage through a magnificent stellar nursery, swirling teal and magenta gas rendered with depth, newborn stars glowing warmly inside sculptural cloud pillars, the silence of deep space made spatial",
            .desertStarscape3D: "a three-dimensional desert landscape at night, sculpted dunes receding into warm darkness, the milky way arching overhead with real depth, the quiet warmth of sand still holding the day's heat",
            .deepOcean3D: "a three-dimensional descent into bioluminescent ocean depths, jellyfish pulsing with soft light rendered as translucent volumes, particles drifting in the current, the pressure and peace of the deep made spatial",
            .ancientRuins3D: "three-dimensional ancient stone ruins under aurora light, crumbling columns with real depth, firefly particles drifting between the arches, soft green light playing across weathered stone surfaces",
            .lushRuins3D: "a three-dimensional temple ruin in a lush tropical jungle, waterfalls cascading over carved stone with real depth, god rays piercing the dense canopy, butterflies circling moss-covered Buddha faces",
            .auroraBorealis3D: "a three-dimensional frozen landscape beneath the northern lights, aurora curtains rendered with translucent depth, silhouetted pine trees receding to a warm cabin, the frozen lake reflecting green and violet light",
            .saltLamp3D: "a three-dimensional himalayan salt lamp glowing with warm amber light, the crystal rendered with subsurface scattering, gentle light filling a cozy space, the breathing pulse of warmth given real volume",
            .conservatory3D: "a three-dimensional greenhouse interior, rain streaming down glass panes with refraction, tropical plants rendered with depth, steam curling from old pipes, the warm humid comfort of a living space",
            .quietMeal3D: "a three-dimensional view through a rain-streaked restaurant window, two friends sharing a meal inside rendered with warm depth, the blue dusk outside contrasting with golden interior light, rain drops on the glass between you and the scene",
            .artDecoLA3D: "a three-dimensional art deco Los Angeles boulevard at golden hour, streamline moderne buildings with real depth and shadows, palm trees casting long geometry, a vintage streetcar rendered in warm light, searchlight beams sweeping through the sky",
            .urbanDreamscape3D: "a three-dimensional dreamy city blending architectural styles from around the world, neon signs with real glow and depth, rain puddles reflecting modelled buildings, an elevated train passing through the scene, low-poly dreamlike geometry",
            .shimizuEvening3D: "a three-dimensional quiet Japanese neighbourhood in the rain, concrete walls and tiled roofs with real depth, warm yellow light from windows casting volumetric glow, puddles reflecting the street scene, utility poles and wires receding into the evening",
            .nightTrain3D: "a three-dimensional night train journey, the locomotive rendered with warm glowing windows, moonlit countryside scrolling past with depth, telegraph poles passing, the gentle rocking motion of travel through the dark",
            .ontarioCountryside3D: "a three-dimensional southern Ontario rural landscape at dusk in the early 1990s, wheat fields with real depth rolling toward a distant treeline, a red barn and silo modelled in warm light, fireflies as particles in the blue hour",
            .minnesotaSmallTown3D: "a three-dimensional tiny Minnesota prairie town at dusk, a white church steeple and water tower with real height, Main Street receding into an enormous pink sky, a grain elevator, a diner with neon, fireflies over the flat land",
            .midnightMotel3D: "a three-dimensional motel room in 1968 America, wood-paneled walls with depth, a neon vacancy sign casting pink volumetric light through thin curtains, a warm table lamp, headlights sweeping across the ceiling, dust motes in the lamplight",
            .forgottenLibrary3D: "a three-dimensional infinite twilight library, towering bookshelves receding in every direction with real depth, candlelight casting warm volumetric glow, floating golden letters drifting upward like embers, moonlight through arched windows",
            .enchantedArchives3D: "a three-dimensional wild magical library, books flying open with real trajectory, paper origami birds soaring between shelves with depth, lightning arcing between bookcases, stained glass casting kaleidoscopic volumetric light",
            .celestialScrollHall3D: "a three-dimensional moonlit Chinese study hall, calligraphy scrolls rendered with depth, ink stones and brush rests modelled on a wooden desk, positive characters glowing softly like lanterns, moonlight pooling on the courtyard floor",
            .floatingKingdom3D: "a three-dimensional sky kingdom floating above luminous clouds, crystalline spires with real height catching ancient light, waterfalls cascading off floating islands into golden mist below, motes of warm magical energy drifting upward",
            .paperLanternFestival3D: "a three-dimensional serene lake at dusk, each tap releasing a warm lantern with real volume rising into the sky, fireflies as particles drifting over the water surface, reflections rendered with depth on the dark lake",
            .captainStar3D: "a three-dimensional barren desert planet at the edge of the universe, ochre terrain stretching to the horizon with real depth, floating rocks defying gravity, a lone crystal outpost catching distant starlight, dust particles drifting through warm emptiness",
            .gouraudSolarSystem3D: "a three-dimensional retro solar system with Gouraud-shaded planets orbiting a warm star, smooth specular highlights on spherical worlds, ring systems with real depth, tiny moons tracing orbital paths, faint grid lines giving it the feel of a nineties demo",
            .retroGarden3D: "a three-dimensional pixel-art inspired garden, blocky flowers and trees rendered with voxel-like depth, butterflies with simple geometry fluttering between the rows, warm sunlight casting crisp shadows, the charm of low resolution made spatial",
            .celShadedRainyDay3D: "a three-dimensional cel-shaded garden in gentle rain, bright cartoon flowers with toon-shaded depth, fat raindrops rendered as falling spheres, puddles forming with real surface reflections, the cozy charm of a rainy day in three dimensions",
            .retroPS13D: "a three-dimensional PS1-era scene with intentionally low-poly mountains, a glowing cabin with warm light, fireflies as simple particle spheres, chunky vertex-jittered stars, the nostalgic beauty of early 3D rendered with love",
            .greetingTheDay3D: "a three-dimensional city at sunrise, buildings rendered with real height and depth growing in the morning light, warm sun rays between the structures, the gentle feeling of a world waking up, each window catching the dawn",
            .mystify3D: "a three-dimensional homage to the classic screensaver, glowing coloured lines bouncing through a dark space with real depth, phosphor trails fading behind them, the hypnotic geometry of Windows 95 given an extra dimension",
            .nonsenseLullabies3D: "a three-dimensional watercolour world like a pop-up picture book, soft painted shapes with gentle depth — moons, stars, cats, little houses — paper texture visible on the surfaces, paint drips running slowly, the gentle nonsense of bedtime stories made spatial",
            .innerLight3D: "warm glowing geometric forms floating in deep indigo space, faceted crystalline icosahedra connected by luminous golden filaments that pulse softly, tiny motes rising from below like thoughts forming, the quiet inner space of a mind that thinks in patterns and light",
            .wireframeCity3D: "a green phosphor wireframe cityscape on pure black, glowing vector-graphic buildings viewed from a slow flyover, a scrolling grid floor underneath, the whole scene looks like a nineteen-eighties vector display terminal, scan lines faintly visible, the iconic early-CG aesthetic of wireframe worlds",
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
        .captainStar: [
            "Ochre sky stretches\nA glass tower catches light\nThe edge holds its breath",
            "Rocks drift without haste\nStars peer through the dusty veil\nSomeone is still here",
            "Desert wind carries\nNothing but the warmth of time\nThe outpost still glows",
        ],
        .nonsenseLullabies: [
            "Paint runs down the page\nA cat sleeps beside the moon\nColours dream of spring",
            "Watercolour stars\nDrip softly onto warm paper\nThe story begins",
            "Little house floats by\nA bird sings in washed-out blue\nNonsense holds us close",
        ],
        .gouraudSolarSystem: [
            "Seven worlds orbit\nSmooth light slides across their faces\nThe star hums below",
            "A new moon is born\nGradient and highlight spinning\nPolygons at peace",
            "Rings catch the slow light\nScanlines trace through empty space\nThe GPU dreams on",
        ],
        .medievalVillage3D: [
            "Low-poly hamlet\nWarm light leaks from tiny homes\nThe owl circles slow",
            "Fog between the roofs\nFirefly dots in three-space drift\nEvery face is flat",
            "The church stands tallest\nAnd its shadow maps the ground\nVertices at rest",
        ],
        .lateNightRerun3D: [
            "The TV casts blue\nAcross the modelled bedroom\nSleep in polygon",
            "Green stars on ceiling\nLava lamp pulses in three\nDimensions of home",
            "Lying here in mesh\nThe channel changes colour\nDepth of memory",
        ],
        .jeonjuNight3D: [
            "Sodium light pools\nOn the three-dimensional road\nMoth wings catch the glow",
            "Cat's green eyes in space\nHanok roofs in polygon\nWarm windows float near",
            "Wire sags in vertices\nBetween the modelled houses\nNight hums in three-D",
        ],
        .oldCar: [
            "Wipers sweep the snow\nAmber dash light hums along\nThe road disappears",
            "Chrome knobs catch the glow\nA heater fights the blizzard\nWarm hands on the wheel",
            "Poles drift past like ghosts\nThe bench seat holds steady warmth\nSnow erases all",
        ],
        .oldCar3D: [
            "Snow rushes the glass\nThe engine hums beneath me\nBarns fade into white",
            "Depth of winter night\nDash light paints the falling snow\nThe road carries us",
            "Wipers mark the time\nReflections glow on the glass\nWarm inside the storm",
        ],
        .cosmicDrift3D: [
            "Nebulae have depth\nI drift between their soft walls\nWarmth in every cloud",
            "Stars recede like thoughts\nDust lanes curve in three dimensions\nSilence has a shape",
            "Through the cosmic fog\nLight finds paths around the dark\nSpace cradles the glow",
        ],
        .voyagerNebula3D: [
            "Gas pillars tower\nNewborn stars glow deep within\nThe nursery hums",
            "Teal and rose have depth\nI pass between the curtains\nStellar warmth surrounds",
            "Space has surfaces\nSmooth clouds sculpted by old light\nThe nebula breathes",
        ],
        .desertStarscape3D: [
            "Dunes recede in dark\nThe milky way has real depth\nSand still holds the warmth",
            "One footprint in three\nDimensions of quiet sand\nStars lean overhead",
            "Warm wind finds the gap\nBetween each sculpted sand ridge\nNight stretches in depth",
        ],
        .deepOcean3D: [
            "Jellyfish descend\nThrough layers of darker blue\nLight pulses in depth",
            "The pressure is peace\nParticles drift all around\nThe deep has a floor",
            "Bioluminescence\nGives the ocean inner walls\nSoft glow everywhere",
        ],
        .ancientRuins3D: [
            "Columns stand in space\nAurora light on real stone\nFireflies have depth",
            "Between the arches\nGreen light finds its way to ground\nRuins breathe in three",
            "Carved stone recedes back\nEach surface holds a shadow\nTime is spatial here",
        ],
        .lushRuins3D: [
            "Waterfalls have depth\nCascading past carved stone walls\nMoss on every face",
            "God rays pierce the leaves\nThe jungle temple towers\nButterflies orbit",
            "Stone and vine embrace\nIn three dimensions of growth\nThe ruin still stands",
        ],
        .auroraBorealis3D: [
            "Curtains made of light\nHang in layers through the sky\nThe lake reflects depth",
            "Pine silhouettes stand\nBetween me and the green glow\nSnow has surfaces",
            "The cabin glows warm\nBeneath translucent heaven\nAurora in three",
        ],
        .saltLamp3D: [
            "Crystal has a depth\nLight scatters through amber walls\nThe room breathes in warm",
            "Salt remembers seas\nRendered now with inner glow\nEvery facet shines",
            "Volume of warm light\nA lamp that fills the whole space\nGentle as a pulse",
        ],
        .conservatory3D: [
            "Rain refracts through glass\nEach pane a lens on the green\nSteam curls into depth",
            "Ferns recede in rows\nThe greenhouse has real distance\nWarm mist fills the space",
            "Droplets on the panes\nBend the light in three dimensions\nPlants breathe all around",
        ],
        .quietMeal3D: [
            "Through the rain-streaked glass\nTwo friends have dimension now\nWarmth is spatial here",
            "Depth between the drops\nAnd the warm scene just beyond\nThe meal glows inside",
            "Blue dusk wraps the street\nGolden light fills the window\nClose enough to touch",
        ],
        .artDecoLA3D: [
            "Deco towers cast\nLong shadows down the boulevard\nPalm trees frame the depth",
            "The streetcar has weight\nSearchlights sweep through real volume\nGolden hour in three",
            "Streamline walls recede\nWarm neon glows in the space\nLos Angeles dreams",
        ],
        .urbanDreamscape3D: [
            "Cities blend in depth\nTokyo and Paris merge\nNeon fills the space",
            "The train passes through\nModelled streets of many lands\nPuddles hold the sky",
            "Low-poly dream town\nReflections have dimension\nRain falls everywhere",
        ],
        .shimizuEvening3D: [
            "Concrete walls have depth\nRain pools on the modelled road\nWarm light from within",
            "Wires recede to night\nEach puddle a mirror world\nThe street breathes in rain",
            "Tiled roofs catch the drops\nYellow windows glow in three\nDimensions of home",
        ],
        .nightTrain3D: [
            "The locomotive\nPulls through three dimensions dark\nWindows warm the night",
            "Telegraph poles pass\nWith real depth between each one\nMoonlight on the fields",
            "Countryside has depth\nThe gentle rocking of rails\nWarm light carries us",
        ],
        .ontarioCountryside3D: [
            "Wheat fields have real depth\nThe barn glows in amber dusk\nFireflies in space",
            "Gravel road recedes\nPower lines trace the distance\nAugust in three-D",
            "The treeline is far\nFireflies close and flickering\nSpace between them warm",
        ],
        .minnesotaSmallTown3D: [
            "The steeple has height\nMain Street stretches into dusk\nNeon hums with depth",
            "Water tower stands\nAbove the modelled prairie\nFlat land in three-D",
            "Grain elevator\nCasts a shadow on the street\nFireflies have space",
        ],
        .midnightMotel3D: [
            "Neon has volume\nPink light fills the modelled room\nDust motes drift in space",
            "Wood panels recede\nThe lamp casts a real shadow\nHeadlights sweep the depth",
            "A room in three-D\nSomewhere between two far towns\nThe phone waits in light",
        ],
        .forgottenLibrary3D: [
            "Bookshelves tower up\nReceding into the dark\nCandles light the depth",
            "Golden letters drift\nUpward through the modelled air\nMoonlight finds the page",
            "The library breathes\nIn three dimensions of hush\nKnowledge has a space",
        ],
        .enchantedArchives3D: [
            "Paper birds have depth\nSoaring between modelled shelves\nLightning arcs in space",
            "Books fly open wide\nTrajectories through the room\nStained glass fills the air",
            "Magic in three-D\nGlyphs orbit like tiny worlds\nThe archive glows bright",
        ],
        .celestialScrollHall3D: [
            "Moonlight pools on wood\nThe desk has depth and shadow\nInk stones wait in space",
            "Characters glow soft\nLanterns in three dimensions\nThe brush rests in light",
            "Scrolls unfurl with depth\nCalligraphy fills the hall\nWisdom has a room",
        ],
        .floatingKingdom3D: [
            "Crystal spires rise\nWith real height above the clouds\nLight catches each face",
            "Waterfalls descend\nFrom islands floating in space\nMist below has depth",
            "The kingdom has weight\nDespite floating in the sky\nDreams in three-D glow",
        ],
        .paperLanternFestival3D: [
            "Lanterns rise with depth\nEach one a warm sphere of light\nThe lake reflects all",
            "Fireflies and flames\nDrift through three dimensions dark\nThe water holds still",
            "One tap sends one wish\nRising through the modelled dusk\nThe sky leans in close",
        ],
        .captainStar3D: [
            "Ochre terrain spreads\nWith real depth to the horizon\nRocks float in the space",
            "The outpost has glass\nCatching starlight from three sides\nDust drifts through the room",
            "Desert planet breathes\nIn three dimensions of warm\nThe edge holds its ground",
        ],
        .gouraudSolarSystem3D: [
            "Planets orbit near\nSmooth highlights on every sphere\nThe star warms the space",
            "Rings have real thickness\nMoons trace paths through modelled void\nGouraud light on all",
            "The solar system\nRendered twice in depth and love\nPolygons at peace",
        ],
        .retroGarden3D: [
            "Voxel flowers bloom\nWith blocky depth and warm light\nButterflies in space",
            "Pixel art has depth\nEach square a tiny world now\nShadows crisp and short",
            "The garden extends\nIn three dimensions of green\nSimple joy has room",
        ],
        .celShadedRainyDay3D: [
            "Toon rain has real depth\nFat drops fall as little spheres\nPuddles form below",
            "Cartoon flowers stand\nWith cel-shaded dimension\nThe garden drinks deep",
            "Every bright petal\nCatches a toon-shaded drop\nRain fills the whole space",
        ],
        .retroPS13D: [
            "Low-poly cabin\nWith vertex jitter and warmth\nFireflies are spheres",
            "Mountains in the back\nChunky and triangulated\nThe old world has depth",
            "Pixel stars above\nThe PS1 night rendered twice\nNostalgia in three",
        ],
        .greetingTheDay3D: [
            "Buildings catch the dawn\nWith real height and morning shadow\nThe city wakes up",
            "Sun rays between walls\nWindows glow in three dimensions\nA new day has depth",
            "The sunrise has weight\nLight spilling between the towers\nReady for the world",
        ],
        .mystify3D: [
            "Lines bounce through real space\nPhosphor trails fade into depth\nThe screen dreams in three",
            "Geometry floats\nBouncing off invisible walls\nNinety-five has depth",
            "Coloured lines in space\nEach bounce a new dimension\nWarm geometry",
        ],
        .nonsenseLullabies3D: [
            "Pop-up book has depth\nPaper moons and stars stand up\nPaint drips down the page",
            "Little houses fold\nOut from painted paper worlds\nNonsense in three-D",
            "Watercolour cats\nHave dimension now they sleep\nBeside paper moons",
        ],
        .innerLight3D: [
            "Shapes glow in the dark\nConnections pulse without sound\nThinking feels like warmth",
            "Golden filaments\nLink each thought to the next one\nQuiet patterns hum",
            "In deep indigo\nFaceted forms drift and turn\nLight understands light",
        ],
        .wireframeCity3D: [
            "Green lines trace the dark\nA city made of nothing\nBut math and phosphor",
            "Vector buildings glow\nThe grid scrolls beneath my feet\nNineteen eighty-one",
            "Wireframe skyline hums\nEach edge a single photon\nThe future was green",
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
