//
//  BudgetInsightsModels.swift
//  Scandalicious
//
//  Budget insights models - deterministic, rule-based insights without AI.
//

import Foundation
import SwiftUI

// MARK: - Belgian Benchmark Comparison

struct BelgianBenchmarkComparison: Codable, Identifiable {
    let category: String
    let userPercentage: Double
    let belgianAveragePercentage: Double
    let differencePercentage: Double
    let comparisonText: String

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case userPercentage = "user_percentage"
        case belgianAveragePercentage = "belgian_average_percentage"
        case differencePercentage = "difference_percentage"
        case comparisonText = "comparison_text"
    }

    /// Whether the user spends more than Belgian average
    var spendsMore: Bool {
        differencePercentage > 2
    }

    /// Whether the user spends less than Belgian average
    var spendsLess: Bool {
        differencePercentage < -2
    }

    /// Color for the comparison indicator
    var indicatorColor: Color {
        if spendsMore {
            return .orange
        } else if spendsLess {
            return .green
        } else {
            return .blue
        }
    }
}

struct BelgianBenchmarksResponse: Codable {
    let comparisons: [BelgianBenchmarkComparison]
    let userTotalAnalyzed: Double
    let dataSource: String

    enum CodingKeys: String, CodingKey {
        case comparisons
        case userTotalAnalyzed = "user_total_analyzed"
        case dataSource = "data_source"
    }
}

// MARK: - Over-Budget Flags

enum OverBudgetSeverity: String, Codable {
    case warning
    case critical

    var color: Color {
        switch self {
        case .warning:
            return .orange
        case .critical:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "xmark.circle.fill"
        }
    }
}

struct OverBudgetFlag: Codable, Identifiable {
    let category: String
    let monthsOver: Int
    let monthsAnalyzed: Int
    let averageOveragePercentage: Double
    let averageOverageAmount: Double
    let severity: OverBudgetSeverity

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case monthsOver = "months_over"
        case monthsAnalyzed = "months_analyzed"
        case averageOveragePercentage = "average_overage_percentage"
        case averageOverageAmount = "average_overage_amount"
        case severity
    }

    /// Summary text like "Over budget 2 of 3 months"
    var summaryText: String {
        "Over budget \(monthsOver) of \(monthsAnalyzed) months"
    }
}

struct OverBudgetFlagsResponse: Codable {
    let flags: [OverBudgetFlag]
    let monthsAnalyzed: Int

    enum CodingKeys: String, CodingKey {
        case flags
        case monthsAnalyzed = "months_analyzed"
    }
}

// MARK: - Quick Wins Calculator

struct QuickWin: Codable, Identifiable {
    let category: String
    let currentMonthlySpend: Double
    let suggestedCutPercentage: Int
    let monthlySavings: Double
    let yearlySavings: Double
    let message: String

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case currentMonthlySpend = "current_monthly_spend"
        case suggestedCutPercentage = "suggested_cut_percentage"
        case monthlySavings = "monthly_savings"
        case yearlySavings = "yearly_savings"
        case message
    }
}

struct QuickWinsResponse: Codable {
    let quickWins: [QuickWin]
    let totalPotentialMonthlySavings: Double
    let totalPotentialYearlySavings: Double

    enum CodingKeys: String, CodingKey {
        case quickWins = "quick_wins"
        case totalPotentialMonthlySavings = "total_potential_monthly_savings"
        case totalPotentialYearlySavings = "total_potential_yearly_savings"
    }
}

// MARK: - Volatility Alerts

enum VolatilityLevel: String, Codable {
    case moderate
    case high
    case veryHigh = "very_high"

    var displayText: String {
        switch self {
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .veryHigh:
            return "Very High"
        }
    }

    var color: Color {
        switch self {
        case .moderate:
            return .yellow
        case .high:
            return .orange
        case .veryHigh:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .moderate:
            return "waveform.path"
        case .high:
            return "waveform.path.badge.plus"
        case .veryHigh:
            return "waveform.badge.exclamationmark"
        }
    }
}

