//
//  BudgetModels.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import Foundation
import SwiftUI

// MARK: - Budget Model

struct UserBudget: Codable, Identifiable {
    let id: String
    let userId: String
    let monthlyAmount: Double
    let categoryAllocations: [CategoryAllocation]?
    let notificationsEnabled: Bool
    let alertThresholds: [Double]  // e.g., [0.5, 0.75, 0.9]
    let isSmartBudget: Bool  // If true, automatically rolls over to next month
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case notificationsEnabled = "notifications_enabled"
        case alertThresholds = "alert_thresholds"
        case isSmartBudget = "is_smart_budget"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String, userId: String, monthlyAmount: Double, categoryAllocations: [CategoryAllocation]? = nil, notificationsEnabled: Bool = true, alertThresholds: [Double] = [0.5, 0.75, 0.9], isSmartBudget: Bool = true, createdAt: String = "", updatedAt: String = "") {
        self.id = id
        self.userId = userId
        self.monthlyAmount = monthlyAmount
        self.categoryAllocations = categoryAllocations
        self.notificationsEnabled = notificationsEnabled
        self.alertThresholds = alertThresholds
        self.isSmartBudget = isSmartBudget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Category Allocation

struct CategoryAllocation: Codable, Identifiable {
    let category: String  // Category display name
    let amount: Double
    let isLocked: Bool    // If true, user manually set this; if false, auto-calculated

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case amount
        case isLocked = "is_locked"
    }

    init(category: String, amount: Double, isLocked: Bool = false) {
        self.category = category
        self.amount = amount
        self.isLocked = isLocked
    }
}

// MARK: - Budget Progress (Computed from spending data)

struct BudgetProgress {
    let budget: UserBudget
    let currentSpend: Double
    let daysElapsed: Int
    let daysInMonth: Int
    let categoryProgress: [CategoryBudgetProgress]

    var remainingBudget: Double {
        max(0, budget.monthlyAmount - currentSpend)
    }

    var spendRatio: Double {
        guard budget.monthlyAmount > 0 else { return 0 }
        return currentSpend / budget.monthlyAmount
    }

    var expectedSpendRatio: Double {
        guard daysInMonth > 0 else { return 0 }
        return Double(daysElapsed) / Double(daysInMonth)
    }

    var daysRemaining: Int {
        max(0, daysInMonth - daysElapsed)
    }

    var dailyBudgetRemaining: Double {
        guard daysRemaining > 0 else { return 0 }
        return remainingBudget / Double(daysRemaining)
    }

    var projectedEndOfMonth: Double {
        guard daysElapsed > 0 else { return currentSpend }
        let dailyRate = currentSpend / Double(daysElapsed)
        return dailyRate * Double(daysInMonth)
    }

    var projectedOverUnder: Double {
        projectedEndOfMonth - budget.monthlyAmount
    }

    var paceStatus: PaceStatus {
        let variance = spendRatio - expectedSpendRatio

        switch variance {
        case ..<(-0.10):
            return .wellUnderBudget  // >10% under pace
        case -0.10..<(-0.02):
            return .underBudget      // 2-10% under pace
        case -0.02..<0.05:
            return .onTrack          // Within -2% to +5%
        case 0.05..<0.15:
            return .slightlyOver     // 5-15% over pace
        default:
            return .overBudget       // >15% over pace
        }
    }

    init(budget: UserBudget, currentSpend: Double, daysElapsed: Int, daysInMonth: Int, categoryProgress: [CategoryBudgetProgress] = []) {
        self.budget = budget
        self.currentSpend = currentSpend
        self.daysElapsed = daysElapsed
        self.daysInMonth = daysInMonth
        self.categoryProgress = categoryProgress
    }
}

// MARK: - Category Budget Progress

struct CategoryBudgetProgress: Identifiable {
    let category: String
    let budgetAmount: Double
    let currentSpend: Double
    let isLocked: Bool

    var id: String { category }

    var remainingAmount: Double {
        max(0, budgetAmount - currentSpend)
    }

    var spendRatio: Double {
        guard budgetAmount > 0 else { return 0 }
        return currentSpend / budgetAmount
    }

