//
//  StoreDetailView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct StoreDetailView: View {
    let storeBreakdown: StoreBreakdown
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String?
    @State private var selectedCategoryColor: Color?
    @State private var showingAllTransactions = false
    @State private var showingCategoryTransactions = false
    @State private var showingReceipts = false
    @State private var trends: [TrendPeriod] = []
    @State private var isLoadingTrends = false

    // Live data that can be refreshed from backend
    @State private var currentTotalSpend: Double = 0
    @State private var currentVisitCount: Int = 0
    @State private var currentCategories: [Category] = []
    @State private var currentHealthScore: Double?
    @State private var isRefreshing = false
    @State private var hasInitialized = false

    // Accent color for the line chart - modern red
    private var chartAccentColor: Color {
        Color(red: 0.95, green: 0.25, blue: 0.3)
    }

    // Top 5 categories + "Other" grouping - uses refreshable currentCategories
    private var groupedChartSegments: [ChartSegment] {
        let sortedCategories = currentCategories.sorted { $0.spent > $1.spent }

        if sortedCategories.count <= 5 {
            return sortedCategories.toChartSegments()
        }

        // Take top 5 and sum the rest into "Other"
        let top5 = Array(sortedCategories.prefix(5))
        let remaining = Array(sortedCategories.dropFirst(5))
        let otherSpent = remaining.reduce(0) { $0 + $1.spent }
        let totalSpent = sortedCategories.reduce(0) { $0 + $1.spent }
        let otherPercentage = totalSpent > 0 ? Int((otherSpent / totalSpent) * 100) : 0

        // Create a Category for "Other"
        let otherCategory = Category(name: "Other", spent: otherSpent, percentage: otherPercentage)

        // Combine top 5 + Other and convert to segments
        let combinedCategories = top5 + [otherCategory]
        return combinedCategories.toChartSegments()
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header card - clickable to view all store transactions
                    Button {
                        showingAllTransactions = true
                    } label: {
                        VStack(spacing: 12) {
                            Text(storeBreakdown.storeName)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(storeBreakdown.period)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            Text(String(format: "€%.0f", currentTotalSpend))
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 8)

                            // Health Score indicator (placeholder - will show when backend provides data)
                            if let healthScore = currentHealthScore {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .padding(.horizontal, 40)
                                    .padding(.top, 8)

                                HStack(spacing: 8) {
                                    HealthScoreBadge(score: Int(healthScore.rounded()), size: .medium, style: .subtle)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Health Score")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))

                                        Text(healthScore.healthScoreLabel)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(healthScore.healthScoreColor)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(StoreHeaderButtonStyle())
                    .padding(.horizontal)
                    
                    // Large donut chart - tap to flip to line chart
                    VStack(spacing: 20) {
                        FlippableDonutChartView(
                            title: "",
                            subtitle: currentVisitCount == 1 ? "receipt" : "receipts",
                            totalAmount: Double(currentVisitCount),
                            segments: groupedChartSegments,
                            size: 220,
                            trends: trends,
                            accentColor: chartAccentColor,
                            selectedPeriod: storeBreakdown.period
                        )
                        .padding(.top, 20)
                        
                        // Legend with tap interaction
                        VStack(spacing: 12) {
                            ForEach(Array(groupedChartSegments.enumerated()), id: \.element.id) { _, segment in
                                Button {
                                    // Don't navigate for "Other" category
                                    if segment.label != "Other" {
                                        selectedCategory = segment.label
                                        selectedCategoryColor = segment.color
                                        showingCategoryTransactions = true
                                    }
                                } label: {
                                    categoryRow(segment: segment, isOther: segment.label == "Other")
                                }
                                .buttonStyle(CategoryRowButtonStyle())
                                .disabled(segment.label == "Other")
                            }
                        }
                        .padding(.horizontal)

                        // View Receipts button
                        Button {
                            showingReceipts = true
                        } label: {
                            HStack(spacing: 12) {
                                Text("View Receipts")
                                    .font(.system(size: 16, weight: .semibold))

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.blue.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                            )
                        }
                        .buttonStyle(CategoryRowButtonStyle())
                        .padding(.horizontal)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingAllTransactions) {
            TransactionListView(
                storeName: storeBreakdown.storeName,
                period: storeBreakdown.period,
                category: nil,
                categoryColor: nil
            )
        }
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
        .task {
            await fetchTrends()
        }
        .onAppear {
            if !hasInitialized {
                // First appearance: initialize state from the passed-in breakdown
                currentTotalSpend = storeBreakdown.totalStoreSpend
                currentVisitCount = storeBreakdown.visitCount
                currentCategories = storeBreakdown.categories
                currentHealthScore = storeBreakdown.averageHealthScore
                hasInitialized = true
            } else {
                // Subsequent appearances (navigating back): refresh from backend
                // This handles the case where a receipt was deleted in ReceiptsListView
                print("🔄 [StoreDetailView] Re-appeared - refreshing from backend")
                Task {
                    await refreshStoreData()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDataDidChange)) { _ in
            print("🗑️ [StoreDetailView] Received receiptsDataDidChange - refreshing store data")
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
            // Parse the period to get date range
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            dateFormatter.locale = Locale(identifier: "en_US")
            dateFormatter.timeZone = TimeZone(identifier: "UTC")

            guard let parsedDate = dateFormatter.date(from: storeBreakdown.period) else {
                print("❌ [StoreDetailView] Could not parse period: \(storeBreakdown.period)")
                return
            }

            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "UTC")!

            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

            // Create filters for this store and period
            var filters = AnalyticsFilters()
            filters.period = .month
            filters.startDate = startOfMonth
            filters.endDate = endOfMonth
            filters.storeName = storeBreakdown.storeName

            print("📡 [StoreDetailView] Fetching fresh data for \(storeBreakdown.storeName)")
            let storeDetails = try await AnalyticsAPIService.shared.getStoreDetails(
                storeName: storeBreakdown.storeName,
                filters: filters
            )

            // Convert categories
            let categories = storeDetails.categories.map { categoryBreakdown in
                Category(
                    name: categoryBreakdown.name,
                    spent: categoryBreakdown.spent,
                    percentage: Int(categoryBreakdown.percentage)
                )
            }

            // Update state on main thread
            await MainActor.run {
                currentTotalSpend = storeDetails.totalSpend
                currentVisitCount = storeDetails.visitCount
                currentCategories = categories
                currentHealthScore = storeDetails.averageHealthScore
                print("✅ [StoreDetailView] Updated: €\(storeDetails.totalSpend), \(storeDetails.visitCount) receipts")
            }

        } catch {
            print("❌ [StoreDetailView] Failed to refresh store data: \(error.localizedDescription)")
        }
    }

    private func fetchTrends() async {
        guard !isLoadingTrends else { return }
        isLoadingTrends = true
        defer { isLoadingTrends = false }

        do {
            // Use the store-specific trends endpoint (52 months = ~4 years of history)
            print("[StoreDetailView] Fetching trends for store: \(storeBreakdown.storeName)")
            let response = try await AnalyticsAPIService.shared.getStoreTrends(storeName: storeBreakdown.storeName, periodType: .month, numPeriods: 52)
            print("[StoreDetailView] Fetched \(response.periods.count) trend periods for \(storeBreakdown.storeName)")
            await MainActor.run {
                self.trends = response.periods
            }
        } catch {
            print("[StoreDetailView] Failed to fetch trends for \(storeBreakdown.storeName): \(error)")
        }
    }

    private func categoryRow(segment: ChartSegment, isOther: Bool = false) -> some View {
        HStack {
            Circle()
                .fill(segment.color)
                .frame(width: 12, height: 12)

            Text(segment.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isOther ? .white.opacity(0.7) : .white)

            Spacer()

            Text("\(segment.percentage)%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 45, alignment: .trailing)

            Text(String(format: "€%.0f", segment.value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(isOther ? .white.opacity(0.7) : .white)
                .frame(width: 70, alignment: .trailing)

            if !isOther {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                // Placeholder to maintain alignment
                Color.clear
                    .frame(width: 12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Custom Button Styles
struct StoreHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

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
        StoreDetailView(storeBreakdown: StoreBreakdown(
            storeName: "COLRUYT",
            period: "January 2026",
            totalStoreSpend: 189.90,
            categories: [
                Category(name: "Meat & Fish", spent: 65.40, percentage: 34),
                Category(name: "Alcohol", spent: 42.50, percentage: 22),
                Category(name: "Drinks (Soft/Soda)", spent: 28.00, percentage: 15),
                Category(name: "Household", spent: 35.00, percentage: 18),
                Category(name: "Snacks & Sweets", spent: 19.00, percentage: 11)
            ],
            visitCount: 15
        ))
    }
    .preferredColorScheme(.dark)
}
