import SwiftUI

// MARK: - Scene Descriptor

/// Co-located metadata for a single scene.  Adding a new scene means adding
/// one entry to ``SceneKind/descriptors`` instead of touching 7+ switch statements.
struct SceneDescriptor {
    let displayName: String
    let accessibilityDescription: String
    let tapHint: String
    let icon: String
    let tint: Color
    let audioMood: String
    let hasSceneKitVersion: Bool

    init(
        displayName: String,
        accessibilityDescription: String,
        tapHint: String,
        icon: String,
        tint: Color,
        audioMood: String,
        hasSceneKitVersion: Bool = false
    ) {
        self.displayName = displayName
        self.accessibilityDescription = accessibilityDescription
        self.tapHint = tapHint
        self.icon = icon
        self.tint = tint
        self.audioMood = audioMood
        self.hasSceneKitVersion = hasSceneKitVersion
    }
}

// MARK: - Scene Kind

enum SceneKind: String, CaseIterable, Identifiable {
    case cosmicDrift = "cosmicDrift"
    case retroGarden = "retroGarden"
    case deepOcean = "deepOcean"
    case desertStarscape = "desertStarscape"
    case ancientRuins = "ancientRuins"
    case saltLamp = "saltLamp"
    case conservatory = "conservatory"
    case nightTrain = "nightTrain"
    case greetingTheDay = "greetingTheDay"
    case celShadedRainyDay = "celShadedRainyDay"
    case voyagerNebula = "voyagerNebula"
    case retroPS1 = "retroPS1"
    case auroraBorealis = "auroraBorealis"
    case paperLanternFestival = "paperLanternFestival"
    case forgottenLibrary = "forgottenLibrary"
    case lateNightRerun = "lateNightRerun"
    case medievalVillage = "medievalVillage"
    case urbanDreamscape = "urbanDreamscape"
    case lushRuins = "lushRuins"
    case enchantedArchives = "enchantedArchives"
    case celestialScrollHall = "celestialScrollHall"
    case jeonjuNight = "jeonjuNight"
    case quietMeal = "quietMeal"
    case artDecoLA = "artDecoLA"
    case floatingKingdom = "floatingKingdom"
    case ontarioCountryside = "ontarioCountryside"
    case minnesotaSmallTown = "minnesotaSmallTown"
    case shimizuEvening = "shimizuEvening"
    case mystify = "mystify"
    case midnightMotel = "midnightMotel"
    case captainStar = "captainStar"
    case nonsenseLullabies = "nonsenseLullabies"
    case gouraudSolarSystem = "gouraudSolarSystem"
    case potterGarden = "potterGarden"
    case oldCar = "oldCar"
    case oldCar3D = "oldCar3D"
    case medievalVillage3D = "medievalVillage3D"
    case lateNightRerun3D = "lateNightRerun3D"
    case jeonjuNight3D = "jeonjuNight3D"
    case cosmicDrift3D = "cosmicDrift3D"
    case voyagerNebula3D = "voyagerNebula3D"
    case desertStarscape3D = "desertStarscape3D"
    case deepOcean3D = "deepOcean3D"
    case ancientRuins3D = "ancientRuins3D"
    case lushRuins3D = "lushRuins3D"
    case auroraBorealis3D = "auroraBorealis3D"
    case saltLamp3D = "saltLamp3D"
    case conservatory3D = "conservatory3D"
    case quietMeal3D = "quietMeal3D"
    case artDecoLA3D = "artDecoLA3D"
    case urbanDreamscape3D = "urbanDreamscape3D"
    case shimizuEvening3D = "shimizuEvening3D"
    case nightTrain3D = "nightTrain3D"
    case ontarioCountryside3D = "ontarioCountryside3D"
    case minnesotaSmallTown3D = "minnesotaSmallTown3D"
    case midnightMotel3D = "midnightMotel3D"
    case forgottenLibrary3D = "forgottenLibrary3D"
    case enchantedArchives3D = "enchantedArchives3D"
    case celestialScrollHall3D = "celestialScrollHall3D"
    case floatingKingdom3D = "floatingKingdom3D"
    case paperLanternFestival3D = "paperLanternFestival3D"
    case captainStar3D = "captainStar3D"
    case gouraudSolarSystem3D = "gouraudSolarSystem3D"
    case retroGarden3D = "retroGarden3D"
    case celShadedRainyDay3D = "celShadedRainyDay3D"
    case retroPS13D = "retroPS13D"
    case greetingTheDay3D = "greetingTheDay3D"
    case mystify3D = "mystify3D"
    case nonsenseLullabies3D = "nonsenseLullabies3D"
    case potterGarden3D = "potterGarden3D"
    case innerLight3D = "innerLight3D"
    case wireframeCity3D = "wireframeCity3D"
    case rotatingAerial3D = "rotatingAerial3D"
    case lastAndFirstMen3D = "lastAndFirstMen3D"
    case murmuration = "murmuration"
    case murmuration3D = "murmuration3D"
    case silicaBench3D = "silicaBench3D"

