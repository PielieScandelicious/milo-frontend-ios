//
//  BudgetInsightCard.swift
//  Scandalicious
//
//  A unified, sleek budget insight card for the Overview tab
//  Shows current progress for current month, final results for past months
//

import SwiftUI

// MARK: - Budget Insight Card

struct BudgetInsightCard: View {
    @ObservedObject var viewModel: BudgetViewModel
    let period: String
    let isCurrentPeriod: Bool

    @State private var isExpanded = false
    @State private var showDetailSheet = false
    @State private var animationProgress: CGFloat = 0

    // Date formatter for display
    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                loadingCard

            case .noBudget:
                noBudgetCard

            case .active(let progress):
                if isCurrentPeriod {
                    currentMonthCard(progress: progress)
                } else {
                    pastMonthCard(progress: progress)
                }

            case .error:
                EmptyView()
            }
        }
        .sheet(isPresented: $showDetailSheet) {
            if let progress = viewModel.state.progress {
                BudgetDetailSheet(
                    progress: progress,
                    viewModel: viewModel,
                    isCurrentPeriod: isCurrentPeriod
                )
            }
        }
    }

    // MARK: - Loading Card

    private var loadingCard: some View {
        HStack(spacing: 12) {
            // Placeholder ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: 3)
                .frame(width: 40, height: 40)
                .overlay(
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white.opacity(0.4))
                )

            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100, height: 14)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 140, height: 10)
            }

            Spacer()
        }
        .padding(14)
        .background(cardBackground)
    }

    // MARK: - No Budget Card

    private var noBudgetCard: some View {
        Button {
            viewModel.startSetup()
        } label: {
            HStack(spacing: 12) {
                // Add icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Budget")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Track your spending goals")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(14)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Current Month Card

    private func currentMonthCard(progress: BudgetProgress) -> some View {
        VStack(spacing: 0) {
            // Main card content
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 14) {
                    // Animated progress ring
                    CurrentMonthRing(
                        progress: progress,
                        size: 48,
                        animationProgress: animationProgress
                    )

                    // Progress info
                    VStack(alignment: .leading, spacing: 4) {
                        // Spend vs budget
                        HStack(spacing: 4) {
                            Text(String(format: "€%.0f", progress.currentSpend))
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text("/")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.3))

                            Text(String(format: "€%.0f", progress.budget.monthlyAmount))
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }

                        // Pace status with days
                        HStack(spacing: 6) {
                            HStack(spacing: 3) {
                                Image(systemName: progress.paceStatus.icon)
                                    .font(.system(size: 10, weight: .bold))
                                Text(progress.paceStatus.displayText)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(progress.paceStatus.color)

                            Circle()
                                .fill(Color.white.opacity(0.2))
                                .frame(width: 3, height: 3)

                            Text("\(progress.daysRemaining)d left")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    Spacer()

                    // Daily budget badge
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "€%.0f", progress.dailyBudgetRemaining))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("/day")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.06))
                    )

                    // Expand indicator
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                expandedCurrentMonthContent(progress: progress)
            }
        }
        .background(cardBackground)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animationProgress = 1.0
            }
        }
    }

    private func expandedCurrentMonthContent(progress: BudgetProgress) -> some View {
        VStack(spacing: 12) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            // Progress bar with time marker
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 8)

                        // Spent progress
                        RoundedRectangle(cornerRadius: 4)
                            .fill(progressGradient(for: progress.spendRatio))
                            .frame(width: geo.size.width * min(1.0, progress.spendRatio), height: 8)

                        // Time marker (expected position)
                        let expectedPosition = geo.size.width * progress.expectedSpendRatio
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: 14)
                            .offset(x: expectedPosition - 1, y: -3)
                    }
                }
                .frame(height: 8)

                // Labels
                HStack {
                    Text("Day \(progress.daysElapsed)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()

                    Text("Projected: \(String(format: "€%.0f", progress.projectedEndOfMonth))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(progress.projectedOverUnder > 0 ? .orange : .green)
                }
            }
            .padding(.horizontal, 14)

            // Quick stats
            HStack(spacing: 0) {
                quickStat(
                    label: "Remaining",
                    value: String(format: "€%.0f", progress.remainingBudget),
                    color: progress.remainingBudget > 0 ? Color(red: 0.3, green: 0.8, blue: 0.5) : .red
                )

                quickStat(
                    label: "Avg/Day",
                    value: String(format: "€%.0f", progress.currentSpend / Double(max(1, progress.daysElapsed))),
                    color: .white
                )

                quickStat(
                    label: "Projected",
                    value: String(format: "€%.0f", progress.projectedEndOfMonth),
                    color: progress.projectedOverUnder > 0 ? .orange : Color(red: 0.3, green: 0.8, blue: 0.5)
                )
            }
            .padding(.bottom, 10)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Past Month Card

    @ViewBuilder
    private func pastMonthCard(progress: BudgetProgress) -> some View {
        let wasUnderBudget = progress.currentSpend <= progress.budget.monthlyAmount
        let difference = abs(progress.budget.monthlyAmount - progress.currentSpend)
        let grade = calculateGrade(for: progress)

        Button {
            showDetailSheet = true
        } label: {
            HStack(spacing: 14) {
                // Result icon
                ZStack {
                    Circle()
                        .fill(
                            wasUnderBudget
                                ? LinearGradient(
                                    colors: [Color(red: 0.2, green: 0.8, blue: 0.5).opacity(0.3), Color(red: 0.3, green: 0.9, blue: 0.6).opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.orange.opacity(0.3), Color.red.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                        )
                        .frame(width: 48, height: 48)

                    Image(systemName: wasUnderBudget ? "checkmark.seal.fill" : "chart.bar.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(
                            wasUnderBudget
                                ? Color(red: 0.3, green: 0.9, blue: 0.5)
                                : Color.orange
                        )
                }

                // Result info
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(wasUnderBudget ? "Budget Achieved" : "Budget Review")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)

                    // Summary
                    HStack(spacing: 4) {
                        Text(String(format: "€%.0f", progress.currentSpend))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))

                        Text("of")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text(String(format: "€%.0f", progress.budget.monthlyAmount))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))

                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 3, height: 3)

                        Text(String(format: "€%.0f %@", difference, wasUnderBudget ? "saved" : "over"))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(wasUnderBudget ? Color(red: 0.3, green: 0.9, blue: 0.5) : .orange)
                    }
                }

                Spacer()

                // Grade badge
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(grade.color.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Text(grade.letter)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(grade.color)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(14)
            .background(cardBackground)
        }
        .buttonStyle(BudgetCardButtonStyle())
    }

    // MARK: - Helper Views & Functions

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    private func quickStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
    }

    private func progressGradient(for ratio: Double) -> LinearGradient {
        if ratio <= 0.5 {
            return LinearGradient(
                colors: [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.3, green: 0.85, blue: 0.5)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if ratio <= 0.8 {
            return LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private func calculateGrade(for progress: BudgetProgress) -> (letter: String, color: Color) {
        let ratio = progress.spendRatio

        switch ratio {
        case ..<0.85:
            return ("A", Color(red: 0.3, green: 0.9, blue: 0.5))
        case 0.85..<0.95:
            return ("B", Color(red: 0.4, green: 0.8, blue: 0.5))
        case 0.95..<1.05:
            return ("C", Color(red: 0.9, green: 0.75, blue: 0.3))
        case 1.05..<1.15:
            return ("D", Color.orange)
        default:
            return ("F", Color.red)
        }
    }
}

// MARK: - Current Month Ring

private struct CurrentMonthRing: View {
    let progress: BudgetProgress
    let size: CGFloat
    let animationProgress: CGFloat

    private var ringColor: Color {
        let ratio = progress.spendRatio
        if ratio <= 0.5 {
            return Color(red: 0.3, green: 0.85, blue: 0.5)
        } else if ratio <= 0.75 {
            return Color(red: 0.9, green: 0.75, blue: 0.3)
        } else if ratio <= 1.0 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.12)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(1.0, progress.spendRatio) * animationProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))

            // Percentage text
            Text("\(Int(progress.spendRatio * 100))%")
                .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Budget Card Button Style

private struct BudgetCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Budget Detail Sheet

private struct BudgetDetailSheet: View {
    let progress: BudgetProgress
    @ObservedObject var viewModel: BudgetViewModel
    let isCurrentPeriod: Bool
    @Environment(\.dismiss) private var dismiss

    private var wasUnderBudget: Bool {
        progress.currentSpend <= progress.budget.monthlyAmount
    }

    private var difference: Double {
        abs(progress.budget.monthlyAmount - progress.currentSpend)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero section
                        heroSection

                        // Stats cards
                        statsSection

                        // Category breakdown
                        if !progress.categoryProgress.isEmpty {
                            categorySection
                        }

                        // AI Report button
                        aiReportButton
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(isCurrentPeriod ? "This Month" : "Budget Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var heroSection: some View {
        VStack(spacing: 20) {
            // Large progress ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 16)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: min(1.0, progress.spendRatio))
                    .stroke(
                        ringGradient,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 4) {
                    Text(String(format: "€%.0f", progress.currentSpend))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("of €\(Int(progress.budget.monthlyAmount))")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            // Result badge
            HStack(spacing: 8) {
                Image(systemName: wasUnderBudget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))

                Text(String(format: "€%.0f %@", difference, wasUnderBudget ? "under budget" : "over budget"))
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(wasUnderBudget ? Color(red: 0.3, green: 0.9, blue: 0.5) : .orange)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill((wasUnderBudget ? Color(red: 0.3, green: 0.9, blue: 0.5) : Color.orange).opacity(0.15))
            )
        }
        .padding(.top, 20)
    }

    private var ringGradient: LinearGradient {
        let ratio = progress.spendRatio
        if ratio <= 0.7 {
            return LinearGradient(
                colors: [Color(red: 0.3, green: 0.85, blue: 0.5), Color(red: 0.4, green: 0.9, blue: 0.6)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if ratio <= 1.0 {
            return LinearGradient(
                colors: [Color.yellow, Color.orange],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            return LinearGradient(
                colors: [Color.orange, Color.red],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "calendar",
                value: isCurrentPeriod ? "\(progress.daysRemaining)" : "\(progress.daysInMonth)",
                label: isCurrentPeriod ? "Days Left" : "Days"
            )

            statCard(
                icon: "chart.line.uptrend.xyaxis",
                value: String(format: "€%.0f", progress.currentSpend / Double(max(1, progress.daysElapsed))),
                label: "Avg/Day"
            )

            statCard(
                icon: isCurrentPeriod ? "arrow.right.circle" : "target",
                value: isCurrentPeriod ? String(format: "€%.0f", progress.projectedEndOfMonth) : String(format: "€%.0f", progress.budget.monthlyAmount),
                label: isCurrentPeriod ? "Projected" : "Budget"
            )
        }
    }

    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.4))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))

                Text("Categories")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)

                Spacer()
            }

            ForEach(progress.categoryProgress.prefix(5), id: \.category) { category in
                categoryRow(category)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func categoryRow(_ category: CategoryBudgetProgress) -> some View {
        HStack(spacing: 12) {
            // Category icon
            ZStack {
                Circle()
                    .fill(categoryColor(for: category).opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(categoryColor(for: category))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.category)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(categoryColor(for: category))
                            .frame(width: geo.size.width * min(1.0, category.spendRatio), height: 4)
                    }
                }
                .frame(height: 4)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "€%.0f", category.currentSpend))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(String(format: "/ €%.0f", category.budgetAmount))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private func categoryColor(for category: CategoryBudgetProgress) -> Color {
        if category.spendRatio <= 0.7 {
            return Color(red: 0.3, green: 0.85, blue: 0.5)
        } else if category.spendRatio <= 1.0 {
            return Color.orange
        } else {
            return Color.red
        }
    }

    private var aiReportButton: some View {
        Button {
            Task {
                await viewModel.loadAIMonthlyReport()
                viewModel.showingAIMonthlyReport = true
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))

                Text("View AI Analysis")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Current Month - On Track") {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 20) {
            BudgetInsightCard(
                viewModel: {
                    let vm = BudgetViewModel()
                    let budget = UserBudget(
                        id: "1",
                        userId: "user1",
                        monthlyAmount: 800,
                        categoryAllocations: nil,
                        notificationsEnabled: true,
                        alertThresholds: [0.5, 0.75, 0.9]
                    )
                    vm.state = .active(BudgetProgress(
                        budget: budget,
                        currentSpend: 420,
                        daysElapsed: 15,
                        daysInMonth: 31
                    ))
                    return vm
                }(),
                period: "February 2026",
                isCurrentPeriod: true
            )
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}

#Preview("Past Month - Under Budget") {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 20) {
            BudgetInsightCard(
                viewModel: {
                    let vm = BudgetViewModel()
                    let budget = UserBudget(
                        id: "1",
                        userId: "user1",
                        monthlyAmount: 800,
                        categoryAllocations: nil,
                        notificationsEnabled: true,
                        alertThresholds: [0.5, 0.75, 0.9]
                    )
                    vm.state = .active(BudgetProgress(
                        budget: budget,
                        currentSpend: 720,
                        daysElapsed: 31,
                        daysInMonth: 31
                    ))
                    return vm
                }(),
                period: "January 2026",
                isCurrentPeriod: false
            )
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}