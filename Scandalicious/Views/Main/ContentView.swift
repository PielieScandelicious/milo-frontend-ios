//
//  ContentView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseAuth

// MARK: - Environment key for active tab (used by MiniBudgetRing to replay animation)

private struct SelectedTabIndexKey: EnvironmentKey {
    static let defaultValue: Int = 1 // scan tab by default
}

extension EnvironmentValues {
    var selectedTabIndex: Int {
        get { self[SelectedTabIndexKey.self] }
        set { self[SelectedTabIndexKey.self] = newValue }
    }
}

struct ContentView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @StateObject private var transactionManager = TransactionManager()
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedTab: Tab = .home
    @State private var showSignOutConfirmation = false
    @State private var hasLoadedInitialData = false

    enum Tab: Int, Hashable {
        case budget = 0
        case home = 1
        case dobby = 2
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label(L("tab_budget"), systemImage: "creditcard.fill")
                    }
                    .tag(Tab.budget)

                ScanTab()
                    .tabItem {
                        Label(L("tab_home"), systemImage: "house.fill")
                    }
                    .tag(Tab.home)

                ScandaLiciousTab()
                    .tabItem {
                        Label {
                            Text(L("tab_milo"))
                        } icon: {
                            MiloTabIcon()
                        }
                    }
                    .tag(Tab.dobby)
            }
            .tint(.blue) // Apple blue
            .toolbarBackground(.ultraThinMaterial, for: .tabBar)
            .toolbarBackgroundVisibility(.visible, for: .tabBar)
            .environment(\.selectedTabIndex, selectedTab.rawValue)

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
        .confirmationDialog(L("sign_out"), isPresented: $showSignOutConfirmation) {
            Button(L("sign_out"), role: .destructive) {
                do {
                    try authManager.signOut()
                } catch {
                }
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("sign_out_confirm"))
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
    @ObservedObject private var syncManager = AppSyncManager.shared
    @State private var isTabVisible = false

    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
        }
        .overlay(alignment: .top) {
            VStack {
                if isTabVisible && syncManager.syncState == .syncing {
                    syncingStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                } else if isTabVisible && syncManager.syncState == .synced {
                    syncedStatusBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: syncManager.syncState)
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
            Text(L("syncing"))
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.blue)
        .padding(.top, 12)
    }

    private var syncedStatusBanner: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: 11))
            Text(L("synced"))
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.green)
        .padding(.top, 12)
    }
}

// MARK: - Milo Tab Icon

/// Tiny Dachshund head for the tab bar, rendered as a template image
/// so iOS can apply the correct tint for selected/unselected states.
private struct MiloTabIcon: View {
    var body: some View {
        Image(uiImage: renderTabIcon())
            .renderingMode(.template)
    }

    private func renderTabIcon() -> UIImage {
        let size: CGFloat = 28
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        return renderer.image { ctx in
            let gc = ctx.cgContext
            let u = size / 100
            let cx = size / 2
            let cy = size / 2

            gc.setFillColor(UIColor.black.cgColor)

            // Left ear (large floppy)
            gc.beginPath()
            gc.move(to: CGPoint(x: cx - 18 * u, y: cy - 16 * u))
            gc.addCurve(
                to: CGPoint(x: cx - 50 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx - 28 * u, y: cy - 34 * u),
                control2: CGPoint(x: cx - 48 * u, y: cy - 32 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 44 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx - 58 * u, y: cy - 2 * u),
                control2: CGPoint(x: cx - 56 * u, y: cy + 20 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 32 * u, y: cy + 26 * u),
                control1: CGPoint(x: cx - 40 * u, y: cy + 34 * u),
                control2: CGPoint(x: cx - 36 * u, y: cy + 34 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 18 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx - 26 * u, y: cy + 10 * u),
                control2: CGPoint(x: cx - 14 * u, y: cy - 4 * u)
            )
            gc.closePath()
            gc.fillPath()

            // Right ear (large floppy)
            gc.beginPath()
            gc.move(to: CGPoint(x: cx + 18 * u, y: cy - 16 * u))
            gc.addCurve(
                to: CGPoint(x: cx + 50 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx + 28 * u, y: cy - 34 * u),
                control2: CGPoint(x: cx + 48 * u, y: cy - 32 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 44 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx + 58 * u, y: cy - 2 * u),
                control2: CGPoint(x: cx + 56 * u, y: cy + 20 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 32 * u, y: cy + 26 * u),
                control1: CGPoint(x: cx + 40 * u, y: cy + 34 * u),
                control2: CGPoint(x: cx + 36 * u, y: cy + 34 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 18 * u, y: cy - 16 * u),
                control1: CGPoint(x: cx + 26 * u, y: cy + 10 * u),
                control2: CGPoint(x: cx + 14 * u, y: cy - 4 * u)
            )
            gc.closePath()
            gc.fillPath()

            // Head (cute dog shape)
            gc.beginPath()
            gc.move(to: CGPoint(x: cx, y: cy - 32 * u))
            gc.addCurve(
                to: CGPoint(x: cx + 36 * u, y: cy - 6 * u),
                control1: CGPoint(x: cx + 16 * u, y: cy - 32 * u),
                control2: CGPoint(x: cx + 32 * u, y: cy - 22 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx + 18 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx + 36 * u, y: cy + 10 * u),
                control2: CGPoint(x: cx + 28 * u, y: cy + 26 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 18 * u, y: cy + 28 * u),
                control1: CGPoint(x: cx + 8 * u, y: cy + 34 * u),
                control2: CGPoint(x: cx - 8 * u, y: cy + 34 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx - 36 * u, y: cy - 6 * u),
                control1: CGPoint(x: cx - 28 * u, y: cy + 26 * u),
                control2: CGPoint(x: cx - 36 * u, y: cy + 10 * u)
            )
            gc.addCurve(
                to: CGPoint(x: cx, y: cy - 32 * u),
                control1: CGPoint(x: cx - 32 * u, y: cy - 22 * u),
                control2: CGPoint(x: cx - 16 * u, y: cy - 32 * u)
            )
            gc.closePath()
            gc.fillPath()

            // Snout (lighter — leave as filled, template mode handles tint)
            gc.fillEllipse(in: CGRect(x: cx - 20 * u, y: cy + 2 * u, width: 40 * u, height: 30 * u))

            // Cut out eyes (white = transparent in template mode)
            gc.setBlendMode(.clear)

            // Left eye
            gc.fillEllipse(in: CGRect(
                x: cx - 14 * u - 7 * u, y: cy - 8 * u - 8 * u,
                width: 14 * u, height: 16 * u
            ))
            // Right eye
            gc.fillEllipse(in: CGRect(
                x: cx + 14 * u - 7 * u, y: cy - 8 * u - 8 * u,
                width: 14 * u, height: 16 * u
            ))

            // Nose cutout
            gc.fillEllipse(in: CGRect(
                x: cx - 7 * u, y: cy + 4 * u,
                width: 14 * u, height: 10 * u
            ))

            gc.setBlendMode(.normal)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
