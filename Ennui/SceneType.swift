import SwiftUI

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

    var id: String { rawValue }

    // MARK: - Display name (human-readable, used in accessibility)

    var displayName: String {
        switch self {
        case .cosmicDrift: return "Cosmic Drift"
        case .retroGarden: return "Retro Garden"
        case .deepOcean: return "Deep Ocean"
        case .desertStarscape: return "Desert Starscape"
        case .ancientRuins: return "Ancient Ruins"
        case .saltLamp: return "Salt Lamp"
        case .conservatory: return "Conservatory"
        case .nightTrain: return "Night Train"
        case .greetingTheDay: return "Greeting the Day"
        case .celShadedRainyDay: return "Rainy Day"
        case .voyagerNebula: return "Voyager Nebula"
        case .retroPS1: return "Retro PS1"
        case .auroraBorealis: return "Aurora Borealis"
        case .paperLanternFestival: return "Paper Lantern Festival"
        case .forgottenLibrary: return "Forgotten Library"
        case .lateNightRerun: return "Late Night Rerun"
        case .medievalVillage: return "Medieval Village"
        case .urbanDreamscape: return "Urban Dreamscape"
        case .lushRuins: return "Lush Ruins"
        case .enchantedArchives: return "Enchanted Archives"
        case .celestialScrollHall: return "Celestial Scroll Hall"
        case .jeonjuNight: return "Jeonju Night"
        case .quietMeal: return "Quiet Meal"
        case .artDecoLA: return "Art Deco LA"
        case .floatingKingdom: return "Floating Kingdom"
        case .ontarioCountryside: return "Ontario Countryside"
        case .minnesotaSmallTown: return "Minnesota Small Town"
        case .shimizuEvening: return "Shimizu Evening"
        case .mystify: return "Mystify"
        case .midnightMotel: return "Midnight Motel"
        case .captainStar: return "Captain Star"
        case .nonsenseLullabies: return "Nonsense & Lullabies"
        case .gouraudSolarSystem: return "Solar System"
        case .potterGarden: return "Potter Garden"
        case .medievalVillage3D: return "Medieval Village 3D"
        case .lateNightRerun3D: return "Late Night Rerun 3D"
        case .jeonjuNight3D: return "Jeonju Night 3D"
        case .oldCar: return "Old Car"
        case .oldCar3D: return "Old Car 3D"
        case .cosmicDrift3D: return "Cosmic Drift 3D"
        case .voyagerNebula3D: return "Voyager Nebula 3D"
        case .desertStarscape3D: return "Desert Starscape 3D"
        case .deepOcean3D: return "Deep Ocean 3D"
        case .ancientRuins3D: return "Ancient Ruins 3D"
        case .lushRuins3D: return "Lush Ruins 3D"
        case .auroraBorealis3D: return "Aurora Borealis 3D"
        case .saltLamp3D: return "Salt Lamp 3D"
        case .conservatory3D: return "Conservatory 3D"
        case .quietMeal3D: return "Quiet Meal 3D"
        case .artDecoLA3D: return "Art Deco LA 3D"
        case .urbanDreamscape3D: return "Urban Dreamscape 3D"
        case .shimizuEvening3D: return "Shimizu Evening 3D"
        case .nightTrain3D: return "Night Train 3D"
        case .ontarioCountryside3D: return "Ontario Countryside 3D"
        case .minnesotaSmallTown3D: return "Minnesota Small Town 3D"
        case .midnightMotel3D: return "Midnight Motel 3D"
        case .forgottenLibrary3D: return "Forgotten Library 3D"
        case .enchantedArchives3D: return "Enchanted Archives 3D"
        case .celestialScrollHall3D: return "Celestial Scroll Hall 3D"
        case .floatingKingdom3D: return "Floating Kingdom 3D"
        case .paperLanternFestival3D: return "Paper Lantern Festival 3D"
        case .captainStar3D: return "Captain Star 3D"
        case .gouraudSolarSystem3D: return "Solar System 3D"
        case .retroGarden3D: return "Retro Garden 3D"
        case .celShadedRainyDay3D: return "Rainy Day 3D"
        case .retroPS13D: return "Retro PS1 3D"
        case .greetingTheDay3D: return "Greeting the Day 3D"
        case .mystify3D: return "Mystify 3D"
        case .nonsenseLullabies3D: return "Nonsense & Lullabies 3D"
        case .potterGarden3D: return "Potter Garden 3D"
        case .innerLight3D: return "Inner Light 3D"
        case .wireframeCity3D: return "Wireframe City 3D"
        }
    }

    // MARK: - Accessibility description (rich VoiceOver context)

    var accessibilityDescription: String {
        switch self {
        case .cosmicDrift: return "Gentle nebulae and twinkling stars drifting through warm cosmic space"
        case .retroGarden: return "A peaceful pixel-art garden with flowers, butterflies, and soft sunlight"
        case .deepOcean: return "Bioluminescent creatures glowing softly in the deep ocean"
        case .desertStarscape: return "Warm desert dunes beneath a vast starry sky"
        case .ancientRuins: return "Ancient stone ruins bathed in soft aurora light with fireflies"
        case .saltLamp: return "The warm amber glow of a Himalayan salt lamp breathing gently"
        case .conservatory: return "Rain on greenhouse windows with plants swaying and steam rising"
        case .nightTrain: return "A gentle night train journey through moonlit countryside"
        case .greetingTheDay: return "A city waking up at sunrise with buildings growing toward the light"
        case .celShadedRainyDay: return "Bright flowers thriving in gentle rain, puddles forming in a cartoon world"
        case .voyagerNebula: return "Drifting through a magnificent nebula, swirling teal and magenta"
        case .retroPS1: return "A nostalgic low-poly nighttime scene with a glowing cabin and fireflies"
        case .auroraBorealis: return "Northern lights dancing in green and violet over a frozen lake with pine trees"
        case .paperLanternFestival: return "A serene lake at dusk where each click releases a glowing lantern carrying a kind message into the night"
        case .forgottenLibrary: return "An infinite twilight library with towering bookshelves and floating golden letters"
        case .lateNightRerun: return "Falling asleep to late-night TV reruns in a cosy nineties bedroom"
        case .medievalVillage: return "A peaceful medieval village settling down for the night under moonlight"
        case .urbanDreamscape: return "A dreamy cel-shaded city blending world capitals at night"
        case .lushRuins: return "Ancient moss-covered temple ruins in a lush tropical jungle with waterfalls"
        case .enchantedArchives: return "A wild magical library where books fly open and paper birds soar"
        case .celestialScrollHall: return "A moonlit Chinese study hall with calligraphy scrolls and glowing characters"
        case .jeonjuNight: return "A quiet Korean neighbourhood at night in the nineteen-nineties"
        case .quietMeal: return "Two friends sharing a quiet meal, seen through the window on a rainy evening"
        case .artDecoLA: return "An art deco Los Angeles boulevard at golden hour with palm trees, streamline moderne buildings, and a vintage red streetcar"
        case .floatingKingdom: return "A sky kingdom floating above an ocean of clouds, with crystalline spires, waterfalls cascading into mist, and motes of ancient magical energy drifting upward"
        case .ontarioCountryside: return "A warm summer evening settling over the rural countryside of southern Ontario in the early nineteen-nineties, with golden wheat fields, an old red barn, a gravel road, and fireflies beginning to blink in the blue hour"
        case .minnesotaSmallTown: return "A calm summer evening in a tiny Minnesota prairie town, with a steeple, a water tower, a grain elevator, a diner with a flickering neon sign, and fireflies drifting over Main Street"
        case .shimizuEvening: return "A quiet Japanese residential neighbourhood on a rainy evening, with a peaked wooden house, a concrete block wall, a corner shop with a striped awning, utility poles, and warm yellow windows glowing through the rain"
        case .mystify: return "Glowing lines bouncing across a dark screen, leaving phosphor trails like a Windows 95 screensaver dreaming"
        case .midnightMotel: return "A quiet motel room in 1968 America, neon vacancy sign bleeding through thin curtains, wood paneling, a warm lamp, and headlights sweeping across the ceiling"
        case .captainStar: return "A barren desert planet at the edge of the universe, ochre skies, floating rocks, a lone glass outpost, stars visible through the dust, cosmic desolation made beautiful"
        case .nonsenseLullabies: return "Hand-painted watercolour nursery shapes drifting on warm paper, cats, moons, little houses, gentle paint drips running down"
        case .gouraudSolarSystem: return "A retro-rendered imaginary solar system with Gouraud-shaded planets orbiting a warm star, specular highlights, ring systems, and moons drifting in elliptical orbits"
        case .potterGarden: return "A watercolour English cottage garden in the style of Beatrix Potter, rows of lush green cabbages on brown earth paths, a stone wall with a wooden gate, a distant cottage, butterflies drifting in warm afternoon light"
        case .medievalVillage3D: return "A low-poly three-dimensional medieval village diorama viewed from above, with warm window lights, moonlit roofs, firefly particles, and a slowly orbiting camera"
        case .lateNightRerun3D: return "A three-dimensional nineties bedroom seen from bed, CRT television casting colored light across the walls, glow-in-the-dark ceiling stars, a pulsing lava lamp"
        case .jeonjuNight3D: return "A three-dimensional quiet Korean neighbourhood at night, hanok houses with warm windows, a sodium-lit street lamp casting orange light, moths, a cat on a wall, telephone wires against the night sky"
        case .oldCar: return "Driving a vintage car through a snowstorm at night, dash lights glowing amber, wipers sweeping, radio tuned to static warmth"
        case .oldCar3D: return "First-person three-dimensional view from inside a nineteen-fifties land yacht, snow rushing at the windshield, utility poles scrolling past, amber dash instruments glowing"
        case .cosmicDrift3D: return "A three-dimensional nebula with stars drifting through warm cosmic space"
        case .voyagerNebula3D: return "Drifting through a three-dimensional nebula with stellar nurseries"
        case .desertStarscape3D: return "Three-dimensional dunes beneath a vast starry sky"
        case .deepOcean3D: return "Three-dimensional bioluminescent deep ocean creatures"
        case .ancientRuins3D: return "Three-dimensional ancient stone ruins bathed in aurora light"
        case .lushRuins3D: return "Three-dimensional moss-covered temple ruins in a tropical jungle"
        case .auroraBorealis3D: return "Three-dimensional northern lights dancing over a frozen lake"
        case .saltLamp3D: return "A three-dimensional Himalayan salt lamp breathing warmly"
        case .conservatory3D: return "Three-dimensional greenhouse with rain on glass and plants"
        case .quietMeal3D: return "Three-dimensional view of two friends sharing a meal through a rainy window"
        case .artDecoLA3D: return "Three-dimensional art deco Los Angeles boulevard at golden hour"
        case .urbanDreamscape3D: return "A three-dimensional dreamy cel-shaded city at night"
        case .shimizuEvening3D: return "Three-dimensional Japanese neighbourhood on a rainy evening"
        case .nightTrain3D: return "Three-dimensional night train journey through moonlit countryside"
        case .ontarioCountryside3D: return "Three-dimensional Ontario countryside at dusk in the nineties"
        case .minnesotaSmallTown3D: return "Three-dimensional Minnesota prairie town on a summer evening"
        case .midnightMotel3D: return "Three-dimensional motel room in 1968 with neon bleeding through curtains"
        case .forgottenLibrary3D: return "Three-dimensional infinite twilight library with floating letters"
        case .enchantedArchives3D: return "Three-dimensional magical library with flying paper birds"
        case .celestialScrollHall3D: return "Three-dimensional moonlit Chinese study hall with calligraphy"
        case .floatingKingdom3D: return "Three-dimensional sky kingdom floating above clouds"
        case .paperLanternFestival3D: return "Three-dimensional lanterns rising over a dark lake at dusk"
        case .captainStar3D: return "Three-dimensional barren desert planet at the edge of the universe"
        case .gouraudSolarSystem3D: return "Three-dimensional retro solar system with Gouraud-shaded planets"
        case .retroGarden3D: return "Three-dimensional pixel-art garden with butterflies"
        case .celShadedRainyDay3D: return "Three-dimensional cartoon rain with flowers and puddles"
        case .retroPS13D: return "Three-dimensional low-poly cabin with fireflies"
        case .greetingTheDay3D: return "Three-dimensional city waking up at sunrise"
        case .mystify3D: return "Three-dimensional glowing lines bouncing with phosphor trails"
        case .nonsenseLullabies3D: return "Three-dimensional watercolour nursery shapes drifting on warm paper"
        case .potterGarden3D: return "Three-dimensional Beatrix Potter cottage garden diorama with rows of cabbages, a stone wall, a wooden gate, butterflies, and warm afternoon light"
        case .innerLight3D: return "Warm glowing geometric forms floating in deep indigo space, connected by luminous filaments, tiny motes rising like thoughts forming"
        case .wireframeCity3D: return "Green phosphor wireframe cityscape on black, a slow flyover of glowing vector buildings, grid floor scrolling beneath, nineteen-eighties vector terminal aesthetic"
        }
    }

    // MARK: - Tap hint for accessibility

    var tapHint: String {
        switch self {
        case .cosmicDrift: return "Tap to send a ripple through the stars"
        case .retroGarden: return "Tap to plant a flower"
        case .deepOcean: return "Tap to attract bioluminescent creatures"
        case .desertStarscape: return "Tap to send a ripple across the dunes"
        case .ancientRuins: return "Tap to release fireflies"
        case .saltLamp: return "Tap to brighten the glow"
        case .conservatory: return "Tap to make it rain harder"
        case .nightTrain: return "Tap to light a window"
        case .greetingTheDay: return "Tap to grow a new building"
        case .celShadedRainyDay: return "Tap for a splash"
        case .voyagerNebula: return "Tap to pulse the nebula"
        case .retroPS1: return "Tap to scatter fireflies"
        case .auroraBorealis: return "Tap to send a solar flare through the aurora"
        case .paperLanternFestival: return "Tap to release a lantern with a gentle message"
        case .forgottenLibrary: return "Tap to open a book and release glowing letters"
        case .lateNightRerun: return "Tap to change the channel"
        case .medievalVillage: return "Tap to snuff a candle"
        case .urbanDreamscape: return "Tap to send a ripple through the puddles"
        case .lushRuins: return "Tap to release butterflies"
        case .enchantedArchives: return "Tap to scatter paper birds"
        case .celestialScrollHall: return "Tap to release glowing characters from a scroll"
        case .jeonjuNight: return "Tap to toggle a window light"
        case .quietMeal: return "Tap to send a raindrop down the glass"
        case .artDecoLA: return "Tap to sweep a searchlight across the sky"
        case .floatingKingdom: return "Tap to send a pulse of magical energy rippling outward"
        case .ontarioCountryside: return "Tap to send a gust of wind rippling through the wheat"
        case .minnesotaSmallTown: return "Tap to send a firefly drifting across the scene"
        case .shimizuEvening: return "Tap to send a splash rippling through a puddle"
        case .mystify: return "Tap to launch an extra ribbon of light"
        case .midnightMotel: return "Tap to send headlights sweeping across the ceiling"
        case .captainStar: return "Tap to send a luminous pulse across the desert"
        case .nonsenseLullabies: return "Tap to bloom a watercolour splash"
        case .gouraudSolarSystem: return "Tap to shimmer a planet or add a new moon"
        case .potterGarden: return "Tap to release a butterfly"
        case .medievalVillage3D: return "Tap to snuff a window light"
        case .lateNightRerun3D: return "Tap to change the channel"
        case .jeonjuNight3D: return "Tap to toggle a window light"
        case .oldCar: return "Tap to honk and flash the dash lights"
        case .oldCar3D: return "Tap to honk and flash the dash lights"
        case .cosmicDrift3D: return "Tap to send a ripple through the stars"
        case .voyagerNebula3D: return "Tap to pulse the nebula"
        case .desertStarscape3D: return "Tap to send a ripple across the dunes"
        case .deepOcean3D: return "Tap to attract bioluminescent creatures"
        case .ancientRuins3D: return "Tap to release fireflies"
        case .lushRuins3D: return "Tap to release butterflies"
        case .auroraBorealis3D: return "Tap to send a solar flare through the aurora"
        case .saltLamp3D: return "Tap to brighten the glow"
        case .conservatory3D: return "Tap to make it rain harder"
        case .quietMeal3D: return "Tap to send a raindrop down the glass"
        case .artDecoLA3D: return "Tap to sweep a searchlight across the sky"
        case .urbanDreamscape3D: return "Tap to send a ripple through the puddles"
        case .shimizuEvening3D: return "Tap to send a splash rippling through a puddle"
        case .nightTrain3D: return "Tap to light a window"
        case .ontarioCountryside3D: return "Tap to send a gust of wind through the wheat"
        case .minnesotaSmallTown3D: return "Tap to send a firefly drifting"
        case .midnightMotel3D: return "Tap to send headlights sweeping across the ceiling"
        case .forgottenLibrary3D: return "Tap to open a book and release glowing letters"
        case .enchantedArchives3D: return "Tap to scatter paper birds"
        case .celestialScrollHall3D: return "Tap to release glowing characters"
        case .floatingKingdom3D: return "Tap to send a pulse of magical energy"
        case .paperLanternFestival3D: return "Tap to release a lantern"
        case .captainStar3D: return "Tap to send a luminous pulse across the desert"
        case .gouraudSolarSystem3D: return "Tap to shimmer a planet"
        case .retroGarden3D: return "Tap to plant a flower"
        case .celShadedRainyDay3D: return "Tap for a splash"
        case .retroPS13D: return "Tap to scatter fireflies"
        case .greetingTheDay3D: return "Tap to grow a new building"
        case .mystify3D: return "Tap to launch an extra ribbon of light"
        case .nonsenseLullabies3D: return "Tap to bloom a watercolour splash"
        case .potterGarden3D: return "Tap to release a butterfly"
        case .innerLight3D: return "Tap to send a brightness pulse through the connections"
        case .wireframeCity3D: return "Tap to sweep a radar pulse across the grid"
        }
    }

    var icon: String {
        switch self {
        case .cosmicDrift: return "sparkles"
        case .retroGarden: return "leaf"
        case .deepOcean: return "water.waves"
        case .desertStarscape: return "moon.stars"
        case .ancientRuins: return "building.columns"
        case .saltLamp: return "flame"
        case .conservatory: return "humidity"
        case .nightTrain: return "train.side.front.car"
        case .greetingTheDay: return "sunrise"
        case .celShadedRainyDay: return "cloud.rain"
        case .voyagerNebula: return "sparkle.magnifyingglass"
        case .retroPS1: return "gamecontroller"
        case .auroraBorealis: return "wind.snow"
        case .paperLanternFestival: return "lamp.desk"
        case .forgottenLibrary: return "books.vertical"
        case .lateNightRerun: return "tv"
        case .medievalVillage: return "house.lodge"
        case .urbanDreamscape: return "building.2"
        case .lushRuins: return "leaf.arrow.triangle.circlepath"
        case .enchantedArchives: return "book.and.wrench"
        case .celestialScrollHall: return "scroll"
        case .jeonjuNight: return "moon"
        case .quietMeal: return "cup.and.saucer"
        case .artDecoLA: return "building.columns.fill"
        case .floatingKingdom: return "cloud.sun"
        case .ontarioCountryside: return "sun.horizon"
        case .minnesotaSmallTown: return "house"
        case .shimizuEvening: return "cloud.rain.fill"
        case .mystify: return "display"
        case .midnightMotel: return "bed.double"
        case .captainStar: return "globe.americas"
        case .nonsenseLullabies: return "paintbrush.pointed"
        case .gouraudSolarSystem: return "globe.europe.africa"
        case .potterGarden: return "leaf.fill"
        case .medievalVillage3D: return "cube"
        case .lateNightRerun3D: return "cube.fill"
        case .jeonjuNight3D: return "cube.transparent"
        case .oldCar: return "car"
        case .oldCar3D: return "car.fill"
        case .cosmicDrift3D: return "cube"
        case .voyagerNebula3D: return "cube"
        case .desertStarscape3D: return "cube"
        case .deepOcean3D: return "cube"
        case .ancientRuins3D: return "cube"
        case .lushRuins3D: return "cube"
        case .auroraBorealis3D: return "cube"
        case .saltLamp3D: return "cube"
        case .conservatory3D: return "cube"
        case .quietMeal3D: return "cube"
        case .artDecoLA3D: return "cube"
        case .urbanDreamscape3D: return "cube"
        case .shimizuEvening3D: return "cube"
        case .nightTrain3D: return "cube"
        case .ontarioCountryside3D: return "cube"
        case .minnesotaSmallTown3D: return "cube"
        case .midnightMotel3D: return "cube"
        case .forgottenLibrary3D: return "cube"
        case .enchantedArchives3D: return "cube"
        case .celestialScrollHall3D: return "cube"
        case .floatingKingdom3D: return "cube"
        case .paperLanternFestival3D: return "cube"
        case .captainStar3D: return "cube"
        case .gouraudSolarSystem3D: return "cube"
        case .retroGarden3D: return "cube"
        case .celShadedRainyDay3D: return "cube"
        case .retroPS13D: return "cube"
        case .greetingTheDay3D: return "cube"
        case .mystify3D: return "cube"
        case .nonsenseLullabies3D: return "cube"
        case .potterGarden3D: return "cube"
        case .innerLight3D: return "cube"
        case .wireframeCity3D: return "cube"
        }
    }

    var tint: Color {
        switch self {
        case .cosmicDrift: return Color(red: 0.5, green: 0.3, blue: 0.9)
        case .retroGarden: return Color(red: 0.3, green: 0.7, blue: 0.3)
        case .deepOcean: return Color(red: 0.1, green: 0.4, blue: 0.8)
        case .desertStarscape: return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .ancientRuins: return Color(red: 0.3, green: 0.7, blue: 0.5)
        case .saltLamp: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .conservatory: return Color(red: 0.4, green: 0.65, blue: 0.45)
        case .nightTrain: return Color(red: 0.3, green: 0.25, blue: 0.5)
        case .greetingTheDay: return Color(red: 0.9, green: 0.65, blue: 0.3)
        case .celShadedRainyDay: return Color(red: 0.4, green: 0.5, blue: 0.35)
        case .voyagerNebula: return Color(red: 0.3, green: 0.55, blue: 0.75)
        case .retroPS1: return Color(red: 0.25, green: 0.2, blue: 0.4)
        case .auroraBorealis: return Color(red: 0.15, green: 0.7, blue: 0.45)
        case .paperLanternFestival: return Color(red: 0.9, green: 0.6, blue: 0.15)
        case .forgottenLibrary: return Color(red: 0.55, green: 0.4, blue: 0.25)
        case .lateNightRerun: return Color(red: 0.3, green: 0.25, blue: 0.55)
        case .medievalVillage: return Color(red: 0.7, green: 0.5, blue: 0.25)
        case .urbanDreamscape: return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .lushRuins: return Color(red: 0.2, green: 0.65, blue: 0.35)
        case .enchantedArchives: return Color(red: 0.45, green: 0.3, blue: 0.6)
        case .celestialScrollHall: return Color(red: 0.75, green: 0.55, blue: 0.3)
        case .jeonjuNight: return Color(red: 0.35, green: 0.25, blue: 0.5)
        case .quietMeal: return Color(red: 0.7, green: 0.6, blue: 0.45)
        case .artDecoLA: return Color(red: 0.9, green: 0.7, blue: 0.35)
        case .floatingKingdom: return Color(red: 0.4, green: 0.3, blue: 0.7)
        case .ontarioCountryside: return Color(red: 0.75, green: 0.55, blue: 0.20)
        case .minnesotaSmallTown: return Color(red: 0.85, green: 0.55, blue: 0.30)
        case .shimizuEvening: return Color(red: 0.30, green: 0.38, blue: 0.58)
        case .mystify: return Color(red: 0.20, green: 0.85, blue: 0.90)
        case .midnightMotel: return Color(red: 0.85, green: 0.30, blue: 0.35)
        case .captainStar: return Color(red: 0.72, green: 0.52, blue: 0.22)
        case .nonsenseLullabies: return Color(red: 0.75, green: 0.55, blue: 0.70)
        case .gouraudSolarSystem: return Color(red: 0.35, green: 0.25, blue: 0.65)
        case .potterGarden: return Color(red: 0.40, green: 0.58, blue: 0.35)
        case .medievalVillage3D: return Color(red: 0.60, green: 0.45, blue: 0.25)
        case .lateNightRerun3D: return Color(red: 0.25, green: 0.20, blue: 0.50)
        case .jeonjuNight3D: return Color(red: 0.85, green: 0.60, blue: 0.22)
        case .oldCar: return Color(red: 0.45, green: 0.35, blue: 0.25)
        case .oldCar3D: return Color(red: 0.40, green: 0.30, blue: 0.20)
        case .cosmicDrift3D: return Color(red: 0.5, green: 0.3, blue: 0.9)
        case .voyagerNebula3D: return Color(red: 0.3, green: 0.55, blue: 0.75)
        case .desertStarscape3D: return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .deepOcean3D: return Color(red: 0.1, green: 0.4, blue: 0.8)
        case .ancientRuins3D: return Color(red: 0.3, green: 0.7, blue: 0.5)
        case .lushRuins3D: return Color(red: 0.2, green: 0.65, blue: 0.35)
        case .auroraBorealis3D: return Color(red: 0.15, green: 0.7, blue: 0.45)
        case .saltLamp3D: return Color(red: 0.95, green: 0.55, blue: 0.2)
        case .conservatory3D: return Color(red: 0.4, green: 0.65, blue: 0.45)
        case .quietMeal3D: return Color(red: 0.7, green: 0.6, blue: 0.45)
        case .artDecoLA3D: return Color(red: 0.9, green: 0.7, blue: 0.35)
        case .urbanDreamscape3D: return Color(red: 0.6, green: 0.3, blue: 0.8)
        case .shimizuEvening3D: return Color(red: 0.30, green: 0.38, blue: 0.58)
        case .nightTrain3D: return Color(red: 0.3, green: 0.25, blue: 0.5)
        case .ontarioCountryside3D: return Color(red: 0.75, green: 0.55, blue: 0.20)
        case .minnesotaSmallTown3D: return Color(red: 0.85, green: 0.55, blue: 0.30)
        case .midnightMotel3D: return Color(red: 0.85, green: 0.30, blue: 0.35)
        case .forgottenLibrary3D: return Color(red: 0.55, green: 0.4, blue: 0.25)
        case .enchantedArchives3D: return Color(red: 0.45, green: 0.3, blue: 0.6)
        case .celestialScrollHall3D: return Color(red: 0.75, green: 0.55, blue: 0.3)
        case .floatingKingdom3D: return Color(red: 0.4, green: 0.3, blue: 0.7)
        case .paperLanternFestival3D: return Color(red: 0.9, green: 0.6, blue: 0.15)
        case .captainStar3D: return Color(red: 0.72, green: 0.52, blue: 0.22)
        case .gouraudSolarSystem3D: return Color(red: 0.35, green: 0.25, blue: 0.65)
        case .retroGarden3D: return Color(red: 0.3, green: 0.7, blue: 0.3)
        case .celShadedRainyDay3D: return Color(red: 0.4, green: 0.5, blue: 0.35)
        case .retroPS13D: return Color(red: 0.25, green: 0.2, blue: 0.4)
        case .greetingTheDay3D: return Color(red: 0.9, green: 0.65, blue: 0.3)
        case .mystify3D: return Color(red: 0.20, green: 0.85, blue: 0.90)
        case .nonsenseLullabies3D: return Color(red: 0.75, green: 0.55, blue: 0.70)
        case .potterGarden3D: return Color(red: 0.35, green: 0.52, blue: 0.30)
        case .innerLight3D: return Color(red: 0.85, green: 0.65, blue: 0.30)
        case .wireframeCity3D: return Color(red: 0.15, green: 0.90, blue: 0.35)
        }
    }

    // MARK: - Ambient audio mood (maps each scene to a generative tone palette)

    var audioMood: String {
        switch self {
        // Amber comfort — home, warmth, safety
        case .saltLamp, .conservatory, .artDecoLA, .quietMeal,
             .lateNightRerun, .midnightMotel, .oldCar,
             .lateNightRerun3D, .oldCar3D,
             .saltLamp3D, .conservatory3D, .artDecoLA3D, .quietMeal3D,
             .midnightMotel3D:
            return "warm"
        // Rain, ocean, night — cooler, more spacious
        case .deepOcean, .celShadedRainyDay, .shimizuEvening, .jeonjuNight,
             .jeonjuNight3D, .deepOcean3D,
             .shimizuEvening3D, .celShadedRainyDay3D:
            return "cool"
        // Stars, nebulae, vast emptiness
        case .cosmicDrift, .voyagerNebula, .desertStarscape,
             .gouraudSolarSystem, .captainStar,
             .cosmicDrift3D, .voyagerNebula3D, .desertStarscape3D,
             .gouraudSolarSystem3D, .captainStar3D:
            return "cosmic"
        // Fields, villages, natural world
        case .ontarioCountryside, .minnesotaSmallTown, .medievalVillage,
             .ancientRuins, .lushRuins, .medievalVillage3D,
             .ancientRuins3D,
             .lushRuins3D, .ontarioCountryside3D, .minnesotaSmallTown3D:
            return "earthy"
        // Retro, nostalgia, gentle floating
        case .retroGarden, .retroPS1, .nightTrain, .paperLanternFestival,
             .mystify, .nonsenseLullabies, .floatingKingdom, .greetingTheDay,
             .potterGarden,
             .retroGarden3D, .retroPS13D, .nightTrain3D, .paperLanternFestival3D,
             .mystify3D, .nonsenseLullabies3D, .floatingKingdom3D, .greetingTheDay3D,
             .potterGarden3D,
             .wireframeCity3D:
            return "dreamy"
        // Libraries, scrolls, ancient knowledge, aurora
        case .forgottenLibrary, .enchantedArchives, .celestialScrollHall,
             .auroraBorealis, .urbanDreamscape, .auroraBorealis3D,
             .forgottenLibrary3D, .enchantedArchives3D, .celestialScrollHall3D,
             .urbanDreamscape3D, .innerLight3D:
            return "mystical"
        }
    }
}
