//
//  PastMonthHistoryWidget.swift
//  Scandalicious
//

import SwiftUI

struct PastMonthHistoryWidget: View {
    let history: BudgetHistory?
    @State private var isExpanded = false

    private static let greenColor = Color(red: 0.3, green: 0.8, blue: 0.5)
    private static let orangeColor = Color(red: 1.0, green: 0.75, blue: 0.3)
    private static let redColor = Color(red: 1.0, green: 0.4, blue: 0.4)

    var body: some View {
        Group {
            if let history = history {
                VStack(spacing: 0) {
                    collapsedHeader(history)
                    if isExpanded {
                        expandedContent(history)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: isExpanded)
            } else {
                noDataView
            }
        }
    }

    // MARK: - No Data

    private var noDataView: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.3))
            Text(L("no_budget_month"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .padding(16)
    }

    // MARK: - Collapsed Header

    @ViewBuilder
    private func collapsedHeader(_ history: BudgetHistory) -> some View {
        let ratio = history.spendRatio
        let color = statusColor(ratio: ratio)
        let isOver = history.hasTotalBudget && history.totalSpent > history.monthlyAmount
        let catCount = history.categorySpend?.count ?? history.categoryAllocations?.count ?? 0

        Button(action: {
            withAnimation(.easeInOut(duration: 0.25)) {
                isExpanded.toggle()
            }
        }) {
            HStack(spacing: 14) {
                if !isExpanded {
                    miniIcon(history, ratio: ratio, color: color)
                }

                summaryText(history, isOver: isOver, color: color, catCount: catCount)

                Spacer()

                if history.wasDeleted {
                    deletedBadge
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

    @ViewBuilder
    private func miniIcon(_ history: BudgetHistory, ratio: Double, color: Color) -> some View {
        if history.hasTotalBudget {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(CGFloat(ratio), 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(ratio, 9.99) * 100))%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(color)
            }
            .frame(width: 36, height: 36)
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

    @ViewBuilder
    private func summaryText(_ history: BudgetHistory, isOver: Bool, color: Color, catCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if history.hasTotalBudget {
                if isOver {
                    Text(String(format: "€%.0f \(L("over_budget"))", history.totalSpent - history.monthlyAmount))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                } else {
                    Text(String(format: "€%.0f / €%.0f", history.totalSpent, history.monthlyAmount))
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
    }

    private var deletedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "trash.fill")
                .font(.system(size: 9, weight: .bold))
            Text(L("deleted"))
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundColor(Self.orangeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Self.orangeColor.opacity(0.12))
        .cornerRadius(5)
    }

    // MARK: - Expanded Content

    @ViewBuilder
    private func expandedContent(_ history: BudgetHistory) -> some View {
        let ratio = history.spendRatio
        let color = statusColor(ratio: ratio)
        let isOver = history.hasTotalBudget && history.totalSpent > history.monthlyAmount
        let percent = Int(min(ratio, 9.99) * 100)

        VStack(spacing: 14) {
            if history.hasTotalBudget {
                totalBudgetRow(history, ratio: ratio, color: color, isOver: isOver, percent: percent)
            }

            if let cats = history.categorySpend, !cats.isEmpty {
                categoryList(cats)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    @ViewBuilder
    private func totalBudgetRow(_ history: BudgetHistory, ratio: Double, color: Color, isOver: Bool, percent: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(CGFloat(ratio), 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 1) {
                    Text("\(percent)%")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                    Text(L("spent"))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(width: 80, height: 80)

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

    // MARK: - Category List

    @ViewBuilder
    private func categoryList(_ cats: [CategorySpendHistory]) -> some View {
        VStack(spacing: 8) {
            ForEach(cats, id: \.category) { cat in
                categoryRow(cat)
            }
        }
    }

    @ViewBuilder
    private func categoryRow(_ cat: CategorySpendHistory) -> some View {
        let cRatio = cat.spendRatio
        let cColor = statusColor(ratio: cRatio)

        HStack(spacing: 10) {
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
                    Text(CategoryRegistryManager.shared.displayNameForSubCategory(cat.category))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 3) {
                        Text(String(format: "€%.0f", cat.spent))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(cColor)
                        Text("/")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.2))
                        Text(String(format: "€%.0f", cat.amount))
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(cColor)
                            .frame(width: max(0, geo.size.width * min(CGFloat(cRatio), 1.0)))
                    }
                }
                .frame(height: 4)
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(ratio: Double) -> Color {
        if ratio >= 1.0 { return Self.redColor }
        else if ratio >= 0.85 { return Self.orangeColor }
        else { return Self.greenColor }
    }
}
