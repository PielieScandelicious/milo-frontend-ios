//
//  StoreDetailView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct StoreDetailView: View {
    let storeBreakdown: StoreBreakdown
    var storeColor: Color = Color(red: 0.3, green: 0.7, blue: 1.0)  // Default to blue if not provided
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String?
    @State private var selectedCategoryColor: Color?
    // Removed showingAllTransactions - header no longer navigates
    @State private var showingCategoryTransactions = false
    @State private var showingReceipts = false

    // Live data that can be refreshed from backend
    @State private var currentTotalSpend: Double
    @State private var currentVisitCount: Int
    @State private var currentCategories: [Category]
    @State private var currentHealthScore: Double?
    @State private var currentTotalItems: Int = 0
    @State private var isRefreshing = false
    @State private var hasInitialized = false
    @State private var categoriesRevealed = false
    @State private var receiptsRevealed = false
    @State private var showAllCategories = false
    private let maxVisibleCategories = 5

    init(storeBreakdown: StoreBreakdown, storeColor: Color = Color(red: 0.3, green: 0.7, blue: 1.0)) {
        self.storeBreakdown = storeBreakdown
        self.storeColor = storeColor
        // Initialize live data from breakdown so donut chart has data on first render
        _currentTotalSpend = State(initialValue: storeBreakdown.totalStoreSpend)
        _currentVisitCount = State(initialValue: storeBreakdown.visitCount)
        _currentCategories = State(initialValue: storeBreakdown.categories)
        _currentHealthScore = State(initialValue: storeBreakdown.averageHealthScore)
    }

    // Expandable receipts section
    @StateObject private var receiptsViewModel = ReceiptsViewModel()
    @State private var isReceiptsSectionExpanded = false
    @State private var expandedReceiptId: String?
    @State private var isDeletingReceipt = false
    @State private var receiptDeleteError: String?

    // Split expense
    @State private var receiptToSplit: APIReceipt?

    // Expandable category transactions
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @State private var expandedCategoryName: String?
    @State private var categoryTransactions: [String: [APITransaction]] = [:]
    @State private var loadingCategories: Set<String> = []

    // Accent color for the line chart - modern red
    private var chartAccentColor: Color {
        Color(red: 0.95, green: 0.25, blue: 0.3)
    }

    // Backend-provided average item price (set during refresh)
    @State private var backendAverageItemPrice: Double?

    // Average item price - prefers backend value, falls back to local calculation
    private var averageItemPrice: Double? {
        // Use backend-computed value if available
        if let backendPrice = backendAverageItemPrice {
            return backendPrice
        }
        // Fallback: compute locally
        guard currentTotalItems > 0 else { return nil }
        return currentTotalSpend / Double(currentTotalItems)
    }

    // Store accent color for header border - uses the color from donut chart segment
    private var storeAccentColor: Color {
        storeColor
    }

    // MARK: - Categories Grouped by Mid-Level Category

    /// A group of categories for display with section header
    struct CategoryGroup: Identifiable {
        let groupName: String
        let groupIcon: String
        let groupColorHex: String
        let categories: [Category]
        let totalSpent: Double

        var id: String { groupName }

        var groupColor: Color {
            Color(hex: groupColorHex) ?? .white.opacity(0.5)
        }
    }

    /// Group currentCategories by their mid-level category (e.g., "Groceries", "Electronics"),
    /// sorted by total spend descending. Icon/color come from the parent group.
    private var categoriesByGroup: [CategoryGroup] {
        let registry = CategoryRegistryManager.shared
        var groupDict: [String: (icon: String, colorHex: String, categories: [Category])] = [:]

        for category in currentCategories {
            let midCategory = registry.categoryForSubCategory(category.name)
            let parentGroup = registry.groupForCategory(midCategory)
            let icon = registry.iconForGroup(parentGroup)
            let colorHex = registry.colorHexForGroup(parentGroup)

            if var existing = groupDict[midCategory] {
                existing.categories.append(category)
                groupDict[midCategory] = existing
            } else {
                groupDict[midCategory] = (icon: icon, colorHex: colorHex, categories: [category])
            }
        }

        // Convert to CategoryGroup array and sort by total spent descending
        return groupDict.map { name, data in
            CategoryGroup(
                groupName: name,
                groupIcon: data.icon,
                groupColorHex: data.colorHex,
                categories: data.categories.sorted { $0.spent > $1.spent },
                totalSpent: data.categories.reduce(0) { $0 + $1.spent }
            )
        }
        .sorted { $0.totalSpent > $1.totalSpent }
    }

    // Categories limited for display (top 5 or all)
    private var sortedCategories: [Category] {
        currentCategories.sorted { $0.spent > $1.spent }
    }

    private var displayCategories: [Category] {
        showAllCategories ? sortedCategories : Array(sortedCategories.prefix(maxVisibleCategories))
    }

    private var hasMoreCategories: Bool {
        currentCategories.count > maxVisibleCategories
    }

    // MARK: - Compact Store Header (centered, matching Overview style)

    private var storeHeaderSection: some View {
        VStack(spacing: 8) {
            Text(storeBreakdown.storeName.localizedCapitalized)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(storeBreakdown.period == "All" ? "All Time" : storeBreakdown.period)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text(String(format: "€%.0f", currentTotalSpend))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentTotalSpend)

        }
        .padding(.top, 20)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Premium Card Styling

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

    private func cardDivider() -> some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.25), .white.opacity(0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 0.5)
        .padding(.horizontal, 20)
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

    // MARK: - Unified Store Card

    private var unifiedStoreCard: some View {
        VStack(spacing: 0) {
            storeHeaderSection

            FlippableDonutChartView(
                title: "",
                subtitle: currentVisitCount == 1 ? "receipt" : "receipts",
                totalAmount: Double(currentVisitCount),
                segments: sortedCategories.toChartSegments(),
                size: 170,
                accentColor: chartAccentColor,
                selectedPeriod: storeBreakdown.period,
                averageItemPrice: averageItemPrice,
                showAllSegments: showAllCategories
            )
            .padding(.vertical, 12)

            if let score = currentHealthScore {
                CompactNutriBadge(score: score)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
            }

            if !currentCategories.isEmpty {
                VStack(spacing: 0) {
                    legendSectionTitle(
                        title: "Categories",
                        count: currentCategories.count
                    )

                    ForEach(Array(displayCategories.enumerated()), id: \.element.id) { index, category in
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

                            let segment = categoryToSegment(category: category)
                            let normalizedName = category.name.normalizedCategoryName
                            let icon = normalizedName.groceryHealthIcon ?? normalizedName.categoryIcon
                            expandableCategoryRow(segment: segment, isOther: false, icon: icon, originalCategoryName: category.name)
                        }
                        .opacity(categoriesRevealed ? 1 : 0)
                        .offset(y: categoriesRevealed ? 0 : 14)
                        .animation(
                            .easeOut(duration: 0.35).delay(Double(index) * 0.06),
                            value: categoriesRevealed
                        )
                    }

                    if hasMoreCategories {
                        showAllCategoriesButton
                    }
                }
                .id("categories-\(showAllCategories)")
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(premiumCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(premiumCardBorder)
        .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 12)
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Unified premium card (header + donut + categories)
                    unifiedStoreCard
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Expandable Receipts Section — revealed last
                    receiptsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .opacity(receiptsRevealed ? 1 : 0)
                        .offset(y: receiptsRevealed ? 0 : 14)
                        .animation(.easeOut(duration: 0.35), value: receiptsRevealed)

                    // Bottom spacing
                    Color.clear.frame(height: 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingCategoryTransactions) {
            TransactionListView(
                storeName: storeBreakdown.storeName,
                period: storeBreakdown.period,
                category: selectedCategory,
                categoryColor: selectedCategoryColor
            )
        }
        .navigationDestination(isPresented: $showingReceipts) {
            ReceiptsListView(
                period: storeBreakdown.period,
                storeName: storeBreakdown.storeName
            )
        }
        .sheet(item: $receiptToSplit) { receipt in
            SplitExpenseView(receipt: receipt.toReceiptUploadResponse())
        }
        .onAppear {
            if !hasInitialized {
                hasInitialized = true

                // Pre-populate categoryTransactions from cache for instant expansion
                let cache = AppDataCache.shared
                let period = storeBreakdown.period
                for category in storeBreakdown.categories {
                    let cacheKey = cache.categoryItemsKey(period: period, category: category.name)
                    if let cachedItems = cache.categoryItemsCache[cacheKey] {
                        let storeFiltered = cachedItems.filter { $0.storeName == storeBreakdown.storeName }
                        let normalizedName = category.name.normalizedCategoryName
                        categoryTransactions[normalizedName] = storeFiltered
                    }
                }
            }

            // Reveal category cards with staggered animation
            // Slight delay so donut sweep gets a head start
            if !currentCategories.isEmpty && !categoriesRevealed {
                let categoryDelay = 0.3
                DispatchQueue.main.asyncAfter(deadline: .now() + categoryDelay) {
                    categoriesRevealed = true
                }
                // Receipts section appears after last category card finishes
                let receiptsDelay = categoryDelay + 0.35 + Double(currentCategories.count) * 0.06
                DispatchQueue.main.asyncAfter(deadline: .now() + receiptsDelay) {
                    receiptsRevealed = true
                }
            } else if currentCategories.isEmpty {
                // No categories — reveal receipts after donut sweep
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    receiptsRevealed = true
                }
            }

            // Fetch detailed data (item count, avg price) from backend immediately.
            // The chart's isSettling guard prevents mid-sweep re-animation.
            Task {
                await refreshStoreData()
            }
            // Load receipts
            loadReceipts()
        }
        .onChange(of: currentCategories.isEmpty) { _, isEmpty in
            // Trigger staggered reveal when categories arrive from backend (past periods)
            if !isEmpty && !categoriesRevealed {
                let categoryDelay = 0.15
                DispatchQueue.main.asyncAfter(deadline: .now() + categoryDelay) {
                    categoriesRevealed = true
                }
                // Receipts after last category card
                let receiptsDelay = categoryDelay + 0.35 + Double(currentCategories.count) * 0.06
                DispatchQueue.main.asyncAfter(deadline: .now() + receiptsDelay) {
                    guard !receiptsRevealed else { return }
                    receiptsRevealed = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDataDidChange)) { _ in
            Task {
                // Wait for backend to process the change
                try? await Task.sleep(for: .seconds(0.5))
                await refreshStoreData()
            }
        }
    }

    // MARK: - Refresh Store Data from Backend

    private func refreshStoreData() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            // Create filters for this store
            var filters = AnalyticsFilters()
            filters.storeName = storeBreakdown.storeName

            // Handle "All" period - no date filtering
            if storeBreakdown.period == "All" {
                filters.period = .all
            } else if let year = Int(storeBreakdown.period), year >= 2000 && year <= 2100 {
                // Handle year period (e.g., "2025")
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!

                let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
                let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

                filters.period = .year
                filters.startDate = startOfYear
                filters.endDate = endOfYear
            } else {
                // Parse the period as month (e.g., "January 2026")
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.timeZone = TimeZone(identifier: "UTC")

                guard let parsedDate = dateFormatter.date(from: storeBreakdown.period) else {
                    return
                }

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!

                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

                filters.period = .month
                filters.startDate = startOfMonth
                filters.endDate = endOfMonth
            }

            let storeDetails = try await AnalyticsAPIService.shared.getStoreDetails(
                storeName: storeBreakdown.storeName,
                filters: filters
            )

            // Convert categories (preserving group info)
            let categories = storeDetails.categories.map { categoryBreakdown in
                Category(
                    name: categoryBreakdown.name,
                    spent: categoryBreakdown.spent,
                    percentage: Int(categoryBreakdown.percentage),
                    group: categoryBreakdown.group,
                    groupColorHex: categoryBreakdown.groupColorHex,
                    groupIcon: categoryBreakdown.groupIcon
                )
            }

            // Use backend totalItems if available, otherwise calculate from category transaction counts
            let totalItems = storeDetails.totalItems ?? storeDetails.categories.reduce(0) { $0 + $1.transactionCount }

            // Update state on main thread (no withAnimation — it causes layout slide artifacts)
            await MainActor.run {
                currentTotalSpend = storeDetails.totalSpend
                currentVisitCount = storeDetails.visitCount
                currentCategories = categories
                currentHealthScore = storeDetails.averageHealthScore
                currentTotalItems = totalItems
                backendAverageItemPrice = storeDetails.averageItemPrice  // Use backend value if available
            }

        } catch {
            // Error refreshing store data - silently ignore
        }
    }

    // MARK: - Show All Categories Button

    private var showAllCategoriesButton: some View {
        Button {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showAllCategories.toggle()
                // Reset animation state to trigger staggered animation for new rows
                if showAllCategories {
                    categoriesRevealed = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            categoriesRevealed = true
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: showAllCategories ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))

                Text(showAllCategories ? "Show Less" : "Show All \(currentCategories.count)")
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

    /// Convert a Category to a ChartSegment for use in expandableCategoryRow.
    /// Grocery sub-categories get health-themed colors instead of the parent group color.
    private func categoryToSegment(category: Category) -> ChartSegment {
        // Normalize name in case backend returns enum-style names (e.g., "MEAT_FISH" -> "Meat & Fish")
        let normalizedName = category.name.normalizedCategoryName

        let color: Color
        if let healthColor = normalizedName.groceryHealthColor {
            color = healthColor
        } else {
            color = category.groupColorHex.flatMap { Color(hex: $0) } ?? normalizedName.categoryColor
        }

        return ChartSegment(
            startAngle: .degrees(0),
            endAngle: .degrees(0),
            color: color,
            value: category.spent,
            label: normalizedName,
            percentage: category.percentage
        )
    }

    // MARK: - Expandable Receipts Section

    private var receiptsSection: some View {
        VStack(spacing: 0) {
            // Section header - seamless inline
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isReceiptsSectionExpanded.toggle()
                }
                if isReceiptsSectionExpanded && receiptsViewModel.receipts.isEmpty {
                    loadReceipts()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text("Receipts")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))

                    if actualReceipts.count > 0 {
                        Text("\(actualReceipts.count)")
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

            // Expanded receipts list
            if isReceiptsSectionExpanded {
                VStack(spacing: 0) {
                    if receiptsViewModel.state.isLoading && actualReceipts.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(0..<3, id: \.self) { _ in
                                SkeletonReceiptCard()
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    } else if actualReceipts.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 22))
                                .foregroundColor(.white.opacity(0.15))
                            Text("No receipts for this store")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.35))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(sortedReceipts.enumerated()), id: \.element.id) { index, receipt in
                                VStack(spacing: 0) {
                                    if index > 0 {
                                        LinearGradient(
                                            colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                        .frame(height: 0.5)
                                        .padding(.horizontal, 14)
                                    }

                                    ExpandableReceiptCard(
                                        receipt: receipt,
                                        isExpanded: expandedReceiptId == receipt.id,
                                        onTap: {
                                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                                if expandedReceiptId == receipt.id {
                                                    expandedReceiptId = nil
                                                } else {
                                                    expandedReceiptId = receipt.id
                                                }
                                            }
                                        },
                                        onDelete: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                deleteReceipt(receipt)
                                            }
                                        },
                                        onDeleteItem: { receiptId, itemId in
                                            deleteReceiptItem(receiptId: receiptId, itemId: itemId)
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
                        .animation(.easeInOut(duration: 0.3), value: receiptsViewModel.receipts.count)
                    }
                }
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
        .background(premiumCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(premiumCardBorder)
        .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }

    // MARK: - Filtered Receipts

    /// All receipts (no longer filtering by source)
    private var actualReceipts: [APIReceipt] {
        receiptsViewModel.receipts
            .sorted { receipt1, receipt2 in
                let date1 = receipt1.dateParsed ?? Date.distantPast
                let date2 = receipt2.dateParsed ?? Date.distantPast
                return date1 > date2
            }
    }

    private var sortedReceipts: [APIReceipt] {
        actualReceipts
    }

    private func loadReceipts() {
        Task {
            await receiptsViewModel.loadReceipts(period: storeBreakdown.period, storeName: storeBreakdown.storeName)
        }
    }

    private func deleteReceipt(_ receipt: APIReceipt) {
        isDeletingReceipt = true
        Task {
            do {
                try await receiptsViewModel.deleteReceipt(receipt, period: storeBreakdown.period, storeName: storeBreakdown.storeName)
                NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                receiptDeleteError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isDeletingReceipt = false
        }
    }

    private func deleteReceiptItem(receiptId: String, itemId: String) {
        Task {
            do {
                try await receiptsViewModel.deleteReceiptItem(receiptId: receiptId, itemId: itemId)
            } catch {
                receiptDeleteError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // MARK: - Expandable Category Row

    private func expandableCategoryRow(segment: ChartSegment, isOther: Bool, icon: String? = nil, originalCategoryName: String? = nil) -> some View {
        // Use original category name for API filtering, fall back to segment.label
        let categoryForAPI = originalCategoryName ?? segment.label

        return VStack(spacing: 0) {
            // Category header button
            Button {
                if expandedCategoryName == segment.label {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        expandedCategoryName = nil
                    }
                } else {
                    // Pre-populate data BEFORE animation so content appears instantly
                    if categoryTransactions[segment.label] == nil {
                        let period = storeBreakdown.period
                        let cacheKey = AppDataCache.shared.categoryItemsKey(period: period, category: categoryForAPI)
                        if let cachedItems = AppDataCache.shared.categoryItemsCache[cacheKey] {
                            let storeFiltered = cachedItems.filter { $0.storeName == storeBreakdown.storeName }
                            categoryTransactions[segment.label] = storeFiltered
                        }
                    }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                        expandedCategoryName = segment.label
                    }
                    // Fallback: fetch from API if not in cache
                    if categoryTransactions[segment.label] == nil {
                        loadCategoryTransactions(category: categoryForAPI, displayKey: segment.label)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Color accent bar on the left (matching StoreRowButton)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isOther ? segment.color.opacity(0.5) : segment.color)
                        .frame(width: 4, height: 32)

                    // Health-themed icon for grocery sub-categories
                    if let icon = icon {
                        Image.categorySymbol(icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(segment.color)
                            .frame(width: 20)
                    }

                    // Category name + percentage
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.label)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(isOther ? .white.opacity(0.5) : .white)
                            .lineLimit(1)

                        Text("\(segment.percentage)%")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(isOther ? .white.opacity(0.4) : segment.color)
                    }

                    Spacer(minLength: 4)

                    Text(String(format: "€%.0f", segment.value))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isOther ? .white.opacity(0.5) : .white)
                        .frame(width: 65, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .rotationEffect(.degrees(expandedCategoryName == segment.label ? 180 : 0))
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 11)
                .contentShape(Rectangle())
            }
            .buttonStyle(CategoryRowButtonStyle())

            // Expanded transactions list
            if expandedCategoryName == segment.label {
                VStack(spacing: 8) {
                    if loadingCategories.contains(segment.label) {
                        ForEach(0..<3, id: \.self) { _ in
                            HStack(spacing: 10) {
                                SkeletonRect(width: 16, height: 16, cornerRadius: 8)
                                SkeletonRect(width: 100, height: 13)
                                Spacer()
                                SkeletonRect(width: 50, height: 13)
                            }
                        }
                        .shimmer()
                        .padding(.vertical, 4)
                    } else if let transactions = categoryTransactions[segment.label], !transactions.isEmpty {
                        CategoryTransactionsContent(transactions: transactions)
                    } else {
                        Text("No transactions")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 4)
                .padding(.bottom, 8)
                .transition(.opacity)
            }
        }
    }

    private func loadCategoryTransactions(category: String, displayKey: String) {
        // Use displayKey for storage/retrieval (matches segment.label used in UI)
        guard categoryTransactions[displayKey] == nil else { return }

        // Try to serve from AppDataCache first (filter cached category items by store name)
        let period = storeBreakdown.period
        let cacheKey = AppDataCache.shared.categoryItemsKey(period: period, category: category)
        if let cachedItems = AppDataCache.shared.categoryItemsCache[cacheKey] {
            let storeFiltered = cachedItems.filter { $0.storeName == storeBreakdown.storeName }
            categoryTransactions[displayKey] = storeFiltered
            return
        }

        loadingCategories.insert(displayKey)

        Task {
            do {
                var filters = TransactionFilters()
                filters.storeName = storeBreakdown.storeName
                filters.category = category  // Use original category for API filtering
                filters.pageSize = 100

                // Handle period filtering
                if storeBreakdown.period == "All" {
                    // No date filtering for "All" period
                } else if let year = Int(storeBreakdown.period), year >= 2000 && year <= 2100 {
                    // Handle year period (e.g., "2025")
                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: "UTC")!

                    let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
                    let endOfYear = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!

                    filters.startDate = startOfYear
                    filters.endDate = endOfYear
                } else {
                    // Parse the period as month (e.g., "January 2026")
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMMM yyyy"
                    dateFormatter.locale = Locale(identifier: "en_US")
                    dateFormatter.timeZone = TimeZone(identifier: "UTC")

                    guard let parsedDate = dateFormatter.date(from: storeBreakdown.period) else {
                        loadingCategories.remove(displayKey)
                        return
                    }

                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: "UTC")!

                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
                    let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

                    filters.startDate = startOfMonth
                    filters.endDate = endOfMonth
                }

                let response = try await AnalyticsAPIService.shared.getTransactions(filters: filters)

                await MainActor.run {
                    categoryTransactions[displayKey] = response.transactions  // Store under display key
                    loadingCategories.remove(displayKey)
                }
            } catch {
                await MainActor.run {
                    loadingCategories.remove(displayKey)
                }
            }
        }
    }

}

