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
        case budget = 1
        case scan = 2
        case dobby = 3
    }
    
    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label("View", systemImage: "chart.pie.fill")
                    }
                    .tag(Tab.view)

                BudgetTab()
                    .tabItem {
                        Label("Budget", systemImage: "creditcard.fill")
                    }
                    .tag(Tab.budget)

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

                // Optimized loading: fetch lightweight period metadata first (1 API call)
                // Falls back to fetchAllHistoricalData if /analytics/periods is not available
                Task {
                    print("🚀 App launched - fetching period metadata (optimized)")

                    // Step 1: Fetch lightweight period metadata (falls back if endpoint unavailable)
                    await dataManager.fetchPeriodMetadata()

                    // Step 2: Load current period + adjacent periods BEFORE showing UI
                    // This ensures smooth swiping without lag on first launch
                    // If fallback was used, all data is already loaded via fetchAllHistoricalData()
                    if !dataManager.periodMetadata.isEmpty {
                        // Get periods to preload - we need current + 2 before + 2 after for smooth swiping
                        // Since periodMetadata is sorted most recent first, we preload first 5 periods
                        let periodsToPreload = Array(dataManager.periodMetadata.prefix(8))
                        print("📊 Preloading \(periodsToPreload.count) periods for smooth swiping")

                        // Load current period + immediate neighbors first (blocking)
                        // These are critical for smooth UX - load in parallel but wait for all
                        let criticalPeriods = Array(periodsToPreload.prefix(5))
                        print("📊 Loading \(criticalPeriods.count) critical periods before showing UI...")

                        await withTaskGroup(of: Void.self) { group in
                            for periodMeta in criticalPeriods {
                                group.addTask {
                                    await dataManager.fetchPeriodDetails(periodMeta.period)
                                }
                            }
                        }
                        print("✅ Critical periods loaded - showing UI")

                        // Show UI after critical periods are loaded
                        await MainActor.run {
                            hasLoadedInitialData = true
                        }

                        // Then load remaining periods in background
                        if periodsToPreload.count > criticalPeriods.count {
                            let remainingPeriods = Array(periodsToPreload.dropFirst(criticalPeriods.count))
                            print("📊 Background loading \(remainingPeriods.count) additional periods...")
                            await withTaskGroup(of: Void.self) { group in
                                for periodMeta in remainingPeriods {
                                    group.addTask {
                                        await dataManager.fetchPeriodDetails(periodMeta.period)
                                    }
                                }
                            }
                            print("✅ All \(periodsToPreload.count) periods preloaded")
                        }
                    } else {
                        print("📊 Using fallback: all historical data already loaded")
                        await MainActor.run {
                            hasLoadedInitialData = true
                        }
                    }
                    print("✅ Initial data loaded successfully")
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            print("🔄 Tab changed: \(oldValue.rawValue) → \(newValue.rawValue)")
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                do {
                    try authManager.signOut()
                } catch {
                    print("Error signing out: \(error.localizedDescription)")
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
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

// MARK: - Budget Tab
struct BudgetTab: View {
    var body: some View {
        NavigationStack {
            BudgetView()
        }
        .id("BudgetTab") // Prevent recreation
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


