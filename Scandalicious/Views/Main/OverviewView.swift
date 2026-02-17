
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
    static let receiptDeleted = Notification.Name("receiptDeleted")
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
    @StateObject private var promosViewModel = PromosViewModel()
    @Environment(\.scenePhase) private var scenePhase


    // Track manual sync triggered by pull-to-refresh (which period is syncing)
    @State private var manuallySyncingPeriod: String?
    @State private var syncedConfirmationPeriod: String?

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
    @State private var categoryCurrentPage: [String: Int] = [:]  // Current loaded page per category
    @State private var categoryHasMore: [String: Bool] = [:]  // Whether more pages exist per category
    @State private var categoryLoadingMore: String?  // Category currently loading more items
    @ObservedObject private var splitCache = SplitCacheManager.shared  // For split avatar display
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
    @State private var isReceiptsSectionExpanded = false // Track receipts section expansion
    @State private var receiptsScrollTarget: String? // Declarative scroll position binding
    @State private var showCategoryBreakdownSheet = false // Show category breakdown detail view
    @State private var isPieChartFlipped = true // Track if pie chart is showing categories (true) or stores (false)
    @State private var pieChartFlipDegrees: Double = 180 // Animation degrees for flip (starts at 180 for categories)
    @State private var pieChartSummaryCache: [String: PieChartSummaryResponse] = [:] // Cache full summary data by period
    @State private var isLoadingCategoryData = false // Track if loading category data
    @State private var showAllRows = false // Track if showing all store/category rows or limited
    @State private var categoryScrollResetToken: Int = 0 // Incremented to force scroll reset on category switch
    @State private var receiptsScrollResetToken: Int = 0 // Incremented to force receipts scroll reset on period change
    @State private var chartRefreshToken: Int = 0 // Incremented on receipt upload to force pie chart re-animation
    @State private var sortedReceiptsCache: [APIReceipt] = [] // Cached sorted receipts
    @State private var budgetExpanded = false // Track if budget widget is expanded
    @State private var activeCardPage = 0 // 0=budget, 1=promos
    @State private var cardDragOffset: CGFloat = 0 // Live drag offset for carousel
    @State private var periodBounceOffset: CGFloat = 0 // Rubber-band effect when at period boundary
    private let maxVisibleRows = 4 // Maximum rows to show before "Show All" button
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
    /// Order: [older months] -> [current month]
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
                return [dateFormatter.string(from: Date())]
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

        return monthPeriods
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
        // Compute hash that includes actual values (not just IDs)
        // StoreBreakdown.hashValue only hashes id (storeName-period), missing spend amounts
        var hasher = Hasher()
        for b in dataManager.storeBreakdowns {
            hasher.combine(b.id)
            hasher.combine(b.totalStoreSpend)
            hasher.combine(b.visitCount)
        }
        let currentHash = hasher.finalize()

        // Skip rebuild if nothing changed (structure AND values)
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

        // Rebuild segment/chart caches immediately for the selected period
        // (avoids momentary empty state that causes pie chart flicker)
        let segments = computeStoreSegments(for: selectedPeriod)
        cachedSegmentsByPeriod = [selectedPeriod: segments]
        cachedChartDataByPeriod = [selectedPeriod: segments.toIconChartData()]

        // Update displayed breakdowns (animation provided by caller)
        displayedBreakdowns = newCache[selectedPeriod] ?? []
        displayedBreakdownsPeriod = selectedPeriod

        // Also update available periods cache
        updateAvailablePeriodsCache()
    }

    /// Update cache for a specific period only
    private func updateCacheForPeriod(_ period: String) {
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == period }

        // Always sort by highest spending for clear visual hierarchy
        breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }

        cachedBreakdownsByPeriod[period] = breakdowns

        // Immediately rebuild segment and chart data caches for this period
        // This ensures consistency - caches are never in an invalid state
        let segments = computeStoreSegments(for: period)
        cachedSegmentsByPeriod[period] = segments
        cachedChartDataByPeriod[period] = segments.toIconChartData()

        // Animate displayed breakdowns update for smooth data transition
        if period == selectedPeriod {
            withAnimation(.easeInOut(duration: 0.3)) {
                displayedBreakdowns = breakdowns
                displayedBreakdownsPeriod = period
            }
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
        ZStack(alignment: .top) {
            // Base background
            appBackgroundColor.ignoresSafeArea()

            // Teal gradient header (fades on scroll)
            GeometryReader { geometry in
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
                .allowsHitTesting(false)
            }
            .ignoresSafeArea()

            // Content
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
                // Scanned receipts use line item splitting
                SplitExpenseView(receipt: receipt.toReceiptUploadResponse())
            }
            .onAppear(perform: handleOnAppear)
            .onDisappear {
                // Keep entrance animation states — no fade-in replay on tab switch back
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
                // Skip cache rebuild during manual sync to prevent flash of empty state
                // (refreshData temporarily clears breakdowns before adding new ones)
                guard manuallySyncingPeriod == nil else { return }
                // Wrap in animation so donut chart trim values and segment proportions
                // animate smoothly instead of snapping during data refresh
                withAnimation(.easeInOut(duration: 0.35)) {
                    rebuildBreakdownCache()
                    cacheSegmentsForPeriod(selectedPeriod)
                }
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

                // Check for share extension uploads
                AppSyncManager.shared.checkForShareExtensionUploads()
            }
        }

        // Load receipts from pre-populated cache (all data loaded during startup)
        let periodToLoad = selectedPeriod
        if !loadedReceiptPeriods.contains(periodToLoad) {
            loadedReceiptPeriods.insert(periodToLoad)
            let cache = AppDataCache.shared
            if let cachedReceipts = cache.receiptsByPeriod[periodToLoad], !cachedReceipts.isEmpty {
                receiptsViewModel.receipts = cachedReceipts
                receiptsViewModel.state = .success(cachedReceipts)
            } else {
                receiptsViewModel.receipts = []
                receiptsViewModel.state = .success([])
            }
            rebuildSortedReceipts()
        }

        // Sync rate limit only once per session
        if !hasSyncedRateLimit {
            Task {
                await rateLimitManager.syncFromBackend()
                await MainActor.run { hasSyncedRateLimit = true }
            }
        }

        // Load budget and promo data — deferred to avoid competing with tab transition animation
        Task {
            try? await Task.sleep(for: .milliseconds(150))
            await budgetViewModel.loadBudget()
        }

        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await promosViewModel.loadPromos()
        }

        // Load category data from pre-populated cache
        let initialPeriod = selectedPeriod
        let cache = AppDataCache.shared
        if let cachedPieChart = cache.pieChartSummaryByPeriod[initialPeriod] {
            pieChartSummaryCache[initialPeriod] = cachedPieChart

            // Pre-populate categoryItems from cache for instant expansion
            for category in cachedPieChart.categories {
                let key = cache.categoryItemsKey(period: initialPeriod, category: category.name)
                if let items = cache.categoryItemsCache[key] {
                    categoryItems[category.id] = items
                }
            }
        }

    }

    private func handleReceiptUploadSuccess() {
        print("[OverviewView] 📩 handleReceiptUploadSuccess() called")

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")
        let currentMonthPeriod = dateFormatter.string(from: Date())
        let currentYear = String(Calendar.current.component(.year, from: Date()))

        // Keep period in loadedReceiptPeriods to prevent duplicate loads
        // The loadReceipts call with reset:true will refresh the data

        Task {
            try? await Task.sleep(for: .seconds(1))

            // Refresh current month data — this atomically updates storeBreakdowns,
            // periodTotalSpends, and periodMetadata in one MainActor.run block.
            // The onChange(of: storeBreakdowns) observer rebuilds chart caches,
            // and the spending number animates via .contentTransition(.numericText()).
            await dataManager.refreshData(for: .month, periodString: currentMonthPeriod)

            // Trigger pie chart expansion animation simultaneously with the data-driven
            // spending number animation. Both fire in the same render cycle since
            // refreshData already updated the data above.
            if selectedPeriod == currentMonthPeriod {
                chartRefreshToken += 1
            }

            // Invalidate DISK caches (backend source of truth changed)
            // Keep in-memory display caches alive to avoid flash - they'll be replaced with fresh data
            AppDataCache.shared.yearSummaryCache.removeValue(forKey: currentYear)
            AppDataCache.shared.pieChartSummaryByPeriod.removeValue(forKey: currentMonthPeriod)
            let keysToRemove = AppDataCache.shared.categoryItemsCache.keys.filter { $0.hasPrefix("\(currentMonthPeriod)|") }
            for key in keysToRemove {
                AppDataCache.shared.categoryItemsCache.removeValue(forKey: key)
            }
            AppDataCache.shared.invalidateReceipts(for: currentMonthPeriod)

            // Refresh period metadata (totals and receipt counts change)
            await dataManager.fetchPeriodMetadata()

            // Update available periods with fresh metadata (may include new periods)
            await MainActor.run {
                updateAvailablePeriodsCache()
            }

            // Reload receipts for the selected period (what the user is currently viewing)
            await receiptsViewModel.loadReceipts(period: selectedPeriod, storeName: nil, reset: true)
            if !receiptsViewModel.receipts.isEmpty {
                AppDataCache.shared.updateReceipts(for: selectedPeriod, receipts: receiptsViewModel.receipts)
            }
            rebuildSortedReceipts()

            // Also update cache for current month if user is viewing a different period
            if selectedPeriod != currentMonthPeriod {
                let tempVM = ReceiptsViewModel()
                await tempVM.loadReceipts(period: currentMonthPeriod, storeName: nil, reset: true)
                if !tempVM.receipts.isEmpty {
                    AppDataCache.shared.updateReceipts(for: currentMonthPeriod, receipts: tempVM.receipts)
                }
            }

            // Re-fetch data if user is currently viewing an affected period
            if selectedPeriod == currentMonthPeriod {
                updateDisplayedBreakdowns()
                // Force re-fetch pie chart / category data - new data replaces old seamlessly
                await fetchCategoryData(for: currentMonthPeriod, force: true)
                // Clear stale expanded category items (fresh data loaded above)
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
                    }
                }
            } else {
                // Not viewing affected period - safe to clear in-memory caches
                pieChartSummaryCache.removeValue(forKey: currentMonthPeriod)
                categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
            }

            await rateLimitManager.syncFromBackend()

            // Refresh budget widget with latest spend data
            print("[OverviewView] 🔄 About to call budgetViewModel.refreshProgress()")
            await budgetViewModel.refreshProgress()
            print("[OverviewView] ✅ budgetViewModel.refreshProgress() completed")
        }
    }

    private func handleReceiptDeleted() {
        Task {
            // Wait briefly for backend to process the deletion
            try? await Task.sleep(for: .milliseconds(500))

            let affectedPeriod = selectedPeriod

            // Refresh the period data to update pie chart and total spending
            await dataManager.refreshData(for: .month, periodString: affectedPeriod)

            // Trigger pie chart expansion animation with the updated data
            chartRefreshToken += 1

            // Also refresh the period metadata to get updated totals
            await dataManager.fetchPeriodMetadata()

            // Invalidate disk caches (keep in-memory display data to avoid flash)
            let deletedYear = String(affectedPeriod.suffix(4))
            if deletedYear.count == 4 && deletedYear.allSatisfy({ $0.isNumber }) {
                AppDataCache.shared.yearSummaryCache.removeValue(forKey: deletedYear)
            }
            AppDataCache.shared.pieChartSummaryByPeriod.removeValue(forKey: affectedPeriod)
            let categoryKeysToRemove = AppDataCache.shared.categoryItemsCache.keys.filter { $0.hasPrefix("\(affectedPeriod)|") }
            for key in categoryKeysToRemove {
                AppDataCache.shared.categoryItemsCache.removeValue(forKey: key)
            }

            // Update available periods with fresh metadata (period may have been emptied)
            await MainActor.run {
                updateAvailablePeriodsCache()
            }

            await MainActor.run {
                // Update caches with fresh data
                updateDisplayedBreakdowns()
                cacheSegmentsForPeriod(affectedPeriod)
            }

            // Force re-fetch pie chart data, then clear stale expanded category items
            await fetchCategoryData(for: affectedPeriod, force: true)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.3)) {
                    categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
                }
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
        expandedCategoryId = nil
        showAllRows = false
        isReceiptsSectionExpanded = false
        receiptsScrollResetToken += 1

        // Reset carousel to budget page when switching periods
        // (past periods don't show promos, so avoid landing on a hidden page)
        activeCardPage = 0
        cardDragOffset = 0

        // Clear segment caches for fresh rendering
        cachedSegmentsByPeriod.removeAll()
        cachedChartDataByPeriod.removeAll()

        // Immediately update displayed breakdowns for the new period (no async delay)
        updateDisplayedBreakdowns()

        // Cache segments for the new period
        cacheSegmentsForPeriod(newValue)

        // All data pre-loaded at startup — use caches directly
        let cache = AppDataCache.shared

        // Receipts: use cache if available, otherwise fetch from backend
        if let cachedReceipts = cache.receiptsByPeriod[newValue], !cachedReceipts.isEmpty {
            receiptsViewModel.receipts = cachedReceipts
            receiptsViewModel.state = .success(cachedReceipts)
        } else {
            // No cached receipts (cache was invalidated or never loaded) - fetch from backend
            receiptsViewModel.receipts = []
            receiptsViewModel.state = .success([])
            Task {
                await receiptsViewModel.loadReceipts(period: newValue, storeName: nil, reset: true)
                // Update cache with freshly loaded receipts
                if !receiptsViewModel.receipts.isEmpty {
                    AppDataCache.shared.updateReceipts(for: newValue, receipts: receiptsViewModel.receipts)
                }
                rebuildSortedReceipts()
            }
        }
        rebuildSortedReceipts()

        // Month period: budget + breakdowns + categories all from cache
        Task { await budgetViewModel.selectPeriod(newValue) }

        if let cachedPieChart = cache.pieChartSummaryByPeriod[newValue] {
            pieChartSummaryCache[newValue] = cachedPieChart

            // Pre-populate categoryItems from cache for instant expansion
            categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
            for category in cachedPieChart.categories {
                let key = cache.categoryItemsKey(period: newValue, category: category.name)
                if let items = cache.categoryItemsCache[key] {
                    categoryItems[category.id] = items
                }
            }
        } else if pieChartSummaryCache[newValue] == nil {
            // No cached pie chart data - fetch from backend
            categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
            Task { await fetchCategoryData(for: newValue) }
        } else {
            categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
        }

        // Breakdowns should already be loaded; if not, fetch
        if !dataManager.isPeriodLoaded(newValue) {
            Task {
                await dataManager.fetchPeriodDetails(newValue)
                await MainActor.run {
                    updateCacheForPeriod(newValue)
                    cacheSegmentsForPeriod(newValue)
                }
            }
        }

        // Prefetch insights
        prefetchInsights()
    }

    // MARK: - Fetch Category Data for Pie Chart

    /// Fetches category breakdown data for a given period
    /// Used for the flippable pie chart back side
    private func fetchCategoryData(for period: String, force: Bool = false) async {
        // Skip if already cached (unless forced refresh)
        if !force {
            guard pieChartSummaryCache[period] == nil else { return }
        }

        // Parse period string to get month/year
        let components = parsePeriodComponents(period)
        guard components.month > 0 && components.year > 0 else { return }

        // Only show loading skeleton if no existing data (avoids flash during refresh)
        let hasExistingData = pieChartSummaryCache[period] != nil
        if !hasExistingData {
            await MainActor.run {
                isLoadingCategoryData = true
            }
        }

        do {
            let response = try await AnalyticsAPIService.shared.getPieChartSummary(
                month: components.month,
                year: components.year
            )

            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    pieChartSummaryCache[period] = response
                    isLoadingCategoryData = false
                }

                // Sync to disk cache
                AppDataCache.shared.updatePieChartSummary(for: period, summary: response)
            }
        } catch {
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
        return (pieChartSummaryCache[period]?.categories ?? []).map { category in
            let normalizedName = category.name.normalizedCategoryName
            return CategorySpendItem(
                categoryId: category.categoryId,
                name: normalizedName,
                totalSpent: category.totalSpent,
                colorHex: normalizedName.categoryColorHex,
                percentage: category.percentage,
                transactionCount: category.transactionCount,
                averageHealthScore: category.averageHealthScore
            )
        }
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

    /// Prefetch receipts + category data for adjacent periods (background, non-blocking)
    private func prefetchAdjacentBrowsingData(around period: String) async {
        guard !availablePeriods.isEmpty else { return }
        guard let currentIndex = availablePeriods.firstIndex(of: period) else { return }

        let cache = AppDataCache.shared
        var periodsToPreload: [String] = []

        for offset in [-1, 1, -2, 2] {
            let index = currentIndex + offset
            if index >= 0 && index < availablePeriods.count {
                periodsToPreload.append(availablePeriods[index])
            }
        }

        await withTaskGroup(of: Void.self) { group in
            for p in periodsToPreload {
                group.addTask { await cache.preloadReceipts(for: p) }
                group.addTask { await cache.preloadCategoryData(for: p) }
            }
        }
    }

    // MARK: - Share Extension Upload Handling

    /// Manual sync triggered by pull-to-refresh — only refreshes the current period
    private func manualSync() async {
        // manuallySyncingPeriod is already set by .refreshable before this Task starts
        guard !dataManager.isLoading else {
            await MainActor.run { manuallySyncingPeriod = nil }
            return
        }

        let syncStart = Date()

        let periodToSync = selectedPeriod

        // Refresh store breakdowns for selected period only
        await dataManager.refreshData(for: .month, periodString: periodToSync)

        // Refresh category data for this period
        AppDataCache.shared.pieChartSummaryByPeriod.removeValue(forKey: periodToSync)
        await fetchCategoryData(for: periodToSync, force: true)
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                categoryItems.removeAll()
                    categoryCurrentPage.removeAll()
                    categoryHasMore.removeAll()
                    categoryLoadingMore = nil
            }
        }

        // Reload receipts for this period
        await receiptsViewModel.loadReceipts(period: periodToSync, storeName: nil, reset: true)
        if !receiptsViewModel.receipts.isEmpty {
            AppDataCache.shared.updateReceipts(for: periodToSync, receipts: receiptsViewModel.receipts)
        }
        rebuildSortedReceipts()

        // Ensure "Syncing" label is visible for at least 1.5s
        let elapsed = Date().timeIntervalSince(syncStart)
        let minimumSyncingDuration: TimeInterval = 1.5
        if elapsed < minimumSyncingDuration {
            try? await Task.sleep(for: .seconds(minimumSyncingDuration - elapsed))
        }

        // Transition to "Synced" — rebuild caches with fresh data
        let syncedPeriod = manuallySyncingPeriod
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.35)) {
                rebuildBreakdownCache()
                cacheSegmentsForPeriod(selectedPeriod)
            }
            lastRefreshTime = Date()
            manuallySyncingPeriod = nil
            withAnimation(.easeInOut(duration: 0.3)) {
                syncedConfirmationPeriod = syncedPeriod
            }
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }

        // Auto-hide "Synced" after 2 seconds
        try? await Task.sleep(for: .seconds(2))
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.3)) {
                syncedConfirmationPeriod = nil
            }
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

                if horizontalAmount > 0 {
                    // Swipe right -> go to previous (older) period
                    if canGoToPreviousPeriod {
                        goToPreviousPeriod()
                    } else {
                        triggerPeriodBoundaryFeedback(direction: 1)
                    }
                } else {
                    // Swipe left -> go to next (newer) period
                    if canGoToNextPeriod {
                        goToNextPeriod()
                    } else {
                        triggerPeriodBoundaryFeedback(direction: -1)
                    }
                }
            }
    }

    /// Rubber-band bounce + haptic when user swipes past the period boundary
    private func triggerPeriodBoundaryFeedback(direction: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.impactOccurred(intensity: 0.5)

        withAnimation(.interpolatingSpring(stiffness: 400, damping: 12)) {
            periodBounceOffset = direction * 20
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                periodBounceOffset = 0
            }
        }
    }

    // MARK: - Main Content View
    private func mainContentView(bottomSafeArea: CGFloat) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                overviewContentForPeriod(selectedPeriod)
                    .id("overview")
                receiptsSection
                    .id("receiptsSection")
            }
            .scrollTargetLayout()
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
        .scrollPosition(id: $receiptsScrollTarget, anchor: .top)
        .coordinateSpace(name: "scrollView")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
            let newOffset = max(0, value)
            // Only update when in the gradient fade zone (0–220px).
            // Beyond that the gradient is fully invisible and further
            // updates just cause needless re-renders during scroll.
            if newOffset <= 220 || scrollOffset <= 220 {
                scrollOffset = newOffset
            }
        }
        .refreshable {
            // Set syncing flag immediately so the UI doesn't flash during refresh
            manuallySyncingPeriod = selectedPeriod
            syncedConfirmationPeriod = nil
            // Fire the actual sync work in a non-cancellable task so .refreshable
            // dismissal doesn't kill the minimum display time for the syncing sequence
            Task { await manualSync() }
        }
    }

    // MARK: - Header Gradient Color
    private var headerPurpleColor: Color {
        Color(red: 0.03, green: 0.18, blue: 0.25) // Deep teal - modern, premium
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
                    selectedPeriod = availablePeriods[currentPeriodIndex - 1]
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

                // Subtle "now" dot when viewing the current period
                if isCurrentPeriod && !isNewMonthStart {
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 5, height: 5)
                }
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
                    selectedPeriod = availablePeriods[currentPeriodIndex + 1]
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
        return VStack(spacing: 16) {
            // Swipeable carousel: Budget + Promos
            cardCarousel

            // Spending card with period swipe
            unifiedSpendingCardForPeriod(period)
                .offset(x: periodBounceOffset)
                .contentShape(Rectangle())
                .simultaneousGesture(periodSwipeGesture)
        }
    }

    /// Swipeable carousel: Budget + Promos (current period only shows both)
    /// Uses a single BudgetPulseView instance with offset-based paging (no TabView)
    /// so expanding/collapsing is smooth with no flash.
    private var cardCarousel: some View {
        let screenWidth = UIScreen.main.bounds.width
        let showPromos = isCurrentPeriod

        return VStack(spacing: 8) {
            // Carousel area
            ZStack(alignment: .top) {
                // Budget widget - single instance, always rendered
                BudgetPulseView(viewModel: budgetViewModel, isExpanded: $budgetExpanded)
                    .padding(.horizontal, 16)
                    .offset(x: (budgetExpanded || !showPromos) ? 0 : CGFloat(-activeCardPage) * screenWidth + cardDragOffset)
                    .allowsHitTesting(budgetExpanded || !showPromos || activeCardPage == 0)

                // Promo card - only shown for current period
                if showPromos && !budgetExpanded {
                    PromoBannerCard(viewModel: promosViewModel)
                        .padding(.horizontal, 16)
                        .offset(x: CGFloat(1 - activeCardPage) * screenWidth + cardDragOffset)
                        .allowsHitTesting(activeCardPage == 1)
                }
            }
            .clipped()
            .contentShape(Rectangle())
            .highPriorityGesture(
                (budgetExpanded || !showPromos) ? nil :
                DragGesture(minimumDistance: 20, coordinateSpace: .local)
                    .onChanged { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            cardDragOffset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            if value.translation.width < -50 && activeCardPage < 1 {
                                activeCardPage = 1
                            } else if value.translation.width > 50 && activeCardPage > 0 {
                                activeCardPage = 0
                            }
                            cardDragOffset = 0
                        }
                    }
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeCardPage)

            // Page dots - only shown for current period with promos
            if showPromos && !budgetExpanded {
                HStack(spacing: 6) {
                    ForEach(0..<2, id: \.self) { index in
                        Capsule()
                            .fill(activeCardPage == index ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                            .frame(width: activeCardPage == index ? 16 : 6, height: 4)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: activeCardPage)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: budgetExpanded)
        .onChange(of: budgetExpanded) { _, expanded in
            if expanded {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    activeCardPage = 0
                    cardDragOffset = 0
                }
            }
        }
    }

    /// Empty rows section for when there's no data
    private func emptyRowsSection(icon: String, title: String, subtitle: String, isNewMonth: Bool) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
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

    /// Look up a store's group info from cached month period data
    /// Used as fallback for year/all-time periods where StoreBreakdown has no categories
    private func lookupStoreGroup(_ storeName: String) -> (group: String, colorHex: String, icon: String)? {
        for (_, breakdowns) in cachedBreakdownsByPeriod {
            if let match = breakdowns.first(where: { $0.storeName == storeName }),
               let group = match.primaryGroup,
               let colorHex = match.primaryGroupColorHex,
               let icon = match.primaryGroupIcon {
                return (group, colorHex, icon)
            }
        }
        return nil
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

            // Use breakdown's own group info, or fall back to cached month data
            var group = breakdown.primaryGroup
            var groupColorHex = breakdown.primaryGroupColorHex
            var groupIcon = breakdown.primaryGroupIcon

            if group == nil, let cached = lookupStoreGroup(breakdown.storeName) {
                group = cached.group
                groupColorHex = cached.colorHex
                groupIcon = cached.icon
            }

            let segment = StoreChartSegment(
                startAngle: .degrees(currentAngle),
                endAngle: .degrees(currentAngle + angleRange),
                color: colors[index % colors.count],
                storeName: breakdown.storeName,
                amount: breakdown.totalStoreSpend,
                percentage: Int(percentage * 100),
                healthScore: breakdown.averageHealthScore,
                group: group,
                groupColorHex: groupColorHex,
                groupIcon: groupIcon
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "storefront.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Stores")
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
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "cart.fill")
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

    // MARK: - Legend Section Title

    private func legendSectionTitle(title: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.3))
            Spacer()
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    // MARK: - Expandable Category Functions

    /// Batch-fetch split data for a list of items so rows don't fetch one-by-one during scroll
    private func batchFetchSplitData(for items: [APITransaction]) async {
        let receiptIds = Set(items.compactMap { $0.receiptId })
        let uncachedIds = receiptIds.filter { !splitCache.hasSplit(for: $0) }
        guard !uncachedIds.isEmpty else { return }
        await withTaskGroup(of: Void.self) { group in
            for receiptId in uncachedIds {
                group.addTask {
                    await self.splitCache.fetchSplit(for: receiptId)
                }
            }
        }
    }

    private func toggleCategoryExpansion(_ category: CategorySpendItem, period: String) {
        if expandedCategoryId == category.id {
            // Collapse
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedCategoryId = nil
            }
        } else {
            // Clear previous category's pagination state so re-expanding starts fresh
            if let previousId = expandedCategoryId {
                categoryItems[previousId] = nil
                categoryCurrentPage[previousId] = nil
                categoryHasMore[previousId] = nil
            }

            // Force scroll reset by changing the token (recreates the ScrollView)
            categoryScrollResetToken += 1

            // Pre-populate items from cache BEFORE animating expansion
            let cacheKey = AppDataCache.shared.categoryItemsKey(period: period, category: category.name)
            if let cachedItems = AppDataCache.shared.categoryItemsCache[cacheKey] {
                categoryItems[category.id] = cachedItems
                // Batch-fetch split data so rows don't fetch one-by-one
                Task { await batchFetchSplitData(for: cachedItems) }
            }

            // Set loading state BEFORE withAnimation so expandedCategoryItemsSection
            // renders skeleton content immediately (gives ClipReveal something to measure)
            let needsLoad = categoryItems[category.id] == nil && loadingCategoryId != category.id
            if needsLoad {
                loadingCategoryId = category.id
                categoryLoadError[category.id] = nil
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                expandedCategoryId = category.id
            }

            if needsLoad {
                Task {
                    await loadCategoryItems(category, period: period)
                }
            }
        }
    }

    private func loadCategoryItems(_ category: CategorySpendItem, period: String) async {
        // Check cache first
        let cacheKey = AppDataCache.shared.categoryItemsKey(period: period, category: category.name)
        if let cachedItems = AppDataCache.shared.categoryItemsCache[cacheKey] {
            categoryItems[category.id] = cachedItems
            return
        }

        loadingCategoryId = category.id
        categoryLoadError[category.id] = nil

        do {
            var filters = TransactionFilters()

            // Use the category name directly from the backend
            filters.category = category.name

            filters.page = 1
            filters.pageSize = 5

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
            }

            let response = try await AnalyticsAPIService.shared.getTransactions(filters: filters)

            await MainActor.run {
                categoryItems[category.id] = response.transactions
                categoryCurrentPage[category.id] = 1
                categoryHasMore[category.id] = response.page < response.totalPages
                loadingCategoryId = nil
                // Update cache
                AppDataCache.shared.updateCategoryItems(period: period, category: category.name, items: response.transactions)
            }

            // Batch-fetch split data so rows don't fetch one-by-one during scroll
            await batchFetchSplitData(for: response.transactions)
        } catch {
            await MainActor.run {
                categoryLoadError[category.id] = error.localizedDescription
                loadingCategoryId = nil
            }
        }
    }

    /// Max items to keep loaded per category — keeps expand/collapse animation smooth
    private static let maxCategoryItems = 10

    private func loadMoreCategoryItems(_ category: CategorySpendItem, period: String) async {
        let existing = categoryItems[category.id] ?? []
        guard categoryHasMore[category.id] == true,
              categoryLoadingMore != category.id,
              existing.count < Self.maxCategoryItems else { return }

        let nextPage = (categoryCurrentPage[category.id] ?? 1) + 1

        await MainActor.run {
            categoryLoadingMore = category.id
        }

        do {
            var filters = TransactionFilters()
            filters.category = category.name
            filters.page = nextPage
            filters.pageSize = 5

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
            }

            let response = try await AnalyticsAPIService.shared.getTransactions(filters: filters)

            await MainActor.run {
                let existing = categoryItems[category.id] ?? []
                let combined = existing + response.transactions
                // Cap at maxCategoryItems to keep the view lightweight
                categoryItems[category.id] = Array(combined.prefix(Self.maxCategoryItems))
                categoryCurrentPage[category.id] = nextPage
                // Stop fetching if we've hit the cap or exhausted pages
                categoryHasMore[category.id] = combined.count < Self.maxCategoryItems && response.page < response.totalPages
                categoryLoadingMore = nil
                // Update cache with accumulated items
                AppDataCache.shared.updateCategoryItems(period: period, category: category.name, items: categoryItems[category.id] ?? [])
            }

            await batchFetchSplitData(for: response.transactions)
        } catch {
            await MainActor.run {
                categoryLoadingMore = nil
            }
        }
    }

    @ViewBuilder
    private func expandedCategoryItemsSection(_ category: CategorySpendItem) -> some View {
        let hasContent = loadingCategoryId == category.id
            || categoryLoadError[category.id] != nil
            || categoryItems[category.id] != nil

        if hasContent {
            VStack(spacing: 0) {
                if loadingCategoryId == category.id {
                    // Skeleton loading state
                    VStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonTransactionRow()
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 8)
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
                        // Items list — scrollable, max 5 visible at a time
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                    expandedCategoryItemRow(item, category: category, isLast: index == items.count - 1)
                                        .onAppear {
                                            // Load more when last item appears
                                            if index == items.count - 1 {
                                                Task { await loadMoreCategoryItems(category, period: selectedPeriod) }
                                            }
                                        }
                                }

                                // Loading more indicator
                                if categoryLoadingMore == category.id {
                                    ProgressView()
                                        .tint(.white.opacity(0.5))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                            }
                        }
                        .scrollBounceBehavior(.basedOnSize)
                        .id(categoryScrollResetToken) // Force scroll to top when switching categories
                        .frame(maxHeight: 5 * 50)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }

    private func expandedCategoryItemRow(_ item: APITransaction, category: CategorySpendItem, isLast: Bool) -> some View {
        // Get split participants for this item
        let splitParticipants: [SplitParticipantInfo] = {
            guard let receiptId = item.receiptId else { return [] }
            guard let splitData = splitCache.getSplit(for: receiptId) else { return [] }
            return splitData.participantsForTransaction(item.id)
        }()
        let friendsOnly = splitParticipants.filter { !$0.isMe }

        return HStack(spacing: 10) {
            // Health score letter (only shown when score exists)
            if item.healthScore != nil {
                Text(item.healthScore.nutriScoreLetter)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(item.healthScore.healthScoreColor)
                    .frame(width: 22, height: 22)
                    .background(
                        Circle()
                            .fill(item.healthScore.healthScoreColor.opacity(0.15))
                    )
                    .overlay(
                        Circle()
                            .stroke(item.healthScore.healthScoreColor.opacity(0.3), lineWidth: 0.5)
                    )
            }

            // Item details
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(item.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineLimit(2)

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

                    // Split participant avatars
                    if !friendsOnly.isEmpty {
                        MiniSplitAvatars(participants: friendsOnly)
                    }
                }

                if let description = item.displayDescription {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)
                }

                HStack(spacing: 6) {
                    Text(item.storeName.capitalized)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(2)

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
            .layoutPriority(1)

            Spacer()

            Text(String(format: "€%.2f", item.totalPrice))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 4)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 0.5)
                    .padding(.leading, 32)
            }
        }
    }

    private func formatCategoryItemDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Show All Rows Button

    private func showAllRowsButton(isExpanded: Bool, totalCount: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 1.0)) {
                showAllRows.toggle()
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))

                Text(isExpanded ? "Show Less" : "Show All \(totalCount)")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.35))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.top, 2)
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

        if (isLoading || !hasFinishedLoading) && sortedReceipts.isEmpty {
            return .loading
        } else if hasFinishedLoading && sortedReceipts.isEmpty {
            return .empty
        } else {
            return .hasData
        }
    }

    // MARK: - Receipts Section (Seamless inline design)
    private var receiptsSection: some View {
        VStack(spacing: 0) {
            // Section header - seamless inline
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isReceiptsSectionExpanded.toggle()
                    // Both state changes in the same transaction — SwiftUI
                    // computes the final layout (expanded + scrolled) and
                    // animates to it in one pass. The header stays fixed.
                    receiptsScrollTarget = isReceiptsSectionExpanded ? "receiptsSection" : nil
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Receipts")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    if receiptsSectionState == .loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.3)))
                            .scaleEffect(0.6)
                    } else if !sortedReceipts.isEmpty {
                        Text("\(sortedReceipts.count)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .rotationEffect(.degrees(isReceiptsSectionExpanded ? 180 : 0))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(ReceiptsHeaderButtonStyle())

            // Expandable content — always rendered, height animates from 0.
            // Content is clipped so it's progressively revealed as the card grows.
            VStack(spacing: 0) {
                switch receiptsSectionState {
                case .loading:
                    SkeletonReceiptList(count: 3)
                        .padding(.horizontal, 14)

                case .empty:
                    VStack(spacing: 8) {
                        if isNewMonthStart {
                            Image(systemName: "sparkles")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.6), .purple.opacity(0.4)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Text("Scan your first receipt to get started")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        } else {
                            Image(systemName: "doc.text")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.15))
                            Text("No receipts for this period")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)

                case .hasData:
                    // Fixed-height scrollable container — shows ~5 receipts at a time
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedReceipts.enumerated()), id: \.element.id) { index, receipt in
                                VStack(spacing: 0) {
                                    // Subtle divider between receipts
                                    if index > 0 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(height: 0.5)
                                            .padding(.horizontal, 14)
                                    }

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
                                }
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .id(receiptsScrollResetToken) // Force scroll to top on period change
                    .frame(maxHeight: 5 * 42)
                }
            }
            .padding(.bottom, isReceiptsSectionExpanded ? 8 : 0)
            .frame(maxHeight: isReceiptsSectionExpanded ? .infinity : 0)
            .clipped()
        }
        .background(premiumCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(premiumCardBorder)
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
    /// Cached sorted receipts — updated via rebuildSortedReceipts(), not on every render
    private var sortedReceipts: [APIReceipt] { sortedReceiptsCache }

    private func rebuildSortedReceipts() {
        sortedReceiptsCache = receiptsViewModel.receipts.sorted { r1, r2 in
            let d1 = r1.dateParsed ?? Date.distantPast
            let d2 = r2.dateParsed ?? Date.distantPast
            return d1 > d2
        }
    }

    /// Delete a receipt from the overview
    private func deleteReceiptFromOverview(_ receipt: APIReceipt) {
        isDeletingReceipt = true
        print("[Overview] deleteReceiptFromOverview called, receiptId=\(receipt.receiptId), selectedPeriod=\(selectedPeriod)")
        print("[Overview] receiptsVM.receipts.count BEFORE=\(receiptsViewModel.receipts.count)")

        Task {
            do {
                try await receiptsViewModel.deleteReceipt(receipt, period: selectedPeriod, storeName: nil)
                rebuildSortedReceipts()
                print("[Overview] deleteReceipt succeeded, receiptsVM.receipts.count AFTER=\(receiptsViewModel.receipts.count)")
            } catch {
                print("[Overview] deleteReceipt FAILED: \(error.localizedDescription)")
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

    private func totalItemsForPeriod(_ period: String) -> Int? {
        // Get total items from period metadata (sum of all quantities purchased)
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.totalItems
        }
        return nil
    }

    // MARK: - Unified Spending Card Components

    /// Premium card background with glass morphism
    private var premiumCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28)
                .fill(Color(white: 0.08))
            RoundedRectangle(cornerRadius: 28)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    /// Premium card border with gradient stroke
    private var premiumCardBorder: some View {
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
    }

    /// Subtle divider within the unified card
    private func cardDivider() -> some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.25), .white.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.5)
        .padding(.horizontal, 20)
    }

    /// Spending header: amount + syncing status
    private func spendingHeaderSection(spending: Double, period: String) -> some View {
        let isCurrentMonth: Bool = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            return period == dateFormatter.string(from: Date())
        }()

        return VStack(spacing: 8) {
            Text("SPENT THIS MONTH")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .tracking(1.2)

            Text(String(format: "€%.0f", spending))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: spending)

            syncingIndicator(for: period)
                .animation(.easeInOut(duration: 0.3), value: manuallySyncingPeriod)
                .animation(.easeInOut(duration: 0.3), value: syncedConfirmationPeriod)
        }
        .padding(.top, 20)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity)
    }

    /// Syncing status indicator for manual pull-to-refresh
    @ViewBuilder
    private func syncingIndicator(for period: String) -> some View {
        let isManualSyncing = manuallySyncingPeriod == period
        let isManualSynced = syncedConfirmationPeriod == period

        if isManualSyncing {
            HStack(spacing: 4) {
                SyncingArrowsView()
                    .font(.system(size: 11))
                Text("Syncing")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.blue)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if isManualSynced {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Synced")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.green)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        }
    }


    /// Flip hint label
    private func flipHintLabel() -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 9, weight: .medium))
            Text(isPieChartFlipped ? "Tap for stores" : "Tap for categories")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.25))
        .padding(.bottom, 4)
    }

    /// Flippable donut chart section with recessed dark well
    private func flippableChartSection(period: String, segments: [StoreChartSegment]) -> some View {
        Group {
            if !segments.isEmpty {
                ZStack {
                    // Back side - Category breakdown
                    Group {
                        if !categoryDataForPeriod(period).isEmpty {
                            IconDonutChartView(
                                data: categoryChartData(for: period),
                                totalAmount: totalSpendForPeriod(period),
                                size: 170,
                                currencySymbol: "€",
                                subtitle: nil,
                                totalItems: nil,
                                averageItemPrice: nil,
                                centerIcon: "cart.fill",
                                centerLabel: "Categories",
                                showAllSegments: showAllRows,
                                refreshToken: chartRefreshToken
                            )
                        } else if isLoadingCategoryData {
                            SkeletonDonutChart()
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "cart")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white.opacity(0.3))
                                Text("No category data")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.4))
                                Text("Tap to flip back")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.25))
                            }
                            .frame(width: 170, height: 170)
                        }
                    }
                    .opacity(isPieChartFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                    // Front side - Store breakdown
                    IconDonutChartView(
                        data: chartDataForPeriod(period),
                        totalAmount: Double(totalReceiptsForPeriod(period)),
                        size: 170,
                        currencySymbol: "",
                        subtitle: "receipts",
                        totalItems: nil,
                        averageItemPrice: nil,
                        centerIcon: "storefront.fill",
                        centerLabel: "Stores",
                        showAllSegments: showAllRows,
                        refreshToken: chartRefreshToken
                    )
                    .opacity(isPieChartFlipped ? 0 : 1)
                }
                .rotation3DEffect(
                    .degrees(pieChartFlipDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .contentShape(Circle())
                .onTapGesture {
                    if pieChartSummaryCache[period] == nil {
                        Task {
                            await fetchCategoryData(for: period)
                        }
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPieChartFlipped.toggle()
                        pieChartFlipDegrees += 180
                        showAllRows = false
                    }
                }
                .onChange(of: period) { _, _ in
                    showAllRows = false
                }
            } else {
                // Empty state
                let isNewMonth = isNewMonthStart && isCurrentPeriod
                ZStack {
                    EmptyPieChartView(
                        isNewMonth: isNewMonth,
                        icon: "cart.fill",
                        label: "Categories"
                    )
                    .opacity(isPieChartFlipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))

                    EmptyPieChartView(
                        isNewMonth: isNewMonth,
                        icon: "storefront.fill",
                        label: "Stores"
                    )
                    .opacity(isPieChartFlipped ? 0 : 1)
                }
                .rotation3DEffect(
                    .degrees(pieChartFlipDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.5
                )
                .contentShape(Circle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isPieChartFlipped.toggle()
                        pieChartFlipDegrees += 180
                        showAllRows = false
                    }
                }
                .onChange(of: period) { _, _ in
                    showAllRows = false
                }
            }
        }
        .padding(.vertical, 12)
    }

    /// Category/Store rows section inside the unified card
    private func rowsSection(
        period: String,
        segments: [StoreChartSegment],
        categories: [CategorySpendItem],
        breakdowns: [StoreBreakdown]
    ) -> some View {
        VStack(spacing: 0) {
            if isPieChartFlipped && !categories.isEmpty {
                let hasMoreCategories = categories.count > maxVisibleRows

                legendSectionTitle(
                    title: "Categories",
                    count: categories.count
                )

                // Always-visible rows (first maxVisibleRows)
                ForEach(Array(categories.prefix(maxVisibleRows).enumerated()), id: \.element.id) { index, category in
                    VStack(spacing: 0) {
                        if index > 0 {
                            LinearGradient(
                                colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 0.5)
                            .padding(.leading, 44)
                        }

                        ExpandableCategoryRowHeader(
                            category: category,
                            isExpanded: expandedCategoryId == category.id,
                            onTap: {
                                toggleCategoryExpansion(category, period: period)
                            }
                        )

                        expandedCategoryItemsSection(category)
                            .clipReveal(isVisible: expandedCategoryId == category.id)
                    }
                }

                // Overflow rows (clipped when collapsed)
                if hasMoreCategories {
                    VStack(spacing: 0) {
                        ForEach(Array(categories.dropFirst(maxVisibleRows).enumerated()), id: \.element.id) { index, category in
                            VStack(spacing: 0) {
                                LinearGradient(
                                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(height: 0.5)
                                .padding(.leading, 44)

                                ExpandableCategoryRowHeader(
                                    category: category,
                                    isExpanded: expandedCategoryId == category.id,
                                    onTap: {
                                        toggleCategoryExpansion(category, period: period)
                                    }
                                )

                                expandedCategoryItemsSection(category)
                                    .clipReveal(isVisible: expandedCategoryId == category.id)
                            }
                        }
                    }
                    .clipReveal(isVisible: showAllRows)

                    showAllRowsButton(
                        isExpanded: showAllRows,
                        totalCount: categories.count
                    )
                }
            } else if !isPieChartFlipped && !segments.isEmpty {
                let hasMoreSegments = segments.count > maxVisibleRows

                legendSectionTitle(
                    title: "Stores",
                    count: segments.count
                )

                // Always-visible rows (first maxVisibleRows)
                ForEach(Array(segments.prefix(maxVisibleRows).enumerated()), id: \.element.id) { index, segment in
                    VStack(spacing: 0) {
                        if index > 0 {
                            LinearGradient(
                                colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .frame(height: 0.5)
                            .padding(.leading, 24)
                        }

                        StoreRowButton(
                            segment: segment,
                            breakdowns: breakdowns,
                            onSelect: { breakdown, color in
                                selectedStoreColor = color
                                selectedBreakdown = breakdown
                            }
                        )
                    }
                }

                // Overflow rows (clipped when collapsed)
                if hasMoreSegments {
                    VStack(spacing: 0) {
                        ForEach(Array(segments.dropFirst(maxVisibleRows).enumerated()), id: \.element.id) { index, segment in
                            VStack(spacing: 0) {
                                LinearGradient(
                                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(height: 0.5)
                                .padding(.leading, 24)

                                StoreRowButton(
                                    segment: segment,
                                    breakdowns: breakdowns,
                                    onSelect: { breakdown, color in
                                        selectedStoreColor = color
                                        selectedBreakdown = breakdown
                                    }
                                )
                            }
                        }
                    }
                    .clipReveal(isVisible: showAllRows)

                    showAllRowsButton(
                        isExpanded: showAllRows,
                        totalCount: segments.count
                    )
                }
            } else if isPieChartFlipped && categories.isEmpty {
                emptyRowsSection(
                    icon: "cart",
                    title: "Categories",
                    subtitle: "No category data yet",
                    isNewMonth: isNewMonthStart && isCurrentPeriod
                )
            } else if !isPieChartFlipped && segments.isEmpty {
                emptyRowsSection(
                    icon: "storefront",
                    title: "Stores",
                    subtitle: "No stores visited yet",
                    isNewMonth: isNewMonthStart && isCurrentPeriod
                )
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
    }

    /// Unified spending card combining amount, donut chart, and category/store rows
    private func unifiedSpendingCardForPeriod(_ period: String) -> some View {
        let breakdowns = getCachedBreakdowns(for: period)
        let segments = storeSegmentsForPeriod(period)
        let categories = categoryDataForPeriod(period)
        let spending = totalSpendForPeriod(period)
        let healthScore = healthScoreForPeriod(period)

        return VStack(spacing: 0) {
            spendingHeaderSection(spending: spending, period: period)

            flippableChartSection(period: period, segments: segments)

            if !segments.isEmpty || !categories.isEmpty {
                flipHintLabel()
            }

            if isPieChartFlipped {
                CompactNutriBadge(score: healthScore ?? 0)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                    .opacity(healthScore != nil ? 1 : 0)
                    .transition(.identity)
            }

            rowsSection(
                period: period,
                segments: segments,
                categories: categories,
                breakdowns: breakdowns
            )
        }
        .background(premiumCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(premiumCardBorder)
        .shadow(color: Color.black.opacity(0.25), radius: 24, x: 0, y: 12)
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
        selectedPeriod = availablePeriods[currentPeriodIndex - 1]
    }

    private func goToNextPeriod() {
        guard canGoToNextPeriod else { return }
        selectedPeriod = availablePeriods[currentPeriodIndex + 1]
    }
}

// MARK: - Clip Reveal Modifier

private struct ClipReveal: ViewModifier {
    let isVisible: Bool
    @State private var contentHeight: CGFloat = 0
    @State private var displayedHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .fixedSize(horizontal: false, vertical: true)
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear {
                            contentHeight = geo.size.height
                            displayedHeight = isVisible ? geo.size.height : 0
                        }
                        .onChange(of: geo.size.height) { _, h in
                            contentHeight = h
                            if isVisible {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    displayedHeight = h
                                }
                            }
                        }
                }
            )
            .frame(height: displayedHeight, alignment: .top)
            .clipped()
            .allowsHitTesting(isVisible)
            .onChange(of: isVisible) { _, visible in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    displayedHeight = visible ? contentHeight : 0
                }
            }
    }
}

