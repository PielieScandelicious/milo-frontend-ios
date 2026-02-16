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

    /// Localized category display name: normalizes then translates to current language.
    /// Use this for UI display. Keep `normalizedCategoryName` for color/icon lookups.
    var localizedCategoryName: String {
        let normalized = self.normalizedCategoryName
        if let key = _categoryNameToTranslationKey[normalized] {
            return L(key)
        }
        return normalized
    }
}

/// English display name → AppStrings key for category translations
private let _categoryNameToTranslationKey: [String: String] = [
    "Fruits": "cat_fruits",
    "Vegetables": "cat_vegetables",
    "Meat & Poultry": "cat_meat_poultry",
    "Charcuterie & Salads": "cat_charcuterie_salads",
    "Fish & Seafood": "cat_fish_seafood",
    "Dairy, Eggs & Cheese": "cat_dairy_eggs_cheese",
    "Dairy Eggs & Cheese": "cat_dairy_eggs_cheese",
    "Bakery": "cat_bakery",
    "Pastries": "cat_pastries",
    "Grains, Pasta & Potatoes": "cat_grains_pasta_potatoes",
    "Grains Pasta & Potatoes": "cat_grains_pasta_potatoes",
    "Canned & Jarred Goods": "cat_canned_jarred",
    "Sauces & Condiments": "cat_sauces_condiments",
    "Breakfast & Cereal": "cat_breakfast_cereal",
    "Baking & Flour": "cat_baking_flour",
    "Frozen Ingredients": "cat_frozen_ingredients",
    "Fries & Snacks": "cat_fries_snacks",
    "Ready Meals & Pizza": "cat_ready_meals",
    "Ready Meals": "cat_ready_meals",
    "Water": "cat_water",
    "Soda & Juices": "cat_soda_juices",
    "Coffee & Tea": "cat_coffee_tea",
    "Alcohol": "cat_alcohol",
    "Chips, Nuts & Aperitif": "cat_chips_nuts",
    "Chips Nuts & Aperitif": "cat_chips_nuts",
    "Chocolate & Sweets": "cat_chocolate_sweets",
    "Waste Bags": "cat_waste_bags",
    "Cleaning & Paper Goods": "cat_cleaning",
    "Cleaning": "cat_cleaning",
    "Pharmacy & Hygiene": "cat_pharmacy_hygiene",
    "Pharmacy": "cat_pharmacy_hygiene",
    "Baby & Kids": "cat_baby_kids",
    "Pet Supplies": "cat_pet_supplies",
    "Tobacco": "cat_tobacco",
    "Lottery & Scratch Cards": "cat_lottery",
    "Lottery": "cat_lottery",
    "Deposits": "cat_deposits",
    "Other": "cat_other",
    // Group names
    "Fresh Food": "group_fresh_food",
    "Pantry & Staples": "group_pantry_staples",
    "Frozen": "group_frozen",
    "Drinks": "group_drinks",
    "Snacks": "group_snacks",
    "Household": "group_household",
    "Personal Care": "group_personal_care",
]

// MARK: - Category Icon Lookup (Phosphor)
extension String {
    /// Get Phosphor icon identifier for a grocery category based on its name.
    /// Returns a Phosphor raw value string usable with `Image.categorySymbol()`.
    var categoryIcon: String {
        ExpenseCategory.from(name: self).phIconName
    }
}

// MARK: - Grocery Category Colors
extension String {
    /// Assigns vibrant colors to grocery categories via the ExpenseCategory enum.
    var categoryColor: Color {
        ExpenseCategory.from(name: self).color
    }

    /// Returns hex color string for categories (for CategorySpendItem conversion)
    var categoryColorHex: String {
        return categoryColor.toHex()
    }
}

