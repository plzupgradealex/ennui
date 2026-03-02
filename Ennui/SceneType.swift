import SwiftUI

enum SceneKind: String, CaseIterable, Identifiable {
    case cosmicDrift = "cosmicDrift"
    case retroGarden = "retroGarden"
    case deepOcean = "deepOcean"
    case desertStarscape = "desertStarscape"
    case ancientRuins = "ancientRuins"
    case saltLamp = "saltLamp"
    case conservatory = "conservatory"

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
        }
    }
}
