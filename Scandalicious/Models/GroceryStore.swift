//
//  GroceryStore.swift
//  Scandalicious
//
//  Belgian grocery store definitions for store preference selection.
//

import SwiftUI

enum GroceryStore: String, CaseIterable, Identifiable {
    case colruyt = "Colruyt"
    case delhaize = "Delhaize"
    case proxyDelhaize = "Proxy Delhaize"
    case shopAndGo = "Shop & Go"
    case carrefour = "Carrefour"
    case carrefourMarket = "Carrefour Market"
    case carrefourExpress = "Carrefour Express"
    case lidl = "Lidl"
    case aldi = "Aldi"
    case albertHeijn = "Albert Heijn"
    case ahToGo = "AH To Go"
    case okay = "Okay"
    case okayCompact = "OKay Compact"
    case spar = "Spar"
    case bioPlanet = "Bio-Planet"
    case jumbo = "Jumbo"
    case action = "Action"
    case makro = "Makro"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var logoImageName: String {
        switch self {
        case .colruyt: return "store-colruyt"
        case .delhaize, .proxyDelhaize, .shopAndGo: return "store-delhaize"
        case .carrefour, .carrefourMarket, .carrefourExpress: return "store-carrefour"
        case .lidl: return "store-lidl"
        case .aldi: return "store-aldi"
        case .albertHeijn, .ahToGo: return "store-albert-heijn"
        case .okay, .okayCompact: return "store-okay"
        case .spar: return "store-spar"
        case .bioPlanet: return "store-bioplanet"
        case .jumbo: return "store-jumbo"
        case .action: return "store-action"
        case .makro: return "store-makro"
        }
    }

    var accentColor: Color {
        switch self {
        case .colruyt: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .delhaize, .proxyDelhaize, .shopAndGo: return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .carrefour, .carrefourMarket, .carrefourExpress: return Color(red: 0.20, green: 0.55, blue: 0.85)
        case .lidl: return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .aldi: return Color(red: 0.90, green: 0.25, blue: 0.25)
        case .albertHeijn, .ahToGo: return Color(red: 0.95, green: 0.80, blue: 0.20)
        case .okay, .okayCompact: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .spar: return Color(red: 0.15, green: 0.60, blue: 0.30)
        case .bioPlanet: return Color(red: 0.30, green: 0.75, blue: 0.45)
        case .jumbo: return Color(red: 0.95, green: 0.75, blue: 0.05)
        case .action: return Color(red: 0.00, green: 0.45, blue: 0.80)
        case .makro: return Color(red: 0.90, green: 0.20, blue: 0.20)
        }
    }

    static func from(rawValues: [String]?) -> Set<GroceryStore> {
        guard let values = rawValues else { return [] }
        return Set(values.compactMap { GroceryStore(rawValue: $0) })
    }
}
