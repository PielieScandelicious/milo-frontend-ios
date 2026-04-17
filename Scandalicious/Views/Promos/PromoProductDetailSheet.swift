//
//  PromoProductDetailSheet.swift
//  Scandalicious
//
//  Polished detail bottom sheet for a promo product.
//  Brand-forward design with urgency-aware validity and clear visual hierarchy.
//

import SwiftUI

struct PromoProductDetailSheet: View {
    let initialItem: PromoGridItem
    var onOpenInFolder: ((PromoFolder, Int, String?) -> Void)? = nil
    @EnvironmentObject private var foldersViewModel: PromoFoldersViewModel
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @State private var addTrigger = false
    @State private var currentItem: PromoGridItem
    @State private var history: [PromoGridItem] = []
    @State private var similarPromos: [PromoStoreItem] = []
    @State private var similarLoading = true
    @State private var loggedOpenForItemIds: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    init(gridItem: PromoGridItem, onOpenInFolder: ((PromoFolder, Int, String?) -> Void)? = nil) {
        self.initialItem = gridItem
        self.onOpenInFolder = onOpenInFolder
        self._currentItem = State(initialValue: gridItem)
    }

    private var item: PromoStoreItem { currentItem.item }
    private var storeName: String { currentItem.storeName }

    private var folderMatch: (folder: PromoFolder, pageIndex: Int)? {
        guard onOpenInFolder != nil else { return nil }
        return foldersViewModel.findFolder(for: item, storeName: storeName)
    }

    private var store: GroceryStore? {
        GroceryStore.fromCanonical(storeName)
    }

    private var storeAccentColor: Color {
        store?.accentColor ?? detailGreen
    }

    private var isSpecialDeal: Bool {
        let mech = item.mechanismLabel.lowercased()
        return mech.contains("gratis") || mech.contains("free") || mech.contains("cadeau")
    }

    private var mechanismPillColor: Color {
        if (item.minPurchaseQty ?? 1) > 1 { return detailGreen }
        if isSpecialDeal { return detailGold }
        return Color(white: 0.22)
    }

    private var mechanismTextColor: Color {
        if isSpecialDeal { return .black.opacity(0.8) }
        if (item.minPurchaseQty ?? 1) > 1 { return .white }
        return .white.opacity(0.85)
    }

