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

    var id: String { rawValue }

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
        }
    }
}
