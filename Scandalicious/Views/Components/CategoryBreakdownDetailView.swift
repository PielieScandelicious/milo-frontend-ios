//
//  CategoryBreakdownDetailView.swift
//  Scandalicious
//
//  Interactive pie chart detail view for category spending breakdown
//

import SwiftUI
import Charts

// MARK: - Category Breakdown Detail View

/// A detailed view showing category spending breakdown with Swift Charts
struct CategoryBreakdownDetailView: View {
    let month: Int
    let year: Int

    @Environment(\.dismiss) private var dismiss
    @State private var data: PieChartSummaryResponse?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedCategory: CategorySpendItem?
    @State private var animateChart = false

    // Expandable category state
    @State private var expandedCategoryId: String?
    @State private var categoryItems: [String: [APITransaction]] = [:]
    @State private var loadingCategoryId: String?
    @State private var categoryLoadError: [String: String] = [:]

    // Pagination state per category
    @State private var categoryCurrentPage: [String: Int] = [:]
    @State private var categoryHasMorePages: [String: Bool] = [:]
    @State private var categoryIsLoadingMore: [String: Bool] = [:]
    @State private var categoryTotalCount: [String: Int] = [:]

    /// Observe split cache for updates
    @ObservedObject private var splitCache = SplitCacheManager.shared

    private let apiService = AnalyticsAPIService.shared

    private var monthName: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        var components = DateComponents()
        components.month = month
        components.year = year
        let date = Calendar.current.date(from: components) ?? Date()
        return dateFormatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Dark background
                Color(white: 0.05)
                    .ignoresSafeArea()

