//
//  AIBudgetViews.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - AI Check-In Card

/// A card displayed on the overview showing weekly AI budget check-in
struct AICheckInCard: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.aiCheckInState {
            case .idle:
                loadCheckInButton

            case .loading:
                loadingView

            case .loaded(let checkIn):
                checkInContent(checkIn)

            case .error(let message):
                errorView(message)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.15, green: 0.12, blue: 0.25),
                            Color(red: 0.1, green: 0.08, blue: 0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private var loadCheckInButton: some View {
        Button(action: {
            Task {
                await viewModel.loadAICheckIn()
            }
        }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)

                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.purple)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Milo Budget Coach")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Get your personalized check-in")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.purple)

            Text("Getting your AI insights...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
        .padding(16)
    }

    private func checkInContent(_ checkIn: AICheckInResponse) -> some View {
        VStack(spacing: 0) {
            // Header (always visible)
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Emoji status
                    Text(checkIn.statusSummary.emoji)
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(checkIn.statusSummary.headline)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text(checkIn.statusSummary.detail)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(isExpanded ? nil : 1)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())

            // Expanded content
            if isExpanded {
                expandedCheckInContent(checkIn)
            }
        }
    }

    private func expandedCheckInContent(_ checkIn: AICheckInResponse) -> some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))

            // Daily budget remaining
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Daily Budget")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text(String(format: "€%.0f", checkIn.dailyBudgetRemaining))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Projection
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Projected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Text(String(format: "€%.0f", checkIn.projectedEndOfMonth.amount))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(checkIn.projectedEndOfMonth.statusColor)
                }
            }
            .padding(.horizontal, 16)

            // Focus areas
            if !checkIn.focusAreas.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus Areas")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ForEach(checkIn.focusAreas) { area in
                        HStack(spacing: 10) {
                            Image(systemName: area.statusIcon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(area.statusColor)

                            Text(area.category)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)

                            Spacer()

                            Text(area.message)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .lineLimit(1)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(area.statusColor.opacity(0.1))
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            // Weekly tip
            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)

                Text(checkIn.weeklyTip)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.1))
            )
            .padding(.horizontal, 16)

            // Motivation
            Text(checkIn.motivation)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
    }

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            Text("Couldn't load AI insights")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.7))

            Spacer()

            Button("Retry") {
                Task {
                    await viewModel.loadAICheckIn()
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.purple)
        }
        .padding(16)
    }
}

// MARK: - AI Receipt Feedback Overlay

