//
//  CategoryRegistry.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 04/02/2026.
//

import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Category Hierarchy Response Models

struct CategoryHierarchyResponse: Codable {
    let groups: [CategoryGroupResponse]
}

struct CategoryGroupResponse: Codable, Identifiable {
    let name: String
    let icon: String
    let colorHex: String
    let categories: [CategoryMidResponse]

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, icon, categories
        case colorHex = "color_hex"
    }
}

struct CategoryMidResponse: Codable, Identifiable {
    let name: String
    let displayName: String?
    let subCategories: [String]
    let icon: String?
    let colorHex: String?
    let budgetable: Bool?

    var id: String { name }

    /// Clean display name, falling back to raw name
    var cleanName: String { displayName ?? name }

    /// Whether this category can be used for budgeting (excludes promos, deposits, etc.)
    var isBudgetable: Bool { budgetable ?? true }

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case subCategories = "sub_categories"
        case icon
        case colorHex = "color_hex"
        case budgetable
    }
}

// MARK: - Used Categories Response Models

struct UsedCategoryResponse: Codable {
    let categories: [UsedCategory]
}

struct UsedCategory: Codable, Identifiable {
    let subCategory: String
    let displayName: String?
    let category: String
    let group: String
    let totalSpent: Double
    let transactionCount: Int
    let colorHex: String
    let icon: String
    let categoryId: String

    var id: String { categoryId }

    /// Clean display name, falling back to subCategory
    var cleanName: String { displayName ?? subCategory }

    enum CodingKeys: String, CodingKey {
        case subCategory = "sub_category"
        case displayName = "display_name"
        case category
        case group
        case totalSpent = "total_spent"
        case transactionCount = "transaction_count"
        case colorHex = "color_hex"
        case icon
        case categoryId = "category_id"
    }
}

// MARK: - Category Registry Manager

@MainActor
class CategoryRegistryManager: ObservableObject {
    static let shared = CategoryRegistryManager()

    @Published var hierarchy: CategoryHierarchyResponse?
    @Published var isLoaded = false

    // Group name -> (icon, colorHex) lookup
    private var groupLookup: [String: (icon: String, colorHex: String)] = [:]
    // Category internal name -> group name
    private var categoryToGroup: [String: String] = [:]
    // Category internal name -> clean display name
    private var categoryToDisplayName: [String: String] = [:]
    // Category internal name -> Phosphor icon
    private var categoryToIcon: [String: String] = [:]
    // Category internal name -> hex color
    private var categoryToColorHex: [String: String] = [:]
    // Display name -> Phosphor icon (for normalized name lookups)
    private var displayNameToIcon: [String: String] = [:]
    // Display name -> hex color (for normalized name lookups)
    private var displayNameToColorHex: [String: String] = [:]
    // Display name -> group name (for normalized name lookups)
    private var displayNameToGroup: [String: String] = [:]

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder = JSONDecoder()

