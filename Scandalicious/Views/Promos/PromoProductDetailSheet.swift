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

    private var discountBadgeColor: Color {
        item.discountPercentage > 30 ? PromoDesign.urgencyUrgent : PromoDesign.accentGreen
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    heroImage

                    VStack(alignment: .leading, spacing: 20) {
                        brandAndNameSection
                        pricingHeroCard
                        promoTextSection
                        crossStorePanel
                        folderLink
                        similarPromosSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                    .padding(.bottom, 160)
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

            // Discount badge (top-left) — suppressed for price_unavailable
            if item.discountPercentage > 0 && !item.priceUnavailable {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(discountBadgeColor))
                    .shadow(color: discountBadgeColor.opacity(0.35), radius: 4, y: 2)
                    .padding(8)
            }

            // Store badge (bottom-left) + Validity chip (bottom-right)
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    StoreBadge(storeName: storeName, size: .large)
                    Spacer()
                    ValidityChip(validityEnd: item.validityEnd)
                        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                }
                .padding(10)
            }
        }
        .frame(height: 300)
        .clipped()
        .overlay(alignment: .leading) {
            // Store accent rail on the left edge
            Rectangle()
                .fill(storeAccentColor)
                .frame(width: 4)
        }
    }

    private var heroPlaceholder: some View {
        Image(systemName: "photo")
            .font(.system(size: 48, weight: .light))
            .foregroundColor(Color(white: 0.8))
            .frame(maxWidth: .infinity, maxHeight: 260)
    }

    // MARK: - Brand & Name Section

    private var brandAndNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Brand — prominent, in store accent color
            if !item.primaryBrandLabel.isEmpty {
                HStack(spacing: 6) {
                    Text(item.primaryBrandLabel.uppercased())
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1.2)
                        .foregroundStyle(storeAccentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(storeAccentColor.opacity(0.15))
                        )
                        .overlay(
                            Capsule().stroke(storeAccentColor.opacity(0.25), lineWidth: 0.5)
                        )
                    // Multi-brand promo: show sibling brands next to the primary.
                    if let extra = item.additionalBrands, !extra.isEmpty {
                        Text("+ \(extra.joined(separator: ", "))")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(PromoDesign.secondaryText)
                    }
                }
            }

            // Product name — large, clear
            Text(item.label)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(PromoDesign.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            // Pack size tag — "500 g", "6 × 25 cl", "12 stuks"
            if let packLabel = item.packSizeLabel {
                HStack(spacing: 6) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(packLabel)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(PromoDesign.secondaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: PromoDesign.chipCorner, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }

            // Description
            if let desc = item.displayDescription, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(PromoDesign.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)
            }
        }
    }

    // MARK: - Pricing hero card (cross-store anchor)

    private var pricingHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Top row: mechanism pill + min-qty hint
            HStack(spacing: 8) {
                MechanismPill(item: item)
                if let qty = item.minPurchaseQty, qty > 1 {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.badge.plus").font(.system(size: 10, weight: .semibold))
                        Text("min. \(qty)").font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(PromoDesign.secondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.06)))
                }
                Spacer(minLength: 4)
            }

            if item.priceUnavailable {
                // Assortment / zero-price case: clean italic label, no fake numbers.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prijs in winkel")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .italic()
                        .foregroundStyle(PromoDesign.primaryText)
                    Text("Zie deal in de winkel voor de exacte prijs.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(PromoDesign.secondaryText)
                }
            } else {
                // HERO: the cross-store comparison anchor.
                if item.unitPriceValue != nil || (item.displayUnitPrice?.isEmpty == false) {
                    VStack(alignment: .leading, spacing: 2) {
                        EffectiveUnitPriceView(item: item, size: .hero)
                        Text("effectieve prijs per eenheid")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(PromoDesign.tertiaryText)
                    }
                }

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Pack price (promo + struck original) — secondary
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    PromoPriceStack(item: item, size: .hero)
                    if item.savings > 0 {
                        savingsPill
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(white: 0.09))
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(storeAccentColor)
                .frame(height: 3)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
    }

    private var savingsPill: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 11, weight: .bold))
            if item.discountPercentage > 0 {
                Text(String(format: "Bespaar €%.2f · %d%%", item.savings, item.discountPercentage))
                    .font(.system(size: 12, weight: .bold))
            } else {
                Text(String(format: "Bespaar €%.2f", item.savings))
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundStyle(PromoDesign.accentGreen)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(PromoDesign.accentGreen.opacity(0.14)))
        .overlay(Capsule().stroke(PromoDesign.accentGreen.opacity(0.28), lineWidth: 0.5))
    }

    // MARK: - Verbatim tile text (Markdown)

    @ViewBuilder
    private var promoTextSection: some View {
        if let raw = item.promoTextMarkdown?.trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Folder tekst")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.5)
                    .foregroundStyle(PromoDesign.tertiaryText)

                ForEach(Array(markdownBlocks(from: raw).enumerated()), id: \.offset) { _, block in
                    promoTextBlock(block)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )
        }
    }

    private enum PromoTextBlock {
        case paragraph(String)
        case bullets([String])
    }

    /// Split a Markdown string into paragraph/bullet blocks separated by blank lines.
    private func markdownBlocks(from raw: String) -> [PromoTextBlock] {
        let chunks = raw.components(separatedBy: "\n\n")
        var blocks: [PromoTextBlock] = []
        for chunk in chunks {
            let trimmed = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lines = trimmed.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            let isBulletList = !lines.isEmpty && lines.allSatisfy { $0.hasPrefix("- ") || $0.hasPrefix("* ") }
            if isBulletList {
                let items = lines.map { String($0.dropFirst(2)).trimmingCharacters(in: .whitespaces) }
                blocks.append(.bullets(items))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }
        return blocks
    }

    @ViewBuilder
    private func promoTextBlock(_ block: PromoTextBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(markdownAttributed(text))
                .font(.system(size: 14))
                .foregroundStyle(PromoDesign.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.system(size: 14))
                            .foregroundStyle(PromoDesign.tertiaryText)
                        Text(markdownAttributed(line))
                            .font(.system(size: 14))
                            .foregroundStyle(PromoDesign.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    /// Parse inline Markdown (bold, italic, code) but keep any embedded newlines as line breaks.
    private func markdownAttributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    // MARK: - Cross-store comparison panel

    @ViewBuilder
    private var crossStorePanel: some View {
        if !item.priceUnavailable {
            CrossStoreComparisonView(
                current: item,
                currentStoreName: storeName,
                siblings: similarPromos
            ) { target in
                handleSimilarTap(target, position: -1)
            }
        }
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

    // MARK: - Similar Promos Carousel (auto-scroll + infinite loop)

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
                AutoScrollingSimilarCarousel(items: similarPromos) { promo, index in
                    handleSimilarTap(promo, position: index)
                }
                .padding(.horizontal, -20)
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
                Text(isInList ? "Remove from my list" : "Add to my list")
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

// MARK: - Auto-Scrolling Infinite-Loop Carousel

private struct AutoScrollingSimilarCarousel: View {
    let items: [PromoStoreItem]
    let onTap: (PromoStoreItem, Int) -> Void

    @State private var offsetX: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var flingVelocity: CGFloat = 0

    private let cardWidth: CGFloat = 150
    private let cardHeight: CGFloat = 220
    private let spacing: CGFloat = 12
    private let leadingInset: CGFloat = 20
    private let pointsPerSecond: CGFloat = 28
    private let frameInterval: Double = 1.0 / 60.0
    private let flingDecayPerFrame: CGFloat = 0.92
    private let maxFlingVelocity: CGFloat = 3000

    private var itemStride: CGFloat { cardWidth + spacing }
    private var contentWidth: CGFloat { itemStride * CGFloat(items.count) }

    // Wrap offset into (-contentWidth, 0] so two back-to-back copies
    // render identically at the seam — the loop stays invisible whether
    // the user is scrolling forward or dragging backward.
    private func wrap(_ x: CGFloat) -> CGFloat {
        guard contentWidth > 0 else { return 0 }
        var r = x.truncatingRemainder(dividingBy: contentWidth)
        if r > 0 { r -= contentWidth }
        return r
    }

    @ViewBuilder
    var body: some View {
        if items.count >= 2 {
            // Color.clear takes proposed width, fixed height — gives the
            // parent a deterministic size. The wide HStack lives in an
            // overlay so its ideal width never influences outer layout.
            Color.clear
                .frame(height: cardHeight)
                .contentShape(Rectangle())
                .overlay(alignment: .leading) {
                    HStack(alignment: .center, spacing: spacing) {
                        ForEach(0..<2, id: \.self) { cycle in
                            ForEach(Array(items.enumerated()), id: \.offset) { index, promo in
                                SimilarPromoCard(promo: promo) {
                                    onTap(promo, index)
                                }
                            }
                        }
                    }
                    .padding(.leading, leadingInset)
                    .offset(x: offsetX)
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartOffset = offsetX
                                flingVelocity = 0
                            }
                            offsetX = wrap(dragStartOffset + value.translation.width)
                        }
                        .onEnded { value in
                            // predictedEndTranslation - translation ≈ remaining distance
                            // over UIKit's ~0.3s prediction window → convert to pts/sec.
                            let predictedDelta = value.predictedEndTranslation.width - value.translation.width
                            let rawVelocity = predictedDelta / 0.3
                            flingVelocity = max(min(rawVelocity, maxFlingVelocity), -maxFlingVelocity)
                            isDragging = false
                        }
                )
                .task(id: items.count) {
                    let sleepNs: UInt64 = UInt64(frameInterval * 1_000_000_000)
                    let dt = CGFloat(frameInterval)
                    while !Task.isCancelled {
                        try? await Task.sleep(nanoseconds: sleepNs)
                        guard !isDragging else { continue }
                        // Baseline auto-scroll + decaying user fling, same assignment path.
                        offsetX = wrap(offsetX - pointsPerSecond * dt + flingVelocity * dt)
                        flingVelocity *= flingDecayPerFrame
                        if abs(flingVelocity) < 0.5 { flingVelocity = 0 }
                    }
                }
        } else if let single = items.first {
            HStack(spacing: 0) {
                Spacer().frame(width: leadingInset)
                SimilarPromoCard(promo: single) { onTap(single, 0) }
                Spacer(minLength: 0)
            }
        }
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

// MARK: - Detail-local color constants (only colors not in PromoDesign)

private let detailGreen = PromoDesign.accentGreen
private let detailLinkBlue = Color(red: 0.4, green: 0.65, blue: 1.0)
