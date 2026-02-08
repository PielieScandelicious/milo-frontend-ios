//
//  CategoryColorExtension.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

// MARK: - Category Name Normalization
extension String {
    /// Normalizes category names from enum-style (e.g., "MEAT_FISH") to display style (e.g., "Meat & Fish")
    /// If already in proper display format, returns unchanged.
    var normalizedCategoryName: String {
        // If it contains spaces or lowercase letters, it's already in display format
        if self.contains(" ") || self.first?.isLowercase == true {
            return self
        }

        // Check if it looks like an enum name (all caps with underscores)
        if self.allSatisfy({ $0.isUppercase || $0 == "_" || $0.isNumber }) {
            // Convert MEAT_FISH -> Meat & Fish
            return self
                .replacingOccurrences(of: "_", with: " ")
                .split(separator: " ")
                .map { word in
                    // Handle special words
                    let lower = String(word).lowercased()
                    switch lower {
                    case "and": return "&"
                    case "non": return "Non"
                    default: return word.capitalized
                    }
                }
                .joined(separator: " ")
        }

        return self
    }
}

// MARK: - Category Icon Lookup
extension String {
    /// Get SF Symbol icon for a grocery category based on its name
    var categoryIcon: String {
        let name = self.lowercased()

        // Fresh Food
        if name == "fruits" || name.contains("fruit") { return "leaf.fill" }
        if name == "vegetables" || name.contains("veg") || name.contains("produce") { return "carrot.fill" }
        if name == "seafood" || name.contains("seafood") || name.contains("fish") { return "fish.fill" }
        if name == "meat" || name.contains("meat") || name.contains("poultry") { return "fork.knife" }
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") { return "mug.fill" }
        if name.contains("bakery") || name.contains("bread") { return "croissant.fill" }

        // Pantry & Frozen
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") { return "cabinet.fill" }
        if name.contains("frozen") { return "snowflake" }
        if name.contains("ready meal") || name.contains("prepared food") { return "takeoutbag.and.cup.and.straw.fill" }

        // Snacks & Beverages
        if name == "candy" || name.contains("candy") || name.contains("chocolate") || name.contains("sweet") { return "gift.fill" }
        if name.contains("snack") { return "birthday.cake.fill" }
        if name.contains("beverage") || name.contains("non-alcoholic") || name == "drinks" { return "cup.and.saucer.fill" }
        if name.contains("beer") || name.contains("wine") || name.contains("alcohol") { return "wineglass.fill" }

        // Household & Care
        if name.contains("household consumable") || name.contains("paper/cleaning") { return "house.fill" }
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") { return "sparkles" }

        // Other
        if name.contains("baby food") || name.contains("formula") { return "figure.and.child.holdinghands" }
        if name.contains("pet food") || name.contains("pet supplies") { return "pawprint.fill" }
        if name.contains("tobacco") { return "smoke.fill" }

        // Legacy category names (for backward compatibility)
        if name.contains("personal care") { return "sparkles" }
        if name.contains("household") { return "house.fill" }
        if name.contains("pet") { return "pawprint.fill" }
        if name.contains("baby") { return "figure.and.child.holdinghands" }
        if name.contains("ready") || name.contains("meal") { return "takeoutbag.and.cup.and.straw.fill" }
        if name.contains("drink") || name.contains("soda") || name.contains("soft") { return "cup.and.saucer.fill" }
        if name.contains("water") { return "waterbottle.fill" }
        if name.contains("sweet") { return "birthday.cake.fill" }
        if name == "other" { return "shippingbox.fill" }

        return "square.grid.2x2.fill"
    }
}

