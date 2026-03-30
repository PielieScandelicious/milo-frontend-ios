//
//  PromoComponents.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import SwiftUI

// MARK: - Color Constants

private let promoGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let promoGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)
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
        DachshundBannerView()
    }
}

// MARK: - Hero Card

struct PromoHeroCard: View {
    let stores: [PromoStore]
    @State private var appeared = false
    @State private var isExpanded = false

    private var dealCount: Int {
        stores.reduce(0) { $0 + $1.items.count }
    }

    private var storeText: String {
        stores.count == 1 ? "store" : "stores"
    }

    private var maxSavings: Double {
        stores.map(\.totalSavings).max() ?? 1
    }

    var body: some View {
        VStack(spacing: 0) {
            // Banner row
            HStack(spacing: 12) {
                Image(systemName: "pawprint.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(greenGradient)
                    .fixedSize()

                (Text("Milo sniffed out ")
                    .foregroundColor(.white.opacity(0.6))
                + Text("\(dealCount) deals")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                + Text(" across \(stores.count) \(storeText)")
                    .foregroundColor(.white.opacity(0.6)))
                .font(.system(size: 14))
                .lineLimit(2)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.2))
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .fixedSize()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isExpanded.toggle()
                }
            }

            // Expanded: savings breakdown by store (in preferred order)
            if isExpanded {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 16)

                    VStack(spacing: 10) {
                        ForEach(stores) { store in
                            HStack(spacing: 10) {
                                StoreLogoView(storeName: store.storeName, height: 18)

                                Text(GroceryStore.fromCanonical(store.storeName)?.displayName ?? store.storeName.capitalized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                                    .frame(width: 80, alignment: .leading)

                                // Savings bar
                                GeometryReader { geo in
                                    let proportion = maxSavings > 0 ? store.totalSavings / maxSavings : 0
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(greenGradient.opacity(0.6))
                                        .frame(width: max(4, geo.size.width * proportion))
                                }
                                .frame(height: 6)

                                Text(String(format: "€%.2f", store.totalSavings))
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(greenGradient)
                                    .frame(width: 55, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    // Total
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)
                        .padding(.horizontal, 16)

                    HStack {
                        Text("Total potential savings")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Spacer()

                        Text(String(format: "€%.2f", stores.reduce(0) { $0 + $1.totalSavings }))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(greenGradient)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
        .glassCard()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.easeOut(duration: 0.3)) {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Store header
            HStack(spacing: 10) {
                StoreLogoView(storeName: store.storeName, height: 22)

                Text(GroceryStore.fromCanonical(store.storeName)?.displayName ?? store.storeName.capitalized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                if !store.items.isEmpty {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(store.items.count) deals")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(promoGreen)

                        Text(daysLeftText)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(daysLeftColor)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            if store.items.isEmpty {
                // Empty state
                VStack(spacing: 6) {
                    Text("No deals this week")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.35))
                    Text("Check back next week for new promotions.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.2))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .padding(.bottom, 8)
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
                        PromoItemRow(item: item)
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
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Collapsed row — always visible
            HStack(alignment: .center, spacing: 12) {
                // Left: brand + name + mechanism
                VStack(alignment: .leading, spacing: 4) {
                    if !item.brand.isEmpty {
                        Text(item.brand.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.65))
                            .tracking(0.5)
                            .lineLimit(1)
                    }

                    Text(item.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(isExpanded ? nil : 2)

                    HStack(spacing: 6) {
                        Text(item.mechanismLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(item.isMultiBuy ? promoGreen.opacity(0.85) : .white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    item.isMultiBuy
                                        ? promoGreen.opacity(0.12)
                                        : Color.white.opacity(0.15)
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    item.isMultiBuy
                                        ? promoGreen.opacity(0.2)
                                        : Color.white.opacity(0.15),
                                    lineWidth: 0.5
                                )
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

                    // Folder link
                    if let urlString = item.promoFolderUrl,
                       let url = URL(string: urlString) {
                        Link(destination: url) {
                            HStack(spacing: 6) {
                                Image(systemName: "book.pages")
                                    .font(.system(size: 12, weight: .medium))
                                if let page = item.pageNumber {
                                    Text("Bekijk in folder — p. \(page)")
                                        .font(.system(size: 13, weight: .semibold))
                                } else {
                                    Text("Bekijk in folder")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(Color(red: 0.4, green: 0.6, blue: 1.0))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(red: 0.4, green: 0.6, blue: 1.0).opacity(0.12))
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
        if item.isMultiBuy, let qty = item.minPurchaseQty, qty > 1 {
            let totalWithout = item.originalPrice * Double(qty)
            let totalWith = totalWithout - item.savings
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "€%.2f", totalWith))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(greenGradient)
                Text(String(format: "€%.2f", totalWithout))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
            .fixedSize()
        } else {
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(greenGradient)
                Text(String(format: "€%.2f", item.originalPrice))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
                    .strikethrough(true, color: .white.opacity(0.3))
            }
            .fixedSize()
        }
    }
}

// MARK: - Skeleton Loading View (Dachshund sniffing animation)

struct PromoSkeletonView: View {
    var body: some View {
        DachshundSniffingView()
    }
}

// MARK: - Empty State

struct PromoEmptyView: View {
    let status: PromoReportStatus
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: iconName)
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }

    private var iconName: String {
        switch status {
        case .ready:
            return "bag.fill"
        case .noEnrichedProfile:
            return "doc.text.viewfinder"
        case .noReportAvailable:
            return "clock.badge.exclamationmark"
        }
    }
}

// MARK: - Error State

struct PromoErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.orange)

            Text("Couldn't load deals")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                onRetry()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Retry")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.blue))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
    }
}
