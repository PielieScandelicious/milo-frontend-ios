//
//  AIBudgetModels.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import Foundation
import SwiftUI

// MARK: - AI Budget Suggestion Response

struct AIBudgetSuggestionResponse: Codable {
    // Core AI analysis fields (flat structure from backend)
    let recommendedBudget: RecommendedBudget
    let categoryAllocations: [AICategoryAllocation]
    let savingsOpportunities: [SavingsOpportunity]
    let spendingInsights: [SpendingInsight]
    let personalizedTips: [String]
    let budgetHealthScore: Int
    let summary: String

    // Raw data fields
    let basedOnMonths: Int
    let totalSpendAnalyzed: Double

    // Cache metadata
    let cachedAt: String?

    enum CodingKeys: String, CodingKey {
        case recommendedBudget = "recommended_budget"
        case categoryAllocations = "category_allocations"
        case savingsOpportunities = "savings_opportunities"
        case spendingInsights = "spending_insights"
        case personalizedTips = "personalized_tips"
        case budgetHealthScore = "budget_health_score"
        case summary
        case basedOnMonths = "based_on_months"
        case totalSpendAnalyzed = "total_spend_analyzed"
        case cachedAt = "cached_at"
    }

    // MARK: - Backward Compatibility

    /// Provides backward-compatible access via aiAnalysis property
    var aiAnalysis: AIBudgetAnalysis {
        AIBudgetAnalysis(
            recommendedBudget: recommendedBudget,
            categoryAllocations: categoryAllocations,
            savingsOpportunities: savingsOpportunities,
            spendingInsights: spendingInsights,
            personalizedTips: personalizedTips,
            budgetHealthScore: budgetHealthScore,
            summary: summary
        )
    }

    /// Provides backward-compatible access via rawData property
    var rawData: AIRawData {
        AIRawData(
            totalSpend: totalSpendAnalyzed,
            basedOnMonths: basedOnMonths
        )
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
}

/// Wrapper for backward compatibility with existing code
struct AIBudgetAnalysis {
    let recommendedBudget: RecommendedBudget
    let categoryAllocations: [AICategoryAllocation]
    let savingsOpportunities: [SavingsOpportunity]
    let spendingInsights: [SpendingInsight]
    let personalizedTips: [String]
    let budgetHealthScore: Int
    let summary: String
}

struct RecommendedBudget: Codable {
    let amount: Double
    let confidence: String  // "high", "medium", "low"
    let reasoning: String
}

struct AICategoryAllocation: Codable, Identifiable {
    let category: String
    let suggestedAmount: Double
    let percentage: Double
    let insight: String
    let savingsPotential: String  // "high", "medium", "low", "none"

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case suggestedAmount = "suggested_amount"
        case percentage
        case insight
        case savingsPotential = "savings_potential"
    }

    var savingsPotentialColor: Color {
        switch savingsPotential {
        case "high": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "medium": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "low": return Color(red: 0.3, green: 0.7, blue: 1.0)
        default: return Color.white.opacity(0.5)
        }
    }
}

struct SavingsOpportunity: Codable, Identifiable {
    let title: String
    let description: String
    let potentialSavings: Double
    let difficulty: String  // "easy", "medium", "hard"

    var id: String { title }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case potentialSavings = "potential_savings"
        case difficulty
    }

    var difficultyColor: Color {
        switch difficulty {
        case "easy": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "medium": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "hard": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return Color.white.opacity(0.5)
        }
    }

    var difficultyIcon: String {
        switch difficulty {
        case "easy": return "leaf.fill"
        case "medium": return "flame.fill"
        case "hard": return "bolt.fill"
        default: return "questionmark"
        }
    }
}

struct SpendingInsight: Codable, Identifiable {
    let type: String  // "pattern", "trend", "anomaly", "positive"
    let title: String
    let description: String
    let recommendation: String

    var id: String { title }

    var typeIcon: String {
        switch type {
        case "pattern": return "chart.line.uptrend.xyaxis"
        case "trend": return "arrow.up.right"
        case "anomaly": return "exclamationmark.triangle.fill"
        case "positive": return "star.fill"
        default: return "lightbulb.fill"
        }
    }

    var typeColor: Color {
        switch type {
        case "pattern": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "trend": return Color(red: 0.55, green: 0.35, blue: 0.95)
        case "anomaly": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "positive": return Color(red: 0.3, green: 0.8, blue: 0.5)
        default: return Color.white.opacity(0.7)
        }
    }
}

/// Simplified raw data wrapper for backward compatibility
struct AIRawData {
    let totalSpend: Double
    let basedOnMonths: Int

    // Computed properties for convenience
    var monthlyAverage: Double {
        basedOnMonths > 0 ? totalSpend / Double(basedOnMonths) : totalSpend
    }
}

// MARK: - AI Check-In Response