    var id: String { rawValue }

    // MARK: - Descriptor Registry

    /// Single source of truth for all scene metadata.
    private static let descriptors: [SceneKind: SceneDescriptor] = [
        .cosmicDrift: SceneDescriptor(
            displayName: "Cosmic Drift",
            accessibilityDescription: "Gentle nebulae and twinkling stars drifting through warm cosmic space",
            tapHint: "Tap to send a ripple through the stars",
            icon: "sparkles",
            tint: Color(red: 0.5, green: 0.3, blue: 0.9),
            audioMood: "cosmic"
        ),
        .retroGarden: SceneDescriptor(
            displayName: "Retro Garden",
            accessibilityDescription: "A peaceful pixel-art garden with flowers, butterflies, and soft sunlight",
            tapHint: "Tap to plant a flower",
            icon: "leaf",
            tint: Color(red: 0.3, green: 0.7, blue: 0.3),
            audioMood: "dreamy"
        ),
        .deepOcean: SceneDescriptor(
            displayName: "Deep Ocean",
            accessibilityDescription: "Bioluminescent creatures glowing softly in the deep ocean",
            tapHint: "Tap to attract bioluminescent creatures",
            icon: "water.waves",
            tint: Color(red: 0.1, green: 0.4, blue: 0.8),
            audioMood: "cool"
        ),
        .desertStarscape: SceneDescriptor(
            displayName: "Desert Starscape",
            accessibilityDescription: "Warm desert dunes beneath a vast starry sky",
            tapHint: "Tap to send a ripple across the dunes",
            icon: "moon.stars",
            tint: Color(red: 0.8, green: 0.6, blue: 0.2),
            audioMood: "cosmic"
        ),
        .ancientRuins: SceneDescriptor(
            displayName: "Ancient Ruins",
            accessibilityDescription: "Ancient stone ruins bathed in soft aurora light with fireflies",
            tapHint: "Tap to release fireflies",
            icon: "building.columns",
            tint: Color(red: 0.3, green: 0.7, blue: 0.5),
            audioMood: "earthy"
        ),
        .saltLamp: SceneDescriptor(
            displayName: "Salt Lamp",
            accessibilityDescription: "The warm amber glow of a Himalayan salt lamp breathing gently",
            tapHint: "Tap to brighten the glow",
            icon: "flame",
            tint: Color(red: 0.95, green: 0.55, blue: 0.2),
            audioMood: "warm"
        ),
        .conservatory: SceneDescriptor(
            displayName: "Conservatory",
            accessibilityDescription: "Rain on greenhouse windows with plants swaying and steam rising",
            tapHint: "Tap to make it rain harder",
            icon: "humidity",
            tint: Color(red: 0.4, green: 0.65, blue: 0.45),
            audioMood: "warm"
        ),
        .nightTrain: SceneDescriptor(
            displayName: "Night Train",
            accessibilityDescription: "A gentle night train journey through moonlit countryside",
            tapHint: "Tap to light a window",
            icon: "train.side.front.car",
            tint: Color(red: 0.3, green: 0.25, blue: 0.5),
            audioMood: "dreamy"
        ),
        .greetingTheDay: SceneDescriptor(
            displayName: "Greeting the Day",
            accessibilityDescription: "A city waking up at sunrise with buildings growing toward the light",
            tapHint: "Tap to grow a new building",
            icon: "sunrise",
            tint: Color(red: 0.9, green: 0.65, blue: 0.3),
            audioMood: "dreamy"
        ),
        .celShadedRainyDay: SceneDescriptor(
            displayName: "Rainy Day",
            accessibilityDescription: "Bright flowers thriving in gentle rain, puddles forming in a cartoon world",
            tapHint: "Tap for a splash",
            icon: "cloud.rain",
            tint: Color(red: 0.4, green: 0.5, blue: 0.35),
            audioMood: "cool"
        ),
        .voyagerNebula: SceneDescriptor(
            displayName: "Voyager Nebula",
            accessibilityDescription: "Drifting through a magnificent nebula, swirling teal and magenta",
            tapHint: "Tap to pulse the nebula",
            icon: "sparkle.magnifyingglass",
            tint: Color(red: 0.3, green: 0.55, blue: 0.75),
            audioMood: "cosmic"
        ),
        .retroPS1: SceneDescriptor(
            displayName: "Retro PS1",
            accessibilityDescription: "A nostalgic low-poly nighttime scene with a glowing cabin and fireflies",
            tapHint: "Tap to scatter fireflies",
            icon: "gamecontroller",
            tint: Color(red: 0.25, green: 0.2, blue: 0.4),
            audioMood: "dreamy"
        ),
        .auroraBorealis: SceneDescriptor(
            displayName: "Aurora Borealis",
            accessibilityDescription: "Northern lights dancing in green and violet over a frozen lake with pine trees",
            tapHint: "Tap to send a solar flare through the aurora",
            icon: "wind.snow",
            tint: Color(red: 0.15, green: 0.7, blue: 0.45),
            audioMood: "mystical"
        ),
        .paperLanternFestival: SceneDescriptor(
            displayName: "Paper Lantern Festival",
            accessibilityDescription: "A serene lake at dusk where each click releases a glowing lantern carrying a kind message into the night",
            tapHint: "Tap to release a lantern with a gentle message",
            icon: "lamp.desk",
            tint: Color(red: 0.9, green: 0.6, blue: 0.15),
            audioMood: "dreamy"
        ),
        .forgottenLibrary: SceneDescriptor(
            displayName: "Forgotten Library",
            accessibilityDescription: "An infinite twilight library with towering bookshelves and floating golden letters",
            tapHint: "Tap to open a book and release glowing letters",
            icon: "books.vertical",
            tint: Color(red: 0.55, green: 0.4, blue: 0.25),
            audioMood: "mystical"
        ),
        .lateNightRerun: SceneDescriptor(
            displayName: "Late Night Rerun",
            accessibilityDescription: "Falling asleep to late-night TV reruns in a cosy nineties bedroom",
            tapHint: "Tap to change the channel",
            icon: "tv",
            tint: Color(red: 0.3, green: 0.25, blue: 0.55),
            audioMood: "warm"
        ),
        .medievalVillage: SceneDescriptor(
            displayName: "Medieval Village",
            accessibilityDescription: "A peaceful medieval village settling down for the night under moonlight",
            tapHint: "Tap to snuff a candle",
            icon: "house.lodge",
            tint: Color(red: 0.7, green: 0.5, blue: 0.25),
            audioMood: "earthy"
        ),
        .urbanDreamscape: SceneDescriptor(
            displayName: "Urban Dreamscape",
            accessibilityDescription: "A dreamy cel-shaded city blending world capitals at night",
            tapHint: "Tap to send a ripple through the puddles",
            icon: "building.2",
            tint: Color(red: 0.6, green: 0.3, blue: 0.8),
            audioMood: "mystical"
        ),
        .lushRuins: SceneDescriptor(
            displayName: "Lush Ruins",
            accessibilityDescription: "Ancient moss-covered temple ruins in a lush tropical jungle with waterfalls",
            tapHint: "Tap to release butterflies",
            icon: "leaf.arrow.triangle.circlepath",
            tint: Color(red: 0.2, green: 0.65, blue: 0.35),
            audioMood: "earthy"
        ),
        .enchantedArchives: SceneDescriptor(
            displayName: "Enchanted Archives",
            accessibilityDescription: "A wild magical library where books fly open and paper birds soar",
            tapHint: "Tap to scatter paper birds",
            icon: "book.and.wrench",
            tint: Color(red: 0.45, green: 0.3, blue: 0.6),
            audioMood: "mystical"
        ),
        .celestialScrollHall: SceneDescriptor(
            displayName: "Celestial Scroll Hall",
            accessibilityDescription: "A moonlit Chinese study hall with calligraphy scrolls and glowing characters",
            tapHint: "Tap to release glowing characters from a scroll",
            icon: "scroll",
            tint: Color(red: 0.75, green: 0.55, blue: 0.3),
            audioMood: "mystical"
        ),
        .jeonjuNight: SceneDescriptor(
            displayName: "Jeonju Night",
            accessibilityDescription: "A quiet Korean neighbourhood at night in the nineteen-nineties",
            tapHint: "Tap to toggle a window light",
            icon: "moon",
            tint: Color(red: 0.35, green: 0.25, blue: 0.5),
            audioMood: "cool"
        ),
        .quietMeal: SceneDescriptor(
            displayName: "Quiet Meal",
            accessibilityDescription: "Two friends sharing a quiet meal, seen through the window on a rainy evening",
            tapHint: "Tap to send a raindrop down the glass",
            icon: "cup.and.saucer",
            tint: Color(red: 0.7, green: 0.6, blue: 0.45),
            audioMood: "warm"
        ),
        .artDecoLA: SceneDescriptor(
            displayName: "Art Deco LA",
            accessibilityDescription: "An art deco Los Angeles boulevard at golden hour with palm trees, streamline moderne buildings, and a vintage red streetcar",
            tapHint: "Tap to sweep a searchlight across the sky",
            icon: "building.columns.fill",
            tint: Color(red: 0.9, green: 0.7, blue: 0.35),
            audioMood: "warm"
        ),
        .floatingKingdom: SceneDescriptor(
            displayName: "Floating Kingdom",
            accessibilityDescription: "A sky kingdom floating above an ocean of clouds, with crystalline spires, waterfalls cascading into mist, and motes of ancient magical energy drifting upward",
            tapHint: "Tap to send a pulse of magical energy rippling outward",
            icon: "cloud.sun",
            tint: Color(red: 0.4, green: 0.3, blue: 0.7),
            audioMood: "dreamy"
        ),
        .ontarioCountryside: SceneDescriptor(
            displayName: "Ontario Countryside",
            accessibilityDescription: "A warm summer evening settling over the rural countryside of southern Ontario in the early nineteen-nineties, with golden wheat fields, an old red barn, a gravel road, and fireflies beginning to blink in the blue hour",
            tapHint: "Tap to send a gust of wind rippling through the wheat",
            icon: "sun.horizon",
            tint: Color(red: 0.75, green: 0.55, blue: 0.20),
            audioMood: "earthy"
        ),
        .minnesotaSmallTown: SceneDescriptor(
            displayName: "Minnesota Small Town",
            accessibilityDescription: "A calm summer evening in a tiny Minnesota prairie town, with a steeple, a water tower, a grain elevator, a diner with a flickering neon sign, and fireflies drifting over Main Street",
            tapHint: "Tap to send a firefly drifting across the scene",
            icon: "house",
            tint: Color(red: 0.85, green: 0.55, blue: 0.30),
            audioMood: "earthy"
        ),
        .shimizuEvening: SceneDescriptor(
            displayName: "Shimizu Evening",
            accessibilityDescription: "A quiet Japanese residential neighbourhood on a rainy evening, with a peaked wooden house, a concrete block wall, a corner shop with a striped awning, utility poles, and warm yellow windows glowing through the rain",
            tapHint: "Tap to send a splash rippling through a puddle",
            icon: "cloud.rain.fill",
            tint: Color(red: 0.30, green: 0.38, blue: 0.58),
            audioMood: "cool"
        ),
        .mystify: SceneDescriptor(
            displayName: "Mystify",
            accessibilityDescription: "Glowing lines bouncing across a dark screen, leaving phosphor trails like a Windows 95 screensaver dreaming",
            tapHint: "Tap to launch an extra ribbon of light",
            icon: "display",
            tint: Color(red: 0.20, green: 0.85, blue: 0.90),
            audioMood: "dreamy"
        ),
        .midnightMotel: SceneDescriptor(
            displayName: "Midnight Motel",
            accessibilityDescription: "A quiet motel room in 1968 America, neon vacancy sign bleeding through thin curtains, wood paneling, a warm lamp, and headlights sweeping across the ceiling",
            tapHint: "Tap to send headlights sweeping across the ceiling",
            icon: "bed.double",
            tint: Color(red: 0.85, green: 0.30, blue: 0.35),
            audioMood: "warm"
        ),
        .captainStar: SceneDescriptor(
            displayName: "Captain Star",
            accessibilityDescription: "A barren desert planet at the edge of the universe, ochre skies, floating rocks, a lone glass outpost, stars visible through the dust, cosmic desolation made beautiful",
            tapHint: "Tap to send a luminous pulse across the desert",
            icon: "globe.americas",
            tint: Color(red: 0.72, green: 0.52, blue: 0.22),
            audioMood: "cosmic"
        ),
        .nonsenseLullabies: SceneDescriptor(
            displayName: "Nonsense & Lullabies",
            accessibilityDescription: "Hand-painted watercolour nursery shapes drifting on warm paper, cats, moons, little houses, gentle paint drips running down",
            tapHint: "Tap to bloom a watercolour splash",
            icon: "paintbrush.pointed",
            tint: Color(red: 0.75, green: 0.55, blue: 0.70),
            audioMood: "dreamy"
        ),
        .gouraudSolarSystem: SceneDescriptor(
            displayName: "Solar System",
            accessibilityDescription: "A retro-rendered imaginary solar system with Gouraud-shaded planets orbiting a warm star, specular highlights, ring systems, and moons drifting in elliptical orbits",
            tapHint: "Tap to shimmer a planet or add a new moon",
            icon: "globe.europe.africa",
            tint: Color(red: 0.35, green: 0.25, blue: 0.65),
            audioMood: "cosmic"
        ),
        .potterGarden: SceneDescriptor(
            displayName: "Potter Garden",
            accessibilityDescription: "A watercolour English cottage garden in the style of Beatrix Potter, rows of lush green cabbages on brown earth paths, a stone wall with a wooden gate, a distant cottage, butterflies drifting in warm afternoon light",
            tapHint: "Tap to release a butterfly",
            icon: "leaf.fill",
            tint: Color(red: 0.40, green: 0.58, blue: 0.35),
            audioMood: "dreamy"
        ),
        .oldCar: SceneDescriptor(
            displayName: "Old Car",
            accessibilityDescription: "Driving a vintage car through a snowstorm at night, dash lights glowing amber, wipers sweeping, radio tuned to static warmth",
            tapHint: "Tap to honk and flash the dash lights",
            icon: "car",
            tint: Color(red: 0.45, green: 0.35, blue: 0.25),
            audioMood: "warm"
        ),
        .oldCar3D: SceneDescriptor(
            displayName: "Old Car 3D",
            accessibilityDescription: "First-person three-dimensional view from inside a nineteen-fifties land yacht, snow rushing at the windshield, utility poles scrolling past, amber dash instruments glowing",
            tapHint: "Tap to honk and flash the dash lights",
            icon: "car.fill",
            tint: Color(red: 0.40, green: 0.30, blue: 0.20),
            audioMood: "warm"
        ),
        .medievalVillage3D: SceneDescriptor(
            displayName: "Medieval Village 3D",
            accessibilityDescription: "A low-poly three-dimensional medieval village diorama viewed from above, with warm window lights, moonlit roofs, firefly particles, and a slowly orbiting camera",
            tapHint: "Tap to snuff a window light",
            icon: "house.lodge.fill",
            tint: Color(red: 0.60, green: 0.45, blue: 0.25),
            audioMood: "earthy"
        ),
        .lateNightRerun3D: SceneDescriptor(
            displayName: "Late Night Rerun 3D",
            accessibilityDescription: "A three-dimensional nineties bedroom seen from bed, CRT television casting colored light across the walls, glow-in-the-dark ceiling stars, a pulsing lava lamp",
            tapHint: "Tap to change the channel",
            icon: "tv.fill",
            tint: Color(red: 0.25, green: 0.20, blue: 0.50),
            audioMood: "warm"
        ),
        .jeonjuNight3D: SceneDescriptor(
            displayName: "Jeonju Night 3D",
            accessibilityDescription: "A three-dimensional quiet Korean neighbourhood at night, hanok houses with warm windows, a sodium-lit street lamp casting orange light, moths, a cat on a wall, telephone wires against the night sky",
            tapHint: "Tap to toggle a window light",
            icon: "moon.fill",
            tint: Color(red: 0.85, green: 0.60, blue: 0.22),
            audioMood: "cool"
        ),
        .cosmicDrift3D: SceneDescriptor(
            displayName: "Cosmic Drift 3D",
            accessibilityDescription: "A three-dimensional nebula with stars drifting through warm cosmic space",
            tapHint: "Tap to send a ripple through the stars",
            icon: "sparkles",
            tint: Color(red: 0.5, green: 0.3, blue: 0.9),
            audioMood: "cosmic"
        ),
        .voyagerNebula3D: SceneDescriptor(
            displayName: "Voyager Nebula 3D",
            accessibilityDescription: "Drifting through a three-dimensional nebula with stellar nurseries",
            tapHint: "Tap to pulse the nebula",
            icon: "sparkle.magnifyingglass",
            tint: Color(red: 0.3, green: 0.55, blue: 0.75),
            audioMood: "cosmic"
        ),
        .desertStarscape3D: SceneDescriptor(
            displayName: "Desert Starscape 3D",
            accessibilityDescription: "Three-dimensional dunes beneath a vast starry sky",
            tapHint: "Tap to send a ripple across the dunes",
            icon: "moon.stars.fill",
            tint: Color(red: 0.8, green: 0.6, blue: 0.2),
            audioMood: "cosmic"
        ),
        .deepOcean3D: SceneDescriptor(
            displayName: "Deep Ocean 3D",
            accessibilityDescription: "Three-dimensional bioluminescent deep ocean creatures",
            tapHint: "Tap to attract bioluminescent creatures",
            icon: "water.waves",
            tint: Color(red: 0.1, green: 0.4, blue: 0.8),
            audioMood: "cool"
        ),
        .ancientRuins3D: SceneDescriptor(
            displayName: "Ancient Ruins 3D",
            accessibilityDescription: "Three-dimensional ancient stone ruins bathed in aurora light",
            tapHint: "Tap to release fireflies",
            icon: "building.columns.fill",
            tint: Color(red: 0.3, green: 0.7, blue: 0.5),
            audioMood: "earthy"
        ),
        .lushRuins3D: SceneDescriptor(
            displayName: "Lush Ruins 3D",
            accessibilityDescription: "Three-dimensional moss-covered temple ruins in a tropical jungle",
            tapHint: "Tap to release butterflies",
            icon: "leaf.arrow.triangle.circlepath",
            tint: Color(red: 0.2, green: 0.65, blue: 0.35),
            audioMood: "earthy"
        ),
        .auroraBorealis3D: SceneDescriptor(
            displayName: "Aurora Borealis 3D",
            accessibilityDescription: "Three-dimensional northern lights dancing over a frozen lake",
            tapHint: "Tap to send a solar flare through the aurora",
            icon: "wind.snow",
            tint: Color(red: 0.15, green: 0.7, blue: 0.45),
            audioMood: "mystical"
        ),
        .saltLamp3D: SceneDescriptor(
            displayName: "Salt Lamp 3D",
            accessibilityDescription: "A three-dimensional Himalayan salt lamp breathing warmly",
            tapHint: "Tap to brighten the glow",
            icon: "flame.fill",
            tint: Color(red: 0.95, green: 0.55, blue: 0.2),
            audioMood: "warm"
        ),
        .conservatory3D: SceneDescriptor(
            displayName: "Conservatory 3D",
            accessibilityDescription: "Three-dimensional greenhouse with rain on glass and plants",
            tapHint: "Tap to make it rain harder",
            icon: "humidity.fill",
            tint: Color(red: 0.4, green: 0.65, blue: 0.45),
            audioMood: "warm"
        ),
        .quietMeal3D: SceneDescriptor(
            displayName: "Quiet Meal 3D",
            accessibilityDescription: "Three-dimensional view of two friends sharing a meal through a rainy window",
            tapHint: "Tap to send a raindrop down the glass",
            icon: "cup.and.saucer.fill",
            tint: Color(red: 0.7, green: 0.6, blue: 0.45),
            audioMood: "warm",
            hasSceneKitVersion: true
        ),
        .artDecoLA3D: SceneDescriptor(
            displayName: "Art Deco LA 3D",
            accessibilityDescription: "Three-dimensional art deco Los Angeles boulevard at golden hour",
            tapHint: "Tap to sweep a searchlight across the sky",
            icon: "building.columns.fill",
            tint: Color(red: 0.9, green: 0.7, blue: 0.35),
            audioMood: "warm",
            hasSceneKitVersion: true
        ),
        .urbanDreamscape3D: SceneDescriptor(
            displayName: "Urban Dreamscape 3D",
            accessibilityDescription: "A three-dimensional dreamy cel-shaded city at night",
            tapHint: "Tap to send a ripple through the puddles",
            icon: "building.2.fill",
            tint: Color(red: 0.6, green: 0.3, blue: 0.8),
            audioMood: "mystical"
        ),
        .shimizuEvening3D: SceneDescriptor(
            displayName: "Shimizu Evening 3D",
            accessibilityDescription: "Three-dimensional Japanese neighbourhood on a rainy evening",
            tapHint: "Tap to send a splash rippling through a puddle",
            icon: "cloud.rain.fill",
            tint: Color(red: 0.30, green: 0.38, blue: 0.58),
            audioMood: "cool"
        ),
        .nightTrain3D: SceneDescriptor(
            displayName: "Night Train 3D",
            accessibilityDescription: "Three-dimensional night train journey through moonlit countryside",
            tapHint: "Tap to light a window",
            icon: "train.side.front.car",
            tint: Color(red: 0.3, green: 0.25, blue: 0.5),
            audioMood: "dreamy"
        ),
        .ontarioCountryside3D: SceneDescriptor(
            displayName: "Ontario Countryside 3D",
            accessibilityDescription: "Three-dimensional Ontario countryside at dusk in the nineties",
            tapHint: "Tap to send a gust of wind through the wheat",
            icon: "sun.horizon.fill",
            tint: Color(red: 0.75, green: 0.55, blue: 0.20),
            audioMood: "earthy"
        ),
        .minnesotaSmallTown3D: SceneDescriptor(
            displayName: "Minnesota Small Town 3D",
            accessibilityDescription: "Three-dimensional Minnesota prairie town on a summer evening",
            tapHint: "Tap to send a firefly drifting",
            icon: "house.fill",
            tint: Color(red: 0.85, green: 0.55, blue: 0.30),
            audioMood: "earthy"
        ),
        .midnightMotel3D: SceneDescriptor(
            displayName: "Midnight Motel 3D",
            accessibilityDescription: "Three-dimensional motel room in 1968 with neon bleeding through curtains",
            tapHint: "Tap to send headlights sweeping across the ceiling",
            icon: "bed.double.fill",
            tint: Color(red: 0.85, green: 0.30, blue: 0.35),
            audioMood: "warm"
        ),
        .forgottenLibrary3D: SceneDescriptor(
            displayName: "Forgotten Library 3D",
            accessibilityDescription: "Three-dimensional infinite twilight library with floating letters",
            tapHint: "Tap to open a book and release glowing letters",
            icon: "books.vertical.fill",
            tint: Color(red: 0.55, green: 0.4, blue: 0.25),
            audioMood: "mystical",
            hasSceneKitVersion: true
        ),
        .enchantedArchives3D: SceneDescriptor(
            displayName: "Enchanted Archives 3D",
            accessibilityDescription: "Three-dimensional magical library with flying paper birds",
            tapHint: "Tap to scatter paper birds",
            icon: "book.and.wrench",
            tint: Color(red: 0.45, green: 0.3, blue: 0.6),
            audioMood: "mystical",
            hasSceneKitVersion: true
        ),
        .celestialScrollHall3D: SceneDescriptor(
            displayName: "Celestial Scroll Hall 3D",
            accessibilityDescription: "Three-dimensional moonlit Chinese study hall with calligraphy",
            tapHint: "Tap to release glowing characters",
            icon: "scroll.fill",
            tint: Color(red: 0.75, green: 0.55, blue: 0.3),
            audioMood: "mystical",
            hasSceneKitVersion: true
        ),
        .floatingKingdom3D: SceneDescriptor(
            displayName: "Floating Kingdom 3D",
            accessibilityDescription: "Three-dimensional sky kingdom floating above clouds",
            tapHint: "Tap to send a pulse of magical energy",
            icon: "cloud.sun.fill",
            tint: Color(red: 0.4, green: 0.3, blue: 0.7),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .paperLanternFestival3D: SceneDescriptor(
            displayName: "Paper Lantern Festival 3D",
            accessibilityDescription: "Three-dimensional lanterns rising over a dark lake at dusk",
            tapHint: "Tap to release a lantern",
            icon: "lamp.desk.fill",
            tint: Color(red: 0.9, green: 0.6, blue: 0.15),
            audioMood: "dreamy"
        ),
        .captainStar3D: SceneDescriptor(
            displayName: "Captain Star 3D",
            accessibilityDescription: "Three-dimensional barren desert planet at the edge of the universe",
            tapHint: "Tap to send a luminous pulse across the desert",
            icon: "globe.americas.fill",
            tint: Color(red: 0.72, green: 0.52, blue: 0.22),
            audioMood: "cosmic"
        ),
        .gouraudSolarSystem3D: SceneDescriptor(
            displayName: "Solar System 3D",
            accessibilityDescription: "Three-dimensional retro solar system with Gouraud-shaded planets",
            tapHint: "Tap to shimmer a planet",
            icon: "globe.europe.africa.fill",
            tint: Color(red: 0.35, green: 0.25, blue: 0.65),
            audioMood: "cosmic",
            hasSceneKitVersion: true
        ),
        .retroGarden3D: SceneDescriptor(
            displayName: "Retro Garden 3D",
            accessibilityDescription: "Three-dimensional pixel-art garden with butterflies",
            tapHint: "Tap to plant a flower",
            icon: "leaf.fill",
            tint: Color(red: 0.3, green: 0.7, blue: 0.3),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .celShadedRainyDay3D: SceneDescriptor(
            displayName: "Rainy Day 3D",
            accessibilityDescription: "Three-dimensional cartoon rain with flowers and puddles",
            tapHint: "Tap for a splash",
            icon: "cloud.rain",
            tint: Color(red: 0.4, green: 0.5, blue: 0.35),
            audioMood: "cool",
            hasSceneKitVersion: true
        ),
        .retroPS13D: SceneDescriptor(
            displayName: "Retro PS1 3D",
            accessibilityDescription: "Three-dimensional low-poly cabin with fireflies",
            tapHint: "Tap to scatter fireflies",
            icon: "gamecontroller.fill",
            tint: Color(red: 0.25, green: 0.2, blue: 0.4),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .greetingTheDay3D: SceneDescriptor(
            displayName: "Greeting the Day 3D",
            accessibilityDescription: "Three-dimensional city waking up at sunrise",
            tapHint: "Tap to grow a new building",
            icon: "sunrise.fill",
            tint: Color(red: 0.9, green: 0.65, blue: 0.3),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .mystify3D: SceneDescriptor(
            displayName: "Mystify 3D",
            accessibilityDescription: "Three-dimensional glowing lines bouncing with phosphor trails",
            tapHint: "Tap to launch an extra ribbon of light",
            icon: "display",
            tint: Color(red: 0.20, green: 0.85, blue: 0.90),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .nonsenseLullabies3D: SceneDescriptor(
            displayName: "Nonsense & Lullabies 3D",
            accessibilityDescription: "Three-dimensional watercolour nursery shapes drifting on warm paper",
            tapHint: "Tap to bloom a watercolour splash",
            icon: "paintbrush.pointed.fill",
            tint: Color(red: 0.75, green: 0.55, blue: 0.70),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .potterGarden3D: SceneDescriptor(
            displayName: "Potter Garden 3D",
            accessibilityDescription: "Three-dimensional Beatrix Potter cottage garden diorama with rows of cabbages, a stone wall, a wooden gate, butterflies, and warm afternoon light",
            tapHint: "Tap to release a butterfly",
            icon: "leaf.fill",
            tint: Color(red: 0.35, green: 0.52, blue: 0.30),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .innerLight3D: SceneDescriptor(
            displayName: "Inner Light 3D",
            accessibilityDescription: "Warm glowing geometric forms floating in deep indigo space, connected by luminous filaments, tiny motes rising like thoughts forming",
            tapHint: "Tap to send a brightness pulse through the connections",
            icon: "light.max",
            tint: Color(red: 0.85, green: 0.65, blue: 0.30),
            audioMood: "mystical",
            hasSceneKitVersion: true
        ),
        .wireframeCity3D: SceneDescriptor(
            displayName: "Wireframe City 3D",
            accessibilityDescription: "Green phosphor wireframe cityscape on black, a slow flyover of glowing vector buildings, grid floor scrolling beneath, nineteen-eighties vector terminal aesthetic",
            tapHint: "Tap to sweep a radar pulse across the grid",
            icon: "grid",
            tint: Color(red: 0.15, green: 0.90, blue: 0.35),
            audioMood: "dreamy",
            hasSceneKitVersion: true
        ),
        .rotatingAerial3D: SceneDescriptor(
            displayName: "Rotating Aerial 3D",
            accessibilityDescription: "A rooftop TV antenna on a motorised rotator turning slowly against a dusk sky full of stars, a small TV on the roof shows static that clears when the aerial finds a signal",
            tapHint: "Tap to reverse the antenna rotation",
            icon: "antenna.radiowaves.left.and.right",
            tint: Color(red: 0.45, green: 0.35, blue: 0.55),
            audioMood: "dreamy"
        ),
        .lastAndFirstMen3D: SceneDescriptor(
            displayName: "Last and First Men 3D",
            accessibilityDescription: "Abstract art deco retelling of Olaf Stapledon's Last and First Men: eighteen human species across two billion years, migrating from Earth to Venus to Neptune, ascending through the Kardashev scale from a single world to the stars",
            tapHint: "Tap to awaken the next human species in the chain of becoming",
            icon: "infinity",
            tint: Color(red: 0.88, green: 0.70, blue: 0.25),
            audioMood: "cosmic"
        ),
        .murmuration: SceneDescriptor(
            displayName: "Murmuration",
            accessibilityDescription: "Hundreds of warm cream dots following three simple rules, separation alignment cohesion, creating an emergent flocking pattern that moves like a single breathing organism against a dark sky",
            tapHint: "Tap to send a gentle scare ripple through the flock",
            icon: "bird",
            tint: Color(red: 0.92, green: 0.85, blue: 0.70),
            audioMood: "dreamy"
        ),
        .murmuration3D: SceneDescriptor(
            displayName: "Murmuration 3D",
            accessibilityDescription: "Three-dimensional murmuration with hundreds of small bird-like triangles turning and folding through dark space, an orbiting camera watching the flock breathe and sweep",
            tapHint: "Tap to send a gentle scare pulse through the flock",
            icon: "bird.fill",
            tint: Color(red: 0.88, green: 0.78, blue: 0.60),
            audioMood: "dreamy"
        ),
        .silicaBench3D: SceneDescriptor(
            displayName: "Silica Bench 3D",
            accessibilityDescription: "A vast golden cathedral-rotunda with thirty-two pillars supporting a great dome, a celestial orrery of concentric torus rings and orbiting planets spinning around a pulsing sun, forty floating crystal gems, and six thousand rising embers, the camera gliding through on a rail like a 2003 GPU benchmark",
            tapHint: "Tap to release a golden starburst of particles",
            icon: "building.columns",
            tint: Color(red: 0.92, green: 0.78, blue: 0.35),
            audioMood: "cosmic"
        ),
    ]

    // MARK: - Computed Properties

    private var descriptor: SceneDescriptor {
        guard let d = Self.descriptors[self] else {
            fatalError("Missing descriptor for \(self.rawValue)")
        }
        return d
    }

    var hasSceneKitVersion: Bool { descriptor.hasSceneKitVersion }
    var displayName: String { descriptor.displayName }
    var accessibilityDescription: String { descriptor.accessibilityDescription }
    var tapHint: String { descriptor.tapHint }
    var icon: String { descriptor.icon }
    var tint: Color { descriptor.tint }
    var audioMood: String { descriptor.audioMood }
}
