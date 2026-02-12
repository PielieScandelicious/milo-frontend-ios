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

    private var hasCategories: Bool {
        guard let allocations = progress.budget.categoryAllocations else { return false }
        return !allocations.isEmpty
    }

    var body: some View {
        if hasCategories {
            BudgetCategoryDonut(progress: progress, size: size)
        } else {
            BudgetTotalRing(progress: progress, size: size)
        }
    }
}

// MARK: - Budget Category Donut (rounded edges, clockwise reveal animation)

private struct BudgetCategoryDonut: View {
    let progress: BudgetProgress
    var size: CGFloat = 160

    @State private var revealProgress: CGFloat = 0

    private var isOverBudget: Bool {
        progress.currentSpend > progress.budget.monthlyAmount
    }

    private static let greenPalette: [Color] = [
        Color(red: 0.22, green: 0.72, blue: 0.45),
        Color(red: 0.28, green: 0.78, blue: 0.52),
        Color(red: 0.35, green: 0.68, blue: 0.48),
        Color(red: 0.25, green: 0.75, blue: 0.58),
        Color(red: 0.40, green: 0.72, blue: 0.42),
        Color(red: 0.30, green: 0.65, blue: 0.50),
        Color(red: 0.32, green: 0.80, blue: 0.55),
        Color(red: 0.38, green: 0.70, blue: 0.46),
    ]

    private static let redPalette: [Color] = [
        Color(red: 0.88, green: 0.35, blue: 0.35),
        Color(red: 0.92, green: 0.42, blue: 0.38),
        Color(red: 0.82, green: 0.38, blue: 0.40),
        Color(red: 0.95, green: 0.45, blue: 0.42),
        Color(red: 0.85, green: 0.32, blue: 0.36),
        Color(red: 0.90, green: 0.48, blue: 0.40),
        Color(red: 0.80, green: 0.36, blue: 0.38),
        Color(red: 0.86, green: 0.40, blue: 0.35),
    ]

    private var activePalette: [Color] {
        isOverBudget ? Self.redPalette : Self.greenPalette
    }

    private struct SliceData {
        let startAngle: Double // 0..1
        let endAngle: Double   // 0..1
        let color: Color
        let isFirst: Bool
        let isLast: Bool
    }

    private var slices: [SliceData] {
        guard let allocations = progress.budget.categoryAllocations,
              !allocations.isEmpty else { return [] }

        let total = progress.budget.monthlyAmount
        guard total > 0 else { return [] }

        var result: [SliceData] = []
        var cursor: Double = 0
        let hasUnallocated = allocations.reduce(0.0) { $0 + $1.amount } < total - 0.01

        for (index, allocation) in allocations.enumerated() {
            let fraction = allocation.amount / total
            let color = activePalette[index % activePalette.count]
            let isLast = !hasUnallocated && index == allocations.count - 1
            result.append(SliceData(
                startAngle: cursor,
                endAngle: cursor + fraction,
                color: color,
                isFirst: index == 0,
                isLast: isLast
            ))
            cursor += fraction
        }

        return result
    }

    private var strokeWidth: CGFloat {
        size * 0.08
    }

    private var leftToSpend: Double {
        max(0, progress.budget.monthlyAmount - progress.currentSpend)
    }

    /// Computes the visible trim end for a slice based on current reveal progress.
    /// When revealProgress < startAngle, returns startAngle (zero-length arc = invisible).
    /// When revealProgress >= endAngle, returns endAngle (fully revealed).
    /// In between, returns revealProgress (partially revealed).
    private func trimEnd(for slice: SliceData) -> CGFloat {
        let start = CGFloat(slice.startAngle)
        let end = CGFloat(slice.endAngle)
        if revealProgress <= start {
            return start // not yet reached — zero-length arc, invisible
        }
        return min(end, revealProgress)
    }

    var body: some View {
        ZStack {
            // Full gray background circle — always visible, no animation
            Circle()
                .stroke(Color(white: 0.25), lineWidth: strokeWidth)
                .frame(width: size - strokeWidth, height: size - strokeWidth)
                .transaction { $0.animation = nil }

            // Animated category segments
            ForEach(Array(slices.enumerated()), id: \.offset) { _, slice in
                Circle()
                    .trim(from: CGFloat(slice.startAngle), to: trimEnd(for: slice))
                    .stroke(
                        slice.color,
                        style: StrokeStyle(
                            lineWidth: strokeWidth,
                            lineCap: .round
                        )
                    )
                    .frame(width: size - strokeWidth, height: size - strokeWidth)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: revealProgress)
            }

            // Center content — also blocks inherited animations
            VStack(spacing: 3) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: size * 0.12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Text(String(format: "€%.0f", leftToSpend))
                    .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("left to spend")
                    .font(.system(size: size * 0.065, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .transaction { $0.animation = nil }
        }
        .frame(width: size, height: size)
        .onAppear {
            revealProgress = 1.0
        }
    }
}

// MARK: - Total Budget Ring (fixed gray background, animated colored segment)

private struct BudgetTotalRing: View {
    let progress: BudgetProgress
    var size: CGFloat = 120

    @State private var fillEnd: CGFloat = 0

    private var isOverBudget: Bool {
        progress.currentSpend > progress.budget.monthlyAmount
    }

    private var ringColor: Color {
        isOverBudget
            ? Color(red: 0.88, green: 0.35, blue: 0.35)
            : Color(red: 0.22, green: 0.72, blue: 0.45)
    }

    private var strokeWidth: CGFloat {
        size * 0.08
    }

    private var leftToSpend: Double {
        max(0, progress.budget.monthlyAmount - progress.currentSpend)
    }

    var body: some View {
        ZStack {
            // Colored segment — spring animation on the trim value
            Circle()
                .trim(from: 0, to: fillEnd)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: strokeWidth,
                        lineCap: .round
                    )
                )
                .frame(width: size - strokeWidth, height: size - strokeWidth)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: fillEnd)

            // Center: amount left to spend — blocks inherited animations
            VStack(spacing: 3) {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: size * 0.12, weight: .semibold))
                    .foregroundColor(ringColor.opacity(0.7))

                Text(String(format: "€%.0f", leftToSpend))
                    .font(.system(size: size * 0.18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("left to spend")
                    .font(.system(size: size * 0.065, weight: .medium))
                    .foregroundColor(.white.opacity(0.45))
            }
            .transaction { $0.animation = nil }
        }
        .frame(width: size, height: size)
        .onAppear {
            fillEnd = 1.0
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
