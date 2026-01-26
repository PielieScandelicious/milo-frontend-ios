//
//
//  OverviewView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers
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
    case stores = "Stores"
    case receipts = "Receipts"
}



struct OverviewView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var dataManager: StoreDataManager
    @ObservedObject var rateLimitManager = RateLimitManager.shared
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
    @State private var isEditMode = false {
        didSet {
            print("🔵🔵🔵 isEditMode changed from \(oldValue) to \(isEditMode)")
        }
    }
    @State private var draggingItem: StoreBreakdown?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var displayedBreakdowns: [StoreBreakdown] = []
    @State private var selectedBreakdown: StoreBreakdown?
    @State private var showingAllStoresBreakdown = false
    @State private var showingAllTransactions = false
    @State private var showingHealthScoreTransactions = false
    @State private var showingProfileMenu = false
    @State private var breakdownToDelete: StoreBreakdown?
    @State private var showingDeleteConfirmation = false
    @State private var lastRefreshTime: Date?
    @State private var cachedBreakdownsByPeriod: [String: [StoreBreakdown]] = [:]  // Cache for period breakdowns
    @State private var displayedBreakdownsPeriod: String = ""  // Track which period displayedBreakdowns belongs to
    @State private var hasWarmedAdjacentViews = false  // Track if adjacent page views have been pre-rendered
    @Binding var showSignOutConfirmation: Bool

    // User defaults key for storing order
    private let orderStorageKey = "StoreBreakdownsOrder"

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
        // For the selected period in edit mode, use displayedBreakdowns to support drag reordering
        // But ONLY if displayedBreakdowns actually belongs to this period
        if isEditMode && period == selectedPeriod && period == displayedBreakdownsPeriod && !displayedBreakdowns.isEmpty {
            return displayedBreakdowns
        }
        // Always return cached data for the specific period requested
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
    
    // MARK: - Custom Order Persistence
    
    private func saveCustomOrder() {
        // Save the current order for this period
        let storeIds = displayedBreakdowns.map { $0.id }
        let key = "\(orderStorageKey)_\(selectedPeriod)"
        UserDefaults.standard.set(storeIds, forKey: key)
        print("💾 Saved custom order for \(selectedPeriod): \(storeIds)")
    }
    
    private func applyCustomOrder(to breakdowns: [StoreBreakdown], for period: String) -> [StoreBreakdown] {
        let key = "\(orderStorageKey)_\(period)"
        guard let savedOrder = UserDefaults.standard.array(forKey: key) as? [String] else {
            // No saved order, return as-is
            return breakdowns
        }
        
        // Create a dictionary for quick lookup
        var breakdownDict = Dictionary(uniqueKeysWithValues: breakdowns.map { ($0.id, $0) })
        
        // Build ordered array based on saved order
        var orderedBreakdowns: [StoreBreakdown] = []
        
        // First, add items in the saved order
        for id in savedOrder {
            if let breakdown = breakdownDict[id] {
                orderedBreakdowns.append(breakdown)
                breakdownDict.removeValue(forKey: id)
            }
        }
        
        // Then append any new items that weren't in the saved order
        orderedBreakdowns.append(contentsOf: breakdownDict.values.sorted { $0.storeName < $1.storeName })
        
        print("📋 Applied custom order for \(period), \(orderedBreakdowns.count) items")
        return orderedBreakdowns
    }
    
    private var totalPeriodSpending: Double {
        // Use the total spend from backend (sum of item_price) instead of summing store amounts
        dataManager.periodTotalSpends[selectedPeriod] ?? currentBreakdowns.reduce(0) { $0 + $1.totalStoreSpend }
    }

    private var totalPeriodReceipts: Int {
        // Use the receipt count from backend instead of summing visit counts
        dataManager.periodReceiptCounts[selectedPeriod] ?? currentBreakdowns.reduce(0) { $0 + $1.visitCount }
    }

    // MARK: - Delete Functions
    private func deleteBreakdowns(at offsets: IndexSet) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            for index in offsets {
                let breakdown = displayedBreakdowns[index]
                dataManager.deleteBreakdownLocally(breakdown)
            }
            updateDisplayedBreakdowns()
        }
    }

    private func deleteBreakdown(_ breakdown: StoreBreakdown) async {
        // Determine period type from selected period
        let periodType: PeriodType = {
            switch selectedPeriod.lowercased() {
            case let p where p.contains("week"): return .week
            case let p where p.contains("year"): return .year
            default: return .month
            }
        }()

        let success = await dataManager.deleteBreakdown(breakdown, periodType: periodType)

        if success {
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    displayedBreakdowns.removeAll { $0.id == breakdown.id }
                    isEditMode = false
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            appBackgroundColor.ignoresSafeArea()
            
            // Subtle overlay in edit mode - visual dimming effect
            if isEditMode {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .allowsHitTesting(false) // Don't block touches - tap handled by ScrollView content
            }
            
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
            
            // Edit mode exit button overlay
            if isEditMode {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditMode = false
                            }
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                        .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 4)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedBreakdown) { breakdown in
            StoreDetailView(storeBreakdown: breakdown)
        }
        .navigationDestination(isPresented: $showingAllStoresBreakdown) {
            AllStoresBreakdownView(period: selectedPeriod, breakdowns: currentBreakdowns, totalSpend: totalPeriodSpending, totalReceipts: totalPeriodReceipts)
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
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedSort: $selectedSort
            )
        }
        .alert(
            "Delete \(breakdownToDelete?.storeName ?? "Store")?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {
                breakdownToDelete = nil
            }
            Button("Delete", role: .destructive) {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                if let breakdown = breakdownToDelete {
                    Task {
                        await deleteBreakdown(breakdown)
                    }
                }
                breakdownToDelete = nil
            }
        } message: {
            Text("This will remove all transactions for this store from \(selectedPeriod). This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: .init(
            get: { dataManager.deleteError != nil },
            set: { if !$0 { dataManager.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {
                dataManager.deleteError = nil
            }
        } message: {
            Text(dataManager.deleteError ?? "An error occurred while deleting.")
        }
        .overlay {
            if dataManager.isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Deleting...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color(white: 0.15).cornerRadius(16))
                }
            }
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
        .onDisappear {
            // Exit edit mode when switching tabs or navigating away
            if isEditMode {
                isEditMode = false
            }
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            // Exit edit mode when changing periods to avoid inconsistency
            if isEditMode {
                isEditMode = false
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
            // Exit edit mode when changing sort to avoid inconsistency
            if isEditMode {
                isEditMode = false
            }
            // Rebuild entire cache since sorting affects all periods
            rebuildBreakdownCache()
        }
        .onChange(of: dataManager.storeBreakdowns) { oldValue, newValue in
            if !isEditMode {
                // Rebuild cache when underlying data changes
                rebuildBreakdownCache()
            }
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
                    .foregroundColor(.white)
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
                    .foregroundColor(.white)
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

    // Grid columns - defined once to avoid recreating on every render
    private let storeGridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var swipeableContentView: some View {
        GeometryReader { geometry in
            TabView(selection: $selectedHeaderTab) {
                ForEach(HeaderTab.allCases, id: \.self) { tab in
                    tabContentView(for: tab, bottomSafeArea: geometry.safeAreaInsets.bottom)
                        .tag(tab)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .safeAreaInset(edge: .top, spacing: 0) {
                // Fixed header with period navigation and tabs
                VStack(spacing: 12) {
                    modernPeriodNavigation
                    headerTabSelector
                }
                .padding(.bottom, 10)
                .frame(maxWidth: .infinity)
                .background(
                    headerPurpleColor
                        .ignoresSafeArea(edges: .top)
                )
                .zIndex(100)
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
        Color(red: 0.55, green: 0.23, blue: 0.90)
    }

    // MARK: - Background Color
    private var appBackgroundColor: Color {
        Color(red: 0.08, green: 0.07, blue: 0.12) // Rich dark with subtle purple undertone
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
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedHeaderTab = tab
                    }
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
    private func tabContentView(for tab: HeaderTab, bottomSafeArea: CGFloat) -> some View {
        ScrollView {
            VStack(spacing: 12) {
                switch tab {
                case .overview:
                    overviewContentForPeriod(selectedPeriod)
                case .stores:
                    storeBreakdownsGridForPeriod(selectedPeriod)
                case .receipts:
                    receiptsContentForPeriod(selectedPeriod)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, bottomSafeArea) // Add padding so last item can scroll above tab bar
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled() // Allow content to render behind the translucent tab bar
    }

    // MARK: - Overview Content
    private func overviewContentForPeriod(_ period: String) -> some View {
        let breakdowns = getCachedBreakdowns(for: period)
        let totalSpend = totalSpendForPeriod(period)
        let totalReceipts = totalReceiptsForPeriod(period)
        let segments = storeSegmentsForPeriod(period)

        return VStack(spacing: 16) {
            // Total spending and health score cards
            totalSpendingCardForPeriod(period)
                .premiumFadeIn(delay: 0)

            healthScoreCardForPeriod(period)
                .premiumFadeIn(delay: 0.08)

            // Donut chart with store breakdown
            if !breakdowns.isEmpty {
                FlippableAllStoresChartView(
                    totalAmount: totalSpend,
                    segments: segments,
                    size: 200,
                    totalReceipts: totalReceipts,
                    trends: [],
                    accentColor: Color(red: 0.95, green: 0.25, blue: 0.3),
                    selectedPeriod: period
                )
                .padding(.top, 16)
                .padding(.bottom, 8)
                .premiumFadeIn(delay: 0.16)

                // Store legend
                VStack(spacing: 8) {
                    ForEach(segments, id: \.id) { segment in
                        Button {
                            // Navigate to store transactions
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
                .premiumFadeIn(delay: 0.24)
            }
        }
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

            Text(segment.storeName)
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
        VStack(spacing: 16) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("Receipts")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("Coming soon")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
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

    private func storeCountForPeriod(_ period: String) -> Int {
        // First check period metadata
        if let metadata = dataManager.periodMetadata.first(where: { $0.period == period }) {
            return metadata.storeCount
        }
        // Fallback to breakdown count
        return breakdownsForPeriod(period).count
    }

    private func totalSpendingCardForPeriod(_ period: String) -> some View {
        let spending = totalSpendForPeriod(period)

        return Button {
            showingAllStoresBreakdown = true
        } label: {
            VStack(spacing: 6) {
                Text("Total Spending")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(String(format: "€%.0f", spending))
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                // Syncing/Synced indicator inline
                HStack(spacing: 4) {
                    if dataManager.isLoading || isReceiptUploading {
                        SyncingArrowsView()
                            .font(.system(size: 11))
                        Text("Syncing...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.blue)
                    } else {
                        Image(systemName: "checkmark.icloud.fill")
                            .font(.system(size: 11))
                        Text("Synced")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .foregroundColor(dataManager.isLoading || isReceiptUploading ? .blue : .green)
            }
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
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

    private func storeBreakdownsGridForPeriod(_ period: String) -> some View {
        // Use cached breakdowns to avoid recalculating during swipes
        let breakdowns = getCachedBreakdowns(for: period)
        let isLoadingPeriod = !dataManager.periodMetadata.isEmpty && !dataManager.isPeriodLoaded(period) && breakdowns.isEmpty
        let storeCount = storeCountForPeriod(period)
        let totalPeriodSpend = totalSpendForPeriod(period)

        return VStack(spacing: 0) {
            if isLoadingPeriod && storeCount > 0 {
                // Show skeleton loading cards with staggered appearance
                LazyVGrid(columns: storeGridColumns, spacing: 12) {
                    ForEach(0..<storeCount, id: \.self) { index in
                        SkeletonStoreCard(index: index)
                    }
                }
                .padding(.horizontal, 12)
                .transition(.opacity)
            } else {
                LazyVGrid(columns: storeGridColumns, spacing: 12) {
                    ForEach(Array(breakdowns.enumerated()), id: \.element.id) { index, breakdown in
                        ZStack(alignment: .topTrailing) {
                            // The card itself with staggered appearance
                            if isEditMode && period == selectedPeriod {
                                storeChartCard(breakdown, totalPeriodSpend: totalPeriodSpend, rank: index, totalStores: breakdowns.count)
                                    .modifier(JiggleModifier(isJiggling: isEditMode && draggingItem?.id != breakdown.id))
                                    .scaleEffect(draggingItem?.id == breakdown.id ? 1.05 : 1.0)
                                    .opacity(draggingItem?.id == breakdown.id ? 0.5 : 1.0)
                                    .zIndex(draggingItem?.id == breakdown.id ? 1 : 0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggingItem?.id == breakdown.id)
                                    .onDrag {
                                        self.draggingItem = breakdown
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                                        generator.impactOccurred()
                                        return NSItemProvider(object: breakdown.id as NSString)
                                    }
                                    .onDrop(of: [UTType.text], delegate: DropViewDelegate(
                                        destinationItem: breakdown,
                                        items: $displayedBreakdowns,
                                        draggingItem: $draggingItem,
                                        onReorder: saveCustomOrder
                                    ))
                            } else {
                                storeChartCard(breakdown, totalPeriodSpend: totalPeriodSpend, rank: index, totalStores: breakdowns.count)
                                    .staggeredAppearance(index: index, totalCount: breakdowns.count)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedBreakdown = breakdown
                                    }
                                    .onLongPressGesture(minimumDuration: 0.5) {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            isEditMode = true
                                        }
                                        let generator = UIImpactFeedbackGenerator(style: .medium)
                                        generator.impactOccurred()
                                    }
                            }

                            // Delete button (X) in edit mode
                            if isEditMode && period == selectedPeriod {
                                Button {
                                    breakdownToDelete = breakdown
                                    showingDeleteConfirmation = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.red)
                                        .background(
                                            Circle()
                                                .fill(Color.white)
                                                .frame(width: 18, height: 18)
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                }
                                .buttonStyle(DeleteButtonStyle())
                                .offset(x: 8, y: -8)
                                .transition(.scale.combined(with: .opacity))
                                .zIndex(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isLoadingPeriod)
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

// MARK: - Drop Delegate for Drag and Drop Reordering
struct DropViewDelegate: DropDelegate {
    let destinationItem: StoreBreakdown
    @Binding var items: [StoreBreakdown]
    @Binding var draggingItem: StoreBreakdown?
    let onReorder: () -> Void // Callback to save order
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // Haptic feedback on drop completion
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        draggingItem = nil
        
        // Save the new order after drop completes
        onReorder()
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        if draggingItem != destinationItem {
            let fromIndex = items.firstIndex(of: draggingItem)
            let toIndex = items.firstIndex(of: destinationItem)
            
            if let fromIndex = fromIndex, let toIndex = toIndex {
                // Haptic feedback on reorder
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                }
            }
        }
    }
}
    
    private func storeChartCard(_ breakdown: StoreBreakdown, totalPeriodSpend: Double, rank: Int, totalStores: Int) -> some View {
        // Calculate this store's percentage of total period spending
        let otherSpend = max(0, totalPeriodSpend - breakdown.totalStoreSpend)

        // Modern red color for all charts
        let storeColor = Color(red: 0.95, green: 0.25, blue: 0.30)

        // Create chart data: this store vs. other stores
        let chartData: [ChartData] = [
            ChartData(value: breakdown.totalStoreSpend, color: storeColor, label: breakdown.storeName),
            ChartData(value: otherSpend, color: Color.white.opacity(0.1), label: "Other")
        ]

        return VStack(spacing: 6) {
            IconDonutChartView(
                data: chartData,
                totalAmount: breakdown.totalStoreSpend,
                size: 84,
                currencySymbol: "€"
            )
            .drawingGroup()

            Text(breakdown.storeName.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .tracking(0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSort: SortOption
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.08, green: 0.07, blue: 0.12).ignoresSafeArea()
                
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

// MARK: - Jiggle Modifier for Edit Mode
struct JiggleModifier: ViewModifier {
    let isJiggling: Bool
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    
    // Random but consistent values per instance
    private let rotationAngle: Double
    private let duration: Double
    private let offsetMagnitude: CGFloat
    
    init(isJiggling: Bool) {
        self.isJiggling = isJiggling
        // Slight randomization for more natural feel
        self.rotationAngle = Double.random(in: 2.0...3.0)
        self.duration = Double.random(in: 0.12...0.14)
        self.offsetMagnitude = CGFloat.random(in: 0.3...0.6)
    }
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .task(id: isJiggling) {
                guard isJiggling else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rotation = 0
                        offset = .zero
                    }
                    return
                }
                
                // Start with random direction for natural look
                let startRotation: Double = Bool.random() ? rotationAngle : -rotationAngle
                let startOffsetX: CGFloat = Bool.random() ? offsetMagnitude : -offsetMagnitude
                let startOffsetY: CGFloat = Bool.random() ? offsetMagnitude : -offsetMagnitude
                
                rotation = startRotation
                offset = CGSize(width: startOffsetX, height: startOffsetY)
                
                // Continuous jiggle loop with varied timing
                while isJiggling {
                    // Rotation jiggle
                    withAnimation(.easeInOut(duration: duration)) {
                        rotation = -rotation
                    }
                    
                    // Offset jiggle (slightly different timing for organic feel)
                    withAnimation(.easeInOut(duration: duration * 1.1)) {
                        offset.width = -offset.width
                        offset.height = offset.height * 0.9 // Subtle variation
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }
    }
}

// MARK: - Premium Fade In Modifier
/// Refined fade-in animation following premium UX principles:
/// - Fast but smooth (350ms) - feels responsive, not sluggish
/// - Subtle transforms - 98% scale, 8pt offset (barely noticeable but adds polish)
/// - Consistent easing - easeOut for natural deceleration
struct PremiumFadeInModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.98)
            .offset(y: isVisible ? 0 : 8)
            .onAppear {
                withAnimation(.easeOut(duration: 0.35).delay(delay)) {
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

// MARK: - Staggered Card Appearance Modifier
/// Premium staggered animation for store cards:
/// - Starts after header cards (160ms base delay)
/// - Quick stagger between cards (60ms) - fast enough to feel cohesive
/// - Subtle transforms for polish without distraction
struct StaggeredCardModifier: ViewModifier {
    let index: Int
    @State private var isVisible = false

    // Base delay after header cards + per-card stagger
    private var appearDelay: Double {
        0.16 + (Double(index) * 0.06)
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.97)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                withAnimation(.easeOut(duration: 0.4).delay(appearDelay)) {
                    isVisible = true
                }
            }
            .onDisappear {
                isVisible = false
            }
    }
}

extension View {
    /// Premium fade-in with subtle scale and offset
    func premiumFadeIn(delay: Double = 0) -> some View {
        modifier(PremiumFadeInModifier(delay: delay))
    }

    /// Staggered appearance for grid items
    func staggeredAppearance(index: Int, totalCount: Int = 0) -> some View {
        modifier(StaggeredCardModifier(index: index))
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

// MARK: - Skeleton Store Card (Loading Placeholder)
struct SkeletonStoreCard: View {
    let index: Int
    @State private var isAnimating = false
    @State private var shimmerOffset: CGFloat = -150

    // Fast stagger (40ms) for premium feel
    private var appearDelay: Double {
        0.16 + (Double(index) * 0.04)
    }

    var body: some View {
        VStack(spacing: 10) {
            // Skeleton donut chart
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 96, height: 96)
                .overlay(
                    Circle()
                        .fill(Color(red: 0.08, green: 0.07, blue: 0.12))
                        .frame(width: 59, height: 59)
                )
                .overlay(
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .frame(width: 81, height: 81)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                )

            // Skeleton store name
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.08))
                .frame(width: 65, height: 16)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .overlay(
            // Shimmer effect
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.05),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: shimmerOffset)
        )
        .clipped()
        .opacity(isAnimating ? 1 : 0)
        .scaleEffect(isAnimating ? 1 : 0.98)
        .onAppear {
            // Premium fade-in
            withAnimation(.easeOut(duration: 0.3).delay(appearDelay)) {
                isAnimating = true
            }
            // Continuous shimmer animation
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerOffset = 150
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

// MARK: - Store Card Button Style
struct StoreCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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

// MARK: - Delete Button Style
struct DeleteButtonStyle: ButtonStyle {
    @State private var isPulsing = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : (isPulsing ? 1.1 : 1.0))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onAppear {
                // Subtle pulse animation on appear
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
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
