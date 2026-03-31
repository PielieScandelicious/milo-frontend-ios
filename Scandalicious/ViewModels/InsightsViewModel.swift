//
//  InsightsViewModel.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Loading State

enum SectionLoadingState: Equatable {
    case idle
    case loading
    case loaded
    case error(String)
}

// MARK: - Spending Change Model

struct SpendingChange: Identifiable {
    let categoryName: String
    let icon: String
    let color: Color
    let currentAmount: Double
    let previousAmount: Double

    var id: String { categoryName }

    var absoluteChange: Double { currentAmount - previousAmount }
    var percentageChange: Double {
        guard previousAmount > 0 else { return currentAmount > 0 ? 100 : 0 }
        return ((currentAmount - previousAmount) / previousAmount) * 100
    }
    var isIncrease: Bool { absoluteChange > 0 }
}

// MARK: - Insights ViewModel

@MainActor
class InsightsViewModel: ObservableObject {

    // MARK: - Period Selection
    @Published var selectedTrendIndex: Int? = nil
    @Published var trendData: TrendsResponse?
    @Published var periodMetadata: [PeriodMetadata] = []

    // MARK: - Section Data
    @Published var pieChartSummary: PieChartSummaryResponse?
    @Published var previousPieChartSummary: PieChartSummaryResponse?
    @Published var storeBreakdowns: [StoreBreakdown] = []

    // MARK: - Loading States
    @Published var trendState: SectionLoadingState = .idle
    @Published var summaryState: SectionLoadingState = .idle
    @Published var categoryState: SectionLoadingState = .idle
    @Published var storeState: SectionLoadingState = .idle

    // MARK: - Category Expansion
    @Published var expandedCategoryId: String?
    @Published var categoryTransactions: [String: [APITransaction]] = [:]


    // MARK: - Services
    private let apiService = AnalyticsAPIService.shared
    private var dataManager: StoreDataManager?

    // MARK: - Caches
    private var pieChartCache: [String: PieChartSummaryResponse] = [:]
    private var storeBreakdownCache: [String: [StoreBreakdown]] = [:]

    // MARK: - Computed Properties

    var selectedPeriod: TrendPeriod? {
        guard let trendData, let index = selectedTrendIndex,
              index >= 0, index < trendData.trends.count else { return nil }
        return trendData.trends[index]
    }

    var previousPeriod: TrendPeriod? {
        guard let trendData, let index = selectedTrendIndex,
              index > 0 else { return nil }
        return trendData.trends[index - 1]
    }

    var selectedPeriodLabel: String {
        selectedPeriod?.period ?? ""
    }

    var totalSpend: Double {
        pieChartSummary?.totalSpent ?? selectedPeriod?.totalSpend ?? 0
    }

    var previousTotalSpend: Double? {
        previousPieChartSummary?.totalSpent ?? previousPeriod?.totalSpend
    }

    var spendingDelta: Double? {
        guard let previous = previousTotalSpend, previous > 0 else { return nil }
        return ((totalSpend - previous) / previous) * 100
    }

    var receiptCount: Int {
        let periodName = selectedPeriod?.period ?? ""
        return periodMetadata.first(where: { $0.period == periodName })?.receiptCount ?? 0
    }

    var averageBasketSize: Double? {
        guard receiptCount > 0 else { return nil }
        return totalSpend / Double(receiptCount)
    }

    var topChanges: [SpendingChange] {
        guard let current = pieChartSummary?.groups,
              let previous = previousPieChartSummary?.groups else { return [] }

        let previousDict = Dictionary(uniqueKeysWithValues: previous.map { ($0.groupName, $0.totalSpent) })

        var changes: [SpendingChange] = []
        for group in current {
            let prev = previousDict[group.groupName] ?? 0
            let delta = group.totalSpent - prev
            guard abs(delta) > 1 else { continue } // Skip tiny changes
            changes.append(SpendingChange(
                categoryName: group.groupName,
                icon: group.groupIcon,
                color: group.color,
                currentAmount: group.totalSpent,
                previousAmount: prev
            ))
        }

        return changes
            .sorted { abs($0.absoluteChange) > abs($1.absoluteChange) }
            .prefix(3)
            .map { $0 }
    }

