//
//  ReceiptTransactionsView.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import SwiftUI

struct ReceiptTransactionsView: View {
    let receipt: APIReceipt

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    private var filteredTransactions: [APIReceiptItem] {
        if searchText.isEmpty {
            return receipt.transactions
        }
        return receipt.transactions.filter {
            $0.itemName.localizedCaseInsensitiveContains(searchText) ||
            $0.categoryDisplayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedByCategory: [(String, [APIReceiptItem])] {
        let grouped = Dictionary(grouping: filteredTransactions) { $0.categoryDisplayName }
        return grouped.sorted { first, second in
            let firstTotal = first.value.reduce(0) { $0 + $1.totalPrice }
            let secondTotal = second.value.reduce(0) { $0 + $1.totalPrice }
            return firstTotal > secondTotal
        }
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    searchBar

                    if filteredTransactions.isEmpty {
                        emptySearchState
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(groupedByCategory, id: \.0) { category, transactions in
                                categorySection(category: category, transactions: transactions)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(receipt.displayStoreName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(receipt.formattedDate)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Components

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Receipt header card
            VStack(spacing: 12) {
                // Store icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 60, height: 60)

                    Image(systemName: "building.2.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.blue)
                }

                Text(receipt.displayStoreName)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(receipt.formattedDate)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text(String(format: "€%.2f", receipt.displayTotalAmount))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 4)

                // Health score if available
                if let healthScore = receipt.averageHealthScore {
                    Divider()
                        .background(Color.white.opacity(0.2))
                        .padding(.horizontal, 40)
                        .padding(.top, 8)

                    HStack(spacing: 8) {
                        HealthScoreBadge(score: Int(healthScore.rounded()), size: .medium, style: .subtle)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Health Score")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            Text(healthScore.healthScoreLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(healthScore.healthScoreColor)
                        }
                    }
                    .padding(.top, 4)
                }

                // Item count
                Text("\(receipt.itemsCount) item\(receipt.itemsCount == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 4)
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(searchText.isEmpty ? .white.opacity(0.4) : .white.opacity(0.6))

            TextField("Search Items", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .accentColor(.blue)
                .focused($isSearchFocused)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSearchFocused ? Color.blue.opacity(0.5) : Color.white.opacity(0.15),
                    lineWidth: isSearchFocused ? 2 : 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.3), value: isSearchFocused)
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 40)

            Text("No Results")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            Text("Try adjusting your search")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func categorySection(category: String, transactions: [APIReceiptItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Category header
            HStack {
                Image(systemName: categoryIcon(for: category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(category.categoryColor)

                Text(category)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Text(String(format: "€%.2f", transactions.reduce(0) { $0 + $1.totalPrice }))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)

            // Transaction rows
            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    transactionRow(transaction)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func transactionRow(_ transaction: APIReceiptItem) -> some View {
        HStack(spacing: 12) {
            // Icon with quantity badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(transaction.categoryDisplayName.categoryColor.opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: categoryIcon(for: transaction.categoryDisplayName))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(transaction.categoryDisplayName.categoryColor)
                }

                if transaction.quantity > 1 {
                    Text("×\(transaction.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(transaction.categoryDisplayName.categoryColor)
                        )
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 50, height: 50)

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(transaction.itemName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    if let healthScore = transaction.healthScore {
                        HealthScoreBadge(score: healthScore, size: .small, style: .subtle)
                    }
                }

                HStack(spacing: 8) {
                    Text(transaction.categoryDisplayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    if transaction.quantity > 1 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        Text("Qty: \(transaction.quantity)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                if let unitPrice = transaction.unitPrice, transaction.quantity > 1 {
                    Text(unitPrice, format: .currency(code: "EUR"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "€%.2f", transaction.totalPrice))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if let score = transaction.healthScore {
                    Text(score.healthScoreShortLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(score.healthScoreColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Meat & Fish": return "fish.fill"
        case "Alcohol": return "wineglass.fill"
        case "Drinks (Soft/Soda)", "Drinks (Water)": return "cup.and.saucer.fill"
        case "Household": return "house.fill"
        case "Snacks & Sweets": return "birthday.cake.fill"
        case "Fresh Produce": return "leaf.fill"
        case "Dairy & Eggs": return "cup.and.saucer.fill"
        case "Ready Meals": return "takeoutbag.and.cup.and.straw.fill"
        case "Bakery": return "birthday.cake.fill"
        case "Pantry": return "cabinet.fill"
        case "Personal Care": return "sparkles"
        case "Frozen": return "snowflake"
        case "Baby & Kids": return "figure.and.child.holdinghands"
        case "Pet Supplies": return "pawprint.fill"
        default: return "cart.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReceiptTransactionsView(
            receipt: APIReceipt(
                receiptId: "abc123",
                storeName: "COLRUYT",
                receiptDate: "2026-01-24",
                totalAmount: 4.48,
                itemsCount: 2,
                averageHealthScore: 3.5,
                transactions: [
                    APIReceiptItem(
                        itemName: "Organic Milk",
                        itemPrice: 2.49,
                        quantity: 2,
                        unitPrice: 1.245,
                        category: "Dairy & Eggs",
                        healthScore: 4
                    ),
                    APIReceiptItem(
                        itemName: "Fresh Bread",
                        itemPrice: 1.99,
                        quantity: 1,
                        unitPrice: nil,
                        category: "Bakery",
                        healthScore: 3
                    )
                ]
            )
        )
    }
    .preferredColorScheme(.dark)
}
