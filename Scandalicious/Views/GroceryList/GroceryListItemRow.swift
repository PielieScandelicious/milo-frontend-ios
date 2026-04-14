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
    let onToggleChecked: () -> Void
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
        Button(action: onToggleChecked) {
            VStack(alignment: .leading, spacing: 0) {
                imageSection
                infoSection
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
            Button {
                onToggleChecked()
            } label: {
                Label("Mark as in cart", systemImage: "cart.badge.plus")
            }
        }
    }

    // MARK: - Image

    private var imageSection: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .frame(height: 140)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 120)
                            .padding(8)
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

            // Discount badge (top-left)
            if item.discountPercentage > 0 {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(discountRed))
                    .shadow(color: discountRed.opacity(0.35), radius: 4, y: 2)
                    .padding(8)
            }

            // Remove button (top-right)
            VStack {
                HStack {
                    Spacer()
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.black.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle())
                    .padding(6)
                }
                Spacer()
            }

            // Savings badge (bottom-right on image)
            if item.savings > 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(String(format: "save €%.2f", item.savings))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(promoGreenGradient)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white))
                            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
                            .padding(8)
                    }
                }
            }

            // Store logo (bottom-left)
            VStack {
                Spacer()
                HStack {
                    StoreLogoView(storeName: item.storeName, height: 14)
                        .frame(width: 22, height: 22)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
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
        ZStack {
            storeAccent.opacity(0.15)
            Text(String(item.label.prefix(1)).uppercased())
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(storeAccent.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: 120)
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.8)
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 34, alignment: .top)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(String(format: "€%.2f", userPays))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(promoGreenGradient)
                Text(String(format: "€%.2f", originalTotal))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
                    .strikethrough(true, color: .white.opacity(0.35))
            }

            if !item.mechanismLabel.isEmpty {
                Text(item.mechanismLabel)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(10)
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
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                        .background(Color.white)
                        .opacity(0.75)
                default:
                    fallbackThumb
                }
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