struct VolatilityAlert: Codable, Identifiable {
    let category: String
    let averageMonthlySpend: Double
    let standardDeviation: Double
    let coefficientOfVariation: Double
    let minMonthSpend: Double
    let maxMonthSpend: Double
    let volatilityLevel: VolatilityLevel
    let recommendation: String

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case averageMonthlySpend = "average_monthly_spend"
        case standardDeviation = "standard_deviation"
        case coefficientOfVariation = "coefficient_of_variation"
        case minMonthSpend = "min_month_spend"
        case maxMonthSpend = "max_month_spend"
        case volatilityLevel = "volatility_level"
        case recommendation
    }

    /// Range text like "€45 - €120"
    var rangeText: String {
        String(format: "€%.0f - €%.0f", minMonthSpend, maxMonthSpend)
    }
}

struct VolatilityAlertsResponse: Codable {
    let alerts: [VolatilityAlert]
    let monthsAnalyzed: Int

    enum CodingKeys: String, CodingKey {
        case alerts
        case monthsAnalyzed = "months_analyzed"
    }
}

// MARK: - Rich Progress & Health Score

struct HealthScoreBreakdown: Codable {
    let paceScore: Int      // 0-40 points
    let categoryBalanceScore: Int  // 0-30 points
    let consistencyScore: Int      // 0-30 points

    enum CodingKeys: String, CodingKey {
        case paceScore = "pace_score"
        case categoryBalanceScore = "category_balance_score"
        case consistencyScore = "consistency_score"
    }

    var total: Int {
        min(100, paceScore + categoryBalanceScore + consistencyScore)
    }
}

enum ProjectedStatus: String, Codable {
    case underBudget = "under_budget"
    case onTrack = "on_track"
    case overBudget = "over_budget"

    var displayText: String {
        switch self {
        case .underBudget:
            return "Under Budget"
        case .onTrack:
            return "On Track"
        case .overBudget:
            return "Over Budget"
        }
    }

    var color: Color {
        switch self {
        case .underBudget:
            return .green
        case .onTrack:
            return .blue
        case .overBudget:
            return .red
        }
    }

    var icon: String {
        switch self {
        case .underBudget:
            return "arrow.down.circle.fill"
        case .onTrack:
            return "checkmark.circle.fill"
        case .overBudget:
            return "arrow.up.circle.fill"
        }
    }
}

struct RichProgressResponse: Codable {
    let dailyBudgetRemaining: Double
    let daysRemaining: Int
    let projectedEndOfMonth: Double
    let projectedStatus: ProjectedStatus
    let projectedDifference: Double  // Positive = under budget
    let healthScore: Int
    let healthScoreBreakdown: HealthScoreBreakdown
    let healthScoreLabel: String

    enum CodingKeys: String, CodingKey {
        case dailyBudgetRemaining = "daily_budget_remaining"
        case daysRemaining = "days_remaining"
        case projectedEndOfMonth = "projected_end_of_month"
        case projectedStatus = "projected_status"
        case projectedDifference = "projected_difference"
        case healthScore = "health_score"
        case healthScoreBreakdown = "health_score_breakdown"
        case healthScoreLabel = "health_score_label"
    }

    /// Health score color based on value
    var healthScoreColor: Color {
        if healthScore >= 80 {
            return .green
        } else if healthScore >= 60 {
            return .blue
        } else if healthScore >= 40 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Combined Insights Response

struct BudgetInsightsResponse: Codable {
    let belgianBenchmarks: BelgianBenchmarksResponse?
    let overBudgetFlags: OverBudgetFlagsResponse?
    let quickWins: QuickWinsResponse?
    let volatilityAlerts: VolatilityAlertsResponse?
    let richProgress: RichProgressResponse?
    let generatedAt: String
    let dataFreshness: String

    enum CodingKeys: String, CodingKey {
        case belgianBenchmarks = "belgian_benchmarks"
        case overBudgetFlags = "over_budget_flags"
        case quickWins = "quick_wins"
        case volatilityAlerts = "volatility_alerts"
        case richProgress = "rich_progress"
        case generatedAt = "generated_at"
        case dataFreshness = "data_freshness"
    }

    /// Whether there are any insights to show
    var hasInsights: Bool {
        let hasBenchmarks = (belgianBenchmarks?.comparisons.count ?? 0) > 0
        let hasFlags = (overBudgetFlags?.flags.count ?? 0) > 0
        let hasQuickWins = (quickWins?.quickWins.count ?? 0) > 0
        let hasVolatility = (volatilityAlerts?.alerts.count ?? 0) > 0
        let hasProgress = richProgress != nil

        return hasBenchmarks || hasFlags || hasQuickWins || hasVolatility || hasProgress
    }
}
