import SwiftUI

struct YearInReviewView: View {
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var yearSummary: YearSummaryResponse?
    @State private var isLoading = false
    @State private var availableYears: [Int] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Year picker
                if availableYears.count > 1 {
                    Picker("Year", selection: $selectedYear) {
                        ForEach(availableYears, id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                }

                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else if let summary = yearSummary {
                    statsGrid(summary)

                    if let categories = summary.topCategories, !categories.isEmpty {
                        topCategoriesSection(categories)
                    }

                    if let monthly = summary.monthlyBreakdown, !monthly.isEmpty {
                        monthlyBreakdownSection(monthly)
                    }
                } else {
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.bar.xaxis",
                        description: Text("No spending data for \(String(selectedYear))")
                    )
                    .padding(.top, 40)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Year in Review")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            computeAvailableYears()
            loadData()
        }
        .onChange(of: selectedYear) { _, _ in
            loadData()
        }
    }

    // MARK: - Stats Grid

    private func statsGrid(_ summary: YearSummaryResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(title: "Total Spent", value: String(format: "€%.2f", summary.totalSpend), icon: "creditcard.fill", color: .purple)
            statCard(title: "Receipts", value: "\(summary.receiptCount)", icon: "receipt.fill", color: .blue)
            statCard(title: "Items", value: "\(summary.totalItems)", icon: "bag.fill", color: .green)
            if let healthScore = summary.averageHealthScore, healthScore > 0 {
                statCard(title: "Health Score", value: String(format: "%.1f", healthScore), icon: "heart.fill", color: .red)
            } else {
                statCard(title: "Transactions", value: "\(summary.transactionCount)", icon: "list.bullet.rectangle.fill", color: .orange)
            }
        }
        .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Top Categories

    private func topCategoriesSection(_ categories: [CategoryBreakdown]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Categories")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                ForEach(Array(categories.prefix(5).enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 12) {
                        Image(systemName: category.groupIcon ?? "tag.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(categoryColor(for: category))
                            .frame(width: 32, height: 32)
                            .background(categoryColor(for: category).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("\(category.transactionCount) transaction\(category.transactionCount == 1 ? "" : "s")")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(String(format: "€%.2f", category.spent))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.primary)
                            Text(String(format: "%.0f%%", category.percentage))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if index < categories.prefix(5).count - 1 {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    private func categoryColor(for category: CategoryBreakdown) -> Color {
        if let hex = category.groupColorHex {
            return Color(hex: hex) ?? .purple
        }
        return .purple
    }

    // MARK: - Monthly Breakdown

    private func monthlyBreakdownSection(_ months: [MonthlySpend]) -> some View {
        let sorted = months.sorted { $0.monthNumber < $1.monthNumber }
        let maxSpend = sorted.map(\.totalSpend).max() ?? 1

        return VStack(alignment: .leading, spacing: 12) {
            Text("Monthly Breakdown")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)

            VStack(spacing: 8) {
                ForEach(sorted) { month in
                    HStack(spacing: 12) {
                        Text(String(month.month.prefix(3)))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, alignment: .leading)

                        GeometryReader { geo in
                            let barWidth = maxSpend > 0 ? CGFloat(month.totalSpend / maxSpend) * geo.size.width : 0
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.purple.opacity(0.7))
                                .frame(width: max(barWidth, 2), height: 20)
                        }
                        .frame(height: 20)

                        Text(String(format: "€%.0f", month.totalSpend))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 60, alignment: .trailing)
                    }
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Data Loading

    private func computeAvailableYears() {
        let cache = AppDataCache.shared
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US")

        var years: Set<Int> = []
        for meta in cache.periodMetadata {
            if let date = dateFormatter.date(from: meta.period) {
                years.insert(Calendar.current.component(.year, from: date))
            }
        }

        let currentYear = Calendar.current.component(.year, from: Date())
        years.insert(currentYear)

        availableYears = years.sorted(by: >)
        if !availableYears.contains(selectedYear), let first = availableYears.first {
            selectedYear = first
        }
    }

    private func loadData() {
        // Check cache first
        let yearKey = String(selectedYear)
        if let cached = AppDataCache.shared.yearSummaryCache[yearKey] {
            yearSummary = cached
            return
        }

        isLoading = true
        yearSummary = nil

        Task {
            do {
                let summary = try await AnalyticsAPIService.shared.getYearSummary(
                    year: selectedYear,
                    includeMonthlyBreakdown: true,
                    topCategoriesLimit: 5
                )
                await MainActor.run {
                    yearSummary = summary
                    AppDataCache.shared.yearSummaryCache[yearKey] = summary
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    yearSummary = nil
                    isLoading = false
                }
            }
        }
    }
}

