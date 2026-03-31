//
//  PromoComponents.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import SwiftUI

// MARK: - Wrapping HStack Layout

private struct WrappingHStack: Layout {
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

// MARK: - Color Constants

private let promoGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let promoGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
private let promoGold = Color(red: 1.00, green: 0.80, blue: 0.20)
private let cardBackground = Color(white: 0.08)
private let cardOverlayTop = Color.white.opacity(0.04)
private let cardOverlayBottom = Color.white.opacity(0.02)
private let borderTop = Color.white.opacity(0.15)
private let borderBottom = Color.white.opacity(0.05)

private var greenGradient: LinearGradient {
    LinearGradient(
        colors: [promoGreen, promoGreenDark],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Glass Card Background Modifier

private struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var borderGradient: LinearGradient? = nil

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(cardBackground)
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [cardOverlayTop, cardOverlayBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderGradient ?? LinearGradient(
                            colors: [borderTop, borderBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = 20,
        borderGradient: LinearGradient? = nil
    ) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, borderGradient: borderGradient))
    }
}

// MARK: - Promo Banner Card (for OverviewView)

struct PromoBannerCard: View {
    @ObservedObject var viewModel: PromosViewModel
    @State private var appeared = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    bannerSkeleton
                }
                .buttonStyle(.plain)
            case .success(let data) where data.isReady && data.dealCount > 0:
                bannerContent(data)
            case .success(let data):
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    debugBanner(bannerMessage(for: data))
                }
                .buttonStyle(.plain)
            case .error:
                // Error — tappable to open PromosView & retry
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    debugBanner("Couldn't load deals — tap to retry")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func debugBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(2)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private func bannerMessage(for data: PromoRecommendationResponse) -> String {
        switch data.reportStatus {
        case .ready:
            return "No deals this week — tap to open your weekly report"
        case .noEnrichedProfile:
            return "Keep scanning receipts to unlock weekly deals"
        case .noReportAvailable:
            return "This week's report isn't ready yet"
        }
    }

    private func bannerContent(_ data: PromoRecommendationResponse) -> some View {
        NavigationLink {
            PromosView(viewModel: viewModel)
        } label: {
            HStack(spacing: 12) {
                // Green accent icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [promoGreen.opacity(0.25), promoGreenDark.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: "tag.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(greenGradient)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 0) {
                        Text("\(data.dealCount) deals")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(greenGradient)
                        Text(" matched this week")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("across \(data.stores.count) stores")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(16)
            .contentShape(Rectangle())
            .glassCard(
                borderGradient: LinearGradient(
                    colors: [promoGreen.opacity(0.25), promoGreenDark.opacity(0.10)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appeared = true
            }
        }
    }

    private var bannerSkeleton: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(promoGreen.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: "tag.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(greenGradient)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("00 deals matched this week")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("across 0 stores")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(16)
        .glassCard(
            borderGradient: LinearGradient(
                colors: [promoGreen.opacity(0.25), promoGreenDark.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .redacted(reason: .placeholder)
    }
}

// MARK: - Hero Card

struct PromoSummaryHeader: View {
    let stores: [PromoStore]
    @State private var appeared = false

    private var totalSavings: Double {
        stores.reduce(0) { $0 + $1.totalSavings }
    }

    private var dealCount: Int {
        stores.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(format: "€%.2f", totalSavings))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(greenGradient)

            Text("in savings this week")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 5) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(greenGradient)

                Text("Milo found \(dealCount) deals")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

// MARK: - Section Header

struct PromoSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(greenGradient)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Store Section

struct PromoStoreSection: View {
    let store: PromoStore
    let index: Int
    let onExpand: () -> Void
    @State private var isExpanded = false
    @State private var appeared = false

    private let initialItemCount = 3

    private var bestDealId: String? {
        store.items.filter { $0.savings > 0 }.max(by: { $0.savings < $1.savings })?.id
    }

    private var daysLeft: Int? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let endDate = formatter.date(from: store.validityEnd) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: Calendar.current.startOfDay(for: endDate)).day
        return days
    }

    private var daysLeftText: String {
        guard let days = daysLeft else { return store.validityEnd }
        if days < 0 { return "Expired" }
        if days == 0 { return "Last day" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }

    private var daysLeftColor: Color {
        guard let days = daysLeft else { return .white.opacity(0.3) }
        if days <= 1 { return Color(red: 0.95, green: 0.3, blue: 0.3) }
        if days <= 3 { return Color(red: 0.95, green: 0.6, blue: 0.2) }
        return .white.opacity(0.3)
    }

    private var storeAccentColor: Color {
        GroceryStore.fromCanonical(store.storeName)?.accentColor ?? promoGreen
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Store accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(storeAccentColor)
                .frame(width: 3)
                .padding(.vertical, 14)

            VStack(alignment: .leading, spacing: 0) {
                // Store header
                HStack(spacing: 10) {
                    StoreLogoView(storeName: store.storeName, height: 22)

                    Text(GroceryStore.fromCanonical(store.storeName)?.displayName ?? store.storeName.capitalized)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    if !store.items.isEmpty {
                        HStack(spacing: 8) {
                            if let days = daysLeft, days <= 3 {
                                Text(daysLeftText)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(days <= 1 ? .red : .orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule().fill((days <= 1 ? Color.red : Color.orange).opacity(0.12))
                                    )
                            }

                            Text("\(store.items.count) deals")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                if store.items.isEmpty {
                    // Empty state — per-store, no deals
                    VStack(spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "tag.slash")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(storeAccentColor.opacity(0.5))
                            Text("No matching deals this week")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.45))
                        }

                        Text("New promotions drop every week — check back soon.")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.25))
                            .multilineTextAlignment(.center)

                        // If the store has a promo folder, link to it
                        if let folderUrl = store.items.first?.promoFolderUrl,
                           let url = URL(string: folderUrl) {
                            Link(destination: url) {
                                HStack(spacing: 5) {
                                    Image(systemName: "safari")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("Browse full folder")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .foregroundColor(storeAccentColor.opacity(0.8))
                            }
                            .padding(.top, 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                } else {
                    // Items
                    let visibleItems = isExpanded ? store.items : Array(store.items.prefix(initialItemCount))

                    VStack(spacing: 0) {
                        ForEach(Array(visibleItems.enumerated()), id: \.element.id) { itemIndex, item in
                            if itemIndex > 0 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 0.5)
                                    .padding(.horizontal, 16)
                            }
                            PromoItemRow(item: item, storeName: store.storeName, isBestDeal: item.id == bestDealId)
                        }
                    }

                    // Show more / less
                    if store.items.count > initialItemCount {
                        Button {
                            let opening = !isExpanded
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                isExpanded.toggle()
                            }
                            if opening {
                                onExpand()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isExpanded ? "Show less" : "Show all \(store.items.count) deals")
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                    }
                }

            }
            .padding(.leading, 6)
        }
        .clipped()
        .glassCard()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.06)) {
                appeared = true
            }
        }
    }
}

