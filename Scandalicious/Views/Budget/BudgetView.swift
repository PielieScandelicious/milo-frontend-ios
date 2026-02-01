//
//  BudgetView.swift
//  Scandalicious
//
//  Main budget management view for the Budget tab
//

import SwiftUI

struct BudgetView: View {
    @StateObject private var viewModel = BudgetViewModel()
    @State private var showingDeleteConfirmation = false
    @State private var selectedCategoryItem: BudgetProgressItem?
    @State private var showAllCategories = false
    @State private var showLastMonthSummary = false

    /// Maximum categories to show before grouping
    private let maxVisibleCategories = 6

    // Date formatter for display
    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// Check if the selected period is the current month
    private var isCurrentMonth: Bool {
        viewModel.selectedPeriod == displayFormatter.string(from: Date())
    }

    /// Shortened period format for adjacent periods (e.g., "Jan 26")
    private func shortenedPeriod(_ period: String) -> String {
        guard let date = displayFormatter.date(from: period) else { return period }
        let shortFormatter = DateFormatter()
        shortFormatter.dateFormat = "MMM yy"
        return shortFormatter.string(from: date)
    }

    /// Current period index in available periods
    private var currentPeriodIndex: Int {
        viewModel.availablePeriods.firstIndex(of: viewModel.selectedPeriod) ?? 0
    }

    /// Can navigate to previous (older) period
    private var canGoToPreviousPeriod: Bool {
        currentPeriodIndex > 0
    }

    /// Can navigate to next (newer) period
    private var canGoToNextPeriod: Bool {
        currentPeriodIndex < viewModel.availablePeriods.count - 1
    }

