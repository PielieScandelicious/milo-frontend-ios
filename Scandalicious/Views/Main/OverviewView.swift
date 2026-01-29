
//
//
//  OverviewView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseAuth
import Combine

// MARK: - Notification for Receipt Upload
extension Notification.Name {
    static let receiptUploadedSuccessfully = Notification.Name("receiptUploadedSuccessfully")
    static let receiptUploadStarted = Notification.Name("receiptUploadStarted")
    static let receiptDeleted = Notification.Name("receiptDeleted")
    static let shareExtensionUploadDetected = Notification.Name("shareExtensionUploadDetected")
}

enum SortOption: String, CaseIterable {
    case highestSpend = "Highest Spend"
    case lowestSpend = "Lowest Spend"
    case storeName = "Store Name"
}




struct OverviewView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var dataManager: StoreDataManager
    @ObservedObject var rateLimitManager = RateLimitManager.shared
    @StateObject private var receiptsViewModel = ReceiptsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    // Track the last time we checked for Share Extension uploads
    @State private var lastCheckedUploadTimestamp: TimeInterval = 0

    // Track when a receipt is being uploaded from Scan tab or Share Extension
    @State private var isReceiptUploading = false

    // Track if refreshWithRetry is currently running to prevent duplicate calls
    @State private var isRefreshWithRetryRunning = false

    @State private var selectedPeriod: String = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US") // Ensure consistent English month names
        return dateFormatter.string(from: Date())
    }()
    @State private var selectedSort: SortOption = .highestSpend
    @State private var showingFilterSheet = false
    @State private var displayedBreakdowns: [StoreBreakdown] = []
    @State private var selectedBreakdown: StoreBreakdown?
    @State private var showingAllTransactions = false
    @State private var showTrendlineInOverview = false  // Toggle between pie chart and trendline
    @State private var lastRefreshTime: Date?
    @State private var cachedBreakdownsByPeriod: [String: [StoreBreakdown]] = [:]  // Cache for period breakdowns
    @State private var displayedBreakdownsPeriod: String = ""  // Track which period displayedBreakdowns belongs to
    @State private var overviewTrends: [TrendPeriod] = []  // Trends for the overview chart
    @State private var isLoadingTrends = false
    @State private var hasFetchedTrends = false  // Prevent duplicate trend fetches
    @State private var hasSyncedRateLimit = false  // Prevent duplicate rate limit syncs
    @State private var loadedReceiptPeriods: Set<String> = []  // Track which periods have loaded receipts
    @State private var expandedReceiptId: String? // For inline receipt expansion
    @State private var isDeletingReceipt = false
    @State private var receiptDeleteError: String?
    @State private var scrollOffset: CGFloat = 0 // Track scroll for header fade effect
    @State private var cachedAvailablePeriods: [String] = [] // Cached for performance
    @State private var cachedSegmentsByPeriod: [String: [StoreChartSegment]] = [:] // Cache segments
    @State private var cachedChartDataByPeriod: [String: [ChartData]] = [:] // Cache chart data for IconDonutChart
    @State private var lastBreakdownsHash: Int = 0 // Track if breakdowns changed
    @State private var storeRowsAppeared = false // Track staggered animation state
    @Binding var showSignOutConfirmation: Bool

    // Check if the selected period is the current month
    private var isCurrentPeriod: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentPeriod = dateFormatter.string(from: Date())
        return selectedPeriod == currentPeriod
    }

    private var availablePeriods: [String] {
        // Use cached version for performance - avoid computing during render
        if !cachedAvailablePeriods.isEmpty {
            return cachedAvailablePeriods
        }
        // Return just the selected period as fallback to avoid blocking render
        // The cache will be populated by handleOnAppear's deferred Task
        return [selectedPeriod]
    }

    /// Compute available periods from data manager - called once when data changes
    private func computeAvailablePeriods() -> [String] {
        // Use period metadata if available (from lightweight /analytics/periods endpoint)
        if !dataManager.periodMetadata.isEmpty {
            // Period metadata is already sorted by backend (most recent first)
            // Reverse to get oldest first (left), most recent last (right) for swipe UX
            return Array(dataManager.periodMetadata.map { $0.period }.reversed())
        }

        // Fallback: Use breakdowns if metadata not loaded yet
        let periods = Array(dataManager.breakdownsByPeriod().keys)

        // If no periods with data, show only the current month (empty state)
        if periods.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            return [dateFormatter.string(from: Date())]
        }

        // Sort periods chronologically (oldest first, most recent last/right)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")

        return periods.sorted { period1, period2 in
            let date1 = dateFormatter.date(from: period1) ?? Date.distantPast
            let date2 = dateFormatter.date(from: period2) ?? Date.distantPast
            return date1 < date2  // Oldest first (left), most recent last (right)
        }
    }

    /// Update the cached available periods
    private func updateAvailablePeriodsCache() {
        let newPeriods = computeAvailablePeriods()
        if cachedAvailablePeriods != newPeriods {
            cachedAvailablePeriods = newPeriods
        }
    }

    private var currentBreakdowns: [StoreBreakdown] {
        // Use displayedBreakdowns only if it belongs to the current selected period
        // This prevents showing stale data from a previous period
        if !displayedBreakdowns.isEmpty && displayedBreakdownsPeriod == selectedPeriod {
            return displayedBreakdowns
        }
        return cachedBreakdownsByPeriod[selectedPeriod] ?? []
    }

    /// Get cached breakdowns for a specific period
    /// This avoids recalculating on every render and ensures correct data per period
    private func getCachedBreakdowns(for period: String) -> [StoreBreakdown] {
        return cachedBreakdownsByPeriod[period] ?? []
    }

    /// Build the cache for all available periods
    /// Called once when data loads or sort changes
    /// Includes guard to prevent redundant rebuilds
    private func rebuildBreakdownCache() {
        // Compute hash of current breakdowns to detect actual changes
        let currentHash = dataManager.storeBreakdowns.hashValue

        // Skip rebuild if nothing changed
        if currentHash == lastBreakdownsHash && !cachedBreakdownsByPeriod.isEmpty {
            // Only update displayedBreakdowns if period changed
            if displayedBreakdownsPeriod != selectedPeriod {
                displayedBreakdowns = cachedBreakdownsByPeriod[selectedPeriod] ?? []
                displayedBreakdownsPeriod = selectedPeriod
            }
            return
        }

        // Store the new hash
        lastBreakdownsHash = currentHash

        var newCache: [String: [StoreBreakdown]] = [:]

        // Group breakdowns by period
        let groupedByPeriod = Dictionary(grouping: dataManager.storeBreakdowns) { $0.period }

        for (period, periodBreakdowns) in groupedByPeriod {
            var sorted = periodBreakdowns

            // Always sort by highest spending for clear visual hierarchy
            sorted.sort { $0.totalStoreSpend > $1.totalStoreSpend }

            newCache[period] = sorted
        }

        // Batch all state updates together to minimize re-renders
        cachedBreakdownsByPeriod = newCache
        displayedBreakdowns = newCache[selectedPeriod] ?? []
        displayedBreakdownsPeriod = selectedPeriod

        // Also update available periods cache
        updateAvailablePeriodsCache()

        // Clear segment and chart data caches when breakdowns change (will be rebuilt lazily)
        cachedSegmentsByPeriod.removeAll()
        cachedChartDataByPeriod.removeAll()
    }

    /// Update cache for a specific period only
    private func updateCacheForPeriod(_ period: String) {
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == period }

        // Always sort by highest spending for clear visual hierarchy
        breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }

        cachedBreakdownsByPeriod[period] = breakdowns

        // Invalidate segment cache for this period (will be rebuilt lazily)
        cachedSegmentsByPeriod.removeValue(forKey: period)

        // Update displayedBreakdowns if this is the selected period
        if period == selectedPeriod {
            displayedBreakdowns = breakdowns
            displayedBreakdownsPeriod = period
        }
    }

    // Update displayed breakdowns when filters change (legacy, now uses cache)
    private func updateDisplayedBreakdowns() {
        updateCacheForPeriod(selectedPeriod)
    }

    private var totalPeriodSpending: Double {
        // Use the total spend from backend (sum of item_price) instead of summing store amounts
        dataManager.periodTotalSpends[selectedPeriod] ?? currentBreakdowns.reduce(0) { $0 + $1.totalStoreSpend }
    }

    private var totalPeriodReceipts: Int {
        // Use the receipt count from backend instead of summing visit counts
        dataManager.periodReceiptCounts[selectedPeriod] ?? currentBreakdowns.reduce(0) { $0 + $1.visitCount }
    }

    // MARK: - Extracted Body Components

    private var mainBodyContent: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()

            if let error = dataManager.error {
                errorStateView(error: error)
            } else {
                swipeableContentView
            }
        }
    }

    private func errorStateView(error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text("Failed to load data")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task {
                    await dataManager.fetchFromBackend(for: .month, periodString: selectedPeriod)
                }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .transition(.opacity)
    }

    private var allTransactionsDestination: some View {
        TransactionListView(
            storeName: "All Stores",
            period: selectedPeriod,
            category: nil,
            categoryColor: nil
        )
    }


    var body: some View {
        mainBodyContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    modernPeriodNavigationToolbar
                }
            }
            .navigationDestination(item: $selectedBreakdown) { breakdown in
                StoreDetailView(storeBreakdown: breakdown)
            }
            .navigationDestination(isPresented: $showingAllTransactions) {
                allTransactionsDestination
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(selectedSort: $selectedSort)
            }
            .onAppear(perform: handleOnAppear)
            .onReceive(NotificationCenter.default.publisher(for: .receiptUploadStarted)) { _ in
                handleReceiptUploadStarted()
            }
            .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
                handleReceiptUploadSuccess()
            }
            .onChange(of: transactionManager.transactions) { oldValue, newValue in
                handleTransactionsChanged(oldValue: oldValue, newValue: newValue)
            }
            .onChange(of: selectedPeriod) { _, newValue in
                handlePeriodChanged(newValue: newValue)
            }
            .onChange(of: selectedSort) { _, _ in
                rebuildBreakdownCache()
            }
            .onChange(of: dataManager.storeBreakdowns) { _, _ in
                rebuildBreakdownCache()
                cacheSegmentsForPeriod(selectedPeriod)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active { checkForShareExtensionUploads() }
            }
    }

    // MARK: - Lifecycle Handlers

    private func handleOnAppear() {
        // Configure data manager if needed
        if dataManager.transactionManager == nil {
            dataManager.configure(with: transactionManager)
        }

        // Defer ALL heavy work to next run loop to allow smooth tab transition
        Task {
            // Small delay to let the tab animation complete
            try? await Task.sleep(for: .milliseconds(100))

            await MainActor.run {
                // Update periods cache (deferred to avoid blocking initial render)
                if cachedAvailablePeriods.isEmpty {
                    cachedAvailablePeriods = computeAvailablePeriods()
                }

                // Build breakdown caches from preloaded data
                rebuildBreakdownCache()

                // Load share extension timestamps (UserDefaults I/O)
                loadShareExtensionTimestamps()

                // Check for share extension uploads
                checkForShareExtensionUploads()
            }
        }

        // Load receipts only if not already loaded for this period
        // Mark as loading IMMEDIATELY to prevent duplicate concurrent loads
        let periodToLoad = selectedPeriod
        if !loadedReceiptPeriods.contains(periodToLoad) {
            loadedReceiptPeriods.insert(periodToLoad) // Mark immediately to prevent race conditions
            Task {
                await receiptsViewModel.loadReceipts(period: periodToLoad, storeName: nil, reset: true)
            }
        }

        // Sync rate limit only once per session
        if !hasSyncedRateLimit {
            Task {
                await rateLimitManager.syncFromBackend()
                await MainActor.run { hasSyncedRateLimit = true }
            }
        }
    }

    private func loadShareExtensionTimestamps() {
        guard lastCheckedUploadTimestamp == 0 else { return }

        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let persistedLastChecked = sharedDefaults.double(forKey: "lastCheckedUploadTimestamp")
        if persistedLastChecked > 0 {
            lastCheckedUploadTimestamp = persistedLastChecked
        } else {
            let existingTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
            if existingTimestamp > 0 {
                lastCheckedUploadTimestamp = existingTimestamp
                sharedDefaults.set(existingTimestamp, forKey: "lastCheckedUploadTimestamp")
            }
        }
    }

    private func handleReceiptUploadStarted() {
        print("📤 Received receipt upload started notification")
        isReceiptUploading = true
    }

    private func handleReceiptUploadSuccess() {
        print("📬 Received receipt upload notification - refreshing backend data")
        isReceiptUploading = false

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentMonthPeriod = dateFormatter.string(from: Date())

        // Keep period in loadedReceiptPeriods to prevent duplicate loads
        // The loadReceipts call with reset:true will refresh the data

        Task {
            try? await Task.sleep(for: .seconds(1))

            await dataManager.refreshData(for: .month, periodString: currentMonthPeriod)

            if selectedPeriod == currentMonthPeriod {
                updateDisplayedBreakdowns()
                // Reload receipts for current month (reset:true will clear and reload)
                await receiptsViewModel.loadReceipts(period: currentMonthPeriod, storeName: nil, reset: true)
            }
            await rateLimitManager.syncFromBackend()
        }
    }

    private func handleTransactionsChanged(oldValue: [Transaction], newValue: [Transaction]) {
        // regenerateBreakdowns() will update dataManager.storeBreakdowns,
        // which triggers onChange -> rebuildBreakdownCache() automatically
        // So we don't need to call updateDisplayedBreakdowns() here (would be redundant)
        dataManager.regenerateBreakdowns()

        if newValue.count > oldValue.count, let latestTransaction = newValue.first {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            selectedPeriod = dateFormatter.string(from: latestTransaction.date)
        }
    }

    private func handlePeriodChanged(newValue: String) {
        if showTrendlineInOverview { showTrendlineInOverview = false }
        expandedReceiptId = nil

        // Reset store rows animation for staggered re-entry
        storeRowsAppeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                storeRowsAppeared = true
            }
        }

        // Immediately update displayed breakdowns for the new period (no async delay)
        updateDisplayedBreakdowns()

        // Pre-cache segments for the new period if not already cached
        if cachedSegmentsByPeriod[newValue] == nil {
            cacheSegmentsForPeriod(newValue)
        }

        // Check if receipts for this period need to be loaded
        // Mark as loading IMMEDIATELY to prevent duplicate concurrent loads
        let needsReceiptsLoad = !loadedReceiptPeriods.contains(newValue)
        if needsReceiptsLoad {
            loadedReceiptPeriods.insert(newValue) // Mark immediately to prevent race conditions
        }

        Task {
            // Prefetch insights
            await MainActor.run { prefetchInsights() }

            // Only load receipts if not already cached for this period
            if needsReceiptsLoad {
                await receiptsViewModel.loadReceipts(period: newValue, storeName: nil, reset: true)
            }

            if !dataManager.periodMetadata.isEmpty {
                if !dataManager.isPeriodLoaded(newValue) {
                    await dataManager.fetchPeriodDetails(newValue)
                    await MainActor.run {
                        updateCacheForPeriod(newValue)
                        cacheSegmentsForPeriod(newValue)
                    }
                }
                await prefetchAdjacentPeriods(around: newValue)
            }
        }
    }

    // MARK: - Insight Prefetching

    /// Prefetches daily insights in the background so they're ready when the user taps
    private func prefetchInsights() {
        // Only prefetch if we have data
        guard totalPeriodSpending > 0 else { return }

        // Prefetch spending insight
        InsightService.shared.prefetchInsight(for: .totalSpending(
            amount: totalPeriodSpending,
            period: selectedPeriod,
            storeCount: currentBreakdowns.count,
            topStore: currentBreakdowns.first?.storeName
        ))

        // Prefetch health score insight if available
        if let score = dataManager.averageHealthScore {
            let totalVisits = currentBreakdowns.reduce(0) { $0 + $1.visitCount }
            InsightService.shared.prefetchInsight(for: .healthScore(
                score: score,
                period: selectedPeriod,
                totalItems: totalVisits
            ))
        }
    }

    // MARK: - Overview Trends Fetching

    /// Fetches trends data for the overview chart (lazy-loaded when user taps trendline)
    private func fetchOverviewTrends() async {
        guard !isLoadingTrends && !hasFetchedTrends else { return }
        isLoadingTrends = true
        defer { isLoadingTrends = false }

        do {
            let response = try await AnalyticsAPIService.shared.getTrends(periodType: .month, numPeriods: 52)
            await MainActor.run {
                self.overviewTrends = response.periods
                self.hasFetchedTrends = true
            }
        } catch {
            print("Failed to fetch overview trends: \(error)")
        }
    }

    // MARK: - Period Prefetching

    /// Prefetches adjacent periods for smooth swiping experience
    /// Loads 2 periods before and 2 periods after the current period
    private func prefetchAdjacentPeriods(around period: String) async {
        guard !dataManager.periodMetadata.isEmpty else { return }

        // Find the index of the current period in availablePeriods
        guard let currentIndex = availablePeriods.firstIndex(of: period) else { return }

        // Collect periods to prefetch (2 before, 2 after)
        var periodsToPrefetch: [String] = []

        // Add 2 periods before (older - lower indices since oldest is first)
        for offset in 1...2 {
            let index = currentIndex - offset
            if index >= 0 {
                let periodString = availablePeriods[index]
                if !dataManager.isPeriodLoaded(periodString) {
                    periodsToPrefetch.append(periodString)
                }
            }
        }

        // Add 2 periods after (newer - higher indices)
        for offset in 1...2 {
            let index = currentIndex + offset
            if index < availablePeriods.count {
                let periodString = availablePeriods[index]
                if !dataManager.isPeriodLoaded(periodString) {
                    periodsToPrefetch.append(periodString)
                }
            }
        }

        // Prefetch in parallel
        if !periodsToPrefetch.isEmpty {
            await withTaskGroup(of: Void.self) { group in
                for periodString in periodsToPrefetch {
                    group.addTask {
                        await dataManager.fetchPeriodDetails(periodString)
                    }
                }
            }
            // Update cache for prefetched periods on main thread
            await MainActor.run {
                for periodString in periodsToPrefetch {
                    updateCacheForPeriod(periodString)
                    // Pre-cache segments for smooth swiping
                    cacheSegmentsForPeriod(periodString)
                }
            }
        }
    }

    // MARK: - Share Extension Upload Detection

    /// Checks if the Share Extension uploaded a receipt while the app was in the background
    private func checkForShareExtensionUploads() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        // Check if there's a new upload timestamp
        let uploadTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")

        // If there's a new upload (timestamp is newer than last checked)
        if uploadTimestamp > lastCheckedUploadTimestamp && uploadTimestamp > 0 {
            print("📬 Detected Share Extension upload (timestamp: \(uploadTimestamp)) - refreshing data")

            // Update last checked timestamp and persist it
            lastCheckedUploadTimestamp = uploadTimestamp
            sharedDefaults.set(uploadTimestamp, forKey: "lastCheckedUploadTimestamp")

            // Show syncing indicator immediately
            isReceiptUploading = true

            // Post notification so other views can react
            NotificationCenter.default.post(name: .shareExtensionUploadDetected, object: nil)

            // Only start refresh if not already running (prevent duplicate concurrent refreshes)
            if !isRefreshWithRetryRunning {
                Task {
                    await refreshWithRetry()
                }
            } else {
                print("ℹ️ refreshWithRetry already running, skipping duplicate call")
            }
        }
    }

    /// Refreshes data with retry mechanism for share extension uploads
    /// The share extension signals immediately but the upload + backend processing can take 5-15 seconds
    private func refreshWithRetry() async {
        // Mark as running
        await MainActor.run {
            isRefreshWithRetryRunning = true
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentMonthPeriod = dateFormatter.string(from: Date())

        // Capture current state to detect changes (not just count - also total spending for existing stores)
        let initialBreakdowns = dataManager.storeBreakdowns.filter { $0.period == currentMonthPeriod }
        let initialBreakdownCount = initialBreakdowns.count
        let initialTotalSpending = initialBreakdowns.reduce(0.0) { $0 + $1.totalStoreSpend }
        let initialTransactionCount = transactionManager.transactions.count

        // Retry configuration: 3 seconds each, up to 4 attempts
        let retryDelays: [Double] = [3.0, 3.0, 3.0, 3.0] // Total: up to 12 seconds of waiting
        var dataChanged = false

        for (attempt, delay) in retryDelays.enumerated() {
            print("⏳ Share Extension sync - attempt \(attempt + 1)/\(retryDelays.count), waiting \(delay)s...")
            try? await Task.sleep(for: .seconds(delay))

            print("📥 Refreshing data for current month: '\(currentMonthPeriod)' (attempt \(attempt + 1))")
            await dataManager.refreshData(for: .month, periodString: currentMonthPeriod)

            // Check if data changed (count OR total spending - handles uploads to existing stores)
            let newBreakdowns = dataManager.storeBreakdowns.filter { $0.period == currentMonthPeriod }
            let newBreakdownCount = newBreakdowns.count
            let newTotalSpending = newBreakdowns.reduce(0.0) { $0 + $1.totalStoreSpend }
            let newTransactionCount = transactionManager.transactions.count

            // Detect change: new stores, more transactions, OR increased spending (same store, new receipt)
            let countChanged = newBreakdownCount > initialBreakdownCount || newTransactionCount > initialTransactionCount
            let spendingChanged = abs(newTotalSpending - initialTotalSpending) > 0.01

            if countChanged || spendingChanged {
                print("✅ Data changed! Breakdowns: \(initialBreakdownCount) -> \(newBreakdownCount), Transactions: \(initialTransactionCount) -> \(newTransactionCount), Spending: €\(String(format: "%.2f", initialTotalSpending)) -> €\(String(format: "%.2f", newTotalSpending))")
                dataChanged = true
                break
            } else {
                print("ℹ️ No changes yet (breakdowns: \(newBreakdownCount), transactions: \(newTransactionCount), spending: €\(String(format: "%.2f", newTotalSpending)))")
            }
        }

        if !dataChanged {
            print("⚠️ No data changes after all retries - upload may have failed or still processing")
        }

        // Sync rate limit status
        await rateLimitManager.syncFromBackend()
        print("✅ Data and rate limit refreshed after Share Extension upload")

        // Update UI on main thread and always reset isReceiptUploading
        await MainActor.run {
            // Always clear syncing indicator and running flag
            isReceiptUploading = false
            isRefreshWithRetryRunning = false

            // Keep period in loadedReceiptPeriods to prevent duplicate loads
            // The loadReceipts call with reset:true will refresh the data

            // Notify other views that share extension sync is complete
            NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)

            // Always update displayed breakdowns to ensure UI reflects latest data
            // The filter inside updateDisplayedBreakdowns will handle period matching
            print("📊 Updating display after sync (selectedPeriod: '\(selectedPeriod)', currentMonthPeriod: '\(currentMonthPeriod)')")
            updateDisplayedBreakdowns()

            // Update refresh time for "Updated X ago" display
            lastRefreshTime = Date()
        }

        // Reload receipts for current month if it's the selected period
        if selectedPeriod == currentMonthPeriod {
            await receiptsViewModel.loadReceipts(period: currentMonthPeriod, storeName: nil, reset: true)
        }
    }

    private var swipeableContentView: some View {
        GeometryReader { geometry in
            let gradientHeight = geometry.size.height * 0.38
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                // Background gradient
                LinearGradient(
                    stops: [
                        .init(color: headerPurpleColor, location: 0.0),
                        .init(color: headerPurpleColor.opacity(0.85), location: 0.12),
                        .init(color: headerPurpleColor.opacity(0.6), location: 0.25),
                        .init(color: headerPurpleColor.opacity(0.35), location: 0.4),
                        .init(color: headerPurpleColor.opacity(0.15), location: 0.55),
                        .init(color: headerPurpleColor.opacity(0.05), location: 0.7),
                        .init(color: appBackgroundColor, location: 0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: gradientHeight)
                .offset(y: -scrollOffset * 0.6)
                .opacity(max(0, 1.0 - scrollOffset / 200))
                .ignoresSafeArea(edges: .top)

                // Main content with vertical scroll
                mainContentView(bottomSafeArea: bottomSafeArea)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    /// Swipe gesture for navigating between periods
    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                // Only trigger if horizontal movement is significantly greater than vertical
                let horizontalAmount = value.translation.width
                let verticalAmount = abs(value.translation.height)

                // Require horizontal to be at least 2x vertical movement
                guard abs(horizontalAmount) > verticalAmount * 2 else { return }
                guard abs(horizontalAmount) > 50 else { return }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if horizontalAmount > 0 {
                        // Swipe right -> go to previous (older) period
                        goToPreviousPeriod()
                    } else {
                        // Swipe left -> go to next (newer) period
                        goToNextPeriod()
                    }
                }
            }
    }

    // MARK: - Main Content View
    private func mainContentView(bottomSafeArea: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                overviewContentForPeriod(selectedPeriod)
                receiptsSection
            }
            .padding(.top, 16)
            .padding(.bottom, bottomSafeArea + 90)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: -proxy.frame(in: .named("scrollView")).origin.y
                        )
                }
            )
            .simultaneousGesture(periodSwipeGesture)
        }
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            if abs(value - scrollOffset) > 2 {
                scrollOffset = value
            }
        }
    }

    // MARK: - Header Purple Color
    private var headerPurpleColor: Color {
        Color(red: 0.35, green: 0.10, blue: 0.60) // Deeper, richer purple
    }

    // MARK: - Background Color
    private var appBackgroundColor: Color {
        Color(white: 0.05) // Match scan and milo views - almost black
    }

    // MARK: - Modern Period Navigation (Toolbar version with adjacent periods)
    private var modernPeriodNavigationToolbar: some View {
        HStack(spacing: 12) {
            // Previous period (faded left)
            if canGoToPreviousPeriod {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedPeriod = availablePeriods[currentPeriodIndex - 1]
                    }
                } label: {
                    Text(shortenedPeriod(availablePeriods[currentPeriodIndex - 1]).uppercased())
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.8)
                }
            }

            // Current period (center pill)
            Text(selectedPeriod.uppercased())
                .font(.system(size: 13, weight: .bold, design: .default))
                .foregroundColor(.white)
                .tracking(1.5)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.25), value: selectedPeriod)

            // Next period (faded right)
            if canGoToNextPeriod {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedPeriod = availablePeriods[currentPeriodIndex + 1]
                    }
                } label: {
                    Text(shortenedPeriod(availablePeriods[currentPeriodIndex + 1]).uppercased())
                        .font(.system(size: 11, weight: .medium, design: .default))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.8)
                }
            }
        }
    }

    // Shorten period to "Jan 26" format
    private func shortenedPeriod(_ period: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")

        guard let date = dateFormatter.date(from: period) else { return period }

        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM yy"
        shortFormatter.locale = Locale(identifier: "en_US")
        return shortFormatter.string(from: date)
    }


    // MARK: - Overview Content
    private func overviewContentForPeriod(_ period: String) -> some View {
        let breakdowns = getCachedBreakdowns(for: period)
        let segments = storeSegmentsForPeriod(period)

        // All Overview components fade in together at the same time
        return VStack(spacing: 16) {
            spendingAndHealthCardForPeriod(period)

            if !segments.isEmpty {
                // Pie chart showing store breakdown - use cached chart data
                IconDonutChartView(
                    data: chartDataForPeriod(period),
                    totalAmount: Double(totalReceiptsForPeriod(period)),
                    size: 200,
                    currencySymbol: "",
                    subtitle: "receipts"
                )
                .padding(.top, 16)
                .padding(.bottom, 8)

                // Store rows with staggered animation
                VStack(spacing: 8) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        StoreRowButton(
                            segment: segment,
                            breakdowns: breakdowns,
                            onSelect: { selectedBreakdown = $0 }
                        )
                        .opacity(storeRowsAppeared ? 1 : 0)
                        .offset(y: storeRowsAppeared ? 0 : 15)
                        .animation(
                            Animation.spring(response: 0.5, dampingFraction: 0.8)
                                .delay(Double(index) * 0.08),
                            value: storeRowsAppeared
                        )
                    }
                }
                .padding(.horizontal, 16)
                .onAppear {
                    // Trigger staggered animation when view appears
                    if !storeRowsAppeared {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation {
                                storeRowsAppeared = true
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Store Segments for Period (Cached)
    private func storeSegmentsForPeriod(_ period: String) -> [StoreChartSegment] {
        // Return cached segments if available
        if let cached = cachedSegmentsByPeriod[period] {
            return cached
        }

        // Compute and cache segments
        let segments = computeStoreSegments(for: period)
        // Note: Can't mutate state during render, so we cache in rebuildBreakdownCache
        return segments
    }

    /// Compute store segments for a period (expensive - cache result)
    private func computeStoreSegments(for period: String) -> [StoreChartSegment] {
        let breakdowns = getCachedBreakdowns(for: period)
        let totalSpend = totalSpendForPeriod(period)

        guard totalSpend > 0 else { return [] }

        var currentAngle: Double = 0
        let colors: [Color] = [
            Color(red: 0.3, green: 0.7, blue: 1.0),   // Blue
            Color(red: 0.4, green: 0.8, blue: 0.5),   // Green
            Color(red: 1.0, green: 0.7, blue: 0.3),   // Orange
            Color(red: 0.9, green: 0.4, blue: 0.6),   // Pink
            Color(red: 0.7, green: 0.5, blue: 1.0),   // Purple
            Color(red: 0.3, green: 0.9, blue: 0.9),   // Cyan
            Color(red: 1.0, green: 0.6, blue: 0.4),   // Coral
            Color(red: 0.6, green: 0.9, blue: 0.4),   // Lime
        ]

        return breakdowns.enumerated().map { index, breakdown in
            let percentage = breakdown.totalStoreSpend / totalSpend
            let angleRange = 360.0 * percentage
            let segment = StoreChartSegment(
                startAngle: .degrees(currentAngle),
                endAngle: .degrees(currentAngle + angleRange),
                color: colors[index % colors.count],
                storeName: breakdown.storeName,
                amount: breakdown.totalStoreSpend,
                percentage: Int(percentage * 100),
                healthScore: breakdown.averageHealthScore
            )
            currentAngle += angleRange
            return segment
        }
    }

    /// Pre-compute and cache segments for a period (call after rebuilding breakdown cache)
    private func cacheSegmentsForPeriod(_ period: String) {
        let segments = computeStoreSegments(for: period)
        cachedSegmentsByPeriod[period] = segments
        // Also cache the chart data to avoid recomputing during render
        cachedChartDataByPeriod[period] = segments.toIconChartData()
    }

    /// Get cached chart data for a period
    private func chartDataForPeriod(_ period: String) -> [ChartData] {
        if let cached = cachedChartDataByPeriod[period] {
            return cached
        }
        // Fallback: compute from segments (shouldn't happen if caching is working)
        return storeSegmentsForPeriod(period).toIconChartData()
    }

    // MARK: - Receipts Section State
    private enum ReceiptsSectionState {
        case loading
        case empty
        case hasData
    }

    private var receiptsSectionState: ReceiptsSectionState {
        let isLoading = receiptsViewModel.state.isLoading
        let hasLoadedSuccessfully = receiptsViewModel.state.value != nil
        let hasError = receiptsViewModel.state.error != nil
        let hasFinishedLoading = hasLoadedSuccessfully || hasError

        if (isLoading || !hasFinishedLoading) && receiptsViewModel.receipts.isEmpty {
            return .loading
        } else if hasFinishedLoading && receiptsViewModel.receipts.isEmpty {
            return .empty
        } else {
            return .hasData
        }
    }

    // MARK: - Receipts Section (Modern inline display)
    private var receiptsSection: some View {
        VStack(spacing: 16) {
            // Section header
            HStack {
                Text("RECEIPTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                    .tracking(1.5)

                Spacer()

                if !receiptsViewModel.receipts.isEmpty {
                    Text("\(receiptsViewModel.receipts.count)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)

            switch receiptsSectionState {
            case .loading:
                // Loading state
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                        .scaleEffect(0.8)
                    Text("Loading receipts...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)

            case .empty:
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 28))
                        .foregroundColor(.white.opacity(0.2))
                    Text("No receipts for this period")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)

            case .hasData:
                // Modern receipt cards
                LazyVStack(spacing: 8) {
                    ForEach(sortedReceipts) { receipt in
                        ModernReceiptCard(
                            receipt: receipt,
                            isExpanded: expandedReceiptId == receipt.id,
                            onTap: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    if expandedReceiptId == receipt.id {
                                        expandedReceiptId = nil
                                    } else {
                                        expandedReceiptId = receipt.id
                                    }
                                }
                            },
                            onDelete: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    deleteReceiptFromOverview(receipt)
                                }
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                    }

                    // Load more indicator
                    if receiptsViewModel.hasMorePages {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                            .scaleEffect(0.8)
                            .padding(.vertical, 16)
                            .onAppear {
                                Task {
                                    await receiptsViewModel.loadNextPage(period: selectedPeriod, storeName: nil)
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .overlay {
            if isDeletingReceipt {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Deleting...")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.12))
                    )
                }
            }
        }
        .alert("Delete Failed", isPresented: Binding<Bool>(
            get: { receiptDeleteError != nil },
            set: { if !$0 { receiptDeleteError = nil } }
        )) {
            Button("OK") {
                receiptDeleteError = nil
            }
        } message: {
            Text(receiptDeleteError ?? "An error occurred")
        }
    }

    /// Receipts sorted from newest to oldest
    private var sortedReceipts: [APIReceipt] {
        receiptsViewModel.receipts.sorted { receipt1, receipt2 in
            // Parse dates and sort descending (newest first)
            let date1 = receipt1.dateParsed ?? Date.distantPast
            let date2 = receipt2.dateParsed ?? Date.distantPast
            return date1 > date2
        }
    }

    /// Delete a receipt from the overview
    private func deleteReceiptFromOverview(_ receipt: APIReceipt) {
        isDeletingReceipt = true

        Task {
            do {
                try await receiptsViewModel.deleteReceipt(receipt, period: selectedPeriod, storeName: nil)
            } catch {
                receiptDeleteError = error.localizedDescription
            }

            isDeletingReceipt = false
        }
    }

    // Period-specific versions of the cards to ensure proper data display
    // Uses cached breakdowns for performance - avoids recalculating on every render
    private func breakdownsForPeriod(_ period: String) -> [StoreBreakdown] {
        // Use cached data if available
        if let cached = cachedBreakdownsByPeriod[period], !cached.isEmpty {
            return cached
        }

        // Fallback: calculate if not yet available (always sorted by highest spending)
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == period }
        breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        return breakdowns
    }

    private func totalSpendForPeriod(_ period: String) -> Double {
        // First check period metadata (from lightweight /analytics/periods)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.totalSpend
        }
        // Fallback to cached values or calculated sum
        return dataManager.periodTotalSpends[period] ?? breakdownsForPeriod(period).reduce(0) { $0 + $1.totalStoreSpend }
    }

    private func totalReceiptsForPeriod(_ period: String) -> Int {
        // First check period metadata (from lightweight /analytics/periods)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.receiptCount
        }
        // Fallback to cached values or calculated sum
        return dataManager.periodReceiptCounts[period] ?? breakdownsForPeriod(period).reduce(0) { $0 + $1.visitCount }
    }

    private func healthScoreForPeriod(_ period: String) -> Double? {
        // First check period metadata (from lightweight /analytics/periods)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.averageHealthScore
        }
        // Fallback to dataManager's health score for selected period
        return dataManager.averageHealthScore
    }

    /// Combined spending and health score card with dynamic color accent
    private func spendingAndHealthCardForPeriod(_ period: String) -> some View {
        let spending = totalSpendForPeriod(period)
        let healthScore = healthScoreForPeriod(period)
        let accentColor = healthScore?.healthScoreColor ?? Color.white.opacity(0.5)

        return VStack(spacing: 0) {
            // Main content area
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showTrendlineInOverview.toggle()
                }
                if showTrendlineInOverview && !hasFetchedTrends {
                    Task { await fetchOverviewTrends() }
                }
            } label: {
                if showTrendlineInOverview {
                    // Trendline view
                    VStack(spacing: 8) {
                        Text("Spending Trends")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.2)

                        if isLoadingTrends {
                            VStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                Text("Loading trends...")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(height: 160)
                        } else if overviewTrends.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No trend data")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(height: 160)
                        } else {
                            StoreTrendLineChart(
                                trends: overviewTrends,
                                size: 140,
                                totalAmount: spending,
                                accentColor: accentColor,
                                selectedPeriod: period,
                                isVisible: true
                            )
                        }

                        HStack(spacing: 4) {
                            Image(systemName: "eurosign.circle.fill")
                                .font(.system(size: 11))
                            Text("Tap for Total")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.5))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                } else {
                    // Total spending view with health score
                    VStack(spacing: 16) {
                        // Spending section
                        VStack(spacing: 4) {
                            Text("Total Spending")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .textCase(.uppercase)
                                .tracking(1.2)

                            Text(String(format: "€%.0f", spending))
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spending)
                        }

                        // Modern health score display
                        if let score = healthScore {
                            ModernHealthScoreBadge(score: score)
                        }

                        // Syncing indicator or tap hint
                        HStack(spacing: 4) {
                            if isCurrentPeriod && (dataManager.isLoading || isReceiptUploading) {
                                SyncingArrowsView()
                                    .font(.system(size: 11))
                                Text("Syncing...")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 11))
                                Text("Tap for Trends")
                                    .font(.system(size: 12, weight: .medium))
                            }
                        }
                        .foregroundColor(isCurrentPeriod && (dataManager.isLoading || isReceiptUploading) ? .blue : .white.opacity(0.4))
                    }
                    .padding(.vertical, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(TotalSpendingCardButtonStyle())
        }
        .background(
            ZStack {
                // Base layer - darker for depth
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.03))

                // Gradient overlay for glass effect
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Inner glow at top
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.15),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 16)
    }

    private var currentPeriodIndex: Int {
        availablePeriods.firstIndex(of: selectedPeriod) ?? 0
    }

    private var canGoToPreviousPeriod: Bool {
        currentPeriodIndex > 0
    }

    private var canGoToNextPeriod: Bool {
        currentPeriodIndex < availablePeriods.count - 1
    }

    private func goToPreviousPeriod() {
        guard canGoToPreviousPeriod else { return }
        withAnimation {
            selectedPeriod = availablePeriods[currentPeriodIndex - 1]
        }
    }

    private func goToNextPeriod() {
        guard canGoToNextPeriod else { return }
        withAnimation {
            selectedPeriod = availablePeriods[currentPeriodIndex + 1]
        }
    }
}

