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
    let data: PromoRecommendationResponse
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 14) {
            Text("YOUR DEALS THIS WEEK")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))

            Text("\(data.dealCount)")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(greenGradient)
                .contentTransition(.numericText())

            Text("deals across \(data.stores.count) stores")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            HStack(spacing: 10) {
                // Deal count badge
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill")
                        .font(.system(size: 10))
                    Text("\(data.dealCount) deals")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))

                // Week badge
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.system(size: 10))
                    Text("\(data.promoWeek.label): \(data.promoWeek.start) - \(data.promoWeek.end)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .glassCard()
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
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
    let onClaim: (PromoStoreItem) -> Void
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

                Text(store.storeName.capitalized)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(store.items.count) deals")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(promoGreen)

                    Text(daysLeftText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(daysLeftColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Items
            let visibleItems = isExpanded ? store.items : Array(store.items.prefix(initialItemCount))

            VStack(spacing: 0) {
                ForEach(Array(visibleItems.enumerated()), id: \.element.id) { itemIndex, item in
                    if itemIndex > 0 {
                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 0.5)
                            .padding(.leading, 64)
                            .padding(.trailing, 16)
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
        .glassCard()
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
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(0.5)
                            .lineLimit(1)
                    }

                    Text(item.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(item.mechanismLabel)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(item.isMultiBuy ? promoGreen : .white.opacity(0.7))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    item.isMultiBuy
                                        ? promoGreen.opacity(0.25)
                                        : Color.white.opacity(0.15)
                                )
                            )
                            .fixedSize()

                        if let savingsText = item.savingsLabel {
                            Text(savingsText)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(promoGreen)
                        }
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // Right: prices
                if item.hasPrices {
                    priceView
                }

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
                                Text("Bekijk in folder")
                                    .font(.system(size: 13, weight: .semibold))
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.1))
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

// MARK: - Summary Footer

struct PromoSummaryFooter: View {
    let summary: PromoSummary
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 16) {
            // Header
            PromoSectionHeader(title: "SUMMARY", icon: "chart.bar.fill")

            // Best value store
            if let bestStore = summary.bestValueStore {
                HStack(spacing: 8) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.yellow.opacity(0.8))

                    Text("Most deals: **\(bestStore)**")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("\(summary.bestValueItems) deals")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Store breakdown bars
            if !summary.storesBreakdown.isEmpty {
                VStack(spacing: 8) {
                    // Segmented bar
                    GeometryReader { geometry in
                        HStack(spacing: 2) {
                            ForEach(summary.storesBreakdown) { breakdown in
                                let proportion = summary.totalItems > 0
                                    ? Double(breakdown.items) / Double(summary.totalItems)
                                    : 1.0 / Double(summary.storesBreakdown.count)

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: max(4, (geometry.size.width - CGFloat(summary.storesBreakdown.count - 1) * 2) * proportion))
                            }
                        }
                    }
                    .frame(height: 8)

                    // Legend
                    HStack(spacing: 12) {
                        ForEach(summary.storesBreakdown) { breakdown in
                            HStack(spacing: 4) {
                                StoreLogoView(storeName: breakdown.store, height: 14)

                                Text(breakdown.store)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                }
            }

        }
        .padding(16)
        .glassCard()
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2)) {
                appeared = true
            }
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
