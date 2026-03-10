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
    case carrefour = "Carrefour"
    case lidl = "Lidl"
    case aldi = "Aldi"
    case albertHeijn = "Albert Heijn"
    case okay = "Okay"
    case spar = "Spar"
    case bioPlanet = "Bio-Planet"

    var id: String { rawValue }
    var displayName: String { rawValue }

    var logoImageName: String {
        switch self {
        case .colruyt: return "store-colruyt"
        case .delhaize: return "store-delhaize"
        case .carrefour: return "store-carrefour"
        case .lidl: return "store-lidl"
        case .aldi: return "store-aldi"
        case .albertHeijn: return "store-albert-heijn"
        case .okay: return "store-okay"
        case .spar: return "store-spar"
        case .bioPlanet: return "store-bioplanet"
        }
    }

    var accentColor: Color {
        switch self {
        case .colruyt: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .delhaize: return Color(red: 0.20, green: 0.70, blue: 0.40)
        case .carrefour: return Color(red: 0.20, green: 0.55, blue: 0.85)
        case .lidl: return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .aldi: return Color(red: 0.90, green: 0.25, blue: 0.25)
        case .albertHeijn: return Color(red: 0.95, green: 0.80, blue: 0.20)
        case .okay: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .spar: return Color(red: 0.15, green: 0.60, blue: 0.30)
        case .bioPlanet: return Color(red: 0.30, green: 0.75, blue: 0.45)
        }
    }

    static func from(rawValues: [String]?) -> Set<GroceryStore> {
        guard let values = rawValues else { return [] }
        return Set(values.compactMap { GroceryStore(rawValue: $0) })
    }
}
