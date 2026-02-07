//
//  StoreBreakdownModel.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
import Combine

struct StoreBreakdown: Codable, Identifiable, Equatable, Hashable {
    let storeName: String
    let period: String
    let totalStoreSpend: Double
    let categories: [Category]
    let visitCount: Int
    let averageHealthScore: Double?  // Average health score for this store

    var id: String { "\(storeName)-\(period)" }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case period
        case totalStoreSpend = "total_store_spend"
        case categories
        case visitCount = "visit_count"
        case averageHealthScore = "average_health_score"
    }

    // Initializer with default nil for averageHealthScore
    init(storeName: String, period: String, totalStoreSpend: Double, categories: [Category], visitCount: Int, averageHealthScore: Double? = nil) {
        self.storeName = storeName
        self.period = period
        self.totalStoreSpend = totalStoreSpend
        self.categories = categories
        self.visitCount = visitCount
        self.averageHealthScore = averageHealthScore
    }

    // MARK: - Primary Group (derived from highest-spend category group)

    /// The category group where this store's spending is highest (e.g., "Food & Dining")
    var primaryGroup: String? {
        guard !categories.isEmpty else { return nil }
        let groupSpend = Dictionary(grouping: categories, by: { $0.group ?? "Miscellaneous" })
            .mapValues { $0.reduce(0.0) { $0 + $1.spent } }
        return groupSpend.max(by: { $0.value < $1.value })?.key
    }

    /// Hex color for the primary group (e.g., "#2ECC71")
    var primaryGroupColorHex: String? {
        guard let group = primaryGroup else { return nil }
        // Find first category matching this group and return its color
        return categories.first(where: { $0.group == group })?.groupColorHex
    }

    /// SF Symbol icon for the primary group (e.g., "fork.knife")
    var primaryGroupIcon: String? {
        guard let group = primaryGroup else { return nil }
        return categories.first(where: { $0.group == group })?.groupIcon
    }

    // Equatable conformance
    static func == (lhs: StoreBreakdown, rhs: StoreBreakdown) -> Bool {
        return lhs.id == rhs.id
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Category: Codable, Identifiable, Equatable, Hashable {
    let name: String
    let spent: Double
    let percentage: Int
    let group: String?  // Top-level group name (e.g., "Food & Dining")
    let groupColorHex: String?  // Hex color for the group
    let groupIcon: String?  // SF Symbol icon for the group

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name, spent, percentage, group
        case groupColorHex = "group_color_hex"
        case groupIcon = "group_icon"
    }

    init(name: String, spent: Double, percentage: Int, group: String? = nil, groupColorHex: String? = nil, groupIcon: String? = nil) {
        self.name = name
        self.spent = spent
        self.percentage = percentage
        self.group = group
        self.groupColorHex = groupColorHex
        self.groupIcon = groupIcon
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - Data Manager
class StoreDataManager: ObservableObject {
    @Published var storeBreakdowns: [StoreBreakdown] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var error: String?
    @Published var lastFetchDate: Date?
    @Published var averageHealthScore: Double?  // Overall average health score for the current period
    @Published var isDeleting = false
    @Published var deleteError: String?
    @Published var deleteSuccessMessage: String?
    @Published var periodTotalSpends: [String: Double] = [:]  // Total spend per period from backend (sum of item_price)
    @Published var periodReceiptCounts: [String: Int] = [:]  // Total receipt count per period

    // Lightweight period metadata for fast initial loading
    @Published var periodMetadata: [PeriodMetadata] = []
    @Published var isLoadingPeriods = false

    // Track which periods have been fully loaded with store breakdowns
    private var loadedPeriods: Set<String> = []

    var transactionManager: TransactionManager?
    private var hasInitiallyFetched = false

    init() {
        // Don't load local JSON anymore - will fetch from backend
    }

    // Inject transaction manager
    func configure(with transactionManager: TransactionManager) {
        self.transactionManager = transactionManager
    }

    // MARK: - Cache Integration

    /// Populate from disk cache for instant launch (no network calls)
    func populateFromCache(_ cache: AppDataCache) {
        guard cache.hasDiskCache else { return }
        self.periodMetadata = cache.periodMetadata
        self.periodTotalSpends = cache.periodTotalSpends
        self.periodReceiptCounts = cache.periodReceiptCounts

        // Restore breakdowns from cache
        var allBreakdowns: [StoreBreakdown] = []
        for (period, breakdowns) in cache.breakdownsByPeriod {
            allBreakdowns.append(contentsOf: breakdowns)
            loadedPeriods.insert(period)
        }
        self.storeBreakdowns = allBreakdowns

        if let latestPeriod = cache.periodMetadata.first {
            self.averageHealthScore = latestPeriod.averageHealthScore
        }

        self.hasInitiallyFetched = true
        self.lastFetchDate = cache.lastRefreshDate
    }

    /// Write current state to AppDataCache after a successful fetch
    private func syncToCache() {
        let cache = AppDataCache.shared
        cache.updatePeriodMetadata(periodMetadata)
        // Sync breakdowns by period
        let grouped = Dictionary(grouping: storeBreakdowns) { $0.period }
        for (period, breakdowns) in grouped {
            cache.updateBreakdowns(for: period, breakdowns: breakdowns)
        }
        for (period, spend) in periodTotalSpends {
            cache.updatePeriodTotalSpend(period, totalSpend: spend)
        }
        for (period, count) in periodReceiptCounts {
            cache.updatePeriodReceiptCount(period, count: count)
        }
    }

    // MARK: - Fetch Data from Backend

    /// Fetch analytics data from backend API - Initial load
    /// - Parameters:
    ///   - period: The period type (week/month/year)
    ///   - periodString: Optional specific period string like "January 2026" to fetch that exact period
    ///   - retryCount: Number of retries attempted (internal use)
    func fetchFromBackend(for period: PeriodType = .month, periodString: String? = nil, retryCount: Int = 0) async {
        // Only show full loading indicator on initial fetch
        let isInitialFetch = !hasInitiallyFetched

        await MainActor.run {
            if isInitialFetch {
                isLoading = true
            } else {
                isRefreshing = true
            }
            error = nil
        }

        do {
            // Create filters for the selected period
            let filters: AnalyticsFilters

            // If a specific period string is provided (e.g., "December 2025"), use its dates
            if let periodString = periodString {
                let (startDateStr, endDateStr) = parsePeriodToDates(periodString, periodType: period)
                var customFilters = AnalyticsFilters()
                customFilters.period = period
                customFilters.startDate = DateFormatter.yyyyMMdd.date(from: startDateStr)
                customFilters.endDate = DateFormatter.yyyyMMdd.date(from: endDateStr)
                filters = customFilters
            } else {
                // Default to current period
                switch period {
                case .week:
                    filters = .thisWeek
                case .month:
                    filters = .thisMonth
                case .year:
                    filters = .thisYear
                case .custom:
                    // Custom requires explicit dates, fall back to current month
                    filters = .thisMonth
                case .all:
                    // All time - no date filtering
                    filters = AnalyticsFilters()
                }
            }

            // Fetch summary from backend (now returns both stores and categories)
            let summary = try await AnalyticsAPIService.shared.getSummary(filters: filters)

            let stores = summary.stores ?? []

            // Convert API response to StoreBreakdown format
            let breakdowns = await convertToStoreBreakdowns(summary: summary, periodType: period)

            // Determine the period key for storing aggregations
            let periodKey = breakdowns.first?.period ?? periodString ?? {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                return dateFormatter.string(from: Date())
            }()

            // Fetch receipt count from /receipts endpoint (now supports date filtering)
            var receiptCount = 0
            if let startDate = filters.startDate, let endDate = filters.endDate {
                var receiptFilters = ReceiptFilters()
                receiptFilters.startDate = startDate
                receiptFilters.endDate = endDate
                receiptFilters.pageSize = 1  // We only need the total count
                if let receiptsResponse = try? await AnalyticsAPIService.shared.getReceipts(filters: receiptFilters) {
                    receiptCount = receiptsResponse.total
                }
            }

            await MainActor.run {
                // Update breakdowns for this specific period (don't replace all)
                // First remove existing breakdowns for this period
                self.storeBreakdowns.removeAll { $0.period == periodKey }
                // Then add the new breakdowns
                self.storeBreakdowns.append(contentsOf: breakdowns)

                // Update period aggregations
                self.periodTotalSpends[periodKey] = summary.totalSpend
                self.periodReceiptCounts[periodKey] = receiptCount

                // Also update periodMetadata if it exists for this period
                // This ensures totalSpendForPeriod and totalReceiptsForPeriod return fresh data
                if let index = self.periodMetadata.firstIndex(where: { $0.period == periodKey }) {
                    let existingMetadata = self.periodMetadata[index]
                    self.periodMetadata[index] = PeriodMetadata(
                        period: periodKey,
                        periodStart: existingMetadata.periodStart,
                        periodEnd: existingMetadata.periodEnd,
                        totalSpend: summary.totalSpend,
                        receiptCount: receiptCount,
                        storeCount: (summary.stores ?? []).count,
                        transactionCount: summary.transactionCount ?? 0,
                        totalItems: existingMetadata.totalItems,
                        averageHealthScore: summary.averageHealthScore
                    )
                }

                self.averageHealthScore = summary.averageHealthScore
                self.isLoading = false
                self.isRefreshing = false
                self.lastFetchDate = Date()
                self.hasInitiallyFetched = true

                // Sync to disk cache
                self.syncToCache()
            }

        } catch let apiError as AnalyticsAPIError {
            // Check if it's a cancellation error
            if case .networkError(let underlyingError) = apiError,
               (underlyingError as NSError).code == NSURLErrorCancelled {
                if retryCount < 3 {
                    await MainActor.run {
                        self.isLoading = false
                        self.isRefreshing = false
                    }
                    // Retry after a short delay to let the view settle
                    try? await Task.sleep(for: .seconds(0.5))
                    await fetchFromBackend(for: period, periodString: periodString, retryCount: retryCount + 1)
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.isRefreshing = false
                    }
                }
                return
            }

            await MainActor.run {
                // Only show error if this is not a refresh (initial load is more important)
                if isInitialFetch {
                    self.error = apiError.localizedDescription
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch is CancellationError {
            // Task was cancelled - this is normal, don't show error
            await MainActor.run {
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch {
            await MainActor.run {
                if isInitialFetch {
                    self.error = error.localizedDescription
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        }
    }

    /// Refresh data from backend - for pull-to-refresh
    /// - Parameters:
    ///   - period: The period type (week/month/year)
    ///   - periodString: Optional specific period string like "January 2026" to refresh that exact period
    func refreshData(for period: PeriodType = .month, periodString: String? = nil) async {
        await fetchFromBackend(for: period, periodString: periodString)
    }

    // MARK: - Fetch Period Metadata (Lightweight)

    /// Fetch lightweight period metadata from /analytics/periods endpoint
    /// This is fast (single API call) and returns summary info for all periods
    /// Falls back to fetchAllHistoricalData() if the endpoint is not available
    func fetchPeriodMetadata() async {
        await MainActor.run {
            isLoadingPeriods = true
            error = nil
        }

        do {
            let response = try await AnalyticsAPIService.shared.getPeriods(periodType: .month, numPeriods: 52)

            await MainActor.run {
                self.periodMetadata = response.periods

                // Pre-populate periodTotalSpends and periodReceiptCounts from metadata
                for period in response.periods {
                    self.periodTotalSpends[period.period] = period.totalSpend
                    self.periodReceiptCounts[period.period] = period.receiptCount
                }

                // Set health score from the most recent period
                if let latestPeriod = response.periods.first {
                    self.averageHealthScore = latestPeriod.averageHealthScore
                }

                self.isLoadingPeriods = false
                self.hasInitiallyFetched = true
                self.lastFetchDate = Date()

                // Sync to disk cache
                AppDataCache.shared.updatePeriodMetadata(response.periods)
            }

        } catch {
            // Endpoint not available yet - fall back to loading all historical data

            await MainActor.run {
                self.isLoadingPeriods = false
            }

            // Fall back to the old method that works with existing endpoints
            await fetchAllHistoricalData()
        }
    }

    /// Check if a period's detailed store breakdowns have been loaded
    func isPeriodLoaded(_ period: String) -> Bool {
        loadedPeriods.contains(period)
    }

    /// Fetch detailed store breakdowns for a specific period (lazy loading)
    /// - Parameter periodString: The period to load (e.g., "January 2026")
    func fetchPeriodDetails(_ periodString: String) async {
        // Skip if already loaded
        guard !loadedPeriods.contains(periodString) else {
            return
        }

        await MainActor.run {
            isRefreshing = true
        }

        do {
            // Parse the period string to get date range
            let (startDateStr, endDateStr) = parsePeriodToDates(periodString, periodType: .month)

            guard let startDate = DateFormatter.yyyyMMdd.date(from: startDateStr),
                  let endDate = DateFormatter.yyyyMMdd.date(from: endDateStr) else {
                await MainActor.run { isRefreshing = false }
                return
            }

            // Create filters for this period
            var filters = AnalyticsFilters()
            filters.period = .month
            filters.startDate = startDate
            filters.endDate = endDate

            // Fetch summary to get store breakdowns
            let summary = try await AnalyticsAPIService.shared.getSummary(filters: filters)

            // Convert to StoreBreakdowns
            let breakdowns = await convertToStoreBreakdowns(summary: summary, periodType: .month)

            await MainActor.run {
                // Remove any existing breakdowns for this period (in case of refresh)
                self.storeBreakdowns.removeAll { $0.period == periodString }

                // Add the new breakdowns
                self.storeBreakdowns.append(contentsOf: breakdowns)

                // Mark this period as loaded
                self.loadedPeriods.insert(periodString)

                // Update health score if this is the current period
                if let metadata = self.periodMetadata.first, metadata.period == periodString {
                    self.averageHealthScore = summary.averageHealthScore
                }

                self.isRefreshing = false

                // Sync breakdowns to disk cache
                AppDataCache.shared.updateBreakdowns(for: periodString, breakdowns: breakdowns)
            }

        } catch {
            await MainActor.run {
                isRefreshing = false
            }
        }
    }

    /// Get available periods from metadata (for period picker)
    var availablePeriods: [String] {
        periodMetadata.map { $0.period }
    }

    // MARK: - Fetch All Historical Data

    /// Fetch all historical data using trends to discover available periods
    /// This loads all past periods with data, going as far back as possible
    func fetchAllHistoricalData() async {
        await MainActor.run {
            isLoading = true
            error = nil
        }

        do {
            // First, fetch trends to discover all periods with data (max 52 months = ~4 years)
            let trendsResponse = try await AnalyticsAPIService.shared.getTrends(
                periodType: .month,
                numPeriods: 52
            )

            // Filter to periods with actual spending
            let periodsWithData = trendsResponse.trends.filter { $0.totalSpend > 0 }

            if periodsWithData.isEmpty {
                // No historical data, just set empty state
                await MainActor.run {
                    self.storeBreakdowns = []
                    self.isLoading = false
                    self.hasInitiallyFetched = true
                    self.lastFetchDate = Date()
                }
                return
            }

            // Fetch summary for each period to get store breakdowns
            var allBreakdowns: [StoreBreakdown] = []
            var allPeriodTotalSpends: [String: Double] = [:]
            var allPeriodReceiptCounts: [String: Int] = [:]
            var latestHealthScore: Double?

            for trendPeriod in periodsWithData {
                // Parse start and end dates from the trend period
                guard let startDate = DateFormatter.yyyyMMdd.date(from: trendPeriod.periodStart),
                      let endDate = DateFormatter.yyyyMMdd.date(from: trendPeriod.periodEnd) else {
                    continue
                }

                // Create filters for this specific period
                // Use 'month' period type with explicit dates to fetch historical data
                var filters = AnalyticsFilters()
                filters.period = .month
                filters.startDate = startDate
                filters.endDate = endDate

                do {
                    let summary = try await AnalyticsAPIService.shared.getSummary(filters: filters)

                    // Convert to StoreBreakdowns
                    let breakdowns = await convertToStoreBreakdowns(summary: summary, periodType: .month)
                    allBreakdowns.append(contentsOf: breakdowns)

                    // Use the breakdown's period as key (ensures consistency with selectedPeriod in UI)
                    let periodKey = breakdowns.first?.period ?? trendPeriod.period

                    // Store the total spend for this period (from backend = sum of item_price)
                    allPeriodTotalSpends[periodKey] = summary.totalSpend

                    // Fetch receipt count from /receipts endpoint (now supports date filtering)
                    var receiptFilters = ReceiptFilters()
                    receiptFilters.startDate = startDate
                    receiptFilters.endDate = endDate
                    receiptFilters.pageSize = 1  // We only need the total count
                    let receiptsResponse = try await AnalyticsAPIService.shared.getReceipts(filters: receiptFilters)
                    allPeriodReceiptCounts[periodKey] = receiptsResponse.total

                    // Store the health score from the most recent period (first one with data)
                    if latestHealthScore == nil {
                        latestHealthScore = summary.averageHealthScore
                    }

                } catch {
                    // Failed to fetch summary for period - continue with others
                }
            }

            // Sort by period (most recent first)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")

            allBreakdowns.sort { breakdown1, breakdown2 in
                let date1 = dateFormatter.date(from: breakdown1.period) ?? Date.distantPast
                let date2 = dateFormatter.date(from: breakdown2.period) ?? Date.distantPast
                return date1 > date2
            }

            await MainActor.run {
                self.storeBreakdowns = allBreakdowns
                self.periodTotalSpends = allPeriodTotalSpends
                self.periodReceiptCounts = allPeriodReceiptCounts
                self.averageHealthScore = latestHealthScore
                self.isLoading = false
                self.hasInitiallyFetched = true
                self.lastFetchDate = Date()

                // Sync to disk cache
                self.syncToCache()
            }

        } catch let apiError as AnalyticsAPIError {
            await MainActor.run {
                self.error = apiError.localizedDescription
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    // MARK: - Convert API Response to StoreBreakdown

    /// Converts API summary response to StoreBreakdown models
    /// Uses parallel fetching for store details to improve performance (3-5x faster)
    private func convertToStoreBreakdowns(summary: SummaryResponse, periodType: PeriodType) async -> [StoreBreakdown] {
        // Format period string (e.g., "January 2026")
        // Use new month/year format if available, otherwise fall back to startDate/endDate
        let periodString: String
        if let month = summary.month, let year = summary.year {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            var components = DateComponents()
            components.month = month
            components.year = year
            if let date = Calendar.current.date(from: components) {
                periodString = dateFormatter.string(from: date)
            } else {
                periodString = "\(month)/\(year)"
            }
        } else if let startDate = summary.startDate, let endDate = summary.endDate {
            periodString = formatPeriod(from: startDate, to: endDate, period: periodType)
        } else {
            // Fallback to current month
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            periodString = dateFormatter.string(from: Date())
        }

        let stores = summary.stores ?? []

        let startTime = Date()

        // Fetch all store details in parallel using TaskGroup
        let breakdowns = await withTaskGroup(of: StoreBreakdown.self, returning: [StoreBreakdown].self) { group in
            // Add a task for each store
            for apiStore in stores {
                group.addTask {
                    await self.fetchStoreBreakdown(
                        apiStore: apiStore,
                        periodType: periodType,
                        periodString: periodString,
                        summary: summary
                    )
                }
            }

            // Collect results as they complete
            var results: [StoreBreakdown] = []
            results.reserveCapacity(stores.count)

            for await breakdown in group {
                results.append(breakdown)
            }

            return results
        }

        // Sort by total spend (descending) to maintain consistent ordering
        return breakdowns.sorted { $0.totalStoreSpend > $1.totalStoreSpend }
    }

    /// Fetches detailed breakdown for a single store (used by parallel TaskGroup)
    private func fetchStoreBreakdown(
        apiStore: APIStoreBreakdown,
        periodType: PeriodType,
        periodString: String,
        summary: SummaryResponse
    ) async -> StoreBreakdown {
        do {
            // Parse dates from summary response
            let startDateParsed = summary.startDateParsed
            let endDateParsed = summary.endDateParsed

            let filters = AnalyticsFilters(
                period: periodType,
                startDate: startDateParsed,
                endDate: endDateParsed,
                storeName: apiStore.storeName
            )

            let storeDetails = try await AnalyticsAPIService.shared.getStoreDetails(
                storeName: apiStore.storeName,
                filters: filters
            )

            // Convert categories (preserving group info)
            let categories = storeDetails.categories.map { categoryBreakdown in
                Category(
                    name: categoryBreakdown.name,
                    spent: categoryBreakdown.spent,
                    percentage: Int(categoryBreakdown.percentage),
                    group: categoryBreakdown.group,
                    groupColorHex: categoryBreakdown.groupColorHex,
                    groupIcon: categoryBreakdown.groupIcon
                )
            }

            return StoreBreakdown(
                storeName: apiStore.storeName,
                period: periodString,
                totalStoreSpend: apiStore.amountSpent,
                categories: categories,
                visitCount: apiStore.storeVisits,
                averageHealthScore: storeDetails.averageHealthScore ?? apiStore.averageHealthScore
            )

        } catch {
            // Fallback: Create breakdown without category details
            return StoreBreakdown(
                storeName: apiStore.storeName,
                period: periodString,
                totalStoreSpend: apiStore.amountSpent,
                categories: [],
                visitCount: apiStore.storeVisits,
                averageHealthScore: apiStore.averageHealthScore
            )
        }
    }

    private func formatPeriod(from startDateStr: String, to endDateStr: String, period: PeriodType) -> String {
        guard let startDate = ISO8601DateFormatter().date(from: startDateStr) ??
                DateFormatter.yyyyMMdd.date(from: startDateStr) else {
            return "Unknown Period"
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US") // Ensure consistent English month names

        let result = dateFormatter.string(from: startDate)
        return result
    }

    // Regenerate breakdowns from transactions (for local data)
    func regenerateBreakdowns() {
        guard let transactionManager = transactionManager else { return }

        let transactions = transactionManager.transactions
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US") // Ensure consistent English month names

        // Group by store and period
        var breakdownDict: [String: [Transaction]] = [:]

        for transaction in transactions {
            let period = dateFormatter.string(from: transaction.date)
            let key = "\(transaction.storeName)-\(period)"
            breakdownDict[key, default: []].append(transaction)
        }

        // Convert to StoreBreakdown objects
        let localBreakdowns = breakdownDict.map { key, transactions -> StoreBreakdown in
            let components = key.split(separator: "-")
            let storeName = String(components[0])
            let period = components.dropFirst().joined(separator: "-")

            // Group by category
            let categoryDict = Dictionary(grouping: transactions, by: { $0.category })
            let totalSpend = transactions.reduce(0) { $0 + $1.amount }

            let categories = categoryDict.map { category, items in
                let spent = items.reduce(0) { $0 + $1.amount }
                let percentage = Int((spent / totalSpend) * 100)
                return Category(name: category, spent: spent, percentage: percentage)
            }.sorted { $0.spent > $1.spent }

            // Calculate visit count (unique dates)
            let uniqueDates = Set(transactions.map { calendar.startOfDay(for: $0.date) })
            let visitCount = uniqueDates.count

            return StoreBreakdown(
                storeName: storeName,
                period: period,
                totalStoreSpend: totalSpend,
                categories: categories,
                visitCount: visitCount
            )
        }

        // Update or add breakdowns
        // First, create a dictionary of existing breakdowns for fast lookup
        var existingBreakdownsDict = Dictionary(uniqueKeysWithValues: storeBreakdowns.map { ($0.id, $0) })

        // Update or add local breakdowns
        for localBreakdown in localBreakdowns {
            existingBreakdownsDict[localBreakdown.id] = localBreakdown
        }

        // Convert back to array and sort by date (most recent first)
        storeBreakdowns = Array(existingBreakdownsDict.values).sorted { breakdown1, breakdown2 in
            // Extract date from period string for sorting
            let date1 = dateFormatter.date(from: breakdown1.period) ?? Date.distantPast
            let date2 = dateFormatter.date(from: breakdown2.period) ?? Date.distantPast
            return date1 > date2
        }
    }

    // Group breakdowns by period for overview
    func breakdownsByPeriod() -> [String: [StoreBreakdown]] {
        Dictionary(grouping: storeBreakdowns, by: { $0.period })
    }

    // Calculate total spending per period
    func totalSpending(for period: String) -> Double {
        storeBreakdowns
            .filter { $0.period == period }
            .reduce(0) { $0 + $1.totalStoreSpend }
    }

    // Delete a store breakdown - removes from local state only (for immediate UI feedback)
    func deleteBreakdownLocally(_ breakdown: StoreBreakdown) {
        storeBreakdowns.removeAll { $0.id == breakdown.id }
    }

    // Delete a store breakdown from backend and local state
    func deleteBreakdown(_ breakdown: StoreBreakdown, periodType: PeriodType = .month) async -> Bool {
        await MainActor.run {
            isDeleting = true
            deleteError = nil
            deleteSuccessMessage = nil
        }

        do {
            // Parse the period string (e.g., "January 2026") to get date range
            let (startDate, endDate) = parsePeriodToDates(breakdown.period, periodType: periodType)

            // Call backend API
            let response = try await AnalyticsAPIService.shared.removeTransactions(
                storeName: breakdown.storeName,
                period: periodType.rawValue,
                startDate: startDate,
                endDate: endDate
            )

            await MainActor.run {
                // Remove from local state after successful API call
                self.storeBreakdowns.removeAll { $0.id == breakdown.id }
                self.isDeleting = false
                self.deleteSuccessMessage = response.message
            }

            return true

        } catch let apiError as AnalyticsAPIError {
            await MainActor.run {
                self.isDeleting = false
                self.deleteError = apiError.localizedDescription
            }
            return false

        } catch {
            await MainActor.run {
                self.isDeleting = false
                self.deleteError = error.localizedDescription
            }
            return false
        }
    }

    // Parse period string to date range
    private func parsePeriodToDates(_ period: String, periodType: PeriodType) -> (startDate: String, endDate: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US") // Ensure consistent English month names
        dateFormatter.timeZone = TimeZone(identifier: "UTC") // Use UTC to avoid timezone shifts

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"
        outputFormatter.timeZone = TimeZone(identifier: "UTC")

        // Use UTC calendar to avoid timezone issues
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        guard let parsedDate = dateFormatter.date(from: period) else {
            // Fallback to current month if parsing fails
            let now = Date()
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (outputFormatter.string(from: startOfMonth), outputFormatter.string(from: endOfMonth))
        }

        switch periodType {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: parsedDate))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return (outputFormatter.string(from: startOfWeek), outputFormatter.string(from: endOfWeek))

        case .month:
            let components = calendar.dateComponents([.year, .month], from: parsedDate)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (outputFormatter.string(from: startOfMonth), outputFormatter.string(from: endOfMonth))

        case .year:
            let components = calendar.dateComponents([.year], from: parsedDate)
            let startOfYear = calendar.date(from: components)!
            let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
            return (outputFormatter.string(from: startOfYear), outputFormatter.string(from: endOfYear))

        case .custom:
            // Custom periods use the same format as month (parsed from "MMMM yyyy")
            let components = calendar.dateComponents([.year, .month], from: parsedDate)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (outputFormatter.string(from: startOfMonth), outputFormatter.string(from: endOfMonth))

        case .all:
            // All time - return a very wide date range
            return ("1900-01-01", outputFormatter.string(from: Date()))
        }
    }

    // Delete a store breakdown at specific indices
    func deleteBreakdowns(at offsets: IndexSet, from breakdowns: [StoreBreakdown]) {
        let breakdownsToDelete = offsets.map { breakdowns[$0] }
        for breakdown in breakdownsToDelete {
            deleteBreakdownLocally(breakdown)
        }
    }
}
// MARK: - DateFormatter Extension

extension DateFormatter {
    static var yyyyMMdd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }
}