struct AICheckInResponse: Codable {
    let greeting: String
    let statusSummary: CheckInStatusSummary
    let dailyBudgetRemaining: Double
    let projectedEndOfMonth: ProjectedEndOfMonth
    let focusAreas: [FocusArea]
    let weeklyTip: String
    let motivation: String

    enum CodingKeys: String, CodingKey {
        case greeting
        case statusSummary = "status_summary"
        case dailyBudgetRemaining = "daily_budget_remaining"
        case projectedEndOfMonth = "projected_end_of_month"
        case focusAreas = "focus_areas"
        case weeklyTip = "weekly_tip"
        case motivation
    }
}

struct CheckInStatusSummary: Codable {
    let emoji: String
    let headline: String
    let detail: String
}

struct ProjectedEndOfMonth: Codable {
    let amount: Double
    let status: String  // "under_budget", "on_track", "over_budget"
    let message: String

    var statusColor: Color {
        switch status {
        case "under_budget": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "on_track": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "over_budget": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return Color.white.opacity(0.5)
        }
    }
}

struct FocusArea: Codable, Identifiable {
    let category: String
    let status: String  // "good", "warning", "critical"
    let message: String

    var id: String { category }

    var statusColor: Color {
        switch status {
        case "good": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "warning": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "critical": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return Color.white.opacity(0.5)
        }
    }

    var statusIcon: String {
        switch status {
        case "good": return "checkmark.circle.fill"
        case "warning": return "exclamationmark.circle.fill"
        case "critical": return "exclamationmark.triangle.fill"
        default: return "questionmark.circle"
        }
    }
}

// MARK: - AI Receipt Analysis Response

struct AIReceiptAnalysisResponse: Codable {
    let impactSummary: String
    let emoji: String
    let status: String  // "great", "fine", "caution", "warning"
    let notableItems: [NotableItem]
    let quickTip: String?

    enum CodingKeys: String, CodingKey {
        case impactSummary = "impact_summary"
        case emoji
        case status
        case notableItems = "notable_items"
        case quickTip = "quick_tip"
    }

    var statusColor: Color {
        switch status {
        case "great": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "fine": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "caution": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "warning": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return Color.white.opacity(0.5)
        }
    }
}

struct NotableItem: Codable, Identifiable {
    let item: String
    let observation: String

    var id: String { item }
}

// MARK: - AI Monthly Report Response

struct AIMonthlyReportResponse: Codable {
    let headline: String
    let grade: String  // "A+", "A", "B", "C", "D", "F"
    let score: Int
    let wins: [String]
    let challenges: [String]
    let categoryGrades: [CategoryGrade]
    let trends: [BudgetTrend]
    let nextMonthFocus: NextMonthFocus
    let funStats: [String]
    let month: String
    let totalSpent: Double
    let budgetAmount: Double
    let receiptCount: Int

    enum CodingKeys: String, CodingKey {
        case headline
        case grade
        case score
        case wins
        case challenges
        case categoryGrades = "category_grades"
        case trends
        case nextMonthFocus = "next_month_focus"
        case funStats = "fun_stats"
        case month
        case totalSpent = "total_spent"
        case budgetAmount = "budget_amount"
        case receiptCount = "receipt_count"
    }

    var gradeColor: Color {
        switch grade {
        case "A+", "A": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "B": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "C": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "D", "F": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return Color.white.opacity(0.5)
        }
    }
}

struct CategoryGrade: Codable, Identifiable {
    let category: String
    let grade: String
    let spent: Double
    let budget: Double?  // Can be null if no category budget was set
    let comment: String

    var id: String { category }

    var gradeColor: Color {
        switch grade {
        case "A+", "A": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "B": return Color(red: 0.3, green: 0.7, blue: 1.0)
        case "C": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "D", "F": return Color(red: 1.0, green: 0.4, blue: 0.4)
        default: return Color.white.opacity(0.5)
        }
    }
}

struct BudgetTrend: Codable, Identifiable {
    let type: String  // "improving", "declining", "stable"
    let area: String
    let detail: String

    var id: String { area }

    var trendIcon: String {
        switch type {
        case "improving": return "arrow.up.right.circle.fill"
        case "declining": return "arrow.down.right.circle.fill"
        case "stable": return "equal.circle.fill"
        default: return "questionmark.circle"
        }
    }

    var trendColor: Color {
        switch type {
        case "improving": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "declining": return Color(red: 1.0, green: 0.4, blue: 0.4)
        case "stable": return Color(red: 0.3, green: 0.7, blue: 1.0)
        default: return Color.white.opacity(0.5)
        }
    }
}

struct NextMonthFocus: Codable {
    let primaryGoal: String
    let suggestedBudgetAdjustment: Double?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case primaryGoal = "primary_goal"
        case suggestedBudgetAdjustment = "suggested_budget_adjustment"
        case reason
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

// MARK: - AI Loading State

enum AILoadingState<T> {
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