    var allChanges: [SpendingChange] {
        guard let current = pieChartSummary?.groups,
              let previous = previousPieChartSummary?.groups else { return [] }

        let previousDict = Dictionary(uniqueKeysWithValues: previous.map { ($0.groupName, $0.totalSpent) })

        var changes: [SpendingChange] = []
        for group in current {
            let prev = previousDict[group.groupName] ?? 0
            let delta = group.totalSpent - prev
            guard abs(delta) > 1 else { continue }
            changes.append(SpendingChange(
                categoryName: group.groupName,
                icon: group.groupIcon,
                color: group.color,
                currentAmount: group.totalSpent,
                previousAmount: prev
            ))
        }

        return changes.sorted { abs($0.absoluteChange) > abs($1.absoluteChange) }
    }

    var categoryChartData: [ChartData] {
        pieChartSummary?.groups.map { $0.toChartData } ?? []
    }

    var storeChartData: [ChartData] {
        let stores = pieChartSummary?.stores ?? []
        return stores.map { store in
            let brandColor = GroceryStore.fromCanonical(store.storeName)?.accentColor ?? store.color
            return ChartData(
                value: store.totalSpent,
                color: brandColor,
                iconName: "bag.fill",
                label: store.storeName
            )
        }
    }

    /// Resolve brand color for a store name
    func storeAccentColor(for storeName: String) -> Color {
        GroceryStore.fromCanonical(storeName)?.accentColor
            ?? GroceryStore.allCases.first {
                $0.rawValue.caseInsensitiveCompare(storeName) == .orderedSame
            }?.accentColor
            ?? Color(red: 0.4, green: 0.5, blue: 0.7)
    }

    // MARK: - Setup

    func configure(dataManager: StoreDataManager) {
        self.dataManager = dataManager
    }

    // MARK: - Data Loading

    func loadInitialData() async {
        guard trendState == .idle else { return }

        // Consume prefetched data from app startup cache
        let cache = BudgetTabPreloadCache.shared
        if cache.hasPreloaded {
            // Seed pie chart cache from prefetched category data
            let fmt = DateFormatter()
            fmt.dateFormat = "MMMM yyyy"
            fmt.locale = Locale(identifier: "en_US")
            for (periodString, response) in cache.categoryDataByPeriod {
                if let date = fmt.date(from: periodString) {
                    let m = Calendar.current.component(.month, from: date)
                    let y = Calendar.current.component(.year, from: date)
                    pieChartCache["\(m)-\(y)"] = response
                }
            }

            // Use prefetched trends
            if let trends = cache.trendData {
                trendData = trends
                trendState = .loaded
                if selectedTrendIndex == nil, !trends.trends.isEmpty {
                    selectedTrendIndex = trends.trends.count - 1
                }
            }

            // Use prefetched period metadata
            if !cache.insightsPeriodMetadata.isEmpty {
                periodMetadata = cache.insightsPeriodMetadata
            }

            // Load selected period data (will hit pie chart cache for recent months)
            if trendState == .loaded {
                await loadSelectedPeriodData()
                return
            }
        }

        await loadTrends()
        await loadPeriodMetadata()
    }

    func refresh() async {
        trendState = .idle
        summaryState = .idle
        categoryState = .idle
        storeState = .idle
        pieChartCache.removeAll()
        storeBreakdownCache.removeAll()
        categoryTransactions.removeAll()
        expandedCategoryId = nil

        // Refresh StoreDataManager so store breakdowns are up to date
        if let dm = dataManager {
            await dm.refreshData(for: .month, periodString: selectedPeriod?.period)
        }

        await loadTrends()
        await loadPeriodMetadata()

        // Re-select the latest period (trends may have new data)
        if let trendData, !trendData.trends.isEmpty {
            selectedTrendIndex = trendData.trends.count - 1
        }

        // Always reload period data after refresh
        await loadSelectedPeriodData()
    }

    func loadTrends() async {
        trendState = .loading
        do {
            let response = try await apiService.getTrends(periodType: .month, numPeriods: 12)
            trendData = response
            trendState = .loaded

            // Auto-select latest period
            if selectedTrendIndex == nil, !response.trends.isEmpty {
                selectedTrendIndex = response.trends.count - 1
                await loadSelectedPeriodData()
            }
        } catch {
            trendState = .error(error.localizedDescription)
        }
    }

