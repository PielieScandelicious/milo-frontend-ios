//
//  AppDataCache.swift
//  Scandalicious
//
//  Centralized disk-backed cache for instant app launch and smooth browsing.
//  Loads from disk synchronously on init so cached data is available before any view body evaluates.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AppDataCache: ObservableObject {
    static let shared = AppDataCache()

    // MARK: - Published Caches

    @Published var periodMetadata: [PeriodMetadata] = []
    @Published var breakdownsByPeriod: [String: [StoreBreakdown]] = [:]
    @Published var periodTotalSpends: [String: Double] = [:]
    @Published var periodReceiptCounts: [String: Int] = [:]
    @Published var pieChartSummaryByPeriod: [String: PieChartSummaryResponse] = [:]
    @Published var receiptsByPeriod: [String: [APIReceipt]] = [:]
    @Published var yearSummaryCache: [String: YearSummaryResponse] = [:]
    @Published var allTimeAggregate: AggregateResponse?
    /// Category items (transactions) keyed by "period|categoryName"
    @Published var categoryItemsCache: [String: [APITransaction]] = [:]
    /// Budget insights (preloaded for instant display)
    @Published var budgetInsightsCache: BudgetInsightsResponse?
    /// Budget progress (preloaded for instant display)
    @Published var budgetProgressCache: BudgetProgressResponse?
    /// Whether budget status has been checked (true = we know if user has budget or not)
    @Published var budgetStatusChecked: Bool = false
    @Published var lastRefreshDate: Date?

    var hasDiskCache: Bool { lastRefreshDate != nil }

    /// Returns true if the cache has data needed for smooth browsing (last 12 months)
    var isComplete: Bool {
        guard hasDiskCache, !periodMetadata.isEmpty else { return false }
        let recentPeriods = recentMonthPeriods
        guard !recentPeriods.isEmpty else { return false }
        // Check recent month periods have breakdowns, receipts, and category data
        for period in recentPeriods {
            if breakdownsByPeriod[period] == nil { return false }
            if receiptsByPeriod[period] == nil { return false }
            if pieChartSummaryByPeriod[period] == nil { return false }
        }
        // Check year summaries exist for distinct years in recent periods
        let years = Set(recentPeriods.compactMap { extractYear(from: $0) })
        for year in years {
            if yearSummaryCache[year] == nil { return false }
        }
        // Check all-time data
        if allTimeAggregate == nil { return false }
        // Check category items are loaded for recent periods
        for period in recentPeriods {
            if let pieChart = pieChartSummaryByPeriod[period] {
                for category in pieChart.categories {
                    if categoryItemsCache[categoryItemsKey(period: period, category: category.name)] == nil { return false }
                }
            }
        }
        return true
    }

    /// Returns month period strings for the last 12 months only
    var recentMonthPeriods: [String] {
        let cutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        return periodMetadata.compactMap { meta -> String? in
            guard let date = dateFormatter.date(from: meta.period) else { return meta.period }
            return date >= cutoff ? meta.period : nil
        }
    }

    private func extractYear(from period: String) -> String? {
        let parts = period.split(separator: " ")
        guard parts.count == 2 else { return nil }
        return String(parts[1])
    }

    // MARK: - Disk Cache

    /// Bump this version whenever category names change to force cache invalidation
    private static let cacheVersion = 4

    private let cacheFileURL: URL = {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("scandalicious_app_cache.json")
    }()

    private var saveDiskTask: Task<Void, Never>?

    // MARK: - Init

    init() {
        loadFromDisk()
    }

    // MARK: - Disk Persistence

    private struct DiskPayload: Codable {
        var cacheVersion: Int?
        var periodMetadata: [PeriodMetadata]
        var breakdownsByPeriod: [String: [StoreBreakdown]]
        var periodTotalSpends: [String: Double]
        var periodReceiptCounts: [String: Int]
        var pieChartSummaryByPeriod: [String: PieChartSummaryResponse]
        var receiptsByPeriod: [String: [APIReceipt]]
        var yearSummaryCache: [String: YearSummaryResponse]
        var allTimeAggregate: AggregateResponse?
        var categoryItemsCache: [String: [APITransaction]]
        var budgetInsightsCache: BudgetInsightsResponse?
        var budgetProgressCache: BudgetProgressResponse?
        var budgetStatusChecked: Bool?
        var lastRefreshDate: Date?
    }

    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: cacheFileURL)
            let decoder = JSONDecoder()
            let payload = try decoder.decode(DiskPayload.self, from: data)
            // Invalidate cache if version changed (e.g. category names renamed)
            if (payload.cacheVersion ?? 0) != Self.cacheVersion {
                try? FileManager.default.removeItem(at: cacheFileURL)
                return
            }
            self.periodMetadata = payload.periodMetadata
            self.breakdownsByPeriod = payload.breakdownsByPeriod
            self.periodTotalSpends = payload.periodTotalSpends
            self.periodReceiptCounts = payload.periodReceiptCounts
            self.pieChartSummaryByPeriod = payload.pieChartSummaryByPeriod
            self.receiptsByPeriod = payload.receiptsByPeriod
            self.yearSummaryCache = payload.yearSummaryCache
            self.allTimeAggregate = payload.allTimeAggregate
            self.categoryItemsCache = payload.categoryItemsCache
            self.budgetInsightsCache = payload.budgetInsightsCache
            self.budgetProgressCache = payload.budgetProgressCache
            self.budgetStatusChecked = payload.budgetStatusChecked ?? false
            self.lastRefreshDate = payload.lastRefreshDate
        } catch {
            // Cache corrupted or schema changed — start fresh
            try? FileManager.default.removeItem(at: cacheFileURL)
        }
    }

    func scheduleSaveToDisk() {
        saveDiskTask?.cancel()
        saveDiskTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            saveToDiskNow()
        }
    }

    private func saveToDiskNow() {
        let payload = DiskPayload(
            cacheVersion: Self.cacheVersion,
            periodMetadata: periodMetadata,
            breakdownsByPeriod: breakdownsByPeriod,
            periodTotalSpends: periodTotalSpends,
            periodReceiptCounts: periodReceiptCounts,
            pieChartSummaryByPeriod: pieChartSummaryByPeriod,
            receiptsByPeriod: receiptsByPeriod,
            yearSummaryCache: yearSummaryCache,
            allTimeAggregate: allTimeAggregate,
            categoryItemsCache: categoryItemsCache,
            budgetInsightsCache: budgetInsightsCache,
            budgetProgressCache: budgetProgressCache,
            budgetStatusChecked: budgetStatusChecked,
            lastRefreshDate: lastRefreshDate
        )
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(payload)
            try data.write(to: cacheFileURL, options: .atomic)
        } catch {
            // Non-fatal — cache is a best-effort optimization
        }
    }

    // MARK: - Cache Update Methods

    func updatePeriodMetadata(_ metadata: [PeriodMetadata]) {
        periodMetadata = metadata
        for period in metadata {
            periodTotalSpends[period.period] = period.totalSpend
            periodReceiptCounts[period.period] = period.receiptCount
        }
        lastRefreshDate = Date()
        scheduleSaveToDisk()
    }

    func updateBreakdowns(for period: String, breakdowns: [StoreBreakdown]) {
        breakdownsByPeriod[period] = breakdowns.sorted { $0.totalStoreSpend > $1.totalStoreSpend }
        scheduleSaveToDisk()
    }

    func updatePeriodTotalSpend(_ period: String, totalSpend: Double) {
        periodTotalSpends[period] = totalSpend
        scheduleSaveToDisk()
    }

    func updatePeriodReceiptCount(_ period: String, count: Int) {
        periodReceiptCounts[period] = count
        scheduleSaveToDisk()
    }

    func updatePieChartSummary(for period: String, summary: PieChartSummaryResponse) {
        pieChartSummaryByPeriod[period] = summary
        scheduleSaveToDisk()
    }

    func updateReceipts(for period: String, receipts: [APIReceipt]) {
        receiptsByPeriod[period] = receipts
        scheduleSaveToDisk()
    }

    func updateYearSummary(for year: String, summary: YearSummaryResponse) {
        yearSummaryCache[year] = summary
        scheduleSaveToDisk()
    }

    func updateAllTimeAggregate(_ aggregate: AggregateResponse) {
        allTimeAggregate = aggregate
        scheduleSaveToDisk()
    }

    /// Key for category items cache: "period|categoryName"
    func categoryItemsKey(period: String, category: String) -> String {
        "\(period)|\(category)"
    }

    func updateCategoryItems(period: String, category: String, items: [APITransaction]) {
        categoryItemsCache[categoryItemsKey(period: period, category: category)] = items
        scheduleSaveToDisk()
    }

    func updateBudgetInsights(_ insights: BudgetInsightsResponse) {
        budgetInsightsCache = insights
        scheduleSaveToDisk()
    }

    func updateBudgetProgress(_ progress: BudgetProgressResponse) {
        budgetProgressCache = progress
        scheduleSaveToDisk()
    }

    // MARK: - Preloading

    private let apiService = AnalyticsAPIService.shared

    func preloadReceipts(for period: String) async {
        guard receiptsByPeriod[period] == nil else { return }
        do {
            var filters = ReceiptFilters()
            filters.pageSize = 20

            if period != "All" && !(period.count == 4 && period.allSatisfy { $0.isNumber }) {
                let (startDate, endDate) = parsePeriodDates(period)
                filters.startDate = startDate
                filters.endDate = endDate
            }

            let response = try await apiService.fetchReceipts(filters: filters)
            await MainActor.run {
                receiptsByPeriod[period] = response.receipts
                scheduleSaveToDisk()
            }
        } catch {
            // Non-critical — receipts will load on demand
        }
    }

    func preloadCategoryData(for period: String) async {
        guard pieChartSummaryByPeriod[period] == nil else { return }
        guard period != "All" && !(period.count == 4 && period.allSatisfy { $0.isNumber }) else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        guard let date = dateFormatter.date(from: period) else { return }

        let month = Calendar.current.component(.month, from: date)
        let year = Calendar.current.component(.year, from: date)

        do {
            let summary = try await apiService.getPieChartSummary(month: month, year: year)
            await MainActor.run {
                pieChartSummaryByPeriod[period] = summary
                scheduleSaveToDisk()
            }
        } catch {
            // Non-critical
        }
    }

    func preloadYearSummary(for year: String) async {
        guard yearSummaryCache[year] == nil else { return }
        guard let yearInt = Int(year) else { return }
        do {
            let summary = try await apiService.getYearSummary(year: yearInt, topCategoriesLimit: 20)
            await MainActor.run {
                yearSummaryCache[year] = summary
                scheduleSaveToDisk()
            }
        } catch {
            // Non-critical
        }
    }

    /// Preloads transactions for all categories in a given month period
    func preloadCategoryItems(for period: String) async {
        guard let pieChart = pieChartSummaryByPeriod[period] else { return }
        guard period != "All" && !(period.count == 4 && period.allSatisfy { $0.isNumber }) else { return }

        let (startDate, endDate) = parsePeriodDates(period)

        await withTaskGroup(of: Void.self) { group in
            for category in pieChart.categories {
                let key = categoryItemsKey(period: period, category: category.name)
                guard categoryItemsCache[key] == nil else { continue }
                group.addTask {
                    do {
                        var filters = TransactionFilters()
                        filters.category = category.name
                        filters.pageSize = 100
                        filters.startDate = startDate
                        filters.endDate = endDate
                        let response = try await self.apiService.getTransactions(filters: filters)
                        await MainActor.run {
                            self.categoryItemsCache[key] = response.transactions
                        }
                    } catch {
                        // Non-critical
                    }
                }
            }
        }
        scheduleSaveToDisk()
    }

    func preloadAllTimeAggregate() async {
        guard allTimeAggregate == nil else { return }
        do {
            var filters = AggregateFilters()
            filters.allTime = true
            filters.topStoresLimit = 20
            filters.topCategoriesLimit = 20
            let aggregate = try await apiService.getAggregate(filters: filters)
            await MainActor.run {
                allTimeAggregate = aggregate
                scheduleSaveToDisk()
            }
        } catch {
            // Non-critical
        }
    }

    func preloadBudgetInsights() async {
        guard budgetInsightsCache == nil else { return }
        do {
            let insights = try await BudgetAPIService.shared.getBudgetInsights()
            await MainActor.run {
                budgetInsightsCache = insights
                scheduleSaveToDisk()
            }
        } catch {
            // Non-critical — insights will load on demand
        }
    }

    func preloadBudgetProgress() async {
        guard !budgetStatusChecked else { return }
        do {
            let progress = try await BudgetAPIService.shared.getBudgetProgress()
            await MainActor.run {
                budgetProgressCache = progress
                budgetStatusChecked = true
                scheduleSaveToDisk()
            }
        } catch {
            // Mark as checked even on failure (noBudgetSet, notFound, etc.)
            // so we don't show a loading spinner when we know there's no budget
            await MainActor.run {
                budgetStatusChecked = true
                scheduleSaveToDisk()
            }
        }
    }

    // MARK: - Helpers

    private func parsePeriodDates(_ period: String) -> (Date?, Date?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        guard let date = dateFormatter.date(from: period) else { return (nil, nil) }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.second = -1
        let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth ?? date)

        return (startOfMonth, endOfMonth)
    }

    // MARK: - Cache Invalidation

    func invalidateReceipts(for period: String) {
        receiptsByPeriod.removeValue(forKey: period)
    }

    func invalidateAll() {
        periodMetadata = []
        breakdownsByPeriod = [:]
        periodTotalSpends = [:]
        periodReceiptCounts = [:]
        pieChartSummaryByPeriod = [:]
        receiptsByPeriod = [:]
        yearSummaryCache = [:]
        allTimeAggregate = nil
        categoryItemsCache = [:]
        budgetInsightsCache = nil
        budgetProgressCache = nil
        budgetStatusChecked = false
        lastRefreshDate = nil
        try? FileManager.default.removeItem(at: cacheFileURL)
    }
}
