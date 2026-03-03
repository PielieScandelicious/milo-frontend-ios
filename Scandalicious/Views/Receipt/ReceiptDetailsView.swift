//
//  ReceiptDetailsView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI

struct ReceiptDetailsView: View {
    let receipt: ReceiptUploadResponse

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Duplicate Warning Banner
                    if receipt.isDuplicate {
                        duplicateWarningBanner
                    }

                    // Header Section - Store and Totals
                    headerSection

                    // Items List (hide for duplicates since they weren't saved)
                    if !receipt.isDuplicate {
                        itemsSection
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L("receipt_details"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Duplicate Warning Banner

    private var duplicateWarningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(L("duplicate_receipt"))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(L("duplicate_receipt_msg"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
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
                    Text(L("total"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(totalAmount, format: .currency(code: "EUR"))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
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
            Text(L("items"))
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

            Text(L("no_items_found_receipt"))
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(L("no_items_detected"))
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
        HStack(alignment: .top, spacing: 12) {
            // Category Icon with Quantity Badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(categoryColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image.categorySymbol(transaction.category.categoryIcon)
                        .frame(width: 20, height: 20)
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
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(transaction.displayName)
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                        }

                        if let description = transaction.displayDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    // Quantity (show if > 1)
                    if transaction.quantity > 1 {
                        Text("\(L("qty")): \(transaction.quantity)")
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
                    Text(transaction.category.localizedCategoryName)
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

            }
            .layoutPriority(1)  // Ensure price doesn't get compressed
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var categoryColor: Color {
        transaction.category.categoryColor
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
                    category: "Dairy & Eggs",
                ),
                ReceiptTransaction(
                    itemName: "Bread",
                    itemPrice: 3.49,
                    quantity: 1,
                    unitPrice: 3.49,
                    category: "Bakery"
                ),
                ReceiptTransaction(
                    itemName: "Apples",
                    itemPrice: 4.99,
                    quantity: 1,
                    unitPrice: 4.99,
                    category: "Fresh Produce"
                ),
                ReceiptTransaction(
                    itemName: "Chicken Breast",
                    itemPrice: 8.99,
                    quantity: 1,
                    unitPrice: 8.99,
                    category: "Meat & Fish"
                ),
                ReceiptTransaction(
                    itemName: "Cola",
                    itemPrice: 3.99,
                    quantity: 1,
                    unitPrice: 3.99,
                    category: "Drinks (Soft/Soda)"
                ),
                ReceiptTransaction(
                    itemName: "Paper Towels",
                    itemPrice: 5.99,
                    quantity: 1,
                    unitPrice: 5.99,
                    category: "Household"
                )
            ],
            warnings: []
        )
    )
}

#Preview("Duplicate Receipt") {
    ReceiptDetailsView(
        receipt: ReceiptUploadResponse(
            receiptId: "456",
            status: .success,
            storeName: "Lidl",
            receiptDate: "2026-01-22",
            totalAmount: 28.50,
            itemsCount: 3,
            transactions: [
                ReceiptTransaction(
                    itemName: "Bananas",
                    itemPrice: 1.99,
                    quantity: 1,
                    unitPrice: 1.99,
                    category: "Fresh Produce"
                ),
                ReceiptTransaction(
                    itemName: "Yogurt",
                    itemPrice: 3.49,
                    quantity: 1,
                    unitPrice: 3.49,
                    category: "Dairy & Eggs"
                )
            ],
            warnings: [],
            isDuplicate: true
        )
    )
}
