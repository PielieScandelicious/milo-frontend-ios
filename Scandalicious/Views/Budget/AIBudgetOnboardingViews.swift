//
//  AIBudgetOnboardingViews.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//  Simplified on 05/02/2026 - AI features removed
//

import SwiftUI

// MARK: - Data Collection Progress Ring

/// A circular progress indicator showing months of data collected towards personalization
struct DataCollectionProgressRing: View {
    let monthsCollected: Int
    let targetMonths: Int
    var size: CGFloat = 80
    var showLabel: Bool = true

    @State private var animationProgress: CGFloat = 0

    private var progress: CGFloat {
        CGFloat(monthsCollected) / CGFloat(targetMonths)
    }

    private var progressColor: Color {
        switch monthsCollected {
        case 0:
            return Color(red: 0.5, green: 0.5, blue: 0.55)  // Muted gray
        case 1:
            return Color(red: 0.3, green: 0.7, blue: 1.0)   // Blue
        case 2:
            return Color(red: 0.55, green: 0.35, blue: 0.95) // Purple
        default:
            return Color(red: 0.3, green: 0.8, blue: 0.5)    // Green
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: size * 0.12)
                    .frame(width: size, height: size)

                // Progress ring
                Circle()
                    .trim(from: 0, to: progress * animationProgress)
                    .stroke(
                        progressColor,
                        style: StrokeStyle(
                            lineWidth: size * 0.12,
                            lineCap: .round
                        )
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(-90))

                // Center content
                VStack(spacing: 2) {
                    Text("\(monthsCollected)")
                        .font(.system(size: size * 0.28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("of \(targetMonths)")
                        .font(.system(size: size * 0.14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            if showLabel {
                Text(monthsCollected == 1 ? "month" : "months")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Confidence Badge

/// A badge showing the confidence level of suggestions
struct ConfidenceBadge: View {
    let confidence: String
    var style: BadgeStyle = .default

    enum BadgeStyle {
        case `default`
        case compact
        case prominent
    }

    private var confidenceLevel: ConfidenceLevel {
        switch confidence.lowercased() {
        case "high": return .high
        case "medium": return .medium
        default: return .low
        }
    }

    private enum ConfidenceLevel {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return Color(red: 0.3, green: 0.8, blue: 0.5)
            case .medium: return Color(red: 1.0, green: 0.75, blue: 0.3)
            case .low: return Color(red: 0.5, green: 0.5, blue: 0.55)
            }
        }

        var icon: String {
            switch self {
            case .high: return "checkmark.seal.fill"
            case .medium: return "seal.fill"
            case .low: return "questionmark.circle"
            }
        }

        var label: String {
            switch self {
            case .high: return "High confidence"
            case .medium: return "Medium confidence"
            case .low: return "Preliminary estimate"
            }
        }
    }

    var body: some View {
        Group {
            switch style {
            case .default:
                defaultBadge
            case .compact:
                compactBadge
            case .prominent:
                prominentBadge
            }
        }
    }

    private var defaultBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: confidenceLevel.icon)
                .font(.system(size: 12))
            Text(confidenceLevel.label)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(confidenceLevel.color)
    }

    private var compactBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceLevel.icon)
                .font(.system(size: 10))
            Text(confidence.capitalized)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(confidenceLevel.color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(confidenceLevel.color.opacity(0.15))
        )
    }

    private var prominentBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: confidenceLevel.icon)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text(confidence.capitalized + " Confidence")
                    .font(.system(size: 14, weight: .semibold))
                Text(confidenceDescription)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .foregroundColor(confidenceLevel.color)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(confidenceLevel.color.opacity(0.1))
        )
    }

    private var confidenceDescription: String {
        switch confidenceLevel {
        case .high: return "Based on consistent spending patterns"
        case .medium: return "More data will improve accuracy"
        case .low: return "Scan receipts for better accuracy"
        }
    }
}

// MARK: - AI Views Removed

// The following AI-powered views have been removed as part of the
// transition to deterministic, rule-based budget insights:
//
// - AIBudgetOnboardingCard
// - AIBudgetBuildingProfileCard
//
// Use the new BudgetInsights feature for non-AI insights.
