//
//  BrandCashbackGridCard.swift
//  Scandalicious
//
//  The workhorse cashback tile: 1:1 product image with overlaid cashback chip,
//  brand eyebrow, product title, optional cap progress, and a state overlay
//  (claimed check, earned seal, expired/sold-out wash).
//

import SwiftUI

// MARK: - State

enum CashbackCardState {
    case available
    case claimed
    case pendingReview
    case partiallyEarned    // 1+ earnings, max > 1, more to go
    case earned
    case expired
    case soldOut

    static func from(_ deal: BrandCashbackDeal) -> CashbackCardState {
        if let cap = deal.totalRedemptionCap, let curr = deal.currentRedemptions, curr >= cap {
            return .soldOut
        }
        if deal.isExpired { return .expired }
        // Pending review > earned > partial > claimed > available — first match wins.
        switch deal.status {
        case .pendingReview: return .pendingReview
        case .earned:        return .earned
        case .claimed:       return deal.isPartiallyEarned ? .partiallyEarned : .claimed
        case .available:     return .available
        }
    }
}

// MARK: - Card

struct BrandCashbackGridCard: View {
    let deal: BrandCashbackDeal
    var onTap: () -> Void

    private static let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
    private static let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)
    private static let warningOrange = Color(red: 1.00, green: 0.55, blue: 0.20)

    /// Photo + info heights are fixed so every card in the grid is identical.
    /// Mirrors the My List card layout (white photo on top, info below).
    private static let photoHeight: CGFloat = 140
    private static let infoSectionHeight: CGFloat = 90

    private var state: CashbackCardState { CashbackCardState.from(deal) }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                photoSection
                infoSection
                    .frame(height: Self.infoSectionHeight)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(stateOverlay)
        }
        .buttonStyle(CashbackCardButtonStyle())
    }

    // MARK: Photo (white bg, fitted product image — matches My List card)

    private var photoSection: some View {
        ZStack(alignment: .topLeading) {
            Color.white
                .frame(height: Self.photoHeight)

            // Prefer the square thumb; fall back to hero for legacy campaigns.
            AsyncImage(url: deal.imageThumbUrl ?? deal.imageUrl) { phase in
                switch phase {
                case .empty:
                    ShimmerPlaceholder()
                        .frame(maxWidth: .infinity, maxHeight: Self.photoHeight - 16)
                        .padding(8)
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: Self.photoHeight - 20)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .saturation(state == .earned ? 0.75 : (state == .expired ? 0 : 1))
                        .opacity(state == .expired || state == .soldOut ? 0.55 : 1)
                case .failure:
                    Image(systemName: "tag.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.18))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(height: Self.photoHeight)
        .clipped()
        .overlay(alignment: .topLeading) {
            if deal.featured {
                FeaturedPill().padding(8)
            }
        }
        .overlay(alignment: .topTrailing) {
            statusBadge
                .overlay(alignment: .topTrailing) { denialDot }
                .padding(8)
        }
        .overlay(alignment: .bottomTrailing) {
            CashbackChip(amount: deal.cashbackAmount, size: .small, emphasis: chipEmphasis)
                .padding(8)
        }
    }

    // MARK: Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deal.brandName.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .tracking(1.0)
                .foregroundStyle(eyebrowColor)
                .lineLimit(1)

            Text(deal.productName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if deal.capFillRatio != nil {
                capProgressBar
            }

            footerLine
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var capProgressBar: some View {
        let ratio = deal.capFillRatio ?? 0
        let nearlyFull = deal.isNearlyFull
        let color: Color = nearlyFull ? Self.warningOrange : Self.cashbackGreen
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 3)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, geo.size.width * ratio), height: 3)
            }
        }
        .frame(height: 3)
    }

    @ViewBuilder
    private var footerLine: some View {
        switch state {
        case .available:
            HStack(spacing: 4) {
                Text(deal.requiresStore ? deal.eligibleStores.first ?? "All stores" : "All stores")
                Text("·")
                Text(deal.formattedExpiry)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white.opacity(0.4))
            .lineLimit(1)
        case .claimed:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 9, weight: .bold))
                Text(deal.redemptionProgressLabel ?? "Claimed")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(Self.cashbackGreen)
        case .pendingReview:
            HStack(spacing: 4) {
                Image(systemName: "hourglass.bottomhalf.filled").font(.system(size: 9, weight: .bold))
                Text("Reviewing receipt")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(Self.warningOrange)
        case .partiallyEarned:
            HStack(spacing: 4) {
                Image(systemName: "seal.fill").font(.system(size: 9, weight: .bold))
                Text("\(deal.redemptionProgressLabel ?? "Earned") · Buy again")
                    .font(.system(size: 10, weight: .heavy))
                    .lineLimit(1)
            }
            .foregroundStyle(Self.cashbackGold)
        case .earned:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill").font(.system(size: 10, weight: .bold))
                Text("Earned")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(0.5)
            }
            .foregroundStyle(Self.cashbackGold)
        case .expired:
            Text("Expired")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.30))
        case .soldOut:
            Text("Sold out")
                .font(.system(size: 10, weight: .heavy))
                .tracking(0.5)
                .foregroundStyle(Self.warningOrange)
        }
    }

    // MARK: Status badge (top-right)

    @ViewBuilder
    private var statusBadge: some View {
        switch state {
        case .claimed:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Self.cashbackGreen))
                .overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 1))
        case .pendingReview:
            Image(systemName: "hourglass")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Self.warningOrange))
                .overlay(Circle().stroke(.black.opacity(0.15), lineWidth: 1))
        case .partiallyEarned:
            Text("\(deal.earningsCount)/\(deal.maxRedemptionsPerUser ?? 1)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .frame(height: 22)
                .background(Capsule().fill(Self.cashbackGold))
                .overlay(Capsule().stroke(.black.opacity(0.15), lineWidth: 1))
        case .earned:
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Self.cashbackGold)
                .shadow(color: Self.cashbackGold.opacity(0.5), radius: 4)
        case .expired:
            Text("EXPIRED")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.10)))
        case .soldOut:
            Text("SOLD OUT")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Self.warningOrange))
        case .available:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private var chipEmphasis: CashbackChip.Emphasis {
        switch state {
        case .available, .claimed, .pendingReview, .partiallyEarned: return .filled
        case .earned: return .filled
        case .expired, .soldOut: return .muted
        }
    }

    private var eyebrowColor: Color {
        switch state {
        case .earned: return Self.cashbackGold
        case .expired, .soldOut: return .white.opacity(0.35)
        default: return Self.cashbackGold
        }
    }

    /// Notification-badge-style red dot on the status badge when the user has a
    /// recent denial. Hidden in the `.pendingReview` state (a fresher receipt
    /// is in flight, so the prior denial is no longer the most recent signal)
    /// and in `.available` (no claim → nothing to nudge about).
    @ViewBuilder
    private var denialDot: some View {
        if deal.recentDenial != nil, state != .pendingReview, state != .available {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                .offset(x: 2, y: -2)
        }
    }

    @ViewBuilder
    private var stateOverlay: some View {
        if state == .expired {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Featured pill

private struct FeaturedPill: View {
    private static let gold = Color(red: 1.0, green: 0.80, blue: 0.20)

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 8, weight: .black))
            Text("FEATURED")
                .font(.system(size: 9, weight: .heavy))
                .tracking(0.8)
        }
        .foregroundStyle(Self.gold)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().fill(Self.gold.opacity(0.12)))
        )
        .overlay(Capsule().stroke(Self.gold.opacity(0.45), lineWidth: 0.5))
    }
}

// MARK: - Shimmer

private struct ShimmerPlaceholder: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(0.05))
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.10), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase * 300)
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Press animation

private struct CashbackCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}