/// Shown after scanning a receipt to provide AI budget feedback
struct AIReceiptFeedbackView: View {
    let analysis: AIReceiptAnalysisResponse
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(analysis.emoji)
                    .font(.system(size: 40))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Budget Impact")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(analysis.impactSummary)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Notable items
            if !analysis.notableItems.isEmpty {
                VStack(spacing: 8) {
                    ForEach(analysis.notableItems) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(analysis.statusColor)
                                .frame(width: 6, height: 6)

                            Text(item.item)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Text("•")
                                .foregroundColor(.white.opacity(0.3))

                            Text(item.observation)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            Spacer()
                        }
                    }
                }
            }

            // Quick tip
            if let tip = analysis.quickTip {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundColor(.purple)

                    Text(tip)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.purple.opacity(0.15))
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(analysis.statusColor.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

// MARK: - AI Suggestion View (for Budget Setup)

/// Shows AI-powered budget suggestion during setup - adapts based on data collection phase
struct AISuggestionView: View {
    let suggestion: AIBudgetSuggestionResponse
    @Binding var selectedAmount: Double
    @State private var expandedOpportunityIds = Set<String>()

    private var isPartialData: Bool {
        suggestion.dataCollectionPhase != .fullyPersonalized
    }

    private var isPreliminary: Bool {
        suggestion.isPreliminaryData
    }

    var body: some View {
        VStack(spacing: 20) {
            // Data collection progress (if not fully personalized)
            if isPartialData {
                dataCollectionProgressSection
            }

            // Health score (muted for partial data)
            healthScoreRing

            // Recommended budget
            recommendedBudgetSection

            // Savings opportunities (only show if has real data)
            if !suggestion.aiAnalysis.savingsOpportunities.isEmpty && !isPreliminary {
                savingsOpportunitiesSection
            }

            // Insights (only show if has real data)
            if !suggestion.aiAnalysis.spendingInsights.isEmpty && !isPreliminary {
                insightsSection
            }

            // Personalized tips (always show - backend provides appropriate tips)
            if !suggestion.aiAnalysis.personalizedTips.isEmpty {
                tipsSection
            }
        }
    }

    private var dataCollectionProgressSection: some View {
        HStack(spacing: 16) {
            DataCollectionProgressRing(
                monthsCollected: suggestion.basedOnMonths,
                targetMonths: 3,
                size: 56,
                showLabel: false
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.dataCollectionPhase.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(suggestion.dataCollectionPhase.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.12),
                            Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var healthScoreRing: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(suggestion.aiAnalysis.budgetHealthScore) / 100)
                    .stroke(
                        healthScoreColor.opacity(isPreliminary ? 0.5 : 1.0),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(suggestion.aiAnalysis.budgetHealthScore)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(isPreliminary ? 0.6 : 1.0))
            }

            HStack(spacing: 4) {
                Text("Budget Health Score")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                if isPreliminary {
                    Text("(Preliminary)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.3))
                }
            }
        }
    }

    private var healthScoreColor: Color {
        let score = suggestion.aiAnalysis.budgetHealthScore
        if score >= 80 {
            return Color(red: 0.3, green: 0.8, blue: 0.5)
        } else if score >= 60 {
            return Color(red: 0.3, green: 0.7, blue: 1.0)
        } else if score >= 40 {
            return Color(red: 1.0, green: 0.75, blue: 0.3)
        } else {
            return Color(red: 1.0, green: 0.4, blue: 0.4)
        }
    }

    private var recommendedBudgetSection: some View {
        VStack(spacing: 12) {
            // Label changes based on data state
            Text(isPreliminary ? "Suggested Starting Point" : "Milo's Recommended Budget")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)

            Text(String(format: "€%.0f", suggestion.aiAnalysis.recommendedBudget.amount))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(isPreliminary ? 0.7 : 1.0))

            // Use the new ConfidenceBadge component
            ConfidenceBadge(
                confidence: suggestion.aiAnalysis.recommendedBudget.confidence,
                style: isPartialData ? .prominent : .default
            )

            Text(suggestion.aiAnalysis.recommendedBudget.reasoning)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(isPreliminary ? 0.5 : 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    private var confidenceIcon: String {
        switch suggestion.aiAnalysis.recommendedBudget.confidence {
        case "high": return "checkmark.seal.fill"
        case "medium": return "seal.fill"
        default: return "questionmark.circle"
        }
    }

    private var confidenceColor: Color {
        switch suggestion.aiAnalysis.recommendedBudget.confidence {
        case "high": return Color(red: 0.3, green: 0.8, blue: 0.5)
        case "medium": return Color(red: 1.0, green: 0.75, blue: 0.3)
        default: return Color.white.opacity(0.5)
        }
    }

    private var savingsOpportunitiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Savings Opportunities")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if isPartialData {
                    Text("Early insight")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.white.opacity(0.05)))
                }
            }

            ForEach(suggestion.aiAnalysis.savingsOpportunities.prefix(3)) { opportunity in
                let isExpanded = expandedOpportunityIds.contains(opportunity.id)

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: opportunity.difficultyIcon)
                        .font(.system(size: 16))
                        .foregroundColor(opportunity.difficultyColor.opacity(isPartialData ? 0.7 : 1.0))
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(opportunity.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(isPartialData ? 0.8 : 1.0))

                        Text(opportunity.description)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(isPartialData ? 0.4 : 0.5))
                            .lineLimit(isExpanded ? nil : 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "€%.0f/mo", opportunity.potentialSavings))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(isPartialData ? 0.7 : 1.0))

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            isPartialData ?
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.03), style: StrokeStyle(lineWidth: 1, dash: [4, 3])) :
                            nil
                        )
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedOpportunityIds.remove(opportunity.id)
                        } else {
                            expandedOpportunityIds.insert(opportunity.id)
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(isPartialData ? "Early Insights" : "Spending Insights")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if isPartialData {
                    Text("More coming soon")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            ForEach(suggestion.aiAnalysis.spendingInsights.prefix(isPartialData ? 1 : 2)) { insight in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: insight.typeIcon)
                        .font(.system(size: 18))
                        .foregroundColor(insight.typeColor.opacity(isPartialData ? 0.7 : 1.0))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(insight.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(isPartialData ? 0.8 : 1.0))

                        Text(insight.description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(isPartialData ? 0.5 : 0.6))
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(insight.typeColor.opacity(isPartialData ? 0.07 : 0.1))
                        .overlay(
                            isPartialData ?
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(insight.typeColor.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 3])) :
                            nil
                        )
                )
            }
        }
    }

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: isPreliminary ? "checklist" : "sparkles")
                    .foregroundColor(isPreliminary ? Color(red: 0.3, green: 0.7, blue: 1.0) : .purple)
                Text(isPreliminary ? "Get Started" : "Milo's Tips for You")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            ForEach(suggestion.aiAnalysis.personalizedTips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    // Extract emoji if present, otherwise use bullet
                    Text(tipEmoji(from: tip))
                        .font(.system(size: isPreliminary ? 16 : 14))
                        .foregroundColor(isPreliminary ? .white : .purple)
                    Text(tipText(from: tip))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill((isPreliminary ? Color(red: 0.3, green: 0.7, blue: 1.0) : Color.purple).opacity(0.1))
        )
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

// MARK: - AI Monthly Report View

/// Full-screen monthly report with AI analysis
struct AIMonthlyReportView: View {
    let report: AIMonthlyReportResponse
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Grade header
                        gradeHeader

