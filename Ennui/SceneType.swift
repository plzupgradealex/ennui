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
        }
    }
}
