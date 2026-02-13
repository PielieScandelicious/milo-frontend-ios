//
//  BudgetModels.swift
//  Scandalicious
//

import Foundation
import SwiftUI

// MARK: - Budget Model

struct UserBudget: Codable, Identifiable {
    let id: String
    let userId: String
    let monthlyAmount: Double
    let categoryAllocations: [CategoryAllocation]?
    let isSmartBudget: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case isSmartBudget = "is_smart_budget"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(id: String, userId: String, monthlyAmount: Double, categoryAllocations: [CategoryAllocation]? = nil, isSmartBudget: Bool = true, createdAt: String = "", updatedAt: String = "") {
        self.id = id
        self.userId = userId
        self.monthlyAmount = monthlyAmount
        self.categoryAllocations = categoryAllocations
        self.isSmartBudget = isSmartBudget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Category Allocation (Guardrail)

struct CategoryAllocation: Codable, Identifiable {
    let category: String
    let amount: Double

    var id: String { category }

    enum CodingKeys: String, CodingKey {
        case category
        case amount
    }

    init(category: String, amount: Double) {
        self.category = category
        self.amount = amount
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
            return .wellUnderBudget
        case -0.10..<(-0.02):
            return .underBudget
        case -0.02..<0.05:
            return .onTrack
        case 0.05..<0.15:
            return .slightlyOver
        default:
            return .overBudget
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
            return Color(red: 0.2, green: 0.8, blue: 0.5)
        case .underBudget:
            return Color(red: 0.3, green: 0.75, blue: 0.45)
        case .onTrack:
            return Color(red: 0.3, green: 0.7, blue: 1.0)
        case .slightlyOver:
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        case .overBudget:
            return Color(red: 1.0, green: 0.4, blue: 0.4)
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

    func toBudgetProgressItems() -> [BudgetProgressItem] {
        categoryProgress.map { $0.toBudgetProgressItem() }
    }
}

struct CategoryProgressResponse: Codable {
    let categoryId: String
    let name: String
    let limitAmount: Double
    let spentAmount: Double
    let isOverBudget: Bool
    let overBudgetAmount: Double?

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case name
        case limitAmount = "limit_amount"
        case spentAmount = "spent_amount"
        case isOverBudget = "is_over_budget"
        case overBudgetAmount = "over_budget_amount"
    }

    func toCategoryBudgetProgress() -> CategoryBudgetProgress {
        CategoryBudgetProgress(
            category: name,
            budgetAmount: limitAmount,
            currentSpend: spentAmount
        )
    }

    func toBudgetProgressItem() -> BudgetProgressItem {
        BudgetProgressItem(
            categoryId: categoryId,
            name: name,
            limitAmount: limitAmount,
            spentAmount: spentAmount,
            isOverBudget: isOverBudget,
            overBudgetAmount: overBudgetAmount
        )
    }
}

// MARK: - Create/Update Budget Request

struct CreateBudgetRequest: Encodable {
    let monthlyAmount: Double
    let categoryAllocations: [CategoryAllocation]?
    let isSmartBudget: Bool

    enum CodingKeys: String, CodingKey {
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case isSmartBudget = "is_smart_budget"
    }
}

struct UpdateBudgetRequest: Encodable {
    let monthlyAmount: Double?
    let categoryAllocations: [CategoryAllocation]?
    let isSmartBudget: Bool?

    enum CodingKeys: String, CodingKey {
        case monthlyAmount = "monthly_amount"
        case categoryAllocations = "category_allocations"
        case isSmartBudget = "is_smart_budget"
    }
}

// MARK: - Budget Progress Item (for Activity Rings)

struct BudgetProgressItem: Codable, Identifiable {
    let categoryId: String
    let name: String
    let limitAmount: Double
    let spentAmount: Double
    let isOverBudget: Bool
    let overBudgetAmount: Double?

    var id: String { categoryId }

    enum CodingKeys: String, CodingKey {
        case categoryId = "category_id"
        case name
        case limitAmount = "limit_amount"
        case spentAmount = "spent_amount"
        case isOverBudget = "is_over_budget"
        case overBudgetAmount = "over_budget_amount"
    }

    var progressRatio: Double {
        guard limitAmount > 0 else { return 0 }
        return spentAmount / limitAmount
    }

    var clampedProgress: Double {
        min(1.0, progressRatio)
    }

    var remainingAmount: Double {
        max(0, limitAmount - spentAmount)
    }

    var overAmount: Double {
        overBudgetAmount ?? max(0, spentAmount - limitAmount)
    }

    var statusText: String {
        if isOverBudget {
            return String(format: "+€%.0f over", overAmount)
        } else {
            return String(format: "€%.0f left", remainingAmount)
        }
    }

    var compactStatusText: String {
        if isOverBudget {
            return String(format: "+€%.0f", overAmount)
        } else {
            return String(format: "€%.0f", remainingAmount)
        }
    }

    var color: Color {
        name.categoryColor
    }

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
