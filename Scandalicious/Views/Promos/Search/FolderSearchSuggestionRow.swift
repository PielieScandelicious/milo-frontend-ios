//
//  FolderSearchSuggestionRow.swift
//  Scandalicious
//
//  Compact product row used inside the focused search overlay.
//  Tap → opens PromoProductDetailSheet via the parent's .sheet(item:).
//  Trailing "+/✓" → toggles the item in the grocery list directly.
//

import SwiftUI

struct FolderSearchSuggestionRow: View {
    let item: PromoStoreItem
    let onTap: () -> Void

    @ObservedObject private var groceryStore = GroceryListStore.shared
    @State private var addTrigger = false

    private var thumbnailURL: URL? {
        if let s = item.thumbnailUrl, let u = URL(string: s) { return u }
        if let s = item.imageUrl, let u = URL(string: s) { return u }
        return nil
    }

    private var brandLabel: String {
        let p = item.primaryBrandLabel
        return p.isEmpty ? "" : p
    }

    private var priceLabel: String {
        if item.priceUnavailable { return "" }
        let value = item.promoPrice > 0 ? item.promoPrice : item.originalPrice
        return String(format: "€%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private var savingsText: String? {
        let label = item.displaySavingsLabel ?? ""
        return label.isEmpty ? nil : label
    }

    private var resolvedStoreName: String { item.storeName ?? "" }

    private var canAddToList: Bool { !resolvedStoreName.isEmpty }

    private var isInList: Bool {
        guard canAddToList else { return false }
        return groceryStore.contains(item: item, storeName: resolvedStoreName)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .center, spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 3) {
                    if !brandLabel.isEmpty {
                        Text(brandLabel.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(PromoDesign.brandAccent)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text(item.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    HStack(spacing: 8) {
                        if !item.validityEnd.isEmpty {
                            ValidityChip(validityEnd: item.validityEnd, compact: true)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                        storeBadge
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                rightColumn
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var storeBadge: some View {
        if let name = item.storeName,
           GroceryStore.fromCanonical(name) != nil {
            StoreLogoView(storeName: name, height: 14)
                .opacity(0.85)
        } else if let raw = item.storeName, !raw.isEmpty {
            Text(raw.capitalized)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
    }

    private var rightColumn: some View {
        HStack(spacing: 4) {
            VStack(alignment: .trailing, spacing: 2) {
                if !priceLabel.isEmpty {
                    Text(priceLabel)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let savings = savingsText {
                    Text(savings)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.green.opacity(0.85))
                        .lineLimit(1)
                }
            }

            if canAddToList {
                addButton
            }
        }
    }

    private var addButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isInList {
                    groceryStore.removeByPromo(item: item, storeName: resolvedStoreName)
                } else {
                    groceryStore.add(item: item, storeName: resolvedStoreName)
                }
                addTrigger.toggle()
            }
        } label: {
            Image(systemName: isInList ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(isInList ? PromoDesign.accentGreen : .white.opacity(0.85))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: addTrigger)
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
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}
