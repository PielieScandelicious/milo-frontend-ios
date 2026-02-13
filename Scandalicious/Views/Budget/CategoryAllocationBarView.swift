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

    private var fillRatio: CGFloat {
        min(1.0, CGFloat(categoryProgress.spendRatio))
    }

    private var statusColor: Color {
        categoryProgress.isOverBudget
            ? Color(red: 1.0, green: 0.4, blue: 0.4)
            : Color(red: 0.3, green: 0.8, blue: 0.5)
    }

    private var statusIcon: String {
        categoryProgress.isOverBudget
            ? "exclamationmark.triangle.fill"
            : "checkmark.circle.fill"
    }

    private var statusText: String {
        if categoryProgress.isOverBudget {
            return String(format: "€%.0f over", categoryProgress.overAmount)
        } else {
            return String(format: "€%.0f left", categoryProgress.remainingAmount)
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

                    Image(systemName: categoryProgress.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(categoryProgress.category.categoryColor)
                }

                Text(categoryProgress.category.normalizedCategoryName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 3) {
                    Text(String(format: "€%.0f", categoryProgress.currentSpend))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(categoryProgress.isOverBudget ? statusColor : .white)

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
                        .fill(statusColor)
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
                .foregroundColor(statusColor)

                Spacer()

                Text(String(format: "%.0f%%", min(categoryProgress.spendRatio, 9.99) * 100))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.35))
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
        categories.sorted { $0.currentSpend > $1.currentSpend }
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
        CategoryBudgetProgress(category: "Meat & Fish", budgetAmount: 200, currentSpend: 165),
        CategoryBudgetProgress(category: "Fresh Produce", budgetAmount: 150, currentSpend: 80),
        CategoryBudgetProgress(category: "Dairy & Eggs", budgetAmount: 120, currentSpend: 130),
        CategoryBudgetProgress(category: "Bakery", budgetAmount: 80, currentSpend: 72),
        CategoryBudgetProgress(category: "Snacks & Sweets", budgetAmount: 60, currentSpend: 15),
        CategoryBudgetProgress(category: "Drinks", budgetAmount: 100, currentSpend: 45)
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
