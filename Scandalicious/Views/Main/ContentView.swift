//
//  ContentView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import Combine
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
    @State private var selectedTab: Tab = .folders
    @State private var showSignOutConfirmation = false
    @State private var hasLoadedInitialData = false
    @StateObject private var brandCashbackViewModel = BrandCashbackViewModel()
    @StateObject private var foldersViewModel = PromoFoldersViewModel()
    @ObservedObject private var gm = GamificationManager.shared
    @ObservedObject private var groceryStore = GroceryListStore.shared

    @State private var cartToast: CartToast? = nil
    @State private var cartToastQueue: [CartToast] = []
    @State private var cartToastDismissTask: Task<Void, Never>? = nil

    // Unified overlay queue — all reward overlays flow through here in order
    private enum OverlayItem {
        case brandCashback(dealName: String, amount: Double)
        case referral(amount: Double)
    }
    @State private var overlayQueue: [OverlayItem] = []
    @State private var activeOverlay: OverlayItem? = nil

    enum Tab: Int, Hashable {
        case folders = 0
        case groceryList = 1
        case receipts = 2
        case cashback = 3
        case insights = 4
    }


    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                FoldersTab()
                    .tabItem {
                        Label("Deals", systemImage: "tag.fill")
                    }
                    .tag(Tab.folders)

                GroceryListTab()
                    .tabItem {
                        Label("My List", systemImage: "list.clipboard.fill")
                    }
                    .badge(groceryStore.activeItemCount)
                    .tag(Tab.groceryList)

                ScanTab()
                    .tabItem {
                        Label("Receipts", systemImage: "doc.text.fill")
                    }
                    .tag(Tab.receipts)

                CashbackTab()
                    .tabItem {
                        Label("Cashback", systemImage: "eurosign.circle.fill")
                    }
                    .tag(Tab.cashback)

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

            // Grocery list "added to cart" toast
            if let toast = cartToast {
                VStack {
                    AddedToCartToastView(toast: toast)
                        .padding(.top, 8)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(90)
                .allowsHitTesting(false)
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
        .environmentObject(foldersViewModel)
        .preferredColorScheme(.dark)
        .onAppear {
            // Configure data manager on first appear
            if !hasLoadedInitialData {
                dataManager.configure(with: transactionManager)
                Task {
                    await loadAllData()
                }
                Task { await foldersViewModel.loadFolders() }
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
        }
        .onReceive(groceryStore.itemAddedPublisher) { item in
            showCartToast(for: item)
        }
        .onReceive(NotificationCenter.default.publisher(for: .switchToDealsTab)) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .folders
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("app.switchToFoldersTab"))) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .folders
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("app.switchToHomeTab"))) { _ in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                selectedTab = .receipts
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

            // Deals: promo folders (public, no auth)
            group.addTask {
                if let folders = try? await PromoAPIService.shared.getFolders() {
                    await MainActor.run {
                        cache.promoFolders = folders
                    }
                }
            }

            // Home tab: cashback summary, brand deals, recent receipts
            group.addTask {
                if let summary = try? await CashbackAPIService.shared.getSummary() {
                    await MainActor.run {
                        cache.cashbackSummary = summary
                    }
                }
            }
            group.addTask {
                let deals = await BrandCashbackService.shared.fetchEarnedDeals()
                await MainActor.run {
                    cache.earnedBrandDeals = deals
                }
            }
            group.addTask {
                let filters = ReceiptFilters(page: 1, pageSize: 15)
                if let response = try? await AnalyticsAPIService.shared.getReceipts(filters: filters) {
                    await MainActor.run {
                        cache.recentUploadedReceipts = response.receipts
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

    // MARK: - Cart toast

    private func showCartToast(for item: GroceryListItem) {
        let toast = CartToast(
            id: UUID(),
            title: item.label,
            imageUrl: item.imageUrl
        )
        if cartToast == nil {
            presentCartToast(toast)
        } else {
            cartToastQueue.append(toast)
        }
    }

    private func presentCartToast(_ toast: CartToast) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            cartToast = toast
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        cartToastDismissTask?.cancel()
        cartToastDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled, cartToast?.id == toast.id else { return }
            withAnimation(.easeInOut(duration: 0.28)) {
                cartToast = nil
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            if !cartToastQueue.isEmpty {
                let next = cartToastQueue.removeFirst()
                presentCartToast(next)
            }
        }
    }
}

// MARK: - Added-to-cart toast

struct CartToast: Equatable, Identifiable {
    let id: UUID
    let title: String
    let imageUrl: String?
}

private struct AddedToCartToastView: View {
    let toast: CartToast

    @State private var appeared: Bool = false
    @State private var checkPulse: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text("Added to List")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(toast.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.26, green: 0.88, blue: 0.47),
                                     Color(red: 0.10, green: 0.72, blue: 0.36)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.green.opacity(0.5), radius: 6, y: 2)

                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: checkPulse)
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .frame(maxWidth: 320)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.55))
                .background(
                    Capsule(style: .continuous)
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.6
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
        .scaleEffect(appeared ? 1.0 : 0.85)
        .opacity(appeared ? 1.0 : 0.0)
        .offset(y: appeared ? 0 : -14)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                appeared = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                checkPulse &+= 1
            }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .frame(width: 38, height: 38)
                .shadow(color: .black.opacity(0.25), radius: 4, y: 2)

            if let urlString = toast.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit().padding(3)
                    default:
                        Image(systemName: "bag.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Image(systemName: "bag.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
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

// MARK: - Cashback Tab
struct CashbackTab: View {
    @EnvironmentObject private var viewModel: BrandCashbackViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                BrandCashbackView(viewModel: viewModel)
                    .padding(.top, 8)
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Cashback")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .id("CashbackTab")
    }
}

// MARK: - Folders Tab
struct FoldersTab: View {
    @EnvironmentObject private var viewModel: PromoFoldersViewModel
    @State private var stackResetToken = 0

    var body: some View {
        NavigationStack {
            FolderHomeView(viewModel: viewModel)
        }
        .id("FoldersTab-\(stackResetToken)")
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("app.switchToFoldersTab"))) { _ in
            // Always land on the folders overview, even if a folder was previously open.
            stackResetToken &+= 1
        }
    }
}

// MARK: - Grocery List Tab
struct GroceryListTab: View {
    var body: some View {
        NavigationStack {
            GroceryListContentView(
                leadingToolbar: { EmptyView() },
                onBrowseTapped: {
                    NotificationCenter.default.post(name: Notification.Name("app.switchToFoldersTab"), object: nil)
                }
            )
        }
        .id("GroceryListTab")
    }
}

// MARK: - Promos Tab
#Preview {
    ContentView()
        .environmentObject(AuthenticationManager())
}
