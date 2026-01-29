//
//  ExpandableReceiptCard.swift
//  Scandalicious
//
//  Unified receipt card component with expandable transaction dropdown.
//  Used consistently throughout the app for receipt display.
//

import SwiftUI

// MARK: - Receipt Display Protocol

/// Protocol for displaying receipts uniformly across the app
protocol ReceiptDisplayable: Identifiable {
    var displayId: String { get }
    var displayStoreName: String { get }
    var displayDate: Date? { get }
    var displayDateString: String? { get }
    var displayTotalAmount: Double { get }
    var displayItemsCount: Int { get }
    var displayTransactions: [ReceiptItemDisplayable] { get }
    var displayHealthScore: Double? { get }
}

/// Protocol for displaying receipt items uniformly
protocol ReceiptItemDisplayable: Identifiable {
    var displayItemName: String { get }
    var displayItemPrice: Double { get }
    var displayQuantity: Int { get }
    var displayHealthScore: Int? { get }
}

// MARK: - APIReceipt Conformance

extension APIReceipt: ReceiptDisplayable {
    var displayId: String { receiptId }
    // Note: displayStoreName and displayTotalAmount already exist in APIReceipt
    var displayDate: Date? { dateParsed }
    var displayDateString: String? { receiptDate }
    var displayItemsCount: Int { itemsCount }
    var displayTransactions: [ReceiptItemDisplayable] { transactions }
    var displayHealthScore: Double? { averageHealthScore }
}

extension APIReceiptItem: ReceiptItemDisplayable {
    var displayItemName: String { itemName }
    var displayItemPrice: Double { itemPrice }
    var displayQuantity: Int { quantity }
    var displayHealthScore: Int? { healthScore }
}

// MARK: - ReceiptUploadResponse Conformance

extension ReceiptUploadResponse: Identifiable {
    var id: String { receiptId }
}

extension ReceiptUploadResponse: ReceiptDisplayable {
    var displayId: String { receiptId }
    var displayStoreName: String { storeName ?? "Unknown Store" }
    var displayDate: Date? { parsedDate }
    var displayDateString: String? { receiptDate }
    var displayTotalAmount: Double { totalAmount ?? 0 }
    var displayItemsCount: Int { itemsCount }
    var displayTransactions: [ReceiptItemDisplayable] { transactions }
    var displayHealthScore: Double? { averageHealthScore }
}

extension ReceiptTransaction: ReceiptItemDisplayable {
    var displayItemName: String { itemName }
    var displayItemPrice: Double { itemPrice }
    var displayQuantity: Int { quantity }
    var displayHealthScore: Int? { healthScore }
}

// MARK: - Expandable Receipt Card

/// A unified receipt card component with expandable transaction dropdown.
/// Use this component anywhere receipts need to be displayed for consistency.
struct ExpandableReceiptCard<Receipt: ReceiptDisplayable>: View {
    let receipt: Receipt
    let isExpanded: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    /// Optional accent color for the card (e.g., green for "Recent Scan")
    var accentColor: Color = .white

    /// Optional badge text (e.g., "Recent Scan")
    var badgeText: String? = nil

    @State private var showDeleteConfirmation = false

    init(
        receipt: Receipt,
        isExpanded: Bool,
        onTap: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        accentColor: Color = .white,
        badgeText: String? = nil
    ) {
        self.receipt = receipt
        self.isExpanded = isExpanded
        self.onTap = onTap
        self.onDelete = onDelete
        self.accentColor = accentColor
        self.badgeText = badgeText
    }

    private var formattedDate: String {
        guard let date = receipt.displayDate else {
            return receipt.displayDateString ?? "Unknown"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private var formattedTime: String {
        guard let date = receipt.displayDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private var itemCount: Int {
        receipt.displayItemsCount
    }

    private var hasAccent: Bool {
        accentColor != .white
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main card content - always visible
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Store icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(hasAccent ? accentColor.opacity(0.15) : Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)

                        Image(systemName: "cart.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(hasAccent ? accentColor : .white.opacity(0.6))
                    }

                    // Store name and date
                    VStack(alignment: .leading, spacing: 4) {
                        // Badge if present
                        if let badge = badgeText {
                            Text(badge)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(accentColor)
                        }

                        Text(receipt.displayStoreName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(formattedDate)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))

                            if !formattedTime.isEmpty {
                                Text("•")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white.opacity(0.3))
                                Text(formattedTime)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }

                    Spacer()

                    // Total amount
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(String(format: "€%.2f", receipt.displayTotalAmount))
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("\(itemCount) item\(itemCount == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }

                    // Chevron indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                        .frame(width: 20)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(ExpandableReceiptCardButtonStyle())

            // Expanded content - show ALL items
            if isExpanded {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 14)

                    // All items
                    if !receipt.displayTransactions.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(Array(receipt.displayTransactions.enumerated()), id: \.offset) { _, item in
                                HStack(spacing: 8) {
                                    if item.displayQuantity > 1 {
                                        Text("×\(item.displayQuantity)")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.4))
                                    }

                                    Text(item.displayItemName)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                        .lineLimit(2)

                                    Spacer()

                                    Text(String(format: "€%.2f", item.displayItemPrice))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }

                    // Delete button only (if delete action provided)
                    if let deleteAction = onDelete {
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Delete Receipt")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(.red.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.red.opacity(0.08))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .confirmationDialog("Delete Receipt", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                            Button("Delete", role: .destructive) {
                                deleteAction()
                            }
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to delete this receipt? This action cannot be undone.")
                        }
                    }
                }
                .transition(.opacity)
            }
        }
        .background(
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            (hasAccent ? accentColor : Color.white).opacity(isExpanded ? 0.15 : 0.1),
                            (hasAccent ? accentColor : Color.white).opacity(isExpanded ? 0.06 : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Button Style

struct ExpandableReceiptCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.04 : 0))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 16) {
            // Preview would go here with mock data
            Text("ExpandableReceiptCard Preview")
                .foregroundColor(.white)
        }
        .padding()
    }
}