// MARK: - Grocery Category Colors
extension String {
    /// Assigns premium, high-contrast colors to grocery categories
    var categoryColor: Color {
        let categoryName = self.lowercased()

        // Fruits - Vibrant Emerald Green
        if categoryName == "fruits" || categoryName.contains("fruit") {
            return Color(red: 0.18, green: 0.80, blue: 0.44)
        }

        // Vegetables - Fresh Teal Green
        if categoryName == "vegetables" || categoryName.contains("vegetable") ||
           categoryName.contains("salad") || categoryName.contains("produce") {
            return Color(red: 0.20, green: 0.70, blue: 0.55)
        }

        // Seafood - Ocean Blue
        if categoryName == "seafood" || categoryName.contains("seafood") ||
           categoryName.contains("fish") || categoryName.contains("shrimp") {
            return Color(red: 0.20, green: 0.55, blue: 0.85)
        }

        // Meat - Warm Amber Orange
        if categoryName == "meat" || categoryName.contains("meat") ||
           categoryName.contains("poultry") || categoryName.contains("chicken") ||
           categoryName.contains("beef") {
            return Color(red: 1.0, green: 0.58, blue: 0.20)
        }

        // Dairy - Electric Sky Blue
        if categoryName.contains("dairy") || categoryName.contains("milk") ||
           categoryName.contains("cheese") || categoryName.contains("yogurt") ||
           categoryName.contains("egg") {
            return Color(red: 0.25, green: 0.72, blue: 1.0)
        }

        // Bakery & Bread - Golden Yellow
        if categoryName.contains("bakery") || categoryName.contains("bread") ||
           categoryName.contains("pastry") || categoryName.contains("bake") {
            return Color(red: 1.0, green: 0.78, blue: 0.22)
        }

        // Pantry - Warm Copper
        if categoryName.contains("pantry") {
            return Color(red: 0.85, green: 0.50, blue: 0.30)
        }

        // Frozen foods - Icy Cyan
        if categoryName.contains("frozen") {
            return Color(red: 0.40, green: 0.85, blue: 0.98)
        }

        // Ready meals - Sunset Orange
        if categoryName.contains("ready") || categoryName.contains("prepared") {
            return Color(red: 1.0, green: 0.50, blue: 0.30)
        }

        // Candy - Vivid Pink
        if categoryName == "candy" || categoryName.contains("candy") ||
           categoryName.contains("chocolate") || categoryName.contains("sweet") {
            return Color(red: 0.92, green: 0.30, blue: 0.65)
        }

        // Snacks - Vivid Coral Red
        if categoryName.contains("snack") || categoryName.contains("chips") ||
           categoryName.contains("cookie") {
            return Color(red: 1.0, green: 0.36, blue: 0.42)
        }

        // Beverages (Non-Alcoholic) - Bright Teal
        if categoryName.contains("drink") || categoryName.contains("beverage") ||
           categoryName.contains("juice") || categoryName.contains("water") {
            return Color(red: 0.15, green: 0.82, blue: 0.78)
        }

        // Alcohol - Rich Burgundy
        if categoryName.contains("alcohol") || categoryName.contains("beer") ||
           categoryName.contains("wine") || categoryName.contains("spirit") {
            return Color(red: 0.72, green: 0.15, blue: 0.30)
        }

        // Household & Cleaning - Royal Purple
        if categoryName.contains("household") || categoryName.contains("cleaning") ||
           categoryName.contains("detergent") || categoryName.contains("supplies") {
            return Color(red: 0.55, green: 0.35, blue: 0.95)
        }

        // Personal Care - Vivid Magenta Pink
        if categoryName.contains("personal") || categoryName.contains("care") ||
           categoryName.contains("hygiene") || categoryName.contains("cosmetic") {
            return Color(red: 0.95, green: 0.35, blue: 0.65)
        }

        // Baby & Kids - Soft Green
        if categoryName.contains("baby") || categoryName.contains("formula") {
            return Color(red: 0.40, green: 0.78, blue: 0.47)
        }

        // Pet Supplies - Muted Brown
        if categoryName.contains("pet") {
            return Color(red: 0.65, green: 0.55, blue: 0.40)
        }

        // Tobacco - Dark Red
        if categoryName.contains("tobacco") {
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        }

        // "Other" category - Soft Steel
        if categoryName == "other" {
            return Color(red: 0.55, green: 0.58, blue: 0.65)
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

// MARK: - Grocery Sub-Category Health Theming
extension String {
    /// Health-gradient color for grocery sub-categories (green=healthy → red=unhealthy).
    /// Returns nil if this name is not a recognized grocery sub-category.
    var groceryHealthColor: Color? {
        let name = self.lowercased()

        // Very healthy → emerald green
        if name == "fruits" || name.contains("fruit") {
            return Color(red: 0.18, green: 0.80, blue: 0.44)
        }
        // Very healthy → teal green
        if name == "vegetables" || name.contains("veg") || name.contains("produce") {
            return Color(red: 0.20, green: 0.78, blue: 0.50)
        }
        // Healthy → soft green
        if name.contains("baby food") || name.contains("formula") || name == "baby & kids" {
            return Color(red: 0.40, green: 0.78, blue: 0.47)
        }
        // Healthy → teal-green
        if name.contains("beverage") || name.contains("non-alcoholic") || name == "drinks" {
            return Color(red: 0.15, green: 0.78, blue: 0.68)
        }
        // Healthy → blue-green
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") {
            return Color(red: 0.30, green: 0.75, blue: 0.65)
        }
        // Moderately healthy → yellow-green
        if name == "meat" || name.contains("meat") || name.contains("poultry") {
            return Color(red: 0.55, green: 0.78, blue: 0.35)
        }
        // Moderately healthy → blue-green
        if name == "seafood" || name.contains("seafood") || name.contains("fish") {
            return Color(red: 0.40, green: 0.72, blue: 0.55)
        }
        // Moderate → golden yellow
        if name.contains("bakery") || name.contains("bread") {
            return Color(red: 0.92, green: 0.78, blue: 0.28)
        }
        // Moderate → warm amber
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") {
            return Color(red: 0.88, green: 0.68, blue: 0.30)
        }
        // Neutral → icy blue
        if name.contains("frozen") {
            return Color(red: 0.40, green: 0.80, blue: 0.95)
        }
        // Non-food → muted brown
        if name.contains("pet food") || name.contains("pet supplies") || name == "pet supplies" {
            return Color(red: 0.65, green: 0.55, blue: 0.40)
        }
        // Non-food → muted purple
        if name.contains("household consumable") || name.contains("paper/cleaning") || name == "household" {
            return Color(red: 0.58, green: 0.48, blue: 0.78)
        }
        // Non-food → lavender pink
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") || name == "personal care" {
            return Color(red: 0.75, green: 0.48, blue: 0.72)
        }
        // Less healthy → orange
        if name.contains("ready meal") || name.contains("prepared food") || name == "ready meals" {
            return Color(red: 1.0, green: 0.55, blue: 0.25)
        }
        // Unhealthy → pink
        if name == "candy" || name.contains("candy") || name.contains("sweet") {
            return Color(red: 0.92, green: 0.30, blue: 0.65)
        }
        // Unhealthy → coral red
        if name.contains("snack") {
            return Color(red: 1.0, green: 0.36, blue: 0.36)
        }
        // Very unhealthy → dark red
        if name.contains("tobacco") {
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        }
        return nil
    }

