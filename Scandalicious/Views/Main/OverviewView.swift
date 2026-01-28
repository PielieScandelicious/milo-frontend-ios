//
//
//  OverviewView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import UIKit
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
    @State private var showingHealthScoreTransactions = false
    @State private var lastRefreshTime: Date?
    @State private var cachedBreakdownsByPeriod: [String: [StoreBreakdown]] = [:]  // Cache for period breakdowns
    @State private var displayedBreakdownsPeriod: String = ""  // Track which period displayedBreakdowns belongs to
    @State private var overviewTrends: [TrendPeriod] = []  // Trends for the overview chart
    @State private var isLoadingTrends = false
    @State private var expandedReceiptId: String? // For inline receipt expansion
    @State private var isDeletingReceipt = false
    @State private var receiptDeleteError: String?
    @State private var scrollOffset: CGFloat = 0 // Track scroll for header fade effect
    @State private var hasLoadedReceiptsOnce = false // Track if receipts have been loaded at least once
    @State private var cachedAvailablePeriods: [String] = [] // Cached for performance
    @State private var cachedSegmentsByPeriod: [String: [StoreChartSegment]] = [:] // Cache segments
    @State private var cachedChartDataByPeriod: [String: [ChartData]] = [:] // Cache chart data for IconDonutChart
    @State private var lastBreakdownsHash: Int = 0 // Track if breakdowns changed
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
        // Use cached version for performance
        if !cachedAvailablePeriods.isEmpty {
            return cachedAvailablePeriods
        }
        return computeAvailablePeriods()
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

    private var healthScoreTransactionsDestination: some View {
        TransactionListView(
            storeName: "All Stores",
            period: selectedPeriod,
            category: nil,
            categoryColor: nil,
            sortOrder: .healthScoreDescending
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
            .navigationDestination(isPresented: $showingHealthScoreTransactions) {
                healthScoreTransactionsDestination
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
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                checkForShareExtensionUploads()
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
                prefetchInsights()
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

        // CRITICAL: Update periods cache FIRST (fast - just a map operation)
        // This prevents multiple computeAvailablePeriods() calls during initial render
        if cachedAvailablePeriods.isEmpty {
            cachedAvailablePeriods = computeAvailablePeriods()
        }

        // Defer heavier work to next run loop to allow smooth tab transition
        Task { @MainActor in
            // Small delay to let the tab animation complete
            try? await Task.sleep(for: .milliseconds(30))

            // Build breakdown caches from preloaded data
            rebuildBreakdownCache()

            // Load share extension timestamps (UserDefaults I/O)
            loadShareExtensionTimestamps()

            // Check for share extension uploads
            checkForShareExtensionUploads()
        }

        // Load receipts for current period
        Task {
            await receiptsViewModel.loadReceipts(period: selectedPeriod, storeName: nil, reset: true)
            hasLoadedReceiptsOnce = true
        }

        // Sync rate limit in background
        Task {
            await rateLimitManager.syncFromBackend()
        }

        // Fetch trends in background
        Task {
            await fetchOverviewTrends()
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
        Task {
            try? await Task.sleep(for: .seconds(1))
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            let currentMonthPeriod = dateFormatter.string(from: Date())

            await dataManager.refreshData(for: .month, periodString: currentMonthPeriod)

            if selectedPeriod == currentMonthPeriod {
                updateDisplayedBreakdowns()
            }
            await rateLimitManager.syncFromBackend()
        }
    }

    private func handleTransactionsChanged(oldValue: [Transaction], newValue: [Transaction]) {
        dataManager.regenerateBreakdowns()
        updateDisplayedBreakdowns()

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

        // Show loading indicator while switching periods
        hasLoadedReceiptsOnce = false

        // Immediately update displayed breakdowns for the new period (no async delay)
        updateDisplayedBreakdowns()

        // Pre-cache segments for the new period if not already cached
        if cachedSegmentsByPeriod[newValue] == nil {
            cacheSegmentsForPeriod(newValue)
        }

        Task { @MainActor in
            prefetchInsights()
            await receiptsViewModel.loadReceipts(period: newValue, storeName: nil, reset: true)
            hasLoadedReceiptsOnce = true

            if !dataManager.periodMetadata.isEmpty {
                if !dataManager.isPeriodLoaded(newValue) {
                    await dataManager.fetchPeriodDetails(newValue)
                    updateCacheForPeriod(newValue)
                    // Cache segments after fetching new data
                    cacheSegmentsForPeriod(newValue)
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

    /// Fetches trends data for the overview chart
    private func fetchOverviewTrends() async {
        guard !isLoadingTrends else { return }
        isLoadingTrends = true
        defer { isLoadingTrends = false }

        do {
            let response = try await AnalyticsAPIService.shared.getTrends(periodType: .month, numPeriods: 52)
            await MainActor.run {
                self.overviewTrends = response.periods
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

            // Notify other views that share extension sync is complete
            NotificationCenter.default.post(name: .receiptUploadedSuccessfully, object: nil)

            // Always update displayed breakdowns to ensure UI reflects latest data
            // The filter inside updateDisplayedBreakdowns will handle period matching
            print("📊 Updating display after sync (selectedPeriod: '\(selectedPeriod)', currentMonthPeriod: '\(currentMonthPeriod)')")
            updateDisplayedBreakdowns()

            // Update refresh time for "Updated X ago" display
            lastRefreshTime = Date()

            // Add haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(dataChanged ? .success : .warning)
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
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
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
            totalSpendingCardForPeriod(period)

            healthScoreCardForPeriod(period)

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

                // Store rows - use segment.id directly, avoid enumerated()
                VStack(spacing: 8) {
                    ForEach(segments) { segment in
                        StoreRowButton(
                            segment: segment,
                            breakdowns: breakdowns,
                            onSelect: { selectedBreakdown = $0 }
                        )
                    }
                }
                .padding(.horizontal, 16)
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

            if !hasLoadedReceiptsOnce || (receiptsViewModel.state.isLoading && receiptsViewModel.receipts.isEmpty) {
                // Loading state - show on first load or when loading with no data
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
            } else if receiptsViewModel.receipts.isEmpty {
                // Compact empty state
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
            } else {
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
                                let generator = UIImpactFeedbackGenerator(style: .light)
                                generator.impactOccurred()
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
        .alert("Delete Failed", isPresented: .constant(receiptDeleteError != nil)) {
            Button("OK") {
                receiptDeleteError = nil
            }
        } message: {
            if let error = receiptDeleteError {
                Text(error)
            }
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

                // Haptic feedback for successful deletion
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } catch {
                receiptDeleteError = error.localizedDescription

                // Haptic feedback for failure
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
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

    private func totalSpendingCardForPeriod(_ period: String) -> some View {
        let spending = totalSpendForPeriod(period)

        return Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showTrendlineInOverview.toggle()
            }
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            Group {
                if showTrendlineInOverview {
                    // Trendline view
                    VStack(spacing: 8) {
                        Text("Spending Trends")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.2)

                        if overviewTrends.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No trend data")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .frame(height: 180)
                        } else {
                            StoreTrendLineChart(
                                trends: overviewTrends,
                                size: 160,
                                totalAmount: spending,
                                accentColor: Color(red: 0.95, green: 0.25, blue: 0.3),
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
                    // Total spending view
                    VStack(spacing: 6) {
                        Text("Total Spending")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .textCase(.uppercase)
                            .tracking(1.2)

                        Text(String(format: "€%.0f", spending))
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        // Syncing/Synced indicator inline (only show syncing on current period)
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
                        .foregroundColor(isCurrentPeriod && (dataManager.isLoading || isReceiptUploading) ? .blue : .white.opacity(0.5))
                    }
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(TotalSpendingCardButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    private func healthScoreCardForPeriod(_ period: String) -> some View {
        let averageScore: Double? = healthScoreForPeriod(period)

        return Button {
            showingHealthScoreTransactions = true
        } label: {
            HStack(spacing: 16) {
                LiquidGaugeView(
                    score: averageScore,
                    size: 70,
                    showLabel: false
                )
                .drawingGroup() // Pre-rasterize gauge for smoother rendering

                VStack(alignment: .leading, spacing: 4) {
                    Text("Health Score")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(1.0)

                    if let score = averageScore {
                        HStack(spacing: 4) {
                            Text(score.formattedHealthScore)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("/ 5.0")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }

                        Text(score.healthScoreLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(score.healthScoreColor)
                            .lineLimit(1)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(score.healthScoreColor.opacity(0.15))
                            )
                    } else {
                        Text("No Data")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .buttonStyle(TotalSpendingCardButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
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
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    private func goToNextPeriod() {
        guard canGoToNextPeriod else { return }
        withAnimation {
            selectedPeriod = availablePeriods[currentPeriodIndex + 1]
        }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
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
            HStack {
                Circle()
                    .fill(segment.color)
                    .frame(width: 10, height: 10)

                Text(segment.storeName.uppercased())
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text("\(segment.percentage)%")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 40, alignment: .trailing)

                Text(String(format: "€%.0f", segment.amount))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
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