// MARK: - Item Row (within a store section)

struct PromoItemRow: View {
    let item: PromoStoreItem
    let storeName: String
    var isBestDeal: Bool = false
    @State private var isExpanded = false
    @ObservedObject private var groceryStore = GroceryListStore.shared
    @State private var addTrigger = false

    private var isSpecialDeal: Bool {
        let mech = item.mechanismLabel.lowercased()
        return mech.contains("gratis") || mech.contains("free") || mech.contains("cadeau")
    }

    private var mechanismPillColor: Color {
        if (item.minPurchaseQty ?? 1) > 1 { return promoGreen }
        if isSpecialDeal { return promoGold }
        return .white.opacity(0.7)
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Collapsed row — always visible
            HStack(alignment: .center, spacing: 12) {
                // Left: brand + name + mechanism
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if !item.brand.isEmpty {
                            Text(item.brand.uppercased())
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .tracking(0.5)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Color.white.opacity(0.08))
                                )
                        }
                        if isBestDeal {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 7, weight: .bold))
                                Text("BEST DEAL")
                                    .font(.system(size: 9, weight: .heavy))
                                    .tracking(0.5)
                            }
                            .foregroundColor(promoGold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(promoGold.opacity(0.12))
                            )
                        }
                    }

                    Text(item.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(isExpanded ? nil : 2)
                        .fixedSize(horizontal: false, vertical: isExpanded)

                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            if (item.minPurchaseQty ?? 1) > 1 {
                                Image(systemName: "cart.badge.plus")
                                    .font(.system(size: 10, weight: .semibold))
                            } else if isSpecialDeal {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            Text(item.mechanismLabel)
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(mechanismPillColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(mechanismPillColor.opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(mechanismPillColor.opacity(0.2), lineWidth: 0.5)
                        )
                        .fixedSize()
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // Right: prices
                if item.hasPrices {
                    priceView
                }

                // Add to grocery list button
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
                    Image(systemName: groceryStore.contains(item: item, storeName: storeName) ? "checkmark.circle.fill" : "plus.circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(groceryStore.contains(item: item, storeName: storeName) ? promoGreen : .white.opacity(0.3))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.impact(weight: .medium), trigger: addTrigger)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }

            // MARK: Expanded detail — shown on tap
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider()
                        .background(Color.white.opacity(0.08))

                    // Description
                    if let desc = item.displayDescription, !desc.isEmpty {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Info chips
                    if hasInfoChips {
                        WrappingHStack(spacing: 8) {
                            if let unitPrice = item.displayUnitPrice, !unitPrice.isEmpty {
                                infoChip(icon: "scalemass", text: unitPrice)
                            }
                            if let label = item.savingsLabel, !label.isEmpty {
                                infoChip(icon: "arrow.down.circle", text: label, isAccented: true)
                            }
                            if let unitPrice = item.effectiveUnitPrice, unitPrice > 0 {
                                infoChip(icon: "tag", text: String(format: "€%.2f/pc", unitPrice))
                            }
                            if let qty = item.minPurchaseQty, qty > 1 {
                                infoChip(icon: "number", text: "Min. \(qty)")
                            }
                        }
                    }

                    // Folder link
                    if let urlString = item.promoFolderUrl,
                       let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari")
                                    .font(.system(size: 13, weight: .medium))
                                if let page = item.pageNumber {
                                    Text("\(L("view_in_folder")) — p. \(page)")
                                        .font(.system(size: 13, weight: .semibold))
                                } else {
                                    Text(L("view_in_folder"))
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .fixedSize()
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.10))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.20), lineWidth: 0.5)
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Price View

    @ViewBuilder
    private var priceView: some View {
        let qty = item.minPurchaseQty ?? 1
        if qty > 1 {
            // Multi-buy: show total prices for the full deal
            let totalOriginal = item.originalPrice * Double(qty)
            let totalUserPays = totalOriginal - item.savings
            VStack(alignment: .trailing, spacing: 4) {
                if item.discountPercentage > 0 {
                    Text("-\(item.discountPercentage)%")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(greenGradient)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(promoGreen.opacity(0.15)))
                }
                Text(String(format: "€%.2f", totalUserPays))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(greenGradient)
                Text(String(format: "€%.2f", totalOriginal))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
            .fixedSize()
        } else {
            // Single-item: show per-unit prices
            VStack(alignment: .trailing, spacing: 4) {
                if item.discountPercentage > 0 {
                    Text("-\(item.discountPercentage)%")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(greenGradient)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(promoGreen.opacity(0.15)))
                }
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(greenGradient)
                Text(String(format: "€%.2f", item.originalPrice))
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
            .fixedSize()
        }
    }

    // MARK: - Info Chips

    private var hasInfoChips: Bool {
        (item.displayUnitPrice != nil && !(item.displayUnitPrice?.isEmpty ?? true))
        || (item.savingsLabel != nil && !(item.savingsLabel?.isEmpty ?? true))
        || (item.minPurchaseQty ?? 0) > 1
    }

    private func infoChip(icon: String, text: String, isAccented: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(isAccented ? promoGreen : .white.opacity(0.6))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isAccented ? promoGreen.opacity(0.10) : Color.white.opacity(0.06))
        )
    }
}

