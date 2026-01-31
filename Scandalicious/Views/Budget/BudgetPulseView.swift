//
//  BudgetPulseView.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//

import SwiftUI

// MARK: - Budget Pulse View

/// The main budget widget - collapsible, showing current budget progress
struct BudgetPulseView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @State private var isExpanded = false
    @State private var showingCategoryDetail = false
    @State private var showingAIReport = false
    @State private var showingAIInsight = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.state {
            case .idle, .loading:
                loadingView

            case .noBudget:
                noBudgetView

            case .active(let progress):
                activeBudgetView(progress)

            case .error(let message):
                errorView(message)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.12))
        )
        .sheet(isPresented: $viewModel.showingSetupSheet) {
            BudgetSetupView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCategoryDetail) {
            if let progress = viewModel.state.progress {
                CategoryBudgetDetailView(progress: progress)
            }
        }
        .sheet(isPresented: $showingAIReport) {
            if let report = viewModel.aiMonthlyReportState.data {
                AIMonthlyReportView(report: report)
            }
        }
        .sheet(isPresented: $showingAIInsight) {
            if case .loaded(let checkIn) = viewModel.aiCheckInState {
                AIInsightSheetView(checkIn: checkIn)
            }
        }
        .alert("Remove Budget?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task {
                    await viewModel.deleteBudget()
                }
            }
        } message: {
            Text("This will remove your budget tracking. You can set a new AI budget anytime.")
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white.opacity(0.6))

            Text("Loading budget...")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))

            Spacer()
        }
        .padding(16)
    }

    // MARK: - No Budget View

    private var noBudgetView: some View {
        Button(action: { viewModel.startSetup() }) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)

                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Smart Budget")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("Track your spending and stay on track")
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

    // MARK: - Active Budget View

    private func activeBudgetView(_ progress: BudgetProgress) -> some View {
        VStack(spacing: 0) {
            // Collapsed header (always visible)
            collapsedHeader(progress)

            // Expanded content
            if isExpanded {
                expandedContent(progress)
            }
        }
    }

    private func collapsedHeader(_ progress: BudgetProgress) -> some View {
        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
            HStack(spacing: 14) {
                // Mini ring
                MiniBudgetRing(
                    spendRatio: progress.spendRatio,
                    paceStatus: progress.paceStatus,
                    size: 44
                )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(String(format: "€%.0f", progress.currentSpend))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("of")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text(String(format: "€%.0f", progress.budget.monthlyAmount))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    HStack(spacing: 6) {
                        // Status badge
                        HStack(spacing: 4) {
                            Image(systemName: progress.paceStatus.icon)
                                .font(.system(size: 11, weight: .semibold))

                            Text(progress.paceStatus.displayText)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(progress.paceStatus.color)

                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        // Days remaining
                        Text("\(progress.daysRemaining) days left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                Spacer()

                // Expand chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
            }
            .padding(16)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func expandedContent(_ progress: BudgetProgress) -> some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.1))

            // Large ring with details
            BudgetRingView(progress: progress, size: 160)
                .padding(.vertical, 8)

            // Stats row
            HStack(spacing: 0) {
                statItem(
                    title: "Remaining",
                    value: String(format: "€%.0f", progress.remainingBudget),
                    color: progress.remainingBudget > 0 ? .green : .red
                )

                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))

                statItem(
                    title: "Daily Budget",
                    value: String(format: "€%.0f", progress.dailyBudgetRemaining),
                    color: .white
                )

                Divider()
                    .frame(height: 40)
                    .background(Color.white.opacity(0.1))

                statItem(
                    title: "Projected",
                    value: String(format: "€%.0f", progress.projectedEndOfMonth),
                    color: progress.projectedOverUnder > 0 ? .orange : .green
                )
            }
            .padding(.horizontal, 8)

            // Progress bar
            VStack(spacing: 6) {
                BudgetProgressBar(progress: progress, height: 10)

                HStack {
                    Text("Day \(progress.daysElapsed)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))

                    Spacer()

                    Text("Day \(progress.daysInMonth)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 16)

            // Category breakdown (if available)
            if !progress.categoryProgress.isEmpty {
                categoryBreakdownSection(progress.categoryProgress)
            }

            // AI Insight section
            aiInsightSection

            // Bottom action bar
            bottomActionBar(progress)
        }
    }

    // MARK: - AI Insight Section

    private var aiInsightSection: some View {
        Group {
            switch viewModel.aiCheckInState {
            case .idle:
                Button(action: {
                    Task {
                        await viewModel.loadAICheckIn()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))

                        Text("Get Milo's Insight")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.3, green: 0.7, blue: 1.0))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .frame(maxWidth: .infinity)

            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)

                    Text("Getting insight...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

            case .loaded(let checkIn):
                Button(action: { showingAIInsight = true }) {
                    HStack(spacing: 10) {
                        Text(checkIn.statusSummary.emoji)
                            .font(.system(size: 20))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(checkIn.statusSummary.headline)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)

                            Text(checkIn.statusSummary.detail)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(2)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.03))
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.horizontal, 16)

            case .error:
                EmptyView()
            }
        }
    }

    // MARK: - Bottom Action Bar

    private func bottomActionBar(_ progress: BudgetProgress) -> some View {
        HStack(spacing: 0) {
            // Remove button
            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .frame(width: 44, height: 36)

            Spacer()

            // Projection text in center
            if let projection = viewModel.projectionText {
                Text(projection)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(progress.projectedOverUnder > 0 ? .orange : .green)
            }

            Spacer()

            // AI Report button
            Button(action: {
                Task {
                    await viewModel.loadAIMonthlyReport()
                    if viewModel.aiMonthlyReportState.data != nil {
                        showingAIReport = true
                    }
                }
            }) {
                HStack(spacing: 4) {
                    if viewModel.aiMonthlyReportState.isLoading {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(.white.opacity(0.6))
                    } else {
                        Image(systemName: "chart.bar.doc.horizontal")
                            .font(.system(size: 14, weight: .medium))
                    }
                    Text("Report")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.6))
            }
            .disabled(viewModel.aiMonthlyReportState.isLoading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(color)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func categoryBreakdownSection(_ categories: [CategoryBudgetProgress]) -> some View {
        CategoryBudgetGrid(categories: categories) {
            showingCategoryDetail = true
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("Couldn't load budget")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer()

            Button(action: { Task { await viewModel.loadBudget() } }) {
                Text("Retry")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
            }
        }
        .padding(16)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 20) {
            // Active budget
            BudgetPulseView(viewModel: {
                let vm = BudgetViewModel()
                let budget = UserBudget(
                    id: "1",
                    userId: "user1",
                    monthlyAmount: 850,
                    categoryAllocations: nil,
                    notificationsEnabled: true,
                    alertThresholds: [0.5, 0.75, 0.9]
                )
                let progress = BudgetProgress(
                    budget: budget,
                    currentSpend: 623,
                    daysElapsed: 21,
                    daysInMonth: 31,
                    categoryProgress: [
                        CategoryBudgetProgress(category: "Fresh Produce", budgetAmount: 100, currentSpend: 85, isLocked: false),
                        CategoryBudgetProgress(category: "Meat & Fish", budgetAmount: 150, currentSpend: 140, isLocked: true),
                        CategoryBudgetProgress(category: "Snacks & Sweets", budgetAmount: 60, currentSpend: 72, isLocked: false),
                    ]
                )
                vm.state = .active(progress)
                return vm
            }())
            .padding(.horizontal)

            // No budget state
            BudgetPulseView(viewModel: {
                let vm = BudgetViewModel()
                vm.state = .noBudget
                return vm
            }())
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}
