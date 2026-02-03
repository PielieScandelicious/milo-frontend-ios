//
//  BankTransactionCard.swift
//  Scandalicious
//
//  Simple non-expandable card for displaying bank-imported transactions.
//  Unlike scanned receipts, bank transactions don't have line items.
//

import SwiftUI

/// A simple card for displaying bank-imported transactions.
/// These transactions don't have line items, so they are not expandable.
struct BankTransactionCard: View {
    let receipt: APIReceipt
    let onDelete: (() -> Void)?
    let onSplit: (() -> Void)?

    @State private var showDeleteConfirmation = false

    /// Observe split cache for updates
    @ObservedObject private var splitCache = SplitCacheManager.shared

    /// Get split data for this transaction
    private var splitData: CachedSplitData? {
        splitCache.getSplit(for: receipt.receiptId)
    }

    /// Get split participants (friends only, excluding "Me")
    private var splitFriends: [SplitParticipantInfo] {
        guard let split = splitData else { return [] }
        return split.participants.filter { !$0.isMe }
    }

    init(
        receipt: APIReceipt,
        onDelete: (() -> Void)? = nil,
        onSplit: (() -> Void)? = nil
    ) {
        self.receipt = receipt
        self.onDelete = onDelete
        self.onSplit = onSplit
    }

    var body: some View {
        VStack(spacing: 0) {
            // Card content
            HStack(spacing: 12) {
                // Bank icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "building.columns.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                }

                // Transaction details
                VStack(alignment: .leading, spacing: 4) {
                    // Merchant name
                    Text(receipt.displayStoreName.localizedCapitalized)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    // Date, category, and split avatars
                    HStack(spacing: 8) {
                        // Date
                        if let dateString = receipt.receiptDate {
                            Text(formattedDate(dateString))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        // Category badge (from first transaction if available)
                        if let category = receipt.transactions.first?.category {
                            Text(category)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.1))
                                )
                        }

                        // Split friend avatars (show if transaction is split)
                        if !splitFriends.isEmpty {
                            BankTransactionSplitAvatars(friends: splitFriends)
                        }
                    }
                }

                Spacer()

                // Amount
                Text(formattedAmount(receipt.displayTotalAmount))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Dropdown menu button
                Menu {
                    // Split with Friends option
                    if let splitAction = onSplit {
                        Button {
                            splitAction()
                        } label: {
                            Label("Split with Friends", systemImage: "person.2.fill")
                        }
                    }

                    if onSplit != nil && onDelete != nil {
                        Divider()
                    }

                    // Delete option
                    if onDelete != nil {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 36, height: 36)

                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(cardBackground)
        }
        .confirmationDialog(
            "Delete Transaction",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                onDelete?()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove the transaction from your spending history.")
        }
        .task {
            // Fetch split data if not already cached
            if splitData == nil {
                await splitCache.fetchSplit(for: receipt.receiptId)
            }
        }
    }

    // MARK: - Card Background

    private var cardBackground: some View {
        ZStack {
            // Glass base
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))

            // Gradient overlay
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Helpers

    private func formattedDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "MMM d"
        return outputFormatter.string(from: date)
    }

    private func formattedAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.currencySymbol = "€"
        return formatter.string(from: NSNumber(value: amount)) ?? "€\(String(format: "%.2f", amount))"
    }
}

// MARK: - Bank Transaction Split Avatars

/// Compact display of friend avatars for split bank transactions (excludes "Me")
struct BankTransactionSplitAvatars: View {
    let friends: [SplitParticipantInfo]

    /// Maximum avatars to show before "+N"
    private let maxVisible = 2

    var body: some View {
        HStack(spacing: -4) {
            // Show up to maxVisible avatars
            ForEach(Array(friends.prefix(maxVisible).enumerated()), id: \.element.id) { index, friend in
                Circle()
                    .fill(friend.swiftUIColor)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text(String(friend.name.prefix(1)).uppercased())
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(white: 0.1), lineWidth: 1)
                    )
                    .zIndex(Double(maxVisible - index))
            }

            // Show "+N" if more friends
            if friends.count > maxVisible {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Text("+\(friends.count - maxVisible)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(white: 0.1), lineWidth: 1)
                    )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05)
            .ignoresSafeArea()

        VStack(spacing: 12) {
            BankTransactionCard(
                receipt: APIReceipt(
                    receiptId: "1",
                    storeName: "Colruyt Kessel-Lo",
                    receiptDate: "2026-02-01",
                    totalAmount: 45.67,
                    itemsCount: 1,
                    averageHealthScore: nil,
                    source: .bankImport,
                    transactions: [
                        APIReceiptItem(
                            itemId: "item1",
                            itemName: "Bank transaction from Colruyt",
                            itemPrice: 45.67,
                            quantity: 1,
                            unitPrice: nil,
                            category: "Fresh Produce",
                            healthScore: nil
                        )
                    ]
                ),
                onDelete: {}
            )

            BankTransactionCard(
                receipt: APIReceipt(
                    receiptId: "2",
                    storeName: "Delhaize",
                    receiptDate: "2026-01-30",
                    totalAmount: 23.45,
                    itemsCount: 1,
                    averageHealthScore: nil,
                    source: .bankImport,
                    transactions: [
                        APIReceiptItem(
                            itemId: "item2",
                            itemName: "Groceries",
                            itemPrice: 23.45,
                            quantity: 1,
                            unitPrice: nil,
                            category: "Pantry",
                            healthScore: nil
                        )
                    ]
                ),
                onDelete: nil
            )
        }
        .padding()
    }
}
