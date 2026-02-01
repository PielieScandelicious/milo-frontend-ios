//
//  BankCard.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct BankCard: View {
    let bank: BankInfo
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                // Bank Logo
                bankLogo

                // Bank Name
                Text(bank.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(Color(white: 0.12))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bank Logo

    @ViewBuilder
    private var bankLogo: some View {
        if let logoUrl = bank.logoUrl, let url = URL(string: logoUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    logoPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                case .failure:
                    logoPlaceholder
                @unknown default:
                    logoPlaceholder
                }
            }
        } else {
            logoPlaceholder
        }
    }

    private var logoPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.2))
                .frame(width: 48, height: 48)

            Text(String(bank.name.prefix(1)))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    HStack {
        BankCard(
            bank: BankInfo(
                name: "KBC Bank",
                country: "BE",
                bic: "KREDBEBB",
                logoUrl: nil,
                maxConsentDays: 90
            ),
            onTap: {}
        )

        BankCard(
            bank: BankInfo(
                name: "BNP Paribas Fortis",
                country: "BE",
                bic: "GEBABEBB",
                logoUrl: nil,
                maxConsentDays: 90
            ),
            onTap: {}
        )
    }
    .padding()
    .background(Color(white: 0.08))
}
