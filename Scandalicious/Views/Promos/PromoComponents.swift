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

// MARK: - Brand Helper

/// Returns true if the brand string is meaningful (not empty, not "No Brand", etc.)
private func hasValidBrand(_ brand: String) -> Bool {
    let trimmed = brand.trimmingCharacters(in: .whitespaces)
    if trimmed.isEmpty { return false }
    let lower = trimmed.lowercased()
    return lower != "no brand" && lower != "unknown" && lower != "n/a"
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
    fileprivate func glassCard(
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
            case .success(let data) where data.dealCount > 0:
                bannerContent(data)
            case .success:
                // deal_count == 0 — still tappable to open PromosView & refresh
                NavigationLink {
                    PromosView(viewModel: viewModel)
                } label: {
                    debugBanner("No deals found yet — tap to check for deals!")
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
                        Text("Save up to ")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                        Text(String(format: "€%.2f", data.weeklySavings))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(greenGradient)
                        Text(" this week")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Text("\(data.dealCount) deals across \(data.stores.count) stores")
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
            Text("TOTAL SAVINGS THIS WEEK")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.5))

            Text(String(format: "€%.2f", data.weeklySavings))
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(greenGradient)
                .contentTransition(.numericText())

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

// MARK: - Top Pick Card

struct PromoTopPickCard: View {
    let pick: PromoTopPick
    let index: Int
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact header row — always visible
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(pick.emoji)
                        .font(.system(size: 18))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color.white.opacity(0.04)))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(hasValidBrand(pick.brand) ? pick.brand : pick.productName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        if hasValidBrand(pick.brand) {
                            Text("\(pick.productName) · \(pick.store)")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(2)
                        } else {
                            Text(pick.store)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                                .lineLimit(1)
                        }
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 4)

                    // Price + discount
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String(format: "€%.2f", pick.promoPrice))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(greenGradient)

                        Text(String(format: "€%.2f", pick.originalPrice))
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.35))
                            .strikethrough(true, color: .white.opacity(0.35))
                    }
                    .fixedSize()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    // Mechanism + savings
                    HStack(spacing: 8) {
                        Text(pick.mechanism)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(greenGradient))

                        HStack(spacing: 3) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "€%.2f saved", pick.savings))
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(promoGreen)

                        Spacer()
                    }

                    // Reason
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow.opacity(0.8))
                            .padding(.top, 2)

                        Text(pick.reason)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.5))
                            .italic()
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    // Validity + folder link
                    HStack {
                        Text("Valid \(pick.validityStart) - \(pick.validityEnd)")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.3))

                        Spacer()

                        if let urlString = pick.promoFolderUrl, let url = URL(string: urlString) {
                            Link(destination: url) {
                                HStack(spacing: 3) {
                                    Text("View in folder")
                                        .font(.system(size: 11, weight: .medium))
                                    Image(systemName: "arrow.up.right")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundColor(.blue.opacity(0.8))
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .clipped()
            }
        }
        .background(isExpanded ? Color.white.opacity(0.02) : Color.clear)
    }
}

// MARK: - Smart Switch Card

struct PromoSmartSwitchCard: View {
    let smartSwitch: PromoSmartSwitch
    @State private var arrowOffset: Bool = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("SMART SWITCH")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.2)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple.opacity(0.8), .blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Spacer()
            }

            // From → To
            HStack(spacing: 10) {
                Text(smartSwitch.emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.06)))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(smartSwitch.fromBrand)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .strikethrough(true, color: .white.opacity(0.3))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .offset(x: arrowOffset ? 3 : 0)

                        Text(smartSwitch.toBrand)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(smartSwitch.productType)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.4))
                }

                Spacer()

                // Savings badge
                VStack(spacing: 2) {
                    Text(String(format: "€%.2f", smartSwitch.savings))
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(greenGradient)
                    Text("saved")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Mechanism + Reason
            Text(smartSwitch.mechanism)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.06)))

            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.yellow.opacity(0.8))
                    .padding(.top, 2)

                Text(smartSwitch.reason)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .italic()
            }
        }
        .padding(16)
        .glassCard(
            borderGradient: LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                arrowOffset = true
            }
        }
    }
}

// MARK: - Store Section

struct PromoStoreSection: View {
    let store: PromoStore
    let index: Int
    @State private var isExpanded = false
    @State private var appeared = false

    private let initialItemCount = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Store header
            HStack(spacing: 10) {
                // Color dot
                Circle()
                    .fill(store.color)
                    .frame(width: 8, height: 8)

                Text(store.storeName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "€%.2f", store.totalSavings))
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(promoGreen)

                    Text("valid until \(store.validityEnd)")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.3))
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
                    PromoItemRow(item: item, storeColor: store.color)
                }
            }

            // Show more / less
            if store.items.count > initialItemCount {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isExpanded.toggle()
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

            // Tip
            if !store.tip.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.yellow.opacity(0.8))
                        .padding(.top, 1)

                    Text(store.tip)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.03))
                .padding(.bottom, 4)
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
    let storeColor: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Emoji
            Text(item.emoji)
                .font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.04)))

            // Brand (title) + product name + mechanism
            VStack(alignment: .leading, spacing: 3) {
                Text(hasValidBrand(item.brand) ? item.brand : item.productName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    if hasValidBrand(item.brand) {
                        Text(item.productName)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(2)
                    }

                    Text(item.mechanism)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(storeColor.opacity(0.15)))
                        .fixedSize()
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            // Prices
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "€%.2f", item.promoPrice))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(greenGradient)

                Text(String(format: "€%.2f", item.originalPrice))
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.35))
                    .strikethrough(true, color: .white.opacity(0.35))
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Summary Footer

struct PromoSummaryFooter: View {
    let summary: PromoSummary
    let stores: [PromoStore]
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

                    Text("Best value: **\(bestStore)**")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.7))

                    Text("\(summary.bestValueItems) items, \(String(format: "€%.2f", summary.bestValueSavings)) saved")
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
                                let proportion = summary.totalSavings > 0
                                    ? breakdown.savings / summary.totalSavings
                                    : 1.0 / Double(summary.storesBreakdown.count)
                                let storeColor = stores.first(where: { $0.storeName == breakdown.store })?.color ?? .gray

                                RoundedRectangle(cornerRadius: 4)
                                    .fill(storeColor)
                                    .frame(width: max(4, (geometry.size.width - CGFloat(summary.storesBreakdown.count - 1) * 2) * proportion))
                            }
                        }
                    }
                    .frame(height: 8)

                    // Legend
                    HStack(spacing: 12) {
                        ForEach(summary.storesBreakdown) { breakdown in
                            let storeColor = stores.first(where: { $0.storeName == breakdown.store })?.color ?? .gray
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(storeColor)
                                    .frame(width: 6, height: 6)
                                Text(breakdown.store)
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                        Spacer()
                    }
                }
            }

            // Closing nudge
            Text(summary.closingNudge)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(greenGradient)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bag.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.white.opacity(0.2), .white.opacity(0.1)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("No deals this week")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Keep scanning receipts so we can find\npersonalized deals for you")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
        .padding(.horizontal, 32)
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
