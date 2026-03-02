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
        }
    }
}
