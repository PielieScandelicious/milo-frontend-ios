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
        VStack(alignment: .leading, spacing: 12) {
            Text("By Category")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            ForEach(data.categories.sorted { $0.totalSpent > $1.totalSpent }) { category in
                VStack(spacing: 0) {
                    categoryRow(category)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                toggleCategoryExpansion(category)
                            }
                        }

                    // Expandable items section
                    if expandedCategoryId == category.id {
                        expandedItemsSection(category)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
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

            await MainActor.run {
                categoryItems[category.id] = response.transactions
                loadingCategoryId = nil
            }
        } catch {
            await MainActor.run {
                categoryLoadError[category.id] = error.localizedDescription
                loadingCategoryId = nil
            }
        }
    }

    // MARK: - Expanded Items Section

    private func expandedItemsSection(_ category: CategorySpendItem) -> some View {
        VStack(spacing: 0) {
            if loadingCategoryId == category.id {
                // Loading state
                HStack {
                    Spacer()
                    ProgressView()
                        .tint(.white)
                    Text("Loading items...")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.leading, 8)
                    Spacer()
                }
                .padding(.vertical, 16)
            } else if let errorMsg = categoryLoadError[category.id] {
                // Error state
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
                .padding(.vertical, 12)
            } else if let items = categoryItems[category.id] {
                if items.isEmpty {
                    // Empty state
                    VStack(spacing: 6) {
                        Image(systemName: "tray")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No items found")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.vertical, 16)
                } else {
                    // Items list
                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            expandedItemRow(item, category: category, isLast: index == items.count - 1)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(category.color.opacity(0.05))
        )
        .padding(.top, -8)
        .padding(.horizontal, 4)
    }

    // MARK: - Expanded Item Row

    private func expandedItemRow(_ item: APITransaction, category: CategorySpendItem, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            // Health score badge
            Text(item.healthScore.nutriScoreLetter)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(item.healthScore.healthScoreColor)
                .frame(width: 22, height: 22)
                .background(
                    Circle()
                        .fill(item.healthScore.healthScoreColor.opacity(0.15))
                )

            // Item details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.itemName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(item.storeName)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)

                    if let date = item.dateParsed {
                        Text("•")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(formatItemDate(date))
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            // Quantity and price
            HStack(spacing: 6) {
                if item.quantity > 1 {
                    Text("×\(item.quantity)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                }

                Text(String(format: "€%.2f", item.totalPrice))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
        .padding(.bottom, isLast ? 0 : 4)
    }

    // MARK: - Date Formatting

    private func formatItemDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }

    // MARK: - Category Row

    private func categoryRow(_ category: CategorySpendItem) -> some View {
        let isExpanded = expandedCategoryId == category.id

        return HStack(spacing: 12) {
            // Color indicator and icon
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(category.color)
            }

            // Category info
            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)

                Text("\(category.transactionCount) items")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Amount and percentage
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "€%.2f", category.totalSpent))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(category.percentageText)
                    .font(.caption)
                    .foregroundStyle(category.color)
            }

            // Chevron indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
                .frame(width: 20)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isExpanded ? category.color.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isExpanded ? category.color.opacity(0.5) : Color.clear, lineWidth: 1)
        )
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