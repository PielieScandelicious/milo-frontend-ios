//
//  PromoDesign.swift
//  Scandalicious
//
//  Centralised design tokens for promo surfaces (cards, sheets, hotspots,
//  grocery-list rows). All colour, spacing, and typography constants used by
//  promo components live here so cards and sheets never visually drift.
//

import SwiftUI

enum PromoDesign {

    // MARK: - Colours

    static let cardBackground = Color(white: 0.08)
    static let cardOverlayTop = Color.white.opacity(0.04)
    static let cardBorder = Color.white.opacity(0.10)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.65)
    static let tertiaryText = Color.white.opacity(0.40)
    static let metaText = Color.white.opacity(0.25)

    /// Generic brand green used when no store accent is available.
    static let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
    static let accentGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)

    /// Mechanism-family colours — consumed by `MechanismKind.color`.
    static let mechanismGratis = Color(red: 1.0, green: 0.84, blue: 0.20)       // gold — "X+Y gratis"
    static let mechanismHalfPrice = Color(red: 0.95, green: 0.55, blue: 0.15)    // orange — "2e aan halve prijs"
    static let mechanismDiscount = Color(red: 0.20, green: 0.85, blue: 0.50)     // green — "-X%"
    static let mechanismBundle = Color(red: 0.55, green: 0.50, blue: 0.95)       // purple — "X voor €Y"
    static let mechanismPriceCut = Color(red: 0.20, green: 0.70, blue: 0.95)     // blue — "Prijsverlaging"
    static let mechanismOther = Color(white: 0.18)

    /// Urgency colours for validity chips.
    static let urgencyExpired = Color.white.opacity(0.25)
    static let urgencyUrgent = Color(red: 0.95, green: 0.25, blue: 0.25)         // <=0 day
    static let urgencySoon = Color(red: 0.95, green: 0.55, blue: 0.15)           // 1-2 days
    static let urgencyWarn = Color(red: 0.95, green: 0.75, blue: 0.30)           // 3-5 days
    static let urgencyRelaxed = Color.white.opacity(0.40)                        // 6+ days

    // MARK: - Spacing

    static let cardCorner: CGFloat = 18
    static let pillCorner: CGFloat = 10
    static let chipCorner: CGFloat = 8

    static let cardPadding: CGFloat = 14
    static let sectionSpacing: CGFloat = 16
    static let inlineSpacing: CGFloat = 8

    // MARK: - Typography helpers (used where SwiftUI modifiers don't compose cleanly)

    static func heroPrice() -> Font { .system(size: 34, weight: .bold, design: .rounded) }
    static func cardPrice() -> Font { .system(size: 22, weight: .bold, design: .rounded) }
    static func unitPrice() -> Font { .system(size: 15, weight: .semibold, design: .rounded) }
    static func strikePrice() -> Font { .system(size: 13, weight: .medium) }
    static func eyebrow() -> Font { .system(size: 10, weight: .semibold) }
    static func chip() -> Font { .system(size: 11, weight: .semibold) }
}
