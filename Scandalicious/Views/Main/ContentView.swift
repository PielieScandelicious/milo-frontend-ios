//
//  ContentView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseAuth

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var transactionManager = TransactionManager()
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedTab: Tab = .scan
    @State private var showSignOutConfirmation = false
    @State private var hasLoadedInitialData = false

    enum Tab: Int, Hashable {
        case view = 0
        case scan = 1
        case dobby = 2
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label("View", systemImage: "chart.pie.fill")
                    }
                    .tag(Tab.view)

                ScanTab()
                    .tabItem {
                        Label("Scan", systemImage: "qrcode.viewfinder")
                    }
                    .tag(Tab.scan)

                ScandaLiciousTab()
                    .tabItem {
                        Label("Milo", systemImage: "sparkles")
                    }
                    .tag(Tab.dobby)
            }
            .tint(.blue) // Apple blue
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)

            // Loading screen overlay
            if !hasLoadedInitialData {
                SyncLoadingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasLoadedInitialData)
        .environmentObject(transactionManager)
        .environmentObject(dataManager)
        .preferredColorScheme(.dark)
        .onAppear {
            // Configure data manager on first appear
            if !hasLoadedInitialData {
                dataManager.configure(with: transactionManager)

                let cache = AppDataCache.shared

                // INSTANT LAUNCH: If cache has ALL data, show UI immediately
                if cache.isComplete {
                    dataManager.populateFromCache(cache)
                    hasLoadedInitialData = true

                    // Silent background refresh (no UI impact)
                    Task(priority: .utility) {
                        try? await Task.sleep(for: .seconds(2))
                        await loadAllData(cache: cache, showLoading: false)
                    }
                } else {
                    // Loading screen stays until ALL data is fetched
                    Task {
                        await loadAllData(cache: cache, showLoading: true)
                    }
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                do {
                    try authManager.signOut()
                } catch {
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Full Data Loading

    /// Loads data needed for smooth browsing (last 12 months).
    /// When showLoading=true, keeps loading screen visible until done.
    /// When showLoading=false, runs silently in background.
    private func loadAllData(cache: AppDataCache, showLoading: Bool) async {
        // Phase 1: Period metadata + store breakdowns for recent periods
        await dataManager.fetchPeriodMetadata()

        guard !dataManager.periodMetadata.isEmpty else {
            if showLoading {
                await MainActor.run { hasLoadedInitialData = true }
            }
            return
        }

        // Only preload the last 12 months of data for fast startup
        let recentPeriods = cache.recentMonthPeriods

        // Load store breakdowns for recent periods in parallel
        await withTaskGroup(of: Void.self) { group in
            for period in recentPeriods {
                group.addTask {
                    await dataManager.fetchPeriodDetails(period)
                }
            }
        }

        // Phase 2: Receipts + category data for recent month periods in parallel
        await withTaskGroup(of: Void.self) { group in
            for period in recentPeriods {
                group.addTask { await cache.preloadReceipts(for: period) }
                group.addTask { await cache.preloadCategoryData(for: period) }
            }
        }

        // Phase 3: Year summaries for years in recent periods + all-time data in parallel
        let distinctYears = Set(recentPeriods.compactMap { period -> String? in
            let parts = period.split(separator: " ")
            return parts.count == 2 ? String(parts[1]) : nil
        })
        await withTaskGroup(of: Void.self) { group in
            for year in distinctYears {
                group.addTask { await cache.preloadYearSummary(for: year) }
            }
            group.addTask { await cache.preloadAllTimeAggregate() }
            group.addTask { await cache.preloadBudgetProgress() }
        }

        // Phase 4: Category items (transactions per category) for recent periods
        // Must run after Phase 2 since preloadCategoryItems reads pieChartSummaryByPeriod
        await withTaskGroup(of: Void.self) { group in
            for period in recentPeriods {
                group.addTask { await cache.preloadCategoryItems(for: period) }
            }
        }

        // All data loaded — dismiss loading screen
        if showLoading {
            await MainActor.run { hasLoadedInitialData = true }
        }
    }
}

// MARK: - View Tab
struct ViewTab: View {
    @Binding var showSignOutConfirmation: Bool
    @ObservedObject var dataManager: StoreDataManager

    var body: some View {
        NavigationStack {
            OverviewView(dataManager: dataManager, showSignOutConfirmation: $showSignOutConfirmation)
                .navigationBarTitleDisplayMode(.inline)
        }
        .id("ViewTab") // Prevent recreation
    }
}

// MARK: - Scan Tab
struct ScanTab: View {
    var body: some View {
        ReceiptScanView()
            .id("ScanTab") // Prevent recreation
    }
}

// MARK: - ScandaLicious Tab
struct ScandaLiciousTab: View {
    @ObservedObject private var rateLimitManager = RateLimitManager.shared
    @State private var isTabVisible = false

    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .top) {
            VStack {
                if isTabVisible && rateLimitManager.isReceiptUploading {
                    syncingStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if isTabVisible && rateLimitManager.showReceiptSynced {
                    syncedStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.isReceiptUploading)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rateLimitManager.showReceiptSynced)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isTabVisible)
        }
        .onAppear {
            // Delay slightly to trigger slide-in animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTabVisible = true
                }
            }
        }
        .onDisappear {
            isTabVisible = false
        }
        .id("ScandaLiciousTab") // Prevent recreation
    }

    private var syncingStatusBanner: some View {
        HStack(spacing: 6) {
            SyncingArrowsView()
            Text("Syncing")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.top, 12)
    }

    private var syncedStatusBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 11))
            Text("Synced")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.top, 12)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
