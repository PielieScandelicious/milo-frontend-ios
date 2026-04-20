//
//  MechanismKind.swift
//  Scandalicious
//
//  Classifies a promo's mechanism string into a small enum so the UI can
//  colour + icon it consistently. The backend returns free-form display
//  strings ("1+1 Gratis", "-25% Vanaf 2 Verpakkingen", "Prijsverlaging",
//  "3 voor €5", …) — the keyword parse happens ONCE here, never in views.
//

import SwiftUI

enum MechanismKind {
    case gratis         // "1+1 Gratis", "2+1 Gratis", "X+Y Gratis"
    case halfPrice      // "2e aan Halve Prijs", "2e Tegen -50%"
    case discountPercent // "-25%", "-25% Vanaf 2 Verpakkingen"
    case bundleDeal     // "3 voor €5", "2 Voor €3"
    case priceCut       // "Prijsverlaging", generic
    case other

    static func from(displayMechanism: String?, mechanism: String?) -> MechanismKind {
        let raw = (displayMechanism?.isEmpty == false ? displayMechanism! : mechanism ?? "")
            .lowercased()

        if raw.isEmpty { return .other }

        if raw.contains("gratis") || raw.contains("+") && raw.contains("gratis") {
            return .gratis
        }
        if raw.contains("halve prijs") || raw.contains("halfprijs") || raw.contains("-50%") && raw.contains("2e") {
            return .halfPrice
        }
        if raw.contains("voor €") || raw.contains("voor ") && raw.contains("€") {
            return .bundleDeal
        }
        if raw.contains("%") || raw.contains("-25") || raw.contains("-30") || raw.contains("-40") {
            return .discountPercent
        }
        if raw.contains("prijsverlaging") || raw.contains("réduction") || raw.contains("price") {
            return .priceCut
        }
        return .other
    }

    var color: Color {
        switch self {
        case .gratis: return PromoDesign.mechanismGratis
        case .halfPrice: return PromoDesign.mechanismHalfPrice
        case .discountPercent: return PromoDesign.mechanismDiscount
        case .bundleDeal: return PromoDesign.mechanismBundle
        case .priceCut: return PromoDesign.mechanismPriceCut
        case .other: return PromoDesign.mechanismOther
        }
    }

    /// Text colour that contrasts with `color`.
    var textColor: Color {
        switch self {
        case .gratis, .halfPrice: return .black.opacity(0.85)
        case .discountPercent, .bundleDeal, .priceCut: return .white
        case .other: return .white.opacity(0.85)
        }
    }

    var iconName: String {
        switch self {
        case .gratis: return "gift.fill"
        case .halfPrice: return "percent"
        case .discountPercent: return "tag.fill"
        case .bundleDeal: return "square.stack.3d.up.fill"
        case .priceCut: return "arrow.down.circle.fill"
        case .other: return "tag"
        }
    }
}