// MARK: - Store Row Button (Optimized)
/// Extracted to its own view for better performance - avoids recreating closures on every render
private struct StoreRowButton: View {
    let segment: StoreChartSegment
    let breakdowns: [StoreBreakdown]
    let onSelect: (StoreBreakdown) -> Void

    var body: some View {
        Button {
            // Find the matching breakdown - O(n) but only on tap, not on render
            if let breakdown = breakdowns.first(where: { $0.storeName == segment.storeName }) {
                onSelect(breakdown)
            }
        } label: {
            HStack(spacing: 12) {
                // Color accent bar on the left
                RoundedRectangle(cornerRadius: 2)
                    .fill(segment.color)
                    .frame(width: 4, height: 32)

                // Store name
                Text(segment.storeName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Percentage badge
                Text("\(segment.percentage)%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(segment.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(segment.color.opacity(0.15))
                    )

                // Amount
                Text(String(format: "€%.0f", segment.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 65, alignment: .trailing)

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.25))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Base glass effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.04))

                    // Subtle gradient
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.06),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    // Colored accent glow on the left
                    HStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        segment.color.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60)
                        Spacer()
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.1),
                                Color.white.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(OverviewStoreRowButtonStyle())
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSort: SortOption

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                List {
                    Section {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedSort == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Sort By")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scroll Offset Preference Key
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Animated Number Text
/// Smoothly animates number changes with a counting effect
struct AnimatedNumberText: View {
    let value: Double
    let format: String
    let prefix: String
    let font: Font
    let color: Color

    @State private var displayValue: Double = 0

    var body: some View {
        Text("\(prefix)\(String(format: format, displayValue))")
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                displayValue = value
            }
            .onChange(of: value) { oldValue, newValue in
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    displayValue = newValue
                }
            }
    }
}

