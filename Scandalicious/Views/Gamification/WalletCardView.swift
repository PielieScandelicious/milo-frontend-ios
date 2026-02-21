//
//  WalletCardView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct WalletCardView: View {
    @ObservedObject private var gm = GamificationManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "wallet.bifold.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                Text("My Wallet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text(gm.tierProgress.currentTier.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: gm.tierProgress.currentTier.gradientColors,
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Balance
            Text(gm.wallet.formatted)
                .font(.system(size: 52, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.5),
                            Color(red: 1.0, green: 0.84, blue: 0.0),
                            Color(red: 0.95, green: 0.65, blue: 0.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3), radius: 12)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: gm.wallet.cents)
                .padding(.bottom, 8)

            // Earnings info
            Text("€0.50 per receipt \u{00B7} \(String(format: "%.0f%%", (gm.tierProgress.currentTier.multiplier - 1.0) * 100)) tier bonus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.bottom, 18)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20).fill(Color(white: 0.08))
                RoundedRectangle(cornerRadius: 20)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.15, green: 0.10, blue: 0.02).opacity(0.5), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    ))
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.3),
                                 Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}
