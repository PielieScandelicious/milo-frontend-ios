//
//  CategoryBudgetRow.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Category Budget Row

/// A row showing budget progress for a specific category
struct CategoryBudgetRow: View {
    let categoryProgress: CategoryBudgetProgress

    @State private var animationProgress: CGFloat = 0

    private var fillRatio: CGFloat {
        min(1.0, CGFloat(categoryProgress.spendRatio))
    }

    private var statusColor: Color {
        if categoryProgress.isOverBudget {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        } else if categoryProgress.spendRatio > 0.85 {
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        } else {
            return Color(red: 0.3, green: 0.75, blue: 0.45)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Category icon with mini ring
            CategoryBudgetRing(categoryProgress: categoryProgress, size: 36)

            // Category info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(categoryProgress.category.normalizedCategoryName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Amounts
                    HStack(spacing: 4) {
                        Text(String(format: "€%.0f", categoryProgress.currentSpend))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(categoryProgress.isOverBudget ? .red : .white)

                        Text("/")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))

                        Text(String(format: "€%.0f", categoryProgress.budgetAmount))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))

                        // Fill
                        RoundedRectangle(cornerRadius: 2)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * fillRatio * animationProgress)

                        // Over budget indicator
                        if categoryProgress.isOverBudget {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red.opacity(0.5))
                                .frame(width: geometry.size.width * min(0.2, CGFloat(categoryProgress.spendRatio - 1.0)) * animationProgress)
                                .offset(x: geometry.size.width)
                        }
                    }
                }
                .frame(height: 4)
            }

            // Lock indicator (if category budget is locked)
            if categoryProgress.isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Editable Category Budget Row

/// An editable version of the category budget row for setup/editing
struct EditableCategoryBudgetRow: View {
    let category: String
    @Binding var amount: Double
    @Binding var isLocked: Bool
    let totalBudget: Double

    private var percentage: Double {
        guard totalBudget > 0 else { return 0 }
        return (amount / totalBudget) * 100
    }

    private var categoryIcon: String {
        category.categoryIcon
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                // Category icon
                Image.categorySymbol(categoryIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(category.categoryColor)
                    .frame(width: 24)

                // Category name and percentage
                VStack(alignment: .leading, spacing: 2) {
                    Text(category)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(String(format: "%.0f%% of budget", percentage))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // Amount display
                Text(String(format: "€%.0f", amount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Lock toggle
                Button(action: { isLocked.toggle() }) {
                    Image(systemName: isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isLocked ? Color(red: 0.3, green: 0.7, blue: 1.0) : .white.opacity(0.4))
                }
            }

            // Slider for amount
            Slider(
                value: $amount,
                in: 0...max(amount * 2, 500),
                step: 5
            )
            .tint(category.categoryColor)
            .disabled(isLocked)
            .opacity(isLocked ? 0.5 : 1)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLocked ? Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 16) {
            Text("Category Budget Rows")
                .font(.headline)
                .foregroundColor(.white)

            // Under budget
            CategoryBudgetRow(
                categoryProgress: CategoryBudgetProgress(
                    category: "Fresh Produce",
                    budgetAmount: 100,
                    currentSpend: 65,
                    isLocked: false
                )
            )

            // Near budget
            CategoryBudgetRow(
                categoryProgress: CategoryBudgetProgress(
                    category: "Meat & Fish",
                    budgetAmount: 150,
                    currentSpend: 140,
                    isLocked: true
                )
            )

            // Over budget
            CategoryBudgetRow(
                categoryProgress: CategoryBudgetProgress(
                    category: "Snacks & Sweets",
                    budgetAmount: 60,
                    currentSpend: 72,
                    isLocked: false
                )
            )

            Divider()
                .padding(.vertical)

            Text("Editable Row")
                .font(.headline)
                .foregroundColor(.white)

            EditableCategoryBudgetRow(
                category: "Fresh Produce",
                amount: .constant(100),
                isLocked: .constant(false),
                totalBudget: 850
            )
            .padding(.horizontal)

            EditableCategoryBudgetRow(
                category: "Meat & Fish",
                amount: .constant(150),
                isLocked: .constant(true),
                totalBudget: 850
            )
            .padding(.horizontal)
        }
        .padding()
    }
}
