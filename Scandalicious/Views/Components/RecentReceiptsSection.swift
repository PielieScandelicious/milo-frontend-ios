//
//  RecentReceiptsSection.swift
//  Scandalicious
//
//  Expandable list of recent cashback receipts (Recent Rewards).
//  Shows 3 rows by default, expands to show all.
//

import SwiftUI

struct RecentReceiptsSection: View {
    let receipts: [RecentReceipt]

    @State private var isExpanded = false

    private var visibleReceipts: [RecentReceipt] {
        if isExpanded {
            return receipts
        } else {
            return Array(receipts.prefix(3))
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tappable header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))

                    Text("Recent Rewards")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))

                    Spacer()

                    Text("\(receipts.count)")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.3))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            // Receipt rows
            ForEach(Array(visibleReceipts.enumerated()), id: \.element.id) { index, receipt in
                RecentReceiptRow(receipt: receipt)

                if index < visibleReceipts.count - 1 {
                    LinearGradient(
                        colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)
                    .padding(.leading, 52)
                    .padding(.trailing, 16)
                }
            }
        }
        .padding(.bottom, 10)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(cardBorder)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
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
                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.5
            )
    }
}

// MARK: - Mock Receipt Row

private struct RecentReceiptRow: View {
    let receipt: RecentReceipt

    private let cashbackGradient = LinearGradient(
        colors: [Color(red: 0.2, green: 0.85, blue: 0.7), Color(red: 0.15, green: 0.55, blue: 0.75)],
        startPoint: .leading,
        endPoint: .trailing
    )
    private let goldGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.88, blue: 0.35), Color(red: 0.80, green: 0.60, blue: 0.0)],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        HStack(spacing: 12) {
            // Store color indicator
            ZStack {
                Circle()
                    .fill(receipt.storeColor.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: "storefront.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(receipt.storeColor)
            }

            // Store name + date
            VStack(alignment: .leading, spacing: 3) {
                Text(receipt.storeName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(formatDate(receipt.date))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()

            // Amounts
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "\u{20AC}%.2f", receipt.totalAmount))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Text(String(format: "+\u{20AC}%.2f", receipt.cashbackAmount))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(cashbackGradient)

                    if receipt.spinsAwarded > 0 {
                        Text("+\(receipt.spinsAwarded) \(receipt.spinsAwarded == 1 ? "spin" : "spins")")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(goldGradient)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date)
    }
}