// MARK: - Period Dots View
/// Shows page indicator dots for period navigation
/// Uses a sliding window approach for many periods
struct PeriodDotsView: View {
    let totalCount: Int
    let currentIndex: Int

    private let maxVisibleDots = 5

    var body: some View {
        HStack(spacing: 4) {
            if totalCount <= maxVisibleDots {
                // Show all dots if 5 or fewer periods
                ForEach(0..<totalCount, id: \.self) { index in
                    dotView(for: index, isActive: index == currentIndex)
                }
            } else {
                // Sliding window for many periods
                let (startIndex, endIndex) = visibleRange

                // Leading indicator if not at start
                if startIndex > 0 {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 3, height: 3)
                }

                ForEach(startIndex..<endIndex, id: \.self) { index in
                    dotView(for: index, isActive: index == currentIndex)
                }

                // Trailing indicator if not at end
                if endIndex < totalCount {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 3, height: 3)
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentIndex)
    }

    private var visibleRange: (start: Int, end: Int) {
        let halfWindow = maxVisibleDots / 2

        var start = currentIndex - halfWindow
        var end = currentIndex + halfWindow + 1

        // Adjust if at edges
        if start < 0 {
            end -= start
            start = 0
        }
        if end > totalCount {
            start -= (end - totalCount)
            end = totalCount
        }
        start = max(0, start)

        return (start, end)
    }