// MARK: - Category Transaction Subviews (Performance-Isolated)

/// Observes SplitCacheManager independently so split-data loads only re-render
/// this small list — not the entire StoreDetailView (header, chart, receipts, etc.).
private struct CategoryTransactionsContent: View {
    let transactions: [APITransaction]
    @ObservedObject private var splitCache = SplitCacheManager.shared

    var body: some View {
        let sorted = transactions.sorted { t1, t2 in
            let s1 = t1.healthScore
            let s2 = t2.healthScore
            if let a = s1, let b = s2 { return a > b }
            if s1 != nil && s2 == nil { return true }
            if s1 == nil && s2 != nil { return false }
            return t1.itemName.localizedCaseInsensitiveCompare(t2.itemName) == .orderedAscending
        }

        ForEach(sorted) { transaction in
            CategoryTransactionItemRow(
                transaction: transaction,
                friends: friendsFor(transaction)
            )
        }
        .task {
            // Batch-fetch all unique receipt splits at once instead of N individual fetches
            let ids = Set(transactions.compactMap { $0.receiptId })
                .filter { !splitCache.hasSplit(for: $0) }
            guard !ids.isEmpty else { return }
            await withTaskGroup(of: Void.self) { group in
                for id in ids {
                    group.addTask {
                        await SplitCacheManager.shared.fetchSplit(for: id)
                    }
                }
            }
        }
    }

