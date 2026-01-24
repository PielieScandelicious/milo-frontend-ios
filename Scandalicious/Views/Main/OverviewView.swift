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



struct OverviewView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var dataManager: StoreDataManager
    @ObservedObject var rateLimitManager = RateLimitManager.shared
    @Environment(\.scenePhase) private var scenePhase

    // Track the last time we checked for Share Extension uploads
    @State private var lastCheckedUploadTimestamp: TimeInterval = 0

    // Track when a receipt is being uploaded from Scan tab
    @State private var isReceiptUploading = false

    @State private var selectedPeriod: String = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US") // Ensure consistent English month names
        return dateFormatter.string(from: Date())
    }()
    @State private var selectedSort: SortOption = .highestSpend
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
    @State private var timerTick = false
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
        // Only show periods that have actual data
        let periods = dataManager.breakdownsByPeriod().keys.sorted()

        // If no periods with data, show only the current month (empty state)
        if periods.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            return [dateFormatter.string(from: Date())]
        }

        return periods
    }
    
    private var currentBreakdowns: [StoreBreakdown] {
        // Always use displayedBreakdowns to maintain consistent ordering
        // This prevents items from jumping when entering/exiting edit mode
        if displayedBreakdowns.isEmpty {
            updateDisplayedBreakdownsSync()
        }
        return displayedBreakdowns
    }
    
    // Synchronous version for use in computed properties
    private func updateDisplayedBreakdownsSync() {
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == selectedPeriod }
        
        // Apply sorting
        switch selectedSort {
        case .highestSpend:
            breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        case .lowestSpend:
            breakdowns.sort { $0.totalStoreSpend < $1.totalStoreSpend }
        case .storeName:
            breakdowns.sort { $0.storeName < $1.storeName }
        }
        
        // Apply saved custom order if available
        breakdowns = applyCustomOrder(to: breakdowns, for: selectedPeriod)
        
        displayedBreakdowns = breakdowns
    }
    
    // Update displayed breakdowns when filters change
    private func updateDisplayedBreakdowns() {
        print("🔄 updateDisplayedBreakdowns called")
        print("   selectedPeriod: '\(selectedPeriod)'")
        print("   Total breakdowns in dataManager: \(dataManager.storeBreakdowns.count)")

        // Debug: Print all periods in the data
        let allPeriods = Set(dataManager.storeBreakdowns.map { $0.period })
        print("   Available periods: \(allPeriods)")

        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == selectedPeriod }
        print("   Filtered breakdowns for '\(selectedPeriod)': \(breakdowns.count)")

        // Apply sorting
        switch selectedSort {
        case .highestSpend:
            breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        case .lowestSpend:
            breakdowns.sort { $0.totalStoreSpend < $1.totalStoreSpend }
        case .storeName:
            breakdowns.sort { $0.storeName < $1.storeName }
        }

        // Apply saved custom order if available
        breakdowns = applyCustomOrder(to: breakdowns, for: selectedPeriod)

        displayedBreakdowns = breakdowns
        print("   Final displayedBreakdowns count: \(displayedBreakdowns.count)")
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
        currentBreakdowns.reduce(0) { $0 + $1.totalStoreSpend }
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
            Color(white: 0.05).ignoresSafeArea()
            
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
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Liquid Glass Period Filter at the top
                        liquidGlassPeriodFilter
                            .padding(.top, 12)
                            .padding(.bottom, 12)

                        // Content
                        VStack(spacing: 24) {
                            // Total spending card
                            totalSpendingCard

                            // Health score card
                            healthScoreCard

                            // Store breakdowns grid
                            storeBreakdownsGrid
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                    .frame(maxWidth: .infinity)
                    // NOTE: Removed .contentShape and gesture to debug pull-to-refresh
                    // .contentShape(Rectangle())
                    // .simultaneousGesture(TapGesture().onEnded { ... })
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .scrollDismissesKeyboard(.interactively)
                .background(Color(white: 0.05))
                .onAppear {
                    print("📱 ScrollView with .refreshable appeared - pull down to refresh!")
                }
                .refreshable {
                    print("⬇️⬇️⬇️ PULL-TO-REFRESH TRIGGERED ⬇️⬇️⬇️")
                    print("🔄 Period: '\(selectedPeriod)'")
                    fflush(stdout) // Force flush to ensure logs appear immediately
                    let startTime = Date()

                    // Refresh data for the currently selected period
                    await dataManager.refreshData(for: .month, periodString: selectedPeriod)
                    print("✅ Pull-to-refresh completed")

                    // Ensure minimum refresh duration for smooth UX (at least 0.8 seconds)
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed < 0.8 {
                        try? await Task.sleep(for: .seconds(0.8 - elapsed))
                    }

                    // Add haptic feedback on completion
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)

                    // Update refresh time for "Updated X ago" display
                    lastRefreshTime = Date()
                }
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
            AllStoresBreakdownView(period: selectedPeriod, breakdowns: currentBreakdowns)
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
            updateDisplayedBreakdowns()

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
                await dataManager.refreshData(for: .month, periodString: selectedPeriod)
                print("✅ Backend data refreshed after receipt upload for period: \(selectedPeriod)")

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
                print("✅ Backend data refreshed after receipt deletion for period: \(selectedPeriod)")

                // Rate limit sync is already handled in ReceiptDetailsView, no need to sync again here
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Trigger re-render to update time display and green highlight
            timerTick.toggle()
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
            updateDisplayedBreakdowns()
            // Prefetch insights for the new period
            prefetchInsights()
        }
        .onChange(of: selectedSort) { oldValue, newValue in
            // Exit edit mode when changing sort to avoid inconsistency
            if isEditMode {
                isEditMode = false
            }
            updateDisplayedBreakdowns()
        }
        .onChange(of: dataManager.storeBreakdowns) { oldValue, newValue in
            if !isEditMode {
                updateDisplayedBreakdowns()
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
            print("📬 Received share extension upload notification - showing syncing indicator")
            if !isReceiptUploading {
                isReceiptUploading = true
                // The actual refresh will be handled by checkForShareExtensionUploads
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

            // Update last checked timestamp
            lastCheckedUploadTimestamp = uploadTimestamp

            // Show syncing indicator immediately
            isReceiptUploading = true

            // Post notification so other views can react
            NotificationCenter.default.post(name: .shareExtensionUploadDetected, object: nil)

            // Trigger refresh with retry mechanism
            Task {
                await refreshWithRetry()
            }
        }
    }

    /// Refreshes data with retry mechanism for share extension uploads
    /// The share extension signals immediately but the upload + backend processing can take 5-15 seconds
    private func refreshWithRetry() async {
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

        // Update UI on main thread
        await MainActor.run {
            // Clear syncing indicator
            isReceiptUploading = false

            if selectedPeriod == currentMonthPeriod {
                print("📊 User is viewing current month - updating display")
                updateDisplayedBreakdowns()
            } else {
                print("ℹ️ User is viewing '\(selectedPeriod)', not '\(currentMonthPeriod)' - may need to switch periods to see new data")
            }

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
    
    private var liquidGlassPeriodFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePeriods, id: \.self) { period in
                    periodButton(for: period)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func periodButton(for period: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedPeriod = period
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } label: {
            Text(period)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedPeriod == period ? Color.black : Color.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background {
                    if selectedPeriod == period {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePeriods, id: \.self) { period in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedPeriod == period ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedPeriod == period ? Color.white : Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var totalSpendingCard: some View {
        Button {
            showingAllStoresBreakdown = true
        } label: {
            VStack(spacing: 8) {
                Text("Total Spending")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(String(format: "€%.0f", totalPeriodSpending))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text(selectedPeriod)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                // Syncing/Synced indicator
                Group {
                    if dataManager.isLoading || dataManager.isRefreshing || isReceiptUploading {
                        HStack(spacing: 6) {
                            SyncingArrowsView()
                            Text("Syncing...")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.blue)
                        .padding(.top, 4)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.icloud.fill")
                                .font(.system(size: 10))
                            Text("Synced")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundColor(.green)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.vertical, 28)
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
        .overlay(alignment: .bottomLeading) {
            if totalPeriodSpending > 0 {
                InsightButton(insightType: .totalSpending(
                    amount: totalPeriodSpending,
                    period: selectedPeriod,
                    storeCount: currentBreakdowns.count,
                    topStore: currentBreakdowns.first?.storeName
                ))
                .padding(12)
            }
        }
        .padding(.horizontal)
    }
    
    // Helper function to format time ago
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return ""
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }

    // MARK: - Health Score Card

    private var healthScoreCard: some View {
        // Use the average health score from the data manager (fetched from backend)
        // Only show score if there are breakdowns for the current period
        let averageScore: Double? = currentBreakdowns.isEmpty ? nil : dataManager.averageHealthScore
        let totalVisits = currentBreakdowns.reduce(0) { $0 + $1.visitCount }

        return Button {
            showingHealthScoreTransactions = true
        } label: {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(averageScore.healthScoreColor)

                    Text("Health Score")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(1)

                    Spacer()

                    if let score = averageScore {
                        Text(score.healthScoreLabel)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(score.healthScoreColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(score.healthScoreColor.opacity(0.15))
                            )
                    }
                }

                HStack(alignment: .center, spacing: 16) {
                    LiquidGaugeView(
                        score: averageScore,
                        size: 70,
                        showLabel: false
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        if let score = averageScore {
                            Text("\(score.formattedHealthScore) / 5.0")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("Average")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            Text("No Data Yet")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))

                            Text("Upload receipts to see your health score")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Spacer()
                }
            }
            .padding(16)
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
        .overlay(alignment: .bottomTrailing) {
            if averageScore != nil {
                InsightButton(insightType: .healthScore(
                    score: averageScore,
                    period: selectedPeriod,
                    totalItems: totalVisits
                ))
                .padding(12)
            }
        }
        .padding(.horizontal)
    }

    private var storeBreakdownsGrid: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16),
                GridItem(.flexible(), spacing: 16)
            ], spacing: 20) {
                ForEach(currentBreakdowns) { breakdown in
                    ZStack(alignment: .topTrailing) {
                        // The card itself
                        if isEditMode {
                            storeChartCard(breakdown)
                                .modifier(JiggleModifier(isJiggling: isEditMode && draggingItem?.id != breakdown.id))
                                .scaleEffect(draggingItem?.id == breakdown.id ? 1.05 : 1.0)
                                .opacity(draggingItem?.id == breakdown.id ? 0.5 : 1.0) // Show we're dragging
                                .zIndex(draggingItem?.id == breakdown.id ? 1 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggingItem?.id == breakdown.id)
                                .onDrag {
                                    self.draggingItem = breakdown
                                    // Haptic feedback when starting drag
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
                            // Use gesture with high priority to ensure long press works
                            storeChartCard(breakdown)
                                .contentShape(Rectangle()) // Ensure entire card area is tappable
                                .onTapGesture {
                                    selectedBreakdown = breakdown
                                }
                                .onLongPressGesture(minimumDuration: 0.5) {
                                    // Enter edit mode on long press
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        isEditMode = true
                                    }
                                    
                                    // Haptic feedback
                                    let generator = UIImpactFeedbackGenerator(style: .medium)
                                    generator.impactOccurred()
                                }
                        }
                        
                        // Delete button (X) in edit mode
                        if isEditMode {
                            Button {
                                // Show confirmation dialog
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
            .padding(.horizontal)
        }
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
    
    private func storeChartCard(_ breakdown: StoreBreakdown) -> some View {
        VStack(spacing: 8) {
            IconDonutChartView(
                data: breakdown.categories.toIconChartData(),
                totalAmount: breakdown.totalStoreSpend,
                size: 80,
                currencySymbol: "€"
            )

            Text(breakdown.storeName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
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
