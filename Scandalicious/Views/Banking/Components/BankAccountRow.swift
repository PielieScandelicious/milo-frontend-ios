//
//  BankAccountRow.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import SwiftUI

struct BankAccountRow: View {
    let account: BankAccountResponse
    let isSyncing: Bool
    let onSync: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Account Icon
            ZStack {
                Circle()
                    .fill(Color(white: 0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.7))
            }

            // Account Info
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)

                HStack(spacing: 8) {
                    if let maskedIban = account.maskedIban {
                        Text(maskedIban)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }

                    if let lastSync = account.lastSyncedAt {
                        Text(formatLastSync(lastSync))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
            }

            Spacer()

            // Balance
            if let balance = account.balance {
                Text(formatBalance(balance, currency: account.currency))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(balance >= 0 ? Color(red: 0.3, green: 0.8, blue: 0.5) : Color(red: 1.0, green: 0.4, blue: 0.4))
            }

            // Sync Button
            Button {
                onSync()
            } label: {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                        .frame(width: 32, height: 32)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                        .frame(width: 32, height: 32)
                }
            }
            .disabled(isSyncing)
        }
        .padding()
        .background(Color(white: 0.12))
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func formatBalance(_ balance: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: balance)) ?? "\(currency) \(balance)"
    }

    private func formatLastSync(_ date: Date) -> String {
        let relativeFormatter = RelativeDateTimeFormatter()
        relativeFormatter.unitsStyle = .abbreviated
        return "Synced " + relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    VStack {
        BankAccountRow(
            account: BankAccountResponse(
                id: "1",
                connectionId: "conn1",
                iban: "BE68539007547034",
                accountName: "Current Account",
                holderName: "John Doe",
                currency: "EUR",
                balance: 1234.56,
                lastSyncedAt: Date().addingTimeInterval(-3600)
            ),
            isSyncing: false,
            onSync: {}
        )

        BankAccountRow(
            account: BankAccountResponse(
                id: "2",
                connectionId: "conn1",
                iban: "BE68539007547035",
                accountName: "Savings Account",
                holderName: "John Doe",
                currency: "EUR",
                balance: 5678.90,
                lastSyncedAt: nil
            ),
            isSyncing: true,
            onSync: {}
        )
    }
    .padding()
    .background(Color(white: 0.08))
}
