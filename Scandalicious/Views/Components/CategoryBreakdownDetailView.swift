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
            .navigationTitle("Spending Breakdown")
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

            Text("Loading breakdown...")
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

            Text("Failed to load data")
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
                Label("Retry", systemImage: "arrow.clockwise")
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
                    Text("Total Spent")
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

            Text("Categories")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func selectedCenterContent(_ category: CategorySpendItem) -> some View {
        VStack(spacing: 4) {
            Image(systemName: category.icon)
                .font(.system(size: 24))
                .foregroundStyle(category.color)

            Text(category.name)
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

        return VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
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

                // VStack for spacing between items
                VStack(spacing: 8) {
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
            Image(systemName: category.icon)
                .font(.system(size: 16))
                .foregroundStyle(category.color)
                .frame(width: 24)

            // Category name
            Text(category.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)

            Spacer()

            // Percentage badge with colored background
            Text(category.percentageText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(category.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(category.color.opacity(0.15))
                )

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
    }

    // MARK: - Toggle Category Expansion

    private func toggleCategoryExpansion(_ category: CategorySpendItem) {
        if expandedCategoryId == category.id {
            // Collapse
            expandedCategoryId = nil
            selectedCategory = nil
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

            // Use the category name directly from the backend (bypasses enum matching issues)
            filters.categoryName = category.name

            filters.pageSize = 100

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

            // Show items immediately - don't block UI waiting for splits
            await MainActor.run {
                categoryItems[category.id] = response.transactions
                loadingCategoryId = nil
            }

            // Load split data in background (non-blocking) - avatars will appear progressively
            // Use detached task so it doesn't block this function's completion
            Task.detached { [weak splitCache] in
                let uniqueReceiptIds = Set(response.transactions.compactMap { $0.receiptId })

                // Load splits in parallel with limited concurrency to avoid overwhelming the backend
                await withTaskGroup(of: Void.self) { group in
                    var activeTasksCount = 0
                    let maxConcurrentTasks = 5  // Limit concurrent API calls

                    var remainingIds = Array(uniqueReceiptIds)

                    while !remainingIds.isEmpty || activeTasksCount > 0 {
                        // Add new tasks up to the limit
                        while activeTasksCount < maxConcurrentTasks && !remainingIds.isEmpty {
                            let receiptId = remainingIds.removeFirst()

                            // Only fetch if not already cached
                            guard let cache = splitCache, await !cache.hasSplit(for: receiptId) else {
                                continue
                            }

                            group.addTask {
                                await cache.fetchSplit(for: receiptId)
                            }
                            activeTasksCount += 1
                        }

                        // Wait for at least one task to complete
                        if activeTasksCount > 0 {
                            await group.next()
                            activeTasksCount -= 1
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                categoryLoadError[category.id] = error.localizedDescription
                loadingCategoryId = nil
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
                Text("Loading...")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else if let errorMsg = categoryLoadError[category.id] {
            VStack(spacing: 8) {
                Text("Failed to load items")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.orange)
                Text(errorMsg)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                Button {
                    Task { await loadCategoryItems(category) }
                } label: {
                    Text("Retry")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
        } else if let items = categoryItems[category.id], !items.isEmpty {
            // Sort by health score (healthiest first), then alphabetically
            let sortedItems = items.sorted { t1, t2 in
                let score1 = t1.healthScore
                let score2 = t2.healthScore
                if let s1 = score1, let s2 = score2 {
                    return s1 > s2
                }
                if score1 != nil && score2 == nil { return true }
                if score1 == nil && score2 != nil { return false }
                return t1.itemName.localizedCaseInsensitiveCompare(t2.itemName) == .orderedAscending
            }
            ForEach(sortedItems) { item in
                // Get split participants for this item
                let splitParticipants: [SplitParticipantInfo] = {
                    guard let receiptId = item.receiptId else { return [] }
                    guard let splitData = splitCache.getSplit(for: receiptId) else { return [] }
                    return splitData.participantsForTransaction(item.id)
                }()
                let friendsOnly = splitParticipants.filter { !$0.isMe }

                HStack(spacing: 10) {
                    // Sleek Nutri-Score badge
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

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(item.itemName)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)

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
                            }

                            // Split participant avatars
                            if !friendsOnly.isEmpty {
                                MiniSplitAvatars(participants: friendsOnly)
                            }
                        }

                        // Store name for context
                        Text(item.storeName)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text(String(format: "€%.2f", item.totalPrice))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        } else {
            Text("No transactions")
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