    func loadPeriodMetadata() async {
        do {
            let response = try await apiService.getPeriods(periodType: .month, numPeriods: 52)
            periodMetadata = response.periods
        } catch {
            // Non-critical — delta badge and receipt count will be unavailable
        }
    }

    func selectPeriod(at index: Int) {
        guard selectedTrendIndex != index else { return }
        selectedTrendIndex = index
        // Reset expansion states
        expandedCategoryId = nil
        categoryTransactions.removeAll()

        Task { await loadSelectedPeriodData() }
    }

    func loadSelectedPeriodData() async {
        guard let period = selectedPeriod else { return }

        // Extract month/year from the period's start date
        guard let startDate = period.startDate,
              let (month, year) = monthYear(from: startDate) else { return }

        async let catLoad: () = loadCategoryData(month: month, year: year)
        async let storeLoad: () = loadStoreData(periodString: period.period)
        async let prevLoad: () = loadPreviousPeriodData()

        _ = await (catLoad, storeLoad, prevLoad)

        // Preload transactions for all category groups in background
        preloadAllGroupTransactions()
    }

    private func loadCategoryData(month: Int, year: Int) async {
        let cacheKey = "\(month)-\(year)"
        if let cached = pieChartCache[cacheKey] {
            pieChartSummary = cached
            categoryState = .loaded
            return
        }

        categoryState = .loading
        do {
            let response = try await apiService.getPieChartSummary(month: month, year: year)
            pieChartSummary = response
            pieChartCache[cacheKey] = response
            categoryState = .loaded
        } catch {
            categoryState = .error(error.localizedDescription)
        }
    }

    private func loadStoreData(periodString: String) async {
        if let cached = storeBreakdownCache[periodString] {
            storeBreakdowns = cached
            storeState = .loaded
            return
        }

        storeState = .loading
        if let dm = dataManager {
            let grouped = dm.breakdownsByPeriod()
            if let breakdowns = grouped[periodString], !breakdowns.isEmpty {
                storeBreakdowns = breakdowns
                storeBreakdownCache[periodString] = breakdowns
                storeState = .loaded
                return
            }
        }

        // Fallback: use pie chart store data
        storeBreakdowns = []
        storeState = .loaded
    }

    private func loadPreviousPeriodData() async {
        guard let prevPeriod = previousPeriod,
              let startDate = prevPeriod.startDate,
              let (month, year) = monthYear(from: startDate) else {
            previousPieChartSummary = nil
            return
        }

        let cacheKey = "\(month)-\(year)"
        if let cached = pieChartCache[cacheKey] {
            previousPieChartSummary = cached
            return
        }

        do {
            let response = try await apiService.getPieChartSummary(month: month, year: year)
            previousPieChartSummary = response
            pieChartCache[cacheKey] = response
        } catch {
            previousPieChartSummary = nil
        }
    }

    // MARK: - Category Group Expansion

    func toggleCategory(_ groupName: String) {
        if expandedCategoryId == groupName {
            expandedCategoryId = nil
        } else {
            expandedCategoryId = groupName
        }
    }

    /// Preload transactions for all category groups so expansion is instant
    private func preloadAllGroupTransactions() {
        guard let period = selectedPeriod,
              let startDate = period.startDate,
              let endDate = period.endDate,
              let groups = pieChartSummary?.groups else { return }

        for group in groups {
            let groupName = group.groupName
            guard categoryTransactions[groupName] == nil else { continue }

            let groupCategories = pieChartSummary?.categories
                .filter { $0.group == groupName }
                .map { $0.name } ?? []

            guard !groupCategories.isEmpty else {
                categoryTransactions[groupName] = []
                continue
            }

            Task {
                var allTransactions: [APITransaction] = []
                for categoryName in groupCategories {
                    do {
                        var filters = TransactionFilters()
                        filters.startDate = startDate
                        filters.endDate = endDate
                        filters.category = categoryName
                        filters.pageSize = 5
                        let response = try await apiService.getTransactions(filters: filters)
                        allTransactions.append(contentsOf: response.transactions)
                    } catch {
                        // Skip failed categories
                    }
                }
                categoryTransactions[groupName] = allTransactions
                    .sorted { abs($0.itemPrice) > abs($1.itemPrice) }
                    .prefix(8)
                    .map { $0 }
            }
        }
    }

    // MARK: - Helpers

    private func monthYear(from date: Date) -> (Int, Int)? {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        return (month, year)
    }
}
