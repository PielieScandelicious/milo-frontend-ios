//
//  BankTransactionReviewView.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct BankTransactionReviewView: View {
    @ObservedObject var viewModel: BankingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selection Header
                selectionHeader

                // Transaction List
                if viewModel.pendingTransactionsState.isLoading {
                    loadingView
                } else if let transactions = viewModel.pendingTransactionsState.data {
                    if transactions.isEmpty {
                        emptyView
                    } else {
                        transactionList(transactions: transactions)
                    }
                } else if let error = viewModel.pendingTransactionsState.errorMessage {
                    errorView(message: error)
                }

                // Action Bar
                if viewModel.selectedTransactionsCount > 0 {
                    actionBar
                }
            }
            .background(Color(white: 0.08))
            .navigationTitle("Review Transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        viewModel.closeTransactionReview()
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Selection Header

    private var selectionHeader: some View {
        HStack {
            Button {
                if viewModel.allTransactionsSelected {
                    viewModel.deselectAllTransactions()
                } else {
                    viewModel.selectAllTransactions()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.allTransactionsSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(viewModel.allTransactionsSelected ? Color(red: 0.3, green: 0.7, blue: 1.0) : .white.opacity(0.4))

                    Text(viewModel.allTransactionsSelected ? "Deselect All" : "Select All")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("\(viewModel.selectedTransactionsCount) selected")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding()
        .background(Color(white: 0.1))
    }

    // MARK: - Transaction List

    private func transactionList(transactions: [BankTransactionResponse]) -> some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    BankTransactionRow(
                        transaction: transaction,
                        isSelected: viewModel.selectedTransactionIds.contains(transaction.id),
                        category: viewModel.getCategory(for: transaction),
                        onToggleSelection: {
                            viewModel.toggleTransactionSelection(transaction.id)
                        },
                        onCategoryChange: { category in
                            viewModel.setCategoryOverride(for: transaction.id, category: category)
                        }
                    )
                }
            }
            .padding()
            .padding(.bottom, 100) // Space for action bar
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.white)

            Text("Loading transactions...")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(red: 0.3, green: 0.8, blue: 0.5))

            Text("All caught up!")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)

            Text("No transactions pending review")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))

            Button {
                viewModel.closeTransactionReview()
            } label: {
                Text("Done")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))

            Text("Failed to load transactions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.loadPendingTransactions()
                }
            } label: {
                Text("Try Again")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            // Ignore Button
            Button {
                Task {
                    await viewModel.ignoreSelectedTransactions()
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isIgnoring {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "eye.slash")
                    }
                    Text("Ignore")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(white: 0.2))
                .cornerRadius(10)
            }
            .disabled(viewModel.isIgnoring || viewModel.isImporting)

            // Import Button
            Button {
                Task {
                    await viewModel.importSelectedTransactions()
                }
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isImporting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }
                    Text("Import (\(viewModel.selectedTransactionsCount))")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color(red: 0.3, green: 0.7, blue: 1.0))
                .cornerRadius(10)
            }
            .disabled(viewModel.isIgnoring || viewModel.isImporting)
        }
        .padding()
        .background(
            Color(white: 0.1)
                .shadow(color: .black.opacity(0.3), radius: 10, y: -5)
        )
    }
}

#Preview {
    BankTransactionReviewView(viewModel: BankingViewModel())
}
