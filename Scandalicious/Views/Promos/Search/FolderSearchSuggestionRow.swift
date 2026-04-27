//
//  FolderSearchSuggestionRow.swift
//  Scandalicious
//
//  Rich product card row used inside the focused search overlay.
//  Tap → opens PromoProductDetailSheet via the parent's .sheet(item:).
//

import SwiftUI

struct FolderSearchSuggestionRow: View {
    let item: PromoStoreItem
    let onTap: () -> Void

    private var thumbnailURL: URL? {
        if let s = item.thumbnailUrl, let u = URL(string: s) { return u }
        if let s = item.imageUrl, let u = URL(string: s) { return u }
        return nil
    }

    private var brandLabel: String {
        let p = item.primaryBrandLabel
        return p.isEmpty ? "—" : p
    }

    private var priceLabel: String {
        if item.priceUnavailable {
            return ""
        }
        let value = item.promoPrice > 0 ? item.promoPrice : item.originalPrice
        return String(format: "€%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private var savingsText: String? {
        let label = item.displaySavingsLabel ?? ""
        return label.isEmpty ? nil : label
    }

    private var store: GroceryStore? {
        guard let name = item.storeName else { return nil }
        return GroceryStore.fromCanonical(name)
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                // Top row: brand (gold, uppercased) on left · store logo on right
                HStack(spacing: 8) {
                    if !brandLabel.isEmpty, brandLabel != "—" {
                        Text(brandLabel.uppercased())
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .tracking(0.6)
                            .foregroundStyle(PromoDesign.brandAccent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Spacer(minLength: 8)
                    if let store {
                        Image(store.logoImageName)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 60, maxHeight: 20)
                            .frame(height: 20)
                            .opacity(0.85)
                            .padding(.top, 4)
                    } else if let raw = item.storeName {
                        Text(raw.capitalized)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }

                Color.clear.frame(height: 6)

                // Main row: [thumbnail + validity below it] + product name + price/savings
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 6) {
                        thumbnail
                        if !item.validityEnd.isEmpty {
                            ValidityChip(validityEnd: item.validityEnd, compact: true)
                        }
                    }
                    .frame(width: 68)

                    productNameText
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 5) {
                        if !priceLabel.isEmpty {
                            Text(priceLabel)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .minimumScaleFactor(0.8)
                                .lineLimit(1)
                        }
                        if let savings = savingsText {
                            Text(savings)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.green.opacity(0.85))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                    .frame(height: 68, alignment: .center)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: 128)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Picks the largest font that lets the full product name fit without
    /// truncation, falling back to smaller sizes when the row's vertical space
    /// is exceeded. ViewThatFits measures each candidate's natural height and
    /// picks the first that fits in the available vertical container — unlike
    /// `minimumScaleFactor`, this never silently shrinks a 4-line name into
    /// 2 small lines.
    @ViewBuilder
    private var productNameText: some View {
        ViewThatFits(in: .vertical) {
            Text(item.label)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Text(item.label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)

            Text(item.label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .lineLimit(6)  // final guard so an extreme outlier still fits
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        AsyncImage(url: thumbnailURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            case .empty:
                Color.white.opacity(0.06)
            case .failure:
                Image(systemName: "photo")
                    .foregroundStyle(.white.opacity(0.3))
            @unknown default:
                Color.white.opacity(0.06)
            }
        }
        .frame(width: 68, height: 68)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

}
