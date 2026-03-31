//
//  BudgetTabPreloadCache.swift
//  Scandalicious
//
//  Lightweight singleton cache that bridges between ContentView's loading screen
//  and OverviewView's ViewModels. Populated during app startup, consumed once on
//  first OverviewView appear, then reset.
//

import Foundation

@MainActor
class BudgetTabPreloadCache {
    static let shared = BudgetTabPreloadCache()

    // Receipts cache: period -> [APIReceipt]
    var receiptsByPeriod: [String: [APIReceipt]] = [:]

    // Budget progress (current month only)
    var budgetProgress: BudgetProgressResponse?

    // Budget history
    var budgetHistory: [BudgetHistory] = []

    // Category breakdown (pie chart): period -> PieChartSummaryResponse
    var categoryDataByPeriod: [String: PieChartSummaryResponse] = [:]

    // Category line items: period -> categoryName -> [APITransaction]
    var categoryItemsByPeriod: [String: [String: [APITransaction]]] = [:]

    // Insights prefetch: trends + period metadata
    var trendData: TrendsResponse?
    var insightsPeriodMetadata: [PeriodMetadata] = []

    // Track whether preloading has completed
    var hasPreloaded = false

    private init() {}

    /// Clear all cached data after consumption
    func reset() {
        receiptsByPeriod.removeAll()
        budgetProgress = nil
        budgetHistory = []
        categoryDataByPeriod.removeAll()
        categoryItemsByPeriod.removeAll()
        trendData = nil
        insightsPeriodMetadata = []
        hasPreloaded = false
    }
}