    private func dotView(for index: Int, isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? Color.white : Color.white.opacity(0.25))
            .frame(width: isActive ? 6 : 4, height: isActive ? 6 : 4)
    }
}

// MARK: - Period Navigation Button Style
struct PeriodNavButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.15 : 0))
                    .scaleEffect(configuration.isPressed ? 1.0 : 0.8)
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Total Spending Card Button Style
struct TotalSpendingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Overview Store Row Button Style
struct OverviewStoreRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Syncing Arrows View
struct SyncingArrowsView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let rotation = seconds.truncatingRemainder(dividingBy: 1.0) * 360

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 11, weight: .semibold))
                .rotationEffect(.degrees(rotation))
        }
    }
}

// MARK: - Modern Receipt Card
/// A compact receipt card that expands inline to show all items
struct ModernReceiptCard: View {
    let receipt: APIReceipt
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirmation = false

    private var formattedDate: String {
        guard let date = receipt.dateParsed else { return receipt.receiptDate ?? "Unknown" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        guard let date = receipt.dateParsed else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var itemCount: Int {
        receipt.itemsCount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content - always visible
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Store icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)

                        Image(systemName: "cart.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    // Store name and date
                    VStack(alignment: .leading, spacing: 4) {
                        Text(receipt.storeName ?? "Unknown Store")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            if !formattedTime.isEmpty {
                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(formattedTime)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    Spacer()

                    // Total amount
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "€%.2f", receipt.totalAmount ?? 0))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 20)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(ReceiptCardButtonStyle())

            // Expanded content - show ALL items
            if isExpanded {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 14)

                    // All items
                    if !receipt.transactions.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(receipt.transactions) { item in
                                HStack {
                                    Text(item.itemName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(2)

                                    Spacer()

                                    if item.quantity > 1 {
                                        Text("×\(item.quantity)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.4))
                                    }

                                    Text(String(format: "€%.2f", item.itemPrice))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }

                    // Delete button only
                    Button {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                                .font(.system(size: 13, weight: .medium))
                            Text("Delete Receipt")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.red.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.08))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(isExpanded ? 0.12 : 0.08), lineWidth: 1)
        )
        .confirmationDialog("Delete Receipt", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this receipt? This action cannot be undone.")
        }
    }
}

// MARK: - Receipt Card Button Style
struct ReceiptCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.03 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Modern Health Score Badge
struct ModernHealthScoreBadge: View {
    let score: Double