    var isOverBudget: Bool {
        currentSpend > budgetAmount
    }

    var overAmount: Double {
        max(0, currentSpend - budgetAmount)
    }

    var icon: String {
        category.categoryIcon
    }
}

// MARK: - Pace Status

enum PaceStatus: String, CaseIterable {
    case wellUnderBudget
    case underBudget
    case onTrack
    case slightlyOver
    case overBudget

    var displayText: String {
        switch self {
        case .wellUnderBudget: return "Great pace!"
        case .underBudget: return "Under budget"
        case .onTrack: return "On track"
        case .slightlyOver: return "Slightly over"
        case .overBudget: return "Over budget"
        }
    }

    var icon: String {
        switch self {
        case .wellUnderBudget: return "arrow.down.circle.fill"
        case .underBudget: return "checkmark.circle.fill"
        case .onTrack: return "equal.circle.fill"
        case .slightlyOver: return "exclamationmark.circle.fill"
        case .overBudget: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .wellUnderBudget:
            return Color(red: 0.2, green: 0.8, blue: 0.5)   // Bright green
        case .underBudget:
            return Color(red: 0.3, green: 0.75, blue: 0.45) // Green
        case .onTrack:
            return Color(red: 0.3, green: 0.7, blue: 1.0)   // Blue
        case .slightlyOver:
            return Color(red: 1.0, green: 0.75, blue: 0.3)  // Amber/Yellow
        case .overBudget:
            return Color(red: 1.0, green: 0.4, blue: 0.4)   // Red
        }
    }