                        // Wins and challenges
                        winsAndChallenges

                        // Category grades
                        categoryGradesSection

                        // Trends
                        trendsSection

                        // Next month focus
                        nextMonthSection

                        // Fun stats
                        if !report.funStats.isEmpty {
                            funStatsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Monthly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var gradeHeader: some View {
        VStack(spacing: 16) {
            // Big grade
            ZStack {
                Circle()
                    .fill(report.gradeColor.opacity(0.2))
                    .frame(width: 120, height: 120)

                Circle()
                    .stroke(report.gradeColor, lineWidth: 4)
                    .frame(width: 120, height: 120)

                Text(report.grade)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(report.gradeColor)
            }

            Text(report.headline)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            // Score bar
            VStack(spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(report.gradeColor)
                            .frame(width: geometry.size.width * CGFloat(report.score) / 100)
                    }
                }
                .frame(height: 8)

                Text("Score: \(report.score)/100")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.vertical, 20)
    }

    private var winsAndChallenges: some View {
        HStack(alignment: .top, spacing: 12) {
            // Wins
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                    Text("Wins")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                ForEach(report.wins, id: \.self) { win in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))
                        Text(win)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.3, green: 0.8, blue: 0.5).opacity(0.1))
            )

            // Challenges
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill")
                        .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                    Text("Challenges")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }

                ForEach(report.challenges, id: \.self) { challenge in
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Color(red: 1.0, green: 0.75, blue: 0.3))
                        Text(challenge)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 1.0, green: 0.75, blue: 0.3).opacity(0.1))
            )
        }
    }

    private var categoryGradesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category Performance")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            ForEach(report.categoryGrades) { grade in
                HStack(spacing: 12) {
                    Text(grade.grade)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(grade.gradeColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(grade.category)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text(grade.comment)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "€%.0f", grade.spent))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        if let budget = grade.budget {
                            Text(String(format: "of €%.0f", budget))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
            }
        }
    }

    private var trendsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trends")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.7))

            ForEach(report.trends) { trend in
                HStack(spacing: 12) {
                    Image(systemName: trend.trendIcon)
                        .font(.system(size: 20))
                        .foregroundColor(trend.trendColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(trend.area)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)

                        Text(trend.detail)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(trend.trendColor.opacity(0.1))
                )
            }
        }
    }

    private var nextMonthSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .foregroundColor(.purple)
                Text("Next Month Focus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(report.nextMonthFocus.primaryGoal)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                if let adjustment = report.nextMonthFocus.suggestedBudgetAdjustment {
                    HStack(spacing: 6) {
                        Image(systemName: adjustment > 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundColor(adjustment > 0 ? Color(red: 1.0, green: 0.75, blue: 0.3) : Color(red: 0.3, green: 0.8, blue: 0.5))

                        Text("Suggested budget adjustment: \(adjustment > 0 ? "+" : "")€\(Int(adjustment))")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Text(report.nextMonthFocus.reason)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.purple.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.purple.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var funStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Fun Stats")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            ForEach(report.funStats, id: \.self) { stat in
                HStack(spacing: 8) {
                    Text("🎉")
                    Text(stat)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.yellow.opacity(0.1))
        )
    }
}

// MARK: - AI Insight Sheet View

/// A clean popup sheet showing detailed AI budget insights
struct AIInsightSheetView: View {
    let checkIn: AICheckInResponse

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Drag indicator
                    Capsule()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)

                    // Header with emoji and summary
                    headerSection

                    // Stats row
                    statsSection

                    // Focus areas
                    if !checkIn.focusAreas.isEmpty {
                        focusAreasSection
                    }

                    // Weekly tip
                    weeklyTipSection

                    // Motivation
                    motivationSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(checkIn.statusSummary.emoji)
                .font(.system(size: 56))

            Text(checkIn.statusSummary.headline)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(checkIn.statusSummary.detail)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
    }

    private var statsSection: some View {
        HStack(spacing: 16) {
            // Daily budget
            VStack(spacing: 6) {
                Text(String(format: "€%.0f", checkIn.dailyBudgetRemaining))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text("Daily Budget")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )

            // Projected
            VStack(spacing: 6) {
                Text(String(format: "€%.0f", checkIn.projectedEndOfMonth.amount))
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(checkIn.projectedEndOfMonth.statusColor)

                Text("Projected")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
            )
        }
    }

    private var focusAreasSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Focus Areas")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(checkIn.focusAreas) { area in
                HStack(spacing: 12) {
                    Image(systemName: area.statusIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(area.statusColor)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(area.category)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)

                        Text(area.message)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(area.statusColor.opacity(0.1))
                )
            }
        }
    }

    private var weeklyTipSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)

                Text("Weekly Tip")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
            }

            Text(checkIn.weeklyTip)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.1))
        )
    }

    private var motivationSection: some View {
        Text(checkIn.motivation)
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.top, 8)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 20) {
            AICheckInCard(viewModel: BudgetViewModel())
                .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}
