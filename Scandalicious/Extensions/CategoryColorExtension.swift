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
    "Promos & Discounts": "cat_promos_discounts",
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

// MARK: - Period Localization

extension String {
    /// Converts English period string (e.g., "February 2026") to user's language.
    /// Returns "All" periods via L("all_time"). Keeps internal key unchanged.
    var localizedPeriod: String {
        if self == "All" { return L("all_time") }

        let parser = DateFormatter()
        parser.dateFormat = "MMMM yyyy"
        parser.locale = Locale(identifier: "en_US")
        guard let date = parser.date(from: self) else { return self }

        let output = DateFormatter()
        output.dateFormat = "MMMM yyyy"
        let langCode = LanguageManager.currentLanguageCode
        output.locale = Locale(identifier: langCode == "nl" ? "nl_BE" : langCode == "fr" ? "fr_BE" : "en_US")
        return output.string(from: date)
    }

    /// Short localized period (e.g., "Feb 26" / "feb 26")
    var localizedShortPeriod: String {
        if self == "All" { return L("all_time") }

        let parser = DateFormatter()
        parser.dateFormat = "MMMM yyyy"
        parser.locale = Locale(identifier: "en_US")
        guard let date = parser.date(from: self) else { return self }

        let output = DateFormatter()
        output.dateFormat = "MMM yy"
        let langCode = LanguageManager.currentLanguageCode
        output.locale = Locale(identifier: langCode == "nl" ? "nl_BE" : langCode == "fr" ? "fr_BE" : "en_US")
        return output.string(from: date)
    }
}

// MARK: - Category Icon Lookup (Phosphor)
extension String {
    /// Get Phosphor icon identifier for a category based on its name.
    /// Looks up via CategoryRegistryManager (backend single source of truth).
    /// Returns a Phosphor raw value string usable with `Image.categorySymbol()`.
    var categoryIcon: String {
        CategoryRegistryManager.shared.iconForCategory(self.normalizedCategoryName)
    }
}

// MARK: - Category Colors
extension String {
    /// Get color for a category via CategoryRegistryManager (backend single source of truth).
    var categoryColor: Color {
        CategoryRegistryManager.shared.colorForCategory(self.normalizedCategoryName)
    }

    /// Returns hex color string for categories (for CategorySpendItem conversion)
    var categoryColorHex: String {
        CategoryRegistryManager.shared.colorHexForCategory(self.normalizedCategoryName)
    }
}

// MARK: - Grocery Category Check
extension String {
    /// Whether this category belongs to a grocery group (Fresh Food, Pantry, Frozen, Drinks, Snacks).
    /// Used to split receipt items into grocery vs non-grocery sections.
    var isGroceryCategory: Bool {
        let group = CategoryRegistryManager.shared.groupForCategory(self.normalizedCategoryName)
        let groceryGroups: Set<String> = ["Fresh Food", "Pantry & Staples", "Frozen", "Drinks", "Snacks"]
        return groceryGroups.contains(group)
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
