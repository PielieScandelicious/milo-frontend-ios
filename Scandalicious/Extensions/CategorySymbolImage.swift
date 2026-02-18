//
//  CategorySymbolImage.swift
//  Scandalicious
//

import SwiftUI
import PhosphorSwift

extension Image {
    /// Creates a resizable, template-rendered icon from a Phosphor icon name (kebab-case)
    /// or falls back to an SF Symbol. Use `.frame(width:height:)` for sizing and
    /// `.foregroundStyle()` for coloring.
    @ViewBuilder
    static func categorySymbol(_ name: String) -> some View {
        if let phIcon = Ph(rawValue: name) {
            phIcon.fill
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: name)
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}

// MARK: - Category Icon Badge (Circle)

/// A circular badge with a category's background color and a darker-shade Phosphor icon.
///
/// Usage:
///   CategoryIconBadge(icon: "carrot", color: Color(hex: "#4ADE80")!, size: 48)
///   CategoryIconBadge(categoryName: "Vegetables", size: 48)
struct CategoryIconBadge: View {
    let icon: String
    let color: Color
    let size: CGFloat

    /// Convenience: look up icon + color from the category registry.
    init(categoryName: String, size: CGFloat = 48) {
        self.icon = categoryName.categoryIcon
        self.color = categoryName.categoryColor
        self.size = size
    }

    /// Direct init with explicit icon name and color.
    init(icon: String, color: Color, size: CGFloat = 48) {
        self.icon = icon
        self.color = color
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: size, height: size)

            Image.categorySymbol(icon)
                .frame(width: size * 0.6, height: size * 0.6)
                .foregroundStyle(darkerShade)
        }
    }

    /// A slightly darker shade of the background color for icon contrast.
    private var darkerShade: Color {
        color.adjustBrightness(by: -0.25)
    }
}

// MARK: - Color Brightness Helper

extension Color {
    /// Returns a new color with brightness adjusted by the given amount (-1…1).
    /// Negative values darken, positive values lighten.
    func adjustBrightness(by amount: Double) -> Color {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
        UIColor(self).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        #endif

        let newBrightness = max(0, min(1, brightness + CGFloat(amount)))
        let newSaturation = min(1, saturation + CGFloat(-amount * 0.15))
        return Color(hue: Double(hue), saturation: Double(newSaturation), brightness: Double(newBrightness), opacity: Double(alpha))
    }
}
