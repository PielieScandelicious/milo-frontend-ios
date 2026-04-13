//
//  PromoProductCard.swift
//  Scandalicious
//
//  Premium product card for the 2-column promo grid.
//  Fixed-height card with brand-forward design and urgency-aware validity.
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
        return Color(white: 0.18)
    }

    private var mechanismTextColor: Color {
        if isSpecialDeal { return .black.opacity(0.8) }
        if (item.minPurchaseQty ?? 1) > 1 { return .white }
        return .white.opacity(0.8)
    }

    private var discountBadgeColor: Color {
        item.discountPercentage > 30
            ? Color(red: 0.95, green: 0.25, blue: 0.25)
            : promoCardGreen
    }

    // MARK: - Validity computation

    private var daysRemaining: Int? {
        let parts = item.validityEnd.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let endDate = Calendar.current.date(from: components) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: endDate)
        return Calendar.current.dateComponents([.day], from: today, to: end).day
    }

    private var validityDisplay: (text: String, color: Color, icon: String?) {
        guard let days = daysRemaining else {
            return (validityFallbackText, .white.opacity(0.4), nil)
        }
        switch days {
        case _ where days < 0:
            return ("Expired", .white.opacity(0.25), nil)
        case 0:
            return ("Last day!", promoUrgentRed, "exclamationmark.circle.fill")
        case 1...2:
            return ("\(days) day\(days == 1 ? "" : "s") left", promoUrgentOrange, "clock.badge.exclamationmark")
        case 3...5:
            return ("\(days) days left", promoWarningAmber, "clock")
        default:
            return ("\(days) days left", .white.opacity(0.4), nil)
        }
    }

    private var validityFallbackText: String {
        let parts = item.validityEnd.split(separator: "-")
        if parts.count == 3 {
            return "Until \(parts[2])/\(parts[1])"
        }
        return item.validityEnd
    }

    // MARK: - Body

    static let cardHeight: CGFloat = 340

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
            }
            .frame(height: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(white: 0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
        .onAppear {
            withAnimation(.smooth(duration: 0.4).delay(Double(index) * 0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Image Section

    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            Color(white: 0.97)
                .frame(height: 140)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 120)
                            .padding(10)
                    case .failure:
                        imagePlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 120)
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
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
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
        .frame(height: 140)
        .clipped()
    }

    private var imagePlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 32, weight: .light))
            .foregroundColor(Color(white: 0.8))
            .frame(maxWidth: .infinity, maxHeight: 120)
    }

    // MARK: - Info Section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Brand
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.0)
                    .foregroundColor(storeAccentColor.opacity(0.9))
                    .lineLimit(1)
            }

            // Product name — fixed height area, scales down for long names
            Text(item.label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 48, alignment: .topLeading)

            // Mechanism pill — solid filled capsule
            HStack(spacing: 4) {
                if (item.minPurchaseQty ?? 1) > 1 {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 10, weight: .semibold))
                } else if isSpecialDeal {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                }
                Text(item.mechanismLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundColor(mechanismTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(mechanismPillColor))

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

            Spacer(minLength: 0)

            // Validity + Add button (pinned to bottom)
            HStack(spacing: 4) {
                validityLabel
                Spacer(minLength: 4)
                addButton
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(10)
        .background(Color(white: 0.09))
    }

    // MARK: - Validity Label

    private var validityLabel: some View {
        let display = validityDisplay
        let isUrgent = (daysRemaining ?? 99) <= 2

        return HStack(spacing: 3) {
            if let icon = display.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(display.text)
                .font(.system(size: 10, weight: isUrgent ? .semibold : .regular))
        }
        .foregroundColor(display.color)
        .padding(.horizontal, isUrgent ? 6 : 0)
        .padding(.vertical, isUrgent ? 3 : 0)
        .background(
            Group {
                if isUrgent {
                    Capsule().fill(display.color.opacity(0.12))
                }
            }
        )
        .lineLimit(1)
    }

    // MARK: - Add Button

    private var addButton: some View {
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

    // MARK: - Price Section

    @ViewBuilder
    private var priceSection: some View {
        let qty = item.minPurchaseQty ?? 1
        if qty > 1 {
            let totalOriginal = item.originalPrice * Double(qty)
            let totalUserPays = totalOriginal - item.savings
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "€%.2f", totalUserPays))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(promoCardGreen)
                Text(String(format: "€%.2f", totalOriginal))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(promoCardGreen)
                Text(String(format: "€%.2f", item.originalPrice))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
        }
    }
}

// MARK: - Card-local color constants

private let promoCardGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let promoCardGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
private let promoCardGold = Color(red: 1.00, green: 0.80, blue: 0.20)
private let promoWarningAmber = Color(red: 1.0, green: 0.75, blue: 0.25)
private let promoUrgentOrange = Color(red: 0.95, green: 0.40, blue: 0.30)
private let promoUrgentRed = Color(red: 0.95, green: 0.25, blue: 0.25)
