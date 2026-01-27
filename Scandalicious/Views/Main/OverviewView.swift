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

// MARK: - Header Tab Options
enum HeaderTab: String, CaseIterable {
    case overview = "Overview"
    case receipts = "Receipts"
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
    @State private var selectedHeaderTab: HeaderTab = .overview
    @State private var showingFilterSheet = false
    @State private var displayedBreakdowns: [StoreBreakdown] = []
    @State private var selectedBreakdown: StoreBreakdown?
    @State private var showingAllTransactions = false
    @State private var showTrendlineInOverview = false  // Toggle between pie chart and trendline
    @State private var showingHealthScoreTransactions = false
    @State private var showingProfileMenu = false
    @State private var lastRefreshTime: Date?
    @State private var cachedBreakdownsByPeriod: [String: [StoreBreakdown]] = [:]  // Cache for period breakdowns
    @State private var displayedBreakdownsPeriod: String = ""  // Track which period displayedBreakdowns belongs to
    @State private var hasWarmedAdjacentViews = false  // Track if adjacent page views have been pre-rendered
    @State private var overviewTrends: [TrendPeriod] = []  // Trends for the overview chart
    @State private var isLoadingTrends = false
    @State private var selectedReceiptForDetail: APIReceipt?
    @State private var showingReceiptDetail = false
    @State private var isDeletingReceipt = false
    @State private var receiptDeleteError: String?
    @State private var scrollOffset: CGFloat = 0 // Track scroll for header fade effect
    @Binding var showSignOutConfirmation: Bool

