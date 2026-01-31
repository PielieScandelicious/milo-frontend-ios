//
//  AIBudgetOnboardingViews.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
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

/// A badge showing the confidence level of AI suggestions
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
        case .low: return "Scan receipts for personalized insights"
        }
    }
}

// MARK: - AI Budget Onboarding Card

/// A welcoming card for users with no spending data
struct AIBudgetOnboardingCard: View {
    let suggestion: AIBudgetSuggestionResponse
    let onScanReceipt: () -> Void
    @State private var animateGlow = false

    var body: some View {
        VStack(spacing: 24) {
            // Welcome header
            welcomeHeader

            // Progress indicator
            DataCollectionProgressRing(
                monthsCollected: suggestion.basedOnMonths,
                targetMonths: 3,
                size: 100
            )

            // Suggested budget (muted styling)
            suggestedBudgetSection

            // Personalized tips
            tipsSection

            // Call to action
            scanReceiptButton
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.1, blue: 0.18),
                            Color(red: 0.08, green: 0.06, blue: 0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 1, dash: [8, 4])
                )
        )
    }

    private var welcomeHeader: some View {
        VStack(spacing: 8) {
            // Sparkle icon with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 0.6, green: 0.4, blue: 1.0).opacity(animateGlow ? 0.3 : 0.15),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    animateGlow = true
                }
            }

            Text("Welcome to Smart Budgeting")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("Let's build your personalized budget together")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var suggestedBudgetSection: some View {
        VStack(spacing: 12) {
            // Label
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.8))

                Text("Suggested Starting Point")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            // Amount with muted styling
            Text(String(format: "€%.0f", suggestion.recommendedBudget.amount))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))

            // Confidence badge
            ConfidenceBadge(confidence: suggestion.recommendedBudget.confidence, style: .compact)

            // Reasoning
            Text(suggestion.recommendedBudget.reasoning)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 8)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [6, 4]))
                )
        )
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "checklist")
                    .font(.system(size: 14))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))

                Text("Get Started")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestion.personalizedTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Text(tipEmoji(from: tip))
                            .font(.system(size: 16))

                        Text(tipText(from: tip))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.08))
        )
    }

    private var scanReceiptButton: some View {
        Button(action: onScanReceipt) {
            HStack(spacing: 10) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text("Scan Your First Receipt")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.7, blue: 1.0),
                        Color(red: 0.25, green: 0.6, blue: 0.95)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.4), radius: 12, y: 4)
        }
    }

    // Helper to extract emoji from tip string
    private func tipEmoji(from tip: String) -> String {
        let firstChar = tip.first ?? Character(" ")
        if firstChar.unicodeScalars.first?.properties.isEmoji == true {
            return String(firstChar)
        }
        return "•"
    }

    // Helper to extract text from tip string (removes leading emoji)
    private func tipText(from tip: String) -> String {
        let firstChar = tip.first ?? Character(" ")
        if firstChar.unicodeScalars.first?.properties.isEmoji == true {
            return String(tip.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        return tip
    }
}

// MARK: - AI Budget Building Profile Card

/// A card for users with partial data (1-2 months)
struct AIBudgetBuildingProfileCard: View {
    let suggestion: AIBudgetSuggestionResponse
    @State private var showAllInsights = false

    var body: some View {
        VStack(spacing: 20) {
            // Header with progress
            headerSection

            // Budget with confidence
            budgetSection

            // Category allocations with muted styling for low confidence items
            if !suggestion.categoryAllocations.isEmpty {
                categorySection
            }

            // Insights preview
            if !suggestion.spendingInsights.isEmpty {
                insightsPreviewSection
            }

            // Tips for more data
            moreDataTipsSection
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.1))
        )
    }

    private var headerSection: some View {
        HStack(spacing: 16) {
            // Progress ring
            DataCollectionProgressRing(
                monthsCollected: suggestion.basedOnMonths,
                targetMonths: 3,
                size: 64,
                showLabel: false
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("Building Your Profile")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(suggestion.dataBasisDescription)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                // Progress text
                Text("\(3 - suggestion.basedOnMonths) more month\(suggestion.basedOnMonths == 2 ? "" : "s") for full personalization")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.95))
            }

            Spacer()
        }
    }

    private var budgetSection: some View {
        VStack(spacing: 12) {
            // Amount
            Text(String(format: "€%.0f", suggestion.recommendedBudget.amount))
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            // Confidence badge
            ConfidenceBadge(confidence: suggestion.recommendedBudget.confidence, style: .prominent)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category Allocations")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                Text("Preliminary")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.05))
                    )
            }

            // Show top categories with muted styling
            ForEach(suggestion.categoryAllocations.prefix(4)) { allocation in
                partialDataCategoryRow(allocation)
            }
        }
    }

    private func partialDataCategoryRow(_ allocation: AICategoryAllocation) -> some View {
        HStack(spacing: 12) {
            // Category color dot
            Circle()
                .fill(allocation.category.categoryColor.opacity(0.6))
                .frame(width: 10, height: 10)

            Text(allocation.category)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Text(String(format: "€%.0f", allocation.suggestedAmount))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.vertical, 6)
    }

    private var insightsPreviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Early Insights")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            // Show first insight
            if let insight = suggestion.spendingInsights.first {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: insight.typeIcon)
                        .font(.system(size: 16))
                        .foregroundColor(insight.typeColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(insight.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)

                        Text(insight.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(insight.typeColor.opacity(0.1))
                )
            }
        }
    }

    private var moreDataTipsSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16))
                .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.95))

            Text("Keep scanning receipts for more accurate insights!")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.1))
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        ScrollView {
            VStack(spacing: 24) {
                // Progress rings
                Text("Progress Rings")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack(spacing: 24) {
                    DataCollectionProgressRing(monthsCollected: 0, targetMonths: 3, size: 60)
                    DataCollectionProgressRing(monthsCollected: 1, targetMonths: 3, size: 60)
                    DataCollectionProgressRing(monthsCollected: 2, targetMonths: 3, size: 60)
                    DataCollectionProgressRing(monthsCollected: 3, targetMonths: 3, size: 60)
                }

                // Confidence badges
                Text("Confidence Badges")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        ConfidenceBadge(confidence: "low", style: .default)
                        ConfidenceBadge(confidence: "medium", style: .default)
                        ConfidenceBadge(confidence: "high", style: .default)
                    }

                    HStack(spacing: 12) {
                        ConfidenceBadge(confidence: "low", style: .compact)
                        ConfidenceBadge(confidence: "medium", style: .compact)
                        ConfidenceBadge(confidence: "high", style: .compact)
                    }

                    ConfidenceBadge(confidence: "low", style: .prominent)
                }
            }
            .padding()
        }
    }
}
