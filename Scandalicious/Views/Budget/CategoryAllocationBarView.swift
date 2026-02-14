//
//  CategoryAllocationBarView.swift
//  Scandalicious
//
//  Horizontal progress bars showing spending against each category budget limit.
//

import SwiftUI

// MARK: - Single Category Bar

struct CategoryAllocationBar: View {
    let categoryProgress: CategoryBudgetProgress
    var height: CGFloat = 8

    @State private var animationProgress: CGFloat = 0

    // MARK: - Color Constants

    private static let greenColor = Color(red: 0.3, green: 0.8, blue: 0.5)
    private static let orangeColor = Color(red: 1.0, green: 0.75, blue: 0.3)
    private static let redColor = Color(red: 1.0, green: 0.4, blue: 0.4)

    // MARK: - Display Rules
    //
    //   0-84%  → green bar, green status
    //  85-99%  → orange bar, orange status, orange percentage + warning icon
    //   100%+  → red bar, red status (at or over budget)

    private var displayedPercent: Int {
        categoryProgress.displayedPercent
    }

    private var fillRatio: CGFloat {
        min(1.0, CGFloat(categoryProgress.spendRatio))
    }

    private var barColor: Color {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return Self.redColor
        } else if displayedPercent >= 85 {
            return Self.orangeColor
        } else {
            return Self.greenColor
        }
    }

    private var statusIcon: String {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return "exclamationmark.triangle.fill"
        } else if displayedPercent >= 85 {
            return "exclamationmark.circle.fill"
        } else {
            return "checkmark.circle.fill"
        }
    }

    private var statusText: String {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return String(format: "€%.0f over", categoryProgress.overAmount)
        } else {
            return String(format: "€%.0f left", categoryProgress.remainingAmount)
        }
    }

    private var spendAmountColor: Color {
        if categoryProgress.isOverBudget || displayedPercent >= 100 {
            return Self.redColor
        } else if displayedPercent >= 85 {
            return Self.orangeColor
        } else {
            return .white
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Top row: icon + name + amounts
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(categoryProgress.category.categoryColor.opacity(0.15))
                        .frame(width: 34, height: 34)

                    Image.categorySymbol(categoryProgress.icon)
                        .frame(width: 15, height: 15)
                        .foregroundStyle(categoryProgress.category.categoryColor)
                }

                Text(CategoryRegistryManager.shared.displayNameForSubCategory(categoryProgress.category))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 3) {
                    Text(String(format: "€%.0f", categoryProgress.currentSpend))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(spendAmountColor)

                    Text("/")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.25))

                    Text(String(format: "€%.0f", categoryProgress.budgetAmount))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
            }

            // Horizontal progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    Capsule()
                        .fill(barColor)
                        .frame(width: geometry.size.width * fillRatio * animationProgress)
                }
            }
            .frame(height: height)

            // Bottom row: status + percentage
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: statusIcon)
                        .font(.system(size: 10, weight: .semibold))
                    Text(statusText)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(barColor)

                Spacer()

                // Percentage with warning icon for 85-99%, red for 100%+
                if displayedPercent >= 85 && displayedPercent < 100 && !categoryProgress.isOverBudget {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 9, weight: .semibold))
                        Text("\(displayedPercent)%")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Self.orangeColor)
                } else if categoryProgress.isOverBudget || displayedPercent >= 100 {
                    Text("\(displayedPercent)%")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Self.redColor)
                } else {
                    Text("\(displayedPercent)%")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Category Bar List

struct CategoryAllocationBarList: View {
    let categories: [CategoryBudgetProgress]
    var maxVisible: Int = 5
    var onSeeAll: (() -> Void)?

    private var sortedCategories: [CategoryBudgetProgress] {
        categories.sorted {
            if $0.spendRatio != $1.spendRatio {
                return $0.spendRatio > $1.spendRatio
            }
            return $0.currentSpend > $1.currentSpend
        }
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("Budget by Category")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Spacer()

                if let onSeeAll, categories.count > maxVisible {
                    Button(action: onSeeAll) {
                        HStack(spacing: 4) {
                            Text("See All (\(categories.count))")
                                .font(.system(size: 12, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white.opacity(0.35))
                    }
                }
            }
            .padding(.horizontal, 16)

            ForEach(Array(sortedCategories.prefix(maxVisible)), id: \.id) { cat in
                CategoryAllocationBar(categoryProgress: cat)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let categories: [CategoryBudgetProgress] = [
        CategoryBudgetProgress(category: "Dairy & Eggs", budgetAmount: 120, currentSpend: 130),   // 108% → red
        CategoryBudgetProgress(category: "Meat & Fish", budgetAmount: 200, currentSpend: 200),    // 100% → red
        CategoryBudgetProgress(category: "Bakery", budgetAmount: 80, currentSpend: 72),           //  90% → orange
        CategoryBudgetProgress(category: "Fresh Produce", budgetAmount: 150, currentSpend: 80),   //  53% → green
        CategoryBudgetProgress(category: "Snacks & Sweets", budgetAmount: 60, currentSpend: 15),  //  25% → green
        CategoryBudgetProgress(category: "Drinks", budgetAmount: 100, currentSpend: 45)           //  45% → green
    ]

    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                Text("Category Bars")
                    .font(.headline)
                    .foregroundColor(.white)

                CategoryAllocationBarList(
                    categories: categories,
                    maxVisible: 5,
                    onSeeAll: {}
                )
            }
            .padding(.vertical)
        }
    }
}
