//
//  PromoProductCard.swift
//  Scandalicious
//
//  Premium product card for the 2-column promo grid.
//

import SwiftUI

struct PromoProductCard: View {
    let gridItem: PromoGridItem
    let index: Int
    let onTap: () -> Void

    @ObservedObject private var groceryStore = GroceryListStore.shared
    @State private var appeared = false
    @State private var addTrigger = false

    private var item: PromoStoreItem { gridItem.item }
    private var storeName: String { gridItem.storeName }

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(storeName)?.accentColor ?? promoCardGreen
    }

    private var isSpecialDeal: Bool {
        let mech = item.mechanismLabel.lowercased()
        return mech.contains("gratis") || mech.contains("free") || mech.contains("cadeau")
    }

    private var mechanismPillColor: Color {
        if (item.minPurchaseQty ?? 1) > 1 { return promoCardGreen }
        if isSpecialDeal { return promoCardGold }
        return .white.opacity(0.7)
    }

    private var discountBadgeColor: Color {
        item.discountPercentage > 30
            ? Color(red: 0.95, green: 0.25, blue: 0.25)
            : promoCardGreen
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.04)) {
                appeared = true
            }
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            // White background for product image
            Color(white: 0.97)
                .frame(height: 160)

            // Product image
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 140)
                            .padding(10)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 140)
                    @unknown default:
                        imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }

            // Discount badge (top-right)
            if item.discountPercentage > 0 {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(discountBadgeColor))
                    .shadow(color: discountBadgeColor.opacity(0.4), radius: 4, y: 2)
                    .padding(8)
            }

            // Store logo (bottom-left)
            VStack {
                Spacer()
                HStack {
                    StoreLogoView(storeName: storeName, height: 16)
                        .frame(width: 24, height: 24)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 2, y: 1)
                        .padding(8)
                    Spacer()
                }
            }
        }
        .frame(height: 160)
        .clipped()
    }

    private var imagePlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 32, weight: .light))
            .foregroundColor(Color(white: 0.8))
            .frame(maxWidth: .infinity, maxHeight: 140)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Brand
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(.white.opacity(0.4))
                    .lineLimit(1)
            }

            // Product name
            Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // Mechanism pill
            HStack(spacing: 4) {
                if (item.minPurchaseQty ?? 1) > 1 {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 9, weight: .semibold))
                } else if isSpecialDeal {
                    Image(systemName: "sparkles")
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(item.mechanismLabel)
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(mechanismPillColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(mechanismPillColor.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(mechanismPillColor.opacity(0.2), lineWidth: 0.5)
            )
            .fixedSize()

            // Prices
            if item.hasPrices {
                priceSection
            }

            // Savings pill
            if item.savings > 0 {
                Text(String(format: "Save €%.2f", item.savings))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(promoCardGreen)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().fill(promoCardGreen.opacity(0.10))
                    )
            }

            // Info chips (unit price, min qty)
            if hasInfoChips {
                VStack(alignment: .leading, spacing: 4) {
                    if let unitPrice = item.displayUnitPrice, !unitPrice.isEmpty {
                        infoChip(icon: "scalemass", text: unitPrice)
                    }
                    if let qty = item.minPurchaseQty, qty > 1 {
                        infoChip(icon: "number", text: "Min. \(qty)")
                    }
                }
            }

            // Validity + Add button
            HStack {
                Text(validityText)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if groceryStore.contains(item: item, storeName: storeName) {
                            groceryStore.removeByPromo(item: item, storeName: storeName)
                        } else {
                            groceryStore.add(item: item, storeName: storeName)
                        }
                        addTrigger.toggle()
                    }
                } label: {
                    Image(systemName: groceryStore.contains(item: item, storeName: storeName) ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(groceryStore.contains(item: item, storeName: storeName) ? promoCardGreen : promoCardGreen.opacity(0.7))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: addTrigger)
            }
        }
        .padding(10)
        .background(Color(white: 0.08))
    }

    // MARK: - Price Section

    @ViewBuilder
    private var priceSection: some View {
        let qty = item.minPurchaseQty ?? 1
        if qty > 1 {
            let totalOriginal = item.originalPrice * Double(qty)
            let totalUserPays = totalOriginal - item.savings
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "€%.2f", totalUserPays))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(promoCardGreenGradient)
                Text(String(format: "€%.2f", totalOriginal))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(promoCardGreenGradient)
                Text(String(format: "€%.2f", item.originalPrice))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
        }
    }

    // MARK: - Info Chips

    private var hasInfoChips: Bool {
        (item.displayUnitPrice != nil && !(item.displayUnitPrice?.isEmpty ?? true))
        || (item.minPurchaseQty ?? 0) > 1
    }

    private func infoChip(icon: String, text: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.5))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Validity

    private var validityText: String {
        // Show "Valid until DD/MM" from validity_end (yyyy-MM-dd format)
        let parts = item.validityEnd.split(separator: "-")
        if parts.count == 3 {
            return "Until \(parts[2])/\(parts[1])"
        }
        return item.validityEnd
    }
}

// MARK: - Card-local color constants

private let promoCardGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let promoCardGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
private let promoCardGold = Color(red: 1.00, green: 0.80, blue: 0.20)

private var promoCardGreenGradient: LinearGradient {
    LinearGradient(
        colors: [promoCardGreen, promoCardGreenDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
