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
    @Binding var isExpanded: Bool
    @State private var showingCategoryDetail = false
    @State private var showDeleteConfirmation = false
    @State private var showingInsights = false

    // MARK: - Premium Card Styling

    private var premiumCardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(white: 0.08))
            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.05),
                            Color.white.opacity(0.02),
                            Color.white.opacity(0.01)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    private var premiumCardBorder: some View {
        RoundedRectangle(cornerRadius: 24)
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.15),
                        Color.white.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    var body: some View {
        let stateDescription: String
        switch viewModel.state {
        case .idle: stateDescription = "idle"
        case .loading: stateDescription = "loading"
        case .noBudget: stateDescription = "noBudget"
        case .active(let progress): stateDescription = "active(\(progress.budget.id))"
        case .error(let msg): stateDescription = "error(\(msg))"
        }
        print("🎨 [BudgetPulseView] ===== BODY CALLED =====")
        print("🎨 [BudgetPulseView] state: \(stateDescription)")
        print("🎨 [BudgetPulseView] hasBudget: \(viewModel.state.hasBudget)")
        print("🎨 [BudgetPulseView] refreshTrigger: \(viewModel.forceRefreshTrigger)")
        print("🎨 [BudgetPulseView] isExpanded: \(isExpanded)")
        print("🎨 [BudgetPulseView] ========================")

        return contentView
            .background(premiumCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(premiumCardBorder)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: stateDescription)
            .onReceive(NotificationCenter.default.publisher(for: .budgetDeleted)) { _ in
                print("🎨 [BudgetPulseView] ⚡️ Received budgetDeleted notification, resetting local state")
                print("🎨 [BudgetPulseView] Before reset - isExpanded: \(isExpanded)")
                isExpanded = false
                showingCategoryDetail = false
                print("🎨 [BudgetPulseView] After reset - isExpanded: \(isExpanded)")
            }
        .sheet(isPresented: $viewModel.showingSetupSheet) {
            BudgetSetupView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingCategoryDetail) {
            if let progress = viewModel.state.progress {
                CategoryBudgetDetailView(progress: progress)
            }
        }
        .sheet(isPresented: $showingInsights) {
            BudgetInsightsView(viewModel: viewModel)
        }
        .alert("Remove Budget?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) {
                Task { @MainActor in
                    print("🎨 [BudgetPulseView] Delete button tapped, calling viewModel.deleteBudget()")
                    let success = await viewModel.deleteBudget()
                    if success {
                        print("🎨 [BudgetPulseView] Deletion successful, state should now be: \(viewModel.state)")
                    } else {
                        print("🎨 [BudgetPulseView] Deletion failed")
                    }
                }
            }
        } message: {
            Text("This will remove your budget tracking. You can set a new budget anytime.")
        }
    }

    // MARK: - Content View

    private var contentView: some View {
        print("🎨 [BudgetPulseView.contentView] Building content for state: \(viewModel.state.hasBudget ? "HAS BUDGET" : "NO BUDGET")")

        return VStack(spacing: 0) {
            switch viewModel.state {
            case .idle, .loading:
                let _ = print("🎨 [BudgetPulseView.contentView] Showing loadingView")
                loadingView
                    .transition(.opacity)

            case .noBudget:
                let _ = print("🎨 [BudgetPulseView.contentView] 🎯 Showing noBudgetView")
                noBudgetView
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

            case .active(let progress):
                let _ = print("🎨 [BudgetPulseView.contentView] Showing activeBudgetView for budget: \(progress.budget.id)")
                activeBudgetView(progress)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))

            case .error(let message):
                let _ = print("🎨 [BudgetPulseView.contentView] Showing errorView: \(message)")
                errorView(message)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack(spacing: 14) {
            // Skeleton mini ring
            SkeletonCircle(size: 44)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    SkeletonRect(width: 60, height: 18)
                    SkeletonRect(width: 20, height: 14)
                    SkeletonRect(width: 50, height: 16)
                }
                SkeletonRect(width: 120, height: 12)
            }

            Spacer()

            SkeletonRect(width: 14, height: 14, cornerRadius: 4)
        }
        .padding(16)
        .shimmer()
    }

    // MARK: - No Budget View

    private var noBudgetView: some View {
        let _ = print("🎨 [BudgetPulseView.noBudgetView] 🚀 RENDERING noBudgetView, isCurrentMonth: \(viewModel.isCurrentMonth)")

        return Group {
            if viewModel.isCurrentMonth {
                // Current month: Show setup button
                let _ = print("🎨 [BudgetPulseView.noBudgetView] ✅ Showing 'Set Budget' button")
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
                            Text("Set Budget")
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Past month: Show budget history if available
                pastMonthBudgetHistoryView
            }
        }
    }

    // MARK: - Past Month Budget History View

    private var pastMonthBudgetHistoryView: some View {
        Group {
            if let history = pastMonthHistoryForSelectedPeriod {
                VStack(alignment: .leading, spacing: 12) {
                    // Header with month
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(history.displayMonth)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)

                            if history.wasSmartBudget {
                                HStack(spacing: 4) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Budget")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                            }
                        }

                        Spacer()

                        if history.wasDeleted {
                            HStack(spacing: 4) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Deleted")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.3))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(red: 1.0, green: 0.55, blue: 0.3).opacity(0.15))
                            .cornerRadius(6)
                        }
                    }

                    Divider()
                        .background(.white.opacity(0.1))

                    // Budget amount
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Monthly Budget")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))

                        Text(String(format: "€%.0f", history.monthlyAmount))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    // Category allocations (if available)
                    if let allocations = history.categoryAllocations, !allocations.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category Allocations")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))

                            VStack(spacing: 4) {
                                ForEach(allocations.prefix(4)) { allocation in
                                    HStack {
                                        Circle()
                                            .fill(allocation.category.categoryColor)
                                            .frame(width: 6, height: 6)

                                        Text(allocation.category.normalizedCategoryName)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.8))

                                        Spacer()

                                        Text(String(format: "€%.0f", allocation.amount))
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .foregroundColor(.white)

                                        if allocation.isLocked {
                                            Image(systemName: "lock.fill")
                                                .font(.system(size: 9, weight: .semibold))
                                                .foregroundColor(.white.opacity(0.4))
                                        }
                                    }
                                }

                                if allocations.count > 4 {
                                    Text("+ \(allocations.count - 4) more")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }
                    }
                }
                .padding(16)
            } else {
                // No budget history for this month
                HStack(spacing: 12) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No budget was set for this month")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    Spacer()
                }
                .padding(16)
            }
        }
    }

    // Helper to get budget history for selected period
    private var pastMonthHistoryForSelectedPeriod: BudgetHistory? {
        // Convert selected period to "yyyy-MM" format
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        guard let date = dateFormatter.date(from: viewModel.selectedPeriod) else {
            return nil
        }

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "yyyy-MM"
        let monthString = monthFormatter.string(from: date)

        return viewModel.budgetHistory.first { $0.month == monthString }
    }

    // MARK: - Active Budget View

    private func activeBudgetView(_ progress: BudgetProgress) -> some View {
        let _ = print("🎨 [BudgetPulseView.activeBudgetView] 💰 RENDERING activeBudgetView for budget: \(progress.budget.id), isExpanded: \(isExpanded)")

        return VStack(spacing: 0) {
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

                // Delete button
                if isExpanded {
                    Button(action: { showDeleteConfirmation = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.3))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 4)
                }

                // Expand chevron
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func expandedContent(_ progress: BudgetProgress) -> some View {
        VStack(spacing: 16) {
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

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5, height: 32)

                statItem(
                    title: "Daily Budget",
                    value: String(format: "€%.0f", progress.dailyBudgetRemaining),
                    color: .white
                )

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 0.5, height: 32)

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
        }
        .padding(.bottom, 16)
    }

    // MARK: - Insight Section (Non-AI)

    private var aiInsightSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                showingInsights = true
                Task {
                    await viewModel.loadInsights()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 12, weight: .semibold))

                    Text("Budget Insights")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(red: 0.6, green: 0.4, blue: 1.0).opacity(0.12))
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(maxWidth: .infinity)
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
            }(), isExpanded: .constant(false))
            .padding(.horizontal)

            // No budget state
            BudgetPulseView(viewModel: {
                let vm = BudgetViewModel()
                vm.state = .noBudget
                return vm
            }(), isExpanded: .constant(false))
            .padding(.horizontal)

            Spacer()
        }
        .padding(.top, 20)
    }
}
