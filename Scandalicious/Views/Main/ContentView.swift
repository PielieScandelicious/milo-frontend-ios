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
    static let defaultValue: Int = 0 // home tab by default
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
    @StateObject private var brandCashbackViewModel = BrandCashbackViewModel()
    @ObservedObject private var gm = GamificationManager.shared

    // Unified overlay queue — all reward overlays flow through here in order
    private enum OverlayItem {
        case brandCashback(dealName: String, amount: Double)
        case referral(amount: Double)
    }
    @State private var overlayQueue: [OverlayItem] = []
    @State private var activeOverlay: OverlayItem? = nil

    enum Tab: Int, Hashable {
        case home = 0
        case promos = 1
        case insights = 2
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ScanTab()
                    .tabItem {
                        Label(L("tab_home"), systemImage: "house.fill")
                    }
                    .tag(Tab.home)

                PromosTab()
                    .tabItem {
                        Label("Deals", systemImage: "tag.fill")
                    }
                    .tag(Tab.promos)

                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label("Insights", systemImage: "chart.pie.fill")
                    }
                    .tag(Tab.insights)
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

            // Unified reward overlay queue — brand cashback → referral → badges
            if let overlay = activeOverlay {
                Group {
                    switch overlay {
                    case .brandCashback(let name, let amount):
                        CashbackEarnedOverlay(
                            dealName: name,
                            cashbackAmount: amount,
                            onDismiss: {
                                brandCashbackViewModel.dismissEarnedOverlay()
                                dequeueOverlay()
                            }
                        )
                    case .referral(let amount):
                        ReferralRevealOverlay(
                            cashbackAmount: amount,
                            onDismiss: {
                                gm.dismissReferralEarnedOverlay()
                                dequeueOverlay()
                            }
                        )
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: hasLoadedInitialData)
        .environmentObject(transactionManager)
        .environmentObject(dataManager)
        .environmentObject(brandCashbackViewModel)
        .preferredColorScheme(.dark)
        .onAppear {
            // Configure data manager on first appear
            if !hasLoadedInitialData {
                dataManager.configure(with: transactionManager)
                Task {
                    await loadAllData()
                }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToDealsTab)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .promos
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("app.switchToHomeTab"))) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .home
            }
        }
        .onChange(of: brandCashbackViewModel.showEarnedOverlay) { _, showing in
            if showing {
                enqueueOverlay(.brandCashback(
                    dealName: brandCashbackViewModel.lastEarnedDealName,
                    amount: brandCashbackViewModel.lastEarnedAmount
                ))
            }
        }
        .onChange(of: gm.showReferralEarnedOverlay) { _, showing in
            if showing {
                enqueueOverlay(.referral(amount: gm.pendingOverlayEuros))
            }
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

    // MARK: - Overlay Queue

    private func enqueueOverlay(_ item: OverlayItem) {
        if activeOverlay == nil {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                activeOverlay = item
            }
        } else {
            overlayQueue.append(item)
        }
    }

    private func dequeueOverlay() {
        withAnimation(.easeOut(duration: 0.3)) {
            activeOverlay = nil
        }
        guard !overlayQueue.isEmpty else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.activeOverlay = self.overlayQueue.removeFirst()
            }
        }
    }

    // MARK: - Full Data Loading

    /// Fetches period metadata and preloads all Budget tab data for the current month
    /// and 2 previous months, then dismisses the loading screen.
    private func loadAllData() async {
        // Phase 1: Lightweight period metadata (all periods)
        await dataManager.fetchPeriodMetadata()

        guard !dataManager.periodMetadata.isEmpty else {
            await MainActor.run { hasLoadedInitialData = true }
            return
        }

        // Phase 2: Parallel preload of ALL Budget tab data for 3 months
        let targetPeriods = computeTargetPeriods()
        let cache = BudgetTabPreloadCache.shared

        await withTaskGroup(of: Void.self) { group in
            // Store breakdowns for all 3 periods (parallel)
            for period in targetPeriods {
                group.addTask {
                    await self.dataManager.fetchPeriodDetails(period)
                }
            }

            // Receipts for all 3 periods (parallel, all pages)
            for period in targetPeriods {
                group.addTask {
                    await self.preloadReceipts(for: period, into: cache)
                }
            }

            // Category breakdown (pie chart) + category line items for all 3 periods (parallel)
            for period in targetPeriods {
                group.addTask {
                    let components = self.parsePeriodComponents(period)
                    guard components.month > 0 && components.year > 0 else { return }

                    // First: fetch pie chart summary to get category names
                    guard let response = try? await AnalyticsAPIService.shared.getPieChartSummary(
                        month: components.month,
                        year: components.year
                    ) else { return }

                    await MainActor.run {
                        cache.categoryDataByPeriod[period] = response
                    }

                    // Then: fetch first page of transactions for each category (parallel)
                    let categories = response.categories
                    guard !categories.isEmpty else { return }
                    guard let dates = self.parsePeriodToDates(period) else { return }

                    await withTaskGroup(of: (String, [APITransaction]).self) { itemGroup in
                        for category in categories {
                            itemGroup.addTask {
                                var filters = TransactionFilters()
                                filters.category = category.name
                                filters.page = 1
                                filters.pageSize = 5
                                filters.startDate = dates.start
                                filters.endDate = dates.end

                                if let txResponse = try? await AnalyticsAPIService.shared.getTransactions(filters: filters) {
                                    return (category.categoryId, txResponse.transactions)
                                }
                                return (category.categoryId, [])
                            }
                        }

                        var itemsForPeriod: [String: [APITransaction]] = [:]
                        for await (categoryId, transactions) in itemGroup {
                            if !transactions.isEmpty {
                                itemsForPeriod[categoryId] = transactions
                            }
                        }

                        await MainActor.run {
                            cache.categoryItemsByPeriod[period] = itemsForPeriod
                        }
                    }
                }
            }

            // Insights: trends + period metadata (parallel)
            group.addTask {
                if let trends = try? await AnalyticsAPIService.shared.getTrends(periodType: .month, numPeriods: 12) {
                    await MainActor.run {
                        cache.trendData = trends
                    }
                }
            }
            group.addTask {
                if let periods = try? await AnalyticsAPIService.shared.getPeriods(periodType: .month, numPeriods: 52) {
                    await MainActor.run {
                        cache.insightsPeriodMetadata = periods.periods
                    }
                }
            }

            // Budget auto-rollover then progress (current month only)
            group.addTask {
                try? await BudgetAPIService.shared.performAutoRollover()
                if let progress = try? await BudgetAPIService.shared.getBudgetProgress() {
                    await MainActor.run {
                        cache.budgetProgress = progress
                    }
                }
            }

            // Budget history
            group.addTask {
                if let history = try? await BudgetAPIService.shared.getBudgetHistory() {
                    await MainActor.run {
                        cache.budgetHistory = history.budgetHistory
                    }
                }
            }
        }

        await MainActor.run {
            cache.hasPreloaded = true
            hasLoadedInitialData = true
        }
    }

    // MARK: - Preload Helpers

    /// Compute target periods: current month + 2 previous months
    private func computeTargetPeriods() -> [String] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = Locale(identifier: "en_US")
        let now = Date()
        return (0...2).reversed().compactMap { i in
            Calendar.current.date(byAdding: .month, value: -i, to: now).map { fmt.string(from: $0) }
        }
    }

    /// Parse period string (e.g. "March 2026") to month/year components
    private func parsePeriodComponents(_ period: String) -> (month: Int, year: Int) {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = Locale(identifier: "en_US")
        guard let date = fmt.date(from: period) else {
            let now = Date()
            return (Calendar.current.component(.month, from: now), Calendar.current.component(.year, from: now))
        }
        return (Calendar.current.component(.month, from: date), Calendar.current.component(.year, from: date))
    }

    /// Parse period string to start/end dates for receipt filtering
    private func parsePeriodToDates(_ period: String) -> (start: Date, end: Date)? {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM yyyy"
        fmt.locale = Locale(identifier: "en_US")
        fmt.timeZone = TimeZone(identifier: "UTC")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        guard let date = fmt.date(from: period) else { return nil }
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) else { return nil }
        guard let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, second: -1), to: startOfMonth) else { return nil }
        return (startOfMonth, endOfMonth)
    }

    /// Preload all receipt pages for a given period into the cache
    private func preloadReceipts(for period: String, into cache: BudgetTabPreloadCache) async {
        guard let dates = parsePeriodToDates(period) else { return }

        var allReceipts: [APIReceipt] = []
        var currentPage = 1
        let pageSize = 20

        // Load all pages
        while true {
            var filters = ReceiptFilters()
            filters.startDate = dates.start
            filters.endDate = dates.end
            filters.page = currentPage
            filters.pageSize = pageSize

            guard let response = try? await AnalyticsAPIService.shared.getReceipts(filters: filters) else { break }
            allReceipts.append(contentsOf: response.receipts)

            if response.page >= response.totalPages {
                break
            }
            currentPage += 1
        }

        await MainActor.run {
            cache.receiptsByPeriod[period] = allReceipts
        }
    }
}

// MARK: - View Tab
struct ViewTab: View {
    @Binding var showSignOutConfirmation: Bool
    @ObservedObject var dataManager: StoreDataManager

    var body: some View {
        NavigationStack {
            InsightsTabView(dataManager: dataManager)
        }
        .id("ViewTab") // Prevent recreation
    }
}

// MARK: - Scan Tab
struct ScanTab: View {
    var body: some View {
        HomeTabView()
            .id("ScanTab") // Prevent recreation
    }
}

// MARK: - Promos Tab
struct PromosTab: View {
    @StateObject private var viewModel = PromosViewModel()

    var body: some View {
        NavigationStack {
            PromosView(viewModel: viewModel)
        }
        .id("PromosTab") // Prevent recreation
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
