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
                HStack(spacing: 4) {
                    if gm.goldTierStatus.isGoldTier {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.black.opacity(0.7))
                    }
                    Text(gm.goldTierStatus.displayName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(gm.goldTierStatus.isGoldTier ? .black : .white.opacity(0.35))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: gm.goldTierStatus.gradientColors,
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
