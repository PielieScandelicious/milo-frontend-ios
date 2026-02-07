//
//  BudgetHistoryView.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

// MARK: - Budget History View

/// Full-screen view showing historical budget tracking across months
struct BudgetHistoryView: View {
    @ObservedObject var viewModel: BudgetViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedHistory: BudgetHistory?

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()

                if viewModel.isLoadingHistory {
                    loadingView
                } else if let error = viewModel.historyError {
                    errorView(error)
                } else if viewModel.budgetHistory.isEmpty {
                    emptyStateView
                } else {
                    historyListView
                }
            }
            .navigationTitle("Budget History")
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
            if viewModel.budgetHistory.isEmpty {
                await viewModel.loadBudgetHistory()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Color(red: 0.3, green: 0.7, blue: 1.0))

            Text("Loading history...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.3))

            Text("Failed to load history")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(error)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task {
                    await viewModel.loadBudgetHistory()
                }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            Text("No Budget History")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Your budget history will appear here once you've set budgets for multiple months.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    // MARK: - History List View

    private var historyListView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header with total count
                headerSection

                // Budget history cards
                ForEach(viewModel.budgetHistory) { history in
                    budgetHistoryCard(history)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text("\(viewModel.budgetHistory.count) Month\(viewModel.budgetHistory.count == 1 ? "" : "s")")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text("Budget tracking history")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Budget History Card

    private func budgetHistoryCard(_ history: BudgetHistory) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(history.displayMonth)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    if history.wasSmartBudget {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Budget")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                    }
                }

                Spacer()

                if history.wasDeleted {
                    HStack(spacing: 4) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Deleted")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.3))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(red: 1.0, green: 0.55, blue: 0.3).opacity(0.15))
                    .cornerRadius(8)
                }
            }

            Divider()
                .background(.white.opacity(0.1))

            // Budget amount
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly Budget")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))

                    Text(String(format: "€%.0f", history.monthlyAmount))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()
            }

            // Category allocations (if available)
            if let allocations = history.categoryAllocations, !allocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Category Allocations")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))

                    VStack(spacing: 6) {
                        ForEach(allocations.prefix(3)) { allocation in
                            HStack {
                                Circle()
                                    .fill(allocation.category.categoryColor)
                                    .frame(width: 8, height: 8)

                                Text(allocation.category.normalizedCategoryName)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))

                                Spacer()

                                Text(String(format: "€%.0f", allocation.amount))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                if allocation.isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white.opacity(0.4))
                                }
                            }
                        }

                        if allocations.count > 3 {
                            Text("+ \(allocations.count - 3) more categories")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#if DEBUG
struct BudgetHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BudgetViewModel()
        // Simulate some budget history data
        viewModel.budgetHistory = [
            BudgetHistory(
                id: "1",
                userId: "user123",
                monthlyAmount: 1500,
                categoryAllocations: [
                    CategoryAllocation(category: "Groceries", amount: 600, isLocked: false),
                    CategoryAllocation(category: "Dining Out", amount: 300, isLocked: true),
                    CategoryAllocation(category: "Entertainment", amount: 200, isLocked: false),
                    CategoryAllocation(category: "Transport", amount: 400, isLocked: false)
                ],
                month: "2026-01",
                wasSmartBudget: true,
                wasDeleted: false,
                createdAt: "2026-01-01T00:00:00Z"
            ),
            BudgetHistory(
                id: "2",
                userId: "user123",
                monthlyAmount: 1400,
                categoryAllocations: [
                    CategoryAllocation(category: "Groceries", amount: 550, isLocked: false),
                    CategoryAllocation(category: "Dining Out", amount: 280, isLocked: false),
                    CategoryAllocation(category: "Entertainment", amount: 180, isLocked: false),
                    CategoryAllocation(category: "Transport", amount: 390, isLocked: false)
                ],
                month: "2025-12",
                wasSmartBudget: true,
                wasDeleted: false,
                createdAt: "2025-12-01T00:00:00Z"
            ),
            BudgetHistory(
                id: "3",
                userId: "user123",
                monthlyAmount: 1600,
                categoryAllocations: nil,
                month: "2025-11",
                wasSmartBudget: false,
                wasDeleted: true,
                createdAt: "2025-11-01T00:00:00Z"
            )
        ]

        return BudgetHistoryView(viewModel: viewModel)
    }
}
#endif
