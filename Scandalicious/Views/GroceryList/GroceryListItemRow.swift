//
//  GroceryListItemRow.swift
//  Scandalicious
//

import SwiftUI

struct GroceryListItemRow: View {
    let item: GroceryListItem
    let onToggleChecked: () -> Void
    let onDelete: () -> Void

    private let promoGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
    private let promoGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)

    private var greenGradient: LinearGradient {
        LinearGradient(
            colors: [promoGreen, promoGreenDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(item.storeName)?.accentColor ?? promoGreen
    }

    var body: some View {
        Button {
            onToggleChecked()
        } label: {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(item.isChecked ? storeAccentColor : .white.opacity(0.3))

                // Item info
                VStack(alignment: .leading, spacing: 3) {
                    if !item.brand.isEmpty {
                        Text(item.brand.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(item.isChecked ? 0.3 : 0.6))
                            .tracking(0.5)
                            .lineLimit(1)
                    }

                    Text(item.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(item.isChecked ? 0.3 : 1.0))
                        .strikethrough(item.isChecked, color: .white.opacity(0.3))
                        .lineLimit(2)

                    Text(item.mechanismLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(item.isChecked ? 0.2 : 0.45))
                }

                Spacer(minLength: 4)

                // Price — matches Deals tab layout
                priceView
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label(L("delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - Price View (mirrors PromoItemRow in Deals tab)

    @ViewBuilder
    private var priceView: some View {
        let checkedOpacity: Double = item.isChecked ? 0.3 : 1.0
        let qty = item.minPurchaseQty ?? 1

        if qty > 1 {
            // Multi-buy: show total price user pays for the full deal
            let totalOriginal = item.originalPrice * Double(qty)
            let totalUserPays = totalOriginal - item.savings

            VStack(alignment: .trailing, spacing: 4) {
                if item.discountPercentage > 0 {
                    discountBadge
                        .opacity(checkedOpacity)
                }
                Text(String(format: "€%.2f", totalUserPays))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(item.isChecked ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(greenGradient))
                Text(String(format: "€%.2f", totalOriginal))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(item.isChecked ? 0.15 : 0.3))
                    .strikethrough(true, color: .white.opacity(item.isChecked ? 0.15 : 0.3))
            }
            .fixedSize()
        } else {
            // Single-item: show per-unit prices
            VStack(alignment: .trailing, spacing: 4) {
                if item.discountPercentage > 0 {
                    discountBadge
                        .opacity(checkedOpacity)
                }
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(item.isChecked ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(greenGradient))
                Text(String(format: "€%.2f", item.originalPrice))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(item.isChecked ? 0.15 : 0.3))
                    .strikethrough(true, color: .white.opacity(item.isChecked ? 0.15 : 0.3))
            }
            .fixedSize()
        }
    }

    private var discountBadge: some View {
        Text("-\(item.discountPercentage)%")
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(greenGradient)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(promoGreen.opacity(0.15)))
    }
}
