
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
    @StateObject private var budgetViewModel = BudgetViewModel()
    @Environment(\.scenePhase) private var scenePhase

    // Track the last time we checked for Share Extension uploads
    @State private var lastCheckedUploadTimestamp: TimeInterval = 0

    // Track when a receipt is being uploaded from Scan tab or Share Extension
    @State private var isReceiptUploading = false

    // Track if refreshWithRetry is currently running to prevent duplicate calls
    @State private var isRefreshWithRetryRunning = false

    // Track when syncing just completed to show "Synced" confirmation
    @State private var showSyncedConfirmation = false

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
    @State private var selectedStoreColor: Color = Color(red: 0.3, green: 0.7, blue: 1.0)
    @State private var selectedCategoryItem: CategorySpendItem?  // For category detail navigation (kept for backwards compatibility)
    @State private var expandedCategoryId: String?  // For inline category expansion
    @State private var categoryItems: [String: [APITransaction]] = [:]  // Loaded items per category
    @State private var loadingCategoryId: String?  // Currently loading category
    @State private var categoryLoadError: [String: String] = [:]  // Error messages per category
    @State private var showingAllTransactions = false
    @State private var lastRefreshTime: Date?
    @State private var cachedBreakdownsByPeriod: [String: [StoreBreakdown]] = [:]  // Cache for period breakdowns
    @State private var displayedBreakdownsPeriod: String = ""  // Track which period displayedBreakdowns belongs to
    @State private var hasSyncedRateLimit = false  // Prevent duplicate rate limit syncs
    @State private var loadedReceiptPeriods: Set<String> = []  // Track which periods have loaded receipts
    @State private var expandedReceiptId: String? // For inline receipt expansion
    @State private var isDeletingReceipt = false
    @State private var receiptDeleteError: String?
    @State private var receiptToSplit: APIReceipt? // For expense split
    @State private var scrollOffset: CGFloat = 0 // Track scroll for header fade effect
    @State private var cachedAvailablePeriods: [String] = [] // Cached for performance
    @State private var cachedSegmentsByPeriod: [String: [StoreChartSegment]] = [:] // Cache segments
    @State private var cachedChartDataByPeriod: [String: [ChartData]] = [:] // Cache chart data for IconDonutChart
    @State private var lastBreakdownsHash: Int = 0 // Track if breakdowns changed
    @State private var storeRowsAppeared = false // Track staggered animation state
    @State private var isReceiptsSectionExpanded = false // Track receipts section expansion
    @State private var isTransactionsSectionExpanded = false // Track bank transactions section expansion
    @State private var allTimeTotalSpend: Double = 0 // Cached all-time total spend from backend
    @State private var allTimeTotalReceipts: Int = 0 // Cached all-time receipt count from backend
    @State private var allTimeHealthScore: Double? = nil // Cached all-time health score from backend
    @State private var isLoadingAllTimeData = false // Track if fetching all-time data for first time
    // Year period data
    @State private var yearSummaryCache: [String: YearSummaryResponse] = [:] // Cache year summaries by year string
    @State private var isLoadingYearData = false // Track if fetching year data for first time
    @State private var currentLoadingYear: String? = nil // Track which year is currently loading
    @State private var showCategoryBreakdownSheet = false // Show category breakdown detail view
    @State private var isPieChartFlipped = false // Track if pie chart is showing categories (flipped) or stores
    @State private var pieChartFlipDegrees: Double = 0 // Animation degrees for flip
    @State private var pieChartSummaryCache: [String: PieChartSummaryResponse] = [:] // Cache full summary data by period
    @State private var isLoadingCategoryData = false // Track if loading category data
    @State private var showAllRows = false // Track if showing all store/category rows or limited
    private let maxVisibleRows = 5 // Maximum rows to show before "Show All" button
    @Binding var showSignOutConfirmation: Bool

    // Entrance animation states
    @State private var viewAppeared = false
    @State private var contentOpacity: Double = 0
    @State private var headerOpacity: Double = 0

    // Check if the selected period is the current month
    private var isCurrentPeriod: Bool {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentPeriod = dateFormatter.string(from: Date())
        return selectedPeriod == currentPeriod
    }

    /// Check if this is a fresh new month (first 3 days with no data yet)
    /// Used to show encouraging "new month" messaging
    /// Only depends on currentBreakdowns (stable/cached) to avoid flickering from async receipts loading
    private var isNewMonthStart: Bool {
        guard isCurrentPeriod else { return false }
        let dayOfMonth = Calendar.current.component(.day, from: Date())
        // Only check breakdowns (stable), not receipts (async) to prevent flickering
        return dayOfMonth <= 3 && currentBreakdowns.isEmpty
    }

    /// Check if current period has no data (for empty state messaging)
    private var currentPeriodHasNoData: Bool {
        currentBreakdowns.isEmpty
    }

    /// Check if the selected period has no store data (for showing empty chart)
    private func periodHasNoStoreData(_ period: String) -> Bool {
        let segments = storeSegmentsForPeriod(period)
        return segments.isEmpty
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

    /// Special constant for the "All" period
    private static let allPeriodIdentifier = "All"

    /// Check if a period is the "All" period
    private func isAllPeriod(_ period: String) -> Bool {
        return period == Self.allPeriodIdentifier
    }

    /// Check if a period is a year period (e.g., "2025", "2024")
    private func isYearPeriod(_ period: String) -> Bool {
        // Year periods are exactly 4 digits
        return period.count == 4 && period.allSatisfy { $0.isNumber }
    }

    /// Get the year from a month period string (e.g., "January 2026" -> 2026)
    private func yearFromPeriod(_ period: String) -> Int? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        guard let date = dateFormatter.date(from: period) else { return nil }
        return Calendar.current.component(.year, from: date)
    }

    /// Parse month and year from period string (e.g., "January 2026" -> (month: 1, year: 2026))
    private func parsePeriodComponents(_ period: String) -> (month: Int, year: Int) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        guard let date = dateFormatter.date(from: period) else {
            // Fallback to current date
            let now = Date()
            return (Calendar.current.component(.month, from: now), Calendar.current.component(.year, from: now))
        }
        let month = Calendar.current.component(.month, from: date)
        let year = Calendar.current.component(.year, from: date)
        return (month, year)
    }

    /// Compute available periods from data manager - called once when data changes
    /// Order: [older months] -> [current month] -> [years descending] -> [All]
    private func computeAvailablePeriods() -> [String] {
        var monthPeriods: [String] = []

        // Get the current month string (e.g., "February 2026")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentMonthString = dateFormatter.string(from: Date())

        // Use period metadata if available (from lightweight /analytics/periods endpoint)
        if !dataManager.periodMetadata.isEmpty {
            // Period metadata is already sorted by backend (most recent first)
            // Reverse to get oldest first (left), most recent last (right) for swipe UX
            monthPeriods = Array(dataManager.periodMetadata.map { $0.period }.reversed())

            // IMPORTANT: Always include current month even if it has no data yet
            // This handles the month transition case (e.g., Jan 31 → Feb 1)
            if !monthPeriods.contains(currentMonthString) {
                monthPeriods.append(currentMonthString)
            }
        } else {
            // Fallback: Use breakdowns if metadata not loaded yet
            let breakdownPeriods = Array(dataManager.breakdownsByPeriod().keys)

            // If no periods with data, show only the current month (empty state)
            if breakdownPeriods.isEmpty {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                let currentYear = Calendar.current.component(.year, from: Date())
                return [dateFormatter.string(from: Date()), "\(currentYear)", Self.allPeriodIdentifier]
            }

            // Sort periods chronologically (oldest first, most recent last/right)
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")

            monthPeriods = breakdownPeriods.sorted { period1, period2 in
                let date1 = dateFormatter.date(from: period1) ?? Date.distantPast
                let date2 = dateFormatter.date(from: period2) ?? Date.distantPast
                return date1 < date2  // Oldest first (left), most recent last (right)
            }
        }

        // Extract unique years from month periods, sorted descending (most recent year first)
        var uniqueYears: Set<Int> = []
        // Reuse dateFormatter from above

        for period in monthPeriods {
            if let date = dateFormatter.date(from: period) {
                let year = Calendar.current.component(.year, from: date)
                uniqueYears.insert(year)
            }
        }

        // Add current year if not already present (for empty state or new users)
        let currentYear = Calendar.current.component(.year, from: Date())
        uniqueYears.insert(currentYear)

        // Sort years descending (most recent first after months)
        let yearPeriods = uniqueYears.sorted(by: >).map { String($0) }

        // Build final order: [months chronologically] + [years descending] + [All]
        var result = monthPeriods
        result.append(contentsOf: yearPeriods)
        result.append(Self.allPeriodIdentifier)

        return result
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
        // Handle "All" period
        if isAllPeriod(period) {
            return cachedBreakdownsByPeriod[period] ?? aggregatedBreakdownsForAllPeriods()
        }
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

        // Preserve existing all-time backend data if available, otherwise use local aggregation
        if let existingAllTimeData = cachedBreakdownsByPeriod[Self.allPeriodIdentifier], !existingAllTimeData.isEmpty {
            newCache[Self.allPeriodIdentifier] = existingAllTimeData
        }
        // Don't set local aggregation here - let it be fetched from backend when needed

        // Batch all state updates together to minimize re-renders
        cachedBreakdownsByPeriod = newCache
        displayedBreakdowns = isAllPeriod(selectedPeriod) ? (newCache[Self.allPeriodIdentifier] ?? []) : (newCache[selectedPeriod] ?? [])
        displayedBreakdownsPeriod = selectedPeriod

        // Also update available periods cache
        updateAvailablePeriodsCache()

        // Clear segment and chart data caches when breakdowns change (will be rebuilt lazily)
        cachedSegmentsByPeriod.removeAll()
        cachedChartDataByPeriod.removeAll()
    }

    /// Update cache for a specific period only
    private func updateCacheForPeriod(_ period: String) {
        // Handle "All" period specially - don't overwrite cache from filtering
        // The "All" period data comes from fetchAllTimeData(), not from dataManager.storeBreakdowns
        if isAllPeriod(period) {
            // Use existing cached data or aggregated fallback
            let breakdowns = cachedBreakdownsByPeriod[period] ?? aggregatedBreakdownsForAllPeriods()
            if period == selectedPeriod {
                displayedBreakdowns = breakdowns
                displayedBreakdownsPeriod = period
            }
            return
        }

        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == period }

        // Always sort by highest spending for clear visual hierarchy
        breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }

        cachedBreakdownsByPeriod[period] = breakdowns

        // Immediately rebuild segment and chart data caches for this period
        // This ensures consistency - caches are never in an invalid state
        let segments = computeStoreSegments(for: period)
        cachedSegmentsByPeriod[period] = segments
        cachedChartDataByPeriod[period] = segments.toIconChartData()

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
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                if let error = dataManager.error {
                    errorStateView(error: error)
                } else {
                    swipeableContentView
                }
            }
            .background(
                ZStack(alignment: .top) {
                    // Base background
                    appBackgroundColor

                    // Purple gradient - strictly in background, fades on scroll
                    LinearGradient(
                        stops: [
                            .init(color: headerPurpleColor, location: 0.0),
                            .init(color: headerPurpleColor.opacity(0.7), location: 0.25),
                            .init(color: headerPurpleColor.opacity(0.3), location: 0.5),
                            .init(color: Color.clear, location: 0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: geometry.size.height * 0.45 + geometry.safeAreaInsets.top)
                    .frame(maxWidth: .infinity)
                    .offset(y: -geometry.safeAreaInsets.top)
                    .opacity(purpleGradientOpacity)
                    .animation(.linear(duration: 0.1), value: scrollOffset)
                    .allowsHitTesting(false)
                }
                .ignoresSafeArea()
            )
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
            .opacity(contentOpacity)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    modernPeriodNavigationToolbar
                        .opacity(headerOpacity)
                }
            }
            .navigationDestination(item: $selectedBreakdown) { breakdown in
                StoreDetailView(storeBreakdown: breakdown, storeColor: selectedStoreColor)
            }
            .navigationDestination(item: $selectedCategoryItem) { category in
                CategoryDetailView(category: category, period: selectedPeriod)
            }
            .navigationDestination(isPresented: $showingAllTransactions) {
                allTransactionsDestination
            }
            .sheet(isPresented: $showingFilterSheet) {
                FilterSheet(selectedSort: $selectedSort)
            }
            .sheet(isPresented: $showCategoryBreakdownSheet) {
                // Parse month and year from selectedPeriod (e.g., "January 2026")
                let components = parsePeriodComponents(selectedPeriod)
                CategoryBreakdownDetailView(month: components.month, year: components.year)
            }
            .sheet(item: $receiptToSplit) { receipt in
                // Use appropriate split view based on receipt source
                if receipt.source == .bankImport {
                    // Bank-imported transactions use custom/equal split
                    SplitBankTransactionView(receipt: receipt)
                } else {
                    // Scanned receipts use line item splitting
                    SplitExpenseView(receipt: receipt.toReceiptUploadResponse())
                }
            }
            .onAppear(perform: handleOnAppear)
            .onDisappear {
                // Reset entrance animation states for next appearance
                viewAppeared = false
                contentOpacity = 0
                headerOpacity = 0
            }
            .onReceive(NotificationCenter.default.publisher(for: .receiptUploadStarted)) { _ in
                handleReceiptUploadStarted()
            }
            .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
                handleReceiptUploadSuccess()
            }
            .onReceive(NotificationCenter.default.publisher(for: .receiptsDataDidChange)) { _ in
                handleReceiptDeleted()
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

        // Trigger entrance animations
        if !viewAppeared {
            viewAppeared = true

            // Header fades in
            withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
                headerOpacity = 1.0
            }

            // Content fades in
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                contentOpacity = 1.0
            }
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

        // Load budget data
        Task {
            await budgetViewModel.loadBudget()
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

            // Show "Synced" confirmation briefly
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSyncedConfirmation = true
                }
            }

            // Hide "Synced" confirmation after 2 seconds
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSyncedConfirmation = false
                }
            }
        }
    }

    private func handleReceiptDeleted() {
        print("🗑️ Received receiptsDataDidChange - refreshing period data")

        Task {
            // Wait briefly for backend to process the deletion
            try? await Task.sleep(for: .milliseconds(500))

            // Refresh the period data to update pie chart and total spending
            await dataManager.refreshData(for: .month, periodString: selectedPeriod)

            // Also refresh the period metadata to get updated totals
            await dataManager.fetchPeriodMetadata()

            await MainActor.run {
                // Update caches with fresh data
                updateDisplayedBreakdowns()
                cacheSegmentsForPeriod(selectedPeriod)
            }
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
        expandedReceiptId = nil

        // Reset store rows animation for staggered re-entry
        storeRowsAppeared = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation {
                storeRowsAppeared = true
            }
        }

        // Clear segment caches EXCEPT for "All" period (preserve to avoid re-fetching)
        // This prevents re-animation when returning to "All" from another period
        let allPeriodSegments = cachedSegmentsByPeriod[Self.allPeriodIdentifier]
        let allPeriodChartData = cachedChartDataByPeriod[Self.allPeriodIdentifier]

        cachedSegmentsByPeriod.removeAll()
        cachedChartDataByPeriod.removeAll()

        // Restore "All" period cache if it existed
        if let segments = allPeriodSegments {
            cachedSegmentsByPeriod[Self.allPeriodIdentifier] = segments
        }
        if let chartData = allPeriodChartData {
            cachedChartDataByPeriod[Self.allPeriodIdentifier] = chartData
        }

        // IMPORTANT: Set loading state BEFORE view renders when switching to "All" or Year period
        // This must be synchronous to prevent the chart from rendering with fallback data first
        if isAllPeriod(newValue) {
            let hasBackendData = cachedBreakdownsByPeriod[Self.allPeriodIdentifier] != nil &&
                                 !(cachedBreakdownsByPeriod[Self.allPeriodIdentifier]?.isEmpty ?? true)
            if !hasBackendData {
                isLoadingAllTimeData = true
            }
        } else if isYearPeriod(newValue) {
            let hasCachedYear = yearSummaryCache[newValue] != nil
            if !hasCachedYear {
                isLoadingYearData = true
                currentLoadingYear = newValue
            }
        }

        // Immediately update displayed breakdowns for the new period (no async delay)
        updateDisplayedBreakdowns()

        // Cache segments for the new period
        // Skip for "All" and Year periods - those are handled by their respective fetch functions
        if !isAllPeriod(newValue) && !isYearPeriod(newValue) {
            cacheSegmentsForPeriod(newValue)
        }

        Task {
            // Prefetch insights
            await MainActor.run { prefetchInsights() }

            // Always reload receipts when period changes
            // (receiptsViewModel only holds one period's data at a time)
            await receiptsViewModel.loadReceipts(period: newValue, storeName: nil, reset: true)

            // Handle "All" period - fetch all-time data from backend
            if isAllPeriod(newValue) {
                await fetchAllTimeData()
            } else if isYearPeriod(newValue) {
                // Handle Year period - fetch year summary from backend
                await fetchYearData(year: newValue)
            } else {
                // Load budget data for the selected month period
                await budgetViewModel.selectPeriod(newValue)

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
    }

    // MARK: - Fetch All-Time Data

    /// Fetches all-time store breakdown data from the backend
    /// Always fetches fresh data (no caching to ensure accuracy)
    private func fetchAllTimeData() async {
        // Only show loading if we don't have cached backend data yet
        // This prevents showing loading indicator when refreshing existing data
        let needsLoading = cachedBreakdownsByPeriod[Self.allPeriodIdentifier] == nil || cachedBreakdownsByPeriod[Self.allPeriodIdentifier]?.isEmpty == true

        if needsLoading {
            await MainActor.run {
                isLoadingAllTimeData = true
            }
        }

        do {
            // Fetch aggregate data with allTime=true to get all-time store data
            var filters = AggregateFilters()
            filters.allTime = true
            filters.topStoresLimit = 20  // Get more stores for the pie chart

            print("📊 Fetching all-time store data from backend (aggregate)...")
            let aggregate = try await AnalyticsAPIService.shared.getAggregate(filters: filters)
            let stores = aggregate.topStores

            print("📊 Backend response: totalSpend=€\(aggregate.totals.totalSpend), stores=\(stores.count), receipts=\(aggregate.totals.totalReceipts)")

            // Convert to StoreBreakdown array
            let breakdowns: [StoreBreakdown] = stores.map { store in
                print("   📍 Store: \(store.storeName) - €\(store.totalSpent) (\(store.visitCount) visits)")
                return StoreBreakdown(
                    storeName: store.storeName,
                    period: Self.allPeriodIdentifier,
                    totalStoreSpend: store.totalSpent,
                    categories: [],  // Categories not available in aggregate, will be fetched in detail view
                    visitCount: store.visitCount,
                    averageHealthScore: store.averageHealthScore
                )
            }.sorted { $0.totalStoreSpend > $1.totalStoreSpend }

            print("✅ Fetched \(breakdowns.count) stores for all-time view, total: €\(aggregate.totals.totalSpend)")

            await MainActor.run {
                // Store all-time totals from backend FIRST
                allTimeTotalSpend = aggregate.totals.totalSpend
                allTimeTotalReceipts = aggregate.totals.totalReceipts
                allTimeHealthScore = aggregate.averages.averageHealthScore

                // Cache the all-time breakdowns
                cachedBreakdownsByPeriod[Self.allPeriodIdentifier] = breakdowns

                // Clear any stale segment cache for All period
                cachedSegmentsByPeriod.removeValue(forKey: Self.allPeriodIdentifier)
                cachedChartDataByPeriod.removeValue(forKey: Self.allPeriodIdentifier)

                // Update displayed breakdowns if still on "All" period
                if isAllPeriod(selectedPeriod) {
                    displayedBreakdowns = breakdowns
                    displayedBreakdownsPeriod = Self.allPeriodIdentifier

                    // Cache segments for the donut chart using the correct total
                    cacheSegmentsForPeriod(Self.allPeriodIdentifier)

                    print("📊 Updated All view: \(breakdowns.count) stores, €\(allTimeTotalSpend) total, \(cachedSegmentsByPeriod[Self.allPeriodIdentifier]?.count ?? 0) segments")
                }

                // Loading complete - chart can now render with backend data
                isLoadingAllTimeData = false
            }
        } catch {
            print("❌ Failed to fetch all-time data: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingAllTimeData = false
            }
        }
    }

    // MARK: - Fetch Category Data for Pie Chart

    /// Fetches category breakdown data for a given period
    /// Used for the flippable pie chart back side
    private func fetchCategoryData(for period: String) async {
        // Skip for all-time or year periods
        guard !isAllPeriod(period) && !isYearPeriod(period) else { return }

        // Skip if already cached
        guard pieChartSummaryCache[period] == nil else { return }

        // Parse period string to get month/year
        let components = parsePeriodComponents(period)
        guard components.month > 0 && components.year > 0 else { return }

        await MainActor.run {
            isLoadingCategoryData = true
        }

        do {
            let response = try await AnalyticsAPIService.shared.getPieChartSummary(
                month: components.month,
                year: components.year
            )

            await MainActor.run {
                pieChartSummaryCache[period] = response
                isLoadingCategoryData = false
            }
        } catch {
            print("❌ Failed to fetch category data for \(period): \(error.localizedDescription)")
            await MainActor.run {
                isLoadingCategoryData = false
            }
        }
    }

    /// Get cached pie chart summary for a period
    private func pieChartSummaryForPeriod(_ period: String) -> PieChartSummaryResponse? {
        pieChartSummaryCache[period]
    }

    /// Get cached category data for a period, or empty array if not loaded
    private func categoryDataForPeriod(_ period: String) -> [CategorySpendItem] {
        pieChartSummaryCache[period]?.categories ?? []
    }

    /// Get average item price for a period
    private func averageItemPriceForPeriod(_ period: String) -> Double? {
        pieChartSummaryCache[period]?.computedAverageItemPrice
    }

    /// Convert CategorySpendItem array to ChartData for the donut chart
    private func categoryChartData(for period: String) -> [ChartData] {
        categoryDataForPeriod(period).map { category in
            ChartData(
                value: category.totalSpent,
                color: category.color,
                iconName: category.icon,
                label: category.name
            )
        }
    }

    // MARK: - Fetch Year Data

    /// Fetches year summary data from the backend
    /// - Parameter year: The year string (e.g., "2025")
    private func fetchYearData(year: String) async {
        guard let yearInt = Int(year) else { return }

        // Only show loading if we don't have cached data yet
        let needsLoading = yearSummaryCache[year] == nil

        if needsLoading {
            await MainActor.run {
                isLoadingYearData = true
                currentLoadingYear = year
            }
        }

        do {
            print("📊 Fetching year summary for \(year) from backend...")

            // First try the dedicated year endpoint
            let yearSummary = try await AnalyticsAPIService.shared.getYearSummary(year: yearInt)

            print("📊 Year \(year) response: totalSpend=€\(yearSummary.totalSpend), stores=\(yearSummary.stores.count), receipts=\(yearSummary.receiptCount)")

            // Convert to StoreBreakdown array for consistent handling
            let breakdowns: [StoreBreakdown] = yearSummary.stores.map { store in
                print("   📍 Store: \(store.storeName) - €\(store.amountSpent) (\(store.storeVisits) visits)")
                return StoreBreakdown(
                    storeName: store.storeName,
                    period: year,
                    totalStoreSpend: store.amountSpent,
                    categories: [],
                    visitCount: store.storeVisits,
                    averageHealthScore: store.averageHealthScore
                )
            }.sorted { $0.totalStoreSpend > $1.totalStoreSpend }

            print("✅ Fetched \(breakdowns.count) stores for year \(year), total: €\(yearSummary.totalSpend)")

            await MainActor.run {
                // Cache the year summary
                yearSummaryCache[year] = yearSummary

                // Cache the breakdowns
                cachedBreakdownsByPeriod[year] = breakdowns

                // Clear any stale segment cache for this year
                cachedSegmentsByPeriod.removeValue(forKey: year)
                cachedChartDataByPeriod.removeValue(forKey: year)

                // Update displayed breakdowns if still on this year period
                if selectedPeriod == year {
                    displayedBreakdowns = breakdowns
                    displayedBreakdownsPeriod = year

                    // Cache segments for the donut chart
                    cacheSegmentsForPeriod(year)

                    print("📊 Updated year \(year) view: \(breakdowns.count) stores, €\(yearSummary.totalSpend) total")
                }

                // Loading complete
                isLoadingYearData = false
                currentLoadingYear = nil
            }
        } catch {
            print("⚠️ Year endpoint not available, falling back to summary endpoint: \(error.localizedDescription)")

            // Fallback: Use the summary endpoint with year date range
            await fetchYearDataFallback(year: year, yearInt: yearInt)
        }
    }

    /// Fallback method to fetch year data using the summary endpoint with date range
    private func fetchYearDataFallback(year: String, yearInt: Int) async {
        do {
            // Create date range for the year
            var calendar = Calendar.current
            calendar.timeZone = TimeZone(identifier: "UTC")!

            var components = DateComponents()
            components.year = yearInt
            components.month = 1
            components.day = 1
            let startDate = calendar.date(from: components)!

            components.year = yearInt
            components.month = 12
            components.day = 31
            let endDate = calendar.date(from: components)!

            var filters = AggregateFilters()
            filters.startDate = startDate
            filters.endDate = endDate
            filters.topStoresLimit = 20

            let aggregate = try await AnalyticsAPIService.shared.getAggregate(filters: filters)
            let aggregateStores = aggregate.topStores
            let transactionCount = aggregate.totals.totalTransactions

            // Convert AggregateStore to APIStoreBreakdown for YearSummaryResponse
            let stores: [APIStoreBreakdown] = aggregateStores.map { store in
                APIStoreBreakdown(
                    storeName: store.storeName,
                    amountSpent: store.totalSpent,
                    storeVisits: store.visitCount,
                    percentage: store.percentage,
                    averageHealthScore: store.averageHealthScore
                )
            }

            let yearSummary = YearSummaryResponse(
                year: yearInt,
                startDate: DateFormatter.yyyyMMdd.string(from: startDate),
                endDate: DateFormatter.yyyyMMdd.string(from: endDate),
                totalSpend: aggregate.totals.totalSpend,
                transactionCount: transactionCount,
                receiptCount: transactionCount, // Approximation
                totalItems: transactionCount,
                averageHealthScore: aggregate.averages.averageHealthScore,
                stores: stores,
                monthlyBreakdown: nil,
                topCategories: nil
            )

            let breakdowns: [StoreBreakdown] = aggregateStores.map { store in
                StoreBreakdown(
                    storeName: store.storeName,
                    period: year,
                    totalStoreSpend: store.totalSpent,
                    categories: [],
                    visitCount: store.visitCount,
                    averageHealthScore: store.averageHealthScore
                )
            }.sorted { $0.totalStoreSpend > $1.totalStoreSpend }

            await MainActor.run {
                yearSummaryCache[year] = yearSummary
                cachedBreakdownsByPeriod[year] = breakdowns

                cachedSegmentsByPeriod.removeValue(forKey: year)
                cachedChartDataByPeriod.removeValue(forKey: year)

                if selectedPeriod == year {
                    displayedBreakdowns = breakdowns
                    displayedBreakdownsPeriod = year
                    cacheSegmentsForPeriod(year)
                }

                isLoadingYearData = false
                currentLoadingYear = nil
            }
        } catch {
            print("❌ Failed to fetch year data: \(error.localizedDescription)")
            await MainActor.run {
                isLoadingYearData = false
                currentLoadingYear = nil
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

            // Show "Synced" confirmation briefly
            withAnimation(.easeInOut(duration: 0.3)) {
                showSyncedConfirmation = true
            }

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

        // Hide "Synced" confirmation after 2 seconds
        try? await Task.sleep(for: .seconds(2))
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                showSyncedConfirmation = false
            }
        }

        // Reload receipts for current month if it's the selected period
        if selectedPeriod == currentMonthPeriod {
            await receiptsViewModel.loadReceipts(period: currentMonthPeriod, storeName: nil, reset: true)
        }
    }

    private var swipeableContentView: some View {
        GeometryReader { geometry in
            let bottomSafeArea = geometry.safeAreaInsets.bottom

            // Main content with vertical scroll
            mainContentView(bottomSafeArea: bottomSafeArea)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // Computed property for smooth gradient fade based on scroll
    private var purpleGradientOpacity: Double {
        // Start fading immediately, fully gone by 200px scroll
        let fadeEnd: CGFloat = 200

        if scrollOffset <= 0 {
            return 1.0
        } else if scrollOffset >= fadeEnd {
            return 0.0
        } else {
            // Linear fade for predictable behavior
            return Double(1.0 - (scrollOffset / fadeEnd))
        }
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
                transactionsSection
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
            scrollOffset = max(0, value)
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
            HStack(spacing: 6) {
                // Show sparkle icon for fresh new month
                if isNewMonthStart {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.9), .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(selectedPeriod.uppercased())
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .tracking(1.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isNewMonthStart
                        ? LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        isNewMonthStart
                            ? LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            )
            .contentTransition(.interpolate)
            .animation(.easeInOut(duration: 0.25), value: selectedPeriod)
            .animation(.easeInOut(duration: 0.3), value: isNewMonthStart)

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

    // Shorten period to "Jan 26" format, or return "All" / year as-is
    private func shortenedPeriod(_ period: String) -> String {
        // Handle "All" period
        if isAllPeriod(period) {
            return period
        }

        // Handle year periods (e.g., "2025") - return as-is
        if isYearPeriod(period) {
            return period
        }

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

        // Check if we're loading All-time or Year data for the first time (no backend data yet)
        // This prevents double animation: first with local data, then with backend data
        let isWaitingForAllTimeData = isAllPeriod(period) && isLoadingAllTimeData
        let isWaitingForYearData = isYearPeriod(period) && isLoadingYearData && currentLoadingYear == period

        // All Overview components fade in together at the same time
        return VStack(spacing: 16) {
            // Swipeable area: spending card + pie chart
            // Both swipe (change period) and tap (toggle trendline) work simultaneously
            VStack(spacing: 16) {
                // Budget widget - only show for month periods (not year or all-time)
                if !isAllPeriod(period) && !isYearPeriod(period) {
                    BudgetPulseView(viewModel: budgetViewModel)
                        .padding(.horizontal, 16)
                }

                spendingAndHealthCardForPeriod(period)

                if isWaitingForAllTimeData {
                    // Show loading indicator while fetching all-time data
                    // This prevents the chart from animating twice
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                            .scaleEffect(1.2)
                        Text("Loading all-time data...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 200, height: 200)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                } else if isWaitingForYearData {
                    // Show loading indicator while fetching year data
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                            .scaleEffect(1.2)
                        Text("Loading \(period) data...")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 200, height: 200)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                } else if !segments.isEmpty {
                    // Flippable pie chart - front shows stores, back shows categories
                    // Tap to flip between the two views
                    ZStack {
                        // Back side - Category breakdown (shown when flipped)
                        Group {
                            if !categoryDataForPeriod(period).isEmpty {
                                IconDonutChartView(
                                    data: categoryChartData(for: period),
                                    totalAmount: totalSpendForPeriod(period),
                                    size: 200,
                                    currencySymbol: "€",
                                    subtitle: nil,
                                    totalItems: nil,
                                    averageItemPrice: nil,
                                    centerIcon: "square.grid.2x2.fill",
                                    centerLabel: "Categories",
                                    showAllSegments: showAllRows
                                )
                            } else if isLoadingCategoryData {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                                        .scaleEffect(1.0)
                                    Text("Loading categories...")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .frame(width: 200, height: 200)
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "square.grid.2x2")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text("No category data")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                    Text("Tap to flip back")
                                        .font(.system(size: 11))
                                        .foregroundColor(.white.opacity(0.25))
                                }
                                .frame(width: 200, height: 200)
                            }
                        }
                        .opacity(isPieChartFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                        // Front side - Store breakdown (shown by default)
                        IconDonutChartView(
                            data: chartDataForPeriod(period),
                            totalAmount: Double(totalReceiptsForPeriod(period)),
                            size: 200,
                            currencySymbol: "",
                            subtitle: "receipts",
                            totalItems: nil,
                            averageItemPrice: nil,
                            centerIcon: "storefront.fill",
                            centerLabel: "Stores &\nBusinesses",
                            showAllSegments: showAllRows
                        )
                        .opacity(isPieChartFlipped ? 0 : 1)
                    }
                    .rotation3DEffect(
                        .degrees(pieChartFlipDegrees),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .id(period)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .contentShape(Circle())
                    .onTapGesture {
                        // Only allow flip for month periods, not year or all-time
                        if !isAllPeriod(period) && !isYearPeriod(period) {
                            // Load category data if not already loaded
                            if pieChartSummaryCache[period] == nil {
                                Task {
                                    await fetchCategoryData(for: period)
                                }
                            }
                            // Flip the chart and reset row expansion
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isPieChartFlipped.toggle()
                                pieChartFlipDegrees += 180
                                showAllRows = false // Reset to collapsed state when flipping
                            }
                        }
                    }
                    .onChange(of: period) { _, newPeriod in
                        // Reset flip state and row expansion when period changes
                        isPieChartFlipped = false
                        pieChartFlipDegrees = 0
                        showAllRows = false
                    }
                } else {
                    // Empty pie chart state - flippable between stores and categories
                    let isNewMonth = isNewMonthStart && isCurrentPeriod

                    ZStack {
                        // Back side - Empty Categories view
                        EmptyPieChartView(
                            isNewMonth: isNewMonth,
                            icon: "square.grid.2x2.fill",
                            label: "Categories"
                        )
                        .opacity(isPieChartFlipped ? 1 : 0)
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                        // Front side - Empty Stores view
                        EmptyPieChartView(
                            isNewMonth: isNewMonth,
                            icon: "storefront.fill",
                            label: "Stores &\nBusinesses"
                        )
                        .opacity(isPieChartFlipped ? 0 : 1)
                    }
                    .rotation3DEffect(
                        .degrees(pieChartFlipDegrees),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.5
                    )
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                    .contentShape(Circle())
                    .onTapGesture {
                        // Allow flip for empty month periods too
                        if !isAllPeriod(period) && !isYearPeriod(period) {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isPieChartFlipped.toggle()
                                pieChartFlipDegrees += 180
                                showAllRows = false
                            }
                        }
                    }
                    .onChange(of: period) { _, _ in
                        // Reset flip state when period changes
                        isPieChartFlipped = false
                        pieChartFlipDegrees = 0
                        showAllRows = false
                    }
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(periodSwipeGesture)

            // Store/Category rows - NOT swipeable, only tappable
            // These are the legend/details for the pie chart, so they appear directly below it
            // Show store rows when not flipped, category rows when flipped
            // Also hide while loading all-time or year data to prevent showing fallback data
            if !isWaitingForAllTimeData && !isWaitingForYearData {
                let categories = categoryDataForPeriod(period)

                if isPieChartFlipped && !categories.isEmpty {
                    // Determine which categories to display
                    let displayCategories = showAllRows ? categories : Array(categories.prefix(maxVisibleRows))
                    let hasMoreCategories = categories.count > maxVisibleRows

                    // Categories section header
                    categoriesSectionHeader(categoryCount: categories.count, isAllTime: isAllPeriod(period), isYear: isYearPeriod(period))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Category rows with staggered animation - now expandable inline
                    VStack(spacing: 8) {
                        ForEach(Array(displayCategories.enumerated()), id: \.element.id) { index, category in
                            VStack(spacing: 0) {
                                // Category row header (tappable to expand)
                                ExpandableCategoryRowHeader(
                                    category: category,
                                    isExpanded: expandedCategoryId == category.id,
                                    onTap: {
                                        toggleCategoryExpansion(category, period: period)
                                    }
                                )

                                // Expanded items section
                                if expandedCategoryId == category.id {
                                    expandedCategoryItemsSection(category)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .opacity(storeRowsAppeared ? 1 : 0)
                            .offset(y: storeRowsAppeared ? 0 : 15)
                            .animation(
                                Animation.spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.08),
                                value: storeRowsAppeared
                            )
                        }

                        // Show All / Show Less button
                        if hasMoreCategories {
                            showAllRowsButton(
                                isExpanded: showAllRows,
                                totalCount: categories.count
                            )
                        }
                    }
                    .id("\(period)-categories-\(showAllRows)-\(expandedCategoryId ?? "")")
                    .padding(.horizontal, 16)
                    .onAppear {
                        if !storeRowsAppeared {
                            withAnimation {
                                storeRowsAppeared = true
                            }
                        }
                    }
                } else if !isPieChartFlipped && !segments.isEmpty {
                    // Determine which segments to display
                    let displaySegments = showAllRows ? segments : Array(segments.prefix(maxVisibleRows))
                    let hasMoreSegments = segments.count > maxVisibleRows

                    // Stores section header
                    storesSectionHeader(storeCount: segments.count, isAllTime: isAllPeriod(period), isYear: isYearPeriod(period))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    // Store rows with staggered animation
                    // Use .id(period) to force SwiftUI to recreate views when period changes
                    // This prevents duplicate views during period transitions
                    VStack(spacing: 8) {
                        ForEach(Array(displaySegments.enumerated()), id: \.element.id) { index, segment in
                            StoreRowButton(
                                segment: segment,
                                breakdowns: breakdowns,
                                onSelect: { breakdown, color in
                                    selectedStoreColor = color
                                    selectedBreakdown = breakdown
                                }
                            )
                            .opacity(storeRowsAppeared ? 1 : 0)
                            .offset(y: storeRowsAppeared ? 0 : 15)
                            .animation(
                                Animation.spring(response: 0.5, dampingFraction: 0.8)
                                    .delay(Double(index) * 0.08),
                                value: storeRowsAppeared
                            )
                        }

                        // Show All / Show Less button
                        if hasMoreSegments {
                            showAllRowsButton(
                                isExpanded: showAllRows,
                                totalCount: segments.count
                            )
                        }
                    }
                    .id("\(period)-\(showAllRows)") // Force complete view recreation when period or expansion changes
                    .padding(.horizontal, 16)
                    .onAppear {
                        // Trigger staggered animation immediately when view appears
                        if !storeRowsAppeared {
                            withAnimation {
                                storeRowsAppeared = true
                            }
                        }
                    }
                } else if isPieChartFlipped && categories.isEmpty {
                    // Empty categories state - shown when flipped but no category data
                    emptyRowsSection(
                        icon: "square.grid.2x2",
                        title: "Categories",
                        subtitle: "No category data yet",
                        isNewMonth: isNewMonthStart && isCurrentPeriod
                    )
                } else if !isPieChartFlipped && segments.isEmpty {
                    // Empty stores state - shown when no store data
                    emptyRowsSection(
                        icon: "storefront",
                        title: "Stores",
                        subtitle: "No stores visited yet",
                        isNewMonth: isNewMonthStart && isCurrentPeriod
                    )
                }
            }

        }
        .id(period) // Ensure entire overview content is recreated for each period
    }

    /// Empty rows section for when there's no data
    private func emptyRowsSection(icon: String, title: String, subtitle: String, isNewMonth: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(isNewMonth
                            ? LinearGradient(
                                colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(isNewMonth ? .blue.opacity(0.7) : .white.opacity(0.4))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isNewMonth ? .white.opacity(0.8) : .white.opacity(0.5))
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isNewMonth ? .white.opacity(0.5) : .white.opacity(0.3))
                }

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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

        // Deduplicate breakdowns by storeName to prevent duplicate segments
        // Keep first occurrence (highest spend due to prior sorting)
        var seenStores = Set<String>()
        let uniqueBreakdowns = breakdowns.filter { seenStores.insert($0.storeName).inserted }

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

        return uniqueBreakdowns.enumerated().map { index, breakdown in
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

    // MARK: - Stores Section Header

    private func storesSectionHeader(storeCount: Int, isAllTime: Bool = false, isYear: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Stores & Businesses")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                let subtitle: String = {
                    if isAllTime {
                        return "\(storeCount) store\(storeCount == 1 ? "" : "s") all time"
                    } else if isYear {
                        return "\(storeCount) store\(storeCount == 1 ? "" : "s") this year"
                    } else {
                        return "\(storeCount) store\(storeCount == 1 ? "" : "s")"
                    }
                }()
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    // MARK: - Categories Section Header

    private func categoriesSectionHeader(categoryCount: Int, isAllTime: Bool = false, isYear: Bool = false) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Categories")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                let subtitle: String = {
                    if isAllTime {
                        return "\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies") all time"
                    } else if isYear {
                        return "\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies") this year"
                    } else {
                        return "\(categoryCount) categor\(categoryCount == 1 ? "y" : "ies")"
                    }
                }()
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    // MARK: - Expandable Category Functions

    private func toggleCategoryExpansion(_ category: CategorySpendItem, period: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if expandedCategoryId == category.id {
                // Collapse
                expandedCategoryId = nil
            } else {
                // Expand and load items
                expandedCategoryId = category.id

                // Load items if not already loaded
                if categoryItems[category.id] == nil && loadingCategoryId != category.id {
                    Task {
                        await loadCategoryItems(category, period: period)
                    }
                }
            }
        }
    }

    private func loadCategoryItems(_ category: CategorySpendItem, period: String) async {
        loadingCategoryId = category.id
        categoryLoadError[category.id] = nil

        // Comprehensive debug logging
        print("═══════════════════════════════════════════════════════════")
        print("🔍 [Category] Loading items for category:")
        print("   categoryId: \(category.categoryId)")
        print("   name: '\(category.name)'")
        print("   period: '\(period)'")
        print("   transactionCount from summary: \(category.transactionCount)")
        print("═══════════════════════════════════════════════════════════")

        do {
            var filters = TransactionFilters()

            // Use the category name directly from the backend (bypasses enum matching issues)
            filters.categoryName = category.name

            filters.pageSize = 100

            // Parse period to get date range (e.g., "January 2026")
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(identifier: "UTC")

            if let parsedDate = dateFormatter.date(from: period) {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!

                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

                filters.startDate = startOfMonth
                filters.endDate = endOfMonth
                print("   📅 Date range: \(DateFormatter.yyyyMMdd.string(from: startOfMonth)) to \(DateFormatter.yyyyMMdd.string(from: endOfMonth))")
            } else {
                print("   ⚠️ Failed to parse period: '\(period)' - will load all time")
            }

            // Debug: Print query items being sent
            let queryItems = filters.toQueryItems()
            print("   📤 Query items:")
            for item in queryItems {
                print("      - \(item.name)=\(item.value ?? "nil")")
            }

            let response = try await AnalyticsAPIService.shared.getTransactions(filters: filters)

            print("✅ [Category] Received \(response.transactions.count) transactions (total: \(response.total))")
            if !response.transactions.isEmpty {
                print("   First transaction: \(response.transactions[0].itemName) - \(response.transactions[0].category)")
            }
            print("═══════════════════════════════════════════════════════════")

            await MainActor.run {
                categoryItems[category.id] = response.transactions
                loadingCategoryId = nil
            }
        } catch {
            print("❌ [Category] Error loading items: \(error.localizedDescription)")
            print("   Full error: \(error)")
            print("═══════════════════════════════════════════════════════════")
            await MainActor.run {
                categoryLoadError[category.id] = error.localizedDescription
                loadingCategoryId = nil
            }
        }
    }

    private func expandedCategoryItemsSection(_ category: CategorySpendItem) -> some View {
        VStack(spacing: 0) {
            if loadingCategoryId == category.id {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Text("Loading items...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if let errorMsg = categoryLoadError[category.id] {
                // Error state
                VStack(spacing: 8) {
                    Text("Failed to load items")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                    Text(errorMsg)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                    Button {
                        Task { await loadCategoryItems(category, period: selectedPeriod) }
                    } label: {
                        Text("Retry")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }
                .padding(.vertical, 12)
            } else if let items = categoryItems[category.id] {
                if items.isEmpty {
                    // Empty state
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No items found")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 16)
                } else {
                    // Items list
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            expandedCategoryItemRow(item, category: category, isLast: index == items.count - 1)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(category.color.opacity(0.05))
        )
        .padding(.top, 4)
    }

    private func expandedCategoryItemRow(_ item: APITransaction, category: CategorySpendItem, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            // Health score badge
            Text(item.healthScore.nutriScoreLetter)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(item.healthScore.healthScoreColor)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(item.healthScore.healthScoreColor.opacity(0.15))
                )

            // Item details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.storeName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)

                    if let date = item.dateParsed {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(formatCategoryItemDate(date))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            // Quantity and price
            HStack(spacing: 6) {
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                }

                Text(String(format: "€%.2f", item.totalPrice))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
        .padding(.bottom, isLast ? 0 : 4)
    }

    private func formatCategoryItemDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Show All Rows Button

    private func showAllRowsButton(isExpanded: Bool, totalCount: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showAllRows.toggle()
                // Reset animation state to trigger staggered animation for new rows
                if showAllRows {
                    storeRowsAppeared = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            storeRowsAppeared = true
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.system(size: 14, weight: .semibold))

                Text(isExpanded ? "Show Less" : "Show All \(totalCount)")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.6))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    // MARK: - Section State Enum (used for both Receipts and Transactions)
    private enum SectionState {
        case loading
        case empty
        case hasData
    }

    // MARK: - Receipts Section State (scanned receipts only)
    private var receiptsSectionState: SectionState {
        let isLoading = receiptsViewModel.state.isLoading
        let hasLoadedSuccessfully = receiptsViewModel.state.value != nil
        let hasError = receiptsViewModel.state.error != nil
        let hasFinishedLoading = hasLoadedSuccessfully || hasError

        if (isLoading || !hasFinishedLoading) && scannedReceipts.isEmpty {
            return .loading
        } else if hasFinishedLoading && scannedReceipts.isEmpty {
            return .empty
        } else {
            return .hasData
        }
    }

    // MARK: - Transactions Section State (bank imports only)
    private var transactionsSectionState: SectionState {
        let isLoading = receiptsViewModel.state.isLoading
        let hasLoadedSuccessfully = receiptsViewModel.state.value != nil
        let hasError = receiptsViewModel.state.error != nil
        let hasFinishedLoading = hasLoadedSuccessfully || hasError

        if (isLoading || !hasFinishedLoading) && bankTransactions.isEmpty {
            return .loading
        } else if hasFinishedLoading && bankTransactions.isEmpty {
            return .empty
        } else {
            return .hasData
        }
    }

    // MARK: - Receipts Section (Collapsible with glass design)
    private var receiptsSection: some View {
        VStack(spacing: 0) {
            // Collapsible header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isReceiptsSectionExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    // Receipt icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)

                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Title and count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Receipts")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if receiptsSectionState == .loading {
                            Text("Loading...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        } else {
                            Text("\(scannedReceipts.count) \(isAllPeriod(selectedPeriod) ? "total" : "this period")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Count badge
                    if !scannedReceipts.isEmpty {
                        Text("\(scannedReceipts.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isReceiptsSectionExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Glass base
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.04))

                        // Gradient overlay
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.07),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ReceiptsHeaderButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 24)

            // Expandable content
            if isReceiptsSectionExpanded {
                VStack(spacing: 12) {
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
                        .padding(.vertical, 30)

                    case .empty:
                        // Empty state - different messaging based on context
                        VStack(spacing: 12) {
                            if isNewMonthStart {
                                // Fresh new month - encouraging message
                                Image(systemName: "sparkles")
                                    .font(.system(size: 32))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Text("Fresh Start!")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("New month, new opportunities.\nScan your first receipt to get started.")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                    .multilineTextAlignment(.center)
                            } else if isCurrentPeriod && currentPeriodHasNoData {
                                // Current month but no data yet (after first few days)
                                Image(systemName: "doc.text")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.2))
                                Text("No receipts this month")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("Scan a receipt to start tracking")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.3))
                            } else {
                                // Past period with no data
                                Image(systemName: "doc.text")
                                    .font(.system(size: 28))
                                    .foregroundColor(.white.opacity(0.2))
                                Text(isAllPeriod(selectedPeriod) ? "No receipts yet" : "No receipts for this period")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)

                    case .hasData:
                        // Expandable receipt cards (scanned receipts only)
                        LazyVStack(spacing: 8) {
                            ForEach(scannedReceipts) { receipt in
                                ExpandableReceiptCard(
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
                                    },
                                    onDeleteItem: { receiptId, itemId in
                                        deleteReceiptItemFromOverview(receiptId: receiptId, itemId: itemId)
                                    },
                                    onSplit: {
                                        receiptToSplit = receipt
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
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.opacity)
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

    // MARK: - Transactions Section (Collapsible with glass design - Bank Imports)
    private var transactionsSection: some View {
        VStack(spacing: 0) {
            // Collapsible header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTransactionsSectionExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    // Bank icon
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue.opacity(0.8))
                    }

                    // Title and count
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Transactions")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)

                        if transactionsSectionState == .loading {
                            Text("Loading...")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        } else {
                            Text("\(bankTransactions.count) \(isAllPeriod(selectedPeriod) ? "total" : "this period")")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Count badge
                    if !bankTransactions.isEmpty {
                        Text("\(bankTransactions.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.blue.opacity(0.2))
                            )
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isTransactionsSectionExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Glass base
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.04))

                        // Gradient overlay with subtle blue tint
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.08),
                                        Color.white.opacity(0.02)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.2),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ReceiptsHeaderButtonStyle())
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Expandable content
            if isTransactionsSectionExpanded {
                VStack(spacing: 12) {
                    switch transactionsSectionState {
                    case .loading:
                        // Loading state
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                .scaleEffect(0.8)
                            Text("Loading transactions...")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)

                    case .empty:
                        // Empty state
                        VStack(spacing: 12) {
                            Image(systemName: "building.columns")
                                .font(.system(size: 28))
                                .foregroundColor(.white.opacity(0.2))
                            Text(isAllPeriod(selectedPeriod) ? "No bank transactions yet" : "No transactions for this period")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Import transactions from your bank")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)

                    case .hasData:
                        // Bank transaction cards (non-expandable)
                        LazyVStack(spacing: 8) {
                            ForEach(bankTransactions) { transaction in
                                BankTransactionCard(
                                    receipt: transaction,
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            deleteReceiptFromOverview(transaction)
                                        }
                                    },
                                    onSplit: {
                                        receiptToSplit = transaction
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .transition(.opacity)
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

    /// Scanned receipts only (excludes bank imports)
    private var scannedReceipts: [APIReceipt] {
        sortedReceipts.filter { $0.source == .receiptUpload }
    }

    /// Bank-imported transactions only
    private var bankTransactions: [APIReceipt] {
        sortedReceipts.filter { $0.source == .bankImport }
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

    /// Delete a line item from a receipt in the overview
    private func deleteReceiptItemFromOverview(receiptId: String, itemId: String) {
        Task {
            do {
                try await receiptsViewModel.deleteReceiptItem(receiptId: receiptId, itemId: itemId)
            } catch {
                receiptDeleteError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // Period-specific versions of the cards to ensure proper data display
    // Uses cached breakdowns for performance - avoids recalculating on every render
    private func breakdownsForPeriod(_ period: String) -> [StoreBreakdown] {
        // Handle "All" period - aggregate all stores across all periods
        if isAllPeriod(period) {
            return aggregatedBreakdownsForAllPeriods()
        }

        // Use cached data if available
        if let cached = cachedBreakdownsByPeriod[period], !cached.isEmpty {
            return cached
        }

        // Fallback: calculate if not yet available (always sorted by highest spending)
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == period }
        breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        return breakdowns
    }

    /// Aggregate store breakdowns across all periods for the "All" view
    /// Prefers cached backend data, falls back to local aggregation
    private func aggregatedBreakdownsForAllPeriods() -> [StoreBreakdown] {
        // First check if we have cached all-time data from backend
        if let cached = cachedBreakdownsByPeriod[Self.allPeriodIdentifier], !cached.isEmpty {
            return cached
        }

        // Fallback: aggregate from loaded periods (may be incomplete)
        // This is used while backend data is loading
        var storeAggregates: [String: (spend: Double, visits: Int, healthScoreSum: Double, healthScoreCount: Int, categories: [Category])] = [:]

        for breakdown in dataManager.storeBreakdowns {
            let key = breakdown.storeName
            var current = storeAggregates[key] ?? (0, 0, 0, 0, [])
            current.spend += breakdown.totalStoreSpend
            current.visits += breakdown.visitCount
            if let healthScore = breakdown.averageHealthScore {
                current.healthScoreSum += healthScore * Double(breakdown.visitCount)
                current.healthScoreCount += breakdown.visitCount
            }
            // Merge categories (for simplicity, just take the first set of categories)
            if current.categories.isEmpty {
                current.categories = breakdown.categories
            }
            storeAggregates[key] = current
        }

        // Convert to StoreBreakdown array
        var aggregated: [StoreBreakdown] = storeAggregates.map { (storeName, data) in
            let avgHealthScore: Double? = data.healthScoreCount > 0 ? data.healthScoreSum / Double(data.healthScoreCount) : nil
            return StoreBreakdown(
                storeName: storeName,
                period: Self.allPeriodIdentifier,
                totalStoreSpend: data.spend,
                categories: data.categories,
                visitCount: data.visits,
                averageHealthScore: avgHealthScore
            )
        }

        // Sort by highest spending
        aggregated.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        return aggregated
    }

    private func totalSpendForPeriod(_ period: String) -> Double {
        // Handle "All" period - use cached backend value
        if isAllPeriod(period) {
            // Return cached backend value if available
            if allTimeTotalSpend > 0 {
                return allTimeTotalSpend
            }
            // Fallback to summing period metadata
            return dataManager.periodMetadata.reduce(0) { $0 + $1.totalSpend }
        }
        // Handle year periods - use cached year summary
        if isYearPeriod(period), let yearSummary = yearSummaryCache[period] {
            return yearSummary.totalSpend
        }
        // First check period metadata (from lightweight /analytics/periods)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.totalSpend
        }
        // Fallback to cached values or calculated sum
        return dataManager.periodTotalSpends[period] ?? breakdownsForPeriod(period).reduce(0) { $0 + $1.totalStoreSpend }
    }

    private func totalReceiptsForPeriod(_ period: String) -> Int {
        // Handle "All" period - use cached backend value
        if isAllPeriod(period) {
            // Return cached backend value if available
            if allTimeTotalReceipts > 0 {
                return allTimeTotalReceipts
            }
            // Fallback to summing period metadata
            return dataManager.periodMetadata.reduce(0) { $0 + $1.receiptCount }
        }
        // Handle year periods - use cached year summary
        if isYearPeriod(period), let yearSummary = yearSummaryCache[period] {
            return yearSummary.receiptCount
        }
        // First check period metadata (from lightweight /analytics/periods)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.receiptCount
        }
        // Fallback to cached values or calculated sum
        return dataManager.periodReceiptCounts[period] ?? breakdownsForPeriod(period).reduce(0) { $0 + $1.visitCount }
    }

    private func healthScoreForPeriod(_ period: String) -> Double? {
        // Handle "All" period - use cached backend value
        if isAllPeriod(period) {
            // Return cached backend value if available
            if let score = allTimeHealthScore {
                return score
            }
            // Fallback to weighted average from period metadata
            let periodsWithScore = dataManager.periodMetadata.filter { $0.averageHealthScore != nil }
            guard !periodsWithScore.isEmpty else { return nil }
            let totalItems = periodsWithScore.reduce(0) { $0 + $1.receiptCount }
            guard totalItems > 0 else { return nil }
            let weightedSum = periodsWithScore.reduce(0.0) { sum, metadata in
                sum + (metadata.averageHealthScore ?? 0) * Double(metadata.receiptCount)
            }
            return weightedSum / Double(totalItems)
        }
        // Handle year periods - use cached year summary
        if isYearPeriod(period), let yearSummary = yearSummaryCache[period] {
            return yearSummary.averageHealthScore
        }
        // First check period metadata (from lightweight /analytics/periods)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.averageHealthScore
        }
        // Fallback to dataManager's health score for selected period
        return dataManager.averageHealthScore
    }

    private func totalItemsForPeriod(_ period: String) -> Int? {
        // Handle "All" period - sum all periods
        if isAllPeriod(period) {
            let total = dataManager.periodMetadata.compactMap { $0.totalItems }.reduce(0, +)
            return total > 0 ? total : nil
        }
        // Handle year periods - use cached year summary
        if isYearPeriod(period), let yearSummary = yearSummaryCache[period] {
            return yearSummary.totalItems > 0 ? yearSummary.totalItems : nil
        }
        // Get total items from period metadata (sum of all quantities purchased)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.totalItems
        }
        return nil
    }

    /// Combined spending and health score card with dynamic color accent
    private func spendingAndHealthCardForPeriod(_ period: String) -> some View {
        let spending = totalSpendForPeriod(period)
        let healthScore = healthScoreForPeriod(period)
        let accentColor = healthScore?.healthScoreColor ?? Color.white.opacity(0.5)

        return VStack(spacing: 0) {
            // Total spending view with health score
            VStack(spacing: 16) {
                // Spending section
                VStack(spacing: 4) {
                    Text(isAllPeriod(period) ? "TOTAL SPENT" : "SPENT THIS MONTH")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .tracking(1.2)

                    Text(String(format: "€%.0f", spending))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spending)
                }

                // Modern health score display
                // Note: averageHealthScore is on 0-5 scale, ModernHealthScoreBadge expects 0-10
                if let score = healthScore {
                    ModernHealthScoreBadge(score: score * 2)
                }

                // Syncing indicator
                if !isAllPeriod(period) && isCurrentPeriod && (dataManager.isLoading || isReceiptUploading) {
                    HStack(spacing: 4) {
                        SyncingArrowsView()
                            .font(.system(size: 11))
                        Text("Syncing")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.blue)
                } else if !isAllPeriod(period) && showSyncedConfirmation {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 11))
                        Text("Synced")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundColor(.green)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .background(
            ZStack {
                // Solid base layer - opaque dark background to block purple gradient
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(white: 0.08))

                // Subtle gradient overlay for glass effect
                RoundedRectangle(cornerRadius: 28)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.04),
                                Color.white.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
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

// MARK: - Empty Pie Chart View
/// Shows an empty donut chart matching IconDonutChartView styling when there's no data for a period
/// Supports customizable icon/label for both Stores and Categories views
private struct EmptyPieChartView: View {
    let isNewMonth: Bool
    let icon: String
    let label: String

    // Match IconDonutChartView dimensions
    private let size: CGFloat = 200
    private let strokeWidthRatio: CGFloat = 0.08

    private var strokeWidth: CGFloat {
        size * strokeWidthRatio  // 16pt for 200 size
    }

    private var ringDiameter: CGFloat {
        size - strokeWidth  // 184pt
    }

    var body: some View {
        ZStack {
            // Empty donut ring - matches IconDonutChartView stroke style
            Circle()
                .stroke(
                    isNewMonth
                        ? LinearGradient(
                            colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)

            // Center content - matches IconDonutChartView center styling exactly
            ZStack {
                // Subtle gradient background circle (same as IconDonutChartView)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.white.opacity(0.02)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.32
                        )
                    )
                    .frame(width: size * 0.58, height: size * 0.58)

                // Center icon and label - clean and simple, matches IconDonutChartView
                VStack(spacing: 8) {
                    // Icon with gradient (same styling as IconDonutChartView)
                    Image(systemName: icon)
                        .font(.system(size: size * 0.18, weight: .semibold))
                        .foregroundStyle(
                            isNewMonth
                                ? LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.9),
                                        Color.purple.opacity(0.7)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.3)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )

                    // Label (e.g., "Stores & Businesses" or "Categories")
                    Text(label)
                        .font(.system(size: size * 0.07, weight: .semibold))
                        .foregroundColor(isNewMonth ? .white.opacity(0.6) : .white.opacity(0.4))
                        .tracking(0.5)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: size * 0.55)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Store Row Button (Optimized)
/// Extracted to its own view for better performance - avoids recreating closures on every render
private struct StoreRowButton: View {
    let segment: StoreChartSegment
    let breakdowns: [StoreBreakdown]
    let onSelect: (StoreBreakdown, Color) -> Void

    var body: some View {
        Button {
            // Find the matching breakdown - O(n) but only on tap, not on render
            if let breakdown = breakdowns.first(where: { $0.storeName == segment.storeName }) {
                onSelect(breakdown, segment.color)
            }
        } label: {
            HStack(spacing: 12) {
                // Color accent bar on the left
                RoundedRectangle(cornerRadius: 2)
                    .fill(segment.color)
                    .frame(width: 4, height: 32)

                // Store name - use original casing for brand identity
                Text(segment.storeName.localizedCapitalized)
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

// MARK: - Expandable Category Row Header
private struct ExpandableCategoryRowHeader: View {
    let category: CategorySpendItem
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                // Color accent bar on the left
                RoundedRectangle(cornerRadius: 2)
                    .fill(category.color)
                    .frame(width: 4, height: 32)

                // Category icon
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(category.color)
                }

                // Category name
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Percentage badge
                Text("\(Int(category.percentage))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(category.color.opacity(0.15))
                    )

                // Amount
                Text(String(format: "€%.0f", category.totalSpent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 65, alignment: .trailing)

                // Chevron for expand/collapse
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Base glass effect
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isExpanded ? category.color.opacity(0.1) : Color.white.opacity(0.04))

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
                                        category.color.opacity(isExpanded ? 0.25 : 0.15),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 80)
                        Spacer()
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: isExpanded
                                ? [category.color.opacity(0.4), category.color.opacity(0.2)]
                                : [Color.white.opacity(0.1), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(OverviewCategoryRowButtonStyle())
    }
}

// MARK: - Category Row Button (Legacy - for navigation)
private struct CategoryRowButton: View {
    let category: CategorySpendItem
    let onSelect: (CategorySpendItem) -> Void

    var body: some View {
        Button {
            onSelect(category)
        } label: {
            HStack(spacing: 12) {
                // Color accent bar on the left
                RoundedRectangle(cornerRadius: 2)
                    .fill(category.color)
                    .frame(width: 4, height: 32)

                // Category icon
                ZStack {
                    Circle()
                        .fill(category.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: category.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(category.color)
                }

                // Category name
                Text(category.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Percentage badge
                Text("\(Int(category.percentage))%")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(category.color)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(category.color.opacity(0.15))
                    )

                // Amount
                Text(String(format: "€%.0f", category.totalSpent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 65, alignment: .trailing)

                // Chevron for navigation affordance
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
                                        category.color.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 80)
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
        .buttonStyle(OverviewCategoryRowButtonStyle())
    }
}

// MARK: - Category Row Button Style
private struct OverviewCategoryRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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

// MARK: - Receipts Header Button Style
struct ReceiptsHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
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

// Note: ModernReceiptCard has been replaced with the shared ExpandableReceiptCard component
// located in Scandalicious/Views/Components/ExpandableReceiptCard.swift

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
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: score)

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