                if isLoading {
                    loadingView
                } else if let error = error {
                    errorView(error)
                } else if let data = data {
                    contentView(data)
                }
            }
            .navigationTitle(L("spending_breakdown"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            await loadData()
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text(L("loading_breakdown"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text(L("failed_load_data"))
                .font(.headline)
                .foregroundStyle(.white)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                Task { await loadData() }
            } label: {
                Label(L("retry"), systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
        }
    }

    // MARK: - Content View

    private func contentView(_ data: PieChartSummaryResponse) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Period header
                Text(monthName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                // Total spending
                VStack(spacing: 4) {
                    Text(L("total_spent"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))

                    Text(String(format: "€%.2f", data.totalSpent))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Pie Chart
                pieChartSection(data)

                // Legend / Category List
                categoryListSection(data)
            }
            .padding()
        }
    }

    // MARK: - Pie Chart Section

    private func pieChartSection(_ data: PieChartSummaryResponse) -> some View {
        VStack(spacing: 16) {
            ZStack {
                // Pie Chart using Swift Charts
                Chart(data.categories) { category in
                    SectorMark(
                        angle: .value("Amount", animateChart ? category.totalSpent : 0),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(category.color)
                    .cornerRadius(6)
                    .opacity(selectedCategory == nil || selectedCategory?.id == category.id ? 1.0 : 0.4)
                }
                .chartLegend(.hidden)
                .frame(height: 280)

                // Center content
                if let selected = selectedCategory {
                    selectedCenterContent(selected)
                } else {
                    defaultCenterContent(data)
                }
            }
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedCategory = nil
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animateChart = true
            }
        }
    }

    // MARK: - Center Content

    private func defaultCenterContent(_ data: PieChartSummaryResponse) -> some View {
        VStack(spacing: 4) {
            Text("\(data.categories.count)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(L("categories"))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func selectedCenterContent(_ category: CategorySpendItem) -> some View {
        VStack(spacing: 4) {
            Image.categorySymbol(category.icon)
                .frame(width: 24, height: 24)
                .foregroundStyle(category.color)

            Text(category.name.localizedCategoryName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Text(String(format: "€%.2f", category.totalSpent))
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(category.color)

            Text(category.percentageText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Category List Section

    private func categoryListSection(_ data: PieChartSummaryResponse) -> some View {
        let sortedCategories = data.categories.sorted { $0.totalSpent > $1.totalSpent }

        return LazyVStack(alignment: .leading, spacing: 12) {
            Text(L("by_category"))
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            ForEach(sortedCategories) { category in
                expandableCategoryCard(category)
            }
        }
    }

    // MARK: - Expandable Category Card

    private func expandableCategoryCard(_ category: CategorySpendItem) -> some View {
        let isExpanded = expandedCategoryId == category.id

        return VStack(spacing: 0) {
            // Category header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    toggleCategoryExpansion(category)
                }
            } label: {
                categoryRowContent(category)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded items - matching StoreDetailView structure
            if isExpanded {
                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 14)

                // LazyVStack for spacing between items (lazy rendering for pagination)
                LazyVStack(spacing: 8) {
                    expandedItemsContent(category)
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 10)
            }
        }
        .background(
            ZStack {
                // Base glass effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))

                // Subtle gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Colored accent glow on the left
                HStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    category.color.opacity(0.15),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 60)
                    Spacer()
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(isExpanded ? 0.15 : 0.1),
                            Color.white.opacity(isExpanded ? 0.06 : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Category Row Content

    private func categoryRowContent(_ category: CategorySpendItem) -> some View {
        let isExpanded = expandedCategoryId == category.id

        return HStack(spacing: 12) {
            // Color accent bar on the left (matching StoreDetailView)
            RoundedRectangle(cornerRadius: 2)
                .fill(category.color)
                .frame(width: 4, height: 32)

            // Category icon
            Image.categorySymbol(category.icon)
                .foregroundStyle(category.color)
                .frame(width: 16, height: 16)

            // Category name + percentage
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name.localizedCategoryName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(category.percentageText)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(category.color)
            }

            Spacer(minLength: 4)

            // Amount
            Text(String(format: "€%.2f", category.totalSpent))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .trailing)

            // Chevron
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.25))
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Toggle Category Expansion

    private func toggleCategoryExpansion(_ category: CategorySpendItem) {
        if expandedCategoryId == category.id {
            // Collapse — clear items so re-expanding fetches fresh data
            let id = category.id
            expandedCategoryId = nil
            selectedCategory = nil
            categoryItems[id] = nil
            categoryCurrentPage[id] = nil
            categoryHasMorePages[id] = nil
            categoryIsLoadingMore[id] = nil
            categoryTotalCount[id] = nil
            categoryLoadError[id] = nil
        } else {
            // Expand and load items
            expandedCategoryId = category.id
            selectedCategory = category

            // Load items if not already loaded
            if categoryItems[category.id] == nil && loadingCategoryId != category.id {
                // Set loading state immediately (synchronously) before async Task
                loadingCategoryId = category.id
                Task {
                    await loadCategoryItems(category)
                }
            }
        }
    }

    // MARK: - Load Category Items

    private func loadCategoryItems(_ category: CategorySpendItem) async {
        loadingCategoryId = category.id
        categoryLoadError[category.id] = nil

        do {
            var filters = TransactionFilters()
            filters.category = category.name
            filters.pageSize = 10
            filters.page = 1

            // Set date range for the specific month/year
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!

            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1

            if let startOfMonth = calendar.date(from: components),
               let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) {
                filters.startDate = startOfMonth
                filters.endDate = endOfMonth
            }

            let response = try await apiService.getTransactions(filters: filters)

            await MainActor.run {
                categoryItems[category.id] = response.transactions
                categoryCurrentPage[category.id] = 1
                categoryHasMorePages[category.id] = response.page < response.totalPages
                categoryTotalCount[category.id] = response.total
                loadingCategoryId = nil
            }

            // Load split data in background for the loaded page
            loadSplitData(for: response.transactions)
        } catch {
            await MainActor.run {
                categoryLoadError[category.id] = error.localizedDescription
                loadingCategoryId = nil
            }
        }
    }

    // MARK: - Load More Category Items (Pagination)

    private func loadMoreCategoryItems(_ category: CategorySpendItem) async {
        let id = category.id
        guard categoryHasMorePages[id] == true,
              categoryIsLoadingMore[id] != true else { return }

        categoryIsLoadingMore[id] = true

        do {
            let nextPage = (categoryCurrentPage[id] ?? 1) + 1
            var filters = TransactionFilters()
            filters.category = category.name
            filters.pageSize = 10
            filters.page = nextPage

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!

            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1

            if let startOfMonth = calendar.date(from: components),
               let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) {
                filters.startDate = startOfMonth
                filters.endDate = endOfMonth
            }

            let response = try await apiService.getTransactions(filters: filters)

            await MainActor.run {
                categoryItems[id, default: []].append(contentsOf: response.transactions)
                categoryCurrentPage[id] = nextPage
                categoryHasMorePages[id] = response.page < response.totalPages
                categoryIsLoadingMore[id] = false
            }

            // Load split data in background for the new page
            loadSplitData(for: response.transactions)
        } catch {
            await MainActor.run {
                categoryIsLoadingMore[id] = false
            }
        }
    }

    // MARK: - Load Split Data (Background)

    private func loadSplitData(for transactions: [APITransaction]) {
        Task.detached { [weak splitCache] in
            let uniqueReceiptIds = Set(transactions.compactMap { $0.receiptId })

            await withTaskGroup(of: Void.self) { group in
                var activeTasksCount = 0
                let maxConcurrentTasks = 5
                var remainingIds = Array(uniqueReceiptIds)

                while !remainingIds.isEmpty || activeTasksCount > 0 {
                    while activeTasksCount < maxConcurrentTasks && !remainingIds.isEmpty {
                        let receiptId = remainingIds.removeFirst()

                        guard let cache = splitCache, await !cache.hasSplit(for: receiptId) else {
                            continue
                        }

                        group.addTask {
                            await cache.fetchSplit(for: receiptId)
                        }
                        activeTasksCount += 1
                    }

                    if activeTasksCount > 0 {
                        await group.next()
                        activeTasksCount -= 1
                    }
                }
            }
        }
    }

    // MARK: - Expanded Items Content

    @ViewBuilder
    private func expandedItemsContent(_ category: CategorySpendItem) -> some View {
        if loadingCategoryId == category.id {
            HStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                    .scaleEffect(0.7)
                Text(L("loading"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let errorMsg = categoryLoadError[category.id] {
            VStack(spacing: 8) {
                Text(L("failed_load_items"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                Text(errorMsg)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                Button {
                    Task { await loadCategoryItems(category) }
                } label: {
                    Text(L("retry"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
        } else if let items = categoryItems[category.id], !items.isEmpty {
            ForEach(items) { item in
                // Get split participants for this item
                let splitParticipants: [SplitParticipantInfo] = {
                    guard let receiptId = item.receiptId else { return [] }
                    guard let splitData = splitCache.getSplit(for: receiptId) else { return [] }
                    return splitData.participantsForTransaction(item.id)
                }()
                let friendsOnly = splitParticipants.filter { !$0.isMe }

                HStack(spacing: 10) {
                    // Nutri-Score badge (only shown when score exists)
                    if item.healthScore != nil {
                        Text(item.healthScore.nutriScoreLetter)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(item.healthScore.healthScoreColor)
                            .frame(width: 16, height: 16)
                            .background(
                                Circle()
                                    .fill(item.healthScore.healthScoreColor.opacity(0.15))
                            )
                            .overlay(
                                Circle()
                                    .stroke(item.healthScore.healthScoreColor.opacity(0.3), lineWidth: 0.5)
                            )
                            .transition(.identity)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.displayName)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.9))
                                .lineLimit(2)

                            if item.quantity > 1 {
                                Text("×\(item.quantity)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(
                                        Capsule()
                                            .fill(Color.white.opacity(0.08))
                                    )
                                    .transition(.identity)
                            }

                            // Split participant avatars
                            if !friendsOnly.isEmpty {
                                MiniSplitAvatars(participants: friendsOnly)
                                    .transition(.identity)
                            }
                        }

                        if let description = item.displayDescription {
                            Text(description)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(2)
                                .transition(.identity)
                        }

                        // Store name for context
                        Text(item.storeName.capitalized)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(String(format: "€%.2f", item.totalPrice))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Infinite scroll sentinel
            if categoryHasMorePages[category.id] == true {
                HStack(spacing: 8) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
                        .scaleEffect(0.7)
                    Text("Loading more...")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .onAppear {
                    Task { await loadMoreCategoryItems(category) }
                }
            }

            // Item count
            if let total = categoryTotalCount[category.id], total > 0 {
                Text("\(items.count) of \(total) items")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.3))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        } else {
            Text(L("no_transactions"))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            let response = try await apiService.getPieChartSummary(month: month, year: year)
            await MainActor.run {
                self.data = response
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CategoryBreakdownDetailView(month: 1, year: 2026)
        .preferredColorScheme(.dark)
}