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
    /// When set, the "View in folder" button is hidden for this specific item —
    /// used when the sheet is opened from inside the folder viewer for a
    /// hotspot the user already sees on screen. Similar-promo navigation
    /// within the sheet still surfaces the button because their itemKey
    /// differs from this origin.
    var originatingItemKey: String? = nil
    @EnvironmentObject private var foldersViewModel: PromoFoldersViewModel
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @State private var addTrigger = false
    @State private var currentItem: PromoGridItem
    @State private var history: [PromoGridItem] = []
    @State private var similarPromos: [PromoStoreItem] = []
    @State private var similarLoading = true
    @State private var loggedOpenForItemIds: Set<String> = []
    @Environment(\.dismiss) private var dismiss

    init(
        gridItem: PromoGridItem,
        onOpenInFolder: ((PromoFolder, Int, String?) -> Void)? = nil,
        originatingItemKey: String? = nil
    ) {
        self.initialItem = gridItem
        self.onOpenInFolder = onOpenInFolder
        self.originatingItemKey = originatingItemKey
        self._currentItem = State(initialValue: gridItem)

        // Pre-populate from the shared cache so a prefetched response renders
        // the carousel on first paint instead of flashing the shimmer.
        if let promoId = gridItem.item.itemKey,
           let cached = SimilarPromosCache.shared.cached(promoId: promoId, limit: 10) {
            self._similarPromos = State(initialValue: cached.items)
            self._similarLoading = State(initialValue: false)
        }
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
                        if item.isCoupon {
                            couponSection
                        }
                        brandAndNameSection
                        if !item.isCoupon {
                            // Pricing card doesn't apply to pure loyalty-points
                            // coupons — the reward is tracked in couponSection.
                            pricingHeroCard
                        }
                        promoTextSection
                        if !item.isCoupon {
                            crossStorePanel
                        }
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

            // Full-tile crop (heroUrl) when available; falls back to the product-focused crop.
            // RemoteImage hits the shared prefetch cache synchronously, so hero images
            // prefetched on the folder page paint without a ProgressView flash.
            if let imageUrl = item.heroUrl ?? item.imageUrl, let url = URL(string: imageUrl) {
                RemoteImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 260)
                        .padding(20)
                } placeholder: {
                    heroPlaceholder
                }
            } else {
                heroPlaceholder
            }

            // Discount badge (top-left) — suppressed for price_unavailable.
            // Leading inset clears the 4pt store accent rail so the badge
            // reads as floating over the image, not glued to the rail.
            if item.discountPercentage > 0 && !item.priceUnavailable {
                Text("-\(item.discountPercentage)%")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(discountBadgeColor))
                    .shadow(color: discountBadgeColor.opacity(0.35), radius: 4, y: 2)
                    .padding(.leading, 14)
                    .padding(.top, 12)
            }

            // Store badge (bottom-left)
            VStack {
                Spacer()
                HStack {
                    StoreBadge(storeName: storeName, size: .small)
                    Spacer()
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

    // MARK: - Coupon Section (shown at the top of the sheet when item.isCoupon)

    /// Human-readable reward label, e.g. "Loyalty Points · +75" / "Cashback · €2 off".
    /// Generic semantic labels (no per-store program mapping) so the UI stays store-agnostic.
    private var couponRewardLabel: String {
        let typeName: String
        switch item.couponType {
        case "loyalty_points":     typeName = L("coupon_loyalty_points")
        case "cashback":           typeName = L("coupon_cashback")
        case "free_product":       typeName = L("coupon_free_product")
        case "percent_off_coupon": typeName = L("coupon_discount")
        default:                   typeName = L("coupon_generic")
        }

        guard let v = item.couponValue else { return typeName }
        switch item.couponType {
        case "loyalty_points":
            let n = Int(v.rounded())
            return "\(typeName) · +\(n) \(L("coupon_points_unit"))"
        case "cashback":
            return String(format: "\(typeName) · €%.2f", v).replacingOccurrences(of: ".", with: ",")
        case "percent_off_coupon":
            return "\(typeName) · -\(Int(v.rounded()))%"
        default:
            return typeName
        }
    }

    /// Prefer the coupon's own validity (printed on the coupon itself) over the
    /// folder-level validity when present — coupons often outlive their folder.
    private var couponEffectiveValidityEnd: String {
        if let coupon = item.couponValidityEnd, !coupon.isEmpty { return coupon }
        return item.validityEnd
    }

    private var couponSection: some View {
        let gold = Color(red: 0.95, green: 0.70, blue: 0.15)

        return VStack(alignment: .leading, spacing: 14) {
            // Reward banner
            HStack(spacing: 10) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(gold)
                Text(couponRewardLabel)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(PromoDesign.primaryText)
                Spacer()
                ValidityChip(validityEnd: couponEffectiveValidityEnd)
            }

            // Barcode — rendered natively on-device from the decoded digit string.
            // If the backend ingested the coupon but the decoder failed, we show
            // a neutral placeholder so the user isn't left with a misleading image.
            if let value = item.couponBarcodeValue,
               !value.isEmpty,
               let image = BarcodeGenerator.image(
                   for: value,
                   format: BarcodeFormat.from(backendFormat: item.couponBarcodeFormat),
                   size: CGSize(width: 320, height: 120),
                   scale: UIScreen.main.scale
               ) {
                VStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 120)
                        .padding(12)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Text(L("coupon_show_at_checkout"))
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(PromoDesign.secondaryText)
                        .textCase(.uppercase)
                }
                .frame(maxWidth: .infinity)
            } else {
                // No scannable barcode — flag plainly instead of silently hiding.
                Text(L("coupon_barcode_unavailable"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(PromoDesign.secondaryText)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }

            // Required purchase condition, if the backend captured one.
            if let trigger = item.couponMinPurchase, !trigger.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(PromoDesign.tertiaryText)
                        .padding(.top, 3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("coupon_required_purchase").uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .tracking(0.8)
                            .foregroundStyle(PromoDesign.tertiaryText)
                        Text(trigger)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(PromoDesign.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(gold.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(gold.opacity(0.4), lineWidth: 1)
                )
        )
    }

    // MARK: - Brand & Name Section

    private var brandAndNameSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Brand — editorial-style eyebrow above the product name:
            // small uppercase wordmark in the store accent color, no heavy
            // pill. Additional brands follow after a thin divider so the
            // primary brand still reads as the anchor. Validity label
            // shares this row, pushed fully to the trailing edge.
            HStack(spacing: 8) {
                if !item.primaryBrandLabel.isEmpty {
                    Text(item.primaryBrandLabel.uppercased())
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(1.6)
                        .foregroundStyle(storeAccentColor)
                        .lineLimit(1)

                    if let extra = item.additionalBrands, !extra.isEmpty {
                        Rectangle()
                            .fill(PromoDesign.tertiaryText.opacity(0.35))
                            .frame(width: 1, height: 10)
                        Text(extra.joined(separator: " · ").uppercased())
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(1.0)
                            .foregroundStyle(PromoDesign.tertiaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                Spacer(minLength: 8)
                ValidityChip(validityEnd: item.validityEnd)
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
                // `layoutPriority(1)` on the price stack keeps the price on a
                // single line even when the savings pill is wide.
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    PromoPriceStack(item: item, size: .hero)
                        .layoutPriority(1)
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

    @ViewBuilder
    private var savingsPill: some View {
        if item.savings > 0 {
            Text(String(format: "Bespaar €%.2f", item.savings))
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(PromoDesign.accentGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(PromoDesign.accentGreen.opacity(0.14)))
                .overlay(Capsule().stroke(PromoDesign.accentGreen.opacity(0.28), lineWidth: 0.5))
                .accessibilityLabel(String(format: "Bespaar €%.2f", item.savings))
        }
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
        // Every promo is anchored to a folder page with a bbox, so the CTA is
        // always the in-app viewer. Styled in premium blue to match the "+"
        // badges, contour trace, and spotlight animation inside the viewer —
        // one visual language for "this lives in the folder".
        //
        // Hidden for the originating hotspot (user tapped a promo in the
        // viewer → button would send them back to where they already are).
        if item.itemKey != nil, item.itemKey == originatingItemKey {
            EmptyView()
        } else if let match = folderMatch, let onOpenInFolder {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onOpenInFolder(match.folder, match.pageIndex, item.itemKey)
                dismiss()
            } label: {
                FolderLinkCard(
                    storeDisplayName: match.folder.storeDisplayName,
                    pageNumber: match.folder.pages[match.pageIndex].pageNumber
                )
            }
            .buttonStyle(FolderLinkPressStyle())
            .accessibilityHint("Opens the promo folder on page \(match.folder.pages[match.pageIndex].pageNumber)")
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

        guard let promoId = gridItem.item.itemKey else {
            similarLoading = false
            return
        }

        // Synchronous cache peek skips the shimmer entirely on a hit (common
        // path when the folder viewer has prefetched similar promos).
        if let cached = SimilarPromosCache.shared.cached(promoId: promoId, limit: 10) {
            similarPromos = cached.items
            similarLoading = false
            return
        }

        similarLoading = true
        similarPromos = []

        let response = await SimilarPromosCache.shared.getOrFetch(promoId: promoId, limit: 10)
        guard !Task.isCancelled, gridItem.id == currentItem.id else { return }
        similarPromos = response?.items ?? []
        similarLoading = false
    }

    // MARK: - Add to List Button

    private var addToListButton: some View {
        let isInList = groceryStore.contains(item: item, storeName: storeName)
        // Coupons get their own label + icon so the action reads as "save this
        // scannable offer for later" rather than generic grocery-list toggling.
        let addLabel: String = item.isCoupon ? L("coupon_save") : "Add to my list"
        let removeLabel: String = item.isCoupon ? L("coupon_remove") : "Remove from my list"
        let addIcon: String = item.isCoupon ? "ticket.fill" : "plus"
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
                Image(systemName: isInList ? "trash.fill" : addIcon)
                    .font(.system(size: 15, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
                Text(isInList ? removeLabel : addLabel)
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

// MARK: - Folder Link Card

/// Sleek CTA that jumps the user to the promo's exact bbox in the folder
/// viewer. The `viewfinder` glyph echoes the contour animation that runs on
/// arrival — so the icon previews what happens when you tap.
private struct FolderLinkCard: View {
    let storeDisplayName: String
    let pageNumber: Int

    private static let folderBlue = Color(red: 0.10, green: 0.45, blue: 0.98)
    private static let folderBlueLight = Color(red: 0.35, green: 0.62, blue: 1.00)

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "viewfinder")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Self.folderBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("View in folder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                HStack(spacing: 0) {
                    Text(storeDisplayName)
                    Text("  ·  page \(pageNumber)")
                        .foregroundStyle(Self.folderBlueLight.opacity(0.9))
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Self.folderBlue.opacity(0.07))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Self.folderBlueLight.opacity(0.45),
                            Self.folderBlue.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        )
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
                                    .frame(maxWidth: .infinity, maxHeight: 100, alignment: .top)
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
                        .minimumScaleFactor(0.85)
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

                    ValidityChip(validityEnd: promo.validityEnd, compact: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: 150, height: 220)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(white: 0.08))
            )
            .overlay(alignment: .topLeading) {
                if promo.discountPercentage > 0 {
                    Text("-\(promo.discountPercentage)%")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().fill(Color(red: 0.95, green: 0.25, blue: 0.25))
                        )
                        .padding(.top, 4)
                        .padding(.leading, 8)
                }
            }
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
