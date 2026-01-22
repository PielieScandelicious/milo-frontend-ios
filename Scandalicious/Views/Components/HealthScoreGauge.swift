//
//  HealthScoreGauge.swift
//  Scandalicious
//
//  Created by Claude on 21/01/2026.
//

import SwiftUI

// MARK: - Health Score Gauge

/// A circular gauge displaying the average health score with optional trend indicator
struct HealthScoreGauge: View {
    let score: Double?
    var size: CGFloat = 120
    var showTrend: Bool = false
    var previousScore: Double? = nil
    var showLabel: Bool = true

    @State private var animationProgress: CGFloat = 0

    private var normalizedScore: CGFloat {
        guard let score = score else { return 0 }
        return CGFloat(score / 5.0)
    }

    private var trendDirection: TrendDirection {
        guard let current = score, let previous = previousScore else {
            return .neutral
        }
        let diff = current - previous
        if diff > 0.1 {
            return .up
        } else if diff < -0.1 {
            return .down
        }
        return .neutral
    }

    var body: some View {
        VStack(spacing: size * 0.08) {
            ZStack {
                // Background track
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: size * 0.1)
                    .frame(width: size, height: size)

                // Progress arc
                Circle()
                    .trim(from: 0, to: normalizedScore * animationProgress)
                    .stroke(
                        score.healthScoreColor,
                        style: StrokeStyle(
                            lineWidth: size * 0.1,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    if let score = score {
                        Text(score.formattedHealthScore)
                            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if showTrend && trendDirection != .neutral {
                            trendIndicator
                        }
                    } else {
                        Text("-")
                            .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
            }

            if showLabel {
                Text(score.healthScoreLabel)
                    .font(.system(size: size * 0.12, weight: .semibold))
                    .foregroundColor(score.healthScoreColor)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }

    private var trendIndicator: some View {
        HStack(spacing: 2) {
            Image(systemName: trendDirection.icon)
                .font(.system(size: size * 0.1, weight: .bold))

            if let previous = previousScore, let current = score {
                let diff = current - previous
                Text(String(format: "%+.1f", diff))
                    .font(.system(size: size * 0.08, weight: .semibold, design: .rounded))
            }
        }
        .foregroundColor(trendDirection.color)
    }
}

// MARK: - Trend Direction

private enum TrendDirection {
    case up
    case down
    case neutral

    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .neutral: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: return Color(red: 0.3, green: 0.8, blue: 0.4)
        case .down: return Color(red: 0.9, green: 0.4, blue: 0.4)
        case .neutral: return Color(white: 0.5)
        }
    }
}

// MARK: - Health Score Card (Dashboard)

/// A full card for displaying health score on the dashboard
struct HealthScoreCard: View {
    let score: Double?
    var previousScore: Double? = nil
    var period: String = ""

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(score.healthScoreColor)

                Text("Health Score")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(1)

                Spacer()

                if let score = score {
                    Text(score.healthScoreLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(score.healthScoreColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(score.healthScoreColor.opacity(0.15))
                        )
                }
            }

            HStack(alignment: .center, spacing: 16) {
                HealthScoreGauge(
                    score: score,
                    size: 80,
                    showTrend: previousScore != nil,
                    previousScore: previousScore,
                    showLabel: false
                )

                VStack(alignment: .leading, spacing: 8) {
                    if let score = score {
                        Text("\(score.formattedHealthScore) / 5.0")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if let previous = previousScore {
                            let diff = score - previous
                            HStack(spacing: 4) {
                                Image(systemName: diff >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                                    .font(.system(size: 14))
                                Text(String(format: "%+.1f vs last period", diff))
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundColor(diff >= 0 ? Color(red: 0.3, green: 0.8, blue: 0.4) : Color(red: 0.9, green: 0.4, blue: 0.4))
                        }
                    } else {
                        Text("No Data")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))

                        Text("Upload receipts to see your health score")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()
            }

            if !period.isEmpty {
                Text(period)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Compact Health Score Display

/// A compact inline health score display
struct CompactHealthScoreDisplay: View {
    let score: Double?
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(score.healthScoreColor)

            if let score = score {
                Text(score.formattedHealthScore)
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(score.healthScoreColor)
            } else {
                Text("-")
                    .font(.system(size: size, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Health Score Summary Row

/// A row showing health score with label, useful for list views
struct HealthScoreSummaryRow: View {
    let label: String
    let score: Double?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            Spacer()

            if let score = score {
                HStack(spacing: 6) {
                    Text(score.formattedHealthScore)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(score.healthScoreColor)

                    HealthScoreIndicator(score: Int(score.rounded()), diameter: 8)
                }
            } else {
                Text("N/A")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 32) {
                // Gauge sizes
                Text("Gauge Sizes")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    HealthScoreGauge(score: 4.2, size: 60)
                    HealthScoreGauge(score: 3.5, size: 100)
                    HealthScoreGauge(score: 2.1, size: 80)
                }

                // With trend
                Text("With Trend")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    HealthScoreGauge(score: 4.2, size: 80, showTrend: true, previousScore: 3.8)
                    HealthScoreGauge(score: 3.1, size: 80, showTrend: true, previousScore: 3.5)
                    HealthScoreGauge(score: nil, size: 80)
                }

                // Full card
                Text("Dashboard Card")
                    .font(.headline)
                    .foregroundColor(.white)

                HealthScoreCard(
                    score: 3.8,
                    previousScore: 3.2,
                    period: "January 2026"
                )
                .padding(.horizontal)

                HealthScoreCard(
                    score: nil,
                    period: "January 2026"
                )
                .padding(.horizontal)

                // Compact display
                Text("Compact Display")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    CompactHealthScoreDisplay(score: 4.5)
                    CompactHealthScoreDisplay(score: 2.3)
                    CompactHealthScoreDisplay(score: nil)
                }

                // Summary rows
                Text("Summary Rows")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    HealthScoreSummaryRow(label: "This Month", score: 3.8)
                    HealthScoreSummaryRow(label: "Last Month", score: 3.2)
                    HealthScoreSummaryRow(label: "No Data", score: nil)
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }
}
