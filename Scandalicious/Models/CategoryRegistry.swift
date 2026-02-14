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

    var id: String { name }

    /// Clean display name, falling back to raw name
    var cleanName: String { displayName ?? name }

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case subCategories = "sub_categories"
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
    // Sub-category -> group name
    private var subCategoryToGroup: [String: String] = [:]
    // Sub-category -> mid-level category name (e.g., "Fresh Produce (Fruit & Veg)" -> "Fruits & Vegetables")
    private var subCategoryToCategory: [String: String] = [:]
    // Sub-category -> clean display name (e.g., "Alcohol (Beer, Cider, ...)" -> "Alcohol")
    private var subCategoryToDisplayName: [String: String] = [:]
    // Mid-level category -> group name (e.g., "Fruits & Vegetables" -> "Fresh Food")
    private var categoryToGroup: [String: String] = [:]

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
        subCategoryToGroup.removeAll()
        subCategoryToCategory.removeAll()
        subCategoryToDisplayName.removeAll()
        categoryToGroup.removeAll()

        for group in response.groups {
            groupLookup[group.name] = (icon: group.icon, colorHex: group.colorHex)
            for category in group.categories {
                categoryToGroup[category.name] = group.name
                for subCategory in category.subCategories {
                    subCategoryToGroup[subCategory] = group.name
                    subCategoryToCategory[subCategory] = category.name
                    subCategoryToDisplayName[subCategory] = category.cleanName
                }
            }
        }
    }

    // MARK: - All Sub-Categories

    /// Returns all sub-category names from the loaded hierarchy
    var allSubCategories: [String] {
        guard let hierarchy = hierarchy else { return [] }
        return hierarchy.groups.flatMap { group in
            group.categories.flatMap { $0.subCategories }
        }
    }

    // MARK: - Lookup Helpers

    /// Get clean display name for a sub-category (e.g., "Alcohol (Beer, ...)" → "Alcohol")
    func displayNameForSubCategory(_ subCategory: String) -> String {
        subCategoryToDisplayName[subCategory] ?? subCategory
    }

    func groupForSubCategory(_ subCategory: String) -> String {
        subCategoryToGroup[subCategory] ?? "Other"
    }

    /// Get the mid-level category for a sub-category (e.g., "Phones & Accessories" -> "Electronics")
    func categoryForSubCategory(_ subCategory: String) -> String {
        subCategoryToCategory[subCategory] ?? subCategory
    }

    /// Get the group for a mid-level category (e.g., "Snacks" -> "Snacks & Beverages")
    func groupForCategory(_ category: String) -> String {
        categoryToGroup[category] ?? "Other"
    }

    func iconForSubCategory(_ subCategory: String) -> String {
        let group = groupForSubCategory(subCategory)
        return groupLookup[group]?.icon ?? iconForGroup(group)
    }

    func colorForSubCategory(_ subCategory: String) -> Color {
        let group = groupForSubCategory(subCategory)
        let hex = groupLookup[group]?.colorHex ?? colorHexForGroup(group)
        return Color(hex: hex) ?? .gray
    }

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
        // Pre-populate lookups with hardcoded values so the app works before API loads
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