    var ringGradient: LinearGradient {
        switch self {
        case .wellUnderBudget, .underBudget:
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.7, blue: 0.4), Color(red: 0.3, green: 0.85, blue: 0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .onTrack:
            return LinearGradient(
                colors: [Color(red: 0.25, green: 0.6, blue: 1.0), Color(red: 0.4, green: 0.8, blue: 1.0)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .slightlyOver:
            return LinearGradient(
                colors: [Color(red: 1.0, green: 0.65, blue: 0.2), Color(red: 1.0, green: 0.85, blue: 0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .overBudget:
            return LinearGradient(
                colors: [Color(red: 0.9, green: 0.3, blue: 0.3), Color(red: 1.0, green: 0.5, blue: 0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Budget Suggestion Response

struct BudgetSuggestionResponse: Codable, Equatable {
    let suggestedAmount: Double
    let basedOnMonths: Int
    let averageMonthlySpend: Double
    let categoryBreakdown: [CategorySuggestion]
    let savingsOptions: [SavingsOption]

    enum CodingKeys: String, CodingKey {
        case suggestedAmount = "suggested_amount"
        case basedOnMonths = "based_on_months"
        case averageMonthlySpend = "average_monthly_spend"
        case categoryBreakdown = "category_breakdown"
        case savingsOptions = "savings_options"
    }
}

struct CategorySuggestion: Codable, Identifiable, Equatable {
    let category: String
    let averageSpend: Double
    let suggestedBudget: Double
    let percentage: Double

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case averageSpend = "average_spend"
        case suggestedBudget = "suggested_budget"
        case percentage
    }
}

struct SavingsOption: Codable, Identifiable, Equatable {
    let label: String
    let amount: Double
    let savingsPercentage: Double

    var id: String { label }

    enum CodingKeys: String, CodingKey {
        case label
        case amount
        case savingsPercentage = "savings_percentage"
    }
}

// MARK: - Budget Progress Response (from backend)

struct BudgetProgressResponse: Codable {
    let budget: UserBudget
    let currentSpend: Double
    let daysElapsed: Int
    let daysInMonth: Int
    let categoryProgress: [CategoryProgressResponse]

    enum CodingKeys: String, CodingKey {
        case budget
        case currentSpend = "current_spend"
        case daysElapsed = "days_elapsed"
        case daysInMonth = "days_in_month"
        case categoryProgress = "category_progress"
    }

    func toBudgetProgress() -> BudgetProgress {
        BudgetProgress(
            budget: budget,
            currentSpend: currentSpend,
            daysElapsed: daysElapsed,
            daysInMonth: daysInMonth,
            categoryProgress: categoryProgress.map { $0.toCategoryBudgetProgress() }
        )
    }

    /// Convert all category progress items to BudgetProgressItem array for Activity Rings
    func toBudgetProgressItems() -> [BudgetProgressItem] {
        categoryProgress.map { $0.toBudgetProgressItem() }
    }
}

struct CategoryProgressResponse: Codable {
    // Legacy fields
    let category: String?
    let budgetAmount: Double?
    let currentSpend: Double?

    // New fields from updated backend
    let categoryId: String?
    let name: String?
    let limitAmount: Double?
    let spentAmount: Double?
    let isOverBudget: Bool?
    let overBudgetAmount: Double?
    let isLocked: Bool

    enum CodingKeys: String, CodingKey {
        case category
        case budgetAmount = "budget_amount"
        case currentSpend = "current_spend"
        case categoryId = "category_id"
        case name
        case limitAmount = "limit_amount"
        case spentAmount = "spent_amount"
        case isOverBudget = "is_over_budget"
        case overBudgetAmount = "over_budget_amount"
        case isLocked = "is_locked"
    }

    // MARK: - Computed Properties for Compatibility

    /// Display name (prefers new `name` field, falls back to `category`), normalized from ALL_CAPS enum style
    var displayName: String {
        (name ?? category ?? "Unknown").normalizedCategoryName
    }

    /// Budget limit amount (prefers new field, falls back to legacy)
    var budget: Double {
        limitAmount ?? budgetAmount ?? 0
    }

    /// Spent amount (prefers new field, falls back to legacy)
    var spent: Double {
        spentAmount ?? currentSpend ?? 0
    }

    /// Whether the category is over budget
    var overBudget: Bool {
        isOverBudget ?? (spent > budget)
    }

    func toCategoryBudgetProgress() -> CategoryBudgetProgress {
        CategoryBudgetProgress(
            category: displayName,
            budgetAmount: budget,
            currentSpend: spent,
            isLocked: isLocked
        )
    }

    /// Convert to BudgetProgressItem for Activity Rings
    func toBudgetProgressItem() -> BudgetProgressItem {
        BudgetProgressItem(
            categoryId: categoryId ?? category?.uppercased().replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "&", with: "") ?? "OTHER",
            name: displayName,
            limitAmount: budget,
            spentAmount: spent,
            isOverBudget: overBudget,
            overBudgetAmount: overBudgetAmount,
            isLocked: isLocked
        )
    }
}

// MARK: - Create/Update Budget Request

struct CreateBudgetRequest: Encodable {
    let monthlyAmount: Double
    let categoryAllocations: [CategoryAllocation]?
    let notificationsEnabled: Bool
    let alertThresholds: [Double]
    let isSmartBudget: Bool

    enum CodingKeys: String, CodingKey {
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case notificationsEnabled = "notifications_enabled"
        case alertThresholds = "alert_thresholds"
        case isSmartBudget = "is_smart_budget"
    }
}

struct UpdateBudgetRequest: Encodable {
    let monthlyAmount: Double?
    let categoryAllocations: [CategoryAllocation]?
    let notificationsEnabled: Bool?
    let alertThresholds: [Double]?
    let isSmartBudget: Bool?

    enum CodingKeys: String, CodingKey {
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case notificationsEnabled = "notifications_enabled"
        case alertThresholds = "alert_thresholds"
        case isSmartBudget = "is_smart_budget"
    }
}

// MARK: - Budget Progress Item (for Activity Rings)

/// Represents budget progress for a single category
/// Matches GET /api/v2/budgets/progress response per-category structure
struct BudgetProgressItem: Codable, Identifiable {
    let categoryId: String       // Enum name e.g., "MEAT_FISH"
    let name: String             // Display name e.g., "Meat & Fish"
    let limitAmount: Double      // Budget allocation
    let spentAmount: Double      // Actual spending
    let isOverBudget: Bool       // True if over budget
    let overBudgetAmount: Double? // Amount over budget (null if not over)
    let isLocked: Bool           // Whether allocation is locked

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case name
        case limitAmount = "limit_amount"
        case spentAmount = "spent_amount"
        case isOverBudget = "is_over_budget"
        case overBudgetAmount = "over_budget_amount"
        case isLocked = "is_locked"
    }

    // MARK: - Computed Properties

    /// Progress ratio (0.0 to 1.0+, can exceed 1.0 when over budget)
    var progressRatio: Double {
        guard limitAmount > 0 else { return 0 }
        return spentAmount / limitAmount
    }

    /// Clamped progress for visual display (0.0 to 1.0)
    var clampedProgress: Double {
        min(1.0, progressRatio)
    }

    /// Amount remaining in budget
    var remainingAmount: Double {
        max(0, limitAmount - spentAmount)
    }

    /// Amount over budget (positive when over)
    var overAmount: Double {
        overBudgetAmount ?? max(0, spentAmount - limitAmount)
    }

    /// Status text for display (e.g., "€20 left" or "+€15 over")
    var statusText: String {
        if isOverBudget {
            return String(format: "+€%.0f over", overAmount)
        } else {
            return String(format: "€%.0f left", remainingAmount)
        }
    }

    /// Compact status text for small displays
    var compactStatusText: String {
        if isOverBudget {
            return String(format: "+€%.0f", overAmount)
        } else {
            return String(format: "€%.0f", remainingAmount)
        }
    }

    /// Color based on category name
    var color: Color {
        name.categoryColor
    }

    /// SF Symbol icon for this category (uses dynamic keyword-based matching)
    var icon: String {
        name.categoryIcon
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

// MARK: - Last Month Summary

struct LastMonthSummary {
    let month: String              // "January 2026"
    let totalSpent: Double
    let budgetAmount: Double
    let grade: String              // "A", "B", etc.
    let score: Int                 // 0-100
    let headline: String
    let wasUnderBudget: Bool
    let difference: Double         // Amount under/over

    var gradeColor: Color {
        switch grade.uppercased() {
        case "A+", "A": return Color(red: 0.2, green: 0.8, blue: 0.5)
        case "A-", "B+", "B": return Color(red: 0.3, green: 0.75, blue: 0.45)
        case "B-", "C+", "C": return Color(red: 1.0, green: 0.75, blue: 0.3)
        case "C-", "D+", "D": return Color(red: 1.0, green: 0.55, blue: 0.3)
        default: return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    var statusText: String {
        if wasUnderBudget {
            return String(format: "€%.0f under budget", difference)
        } else {
            return String(format: "€%.0f over budget", difference)
        }
    }
}

// MARK: - Budget History

struct BudgetHistory: Codable, Identifiable {
    let id: String
    let userId: String
    let monthlyAmount: Double
    let categoryAllocations: [CategoryAllocation]?
    let month: String  // "2026-01" format
    let wasSmartBudget: Bool
    let wasDeleted: Bool
    let createdAt: String

    var id_computed: String { id }

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case month
        case wasSmartBudget = "was_smart_budget"
        case wasDeleted = "was_deleted"
        case createdAt = "created_at"
    }

    /// Display format for month (e.g., "January 2026")
    var displayMonth: String {
        let components = month.split(separator: "-")
        guard components.count == 2,
              let year = components.last,
              let monthNum = Int(components.first ?? "0"),
              monthNum >= 1 && monthNum <= 12 else {
            return month
        }

        let monthNames = ["January", "February", "March", "April", "May", "June",
                         "July", "August", "September", "October", "November", "December"]
        return "\(monthNames[monthNum - 1]) \(year)"
    }
}

struct BudgetHistoryResponse: Codable {
    let budgetHistory: [BudgetHistory]

    enum CodingKeys: String, CodingKey {
        case budgetHistory = "budget_history"
    }
}

// MARK: - Budget Notification

extension Notification.Name {
    static let budgetUpdated = Notification.Name("budgetUpdated")
    static let budgetDeleted = Notification.Name("budgetDeleted")
    static let budgetCategoryAllocationsUpdated = Notification.Name("budgetCategoryAllocationsUpdated")
}