    var body: some View {
        ZStack {
            // Background
            Color(white: 0.05)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    switch viewModel.state {
                    case .idle, .loading:
                        loadingView
                    case .noBudget:
                        noBudgetView
                    case .active(let progress):
                        // Show fresh start view for new month with minimal spending
                        if viewModel.isNewMonthWithMinimalSpending {
                            freshStartView(progress: progress)
                        } else {
                            activeBudgetView(progress: progress)
                        }
                    case .error(let message):
                        errorView(message: message)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            // Period selector in center (replaces title)
            ToolbarItem(placement: .principal) {
                periodNavigationToolbar
            }

            if viewModel.state.hasBudget {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.startSetup()
                        } label: {
                            Label("Edit Budget", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete Budget", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingSetupSheet) {
            BudgetSetupView(viewModel: viewModel)
        }
        .sheet(item: $selectedCategoryItem) { item in
            CategoryBudgetDetailSheet(item: item)
        }
        .sheet(isPresented: $showLastMonthSummary) {
            if let summary = viewModel.lastMonthSummary {
                LastMonthDetailSheet(summary: summary, viewModel: viewModel)
            }
        }
        .confirmationDialog("Delete Budget", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task {
                    _ = await viewModel.deleteBudget()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your budget? This action cannot be undone.")
        }
        .task {
            await viewModel.loadBudget()
        }
        .gesture(periodSwipeGesture)
    }

    // MARK: - Period Navigation

    private var periodNavigationToolbar: some View {
        Group {
            // Only show toolbar when periods are loaded
            if !viewModel.selectedPeriod.isEmpty {
                periodNavigationContent
            }
        }
    }

    private var periodNavigationContent: some View {
        HStack(spacing: 12) {
            // Previous period (faded left)
            if canGoToPreviousPeriod {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        let newPeriod = viewModel.availablePeriods[currentPeriodIndex - 1]
                        Task {
                            await viewModel.selectPeriod(newPeriod)
                        }
                    }
                } label: {
                    Text(shortenedPeriod(viewModel.availablePeriods[currentPeriodIndex - 1]).uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.8)
                }
            }

            // Current period (center pill)
            HStack(spacing: 6) {
                // Show sparkle icon for fresh new month
                if viewModel.isNewMonthStart && isCurrentMonth {
                    Image(systemName: "sparkle")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue.opacity(0.9), .purple.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                Text(viewModel.selectedPeriod.uppercased())
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .tracking(1.5)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(viewModel.isNewMonthStart && isCurrentMonth
                        ? LinearGradient(
                            colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Capsule()
                    .stroke(
                        viewModel.isNewMonthStart && isCurrentMonth
                            ? LinearGradient(
                                colors: [Color.blue.opacity(0.4), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.2), Color.white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                        lineWidth: 1
                    )
            )
            .contentTransition(.interpolate)
            .animation(.easeInOut(duration: 0.25), value: viewModel.selectedPeriod)

            // Next period (faded right)
            if canGoToNextPeriod {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        let newPeriod = viewModel.availablePeriods[currentPeriodIndex + 1]
                        Task {
                            await viewModel.selectPeriod(newPeriod)
                        }
                    }
                } label: {
                    Text(shortenedPeriod(viewModel.availablePeriods[currentPeriodIndex + 1]).uppercased())
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                        .tracking(0.8)
                }
            }
        }
    }

    /// Swipe gesture for navigating between periods
    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 30, coordinateSpace: .local)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = abs(value.translation.height)

                // Require horizontal to be at least 2x vertical movement
                guard abs(horizontalAmount) > verticalAmount * 2 else { return }
                guard abs(horizontalAmount) > 50 else { return }

                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if horizontalAmount > 0 && canGoToPreviousPeriod {
                        // Swipe right -> go to previous (older) period
                        let newPeriod = viewModel.availablePeriods[currentPeriodIndex - 1]
                        Task {
                            await viewModel.selectPeriod(newPeriod)
                        }
                    } else if horizontalAmount < 0 && canGoToNextPeriod {
                        // Swipe left -> go to next (newer) period
                        let newPeriod = viewModel.availablePeriods[currentPeriodIndex + 1]
                        Task {
                            await viewModel.selectPeriod(newPeriod)
                        }
                    }
                }
            }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 100)

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.7)))
                .scaleEffect(1.3)

            Text("Loading budget...")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Spacer()
        }
    }

    // MARK: - Fresh Start View (New Month)

    private func freshStartView(progress: BudgetProgress) -> some View {
        VStack(spacing: 24) {
            // Fresh Start Hero
            VStack(spacing: 20) {
                // Animated sparkle icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(0.2),
                                    Color.purple.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)

                    Image(systemName: "sparkles")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text("Fresh Start!")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text("A new month begins. Your budget is ready.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top, 20)

            // Budget Target Card
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Month's Budget")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)

                        Text(String(format: "€%.0f", progress.budget.monthlyAmount))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Daily Target")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)

                        Text(String(format: "€%.0f", progress.dailyBudgetRemaining))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )

            // Last Month Summary Card (if available)
            if let summary = viewModel.lastMonthSummary {
                lastMonthSummaryCard(summary: summary)
            } else if viewModel.isLoadingLastMonth {
                // Loading state for last month
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))

                    Text("Loading last month...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }

            // Encouragement text
            VStack(spacing: 8) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green.opacity(0.8))

                Text("Start fresh and stay on track!")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(.top, 20)
        }
    }

    // MARK: - Last Month Summary Card

    private func lastMonthSummaryCard(summary: LastMonthSummary) -> some View {
        Button {
            showLastMonthSummary = true
        } label: {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("How did last month go?")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .textCase(.uppercase)

                        Text(summary.month)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Grade badge
                    ZStack {
                        Circle()
                            .fill(summary.gradeColor.opacity(0.15))
                            .frame(width: 50, height: 50)

                        Circle()
                            .stroke(summary.gradeColor, lineWidth: 2)
                            .frame(width: 50, height: 50)

                        Text(summary.grade)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(summary.gradeColor)
                    }
                }

                // Stats row
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spent")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(String(format: "€%.0f", summary.totalSpent))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Budget")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))

                        Text(String(format: "€%.0f", summary.budgetAmount))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    // Under/over badge
                    Text(summary.statusText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(summary.wasUnderBudget ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill((summary.wasUnderBudget ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color.red).opacity(0.15))
                        )
                }

                // Tap to see more
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Text("View Details")
                            .font(.system(size: 12, weight: .medium))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - No Budget View

    private var noBudgetView: some View {
        VStack(spacing: 32) {
            Spacer()
                .frame(height: 60)

            // Hero illustration
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.blue.opacity(0.2),
                                Color.purple.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 160)

                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 12)
                    .frame(width: 140, height: 140)

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            // Text content
            VStack(spacing: 12) {
                Text("Set Your Budget")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)

                Text("Take control of your spending with smart\ncategory-based budgeting powered by AI.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Features list
            VStack(spacing: 16) {
                featureRow(icon: "sparkles", title: "AI-Powered Suggestions", subtitle: "Personalized category allocations")
                featureRow(icon: "chart.bar.fill", title: "Track by Category", subtitle: "See where your money goes")
                featureRow(icon: "bell.fill", title: "Smart Alerts", subtitle: "Get notified before overspending")
            }
            .padding(.horizontal, 8)

            Spacer()
                .frame(height: 20)

            // CTA Button
            Button {
                viewModel.startSetup()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Create Budget")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.purple.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func featureRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - Active Budget View

    private func activeBudgetView(progress: BudgetProgress) -> some View {
        VStack(spacing: 20) {
            // Historical period banner (when viewing past months)
            if !isCurrentMonth {
                historicalPeriodBanner
            }

            // Main budget overview card
            mainBudgetCard(progress: progress)

            // Pace indicator (only show for current month)
            if isCurrentMonth {
                paceIndicatorCard(progress: progress)
            }

            // Last month summary (compact version for active view, only on current month)
            if isCurrentMonth, let summary = viewModel.lastMonthSummary {
                lastMonthCompactCard(summary: summary)
            }

            // Category breakdown
            categoryBreakdownSection

            // Quick stats
            quickStatsCard(progress: progress)
        }
    }

    // MARK: - Historical Period Banner

    private var historicalPeriodBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Text("Viewing \(viewModel.selectedPeriod)")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            // Jump to current month button
            Button {
                let currentMonth = displayFormatter.string(from: Date())
                Task {
                    await viewModel.selectPeriod(currentMonth)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Current")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(0.15))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Last Month Compact Card (for Active Budget View)

    private func lastMonthCompactCard(summary: LastMonthSummary) -> some View {
        Button {
            showLastMonthSummary = true
        } label: {
            HStack(spacing: 12) {
                // Grade badge
                ZStack {
                    Circle()
                        .fill(summary.gradeColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Text(summary.grade)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(summary.gradeColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Month")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(summary.statusText)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(summary.wasUnderBudget ? Color(red: 0.2, green: 0.8, blue: 0.4) : .red)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Budget Card

    private func mainBudgetCard(progress: BudgetProgress) -> some View {
        VStack(spacing: 20) {
            // Large progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 20)
                    .frame(width: 180, height: 180)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(1.0, progress.spendRatio))
                    .stroke(
                        progressGradient(for: progress.spendRatio),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8), value: progress.spendRatio)

                // Center content
                VStack(spacing: 4) {
                    Text(String(format: "€%.0f", progress.currentSpend))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("of €\(Int(progress.budget.monthlyAmount))")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("\(Int(progress.spendRatio * 100))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(progressColor(for: progress.spendRatio))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(progressColor(for: progress.spendRatio).opacity(0.15))
                        )
                }
            }
            .padding(.vertical, 10)

            // Remaining budget
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remaining")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(String(format: "€%.0f", progress.remainingBudget))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Daily Budget")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .textCase(.uppercase)

                    Text(String(format: "€%.0f/day", progress.dailyBudgetRemaining))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    // MARK: - Pace Indicator Card

    private func paceIndicatorCard(progress: BudgetProgress) -> some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(progress.paceStatus.color.opacity(0.15))
                    .frame(width: 50, height: 50)

                Image(systemName: progress.paceStatus.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(progress.paceStatus.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(progress.paceStatus.displayText)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(paceSubtitle(for: progress))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer()

            // Days remaining
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(progress.daysRemaining)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("days left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func paceSubtitle(for progress: BudgetProgress) -> String {
        let projected = progress.projectedEndOfMonth
        let budget = progress.budget.monthlyAmount

        if projected > budget {
            return String(format: "Projected €%.0f over budget", projected - budget)
        } else {
            return String(format: "Projected €%.0f under budget", budget - projected)
        }
    }

    // MARK: - Category Breakdown Section

    /// Whether categories need grouping
    private var needsCategoryGrouping: Bool {
        viewModel.budgetProgressItems.count > maxVisibleCategories
    }

    /// Categories to display - either all or limited with "Others" summary
    private var displayCategories: [BudgetProgressItem] {
        let items = viewModel.budgetProgressItems
        guard needsCategoryGrouping && !showAllCategories else { return items }

        // Sort by spent amount descending to keep largest categories visible
        let sortedItems = items.sorted { $0.spentAmount > $1.spentAmount }

        // Return first (maxVisibleCategories) items
        return Array(sortedItems.prefix(maxVisibleCategories))
    }

    /// Count of hidden categories
    private var hiddenCategoryCount: Int {
        max(0, viewModel.budgetProgressItems.count - maxVisibleCategories)
    }

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))

                Text("Budget by Category")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Category count badge
                if !viewModel.budgetProgressItems.isEmpty {
                    Text("\(viewModel.budgetProgressItems.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                        )
                }
            }
            .padding(.horizontal, 4)

            // Category grid - 3 pie charts per row
            if viewModel.budgetProgressItems.isEmpty {
                emptyCategoryState
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 20) {
                    ForEach(displayCategories) { item in
                        CategoryBudgetRingView(item: item)
                            .onTapGesture {
                                selectedCategoryItem = item
                            }
                    }
                }

                // Show All / Show Less button
                if needsCategoryGrouping {
                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            showAllCategories.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showAllCategories ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                .font(.system(size: 14, weight: .semibold))

                            Text(showAllCategories ? "Show Less" : "Show All \(viewModel.budgetProgressItems.count)")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.06))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
    }

    private var emptyCategoryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.3))

            Text("No category data yet")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Quick Stats Card

    private func quickStatsCard(progress: BudgetProgress) -> some View {
        HStack(spacing: 0) {
            statItem(
                value: "\(progress.daysElapsed)",
                label: "Days In",
                icon: "calendar"
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.1))

            statItem(
                value: String(format: "€%.0f", progress.currentSpend / Double(max(1, progress.daysElapsed))),
                label: "Avg/Day",
                icon: "chart.line.uptrend.xyaxis"
            )

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.1))

            statItem(
                value: String(format: "€%.0f", progress.projectedEndOfMonth),
                label: "Projected",
                icon: "arrow.right.circle"
            )
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
                .frame(height: 100)

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadBudget()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }

            Spacer()
        }
    }

    // MARK: - Helper Functions

    private func progressGradient(for ratio: Double) -> LinearGradient {
        let colors: [Color]
        if ratio <= 0.5 {
            colors = [Color(red: 0.2, green: 0.8, blue: 0.4), Color(red: 0.3, green: 0.85, blue: 0.5)]
        } else if ratio <= 0.75 {
            colors = [Color.yellow, Color.orange]
        } else if ratio <= 1.0 {
            colors = [Color.orange, Color.red]
        } else {
            colors = [Color.red, Color(red: 0.8, green: 0.2, blue: 0.2)]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    private func progressColor(for ratio: Double) -> Color {
        if ratio <= 0.5 {
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        } else if ratio <= 0.75 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Category Budget Ring View (Grid Item)

private struct CategoryBudgetRingView: View {
    let item: BudgetProgressItem

    @State private var animationProgress: CGFloat = 0

    private let ringSize: CGFloat = 70
    private let lineWidth: CGFloat = 8

    private var ringColor: Color {
        let ratio = item.progressRatio
        if ratio <= 0.5 {
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        } else if ratio <= 0.7 {
            let t = (ratio - 0.5) / 0.2
            return Color(
                red: 0.2 + 0.6 * t,
                green: 0.8,
                blue: 0.4 - 0.2 * t
            )
        } else if ratio <= 0.85 {
            let t = (ratio - 0.7) / 0.15
            return Color(
                red: 0.8 + 0.15 * t,
                green: 0.8 - 0.3 * t,
                blue: 0.2 - 0.1 * t
            )
        } else if ratio <= 1.0 {
            let t = (ratio - 0.85) / 0.15
            return Color(
                red: 0.95 + 0.05 * t,
                green: 0.5 - 0.2 * t,
                blue: 0.1
            )
        } else {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Pie chart ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
                    .frame(width: ringSize, height: ringSize)

                // Progress ring
                Circle()
                    .trim(from: 0, to: item.clampedProgress * animationProgress)
                    .stroke(
                        ringColor,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))

                // Center icon
                Image(systemName: item.icon)
                    .font(.system(size: ringSize * 0.3, weight: .semibold))
                    .foregroundStyle(ringColor)
            }

            // Category name
            Text(item.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: ringSize + 20)

            // Status text (remaining or over)
            Text(item.compactStatusText)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
        .onChange(of: item.spentAmount) { _, _ in
            animationProgress = 0
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Category Budget Detail Sheet

private struct CategoryBudgetDetailSheet: View {
    let item: BudgetProgressItem
    @Environment(\.dismiss) private var dismiss

    private var ringColor: Color {
        let ratio = item.progressRatio
        if ratio <= 0.5 {
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        } else if ratio <= 0.75 {
            return .orange
        } else {
            return .red
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                VStack(spacing: 32) {
                    // Large ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 16)
                            .frame(width: 160, height: 160)

                        Circle()
                            .trim(from: 0, to: item.clampedProgress)
                            .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                            .frame(width: 160, height: 160)
                            .rotationEffect(.degrees(-90))

                        VStack(spacing: 4) {
                            Image(systemName: item.icon)
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundStyle(ringColor)

                            Text("\(Int(item.progressRatio * 100))%")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.top, 20)

                    // Stats
                    VStack(spacing: 16) {
                        statRow(label: "Spent", value: String(format: "€%.2f", item.spentAmount))
                        Divider().background(Color.white.opacity(0.1))
                        statRow(label: "Budget", value: String(format: "€%.2f", item.limitAmount))
                        Divider().background(Color.white.opacity(0.1))
                        statRow(
                            label: item.isOverBudget ? "Over by" : "Remaining",
                            value: String(format: "€%.2f", item.isOverBudget ? item.overAmount : item.remainingAmount),
                            valueColor: item.isOverBudget ? .red : Color(red: 0.2, green: 0.8, blue: 0.4)
                        )
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                    )
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationTitle(item.name)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func statRow(label: String, value: String, valueColor: Color = .white) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
        }
    }
}

// MARK: - Last Month Detail Sheet

private struct LastMonthDetailSheet: View {
    let summary: LastMonthSummary
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Grade Hero
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(summary.gradeColor.opacity(0.15))
                                    .frame(width: 120, height: 120)

                                Circle()
                                    .stroke(summary.gradeColor, lineWidth: 4)
                                    .frame(width: 120, height: 120)

                                VStack(spacing: 4) {
                                    Text(summary.grade)
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(summary.gradeColor)

                                    Text("\(summary.score)/100")
                                        .font(.system(size: 14, weight: .medium, design: .rounded))
                                        .foregroundStyle(.white.opacity(0.5))
                                }
                            }

                            Text(summary.headline)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.top, 20)

                        // Spending Overview
                        VStack(spacing: 16) {
                            HStack {
                                Text("Spending Overview")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .textCase(.uppercase)

                                Spacer()
                            }

                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Spent")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))

                                    Text(String(format: "€%.0f", summary.totalSpent))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Budget")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))

                                    Text(String(format: "€%.0f", summary.budgetAmount))
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }

                            // Result badge
                            HStack {
                                Image(systemName: summary.wasUnderBudget ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(summary.wasUnderBudget ? Color(red: 0.2, green: 0.8, blue: 0.4) : .red)

                                Text(summary.statusText)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(summary.wasUnderBudget ? Color(red: 0.2, green: 0.8, blue: 0.4) : .red)

                                Spacer()
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill((summary.wasUnderBudget ? Color(red: 0.2, green: 0.8, blue: 0.4) : Color.red).opacity(0.1))
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                        )

                        // AI Report Button
                        Button {
                            Task {
                                let formatter = DateFormatter()
                                formatter.dateFormat = "MMMM yyyy"
                                if let date = formatter.date(from: summary.month) {
                                    let apiFormatter = DateFormatter()
                                    apiFormatter.dateFormat = "yyyy-MM"
                                    await viewModel.loadAIMonthlyReport(month: apiFormatter.string(from: date))
                                }
                                viewModel.showingAIMonthlyReport = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 18, weight: .semibold))

                                Text("View Full AI Report")
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle(summary.month)
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
}

#Preview {
    NavigationStack {
        BudgetView()
    }
    .preferredColorScheme(.dark)
}