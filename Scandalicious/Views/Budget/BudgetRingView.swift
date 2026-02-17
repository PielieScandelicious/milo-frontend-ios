//
//  BudgetRingView.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Budget Ring View

/// A circular gauge showing budget progress with animated fill
struct BudgetRingView: View {
    let progress: BudgetProgress
    var size: CGFloat = 140
    var showDetails: Bool = true

    @State private var animationProgress: CGFloat = 0

    private var fillRatio: CGFloat {
        min(1.0, CGFloat(progress.spendRatio))
    }

    private var paceStatus: PaceStatus {
        progress.paceStatus
    }

    var body: some View {
        ZStack {
            // Background ring (budget limit)
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.12)
                .frame(width: size, height: size)

            // Progress ring (spending)
            Circle()
                .trim(from: 0, to: fillRatio * animationProgress)
                .stroke(
                    paceStatus.ringGradient,
                    style: StrokeStyle(
                        lineWidth: size * 0.12,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Over-budget indicator (if applicable)
            if progress.spendRatio > 1.0 {
                overBudgetRing
            }

            // Center content
            centerContent
        }
        .animation(.easeInOut(duration: 0.3), value: fillRatio)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }

    // MARK: - Over Budget Ring

    private var overBudgetRing: some View {
        let overRatio = min(0.5, CGFloat(progress.spendRatio - 1.0)) // Cap at 50% over for visual

        return Circle()
            .trim(from: 0, to: overRatio * animationProgress)
            .stroke(
                Color.red.opacity(0.6),
                style: StrokeStyle(
                    lineWidth: size * 0.06,
                    lineCap: .round,
                    dash: [4, 4]
                )
            )
            .frame(width: size * 1.15, height: size * 1.15)
            .rotationEffect(.degrees(-90))
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 2) {
            if showDetails {
                let remaining = max(0, progress.budget.monthlyAmount - progress.currentSpend)

                Text(String(format: "€%.0f", remaining))
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(L("left_to_spend"))
                    .font(.system(size: size * 0.08, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            } else {
                // Compact: just percentage
                Text(String(format: "%.0f%%", progress.spendRatio * 100))
                    .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}

// MARK: - Mini Budget Ring

/// A smaller, simpler budget ring for inline use
struct MiniBudgetRing: View {
    let spendRatio: Double
    let paceStatus: PaceStatus
    var ringColor: Color? = nil
    var size: CGFloat = 44

    @State private var animationProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Background — blocks inherited animations
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.15)
                .frame(width: size, height: size)
                .transaction { $0.animation = nil }

            // Progress
            Circle()
                .trim(from: 0, to: min(1.0, CGFloat(spendRatio)) * animationProgress)
                .stroke(
                    ringColor ?? paceStatus.color,
                    style: StrokeStyle(
                        lineWidth: size * 0.15,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.8, dampingFraction: 0.8), value: animationProgress)
                .animation(.easeInOut(duration: 0.3), value: spendRatio)

            // Warning icon at 85%+ thresholds
            if spendRatio >= 0.85 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundColor(ringColor ?? paceStatus.color)
            }
        }
        .onAppear {
            animationProgress = 1.0
        }
    }
}

// MARK: - Category Budget Ring

/// A ring showing budget progress for a specific category
struct CategoryBudgetRing: View {
    let categoryProgress: CategoryBudgetProgress
    var size: CGFloat = 36

    @State private var animationProgress: CGFloat = 0

    private var fillRatio: CGFloat {
        min(1.2, CGFloat(categoryProgress.spendRatio)) // Allow slight overflow visual
    }

    private var ringColor: Color {
        if categoryProgress.isOverBudget {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        } else if categoryProgress.spendRatio > 0.85 {
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        } else {
            return Color(red: 0.3, green: 0.75, blue: 0.45)
        }
    }

    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.12)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: min(1.0, fillRatio) * animationProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: size * 0.12,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Category icon
            Image.categorySymbol(categoryProgress.icon)
                .frame(width: size * 0.32, height: size * 0.32)
                .foregroundStyle(ringColor)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleBudget = UserBudget(
        id: "1",
        userId: "user1",
        monthlyAmount: 850,
        categoryAllocations: nil,
        isSmartBudget: true,
        createdAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-01T00:00:00Z"
    )

    let sampleProgress = BudgetProgress(
        budget: sampleBudget,
        currentSpend: 623,
        daysElapsed: 21,
        daysInMonth: 31,
        categoryProgress: []
    )

    return ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 40) {
            BudgetRingView(progress: sampleProgress, size: 120)

                HStack(spacing: 24) {
                    BudgetRingView(progress: sampleProgress, size: 100)
                    BudgetRingView(progress: sampleProgress, size: 140)
                }

                Text("Status Variations")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 20) {
                    // Under budget
                    BudgetRingView(
                        progress: BudgetProgress(
                            budget: sampleBudget,
                            currentSpend: 400,
                            daysElapsed: 21,
                            daysInMonth: 31,
                            categoryProgress: []
                        ),
                        size: 100
                    )

                    // Over budget
                    BudgetRingView(
                        progress: overBudgetProgress,
                        size: 100
                    )
                }

                Text("Mini Rings")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 16) {
                    MiniBudgetRing(spendRatio: 0.4, paceStatus: .underBudget)
                    MiniBudgetRing(spendRatio: 0.73, paceStatus: .onTrack)
                    MiniBudgetRing(spendRatio: 0.95, paceStatus: .slightlyOver)
                }

                Text("Progress Bar")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(spacing: 16) {
                    BudgetProgressBar(progress: sampleProgress)
                        .padding(.horizontal)

                    BudgetProgressBar(progress: overBudgetProgress)
                        .padding(.horizontal)
                }

                Text("Category Rings")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    CategoryBudgetRing(
                        categoryProgress: CategoryBudgetProgress(
                            category: "Fresh Produce",
                            budgetAmount: 100,
                            currentSpend: 65
                        )
                    )

                    CategoryBudgetRing(
                        categoryProgress: CategoryBudgetProgress(
                            category: "Snacks & Sweets",
                            budgetAmount: 60,
                            currentSpend: 72
                        )
                    )

                    CategoryBudgetRing(
                        categoryProgress: CategoryBudgetProgress(
                            category: "Meat & Fish",
                            budgetAmount: 120,
                            currentSpend: 110
                        )
                    )
                }

                Text("Projected Budget Bar")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 16) {
                    // Under budget projection
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("under_budget"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        ProjectedBudgetBar(
                            totalBudget: 850,
                            currentSpend: 400,
                            projectedSpend: 620
                        )
                    }

                    // Over budget projection
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("over_budget_projection"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        ProjectedBudgetBar(
                            totalBudget: 850,
                            currentSpend: 500,
                            projectedSpend: 950
                        )
                    }

                    // Already over budget
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("already_over_budget"))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                        ProjectedBudgetBar(
                            totalBudget: 850,
                            currentSpend: 920,
                            projectedSpend: 1100
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
