//
//  BrandLogoDisc.swift
//  Scandalicious
//
//  White circular brand badge worn on the photo block of every deal row /
//  featured card. When the deal feed exposes a real `brandLogoURL`, the disc
//  loads it; otherwise it falls back to a 1–2 letter monogram in the brand's
//  accent color.
//

import SwiftUI

struct BrandLogoDisc: View {
    let brand: String
    var brandColor: Color = CashbackTokens.greenInk
    var logoURL: URL? = nil
    var size: CGFloat = 28
    var ring: Bool = true

    var body: some View {
        ZStack {
            Circle().fill(.white)

            if let url = logoURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    default:
                        monogram
                    }
                }
                .padding(size * 0.10)
            } else {
                monogram
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(.white.opacity(ring ? 0.95 : 0), lineWidth: 2)
        )
        .compositingGroup()
        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
    }

    private var monogram: some View {
        Text(monogramText)
            .font(.system(size: size * 0.42, weight: .black, design: .rounded))
            .kerning(-0.5)
            .foregroundStyle(brandColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }

    private var monogramText: String {
        let cleaned = brand.replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\u{2019}", with: "")
        let letters = cleaned
            .split(whereSeparator: { $0.isWhitespace })
            .compactMap { $0.first.map { String($0) } }
            .joined()
        return String(letters.prefix(2)).uppercased()
    }
}

// MARK: - Brand color helper

extension Color {
    /// Decode a `#RRGGBB` or `RRGGBB` hex string into a Color. Returns nil on
    /// malformed input so callers can fall through to a sensible default
    /// (e.g. the cashback green ink).
    init?(cashbackHex hex: String) {
        var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("#") { cleaned.removeFirst() }
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value & 0xFF0000) >> 16) / 255.0
        let g = Double((value & 0x00FF00) >> 8)  / 255.0
        let b = Double( value & 0x0000FF)        / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
