//
//  PromoProductCard.swift
//  Scandalicious
//
//  Thumbnail card for the 2-column promo grid (340pt fixed height).
//  Rebuilt around the cross-store design language:
//    · store accent rail + store badge (always visible → immediate store ID)
//    · mechanism pill coloured by MechanismKind (consistent colour language)
//    · effective €/unit as the PRIMARY visual element (cross-store anchor)
//    · pack price + struck original underneath (secondary)
//    · savings chip + validity chip + add button at the bottom
//    · `price_unavailable` → italic "Prijs in winkel" instead of fake €0.00
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

    private var storeAccent: Color {
        GroceryStore.fromCanonical(storeName)?.accentColor ?? PromoDesign.accentGreen
    }

    static let cardHeight: CGFloat = 340

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .leading) {
                // Store accent rail on the left edge (always visible identity).
                Rectangle()
                    .fill(storeAccent)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 0) {
                    imageSection
                    infoSection
                }
            }
            .frame(height: Self.cardHeight)
            .clipShape(RoundedRectangle(cornerRadius: PromoDesign.cardCorner, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: PromoDesign.cardCorner, style: .continuous)
                    .fill(PromoDesign.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PromoDesign.cardCorner, style: .continuous)
                    .stroke(PromoDesign.cardBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.94)
        .onAppear { triggerEntrance() }
    }

    // MARK: - Entrance animation (unchanged)

    private func triggerEntrance() {
        let row = index / 2
        let col = index % 2
        let sequentialPosition = row * 2 + col
        let delay = min(Double(sequentialPosition) * 0.06, 0.6)
        withAnimation(.smooth(duration: 0.35).delay(delay)) { appeared = true }
    }

    // MARK: - Image section

    private var imageSection: some View {
        ZStack(alignment: .topTrailing) {
            Color(white: 0.97)
                .frame(height: 140)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 120)
                            .padding(10)
                    case .failure: imagePlaceholder
                    case .empty: ProgressView().frame(maxWidth: .infinity, maxHeight: 120)
                    @unknown default: imagePlaceholder
                    }
                }
            } else {
                imagePlaceholder
            }

            // Discount badge (top-right) — only when we have a real discount %
            if item.discountPercentage > 0 && !item.priceUnavailable {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(
                            item.discountPercentage > 30 ? PromoDesign.urgencyUrgent : PromoDesign.accentGreen
                        )
                    )
                    .padding(8)
            }

            // Store badge (bottom-left) — compact logo always visible.
            VStack {
                Spacer()
                HStack {
                    StoreBadge(storeName: storeName, size: .small)
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

    // MARK: - Info section

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Brand eyebrow
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(PromoDesign.eyebrow())
                    .tracking(1.0)
                    .foregroundStyle(PromoDesign.brandAccent)
                    .lineLimit(1)
            }

            // Product name
            Text(item.label)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(PromoDesign.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 34, alignment: .topLeading)

            // Mechanism pill
            HStack {
                MechanismPill(item: item)
                Spacer(minLength: 4)
            }

            // Promo + struck original, or "Prijs in winkel"
            PromoPriceStack(item: item, size: .card)

            Spacer(minLength: 0)

            // Bottom row: savings + validity + add
            HStack(spacing: 6) {
                if item.savings > 0 && !item.priceUnavailable {
                    savingsChip
                }
                Spacer(minLength: 0)
                subtleValidity
                addButton
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(10)
        .background(PromoDesign.cardBackground)
    }

    private var subtleValidity: some View {
        let d = PromoValidity.display(for: item.validityEnd)
        return HStack(spacing: 3) {
            if let icon = d.icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(d.text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(d.isUrgent ? d.color.opacity(0.85) : PromoDesign.secondaryText.opacity(0.55))
    }

    private var savingsChip: some View {
        Text(item.savingsLabel ?? String(format: "Bespaar €%.2f", item.savings))
            .font(PromoDesign.chip())
            .foregroundStyle(PromoDesign.accentGreen)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: PromoDesign.chipCorner, style: .continuous)
                    .fill(PromoDesign.accentGreen.opacity(0.15))
            )
            .lineLimit(1)
    }

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
            Image(systemName: groceryStore.contains(item: item, storeName: storeName)
                    ? "checkmark.circle.fill" : "plus.circle.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(
                    groceryStore.contains(item: item, storeName: storeName)
                        ? storeAccent
                        : storeAccent.opacity(0.7)
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .medium), trigger: addTrigger)
    }
}
