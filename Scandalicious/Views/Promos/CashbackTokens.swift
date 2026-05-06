//
//  CashbackTokens.swift
//  Scandalicious
//
//  Shared color + typography tokens for the redesigned Cashback tab.
//  Centralised so component files stop duplicating raw RGB literals.
//

import SwiftUI

enum CashbackTokens {
    // MARK: Greens
    static let green     = Color(red: 0.25, green: 0.90, blue: 0.55)        // #40E58D
    static let greenDim  = Color(red: 0.25, green: 0.90, blue: 0.55).opacity(0.55)
    static let greenInk  = Color(red: 0.024, green: 0.075, blue: 0.047)     // text on green

    // MARK: Gold
    static let gold      = Color(red: 1.00, green: 0.80, blue: 0.20)        // #FFCC33
    static let goldDim   = Color(red: 1.00, green: 0.80, blue: 0.20).opacity(0.55)
    static let goldInk   = Color(red: 0.102, green: 0.075, blue: 0.0)

    // MARK: Warn
    static let warn      = Color(red: 1.00, green: 0.545, blue: 0.20)       // #FF8B33

    // MARK: Surface
    static let bg        = Color(red: 0.043, green: 0.043, blue: 0.055)     // #0B0B0E
    static let card      = Color.white.opacity(0.045)
    static let cardStroke = Color.white.opacity(0.075)

    // MARK: Text
    static let textPrimary = Color(red: 0.988, green: 0.988, blue: 0.992)   // #FCFCFD
    static let text85    = Color.white.opacity(0.85)
    static let text70    = Color.white.opacity(0.70)
    static let text55    = Color.white.opacity(0.55)
    static let text45    = Color.white.opacity(0.45)
    static let text40    = Color.white.opacity(0.40)
    static let text30    = Color.white.opacity(0.30)
    static let text15    = Color.white.opacity(0.15)
    static let text08    = Color.white.opacity(0.08)
    static let text06    = Color.white.opacity(0.06)

    // MARK: Layout
    static let gridPhotoSize: CGFloat = 124
}

// MARK: - Typography

/// Three families per the design spec:
///   • Inter         — UI labels, body, eyebrow, button labels
///   • InstrumentSerif — editorial headlines, balance, deal titles
///   • GeistMono     — numerics, stat values, chip amounts
///
/// The .ttf files are not yet bundled. Until they ship, falls back to the
/// closest SwiftUI system designs (`.serif`, default `.system`,
/// `.monospaced`). Once `Inter*.ttf` / `InstrumentSerif*.ttf` /
/// `GeistMono*.ttf` are added to the asset catalog and registered in
/// Info.plist (`UIAppFonts`), flip `useCustomFonts` to `true` and the
/// rest of the app picks them up automatically.
enum CashbackFont {
    /// Toggle once the .ttf files are bundled and registered.
    private static let useCustomFonts: Bool = false

    static func sans(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard useCustomFonts else {
            return .system(size: size, weight: weight, design: .default)
        }
        let name: String
        switch weight {
        case .medium:                name = "Inter-Medium"
        case .semibold:              name = "Inter-SemiBold"
        case .bold, .heavy, .black:  name = "Inter-Bold"
        default:                     name = "Inter-Regular"
        }
        return .custom(name, size: size)
    }

    static func serif(_ size: CGFloat, italic: Bool = false) -> Font {
        guard useCustomFonts else {
            return .system(size: size, weight: .regular, design: .serif)
                .italic(italic)
        }
        return .custom(italic ? "InstrumentSerif-Italic" : "InstrumentSerif-Regular", size: size)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        guard useCustomFonts else {
            return .system(size: size, weight: weight, design: .monospaced)
        }
        let name: String
        switch weight {
        case .medium:    name = "GeistMono-Medium"
        case .semibold:  name = "GeistMono-SemiBold"
        default:         name = "GeistMono-Regular"
        }
        return .custom(name, size: size)
    }
}

private extension Font {
    func italic(_ on: Bool) -> Font { on ? self.italic() : self }
}