    private func friendsFor(_ transaction: APITransaction) -> [SplitParticipantInfo] {
        guard let receiptId = transaction.receiptId,
              let splitData = splitCache.getSplit(for: receiptId) else { return [] }
        return splitData.participantsForTransaction(transaction.id).filter { !$0.isMe }
    }
}

/// Pure rendering view — no observation, no async work.
/// Receives pre-computed friends so SwiftUI can diff efficiently via Equatable arrays.
private struct CategoryTransactionItemRow: View {
    let transaction: APITransaction
    let friends: [SplitParticipantInfo]

    var body: some View {
        HStack(spacing: 10) {
            // Nutri-Score letter (only shown when score exists)
            if transaction.healthScore != nil {
                Text(transaction.healthScore.nutriScoreLetter)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(transaction.healthScore.healthScoreColor)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(transaction.healthScore.healthScoreColor.opacity(0.15))
                    )
                    .overlay(
                        Circle()
                            .stroke(transaction.healthScore.healthScoreColor.opacity(0.3), lineWidth: 0.5)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(transaction.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)

                    if transaction.quantity > 1 {
                        Text("×\(transaction.quantity)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                            )
                    }

                    if !friends.isEmpty {
                        MiniSplitAvatars(participants: friends)
                    }
                }

                if let description = transaction.displayDescription {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(String(format: "€%.2f", transaction.totalPrice))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

// MARK: - Custom Button Styles

struct CategoryRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct DonutChartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        StoreDetailView(
            storeBreakdown: StoreBreakdown(
                storeName: "COLRUYT",
                period: "January 2026",
                totalStoreSpend: 189.90,
                categories: [
                    Category(name: "Meat Poultry & Seafood", spent: 65.40, percentage: 34, group: "Food & Dining", groupColorHex: "#2ECC71", groupIcon: "fork.knife"),
                    Category(name: "Alcohol", spent: 42.50, percentage: 22, group: "Food & Dining", groupColorHex: "#2ECC71", groupIcon: "fork.knife"),
                    Category(name: "Beverages (Non-Alcoholic)", spent: 28.00, percentage: 15, group: "Food & Dining", groupColorHex: "#2ECC71", groupIcon: "fork.knife"),
                    Category(name: "Household Consumables (Paper/Cleaning)", spent: 35.00, percentage: 18, group: "Housing & Utilities", groupColorHex: "#8E44AD", groupIcon: "house.fill"),
                    Category(name: "Snacks & Candy", spent: 19.00, percentage: 11, group: "Food & Dining", groupColorHex: "#2ECC71", groupIcon: "fork.knife")
                ],
                visitCount: 15
            ),
            storeColor: Color(red: 0.3, green: 0.7, blue: 1.0)
        )
    }
    .preferredColorScheme(.dark)
}
