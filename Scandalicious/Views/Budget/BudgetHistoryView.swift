//
//  BudgetHistoryView.swift
//  Scandalicious
//

import SwiftUI

// MARK: - Budget History View

struct BudgetHistoryView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var expandedHistoryId: String?

    private static let greenColor = Color(red: 0.3, green: 0.8, blue: 0.5)
    private static let orangeColor = Color(red: 1.0, green: 0.75, blue: 0.3)
    private static let redColor = Color(red: 1.0, green: 0.4, blue: 0.4)

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                if viewModel.isLoadingHistory {
                    loadingView
                } else if let error = viewModel.historyError {
                    errorView(error)
                } else if viewModel.budgetHistory.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle(L("budget_history"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L("done")) { dismiss() }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if viewModel.budgetHistory.isEmpty {
                await viewModel.loadBudgetHistory()
            }
        }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(red: 0.3, green: 0.7, blue: 1.0))
            Text(L("loading_history"))
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Error

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Self.orangeColor)

            Text(L("failed_load_history"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.loadBudgetHistory() }
            } label: {
                Text(L("retry"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text(L("no_budget_history"))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(L("budget_history_appear"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - History List

    private var historyListView: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(viewModel.budgetHistory) { history in
                    historyWidget(history)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: - History Widget (Expandable Card)

    private func historyWidget(_ history: BudgetHistory) -> some View {
        let isExpanded = expandedHistoryId == history.id

        return VStack(spacing: 0) {
            // Collapsed header (always visible)
            historyCollapsedHeader(history, isExpanded: isExpanded)

            // Expanded content
            if isExpanded {
                historyExpandedContent(history)
                    .transition(.opacity)
            }
        }
        .background(premiumCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(premiumCardBorder)
        .animation(.easeInOut(duration: 0.25), value: expandedHistoryId)
    }

    // MARK: - Collapsed Header

    private func historyCollapsedHeader(_ history: BudgetHistory, isExpanded: Bool) -> some View {
        let ratio = history.spendRatio
        let color = statusColor(ratio: ratio)
        let isOver = history.hasTotalBudget && history.totalSpent > history.monthlyAmount
        let catCount = history.categorySpend?.count ?? history.categoryAllocations?.count ?? 0

        return Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedHistoryId = isExpanded ? nil : history.id
            }
        }) {
            HStack(spacing: 14) {
                // Mini ring or icon (collapsed only)
                if !isExpanded {
                    if history.hasTotalBudget {
                        MiniHistoryRing(
                            spendRatio: ratio,
                            ringColor: color,
                            size: 36
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 36, height: 36)

                            Image(systemName: "square.grid.2x2.fill")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Color(red: 0.5, green: 0.6, blue: 1.0))
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    }
                }

                // Summary text
                VStack(alignment: .leading, spacing: 2) {
                    if history.hasTotalBudget {
                        if isOver {
                            Text(String(format: "€%.0f \(L("over_budget"))", history.totalSpent - history.monthlyAmount))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(color)
                        } else {
                            Text(String(format: "€%.0f / €%.0f \(L("spent"))", history.totalSpent, history.monthlyAmount))
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(color)
                        }
                    } else if catCount > 0 {
                        Text("\(catCount) category budget\(catCount == 1 ? "" : "s")")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(String(format: "€%.0f \(L("budget"))", history.monthlyAmount))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text(history.displayMonthFull)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                // Deleted badge
                if history.wasDeleted {
                    HStack(spacing: 3) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 9, weight: .bold))
                        Text(L("deleted"))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(Self.orangeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Self.orangeColor.opacity(0.12))
                    .cornerRadius(6)
                }

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Expanded Content

    private func historyExpandedContent(_ history: BudgetHistory) -> some View {
        let ratio = history.spendRatio
        let color = statusColor(ratio: ratio)
        let isOver = history.hasTotalBudget && history.totalSpent > history.monthlyAmount
        let percent = Int(min(ratio, 9.99) * 100)

        return VStack(spacing: 14) {
            // Total budget section
            if history.hasTotalBudget {
                HStack(spacing: 14) {
                    // Pie ring
                    HistoryPieRing(
                        spendRatio: ratio,
                        ringColor: color,
                        size: 80
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "€%.0f", history.totalSpent))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(color)

                        Text(String(format: "€%.0f", history.monthlyAmount))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        HStack(spacing: 4) {
                            if ratio >= 0.85 {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(color)
                            } else {
                                Circle()
                                    .fill(color)
                                    .frame(width: 5, height: 5)
                            }

                            Text(isOver
                                 ? String(format: "€%.0f \(L("over"))", history.totalSpent - history.monthlyAmount)
                                 : "\(percent)% \(L("spent"))")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(color.opacity(0.85))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }

            // Category spend bars
            if let cats = history.categorySpend, !cats.isEmpty {
                VStack(spacing: 8) {
                    ForEach(cats, id: \.category) { cat in
                        historyCategoryRow(cat)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    // MARK: - Category Row

    private func historyCategoryRow(_ cat: CategorySpendHistory) -> some View {
        let ratio = cat.spendRatio
        let color = statusColor(ratio: ratio)
        let registry = CategoryRegistryManager.shared

        return HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(cat.category.categoryColor.opacity(0.15))
                    .frame(width: 30, height: 30)

                Image.categorySymbol(cat.category.categoryIcon)
                    .frame(width: 13, height: 13)
                    .foregroundStyle(cat.category.categoryColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(registry.displayNameForSubCategory(cat.category))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 3) {
                        Text(String(format: "€%.0f", cat.spent))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(color)

                        Text("/")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))

                        Text(String(format: "€%.0f", cat.amount))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                progressBar(ratio: ratio, color: color, height: 4)
            }
        }
    }

    // MARK: - Shared Components

    private var premiumCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
            RoundedRectangle(cornerRadius: 20)
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
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }

    private func progressBar(ratio: Double, color: Color, height: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * min(CGFloat(ratio), 1.0)))
            }
        }
        .frame(height: height)
    }

    private func statusColor(ratio: Double) -> Color {
        if ratio >= 1.0 {
            return Self.redColor
        } else if ratio >= 0.85 {
            return Self.orangeColor
        } else {
            return Self.greenColor
        }
    }
}

// MARK: - Mini History Ring (matches MiniBudgetRing style)

private struct MiniHistoryRing: View {
    let spendRatio: Double
    let ringColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 3)

            Circle()
                .trim(from: 0, to: min(CGFloat(spendRatio), 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(min(spendRatio, 9.99) * 100))%")
                .font(.system(size: size * 0.25, weight: .bold, design: .rounded))
                .foregroundColor(ringColor)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - History Pie Ring (matches BudgetPieChartView style)

private struct HistoryPieRing: View {
    let spendRatio: Double
    let ringColor: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 6)

            Circle()
                .trim(from: 0, to: min(CGFloat(spendRatio), 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(Int(min(spendRatio, 9.99) * 100))%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundColor(ringColor)

                Text(L("spent"))
                    .font(.system(size: size * 0.1, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Preview

#if DEBUG
struct BudgetHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BudgetViewModel()
        viewModel.budgetHistory = [
            BudgetHistory(
                id: "1", userId: "u1", monthlyAmount: 850,
                categoryAllocations: [
                    CategoryAllocation(category: "Fruits", amount: 80),
                    CategoryAllocation(category: "Dairy, Eggs & Cheese", amount: 120),
                ],
                month: "2026-02", wasSmartBudget: true, wasDeleted: false,
                createdAt: "2026-02-01T00:00:00Z", totalSpent: 720,
                categorySpend: [
                    CategorySpendHistory(category: "Fruits", amount: 80, spent: 65),
                    CategorySpendHistory(category: "Dairy, Eggs & Cheese", amount: 120, spent: 135),
                ]
            ),
            BudgetHistory(
                id: "2", userId: "u1", monthlyAmount: 900,
                categoryAllocations: nil,
                month: "2026-01", wasSmartBudget: false, wasDeleted: false,
                createdAt: "2026-01-01T00:00:00Z", totalSpent: 950,
                categorySpend: nil
            ),
            BudgetHistory(
                id: "3", userId: "u1", monthlyAmount: 700,
                categoryAllocations: [CategoryAllocation(category: "Alcohol", amount: 100)],
                month: "2025-12", wasSmartBudget: false, wasDeleted: true,
                createdAt: "2025-12-01T00:00:00Z", totalSpent: 0,
                categorySpend: [CategorySpendHistory(category: "Alcohol", amount: 100, spent: 45)]
            ),
        ]
        return BudgetHistoryView(viewModel: viewModel)
    }
}
#endif
