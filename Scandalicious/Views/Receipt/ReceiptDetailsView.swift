//
//  ReceiptDetailsView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI

struct ReceiptDetailsView: View {
    let receipt: ReceiptUploadResponse
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section - Store and Totals
                    headerSection
                    
                    // Items List
                    itemsSection
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Receipt Details")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                print("📋 ReceiptDetailsView appeared")
                print("   Receipt ID: \(receipt.receiptId)")
                print("   Store: \(receipt.storeName ?? "N/A")")
                print("   Total: \(receipt.totalAmount ?? 0.0)")
                print("   Items Count: \(receipt.itemsCount)")
                print("   Transactions array count: \(receipt.transactions.count)")
                print("   Transactions isEmpty: \(receipt.transactions.isEmpty)")
                
                if !receipt.transactions.isEmpty {
                    print("   First few transactions:")
                    for (index, transaction) in receipt.transactions.prefix(3).enumerated() {
                        print("      [\(index)] \(transaction.itemName) - €\(transaction.itemPrice) - qty: \(transaction.quantity) - unitPrice: \(transaction.unitPrice ?? 0)")
                    }
                } else {
                    print("   ⚠️ Transactions array is empty!")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Store Name
            if let storeName = receipt.storeName {
                HStack {
                    Image(systemName: "storefront.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)

                    Text(storeName)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Date
            if let date = receipt.parsedDate {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.subheadline)
                    Text(date, style: .date)
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
            }

            Divider()
                .padding(.vertical, 8)

            // Total Amount
            if let totalAmount = receipt.totalAmount {
                VStack(spacing: 4) {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(totalAmount, format: .currency(code: "EUR"))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            }

            // Health Score (if available)
            if let healthScore = receipt.calculatedAverageHealthScore {
                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
                    HealthScoreGauge(score: healthScore, size: 60, showLabel: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Health Score")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Text(healthScore.healthScoreLabel)
                            .font(.headline)
                            .foregroundStyle(healthScore.healthScoreColor)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }

            // Items Count
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                    .font(.caption)
                Text("\(receipt.itemsCount) item\(receipt.itemsCount == 1 ? "" : "s")")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Items Section
    
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Items")
                .font(.headline)
                .padding(.horizontal, 4)
            
            if receipt.transactions.isEmpty {
                emptyItemsView
            } else {
                itemsList
            }
        }
    }
    
    private var emptyItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "cart")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            
            Text("No items found")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("The receipt was uploaded successfully, but no items were detected.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var itemsList: some View {
        VStack(spacing: 8) {
            ForEach(receipt.transactions) { transaction in
                ReceiptItemRow(transaction: transaction)
            }
        }
    }
}

// MARK: - Receipt Item Row

struct ReceiptItemRow: View {
    let transaction: ReceiptTransaction

    var body: some View {
        let _ = print("🛒 ReceiptItemRow: \(transaction.itemName) - qty: \(transaction.quantity), unitPrice: \(transaction.unitPrice ?? 0)")
        HStack(alignment: .top, spacing: 12) {
            // Category Icon with Quantity Badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: transaction.category.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(categoryColor)
                }

                // Quantity badge (show if > 1)
                if transaction.quantity > 1 {
                    Text("×\(transaction.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(categoryColor)
                        )
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 50, height: 44)  // Slightly wider to accommodate badge

            // Item Details
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    // Horizontally scrollable item name (2 lines max)
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(transaction.itemName)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxHeight: 44) // Roughly 2 lines of text

                    // Health Score Badge
                    HealthScoreBadge(score: transaction.healthScore, size: .small, style: .subtle)
                        .layoutPriority(1)
                }

                HStack(spacing: 8) {
                    // Quantity (show if > 1)
                    if transaction.quantity > 1 {
                        Text("Qty: \(transaction.quantity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Unit Price (show if quantity > 1)
                    if let unitPrice = transaction.unitPrice, transaction.quantity > 1 {
                        Text(unitPrice, format: .currency(code: "EUR"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Category
                    Text(transaction.category.displayName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 8)

            // Price
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.itemPrice, format: .currency(code: "EUR"))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                // Health score label
                if let score = transaction.healthScore {
                    Text(score.healthScoreShortLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(score.healthScoreColor)
                }
            }
            .layoutPriority(1)  // Ensure price doesn't get compressed
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryColor: Color {
        switch transaction.category.color {
        case "red": return .red
        case "purple": return .purple
        case "orange": return .orange
        case "blue": return .blue
        case "gray": return .gray
        case "pink": return .pink
        case "green": return .green
        case "yellow": return .yellow
        case "brown": return .brown
        case "mint": return .mint
        case "cyan": return .cyan
        default: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    ReceiptDetailsView(
        receipt: ReceiptUploadResponse(
            receiptId: "123",
            status: .success,
            storeName: "Carrefour",
            receiptDate: "2026-01-20",
            totalAmount: 45.67,
            itemsCount: 5,
            transactions: [
                ReceiptTransaction(
                    itemName: "Milk",
                    itemPrice: 2.99,
                    quantity: 2,
                    unitPrice: 1.50,
                    category: .dairyAndEggs,
                    healthScore: 4
                ),
                ReceiptTransaction(
                    itemName: "Bread",
                    itemPrice: 3.49,
                    quantity: 1,
                    unitPrice: 3.49,
                    category: .bakery,
                    healthScore: 3
                ),
                ReceiptTransaction(
                    itemName: "Apples",
                    itemPrice: 4.99,
                    quantity: 1,
                    unitPrice: 4.99,
                    category: .freshProduce,
                    healthScore: 5
                ),
                ReceiptTransaction(
                    itemName: "Chicken Breast",
                    itemPrice: 8.99,
                    quantity: 1,
                    unitPrice: 8.99,
                    category: .meatAndFish,
                    healthScore: 4
                ),
                ReceiptTransaction(
                    itemName: "Cola",
                    itemPrice: 3.99,
                    quantity: 1,
                    unitPrice: 3.99,
                    category: .drinksSoftSoda,
                    healthScore: 1
                ),
                ReceiptTransaction(
                    itemName: "Paper Towels",
                    itemPrice: 5.99,
                    quantity: 1,
                    unitPrice: 5.99,
                    category: .household,
                    healthScore: nil  // Non-food item
                )
            ],
            warnings: [],
            averageHealthScore: 3.4
        )
    )
}