extension View {
    fileprivate func clipReveal(isVisible: Bool) -> some View {
        modifier(ClipReveal(isVisible: isVisible))
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
    private let size: CGFloat = 170
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
            if let breakdown = breakdowns.first(where: { $0.storeName == segment.storeName }) {
                onSelect(breakdown, segment.color)
            }
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(segment.color)
                    .frame(width: 3, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(segment.storeName.localizedCapitalized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text("\(segment.percentage)%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(segment.color.opacity(0.8))
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                Text(String(format: "€%.0f", segment.amount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 65, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
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
                    .frame(width: 3, height: 28)

                // Category icon
                Image.categorySymbol(category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 16, height: 16)

                // Category name + percentage
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text("\(Int(category.percentage))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(category.color.opacity(0.8))
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // Amount
                Text(String(format: "€%.0f", category.totalSpent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 65, alignment: .trailing)

                // Chevron for expand/collapse
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
                    .rotationEffect(.degrees(isExpanded ? -180 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
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
                    .frame(width: 3, height: 28)

                // Category icon
                Image.categorySymbol(category.icon)
                    .foregroundStyle(category.color)
                    .frame(width: 16, height: 16)

                // Category name + percentage
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text("\(Int(category.percentage))%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(category.color.opacity(0.8))
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // Amount
                Text(String(format: "€%.0f", category.totalSpent))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 65, alignment: .trailing)

                // Chevron for navigation affordance
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
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

// MARK: - Compact Nutri Badge (inline pill for unified card)
struct CompactNutriBadge: View {
    let score: Double

    @State private var animatedProgress: CGFloat = 0

    private var scoreColor: Color {
        switch score {
        case 0..<1.5:
            return Color(red: 0.95, green: 0.3, blue: 0.3)
        case 1.5..<2.5:
            return Color(red: 1.0, green: 0.55, blue: 0.2)
        case 2.5..<3.25:
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        case 3.25..<4:
            return Color(red: 0.5, green: 0.85, blue: 0.4)
        default:
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        }
    }

    private var gradeLabel: String {
        switch score {
        case 4...: return "A"
        case 3.25..<4: return "B"
        case 2.5..<3.25: return "C"
        case 1.5..<2.5: return "D"
        default: return "E"
        }
    }

    private var scoreProgress: Double {
        switch gradeLabel {
        case "A": return 1.0
        case "B": return 0.75
        case "C": return 0.5
        case "D": return 0.25
        default: return 0.0
        }
    }

    private func replayAnimation() {
        animatedProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                animatedProgress = 1.0
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            // Grade letter with circular ring
            ZStack {
                Circle()
                    .stroke(scoreColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .transaction { $0.animation = nil }
                Circle()
                    .trim(from: 0, to: scoreProgress * animatedProgress)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animatedProgress)
                Text(gradeLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
                    .transaction { $0.animation = nil }
            }

            Text("NUTRI SCORE")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .tracking(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(scoreColor.opacity(0.08))
                .overlay(
                    Capsule()
                        .stroke(scoreColor.opacity(0.2), lineWidth: 0.5)
                )
        )
        .transaction { $0.animation = nil }
        .onAppear {
            replayAnimation()
        }
        .onChange(of: score) { _, _ in
            replayAnimation()
        }
    }
}

// MARK: - Modern Health Score Badge
struct ModernHealthScoreBadge: View {
    let score: Double

    // Color based on score (0-5): red (poor) → orange → yellow → green (excellent)
    private var scoreColor: Color {
        switch score {
        case 0..<1.5:
            return Color(red: 0.95, green: 0.3, blue: 0.3) // Red - E
        case 1.5..<2.5:
            return Color(red: 1.0, green: 0.55, blue: 0.2) // Orange - D
        case 2.5..<3.25:
            return Color(red: 1.0, green: 0.8, blue: 0.2) // Yellow - C
        case 3.25..<4:
            return Color(red: 0.5, green: 0.85, blue: 0.4) // Light green - B
        default:
            return Color(red: 0.2, green: 0.8, blue: 0.4) // Green - A
        }
    }

    // Grade letter based on score (A, B, C, D, E) on 0-5 scale
    private var gradeLabel: String {
        switch score {
        case 4...:
            return "A"
        case 3.25..<4:
            return "B"
        case 2.5..<3.25:
            return "C"
        case 1.5..<2.5:
            return "D"
        default:
            return "E"
        }
    }

    private var scoreProgress: Double {
        score / 5.0
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
