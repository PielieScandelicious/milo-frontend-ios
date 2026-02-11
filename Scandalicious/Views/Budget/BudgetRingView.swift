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
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: progress.currentSpend) { _, _ in
            // Re-animate when progress changes
            animationProgress = 0
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
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
                // Amount spent
                Text(String(format: "€%.0f", progress.currentSpend))
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Of budget
                Text(String(format: "of €%.0f", progress.budget.monthlyAmount))
                    .font(.system(size: size * 0.09, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Spacer().frame(height: 4)

                // Status indicator
                HStack(spacing: 4) {
                    Image(systemName: paceStatus.icon)
                        .font(.system(size: size * 0.08, weight: .semibold))

                    Text(paceStatus.displayText)
                        .font(.system(size: size * 0.08, weight: .semibold))
                }
                .foregroundColor(paceStatus.color)
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
    var size: CGFloat = 44

    @State private var animationProgress: CGFloat = 0

    var body: some View {
        ZStack {
            // Background
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.15)
                .frame(width: size, height: size)

            // Progress
            Circle()
                .trim(from: 0, to: min(1.0, CGFloat(spendRatio)) * animationProgress)
                .stroke(
                    paceStatus.color,
                    style: StrokeStyle(
                        lineWidth: size * 0.15,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Percentage
            Text(String(format: "%.0f", min(spendRatio, 1.0) * 100))
                .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Budget Progress Bar

/// A horizontal progress bar alternative to the ring
struct BudgetProgressBar: View {
    let progress: BudgetProgress
    var height: CGFloat = 8

    @State private var animationProgress: CGFloat = 0

    private var fillRatio: CGFloat {
        min(1.0, CGFloat(progress.spendRatio))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.white.opacity(0.1))

                // Progress fill
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(progress.paceStatus.ringGradient)
                    .frame(width: geometry.size.width * fillRatio * animationProgress)

                // Pace marker (where you "should" be)
                let expectedPosition = geometry.size.width * CGFloat(progress.expectedSpendRatio)
                Rectangle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2, height: height + 4)
                    .offset(x: expectedPosition - 1)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
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
            Image(systemName: categoryProgress.icon)
                .font(.system(size: size * 0.32, weight: .semibold))
                .foregroundColor(ringColor)
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

    let overBudgetProgress = BudgetProgress(
        budget: sampleBudget,
        currentSpend: 920,
        daysElapsed: 25,
        daysInMonth: 31,
        categoryProgress: []
    )

    return ZStack {
        Color(white: 0.05).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 40) {
                Text("Budget Ring Sizes")
                    .font(.headline)
                    .foregroundColor(.white)

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
            }
            .padding()
        }
    }
}
