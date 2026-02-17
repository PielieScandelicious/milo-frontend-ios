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
                    Text(CategoryRegistryManager.shared.displayNameForCategory(categoryProgress.category))
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
                    currentSpend: 65
                )
            )

            // Near budget
            CategoryBudgetRow(
                categoryProgress: CategoryBudgetProgress(
                    category: "Meat & Fish",
                    budgetAmount: 150,
                    currentSpend: 140
                )
            )

            // Over budget
            CategoryBudgetRow(
                categoryProgress: CategoryBudgetProgress(
                    category: "Snacks & Sweets",
                    budgetAmount: 60,
                    currentSpend: 72
                )
            )
        }
        .padding()
    }
}
