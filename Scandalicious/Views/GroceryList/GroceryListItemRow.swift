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
private let giftGold = Color(red: 1.0, green: 0.82, blue: 0.30)
private let brandGold = Color(red: 0.95, green: 0.80, blue: 0.20)

private var promoGreenGradient: LinearGradient {
    LinearGradient(colors: [promoGreen, promoGreenDark], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private func groceryDealBadge(for item: GroceryListItem) -> (text: String, icon: String?, bg: Color, fg: Color)? {
    let mech = item.mechanismLabel.lowercased()
    let qty = item.minPurchaseQty ?? 1

    if qty > 1 {
        if let r = mech.range(of: #"\d+\s*\+\s*\d+"#, options: .regularExpression) {
            let compact = mech[r].replacingOccurrences(of: " ", with: "")
            return (compact, nil, promoGreen, .white)
        }
        if let (n, price) = parseForPriceMechanism(mech) {
            return ("\(n)×€\(price)", nil, promoGreen, .white)
        }
        return ("\(qty)×", nil, promoGreen, .white)
    }
    if mech.contains("gratis") || mech.contains("free") || mech.contains("cadeau") {
        return ("FREE", "gift.fill", giftGold, .black.opacity(0.85))
    }
    if item.discountPercentage > 0 {
        return ("-\(item.discountPercentage)%", nil, discountRed, .white)
    }
    if item.savings > 0 {
        return (String(format: "-€%.2f", item.savings), nil, discountRed, .white)
    }
    return nil
}

private func parseForPriceMechanism(_ text: String) -> (Int, String)? {
    let pattern = #"(\d+)\s*(?:voor|for|pour)\s*€?\s*(\d+(?:[.,]\d+)?)"#
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range),
          match.numberOfRanges >= 3,
          let nRange = Range(match.range(at: 1), in: text),
          let pRange = Range(match.range(at: 2), in: text),
          let n = Int(text[nRange]) else { return nil }
    let priceRaw = text[pRange].replacingOccurrences(of: ",", with: ".")
    let priceDouble = Double(priceRaw) ?? 0
    let priceStr = priceDouble == floor(priceDouble)
        ? "\(Int(priceDouble))"
        : String(format: "%.2f", priceDouble)
    return (n, priceStr)
}

// MARK: - Full Card (unchecked, "still to find")

struct GroceryListCard: View {
    let item: GroceryListItem
    let onTap: () -> Void
    let onRemove: () -> Void

    private var storeAccent: Color {
        GroceryStore.fromCanonical(item.storeName)?.accentColor ?? promoGreen
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
                validityFooter
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .frame(height: 140)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                RemoteImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 120)
                        .padding(8)
                } placeholder: {
                    imagePlaceholder
                }
            } else {
                imagePlaceholder
            }

            if let badge = groceryDealBadge(for: item) {
                HStack(spacing: 3) {
                    if let icon = badge.icon {
                        Image(systemName: icon)
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(badge.text)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(badge.fg)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(badge.bg))
                .shadow(color: badge.bg.opacity(0.3), radius: 3, y: 1)
                .padding(6)
            }
        }
        .frame(height: 140)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            StoreLogoView(storeName: item.storeName, height: 14)
                .frame(width: 22, height: 22)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            removeButton
        }
    }

    private var removeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onRemove()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("delete"))
    }

    private var imagePlaceholder: some View {
        ZStack {
            storeAccent.opacity(0.15)
            Text(String(item.label.prefix(1)).uppercased())
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(storeAccent.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: 120)
    }

    // MARK: - Info (compact)

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(PromoDesign.brandAccent)
                    .lineLimit(1)
            }

            Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 34, alignment: .top)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(promoGreenGradient)
                if item.originalPrice > item.promoPrice {
                    Text(String(format: "€%.2f", item.originalPrice))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                        .strikethrough(true, color: .white.opacity(0.35))
                }
            }
        }
        .padding(10)
    }

    // MARK: - Validity footer

    private var validityFooter: some View {
        let d = PromoValidity.display(for: item.validityEnd)
        return HStack(spacing: 4) {
            if let icon = d.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(d.text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(d.isUrgent ? d.color.opacity(0.85) : Color.white.opacity(0.35))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

}

// MARK: - Coupon Card (matches promo card layout, with coupon reward label)

struct GroceryListCouponCard: View {
    let item: GroceryListItem
    let onTap: () -> Void
    let onRemove: () -> Void

    private var storeAccent: Color {
        GroceryStore.fromCanonical(item.storeName)?.accentColor ?? promoGreen
    }

    private var rewardLabel: String {
        guard let value = item.couponValue else { return L("coupon_generic") }
        switch item.couponType {
        case "loyalty_points": return "+\(Int(value.rounded())) \(L("coupon_points_unit"))"
        case "cashback": return String(format: "€%.2f", value).replacingOccurrences(of: ".", with: ",")
        case "percent_off_coupon": return "-\(Int(value.rounded()))%"
        case "free_product": return L("coupon_free_product")
        default: return L("coupon_generic")
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
                validityFooter
            }
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
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

    private var imageSection: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .frame(height: 140)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                RemoteImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 120)
                        .padding(8)
                } placeholder: {
                    imagePlaceholder
                }
            } else {
                imagePlaceholder
            }

            HStack(spacing: 3) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 9, weight: .bold))
                Text("COUPON")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
            }
            .foregroundColor(.black.opacity(0.85))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(brandGold))
            .shadow(color: brandGold.opacity(0.3), radius: 3, y: 1)
            .padding(6)
        }
        .frame(height: 140)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            StoreLogoView(storeName: item.storeName, height: 14)
                .frame(width: 22, height: 22)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .padding(6)
        }
        .overlay(alignment: .topTrailing) {
            removeButton
        }
    }

    private var removeButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onRemove()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("delete"))
    }

    private var imagePlaceholder: some View {
        ZStack {
            storeAccent.opacity(0.15)
            Image(systemName: "ticket.fill")
                .font(.system(size: 40, weight: .heavy))
                .foregroundColor(storeAccent.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: 120)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.0)
                    .foregroundStyle(PromoDesign.brandAccent)
                    .lineLimit(1)
            }

            Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 34, alignment: .top)

            Text(rewardLabel)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(promoGreenGradient)
                .lineLimit(1)
        }
        .padding(10)
    }

    private var validityFooter: some View {
        let d = PromoValidity.display(for: item.validityEnd)
        return HStack(spacing: 4) {
            if let icon = d.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(d.text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .foregroundStyle(d.isUrgent ? d.color.opacity(0.85) : Color.white.opacity(0.35))
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
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
