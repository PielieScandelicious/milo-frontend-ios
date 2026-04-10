//
//  PromoProductDetailSheet.swift
//  Scandalicious
//
//  Full detail bottom sheet for a promo product.
//

import SwiftUI

struct PromoProductDetailSheet: View {
    let gridItem: PromoGridItem
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @State private var addTrigger = false
    @Environment(\.dismiss) private var dismiss

    private var item: PromoStoreItem { gridItem.item }
    private var storeName: String { gridItem.storeName }

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(storeName)?.accentColor ?? detailGreen
    }

    private var isSpecialDeal: Bool {
        let mech = item.mechanismLabel.lowercased()
        return mech.contains("gratis") || mech.contains("free") || mech.contains("cadeau")
    }

    private var mechanismPillColor: Color {
        if (item.minPurchaseQty ?? 1) > 1 { return detailGreen }
        if isSpecialDeal { return detailGold }
        return .white.opacity(0.7)
    }

    private var discountBadgeColor: Color {
        item.discountPercentage > 30
            ? Color(red: 0.95, green: 0.25, blue: 0.25)
            : detailGreen
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    heroImage
                    productInfo
                    priceSection
                    if hasInfoChips {
                        infoChipsSection
                    }
                    validitySection
                    folderLink
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .overlay(alignment: .bottom) {
                addToListButton
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.97))
                .frame(height: 280)

            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 260)
                            .padding(10)
                    case .failure:
                        heroPlaceholder
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: 260)
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }

            // Discount badge
            if item.discountPercentage > 0 {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(discountBadgeColor))
                    .shadow(color: discountBadgeColor.opacity(0.4), radius: 6, y: 3)
                    .padding(12)
            }
        }
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var heroPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 48, weight: .light))
            .foregroundColor(Color(white: 0.8))
            .frame(maxWidth: .infinity, maxHeight: 260)
    }

    // MARK: - Product Info

    private var productInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Store row
            HStack(spacing: 8) {
                StoreLogoView(storeName: storeName, height: 18)
                    .frame(width: 28, height: 28)
                    .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(GroceryStore.fromCanonical(storeName)?.displayName ?? storeName.capitalized)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
            }

            // Brand
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(.white.opacity(0.4))
            }

            // Product name
            Text(item.label)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Mechanism pill
            HStack(spacing: 5) {
                if (item.minPurchaseQty ?? 1) > 1 {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                } else if isSpecialDeal {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(item.mechanismLabel)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(mechanismPillColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(mechanismPillColor.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(mechanismPillColor.opacity(0.2), lineWidth: 0.5)
            )

            // Description
            if let desc = item.displayDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Price Section

    private var priceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let qty = item.minPurchaseQty ?? 1

            if qty > 1 {
                let totalOriginal = item.originalPrice * Double(qty)
                let totalUserPays = totalOriginal - item.savings
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "€%.2f", totalUserPays))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(detailGreenGradient)
                    Text(String(format: "€%.2f", totalOriginal))
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))
                        .strikethrough(true, color: .white.opacity(0.3))
                }
            } else if item.hasPrices {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "€%.2f", item.promoPrice))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(detailGreenGradient)
                    Text(String(format: "€%.2f", item.originalPrice))
                        .font(.system(size: 18))
                        .foregroundColor(.white.opacity(0.3))
                        .strikethrough(true, color: .white.opacity(0.3))
                }
            }

            // Savings pill with percentage
            if item.savings > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    if item.discountPercentage > 0 {
                        Text(String(format: "You save €%.2f (%d%%)", item.savings, item.discountPercentage))
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Text(String(format: "You save €%.2f", item.savings))
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(detailGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(detailGreen.opacity(0.10))
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Info Chips

    private var hasInfoChips: Bool {
        (item.displayUnitPrice != nil && !(item.displayUnitPrice?.isEmpty ?? true))
        || (item.effectiveUnitPrice ?? 0) > 0
        || (item.minPurchaseQty ?? 0) > 1
        || (item.savingsLabel != nil && !(item.savingsLabel?.isEmpty ?? true))
        || (item.bucketLabel != nil && !(item.bucketLabel?.isEmpty ?? true))
    }

    private var infoChipsSection: some View {
        FlowLayout(spacing: 8) {
            if let unitPrice = item.displayUnitPrice, !unitPrice.isEmpty {
                detailChip(icon: "scalemass", text: unitPrice)
            }
            if let unitPrice = item.effectiveUnitPrice, unitPrice > 0 {
                detailChip(icon: "tag", text: String(format: "€%.2f/pc", unitPrice))
            }
            if let qty = item.minPurchaseQty, qty > 1 {
                detailChip(icon: "number", text: "Min. \(qty)")
            }
            if let label = item.savingsLabel, !label.isEmpty {
                detailChip(icon: "arrow.down.circle", text: label, isAccented: true)
            }
            if let bucket = item.bucketLabel, !bucket.isEmpty {
                detailChip(icon: "folder", text: bucket)
            }
        }
    }

    private func detailChip(icon: String, text: String, isAccented: Bool = false) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(isAccented ? detailGreen : .white.opacity(0.6))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAccented ? detailGreen.opacity(0.10) : Color.white.opacity(0.06))
        )
    }

    // MARK: - Validity

    private var validitySection: some View {
        HStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .semibold))
            Text("Valid \(formatDate(item.validityStart)) – \(formatDate(item.validityEnd))")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.4))
    }

    private func formatDate(_ dateStr: String) -> String {
        let parts = dateStr.split(separator: "-")
        if parts.count == 3 {
            return "\(parts[2])/\(parts[1])"
        }
        return dateStr
    }

    // MARK: - Folder Link

    @ViewBuilder
    private var folderLink: some View {
        if let urlString = item.promoFolderUrl, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .font(.system(size: 13, weight: .medium))
                    if let page = item.pageNumber {
                        Text("View in promo folder — p. \(page)")
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Text("View in promo folder")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule().fill(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.10))
                )
                .overlay(
                    Capsule().stroke(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.20), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Add to List Button

    private var addToListButton: some View {
        let isInList = groceryStore.contains(item: item, storeName: storeName)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if isInList {
                    groceryStore.removeByPromo(item: item, storeName: storeName)
                } else {
                    groceryStore.add(item: item, storeName: storeName)
                }
                addTrigger.toggle()
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isInList ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text(isInList ? "Added to Shopping List" : "Add to Shopping List")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(isInList ? detailGreen : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                Capsule().fill(isInList ? detailGreen.opacity(0.15) : detailGreen)
            )
            .overlay(
                isInList
                    ? Capsule().stroke(detailGreen, lineWidth: 1.5)
                    : nil
            )
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: addTrigger)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.05).opacity(0), Color(white: 0.05)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 80)
            .allowsHitTesting(false)
        )
    }
}

// MARK: - Flow Layout (simple wrapping layout for chips)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.enumerated().reduce(CGFloat.zero) { total, entry in
            let rowHeight = entry.element.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            return total + rowHeight + (entry.offset > 0 ? spacing : 0)
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            var x = bounds.minX
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubviews.Element]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(subview)
            currentWidth += size.width + spacing
        }
        return rows
    }
}

// MARK: - Detail-local color constants

private let detailGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let detailGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
private let detailGold = Color(red: 1.00, green: 0.80, blue: 0.20)

private var detailGreenGradient: LinearGradient {
    LinearGradient(
        colors: [detailGreen, detailGreenDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
