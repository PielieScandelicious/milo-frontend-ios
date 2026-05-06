//
//  BrandCashbackWalletEntryCard.swift
//  Scandalicious
//
//  Tappable wrapper that loads the wallet summary and renders the new
//  `WalletHeroCard` at the top of `BrandCashbackView`. Tapping anywhere on
//  the card (or the visual Withdraw chip) pushes to the full wallet view.
//
//  The lifetime "Pending" stat is sourced separately from the deals list
//  (sum of cashback amounts in pendingReview state) so it can render before
//  the wallet network call settles.
//

import SwiftUI

struct BrandCashbackWalletEntryCard: View {
    /// Pending cents derived upstream from the deals list (sum of cashback
    /// amounts for `pendingReview` deals). Defaults to 0 so legacy callers
    /// keep working.
    var pendingCents: Int = 0

    @State private var wallet: BrandCashbackWallet = .empty
    @State private var didLoad = false

    var body: some View {
        NavigationLink {
            BrandCashbackWalletView()
        } label: {
            WalletHeroCard(
                balanceCents:  wallet.balanceCents,
                earnedCents:   wallet.totalEarnedCents,
                pendingCents:  pendingCents,
                thisMonthCents: thisMonthCents,
                onWithdraw: {}     // decorative; tap target is the whole card
            )
        }
        .buttonStyle(.plain)
        .task {
            guard !didLoad else { return }
            didLoad = true
            if let fetched = try? await BrandCashbackWalletService.shared.getWallet(earningsLimit: 50) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.wallet = fetched
                    }
                }
            }
        }
    }

    private var thisMonthCents: Int {
        let cal = Calendar.current
        let now = Date()
        let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
        return wallet.recentEarnings
            .filter { $0.earnedAt >= monthStart }
            .reduce(0) { $0 + $1.cashbackEarnedCents }
    }
}
