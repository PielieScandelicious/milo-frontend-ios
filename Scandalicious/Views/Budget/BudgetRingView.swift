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
                let remaining = max(0, progress.budget.monthlyAmount - progress.currentSpend)

                Text(String(format: "€%.0f", remaining))
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("left to spend")
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
    @Environment(\.selectedTabIndex) private var selectedTabIndex

    private func replayAnimation() {
        // Reset without animation, then animate in the next render pass.
        // Without the delay, SwiftUI coalesces 1.0→0→1.0 into a no-op.
        animationProgress = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }

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
        }
        .onAppear {
            replayAnimation()
        }
        .onChange(of: selectedTabIndex) { _, newValue in
            // Replay sweep when switching to the View tab (rawValue 0)
            if newValue == 0 {
                replayAnimation()
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

// MARK: - Projected Budget Bar

/// A horizontal bar visualizing current and projected spend against a category limit.
/// Uses three layered capsules: background track, semi-transparent ghost bar for projection,
/// and a solid bar for current spend.
struct ProjectedBudgetBar: View {
    let totalBudget: Double
    let currentSpend: Double
    let projectedSpend: Double
    var height: CGFloat = 10

    @State private var animationProgress: CGFloat = 0

    private var currentRatio: CGFloat {
        guard totalBudget > 0 else { return 0 }
        return min(1.0, CGFloat(currentSpend / totalBudget))
    }

    private var projectedRatio: CGFloat {
        guard totalBudget > 0 else { return 0 }
        return min(1.0, CGFloat(projectedSpend / totalBudget))
    }

    private var isProjectedOverBudget: Bool {
        projectedSpend > totalBudget
    }

    private var ghostBarColor: Color {
        isProjectedOverBudget
            ? Color(red: 1.0, green: 0.5, blue: 0.25)
            : Color(red: 0.3, green: 0.75, blue: 0.45)
    }

    private var currentBarColor: Color {
        if currentSpend > totalBudget {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        } else if isProjectedOverBudget {
            return Color(red: 1.0, green: 0.65, blue: 0.2)
        } else {
            return Color(red: 0.3, green: 0.75, blue: 0.45)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Layer 1 (Bottom): Gray background track — full budget
                Capsule()
                    .fill(Color.white.opacity(0.1))

                // Layer 2 (Middle): Ghost bar — projected spend
                Capsule()
                    .fill(ghostBarColor.opacity(0.3))
                    .frame(width: geometry.size.width * projectedRatio * animationProgress)

                // Layer 3 (Top): Solid bar — current spend
                Capsule()
                    .fill(currentBarColor)
                    .frame(width: geometry.size.width * currentRatio * animationProgress)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: currentSpend) { _, _ in
            animationProgress = 0
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

                Text("Projected Budget Bar")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(alignment: .leading, spacing: 16) {
                    // Under budget projection
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Under budget")
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
                        Text("Over budget projection")
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
                        Text("Already over budget")
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
            .padding()
        }
    }
}
