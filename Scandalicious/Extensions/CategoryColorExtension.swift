//
//  CategoryColorExtension.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

// MARK: - Premium High-Contrast Category Colors
extension String {
    /// Intelligently assigns premium, high-contrast colors to categories
    var categoryColor: Color {
        let categoryName = self.lowercased()

        // Healthy categories - Vibrant Emerald Green
        if categoryName.contains("fruit") || categoryName.contains("vegetable") ||
           categoryName.contains("salad") || categoryName.contains("greens") ||
           categoryName.contains("organic") || categoryName.contains("fresh produce") ||
           categoryName.contains("produce") {
            return Color(red: 0.18, green: 0.80, blue: 0.44)  // Emerald green
        }

        // Unhealthy categories - Vivid Coral Red
        if categoryName.contains("snack") || categoryName.contains("sweet") ||
           categoryName.contains("candy") || categoryName.contains("chocolate") ||
           categoryName.contains("chips") || categoryName.contains("cookie") ||
           categoryName.contains("dessert") || categoryName.contains("cake") ||
           categoryName.contains("ice cream") || categoryName.contains("soda") ||
           categoryName.contains("soft") && categoryName.contains("drink") {
            return Color(red: 1.0, green: 0.36, blue: 0.42)  // Coral red
        }

        // Alcohol - Rich Burgundy
        if categoryName.contains("alcohol") || categoryName.contains("beer") ||
           categoryName.contains("wine") || categoryName.contains("spirit") {
            return Color(red: 0.72, green: 0.15, blue: 0.30)  // Burgundy
        }

        // Meat & Fish - Warm Amber Orange
        if categoryName.contains("meat") || categoryName.contains("fish") ||
           categoryName.contains("poultry") || categoryName.contains("seafood") ||
           categoryName.contains("chicken") || categoryName.contains("beef") {
            return Color(red: 1.0, green: 0.58, blue: 0.20)  // Amber orange
        }

        // Dairy - Electric Sky Blue
        if categoryName.contains("dairy") || categoryName.contains("milk") ||
           categoryName.contains("cheese") || categoryName.contains("yogurt") ||
           categoryName.contains("egg") {
            return Color(red: 0.25, green: 0.72, blue: 1.0)  // Electric blue
        }

        // Bakery & Bread - Golden Yellow
        if categoryName.contains("bakery") || categoryName.contains("bread") ||
           categoryName.contains("pastry") || categoryName.contains("bake") {
            return Color(red: 1.0, green: 0.78, blue: 0.22)  // Golden yellow
        }

        // Household & Cleaning - Royal Purple
        if categoryName.contains("household") || categoryName.contains("cleaning") ||
           categoryName.contains("detergent") || categoryName.contains("supplies") {
            return Color(red: 0.55, green: 0.35, blue: 0.95)  // Royal purple
        }

        // Personal Care - Vivid Magenta Pink
        if categoryName.contains("personal") || categoryName.contains("care") ||
           categoryName.contains("hygiene") || categoryName.contains("cosmetic") ||
           categoryName.contains("beauty") {
            return Color(red: 0.95, green: 0.35, blue: 0.65)  // Magenta pink
        }

        // Drinks (general, non-alcoholic) - Bright Teal
        if categoryName.contains("drink") || categoryName.contains("beverage") ||
           categoryName.contains("juice") || categoryName.contains("water") {
            return Color(red: 0.15, green: 0.82, blue: 0.78)  // Bright teal
        }

        // Frozen foods - Icy Cyan
        if categoryName.contains("frozen") {
            return Color(red: 0.40, green: 0.85, blue: 0.98)  // Icy cyan
        }

        // Canned/Preserved - Rich Bronze
        if categoryName.contains("canned") || categoryName.contains("preserved") {
            return Color(red: 0.80, green: 0.55, blue: 0.25)  // Bronze
        }

        // Pantry/General - Warm Copper
        if categoryName.contains("pantry") {
            return Color(red: 0.85, green: 0.50, blue: 0.30)  // Copper
        }

        // Ready meals - Sunset Orange
        if categoryName.contains("ready") || categoryName.contains("meal") {
            return Color(red: 1.0, green: 0.50, blue: 0.30)  // Sunset orange
        }

        // "Other" category - Soft Steel
        if categoryName == "other" {
            return Color(red: 0.55, green: 0.58, blue: 0.65)  // Steel gray
        }

        // Premium fallback colors for uncategorized items
        let fallbackColors: [Color] = [
            Color(red: 0.45, green: 0.70, blue: 0.95),   // Ocean blue
            Color(red: 0.90, green: 0.55, blue: 0.35),   // Terracotta
            Color(red: 0.65, green: 0.45, blue: 0.80),   // Lavender
            Color(red: 0.35, green: 0.75, blue: 0.60),   // Jade
        ]

        // Use hash of category name to consistently assign same color
        let hash = abs(categoryName.hashValue)
        return fallbackColors[hash % fallbackColors.count]
    }

    /// Returns hex color string for categories (for CategorySpendItem conversion)
    var categoryColorHex: String {
        return categoryColor.toHex()
    }
}

// MARK: - Color to Hex Extension
extension Color {
    /// Convert SwiftUI Color to hex string
    func toHex() -> String {
        // Convert to UIColor/NSColor components
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        #elseif canImport(AppKit)
        let uiColor = NSColor(self)
        #endif

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        #if canImport(UIKit)
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #elseif canImport(AppKit)
        uiColor.usingColorSpace(.deviceRGB)?.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #endif

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