    private var discountBadgeColor: Color {
        item.discountPercentage > 30
            ? Color(red: 0.95, green: 0.25, blue: 0.25)
            : detailGreen
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

    private var validityDisplay: (text: String, color: Color, icon: String) {
        guard let days = daysRemaining else {
            return (validityFallbackText, .white.opacity(0.4), "calendar")
        }
        switch days {
        case _ where days < 0:
            return ("Expired", .white.opacity(0.25), "calendar.badge.exclamationmark")
        case 0:
            return ("Last day!", detailUrgentRed, "exclamationmark.circle.fill")
        case 1...2:
            return ("\(days) day\(days == 1 ? "" : "s") left", detailUrgentOrange, "clock.badge.exclamationmark")
        case 3...5:
            return ("\(days) days left", detailWarningAmber, "clock")
        default:
            return ("\(days) days left", .white.opacity(0.5), "calendar")
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

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 20) {
                        savingsRow
                        brandAndNameSection
                        mechanismAndPriceSection
                        if hasInfoChips {
                            infoChipsSection
                        }
                        folderLink
                        similarPromosSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(Color(white: 0.05).ignoresSafeArea())
            .overlay(alignment: .bottom) {
                addToListButton
            }
            .overlay(alignment: .topTrailing) {
                closeButton
            }
            .overlay(alignment: .topLeading) {
                if !history.isEmpty {
                    backButton
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task(id: currentItem.id) {
            await loadSimilar(for: currentItem)
        }
    }

    // MARK: - Back Button (similar-promo breadcrumb)

    private var backButton: some View {
        Button {
            guard let previous = history.popLast() else { return }
            withAnimation(.easeInOut(duration: 0.22)) {
                currentItem = previous
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
                Text("Back")
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to previous promo")
        .padding(.leading, 16)
        .padding(.top, 12)
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                )
                .overlay(
                    Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .padding(.trailing, 16)
        .padding(.top, 12)
    }

    // MARK: - Hero Image

    private var heroImage: some View {
        ZStack(alignment: .topLeading) {
            // White background
            Color(white: 0.97)
                .frame(height: 300)

            // Product image
            if let imageUrl = item.imageUrl, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: 260)
                            .padding(20)
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

            // Discount badge (top-left)
            if item.discountPercentage > 0 {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(discountBadgeColor))
                    .shadow(color: discountBadgeColor.opacity(0.35), radius: 4, y: 2)
                    .padding(8)
            }

            // Store badge (bottom-left) + Validity badge (bottom-right)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    StoreLogoView(storeName: storeName, height: 20)
                        .frame(width: 30, height: 30)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Spacer()

                    heroValidityBadge
                }
                .padding(8)
            }
        }
        .frame(height: 300)
        .clipped()
    }

    private var heroValidityStyle: (text: String, icon: String, bg: Color, fg: Color) {
        guard let days = daysRemaining else {
            return (validityFallbackText, "calendar", Color.black.opacity(0.55), .white.opacity(0.85))
        }
        switch days {
        case _ where days < 0:
            return ("Expired", "calendar.badge.exclamationmark", Color.black.opacity(0.55), .white.opacity(0.6))
        case 0:
            return ("Last day!", "exclamationmark.circle.fill", detailUrgentRed.opacity(0.85), .white)
        case 1...2:
            return ("\(days) day\(days == 1 ? "" : "s") left", "clock.badge.exclamationmark", detailUrgentOrange.opacity(0.85), .white)
        case 3...5:
            return ("\(days) days left", "clock", detailWarningAmber.opacity(0.80), .black.opacity(0.85))
        default:
            return ("\(days) days left", "calendar", Color.black.opacity(0.55), .white.opacity(0.9))
        }
    }

    @ViewBuilder
    private var heroValidityBadge: some View {
        let style = heroValidityStyle
        HStack(spacing: 3) {
            Image(systemName: style.icon)
                .font(.system(size: 8, weight: .semibold))
            Text(style.text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundColor(style.fg)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Capsule().fill(style.bg))
        .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
    }

    private var heroPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 48, weight: .light))
            .foregroundColor(Color(white: 0.8))
            .frame(maxWidth: .infinity, maxHeight: 260)
    }

    // MARK: - Brand & Name Section