    // Color based on score: red (poor) → orange → yellow → green (excellent)
    private var scoreColor: Color {
        switch score {
        case 0..<3:
            return Color(red: 0.95, green: 0.3, blue: 0.3) // Red - E
        case 3..<5:
            return Color(red: 1.0, green: 0.55, blue: 0.2) // Orange - D
        case 5..<6.5:
            return Color(red: 1.0, green: 0.8, blue: 0.2) // Yellow - C
        case 6.5..<8:
            return Color(red: 0.5, green: 0.85, blue: 0.4) // Light green - B
        default:
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Green - A
        }
    }

    // Grade letter based on score (A, B, C, D, E)
    private var gradeLabel: String {
        switch score {
        case 8...:
            return "A"
        case 6.5..<8:
            return "B"
        case 5..<6.5:
            return "C"
        case 3..<5:
            return "D"
        default:
            return "E"
        }
    }

    private var scoreProgress: Double {
        score / 10.0
    }

    var body: some View {
        HStack(spacing: 14) {
            // Circular progress ring with letter grade inside
            ZStack {
                // Background ring
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 3.5)
                    .frame(width: 44, height: 44)

                // Progress ring
                Circle()
                    .trim(from: 0, to: scoreProgress)
                    .stroke(
                        scoreColor,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .frame(width: 44, height: 44)
                    .rotationEffect(.degrees(-90))

                // Letter grade in the middle of the circle
                Text(gradeLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
            }

            // Score number and label in the center
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f", score))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Nutri Score")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                // Glass base
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.04))

                // Gradient overlay
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                scoreColor.opacity(0.12),
                                scoreColor.opacity(0.03)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [
                            scoreColor.opacity(0.3),
                            scoreColor.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    NavigationStack {
        OverviewView(
            dataManager: StoreDataManager(),
            showSignOutConfirmation: .constant(false)
        )
        .environmentObject(TransactionManager())
        .environmentObject(AuthenticationManager())
    }
    .preferredColorScheme(.dark)
}
