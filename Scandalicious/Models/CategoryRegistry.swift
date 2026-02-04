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
    let subCategories: [String]

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case subCategories = "sub_categories"
    }
}

// MARK: - Used Categories Response Models

struct UsedCategoryResponse: Codable {
    let categories: [UsedCategory]
}

struct UsedCategory: Codable, Identifiable {
    let subCategory: String
    let category: String
    let group: String
    let totalSpent: Double
    let transactionCount: Int
    let colorHex: String
    let icon: String
    let categoryId: String

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case subCategory = "sub_category"
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

        for group in response.groups {
            groupLookup[group.name] = (icon: group.icon, colorHex: group.colorHex)
            for category in group.categories {
                for subCategory in category.subCategories {
                    subCategoryToGroup[subCategory] = group.name
                }
            }
        }
    }

    // MARK: - Lookup Helpers

    func groupForSubCategory(_ subCategory: String) -> String {
        subCategoryToGroup[subCategory] ?? "Miscellaneous"
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
        case "Housing & Utilities": return "house.fill"
        case "Food & Dining": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Health & Wellness": return "heart.fill"
        case "Shopping & Personal Care": return "bag.fill"
        case "Entertainment & Leisure": return "film.fill"
        case "Financial & Legal": return "banknote.fill"
        case "Family & Education": return "book.fill"
        case "Travel & Vacation": return "airplane"
        case "Gifts & Donations": return "gift.fill"
        case "Miscellaneous": return "square.grid.2x2.fill"
        default: return "square.grid.2x2.fill"
        }
    }

    func colorHexForGroup(_ group: String) -> String {
        if let cached = groupLookup[group]?.colorHex { return cached }
        switch group {
        case "Housing & Utilities": return "#8E44AD"
        case "Food & Dining": return "#2ECC71"
        case "Transportation": return "#3498DB"
        case "Health & Wellness": return "#E74C3C"
        case "Shopping & Personal Care": return "#E91E8C"
        case "Entertainment & Leisure": return "#F1C40F"
        case "Financial & Legal": return "#7F8C8D"
        case "Family & Education": return "#E67E22"
        case "Travel & Vacation": return "#5DADE2"
        case "Gifts & Donations": return "#F06292"
        case "Miscellaneous": return "#95A5A6"
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
            ("Housing & Utilities", "house.fill", "#8E44AD"),
            ("Food & Dining", "fork.knife", "#2ECC71"),
            ("Transportation", "car.fill", "#3498DB"),
            ("Health & Wellness", "heart.fill", "#E74C3C"),
            ("Shopping & Personal Care", "bag.fill", "#E91E8C"),
            ("Entertainment & Leisure", "film.fill", "#F1C40F"),
            ("Financial & Legal", "banknote.fill", "#7F8C8D"),
            ("Family & Education", "book.fill", "#E67E22"),
            ("Travel & Vacation", "airplane", "#5DADE2"),
            ("Gifts & Donations", "gift.fill", "#F06292"),
            ("Miscellaneous", "square.grid.2x2.fill", "#95A5A6"),
        ]
        for (name, icon, colorHex) in fallbackGroups {
            groupLookup[name] = (icon: icon, colorHex: colorHex)
        }
    }
}
