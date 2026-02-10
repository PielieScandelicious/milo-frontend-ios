//
//  AIBudgetModels.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//  Simplified on 05/02/2026 - Removed AI features
//

import Foundation
import SwiftUI

// MARK: - Simple Budget Suggestion Response

struct SimpleBudgetSuggestionResponse: Codable {
    // Core fields
    let recommendedBudget: RecommendedBudget
    let categoryAllocations: [SimpleCategoryAllocation]

    // Metadata fields
    let basedOnMonths: Int
    let totalSpendAnalyzed: Double

    enum CodingKeys: String, CodingKey {
        case recommendedBudget = "recommended_budget"
        case categoryAllocations = "category_allocations"
        case basedOnMonths = "based_on_months"
        case totalSpendAnalyzed = "total_spend_analyzed"
    }

    // MARK: - Data Collection Phase Detection

    /// Determines the user's data collection phase for UI customization
    var dataCollectionPhase: DataCollectionPhase {
        switch basedOnMonths {
        case 0:
            return .onboarding
        case 1...2:
            return .buildingProfile
        default:
            return .fullyPersonalized
        }
    }

    /// Indicates if this is preliminary data (no actual spending analyzed)
    var isPreliminaryData: Bool {
        totalSpendAnalyzed == 0 || basedOnMonths == 0
    }

    /// Progress towards full personalization (0.0 to 1.0)
    var personalizationProgress: Double {
        min(1.0, Double(basedOnMonths) / 3.0)
    }

    /// User-friendly description of the data basis
    var dataBasisDescription: String {
        switch basedOnMonths {
        case 0:
            return "Suggested starting point"
        case 1:
            return "Based on 1 month of data"
        case 2:
            return "Based on 2 months of data"
        default:
            return "Based on \(basedOnMonths) months of data"
        }
    }

    /// Monthly average spending
    var monthlyAverage: Double {
        basedOnMonths > 0 ? totalSpendAnalyzed / Double(basedOnMonths) : totalSpendAnalyzed
    }
}

struct RecommendedBudget: Codable {
    let amount: Double
    let confidence: String  // "high", "medium", "low"
    let reasoning: String
}

struct SimpleCategoryAllocation: Codable, Identifiable {
    let category: String
    let suggestedAmount: Double
    let percentage: Double

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case suggestedAmount = "suggested_amount"
        case percentage
    }
}

// MARK: - Data Collection Phase

/// Represents the user's data collection phase based on spending history
enum DataCollectionPhase: Equatable {
    case onboarding          // 0 months - no data, show welcome/getting started
    case buildingProfile     // 1-2 months - partial data, building profile
    case fullyPersonalized   // 3+ months - full personalization

    var title: String {
        switch self {
        case .onboarding: return "Getting Started"
        case .buildingProfile: return "Building Your Profile"
        case .fullyPersonalized: return "Your Smart Budget"
        }
    }

    var subtitle: String {
        switch self {
        case .onboarding: return "Scan receipts to get personalized insights"
        case .buildingProfile: return "Keep scanning for better insights!"
        case .fullyPersonalized: return "Based on your spending history"
        }
    }

    var monthsCollected: Int {
        switch self {
        case .onboarding: return 0
        case .buildingProfile: return 1  // Will be overridden by actual value
        case .fullyPersonalized: return 3
        }
    }

    var targetMonths: Int { 3 }

    var isOnboarding: Bool { self == .onboarding }
    var hasPartialData: Bool { self == .buildingProfile }
    var isFullyPersonalized: Bool { self == .fullyPersonalized }
}

// MARK: - Simple Loading State

enum SimpleLoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var data: T? {
        if case .loaded(let data) = self { return data }
        return nil
    }

    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}

// MARK: - Category Monthly Spend (Smart Anchor)

/// Per-category monthly spending data from the backend
struct CategoryMonthlySpendResponse: Codable {
    let categories: [CategoryMonthlySpend]
    let basedOnMonths: Int
    let monthLabels: [String]

    enum CodingKeys: String, CodingKey {
        case categories
        case basedOnMonths = "based_on_months"
        case monthLabels = "month_labels"
    }
}

struct CategoryMonthlySpend: Codable, Identifiable {
    let category: String
    let monthLabels: [String]
    let monthlyTotals: [Double]
    let average: Double

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case monthLabels = "month_labels"
        case monthlyTotals = "monthly_totals"
        case average
    }
}

// MARK: - Legacy Compatibility Aliases

// Keep these aliases for gradual migration
typealias AIBudgetSuggestionResponse = SimpleBudgetSuggestionResponse
typealias AICategoryAllocation = SimpleCategoryAllocation
typealias AILoadingState = SimpleLoadingState

// Legacy extension to provide backward compatibility
extension SimpleBudgetSuggestionResponse {
    /// Backward-compatible access for code expecting rawData.monthlyAverage
    var rawData: SimpleRawData {
        SimpleRawData(totalSpend: totalSpendAnalyzed, basedOnMonths: basedOnMonths)
    }
}

struct SimpleRawData {
    let totalSpend: Double
    let basedOnMonths: Int

    var monthlyAverage: Double {
        basedOnMonths > 0 ? totalSpend / Double(basedOnMonths) : totalSpend
    }
}
