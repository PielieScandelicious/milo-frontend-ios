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
private let borderTop = Color.white.opacity(0.12)
private let borderBottom = Color.white.opacity(0.04)

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
                        lineWidth: 1
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
    @State private var shimmerX: CGFloat = -1
    @State private var iconPulse = false

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle, .loading:
                bannerSkeleton
            case .success(let data) where data.dealCount > 0:
                bannerContent(data)
            case .success:
                // deal_count == 0
                debugBanner("No deals found yet — keep scanning receipts!")
            case .error(let message):
                debugBanner("Deals: \(message)")
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
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
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
        HStack(spacing: 12) {
            // Pulsing green icon
            ZStack {
                Circle()
                    .fill(promoGreen.opacity(iconPulse ? 0.3 : 0.12))
                    .frame(width: 40, height: 40)
                    .scaleEffect(iconPulse ? 1.15 : 1.0)

                Image(systemName: "tag.fill")
                    .font(.system(size: 16))
                    .foregroundColor(promoGreen)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Loading deals...")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))

                Text("Scanning promotions")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.3))
            }

            Spacer()

            ProgressView()
                .tint(promoGreen)
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackground)
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [promoGreen.opacity(0.06), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [promoGreen.opacity(0.35), promoGreenDark.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Green shimmer sweep
        .overlay(
            GeometryReader { geo in
                LinearGradient(
                    colors: [
                        .clear,
                        promoGreen.opacity(0.15),
                        Color.white.opacity(0.10),
                        promoGreen.opacity(0.15),
                        .clear
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.5)
                .offset(x: shimmerX * geo.size.width)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                iconPulse = true
            }
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                shimmerX = 1.5
            }
        }
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
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: emoji + name + discount badge
            HStack(alignment: .top, spacing: 12) {
                // Emoji circle
                Text(pick.emoji)
                    .font(.system(size: 22))
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Color.white.opacity(0.06)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(pick.productName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Text("\(pick.brand) · \(pick.store)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
                .layoutPriority(1)

                Spacer(minLength: 4)

                // Discount badge
                Text(pick.mechanism)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(greenGradient))
                    .fixedSize()
            }

            // Prices
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "€%.2f", pick.promoPrice))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(greenGradient)

                Text(String(format: "€%.2f", pick.originalPrice))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.4))
                    .strikethrough(true, color: .white.opacity(0.4))

                Spacer()

                // Savings capsule
                HStack(spacing: 3) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 9, weight: .bold))
                    Text(String(format: "€%.2f", pick.savings))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(promoGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(promoGreen.opacity(0.12)))
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
        .padding(16)
        .glassCard()
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(Double(index) * 0.08)) {
                appeared = true
            }
        }
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
                        Divider()
                            .background(Color.white.opacity(0.06))
                            .padding(.horizontal, 16)
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
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.04))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
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

            // Name + brand + mechanism
            VStack(alignment: .leading, spacing: 3) {
                Text(item.productName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text(item.brand)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)

                    Text(item.mechanism)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(storeColor.opacity(0.15)))
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

// MARK: - Skeleton Loading View

struct PromoSkeletonView: View {
    @State private var pulse = false
    @State private var shimmerPhase: CGFloat = -1
    @State private var appeared = false

    private let accentGreen = Color(red: 0.20, green: 0.85, blue: 0.50)

    var body: some View {
        VStack(spacing: 16) {
            // Hero loading card
            VStack(spacing: 20) {
                // Pulsing rings + icon
                ZStack {
                    // Outer pulse ring
                    Circle()
                        .stroke(accentGreen.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                        .scaleEffect(pulse ? 1.5 : 1.0)
                        .opacity(pulse ? 0.0 : 0.8)

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentGreen.opacity(0.3), accentGreen.opacity(0.05)],
                                center: .center,
                                startRadius: 0,
                                endRadius: 36
                            )
                        )
                        .frame(width: 72, height: 72)

                    // Icon circle
                    Circle()
                        .fill(accentGreen.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(accentGreen)
                        )
                }

                VStack(spacing: 6) {
                    Text("Finding your deals...")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Scanning promotions across stores")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.35))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [accentGreen.opacity(0.08), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [accentGreen.opacity(0.4), accentGreen.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )

            // Placeholder cards with shimmer
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 46, height: 46)

                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.14))
                            .frame(width: CGFloat([140, 120, 160][index]), height: 14)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: CGFloat([100, 80, 110][index]), height: 10)
                    }

                    Spacer()

                    RoundedRectangle(cornerRadius: 10)
                        .fill(accentGreen.opacity(0.15))
                        .frame(width: 54, height: 28)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    // Shimmer sweep
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [
                                .clear,
                                accentGreen.opacity(0.10),
                                Color.white.opacity(0.12),
                                accentGreen.opacity(0.10),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: shimmerPhase * geo.size.width)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                )
            }
        }
        .padding(.horizontal, 16)
        .opacity(appeared ? 1.0 : 0.0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.5
            }
        }
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