    private var brandAndNameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Brand — prominent, in store accent color
            if !item.brand.isEmpty {
                Text(item.brand.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .tracking(1.2)
                    .foregroundColor(detailBrandColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(detailBrandColor.opacity(0.15))
                    )
                    .overlay(
                        Capsule().stroke(detailBrandColor.opacity(0.25), lineWidth: 0.5)
                    )
            }

            // Product name — large, clear
            Text(item.label)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Description
            if let desc = item.displayDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Mechanism & Price Section

    private var mechanismAndPriceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Mechanism pill — solid filled
            HStack(spacing: 6) {
                if (item.minPurchaseQty ?? 1) > 1 {
                    Image(systemName: "cart.badge.plus")
                        .font(.system(size: 12, weight: .semibold))
                } else if isSpecialDeal {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(item.mechanismLabel)
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(mechanismTextColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(mechanismPillColor))

            // Price row
            priceSection
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    // MARK: - Price Section

    @ViewBuilder
    private var priceSection: some View {
        let qty = item.minPurchaseQty ?? 1

        VStack(alignment: .leading, spacing: 8) {
            if qty > 1 {
                let totalOriginal = item.originalPrice * Double(qty)
                let totalUserPays = totalOriginal - item.savings
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "€%.2f", totalUserPays))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(detailGreen)
                    Text(String(format: "€%.2f", totalOriginal))
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                        .strikethrough(true, color: .white.opacity(0.3))
                }
            } else if item.hasPrices {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(String(format: "€%.2f", item.promoPrice))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(detailGreen)
                    Text(String(format: "€%.2f", item.originalPrice))
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.white.opacity(0.3))
                        .strikethrough(true, color: .white.opacity(0.3))
                }
            }

        }
    }

    // MARK: - Savings Row (headline)

    @ViewBuilder
    private var savingsRow: some View {
        if item.savings > 0 {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 15, weight: .bold))
                if item.discountPercentage > 0 {
                    Text(String(format: "You save €%.2f (%d%%)", item.savings, item.discountPercentage))
                        .font(.system(size: 15, weight: .bold))
                } else {
                    Text(String(format: "You save €%.2f", item.savings))
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundColor(detailGreen)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                Capsule().fill(detailGreen.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(detailGreen.opacity(0.25), lineWidth: 0.5)
            )
        }
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
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(isAccented ? detailGreen : .white.opacity(0.6))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isAccented ? detailGreen.opacity(0.10) : Color.white.opacity(0.06))
        )
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
        if let match = folderMatch, let onOpenInFolder {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpenInFolder(match.folder, match.pageIndex, item.itemKey)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(storeAccentColor.opacity(0.18))
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(storeAccentColor)
                    }
                    .frame(width: 38, height: 38)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Find in folder")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("\(match.folder.storeDisplayName) · Page \(match.folder.pages[match.pageIndex].pageNumber)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white.opacity(0.35))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            }
            .buttonStyle(FolderLinkPressStyle())
            .accessibilityHint("Opens the promo folder on page \(match.folder.pages[match.pageIndex].pageNumber)")
        } else if let urlString = item.promoFolderUrl, let url = URL(string: urlString) {
            Link(destination: url) {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                        .font(.system(size: 14, weight: .medium))
                    Text(item.pageNumber.map { "View in promo folder — p. \($0)" } ?? "View in promo folder")
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(detailLinkBlue)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(detailLinkBlue.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(detailLinkBlue.opacity(0.15), lineWidth: 0.5)
                )
            }
        }
    }

    // MARK: - Similar Promos Carousel

    @ViewBuilder
    private var similarPromosSection: some View {
        if similarLoading {
            VStack(alignment: .leading, spacing: 12) {
                similarHeader
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(0..<3, id: \.self) { _ in
                            SimilarPromoShimmerCard()
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, -20)
                .scrollClipDisabled()
            }
        } else if !similarPromos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                similarHeader
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(similarPromos.enumerated()), id: \.element.id) { index, promo in
                            SimilarPromoCard(promo: promo) {
                                handleSimilarTap(promo, position: index)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.horizontal, -20)
                .scrollClipDisabled()
            }
        }
    }

    private var similarHeader: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
            Text("Similar deals")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(.top, 4)
    }

    private func handleSimilarTap(_ promo: PromoStoreItem, position: Int) {
        guard let targetId = promo.itemKey else { return }

        // Telemetry: record the tap with source + target + position
        Task {
            await PromoAPIService.shared.logInteractionEvent(
                eventType: .similarPromoClicked,
                promoItemId: targetId,
                sourceItemId: currentItem.item.itemKey,
                storeName: promo.storeName,
                metadata: ["position": "\(position)"]
            )
        }

        // Push current onto history and swap
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let newItem = PromoGridItem(
            id: targetId,
            item: promo,
            storeName: promo.storeName ?? currentItem.storeName
        )
        withAnimation(.easeInOut(duration: 0.25)) {
            history.append(currentItem)
            currentItem = newItem
        }
    }

    private func loadSimilar(for gridItem: PromoGridItem) async {
        // Fire deal_opened exactly once per unique item in this sheet session
        if let itemKey = gridItem.item.itemKey, !loggedOpenForItemIds.contains(itemKey) {
            loggedOpenForItemIds.insert(itemKey)
            Task {
                await PromoAPIService.shared.logInteractionEvent(
                    eventType: .dealOpened,
                    promoItemId: itemKey,
                    storeName: gridItem.storeName,
                    metadata: ["source": "folder_viewer"]
                )
            }
        }

        similarLoading = true
        similarPromos = []
        guard let promoId = gridItem.item.itemKey else {
            similarLoading = false
            return
        }

        do {
            let response = try await PromoAPIService.shared.getSimilarPromos(promoId: promoId, limit: 10)
            if !Task.isCancelled && gridItem.id == currentItem.id {
                similarPromos = response.items
            }
        } catch {
            // Silent failure — section hides if empty
            if !Task.isCancelled && gridItem.id == currentItem.id {
                similarPromos = []
            }
        }
        if !Task.isCancelled && gridItem.id == currentItem.id {
            similarLoading = false
        }
    }

    // MARK: - Add to List Button

    private var addToListButton: some View {
        let isInList = groceryStore.contains(item: item, storeName: storeName)
        return Button {
            if isInList {
                groceryStore.removeByPromo(item: item, storeName: storeName)
            } else {
                groceryStore.add(item: item, storeName: storeName)
            }
            addTrigger.toggle()
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isInList ? "trash.fill" : "plus")
                    .font(.system(size: 15, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(isInList ? "Remove from Grocery List" : "Add to Grocery List")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(isInList ? Color(red: 0.95, green: 0.30, blue: 0.30) : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Capsule().fill(isInList ? Color(red: 0.95, green: 0.30, blue: 0.30).opacity(0.12) : detailGreen)
            )
            .overlay(
                isInList
                    ? Capsule().stroke(Color(red: 0.95, green: 0.30, blue: 0.30).opacity(0.35), lineWidth: 1)
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
            .frame(height: 90)
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

// MARK: - Button Styles

private struct FolderLinkPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Similar Promo Card

private struct SimilarPromoCard: View {
    let promo: PromoStoreItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    Color(white: 0.97)
                        .frame(height: 120)

                    if let urlStr = promo.imageUrl ?? promo.thumbnailUrl,
                       let url = URL(string: urlStr) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: 100)
                                    .padding(10)
                            case .failure:
                                cardPlaceholder
                            case .empty:
                                ProgressView()
                                    .frame(maxWidth: .infinity, maxHeight: 100)
                            @unknown default:
                                cardPlaceholder
                            }
                        }
                    } else {
                        cardPlaceholder
                    }

                    if promo.discountPercentage > 0 {
                        Text("-\(promo.discountPercentage)%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    promo.discountPercentage > 30
                                        ? Color(red: 0.95, green: 0.25, blue: 0.25)
                                        : Color(red: 0.20, green: 0.85, blue: 0.50)
                                )
                            )
                            .padding(6)
                    }

                    // Store logo overlay (bottom-left)
                    if let storeName = promo.storeName {
                        VStack {
                            Spacer()
                            HStack {
                                StoreLogoView(storeName: storeName, height: 12)
                                    .frame(width: 22, height: 22)
                                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                Spacer()
                            }
                            .padding(6)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !promo.brand.isEmpty {
                        Text(promo.brand.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.6)
                            .foregroundColor(.white.opacity(0.55))
                            .lineLimit(1)
                    }
                    Text(promo.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 2)

                    if promo.hasPrices {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(String(format: "€%.2f", promo.promoPrice))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(Color(red: 0.20, green: 0.85, blue: 0.50))
                            if promo.originalPrice > promo.promoPrice {
                                Text(String(format: "€%.2f", promo.originalPrice))
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundColor(.white.opacity(0.3))
                                    .strikethrough(true, color: .white.opacity(0.3))
                            }
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 150, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(SimilarCardPressStyle())
    }

    private var cardPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 28, weight: .light))
            .foregroundColor(Color(white: 0.8))
            .frame(maxWidth: .infinity, maxHeight: 100)
    }
}

