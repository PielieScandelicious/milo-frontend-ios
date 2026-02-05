//
//  BudgetInsightsView.swift
//  Scandalicious
//
//  Created by Claude on 05/02/2026.
//  Deterministic, rule-based budget insights (no AI)
//

import SwiftUI

// MARK: - Budget Insights View

/// Main container for displaying budget insights
struct BudgetInsightsView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        switch viewModel.insightsState {
                        case .idle:
                            idleView
                        case .loading:
                            loadingView
                        case .loaded(let insights):
                            insightsContent(insights)
                        case .error(let message):
                            errorView(message)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Budget Insights")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if case .idle = viewModel.insightsState {
                await viewModel.loadInsights()
            }
        }
    }

    // MARK: - States

    private var idleView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

            Text("Loading insights...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(red: 0.3, green: 0.7, blue: 1.0))

            Text("Analyzing your spending...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("Failed to load insights")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await viewModel.loadInsights() }
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(red: 0.3, green: 0.7, blue: 1.0))
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    // MARK: - Insights Content

    private func insightsContent(_ insights: BudgetInsightsResponse) -> some View {
        VStack(spacing: 20) {
            // Health Score (if available)
            if let progress = insights.richProgress {
                BudgetHealthScoreCard(progress: progress)
            }

            // Belgian Benchmarks
            if let benchmarks = insights.belgianBenchmarks,
               !benchmarks.comparisons.isEmpty {
                BelgianBenchmarksCard(benchmarks: benchmarks)
            }

            // Over-budget Flags
            if let flags = insights.overBudgetFlags,
               !flags.flags.isEmpty {
                OverBudgetFlagsCard(flags: flags)
            }

            // Quick Wins
            if let quickWins = insights.quickWins,
               !quickWins.quickWins.isEmpty {
                QuickWinsCard(quickWins: quickWins)
            }

            // Volatility Alerts
            if let volatility = insights.volatilityAlerts,
               !volatility.alerts.isEmpty {
                VolatilityAlertsCard(volatility: volatility)
            }

            // Empty state
            if !insights.hasInsights {
                emptyInsightsView
            }

            // Data freshness
            Text(insights.dataFreshness)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
                .padding(.top, 8)
        }
    }

    private var emptyInsightsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("Not enough data yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Scan more receipts to get personalized insights")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
        )
    }
}

// MARK: - Budget Health Score Card

struct BudgetHealthScoreCard: View {
    let progress: RichProgressResponse

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(progress.healthScoreColor)
                Text("Budget Health")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            // Score display
            HStack(spacing: 24) {
                // Score ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 8)
                        .frame(width: 80, height: 80)

                    Circle()
                        .trim(from: 0, to: CGFloat(progress.healthScore) / 100)
                        .stroke(progress.healthScoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(progress.healthScore)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("/ 100")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Details
                VStack(alignment: .leading, spacing: 8) {
                    Text(progress.healthScoreLabel)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(progress.healthScoreColor)

                    // Breakdown
                    HStack(spacing: 12) {
                        scoreComponent("Pace", progress.healthScoreBreakdown.paceScore, max: 40)
                        scoreComponent("Balance", progress.healthScoreBreakdown.categoryBalanceScore, max: 30)
                        scoreComponent("Consistency", progress.healthScoreBreakdown.consistencyScore, max: 30)
                    }
                }

                Spacer()
            }

            Divider().background(Color.white.opacity(0.1))

            // Progress metrics
            HStack(spacing: 0) {
                metricItem(
                    title: "Daily Budget",
                    value: String(format: "€%.0f", progress.dailyBudgetRemaining),
                    subtitle: "\(progress.daysRemaining) days left"
                )

                Divider().background(Color.white.opacity(0.1)).frame(height: 40)

                metricItem(
                    title: "Projected",
                    value: String(format: "€%.0f", progress.projectedEndOfMonth),
                    subtitle: progress.projectedStatus.displayText,
                    color: progress.projectedStatus.color
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    private func scoreComponent(_ label: String, _ score: Int, max: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(score)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private func metricItem(title: String, value: String, subtitle: String, color: Color = .white) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text(subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Belgian Benchmarks Card

struct BelgianBenchmarksCard: View {
    let benchmarks: BelgianBenchmarksResponse
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "flag.fill")
                        .foregroundColor(.orange)
                    Text("Belgian Benchmarks")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(benchmarks.comparisons.prefix(8)) { comparison in
                        benchmarkRow(comparison)
                    }
                }
            } else {
                // Show summary
                if let topOver = benchmarks.comparisons.first(where: { $0.spendsMore }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.circle.fill")
                            .foregroundColor(.orange)
                        Text(topOver.comparisonText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
    }

    private func benchmarkRow(_ comparison: BelgianBenchmarkComparison) -> some View {
        HStack {
            Text(comparison.category)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            // User percentage
            Text(String(format: "%.0f%%", comparison.userPercentage))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)

            // Comparison indicator
            HStack(spacing: 4) {
                Image(systemName: comparison.spendsMore ? "arrow.up" : comparison.spendsLess ? "arrow.down" : "equal")
                    .font(.system(size: 10, weight: .bold))
                Text(String(format: "%+.0f%%", comparison.differencePercentage))
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(comparison.indicatorColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(comparison.indicatorColor.opacity(0.15))
            .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Over Budget Flags Card

struct OverBudgetFlagsCard: View {
    let flags: OverBudgetFlagsResponse

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Consistently Over Budget")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }

            VStack(spacing: 8) {
                ForEach(flags.flags) { flag in
                    flagRow(flag)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.red.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private func flagRow(_ flag: OverBudgetFlag) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(flag.category)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(flag.summaryText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "+€%.0f", flag.averageOverageAmount))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(flag.severity.color)
                Text("avg over")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
}

// MARK: - Quick Wins Card

struct QuickWinsCard: View {
    let quickWins: QuickWinsResponse
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.green)
                    Text("Quick Wins")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()

                    // Total savings
                    Text(String(format: "€%.0f/year", quickWins.totalPotentialYearlySavings))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(quickWins.quickWins) { win in
                        quickWinRow(win)
                    }
                }
            } else if let topWin = quickWins.quickWins.first {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                    Text(topWin.message)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.08))
        )
    }

    private func quickWinRow(_ win: QuickWin) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(win.category)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(String(format: "Cut %d%% (€%.0f → €%.0f/mo)",
                           win.suggestedCutPercentage,
                           win.currentMonthlySpend,
                           win.currentMonthlySpend - win.monthlySavings))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "€%.0f", win.yearlySavings))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.green)
                Text("per year")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
}

// MARK: - Volatility Alerts Card

struct VolatilityAlertsCard: View {
    let volatility: VolatilityAlertsResponse
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: "waveform.path")
                        .foregroundColor(.yellow)
                    Text("Unpredictable Spending")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(volatility.alerts) { alert in
                        volatilityRow(alert)
                    }
                }
            } else if let topAlert = volatility.alerts.first {
                HStack(spacing: 8) {
                    Image(systemName: topAlert.volatilityLevel.icon)
                        .foregroundColor(topAlert.volatilityLevel.color)
                    Text("\(topAlert.category): \(topAlert.rangeText)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.08))
        )
    }

    private func volatilityRow(_ alert: VolatilityAlert) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(alert.category)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)

                    Text(alert.volatilityLevel.displayText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(alert.volatilityLevel.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(alert.volatilityLevel.color.opacity(0.2))
                        .cornerRadius(4)
                }

                Text(alert.rangeText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "€%.0f", alert.averageMonthlySpend))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Text("avg/month")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .cornerRadius(10)
    }
}
