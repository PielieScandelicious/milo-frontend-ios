//
//  BudgetPieChartView.swift
//  Scandalicious
//
//  A pie chart showing how the monthly budget is allocated across categories.
//  Custom donut for multi-category, custom ring for total-only.
//

import SwiftUI

struct BudgetPieChartView: View {
    let progress: BudgetProgress
    var size: CGFloat = 160

    var body: some View {
        BudgetTotalRing(progress: progress, size: size)
    }
}

// MARK: - Total Budget Ring (fixed gray background, animated colored segment)

private struct BudgetTotalRing: View {
    let progress: BudgetProgress
    var size: CGFloat = 120

    @State private var animationProgress: CGFloat = 0

    private var ringColor: Color {
        progress.budgetStatusColor
    }

    private var strokeWidth: CGFloat {
        size * 0.12
    }

    private var spendFraction: CGFloat {
        guard progress.budget.monthlyAmount > 0 else { return 0 }
        return min(1.0, CGFloat(progress.currentSpend / progress.budget.monthlyAmount))
    }

    var body: some View {
        ZStack {
            // Full gray background circle — always visible, no animation
            Circle()
                .stroke(Color(white: 0.25), lineWidth: strokeWidth)
                .frame(width: size - strokeWidth, height: size - strokeWidth)
                .transaction { $0.animation = nil }

            // Colored segment — sweeps in on appear, smoothly adjusts on data change
            Circle()
                .trim(from: 0, to: spendFraction * animationProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size - strokeWidth, height: size - strokeWidth)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animationProgress)
                .animation(.easeInOut(duration: 0.3), value: spendFraction)

            // Center icon
            Image(systemName: "banknote.fill")
                .font(.system(size: size * 0.22, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
                .transaction { $0.animation = nil }
        }
        .frame(width: size, height: size)
        .onAppear {
            animationProgress = 1.0
        }
    }
}

// MARK: - Preview

#Preview {
    let budget = UserBudget(
        id: "1",
        userId: "user1",
        monthlyAmount: 850,
        categoryAllocations: [
            CategoryAllocation(category: "MEAT_FISH", amount: 200),
            CategoryAllocation(category: "FRESH_PRODUCE", amount: 150),
            CategoryAllocation(category: "DAIRY_EGGS", amount: 120),
            CategoryAllocation(category: "BAKERY", amount: 80),
            CategoryAllocation(category: "SNACKS_SWEETS", amount: 60)
        ],
        isSmartBudget: true
    )

    let progress = BudgetProgress(
        budget: budget,
        currentSpend: 450,
        daysElapsed: 15,
        daysInMonth: 28,
        categoryProgress: []
    )

    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 32) {
            Text("With Categories")
                .font(.headline)
                .foregroundColor(.white)
            BudgetPieChartView(progress: progress, size: 140)

            Text("Total Only (under)")
                .font(.headline)
                .foregroundColor(.white)
            BudgetPieChartView(
                progress: BudgetProgress(
                    budget: UserBudget(
                        id: "2",
                        userId: "user1",
                        monthlyAmount: 500
                    ),
                    currentSpend: 200,
                    daysElapsed: 10,
                    daysInMonth: 28
                ),
                size: 120
            )

            Text("Total Only (over)")
                .font(.headline)
                .foregroundColor(.white)
            BudgetPieChartView(
                progress: BudgetProgress(
                    budget: UserBudget(
                        id: "3",
                        userId: "user1",
                        monthlyAmount: 500
                    ),
                    currentSpend: 600,
                    daysElapsed: 25,
                    daysInMonth: 28
                ),
                size: 120
            )
        }
    }
}