// MARK: - Grocery Sub-Category Health Theming
extension String {
    /// Health-gradient color for grocery sub-categories (green=healthy -> red=unhealthy).
    /// Returns nil if this name is not a recognized grocery sub-category.
    var groceryHealthColor: Color? {
        let name = self.lowercased()

        // Very healthy -> emerald green
        if name == "fruits" || name.contains("fruit") {
            return Color(red: 0.18, green: 0.80, blue: 0.44)
        }
        // Very healthy -> teal green
        if name == "vegetables" || name.contains("veg") || name.contains("produce") {
            return Color(red: 0.20, green: 0.78, blue: 0.50)
        }
        // Healthy -> soft green
        if name.contains("baby food") || name.contains("formula") || name == "baby & kids" {
            return Color(red: 0.40, green: 0.78, blue: 0.47)
        }
        // Healthy -> teal-green
        if name.contains("beverage") || name.contains("non-alcoholic") || name == "drinks" {
            return Color(red: 0.15, green: 0.78, blue: 0.68)
        }
        // Healthy -> blue-green
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") {
            return Color(red: 0.30, green: 0.75, blue: 0.65)
        }
        // Moderately healthy -> yellow-green
        if name == "meat" || name.contains("meat") || name.contains("poultry") {
            return Color(red: 0.55, green: 0.78, blue: 0.35)
        }
        // Moderately healthy -> blue-green
        if name == "seafood" || name.contains("seafood") || name.contains("fish") {
            return Color(red: 0.40, green: 0.72, blue: 0.55)
        }
        // Moderate -> golden yellow
        if name.contains("bakery") || name.contains("bread") {
            return Color(red: 0.92, green: 0.78, blue: 0.28)
        }
        // Moderate -> warm amber
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") {
            return Color(red: 0.88, green: 0.68, blue: 0.30)
        }
        // Neutral -> icy blue
        if name.contains("frozen") {
            return Color(red: 0.40, green: 0.80, blue: 0.95)
        }
        // Non-food -> muted brown
        if name.contains("pet food") || name.contains("pet supplies") || name == "pet supplies" {
            return Color(red: 0.65, green: 0.55, blue: 0.40)
        }
        // Non-food -> muted purple
        if name.contains("household consumable") || name.contains("paper/cleaning") || name == "household" {
            return Color(red: 0.58, green: 0.48, blue: 0.78)
        }
        // Non-food -> lavender pink
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") || name == "personal care" {
            return Color(red: 0.75, green: 0.48, blue: 0.72)
        }
        // Less healthy -> orange
        if name.contains("ready meal") || name.contains("prepared food") || name == "ready meals" {
            return Color(red: 1.0, green: 0.55, blue: 0.25)
        }
        // Unhealthy -> pink
        if name == "candy" || name.contains("candy") || name.contains("sweet") {
            return Color(red: 0.92, green: 0.30, blue: 0.65)
        }
        // Unhealthy -> coral red
        if name.contains("snack") {
            return Color(red: 1.0, green: 0.36, blue: 0.36)
        }
        // Very unhealthy -> dark red
        if name.contains("tobacco") {
            return Color(red: 0.80, green: 0.20, blue: 0.20)
        }
        return nil
    }

    /// Health-themed Phosphor icon identifier for grocery sub-categories.
    /// Returns nil if this name is not a recognized grocery sub-category.
    var groceryHealthIcon: String? {
        let name = self.lowercased()
        if name == "fruits" || name.contains("fruit") { return "apple-logo" }
        if name == "vegetables" || name.contains("veg") || name.contains("produce") { return "carrot" }
        if name == "seafood" || name.contains("seafood") || name.contains("fish") { return "fish" }
        if name == "meat" || name.contains("meat") || name.contains("poultry") { return "bone" }
        if name.contains("dairy") || name.contains("cheese") || name.contains("egg") { return "cheese" }
        if name.contains("bakery") || name.contains("bread") { return "bread" }
        if name.contains("pantry") || name.contains("pasta") || name.contains("rice") { return "grains" }
        if name.contains("frozen") { return "snowflake" }
        if name == "candy" || name.contains("candy") || name.contains("sweet") || name.contains("confectionery") { return "cookie" }
        if name.contains("snack") { return "popcorn" }
        if name.contains("beverage") || name.contains("non-alcoholic") || name == "drinks" { return "orange-slice" }
        if name.contains("alcohol") || name.contains("beer") || name.contains("wine") || name.contains("spirit") { return "wine" }
        if name.contains("baby food") || name.contains("formula") || name.contains("baby") { return "baby" }
        if name.contains("pet food") || name.contains("pet supplies") || name.contains("pet") { return "paw-print" }
        if name.contains("household") || name.contains("paper/cleaning") || name.contains("cleaning") { return "sparkle" }
        if name.contains("hygiene") || name.contains("soap") || name.contains("shampoo") || name == "personal care" { return "pill" }
        if name.contains("ready meal") || name.contains("prepared food") || name == "ready meals" { return "pizza" }
        if name.contains("tobacco") { return "cigarette" }
        if name == "other" { return "tag" }
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
