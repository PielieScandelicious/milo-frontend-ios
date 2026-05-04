//
//  BrandCashbackWalletHeaderCard.swift
//  Scandalicious
//
//  Top of BrandCashbackWalletView: balance + Withdraw CTA.
//

import SwiftUI

struct BrandCashbackWalletHeaderCard: View {
    let balanceCents: Int
    let totalEarnedCents: Int
    let totalWithdrawnCents: Int
    let canWithdraw: Bool
    let cannotWithdrawReason: String?
    let onWithdrawTapped: () -> Void

    private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Caption
            Text("BRAND CASHBACK COLLECTED")
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.4)
                .foregroundStyle(cashbackGreen.opacity(0.85))

            // Big balance
            Text(MoneyFormatter.eur(cents: balanceCents))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundStyle(cashbackGreen)
                .contentTransition(.numericText())
                .accessibilityLabel("Balance \(MoneyFormatter.eur(cents: balanceCents))")

            // Lifetime stats
            HStack(spacing: 14) {
                statPill(label: "Earned", value: totalEarnedCents)
                statPill(label: "Withdrawn", value: totalWithdrawnCents)
            }

            // Withdraw CTA
            Button(action: onWithdrawTapped) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 14, weight: .bold))
                    Text(canWithdraw ? "Withdraw" : "Withdraw unavailable")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(canWithdraw ? .black : Color.white.opacity(0.4))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(canWithdraw ? cashbackGreen : Color.white.opacity(0.08))
                )
            }
            .disabled(!canWithdraw)

            if !canWithdraw, let reason = cannotWithdrawReason {
                Text(reason)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func statPill(label: String, value: Int) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(MoneyFormatter.eur(cents: value))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.05)))
    }
}
