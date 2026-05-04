//
//  BrandCashbackWalletView.swift
//  Scandalicious
//
//  Brand cashback wallet: balance + earnings history + withdrawal history.
//  Pushed from BrandCashbackView's wallet entry card.
//

import SwiftUI

struct BrandCashbackWalletView: View {
    @StateObject private var viewModel = BrandCashbackWalletViewModel()
    @State private var showWithdrawalSheet = false

    var body: some View {
        ZStack {
            backgroundGradient

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    BrandCashbackWalletHeaderCard(
                        balanceCents: viewModel.wallet.balanceCents,
                        totalEarnedCents: viewModel.wallet.totalEarnedCents,
                        totalWithdrawnCents: viewModel.wallet.totalWithdrawnCents,
                        canWithdraw: viewModel.withdrawalInfo?.canWithdraw ?? false,
                        cannotWithdrawReason: viewModel.withdrawalInfo?.cannotWithdrawReason,
                        onWithdrawTapped: { showWithdrawalSheet = true }
                    )

                    earningsSection

                    withdrawalsSection

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .scrollContentBackground(.hidden)
            .refreshable { await viewModel.load() }
        }
        .navigationTitle("Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .task { await viewModel.load() }
        .sheet(isPresented: $showWithdrawalSheet) {
            if let info = viewModel.withdrawalInfo {
                WithdrawalRequestSheet(info: info, onSuccess: {
                    Task { await viewModel.refreshAfterWithdrawal() }
                })
            }
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            stops: [
                .init(color: Color(red: 0.06, green: 0.09, blue: 0.14), location: 0.0),
                .init(color: Color(red: 0.04, green: 0.06, blue: 0.10), location: 0.4),
                .init(color: Color(red: 0.03, green: 0.04, blue: 0.07), location: 1.0),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    // MARK: - Sections

    private var earningsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "EARNINGS", icon: "checkmark.seal.fill")

            if viewModel.wallet.recentEarnings.isEmpty {
                emptyStateRow(
                    icon: "tray",
                    title: "No earnings yet",
                    subtitle: "Claim a brand campaign and scan the matching receipt to start earning."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.wallet.recentEarnings) { event in
                        BrandCashbackEarningRow(event: event)
                    }
                }
            }
        }
    }

    private var withdrawalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "WITHDRAWALS", icon: "arrow.down.to.line")

            if viewModel.withdrawalHistory.isEmpty {
                emptyStateRow(
                    icon: "banknote",
                    title: "No withdrawals yet",
                    subtitle: "Once your balance reaches €5 you can withdraw to your bank account."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.withdrawalHistory) { item in
                        WithdrawalRow(item: item)
                    }
                }
            }
        }
    }

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .heavy))
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
        }
        .foregroundStyle(.white.opacity(0.4))
    }

    private func emptyStateRow(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(.white.opacity(0.18))
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
    }
}
