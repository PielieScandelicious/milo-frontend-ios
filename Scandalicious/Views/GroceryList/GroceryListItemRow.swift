//
//  GroceryListItemRow.swift
//  Scandalicious
//
//  Grid cards for the grocery list — full (unchecked) and compact (in-cart) variants.
//

import SwiftUI

private let promoGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let promoGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
private let discountRed = Color(red: 0.95, green: 0.30, blue: 0.35)

private var promoGreenGradient: LinearGradient {
    LinearGradient(colors: [promoGreen, promoGreenDark], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Full Card (unchecked, "still to find")

struct GroceryListCard: View {
    let item: GroceryListItem
    let onTap: () -> Void
    let onRemove: () -> Void

    private var storeAccent: Color {
        GroceryStore.fromCanonical(item.storeName)?.accentColor ?? promoGreen
    }

    private var qty: Int { item.minPurchaseQty ?? 1 }
    private var userPays: Double {
        qty > 1 ? (item.originalPrice * Double(qty) - item.savings) : item.promoPrice
    }
    private var originalTotal: Double {
        qty > 1 ? item.originalPrice * Double(qty) : item.originalPrice
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                onRemove()
            } label: {
                Label(L("delete"), systemImage: "trash")
            }
        }
    }

    // MARK: - Image (thumbnail)

    private var imageSection: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .frame(height: 84)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                RemoteImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 72)
                        .padding(6)
                } placeholder: {
                    imagePlaceholder
                }
            } else {
                imagePlaceholder
            }

            if item.discountPercentage > 0 {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(discountRed))
                    .padding(5)
            }

            if let days = item.daysRemaining, days <= 2 {
                let style = validityBadgeStyle(days: days)
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HStack(spacing: 2) {
                            if let icon = style.icon {
                                Image(systemName: icon)
                                    .font(.system(size: 7, weight: .semibold))
                            }
                            Text(style.text)
                                .font(.system(size: 8, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(style.fg)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(style.bg))
                        .padding(5)
                    }
                }
            }
        }
        .frame(height: 84)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            StoreLogoView(storeName: item.storeName, height: 12)
                .frame(width: 20, height: 20)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .padding(5)
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            storeAccent.opacity(0.15)
            Text(String(item.label.prefix(1)).uppercased())
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundColor(storeAccent.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: 72)
    }

    // MARK: - Info (compact)

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(item.label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 30, alignment: .top)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(String(format: "€%.2f", userPays))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(promoGreenGradient)
                if item.savings > 0 {
                    Text(String(format: "€%.2f", originalTotal))
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.35))
                        .strikethrough(true, color: .white.opacity(0.35))
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func validityDisplay(days: Int) -> (text: String, color: Color, icon: String?) {
        if days < 0 { return ("Expired", .white.opacity(0.35), nil) }
        if days == 0 { return ("Last day!", Color(red: 0.95, green: 0.25, blue: 0.25), "exclamationmark.circle.fill") }
        if days <= 2 { return ("\(days) day\(days == 1 ? "" : "s") left", Color(red: 0.95, green: 0.40, blue: 0.30), "clock.badge.exclamationmark") }
        if days <= 5 { return ("\(days) days left", Color(red: 1.0, green: 0.75, blue: 0.25), "clock") }
        return ("\(days) days left", .white.opacity(0.5), "clock")
    }

    private func validityBadgeStyle(days: Int) -> (text: String, icon: String?, bg: Color, fg: Color) {
        if days < 0 {
            return ("Expired", "calendar.badge.exclamationmark", Color.black.opacity(0.55), .white.opacity(0.6))
        }
        if days == 0 {
            return ("Last day!", "exclamationmark.circle.fill", Color(red: 0.95, green: 0.25, blue: 0.25).opacity(0.85), .white)
        }
        if days <= 2 {
            return ("\(days) day\(days == 1 ? "" : "s") left", "clock.badge.exclamationmark", Color(red: 0.95, green: 0.40, blue: 0.30).opacity(0.85), .white)
        }
        if days <= 5 {
            return ("\(days) days left", "clock", Color(red: 1.0, green: 0.75, blue: 0.25).opacity(0.80), .black.opacity(0.85))
        }
        return ("\(days) days left", "clock", Color.black.opacity(0.55), .white.opacity(0.9))
    }
}

// MARK: - Compact Card (checked, "in cart")

struct GroceryListCompactCard: View {
    let item: GroceryListItem
    let onToggleChecked: () -> Void
    let onRemove: () -> Void

    private var storeAccent: Color {
        GroceryStore.fromCanonical(item.storeName)?.accentColor ?? promoGreen
    }

    var body: some View {
        Button(action: onToggleChecked) {
            HStack(spacing: 10) {
                thumbnail
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.55))
                        .strikethrough(true, color: .white.opacity(0.35))
                        .lineLimit(1)
                    if item.savings > 0 {
                        Text(String(format: "saved €%.2f", item.savings))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(promoGreen.opacity(0.75))
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(promoGreen.opacity(0.9))

                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(Color.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
            RemoteImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
                    .background(Color.white)
                    .opacity(0.75)
            } placeholder: {
                fallbackThumb
            }
        } else {
            fallbackThumb
        }
    }

    private var fallbackThumb: some View {
        ZStack {
            storeAccent.opacity(0.2)
            Text(String(item.label.prefix(1)).uppercased())
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundColor(storeAccent.opacity(0.7))
        }
    }
}
