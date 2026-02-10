//
//  SmartAnchorViewModel.swift
//  Scandalicious
//
//  Smart Anchor logic for per-category budget suggestions.
//  Computes three spend tiers from historical monthly data.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Budget Cycle

enum BudgetCycle: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }

    /// Divisor to convert monthly → weekly
    static let weeksPerMonth: Double = 4.33
}

// MARK: - Smart Anchor Tier

struct SmartAnchorTier: Identifiable {
    let id: String
    let label: String
    let sublabel: String
    let amount: Double
    let color: Color
    let icon: String

    static func saver(amount: Double) -> SmartAnchorTier {
        SmartAnchorTier(
            id: "saver",
            label: "Saver",
            sublabel: "Tighten",
            amount: amount,
            color: Color(red: 0.2, green: 0.8, blue: 0.5),
            icon: "arrow.down.circle.fill"
        )
    }

    static func maintainer(amount: Double) -> SmartAnchorTier {
        SmartAnchorTier(
            id: "maintainer",
            label: "Maintainer",
            sublabel: "Maintain",
            amount: amount,
            color: Color(red: 0.3, green: 0.7, blue: 1.0),
            icon: "equal.circle.fill"
        )
    }

    static func buffer(amount: Double) -> SmartAnchorTier {
        SmartAnchorTier(
            id: "buffer",
            label: "Buffer",
            sublabel: "Relaxed",
            amount: amount,
            color: Color(red: 1.0, green: 0.75, blue: 0.3),
            icon: "arrow.up.circle.fill"
        )
    }
}

// MARK: - Monthly Spending Data Point

struct MonthlySpendDataPoint: Identifiable {
    let id = UUID()
    let monthLabel: String   // e.g. "Nov", "Dec", "Jan"
    let amount: Double
}

// MARK: - Smart Anchor ViewModel

@MainActor
class SmartAnchorViewModel: ObservableObject {
    // MARK: - Inputs

    let categoryName: String
    let monthlyTotals: [Double]          // Last N months of spending for this category
    let monthLabels: [String]            // Matching labels e.g. ["Nov", "Dec", "Jan"]

    // MARK: - Published State

    @Published var selectedCycle: BudgetCycle = .monthly
    @Published var customAmount: String = ""
    @Published var selectedTierId: String?
    @Published var isSaving = false

    // MARK: - Computed: Core Stats

    /// Average monthly spend across available history
    var averageMonthlySpend: Double {
        guard !monthlyTotals.isEmpty else { return 0 }
        return monthlyTotals.reduce(0, +) / Double(monthlyTotals.count)
    }

    /// Whether we have enough data to show suggestions
    var hasHistory: Bool {
        !monthlyTotals.isEmpty && monthlyTotals.contains(where: { $0 > 0 })
    }

    // MARK: - Computed: Tiers

    /// The three smart anchor tiers, adjusted for the selected cycle
    var tiers: [SmartAnchorTier] {
        guard hasHistory else {
            return [
                .saver(amount: 0),
                .maintainer(amount: 0),
                .buffer(amount: 0)
            ]
        }

        let avg = cycleAdjustedAverage
        return [
            .saver(amount: roundToNearestAnchor(avg * 0.90)),
            .maintainer(amount: roundToNearestAnchor(avg * 1.00)),
            .buffer(amount: roundToNearestAnchor(avg * 1.10))
        ]
    }

    /// Average adjusted for the current cycle (weekly or monthly)
    var cycleAdjustedAverage: Double {
        switch selectedCycle {
        case .monthly:
            return averageMonthlySpend
        case .weekly:
            return averageMonthlySpend / BudgetCycle.weeksPerMonth
        }
    }

    /// Formatted average string for display
    var formattedAverage: String {
        String(format: "€%.0f", roundToNearestAnchor(cycleAdjustedAverage))
    }

    /// Data points for the spending chart
    var chartDataPoints: [MonthlySpendDataPoint] {
        guard monthlyTotals.count == monthLabels.count else { return [] }
        return zip(monthLabels, monthlyTotals).map { label, amount in
            MonthlySpendDataPoint(monthLabel: label, amount: amount)
        }
    }

    /// The resolved budget amount (from selected tier or custom input)
    var resolvedAmount: Double? {
        if let customValue = Double(customAmount), customValue > 0 {
            return customValue
        }
        if let tierId = selectedTierId,
           let tier = tiers.first(where: { $0.id == tierId }) {
            return tier.amount
        }
        return nil
    }

    /// Whether the "Set Budget" button should be enabled
    var canSetBudget: Bool {
        resolvedAmount != nil && (resolvedAmount ?? 0) > 0
    }

    // MARK: - Init

    init(
        categoryName: String,
        monthlyTotals: [Double],
        monthLabels: [String]
    ) {
        self.categoryName = categoryName
        self.monthlyTotals = monthlyTotals
        self.monthLabels = monthLabels
    }

    /// Convenience init from a SimpleCategoryAllocation (when per-month data unavailable)
    convenience init(
        categoryName: String,
        averageMonthlySpend: Double,
        basedOnMonths: Int
    ) {
        // Synthesize monthly totals from the average (uniform distribution)
        let months = max(1, basedOnMonths)
        let totals = Array(repeating: averageMonthlySpend, count: months)

        // Generate month labels going backwards from current month
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        let now = Date()
        let labels: [String] = (0..<months).reversed().map { offset in
            let date = Calendar.current.date(byAdding: .month, value: -offset, to: now) ?? now
            return formatter.string(from: date)
        }

        self.init(categoryName: categoryName, monthlyTotals: totals, monthLabels: labels)
    }

    // MARK: - Actions

    /// Select a tier and populate the custom field
    func selectTier(_ tier: SmartAnchorTier) {
        selectedTierId = tier.id
        customAmount = String(format: "%.0f", tier.amount)
    }

    /// Clear tier selection when custom amount is edited manually
    func onCustomAmountEdited() {
        selectedTierId = nil
    }

    // MARK: - Rounding Logic

    /// Round to nearest $5 if >= $10, otherwise round to nearest whole number
    func roundToNearestAnchor(_ value: Double) -> Double {
        guard value > 0 else { return 0 }
        if value < 10 {
            return value.rounded()
        }
        return (value / 5).rounded() * 5
    }
}
