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
    static let defaultValue: Int = 2 // home tab by default
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
    @State private var showBadgeUnlock = false
    @State private var badgeToShow: Badge? = nil
    @State private var badgeQueue: [Badge] = []

    enum Tab: Int, Hashable {
        case budget = 0
        case promos = 1
        case home = 2
        case dobby = 3
        case rewards = 4
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ViewTab(showSignOutConfirmation: $showSignOutConfirmation, dataManager: dataManager)
                    .tabItem {
                        Label(L("tab_budget"), systemImage: "wallet.bifold.fill")
                    }
                    .tag(Tab.budget)

                PromosTab()
                    .tabItem {
                        Label("Deals", systemImage: "tag.fill")
                    }
                    .tag(Tab.promos)

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

                RewardsTab()
                    .tabItem {
                        Label("Rewards", systemImage: "gift.fill")
                    }
                    .tag(Tab.rewards)
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

            // Brand cashback earned overlay (app-wide, works from any tab)
            if brandCashbackViewModel.showEarnedOverlay {
                CashbackEarnedOverlay(
                    dealName: brandCashbackViewModel.lastEarnedDealName,
                    cashbackAmount: brandCashbackViewModel.lastEarnedAmount,
                    onDismiss: { brandCashbackViewModel.dismissEarnedOverlay() }
                )
                .transition(.opacity)
                .zIndex(99)
            }

            // Badge unlock overlay (app-wide, works from any tab)
            if showBadgeUnlock, let badge = badgeToShow {
                BadgeUnlockView(badge: badge) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBadgeUnlock = false
                    }
                    // Show next queued badge after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showNextQueuedBadge()
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
        .onReceive(NotificationCenter.default.publisher(for: .badgeUnlocked)) { _ in
            if let badge = GamificationManager.shared.lastUnlockedBadge {
                if showBadgeUnlock {
                    // Already showing a badge — queue this one
                    if !badgeQueue.contains(where: { $0.id == badge.id }) {
                        badgeQueue.append(badge)
                    }
                } else {
                    badgeToShow = badge
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showBadgeUnlock = true
                    }
                }
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

    // MARK: - Badge Queue

    private func showNextQueuedBadge() {
        guard !badgeQueue.isEmpty else { return }
        let next = badgeQueue.removeFirst()
        badgeToShow = next
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showBadgeUnlock = true
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
            OverviewView(dataManager: dataManager, showSignOutConfirmation: $showSignOutConfirmation)
                .navigationBarTitleDisplayMode(.inline)
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

// MARK: - ScandaLicious Tab
struct ScandaLiciousTab: View {
    var body: some View {
        NavigationStack {
            ScandaLiciousAIChatView()
                .toolbarBackground(.hidden, for: .navigationBar)
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

// MARK: - Rewards Tab
struct RewardsTab: View {
    var body: some View {
        NavigationStack {
            RewardsView()
        }
        .id("RewardsTab")
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
