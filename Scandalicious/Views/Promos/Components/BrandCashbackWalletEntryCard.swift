//
//  BrandCashbackWalletEntryCard.swift
//  Scandalicious
//
//  The "My Wallet" tile that sits at the top of BrandCashbackView and pushes
//  to BrandCashbackWalletView. Loads its own balance summary so it can render
//  before the wallet view itself runs.
//

import SwiftUI

struct BrandCashbackWalletEntryCard: View {
    @State private var balanceCents: Int = 0
    @State private var didLoad: Bool = false

    private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)

    var body: some View {
        NavigationLink {
            BrandCashbackWalletView()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(cashbackGreen.opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: "wallet.pass.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(cashbackGreen)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("MY WALLET")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.5))
                    Text(MoneyFormatter.eur(cents: balanceCents))
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(cashbackGreen)
                        .contentTransition(.numericText())
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(cashbackGreen.opacity(0.25), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .task {
            // Avoid blocking re-renders by only loading once per appearance.
            guard !didLoad else { return }
            didLoad = true
            if let wallet = try? await BrandCashbackWalletService.shared.getWallet(earningsLimit: 1) {
                await MainActor.run {
                    withAnimation(.easeOut(duration: 0.3)) {
                        self.balanceCents = wallet.balanceCents
                    }
                }
            }
        }
    }
}
