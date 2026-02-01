//
//  BankingMainView.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct BankingMainView: View {
    @StateObject private var viewModel = BankingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Connected Banks Section
                    if viewModel.hasConnections {
                        connectedBanksSection
                    }

                    // Accounts Section
                    if let accounts = viewModel.accountsState.data, !accounts.isEmpty {
                        accountsSection(accounts: accounts)
                    }

                    // Pending Transactions Section
                    if viewModel.hasPendingTransactions {
                        pendingTransactionsSection
                    }

                    // Add Bank Button (always visible)
                    addBankButton
                }
                .padding()
            }
            .background(Color(white: 0.08))
            .navigationTitle("Bank Accounts")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.hasConnections {
                        Button {
                            Task {
                                await viewModel.syncAllAccounts()
                            }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(viewModel.accountsState.isLoading || !viewModel.syncingAccountIds.isEmpty)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadInitialData()
            }
            .sheet(isPresented: $viewModel.showingCountryPicker) {
                CountryPickerView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingBankSelection) {
                BankSelectionView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showingTransactionReview) {
                BankTransactionReviewView(viewModel: viewModel)
            }
            .alert("Connection Successful", isPresented: $viewModel.showingConnectionSuccess) {
                Button("OK") {
                    viewModel.showingConnectionSuccess = false
                }
            } message: {
                if let result = viewModel.lastConnectionResult {
                    Text("Successfully connected \(result.accountCount) account\(result.accountCount == 1 ? "" : "s").")
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK") {
                    viewModel.dismissError()
                }
            } message: {
                if let message = viewModel.errorMessage {
                    Text(message)
                }
            }
            .confirmationDialog(
                "Disconnect Bank",
                isPresented: $viewModel.showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive) {
                    Task {
                        await viewModel.executeDeleteConnection()
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.connectionToDelete = nil
                }
            } message: {
                if let connection = viewModel.connectionToDelete {
                    Text("Are you sure you want to disconnect \(connection.aspspName)? This will remove all linked accounts.")
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Connected Banks Section

    private var connectedBanksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connected Banks")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)

            if viewModel.connectionsState.isLoading {
                loadingCard
            } else if let connections = viewModel.connectionsState.data {
                ForEach(connections) { connection in
                    ConnectedBankCard(
                        connection: connection,
                        onDisconnect: {
                            viewModel.confirmDeleteConnection(connection)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Accounts Section

    private func accountsSection(accounts: [BankAccountResponse]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)

            ForEach(accounts) { account in
                BankAccountRow(
                    account: account,
                    isSyncing: viewModel.isSyncingAccount(account.id),
                    onSync: {
                        Task {
                            await viewModel.syncAccount(account.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Pending Transactions Section

    private var pendingTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Transactions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)

                Spacer()

                Text("\(viewModel.pendingTransactionsTotal)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(red: 1.0, green: 0.4, blue: 0.4))
                    .clipShape(Capsule())
            }

            Button {
                viewModel.openTransactionReview()
            } label: {
                HStack {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 20))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Review & Import")
                            .font(.system(size: 16, weight: .semibold))

                        Text("\(viewModel.pendingTransactionsTotal) transactions waiting for review")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Add Bank Button

    private var addBankButton: some View {
        Button {
            viewModel.openCountryPicker()
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))

                Text(viewModel.hasConnections ? "Link Another Bank" : "Link Bank Account")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.7, blue: 1.0),
                        Color(red: 0.4, green: 0.6, blue: 1.0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .padding(.top, viewModel.hasConnections ? 8 : 40)
    }

    // MARK: - Loading Card

    private var loadingCard: some View {
        HStack {
            ProgressView()
                .tint(.white)

            Text("Loading...")
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }
}

// MARK: - Connected Bank Card

struct ConnectedBankCard: View {
    let connection: BankConnectionResponse
    let onDisconnect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Bank Icon
            ZStack {
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 44, height: 44)

                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
            }

            // Bank Info
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.aspspName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    BankConnectionStatusBadge(status: connection.status)

                    Text("\(connection.accountsCount) account\(connection.accountsCount == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Disconnect Button
            Button {
                onDisconnect()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.3))
            }
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }
}

#Preview {
    BankingMainView()
}
