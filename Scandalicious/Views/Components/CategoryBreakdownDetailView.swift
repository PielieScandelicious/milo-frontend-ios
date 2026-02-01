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
                categoryRow(category)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if selectedCategory?.id == category.id {
                                selectedCategory = nil
                            } else {
                                selectedCategory = category
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Category Row

    private func categoryRow(_ category: CategorySpendItem) -> some View {
        HStack(spacing: 12) {
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
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedCategory?.id == category.id ? category.color.opacity(0.15) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedCategory?.id == category.id ? category.color.opacity(0.5) : Color.clear, lineWidth: 1)
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