    // Receipt limit status icon
    private var receiptLimitIcon: String {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .exhausted:
            return "xmark.circle.fill"
        }
    }

    // Receipt limit status color
    private var receiptLimitColor: Color {
        switch rateLimitManager.receiptLimitState {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .exhausted:
            return .red
        }
    }

    // Check if the selected period is the current month
    private var isCurrentPeriod: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentPeriod = dateFormatter.string(from: Date())
        return selectedPeriod == currentPeriod
    }

    private var availablePeriods: [String] {
        // Use period metadata if available (from lightweight /analytics/periods endpoint)
        if !dataManager.periodMetadata.isEmpty {
            // Period metadata is already sorted by backend (most recent first)
            // Reverse to get oldest first (left), most recent last (right) for swipe UX
            return dataManager.periodMetadata.map { $0.period }.reversed()
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

    /// Adjacent periods that need view pre-warming for smooth swiping
    /// Returns 1 period before and 1 period after the current selection
    private var adjacentPeriodsToWarm: [String] {
        guard let currentIndex = availablePeriods.firstIndex(of: selectedPeriod) else { return [] }
        var periods: [String] = []

        // Previous period (older - to the left)
        if currentIndex > 0 {
            periods.append(availablePeriods[currentIndex - 1])
        }
        // Next period (newer - to the right)
        if currentIndex < availablePeriods.count - 1 {
            periods.append(availablePeriods[currentIndex + 1])
        }
        return periods
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
    private func rebuildBreakdownCache() {
        var newCache: [String: [StoreBreakdown]] = [:]

        // Group breakdowns by period
        let groupedByPeriod = Dictionary(grouping: dataManager.storeBreakdowns) { $0.period }

        for (period, periodBreakdowns) in groupedByPeriod {
            var sorted = periodBreakdowns

            // Always sort by highest spending for clear visual hierarchy
            sorted.sort { $0.totalStoreSpend > $1.totalStoreSpend }

            newCache[period] = sorted
        }

        cachedBreakdownsByPeriod = newCache

        // Also update displayedBreakdowns for the current period
        displayedBreakdowns = newCache[selectedPeriod] ?? []
        displayedBreakdownsPeriod = selectedPeriod
    }

    /// Update cache for a specific period only
    private func updateCacheForPeriod(_ period: String) {
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == period }

        // Always sort by highest spending for clear visual hierarchy
        breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }

        cachedBreakdownsByPeriod[period] = breakdowns

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

    var body: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()

            if let error = dataManager.error {
                // Error state
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
            } else {
                swipeableContentView
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedBreakdown) { breakdown in
            StoreDetailView(storeBreakdown: breakdown)
        }
        .navigationDestination(isPresented: $showingAllTransactions) {
            TransactionListView(
                storeName: "All Stores",
                period: selectedPeriod,
                category: nil,
                categoryColor: nil
            )
        }
        .navigationDestination(isPresented: $showingHealthScoreTransactions) {
            TransactionListView(
                storeName: "All Stores",
                period: selectedPeriod,
                category: nil,
                categoryColor: nil,
                sortOrder: .healthScoreDescending
            )
        }
        .navigationDestination(isPresented: $showingReceiptDetail) {
            if let receipt = selectedReceiptForDetail {
                ReceiptTransactionsView(receipt: receipt)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedSort: $selectedSort
            )
        }
        .onAppear {
            // Configure with transaction manager if not already configured
            if dataManager.transactionManager == nil {
                dataManager.configure(with: transactionManager)
            }
            // Build the cache for all periods on first appear
            rebuildBreakdownCache()

            // Initialize lastCheckedUploadTimestamp from persistent storage on first appear
            // This prevents re-detecting old uploads as "new" on app launch
            if lastCheckedUploadTimestamp == 0 {
                let appGroupIdentifier = "group.com.deepmaind.scandalicious"
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    // First try to load from persisted lastCheckedUploadTimestamp
                    let persistedLastChecked = sharedDefaults.double(forKey: "lastCheckedUploadTimestamp")
                    if persistedLastChecked > 0 {
                        lastCheckedUploadTimestamp = persistedLastChecked
                        print("📋 Restored lastCheckedUploadTimestamp from storage: \(persistedLastChecked)")
                    } else {
                        // Fall back to current upload timestamp to prevent detecting old uploads as new
                        let existingTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
                        if existingTimestamp > 0 {
                            lastCheckedUploadTimestamp = existingTimestamp
                            // Also persist it so future checks use this value
                            sharedDefaults.set(existingTimestamp, forKey: "lastCheckedUploadTimestamp")
                            print("📋 Initialized lastCheckedUploadTimestamp to current upload timestamp: \(existingTimestamp)")
                        }
                    }
                }
            }

            // Check for Share Extension uploads when view appears
            // This handles the case when user switches tabs
            checkForShareExtensionUploads()

            // Fetch rate limit status when view appears
            Task {
                await rateLimitManager.syncFromBackend()
            }

            // Fetch trends for the overview chart
            Task {
                await fetchOverviewTrends()
            }

            // Prefetch daily insights in background
            prefetchInsights()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadStarted)) { _ in
            print("📤 Received receipt upload started notification")
            isReceiptUploading = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            print("📬 Received receipt upload notification - refreshing backend data")
            isReceiptUploading = false
            Task {
                // Wait a moment for backend to fully process
                try? await Task.sleep(for: .seconds(1))

                // Always refresh the CURRENT month since new receipts go into the current period
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                let currentMonthPeriod = dateFormatter.string(from: Date())

                await dataManager.refreshData(for: .month, periodString: currentMonthPeriod)

                // If viewing the current month, update displayed breakdowns
                if selectedPeriod == currentMonthPeriod {
                    updateDisplayedBreakdowns()
                }
                print("✅ Backend data refreshed after receipt upload for period: \(currentMonthPeriod)")

                // Also refresh rate limit status
                await rateLimitManager.syncFromBackend()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptDeleted)) { _ in
            print("🗑️ Received receipt deleted notification - refreshing backend data")
            Task {
                // Wait a moment for backend to process deletion
                try? await Task.sleep(for: .seconds(0.5))
                await dataManager.refreshData(for: .month, periodString: selectedPeriod)
                updateDisplayedBreakdowns()
                print("✅ Backend data refreshed after receipt deletion for period: \(selectedPeriod)")

                // Rate limit sync is already handled in ReceiptDetailsView, no need to sync again here
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDataDidChange)) { _ in
            print("🗑️ Received receiptsDataDidChange notification - refreshing backend data")
            Task {
                // Wait a moment for backend to process changes
                try? await Task.sleep(for: .seconds(0.5))
                await dataManager.refreshData(for: .month, periodString: selectedPeriod)
                updateDisplayedBreakdowns()
                print("✅ Backend data refreshed after receipts data change for period: \(selectedPeriod)")
            }
        }
        .onChange(of: dataManager.lastFetchDate) { _, newValue in
            // Set green highlight whenever data is fetched (initial load, refresh, etc.)
            if newValue != nil {
                lastRefreshTime = Date()
            }
        }
        .onChange(of: transactionManager.transactions) { oldValue, newValue in
            // Regenerate breakdowns when transactions change
            print("🔄 Transactions changed - regenerating breakdowns")
            print("   Old count: \(oldValue.count), New count: \(newValue.count)")
            dataManager.regenerateBreakdowns()
            updateDisplayedBreakdowns()
            
            // Update selected period to current month if we added new transactions
            if newValue.count > oldValue.count, let latestTransaction = newValue.first {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                let newPeriod = dateFormatter.string(from: latestTransaction.date)
                selectedPeriod = newPeriod
                print("   📅 Switched to period: \(newPeriod)")
            }
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            // Reset trendline toggle when changing periods (show pie chart)
            if showTrendlineInOverview {
                showTrendlineInOverview = false
            }

            // Always return to Overview tab when switching periods
            if selectedHeaderTab != .overview {
                selectedHeaderTab = .overview
            }

            // Defer non-critical work to after swipe animation completes
            // This prevents jank during the page transition
            Task { @MainActor in
                // Small delay to let the swipe animation complete
                try? await Task.sleep(for: .milliseconds(50))

                updateDisplayedBreakdowns()
                prefetchInsights()

                // Lazy load store breakdowns for this period if not already loaded
                if !dataManager.periodMetadata.isEmpty {
                    if !dataManager.isPeriodLoaded(newValue) {
                        await dataManager.fetchPeriodDetails(newValue)
                        // Update cache for the newly loaded period
                        updateCacheForPeriod(newValue)
                    }

                    // Prefetch adjacent periods for smooth swiping (2 in each direction)
                    await prefetchAdjacentPeriods(around: newValue)
                }

                // Re-warm adjacent views for the new period after animation settles
                // This ensures smooth swiping regardless of how far user navigated
                hasWarmedAdjacentViews = false
            }
        }
        .onChange(of: selectedSort) { oldValue, newValue in
            // Rebuild entire cache since sorting affects all periods
            rebuildBreakdownCache()
        }
        .onChange(of: selectedHeaderTab) { oldValue, newValue in
            // Load receipts when switching to the Receipts tab
            if newValue == .receipts {
                Task {
                    await receiptsViewModel.loadReceipts(period: selectedPeriod, storeName: nil, reset: true)
                }
            }
        }
        .onChange(of: dataManager.storeBreakdowns) { oldValue, newValue in
            // Rebuild cache when underlying data changes
            rebuildBreakdownCache()
            // Prefetch insights when data changes
            prefetchInsights()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Check for Share Extension uploads when app becomes active
            print("🔄 scenePhase changed: \(oldPhase) -> \(newPhase)")
            if newPhase == .active {
                checkForShareExtensionUploads()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // Backup: Also check when app becomes active via notification (more reliable)
            print("🔄 App became active (UIApplication notification)")
            checkForShareExtensionUploads()
        }
        .onReceive(NotificationCenter.default.publisher(for: .shareExtensionUploadDetected)) { _ in
            // Share extension upload detected (possibly from another view)
            // Note: isReceiptUploading is managed by checkForShareExtensionUploads, don't set it here
            print("📬 Received share extension upload notification")
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
                }
            }
        }
    }

    // MARK: - Share Extension Upload Detection

    /// Checks if the Share Extension uploaded a receipt while the app was in the background
    private func checkForShareExtensionUploads() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else {
            print("❌ Could not access shared UserDefaults with App Group: \(appGroupIdentifier)")
            return
        }

        // Check if there's a new upload timestamp
        let uploadTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
        print("📋 Share Extension check - uploadTimestamp: \(uploadTimestamp), lastChecked: \(lastCheckedUploadTimestamp)")

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
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Sort button
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSort = option
                        }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
            
            Spacer()
            
            // Profile button
            Menu {
                // User Email
                if let user = authManager.user {
                    Section {
                        Text(user.email ?? "No email")
                            .font(.headline)
                    }
                }

                // Receipt Upload Limit
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(rateLimitManager.receiptsRemaining)/\(rateLimitManager.receiptsLimit) receipts remaining")
                            Text(rateLimitManager.resetDaysFormatted)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    } icon: {
                        Image(systemName: receiptLimitIcon)
                            .foregroundColor(receiptLimitColor)
                    }
                }

                // Sign Out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Color(red: 0.0, green: 0.48, blue: 1.0))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
    }

    private var swipeableContentView: some View {
        GeometryReader { geometry in
            let gradientHeight = geometry.size.height * 0.32 + geometry.safeAreaInsets.top // 32% of screen + safe area

            ZStack(alignment: .top) {
                // Full-screen gradient background that fades from purple to black (like Apple Health)
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
                .offset(y: -scrollOffset * 0.6) // Parallax effect - scrolls away slower
                .opacity(max(0, 1.0 - scrollOffset / 200)) // Fade as scrolling
                .ignoresSafeArea(edges: .top)

                // Main content
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 0) {
                            ForEach(HeaderTab.allCases, id: \.self) { tab in
                                tabContentView(for: tab, bottomSafeArea: geometry.safeAreaInsets.bottom, screenHeight: geometry.size.height)
                                    .frame(width: geometry.size.width)
                                    .id(tab)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                    .scrollPosition(id: Binding(
                        get: { selectedHeaderTab },
                        set: { newValue in
                            if let newValue = newValue {
                                selectedHeaderTab = newValue
                            }
                        }
                    ))
                    .onChange(of: selectedHeaderTab) { oldValue, newValue in
                        // Programmatically scroll when button is tapped with smooth spring animation
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                            scrollProxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    // Fixed period navigation - transparent background, sits on gradient
                    modernPeriodNavigation
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity)
                }
            }
            .background {
                // Pre-warm adjacent page views to eliminate first-swipe lag
                if !hasWarmedAdjacentViews && !adjacentPeriodsToWarm.isEmpty {
                    AdjacentPagesWarmer(
                        periods: adjacentPeriodsToWarm,
                        getCachedBreakdowns: getCachedBreakdowns,
                        healthScoreForPeriod: healthScoreForPeriod,
                        totalSpendForPeriod: totalSpendForPeriod
                    )
                    .task {
                        try? await Task.sleep(for: .milliseconds(200))
                        hasWarmedAdjacentViews = true
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .bottom) // Allow content to extend behind tab bar
    }

    // MARK: - Header Purple Color
    private var headerPurpleColor: Color {
        Color(red: 0.35, green: 0.10, blue: 0.60) // Deeper, richer purple
    }

    // MARK: - Background Color
    private var appBackgroundColor: Color {
        Color(white: 0.05) // Match scan and milo views - almost black
    }

    // MARK: - Modern Period Navigation
    private var modernPeriodNavigation: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Previous period button
                Button {
                    goToPreviousPeriod()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canGoToPreviousPeriod ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 28)
                }
                .disabled(!canGoToPreviousPeriod)

                Spacer()

                // Center: Period display
                Text(selectedPeriod.uppercased())
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .tracking(1.5)
                    .contentTransition(.interpolate)
                    .animation(.easeInOut(duration: 0.2), value: selectedPeriod)

                Spacer()

                // Next period button
                Button {
                    goToNextPeriod()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(canGoToNextPeriod ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 28)
                }
                .disabled(!canGoToNextPeriod)
            }
            .padding(.horizontal, 8)

            // Period dots indicator
            PeriodDotsView(
                totalCount: availablePeriods.count,
                currentIndex: currentPeriodIndex
            )
        }
    }

    // MARK: - Header Tab Selector
    private var headerTabSelector: some View {
        HStack(spacing: 4) {
            ForEach(HeaderTab.allCases, id: \.self) { tab in
                Button {
                    selectedHeaderTab = tab
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(selectedHeaderTab == tab ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedHeaderTab == tab ? Color.white.opacity(0.2) : Color.clear)
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedHeaderTab)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }

    // MARK: - Tab Content View (for swipe navigation between tabs)
    private func tabContentView(for tab: HeaderTab, bottomSafeArea: CGFloat, screenHeight: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Tab selector scrolls with content
                headerTabSelector
                    .padding(.top, 4)

                switch tab {
                case .overview:
                    overviewContentForPeriod(selectedPeriod)
                case .receipts:
                    receiptsContentForPeriod(selectedPeriod)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, bottomSafeArea + 90) // Extra padding to clear tab bar
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle()) // Ensure entire content area is scrollable
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
            scrollOffset = value
        }
    }

    // MARK: - Overview Content
    private func overviewContentForPeriod(_ period: String) -> some View {
        let breakdowns = getCachedBreakdowns(for: period)
        let totalReceipts = totalReceiptsForPeriod(period)
        let segments = storeSegmentsForPeriod(period)

        // All Overview components fade in together at the same time
        return VStack(spacing: 16) {
            totalSpendingCardForPeriod(period)

            healthScoreCardForPeriod(period)

            if !breakdowns.isEmpty {
                // Pie chart showing store breakdown
                IconDonutChartView(
                    data: segments.toIconChartData(),
                    totalAmount: Double(totalReceipts),
                    size: 200,
                    currencySymbol: "",
                    subtitle: "receipts"
                )
                .padding(.top, 16)
                .padding(.bottom, 8)

                VStack(spacing: 8) {
                    ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                        Button {
                            if let breakdown = breakdowns.first(where: { $0.storeName == segment.storeName }) {
                                selectedBreakdown = breakdown
                            }
                        } label: {
                            overviewStoreRow(segment: segment)
                        }
                        .buttonStyle(OverviewStoreRowButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .smoothFadeIn(delay: 0.08, period: period)
    }

    // MARK: - Store Segments for Period
    private func storeSegmentsForPeriod(_ period: String) -> [StoreChartSegment] {
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

    // MARK: - Overview Store Row
    private func overviewStoreRow(segment: StoreChartSegment) -> some View {
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

    // MARK: - Receipts Content
    private func receiptsContentForPeriod(_ period: String) -> some View {
        VStack(spacing: 12) {
            if receiptsViewModel.state.isLoading && receiptsViewModel.receipts.isEmpty {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Loading receipts...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 80)
            } else if receiptsViewModel.receipts.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No Receipts")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)

                    Text("No receipts found for this period")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                // Receipts list - sorted newest to oldest
                LazyVStack(spacing: 12) {
                    ForEach(sortedReceipts) { receipt in
                        ReceiptRowWithDelete(
                            receipt: receipt,
                            onTap: {
                                selectedReceiptForDetail = receipt
                                showingReceiptDetail = true
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
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .padding()
                            .onAppear {
                                Task {
                                    await receiptsViewModel.loadNextPage(period: period, storeName: nil)
                                }
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: receiptsViewModel.receipts.count)
                .padding(.horizontal, 16)
            }
        }
        .smoothFadeIn(delay: 0.1, period: period)
        .overlay {
            if isDeletingReceipt {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.2)

                        Text("Deleting...")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(white: 0.15))
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

// MARK: - Period-Aware Fade In Modifier
/// Fade-in animation that plays when view appears OR when period changes.
struct PeriodFadeInModifier: ViewModifier {
    let delay: Double
    let period: String
    @State private var isVisible = false
    @State private var animatedPeriod: String = ""
    @State private var isOnScreen = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.96)
            .offset(y: isVisible ? 0 : 12)
            .onChange(of: period) { oldValue, newValue in
                // Reset and re-animate when period changes while view is on screen
                isVisible = false
                animatedPeriod = ""
                if isOnScreen {
                    triggerAnimation()
                }
            }
            .onAppear {
                isOnScreen = true
                // Animate when view appears on screen with a new period
                if animatedPeriod != period {
                    triggerAnimation()
                }
            }
            .onDisappear {
                isOnScreen = false
            }
    }

    private func triggerAnimation() {
        guard animatedPeriod != period else { return }
        isVisible = false
        animatedPeriod = period

        Task {
            if delay > 0 {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) {
                isVisible = true
            }
        }
    }
}

extension View {
    /// Period-aware fade-in - resets when period changes, persists during tab swipes
    func smoothFadeIn(delay: Double = 0, period: String) -> some View {
        modifier(PeriodFadeInModifier(delay: delay, period: period))
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

// MARK: - Adjacent Pages Warmer
/// Pre-renders chart components for adjacent periods to eliminate first-swipe lag.
/// This forces SwiftUI to create the view hierarchy and triggers Metal shader compilation
/// before the user swipes, ensuring smooth page transitions.
struct AdjacentPagesWarmer: View {
    let periods: [String]
    let getCachedBreakdowns: (String) -> [StoreBreakdown]
    let healthScoreForPeriod: (String) -> Double?
    let totalSpendForPeriod: (String) -> Double

    var body: some View {
        // Render chart components at full size but positioned far offscreen
        // Full size rendering ensures Metal shaders are fully compiled
        VStack(spacing: 0) {
            ForEach(periods, id: \.self) { period in
                let breakdowns = getCachedBreakdowns(period)
                let healthScore = healthScoreForPeriod(period)
                let totalSpend = totalSpendForPeriod(period)

                // Pre-render the LiquidGaugeView (health score card)
                LiquidGaugeView(
                    score: healthScore,
                    size: 70,
                    showLabel: false
                )
                .drawingGroup()

                // Pre-render IconDonutChartViews for store cards (limit to first 6 for performance)
                ForEach(breakdowns.prefix(6)) { breakdown in
                    let storeColor = Color(red: 0.95, green: 0.25, blue: 0.30) // Modern red
                    let otherSpend = max(0, totalSpend - breakdown.totalStoreSpend)
                    let chartData: [ChartData] = [
                        ChartData(value: breakdown.totalStoreSpend, color: storeColor, label: breakdown.storeName),
                        ChartData(value: otherSpend, color: Color.white.opacity(0.1), label: "Other")
                    ]

                    IconDonutChartView(
                        data: chartData,
                        totalAmount: breakdown.totalStoreSpend,
                        size: 84,
                        currencySymbol: "€"
                    )
                    .drawingGroup()
                }
            }
        }
        .frame(width: UIScreen.main.bounds.width)
        .offset(x: UIScreen.main.bounds.width * 3) // Position far offscreen to the right
        .allowsHitTesting(false)
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
