//
//  ReceiptDetailsView.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI

struct ReceiptDetailsView: View {
    let receipt: ReceiptUploadResponse
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showDeleteError = false
    @State private var showSplitView = false

    /// Observe split cache for updates
    @ObservedObject private var splitCache = SplitCacheManager.shared

    /// Get cached split data for this receipt
    private var splitData: CachedSplitData? {
        splitCache.getSplit(for: receipt.receiptId)
    }

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
                        // Split with Friends Button
                        if !receipt.transactions.isEmpty {
                            splitButton
                        }

                        itemsSection

                        // Delete Button
                        deleteButton
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(L("receipt_details"))
            .navigationBarTitleDisplayMode(.inline)
            .alert(L("delete_failed"), isPresented: $showDeleteError) {
                Button(L("ok"), role: .cancel) {}
            } message: {
                Text(deleteError ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showSplitView) {
                SplitExpenseView(receipt: receipt)
            }
            .task {
                // Fetch split data if not already cached
                if splitData == nil {
                    await splitCache.fetchSplit(for: receipt.receiptId)
                }
            }
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

            // Health Score (if available)
            if let healthScore = receipt.calculatedAverageHealthScore {
                Divider()
                    .padding(.vertical, 4)

                HStack(spacing: 12) {
                    HealthScoreGauge(score: healthScore, size: 60, showLabel: false)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L("health_score"))
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

    // MARK: - Split Button

    private var splitButton: some View {
        Button {
            showSplitView = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L("split_with_friends"))
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(L("divide_receipt"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
                // Get split participants for this item
                let participants: [SplitParticipantInfo] = {
                    guard let itemId = transaction.itemId,
                          let split = splitData else { return [] }
                    return split.participantsForTransaction(itemId)
                }()

                ReceiptItemRow(transaction: transaction, splitParticipants: participants)
            }
        }
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(role: .destructive) {
            Task {
                await deleteReceipt()
            }
        } label: {
            HStack {
                if isDeleting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "trash")
                }
                Text(isDeleting ? L("deleting") : L("delete_receipt"))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(isDeleting ? 0.5 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isDeleting)
        .padding(.top, 16)
    }

    // MARK: - Delete Receipt

    private func deleteReceipt() async {
        isDeleting = true

        do {
            try await AnalyticsAPIService.shared.removeReceipt(receiptId: receipt.receiptId)

            await MainActor.run {
                onDelete?()
                dismiss()
            }
        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
                showDeleteError = true
                isDeleting = false
            }
        }
    }
}

// MARK: - Receipt Item Row

struct ReceiptItemRow: View {
    let transaction: ReceiptTransaction
    var splitParticipants: [SplitParticipantInfo] = []

    /// Filter out "Me" - only show friends
    private var friendsOnly: [SplitParticipantInfo] {
        splitParticipants.filter { !$0.isMe }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Category Icon with Quantity Badge
            ZStack(alignment: .topTrailing) {
                CategoryIconBadge(
                    icon: transaction.category.categoryIcon,
                    color: categoryColor,
                    size: 44
                )

                // Quantity badge (show if > 1)
                if transaction.quantity > 1 {
                    Text("×\(transaction.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(categoryColor.adjustBrightness(by: -0.25))
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

                            // Split participant avatars (friends only)
                            if !friendsOnly.isEmpty {
                                ReceiptItemSplitAvatars(participants: friendsOnly)
                            }
                        }

                        if let description = transaction.displayDescription {
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }

                    Spacer(minLength: 0)

                    // Health Score Badge
                    HealthScoreBadge(score: transaction.healthScore, size: .small, style: .subtle)
                        .layoutPriority(1)
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
        transaction.category.categoryColor
    }
}

// MARK: - Receipt Item Split Avatars

/// Compact display of friend avatars for split items in ReceiptDetailsView
struct ReceiptItemSplitAvatars: View {
    let participants: [SplitParticipantInfo]

    /// Maximum avatars to show before "+N"
    private let maxVisible = 3

    var body: some View {
        if !participants.isEmpty {
            HStack(spacing: -4) {
                // Show up to maxVisible avatars
                ForEach(Array(participants.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                    Circle()
                        .fill(participant.swiftUIColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text(String(participant.name.prefix(1)).uppercased())
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
                        )
                        .zIndex(Double(maxVisible - index))
                }

                // Show "+N" if more participants
                if participants.count > maxVisible {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Text("+\(participants.count - maxVisible)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.primary.opacity(0.7))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
                        )
                }
            }
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
                    category: "Dairy & Eggs",
                    healthScore: 4
                ),
                ReceiptTransaction(
                    itemName: "Bread",
                    itemPrice: 3.49,
                    quantity: 1,
                    unitPrice: 3.49,
                    category: "Bakery",
                    healthScore: 3
                ),
                ReceiptTransaction(
                    itemName: "Apples",
                    itemPrice: 4.99,
                    quantity: 1,
                    unitPrice: 4.99,
                    category: "Fresh Produce",
                    healthScore: 5
                ),
                ReceiptTransaction(
                    itemName: "Chicken Breast",
                    itemPrice: 8.99,
                    quantity: 1,
                    unitPrice: 8.99,
                    category: "Meat & Fish",
                    healthScore: 4
                ),
                ReceiptTransaction(
                    itemName: "Cola",
                    itemPrice: 3.99,
                    quantity: 1,
                    unitPrice: 3.99,
                    category: "Drinks (Soft/Soda)",
                    healthScore: 1
                ),
                ReceiptTransaction(
                    itemName: "Paper Towels",
                    itemPrice: 5.99,
                    quantity: 1,
                    unitPrice: 5.99,
                    category: "Household",
                    healthScore: nil  // Non-food item
                )
            ],
            warnings: [],
            averageHealthScore: 3.4
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
                    category: "Fresh Produce",
                    healthScore: 5
                ),
                ReceiptTransaction(
                    itemName: "Yogurt",
                    itemPrice: 3.49,
                    quantity: 1,
                    unitPrice: 3.49,
                    category: "Dairy & Eggs",
                    healthScore: 4
                )
            ],
            warnings: [],
            averageHealthScore: 4.5,
            isDuplicate: true
        )
    )
}
