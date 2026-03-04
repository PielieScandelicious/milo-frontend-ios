//
//  WalletPassCard.swift
//  Scandalicious
//
//  Card linking to the Wallet Pass creator for loyalty cards.
//

import SwiftUI

struct WalletPassCard: View {
    let onTap: () -> Void

    private let purple = Color(red: 0.45, green: 0.15, blue: 0.70)

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(purple.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(purple)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Wallet Pass Creator")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)

                    Text("Add your loyalty cards to Apple Wallet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.3))
            }
            .padding(16)
            .background(cardBackground)
            .overlay(cardBorder)
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(Color(white: 0.08))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 20)
            .stroke(
                LinearGradient(
                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}