private struct SimilarCardPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

private struct SimilarPromoShimmerCard: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 120)
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(Color.white.opacity(0.06)).frame(width: 40, height: 8)
                Capsule().fill(Color.white.opacity(0.06)).frame(maxWidth: .infinity, minHeight: 10, maxHeight: 10)
                Capsule().fill(Color.white.opacity(0.06)).frame(width: 80, height: 10)
                Spacer(minLength: 2)
                Capsule().fill(Color.white.opacity(0.06)).frame(width: 50, height: 12)
            }
            .padding(10)
        }
        .frame(width: 150, height: 220)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .mask(
            LinearGradient(
                colors: [.black.opacity(0.6), .white, .black.opacity(0.6)],
                startPoint: UnitPoint(x: phase, y: 0.5),
                endPoint: UnitPoint(x: phase + 0.8, y: 0.5)
            )
        )
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Detail-local color constants

private let detailGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let detailGold = Color(red: 1.00, green: 0.80, blue: 0.20)
private let detailBrandColor = Color(red: 0.82, green: 0.68, blue: 0.40)
private let detailWarningAmber = Color(red: 1.0, green: 0.75, blue: 0.25)
private let detailUrgentOrange = Color(red: 0.95, green: 0.40, blue: 0.30)
private let detailUrgentRed = Color(red: 0.95, green: 0.25, blue: 0.25)
private let detailLinkBlue = Color(red: 0.4, green: 0.65, blue: 1.0)