    private init() {
        // Hardcoded fallback while API loads
        setupFallbackData()
    }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        await load()
    }

    func load() async {
        guard let url = URL(string: "\(baseURL)/categories") else { return }

        do {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.timeoutInterval = 30

            // Add auth header using the same pattern as AnalyticsAPIService
            if let user = Auth.auth().currentUser {
                let token = try await user.getIDToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try decoder.decode(CategoryHierarchyResponse.self, from: data)

            hierarchy = response
            buildLookups(from: response)
            isLoaded = true
        } catch {
            print("Failed to load category hierarchy: \(error)")
            // Fallback data already set in init
        }
    }

    private func buildLookups(from response: CategoryHierarchyResponse) {
        groupLookup.removeAll()
        categoryToGroup.removeAll()
        categoryToDisplayName.removeAll()
        categoryToIcon.removeAll()
        categoryToColorHex.removeAll()
        displayNameToIcon.removeAll()
        displayNameToColorHex.removeAll()
        displayNameToGroup.removeAll()

        for group in response.groups {
            groupLookup[group.name] = (icon: group.icon, colorHex: group.colorHex)
            for category in group.categories {
                let name = category.name
                let displayName = category.cleanName
                let icon = category.icon ?? "tag"
                let colorHex = category.colorHex ?? group.colorHex

                categoryToGroup[name] = group.name
                categoryToDisplayName[name] = displayName
                categoryToIcon[name] = icon
                categoryToColorHex[name] = colorHex

                // Also index by display name for normalized lookups
                displayNameToIcon[displayName] = icon
                displayNameToColorHex[displayName] = colorHex
                displayNameToGroup[displayName] = group.name
            }
        }
    }

    // MARK: - All Categories

    /// Returns all category names from the loaded hierarchy
    var allCategories: [String] {
        guard let hierarchy = hierarchy else { return [] }
        return hierarchy.groups.flatMap { group in
            group.categories.flatMap { $0.subCategories }
        }
    }

    /// Returns only categories that can be used for budget allocation
    /// (excludes promos, deposits, and other non-product categories)
    var budgetableCategories: [String] {
        guard let hierarchy = hierarchy else { return [] }
        return hierarchy.groups.flatMap { group in
            group.categories.filter { $0.isBudgetable }.flatMap { $0.subCategories }
        }
    }

    // MARK: - Localized Name Lookups

    /// Maps English API display names → AppStrings L() keys for category translations
    private static let categoryTranslationKeys: [String: String] = [
        "Fruits": "cat_fruits",
        "Vegetables": "cat_vegetables",
        "Meat & Poultry": "cat_meat_poultry",
        "Charcuterie & Salads": "cat_charcuterie_salads",
        "Fish & Seafood": "cat_fish_seafood",
        "Dairy, Eggs & Cheese": "cat_dairy_eggs_cheese",
        "Bakery": "cat_bakery",
        "Pastries": "cat_pastries",
        "Grains, Pasta & Potatoes": "cat_grains_pasta_potatoes",
        "Canned & Jarred Goods": "cat_canned_jarred",
        "Sauces & Condiments": "cat_sauces_condiments",
        "Breakfast & Cereal": "cat_breakfast_cereal",
        "Baking & Flour": "cat_baking_flour",
        "Frozen Ingredients": "cat_frozen_ingredients",
        "Fries & Snacks": "cat_fries_snacks",
        "Ready Meals & Pizza": "cat_ready_meals",
        "Water": "cat_water",
        "Soda & Juices": "cat_soda_juices",
        "Coffee & Tea": "cat_coffee_tea",
        "Alcohol": "cat_alcohol",
        "Chips, Nuts & Aperitif": "cat_chips_nuts",
        "Chocolate & Sweets": "cat_chocolate_sweets",
        "Waste Bags": "cat_waste_bags",
        "Cleaning & Paper Goods": "cat_cleaning",
        "Pharmacy & Hygiene": "cat_pharmacy_hygiene",
        "Baby & Kids": "cat_baby_kids",
        "Pet Supplies": "cat_pet_supplies",
        "Tobacco": "cat_tobacco",
        "Lottery & Scratch Cards": "cat_lottery",
        "Promos & Discounts": "cat_promos_discounts",
        "Deposits": "cat_deposits",
        "Other": "cat_other",
    ]

    /// Maps English API group names → AppStrings L() keys for group translations
    private static let groupTranslationKeys: [String: String] = [
        "Fresh Food": "group_fresh_food",
        "Pantry & Staples": "group_pantry_staples",
        "Frozen": "group_frozen",
        "Drinks": "group_drinks",
        "Snacks": "group_snacks",
        "Household": "group_household",
        "Personal Care": "group_personal_care",
        "Other": "group_other",
    ]

    // MARK: - Category Lookup Helpers

    /// Get localized display name for a category
    func displayNameForCategory(_ category: String) -> String {
        let englishName = categoryToDisplayName[category] ?? category
        if let key = Self.categoryTranslationKeys[englishName] {
            return L(key)
        }
        return englishName
    }

    /// Get localized group name for display
    func localizedGroupName(_ group: String) -> String {
        if let key = Self.groupTranslationKeys[group] {
            return L(key)
        }
        return group
    }

    /// Get the group for a category (checks internal name, then display name)
    func groupForCategory(_ category: String) -> String {
        categoryToGroup[category]
            ?? displayNameToGroup[category]
            ?? "Other"
    }

    /// Get Phosphor icon name for a category (looks up by internal name, then display name)
    func iconForCategory(_ category: String) -> String {
        categoryToIcon[category]
            ?? displayNameToIcon[category]
            ?? "tag"
    }

    /// Get Color for a category
    func colorForCategory(_ category: String) -> Color {
        let hex = colorHexForCategory(category)
        return Color(hex: hex) ?? .gray
    }

    /// Get hex color string for a category
    func colorHexForCategory(_ category: String) -> String {
        categoryToColorHex[category]
            ?? displayNameToColorHex[category]
            ?? "#8E8E93"
    }

    // MARK: - Group Lookup Helpers

    func iconForGroup(_ group: String) -> String {
        if let cached = groupLookup[group]?.icon { return cached }
        switch group {
        case "Fresh Food": return "leaf.fill"
        case "Pantry & Staples": return "cabinet.fill"
        case "Frozen": return "snowflake"
        case "Drinks": return "mug.fill"
        case "Snacks": return "popcorn.fill"
        case "Household": return "bubbles.and.sparkles.fill"
        case "Personal Care": return "heart.fill"
        case "Other": return "tag.fill"
        default: return "tag.fill"
        }
    }

    func colorHexForGroup(_ group: String) -> String {
        if let cached = groupLookup[group]?.colorHex { return cached }
        switch group {
        case "Fresh Food": return "#2ECC71"
        case "Pantry & Staples": return "#E67E22"
        case "Frozen": return "#3498DB"
        case "Drinks": return "#E74C3C"
        case "Snacks": return "#F39C12"
        case "Household": return "#8E44AD"
        case "Personal Care": return "#1ABC9C"
        case "Other": return "#95A5A6"
        default: return "#95A5A6"
        }
    }

    func colorForGroup(_ group: String) -> Color {
        Color(hex: colorHexForGroup(group)) ?? .gray
    }

    // MARK: - Fallback Data

    private func setupFallbackData() {
        // Pre-populate group lookups with hardcoded values so the app works before API loads
        let fallbackGroups: [(String, String, String)] = [
            ("Fresh Food", "leaf.fill", "#2ECC71"),
            ("Pantry & Staples", "cabinet.fill", "#E67E22"),
            ("Frozen", "snowflake", "#3498DB"),
            ("Drinks", "mug.fill", "#E74C3C"),
            ("Snacks", "popcorn.fill", "#F39C12"),
            ("Household", "bubbles.and.sparkles.fill", "#8E44AD"),
            ("Personal Care", "heart.fill", "#1ABC9C"),
            ("Other", "tag.fill", "#95A5A6"),
        ]
        for (name, icon, colorHex) in fallbackGroups {
            groupLookup[name] = (icon: icon, colorHex: colorHex)
        }
    }
}