// MARK: - Skeleton Loading View (redacted placeholder)

struct PromoSkeletonView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Placeholder summary header
            VStack(alignment: .leading, spacing: 4) {
                Text("€00.00")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("potential savings this week")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            // Placeholder store sections
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 0) {
                    // Store header
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 36, height: 36)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Store Name")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                            Text("12 deals • Save €5.00")
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        Spacer()
                    }
                    .padding(16)

                    // Placeholder deal rows
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 48, height: 48)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Product Name Here")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                                Text("€3.99 → €2.49")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Text("-25%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(promoGreen)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .glassCard()
            }
            .padding(.horizontal, 16)
        }
        .redacted(reason: .placeholder)
    }
}

// MARK: - Empty State

struct PromoEmptyView: View {
    let status: PromoReportStatus
    let title: String
    let message: String
    var onAddStores: (() -> Void)? = nil
    var onScanReceipt: (() -> Void)? = nil

    @State private var appeared = false
    @State private var iconPulse = false

    var body: some View {
        VStack(spacing: 20) {
            // Icon with animated glow
            ZStack {
                // Glow ring behind icon
                Circle()
                    .fill(accentColor.opacity(0.08))
                    .frame(width: 88, height: 88)
                    .scaleEffect(iconPulse ? 1.12 : 1.0)
                    .opacity(iconPulse ? 0.6 : 0.3)

                Circle()
                    .fill(Color(white: 0.08))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(accentColor.opacity(0.2), lineWidth: 1))

                Image(systemName: iconName)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            // Status-specific hint
            if let hint = contextHint {
                HStack(spacing: 6) {
                    Image(systemName: hintIcon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(hint)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(accentColor.opacity(0.7))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(accentColor.opacity(0.08))
                )
            }

            // CTA buttons
            ctaButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .glassCard()
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true).delay(0.5)) {
                iconPulse = true
            }
        }
    }

    // MARK: - Status-specific content

    private var subtitle: String {
        switch status {
        case .noReportAvailable:
            return "Milo is sniffing out the best deals for your stores. Your personalised report refreshes every week."
        case .noEnrichedProfile:
            return "Milo personalises deals based on your shopping habits. Scan a few receipts so he knows what you like!"
        case .ready:
            return message.isEmpty
                ? "No matching promotions this week across your selected stores. Milo will keep looking!"
                : message
        }
    }

    private var contextHint: String? {
        switch status {
        case .noReportAvailable:
            return "Usually ready by Monday"
        case .noEnrichedProfile:
            return "Scan 2–3 receipts to get started"
        case .ready:
            return nil
        }
    }

    private var hintIcon: String {
        switch status {
        case .noReportAvailable: return "clock"
        case .noEnrichedProfile: return "camera.viewfinder"
        case .ready: return "calendar"
        }
    }

    private var accentColor: Color {
        switch status {
        case .noReportAvailable: return Color(red: 0.40, green: 0.70, blue: 1.0)
        case .noEnrichedProfile: return promoGreen
        case .ready: return promoGold
        }
    }

    private var iconName: String {
        switch status {
        case .ready:
            return "pawprint.fill"
        case .noEnrichedProfile:
            return "doc.text.viewfinder"
        case .noReportAvailable:
            return "sparkle.magnifyingglass"
        }
    }

    @ViewBuilder
    private var ctaButton: some View {
        switch status {
        case .noEnrichedProfile:
            if let onScan = onScanReceipt {
                Button(action: onScan) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Scan a Receipt")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(promoGreen))
                }
                .padding(.top, 4)
            }
        case .ready:
            if let onAdd = onAddStores {
                Button(action: onAdd) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Add More Stores")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(promoGreen)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().stroke(promoGreen, lineWidth: 1.5))
                }
                .padding(.top, 4)
            }
        case .noReportAvailable:
            EmptyView()
        }
    }
}

// MARK: - Error State

struct PromoErrorView: View {
    let message: String
    let onRetry: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color.orange.opacity(0.2), lineWidth: 1))

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .orange.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("Couldn't load deals")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }

            Button(action: onRetry) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Try Again")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.orange))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
        .glassCard()
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