    /// Health-themed SF Symbol icon for grocery sub-categories.
    /// Returns nil if this name is not a recognized grocery sub-category.
    var groceryHealthIcon: String? {
        let name = self.lowercased()
        if name == "fruits" || name.contains("fruit") { return "leaf.fill" }
        if name == "vegetables" || name.contains("veg") || name.contains("produce") { return "carrot.fill" }
        if name == "seafood" || name.contains("seafood") || name.contains("fish") { return "fish.fill" }
        if name == "meat" || name.contains("meat") || name.contains("poultry") { return "fork.knife" }
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") { return "mug.fill" }
        if name.contains("bakery") || name.contains("bread") { return "croissant.fill" }
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") { return "cabinet.fill" }
        if name.contains("frozen") { return "snowflake" }
        if name == "candy" || name.contains("candy") || name.contains("sweet") || name.contains("confectionery") { return "gift.fill" }
        if name.contains("snack") { return "birthday.cake.fill" }
        if name.contains("beverage") || name.contains("non-alcoholic") || name == "drinks" { return "cup.and.saucer.fill" }
        if name.contains("alcohol") || name.contains("beer") || name.contains("wine") || name.contains("spirit") { return "wineglass.fill" }
        if name.contains("baby food") || name.contains("formula") || name.contains("baby") { return "figure.and.child.holdinghands" }
        if name.contains("pet food") || name.contains("pet supplies") || name.contains("pet") { return "pawprint.fill" }
        if name.contains("household") || name.contains("paper/cleaning") || name.contains("cleaning") { return "house.fill" }
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") || name == "personal care" { return "sparkles" }
        if name.contains("ready meal") || name.contains("prepared food") || name == "ready meals" { return "takeoutbag.and.cup.and.straw.fill" }
        if name.contains("tobacco") { return "smoke.fill" }
        if name == "other" { return "shippingbox.fill" }
        return nil
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
