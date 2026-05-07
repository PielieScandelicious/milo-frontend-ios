//
//  BrandCashbackGridCard.swift
//  Scandalicious
//
//  Hosts the redesigned 1-deal-per-row editorial card (`DealRow`) plus the
//  `CashbackCardState` enum that the rest of the cashback feature still
//  consumes.
//
//  The original 2-column grid card has been replaced; this file now exposes:
//    • CashbackCardState  — backend status → UI state collapse
//    • DealRow            — the new editorial row used in MY DEALS / ALL DEALS
//    • BrandCashbackGridCard — thin wrapper preserved for any callers still
//                              referencing the old name (delegates to DealRow)
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
        switch deal.status {
        case .pendingReview: return .pendingReview
        case .earned:        return .earned
        case .claimed:       return deal.isPartiallyEarned ? .partiallyEarned : .claimed
        case .available:     return .available
        }
    }
}

// MARK: - DealRow

/// 1-deal-per-row editorial card. 124pt photo block on the left with a brand
/// logo disc + state badge, content block on the right with eyebrow, serif
/// title, terms and a state-specific footer + CTA.
struct DealRow: View {
    let deal: BrandCashbackDeal
    var onTap: () -> Void

    private var state: CashbackCardState { CashbackCardState.from(deal) }

    private static let cornerRadius: CGFloat = 18
    private static let cardHeight: CGFloat = 184

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 0) {
                photoBlock
                contentBlock
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: Self.cardHeight)
            .background(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .fill(CashbackTokens.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                    .stroke(CashbackTokens.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        }
        .buttonStyle(DealRowButtonStyle())
    }

    // MARK: Photo

    private var photoBlock: some View {
        let size = CashbackTokens.gridPhotoSize
        return ZStack(alignment: .topLeading) {
            // White product-tile background fills the full photo column so
            // there's no visible seam between the photo area and the card body.
            Color.white

            // Backdrop: real photo if available, otherwise a soft placeholder.
            // The image is wrapped twice — inner .frame fixes its square size
            // (matches the backend's 1:1 thumbnail), outer .frame expands and
            // centers it vertically within the variable-height column so the
            // product takes as much space as possible while staying centred.
            AsyncImage(url: deal.imageThumbUrl ?? deal.imageUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .empty:
                    PhotoPlaceholder(label: deal.productName)
                case .failure:
                    PhotoPlaceholder(label: deal.brandName)
                @unknown default:
                    PhotoPlaceholder(label: deal.brandName)
                }
            }
            .frame(width: size, height: size)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .clipped()

            // State badge — top-right
            VStack {
                HStack {
                    Spacer()
                    stateBadge
                        .padding(8)
                }
                Spacer()
            }
        }
        .frame(width: size)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var stateBadge: some View {
        switch state {
        case .claimed:
            EmptyView()
        case .pendingReview:
            ZStack {
                Circle().fill(CashbackTokens.warn)
                Image(systemName: "hourglass")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 22, height: 22)
        case .partiallyEarned:
            Text(progressBadgeText)
                .font(CashbackFont.mono(10, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(CashbackTokens.goldInk)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(CashbackTokens.gold))
        case .earned:
            ZStack {
                Circle().fill(CashbackTokens.gold)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(CashbackTokens.goldInk)
            }
            .frame(width: 22, height: 22)
        case .expired:
            EmptyView()
        case .soldOut:
            Text("SOLD OUT")
                .font(CashbackFont.sans(9, weight: .heavy))
                .tracking(0.7)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(CashbackTokens.warn))
        case .available:
            EmptyView()
        }
    }

    private var progressBadgeText: String {
        let max = deal.maxRedemptionsPerUser ?? 1
        return "\(deal.earningsCount)/\(max)"
    }

    // MARK: Content

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            // Brand logo — white disc with logo on top
            BrandLogoDisc(
                brand: deal.brandName,
                brandColor: brandAccentColor,
                logoURL: deal.brandLogoUrl,
                size: 52,
                ring: false
            )
            .padding(.bottom, 10)

            // Title — serif, max 2 lines
            Text(deal.productName)
                .font(CashbackFont.serif(13))
                .kerning(-0.2)
                .foregroundStyle(CashbackTokens.textPrimary)
                .lineSpacing(2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            DaysLeftPill(days: deal.daysRemaining)
                .padding(.top, 10)

            Spacer(minLength: 0)

            // Bottom row: footer (left) and CTA (right, available only)
            HStack(alignment: .bottom) {
                stateFooter
                Spacer(minLength: 8)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 14)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var stateFooter: some View {
        switch state {
        case .available:
            if let ratio = deal.capFillRatio {
                capProgress(ratio: ratio)
            }
        case .claimed:
            EmptyView()
        case .partiallyEarned:
            partialFooter
        case .pendingReview:
            Text("Reviewing receipt · ~24h")
                .font(CashbackFont.sans(10.5, weight: .medium))
                .kerning(-0.05)
                .foregroundStyle(CashbackTokens.warn)
        case .earned:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 10, weight: .bold))
                Text("Earned")
                    .font(CashbackFont.sans(10.5, weight: .semibold))
                    .tracking(0.5)
            }
            .foregroundStyle(CashbackTokens.gold)
        case .expired:
            EmptyView()
        case .soldOut:
            Text("Sold out")
                .font(CashbackFont.sans(10.5, weight: .medium))
                .foregroundStyle(CashbackTokens.warn)
        }
    }

    private var partialFooter: some View {
        let earned = deal.cashbackAmount * Double(deal.earningsCount)
        let max = deal.maxRedemptionsPerUser ?? 1
        let remaining = Swift.max(0, max - deal.earningsCount)
        return HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(String(format: "€%.2f", earned))
                .font(CashbackFont.mono(10.5, weight: .semibold))
                .monospacedDigit()
            Text("earned · buy \(remaining) more")
                .font(CashbackFont.sans(10.5, weight: .medium))
                .kerning(-0.05)
        }
        .foregroundStyle(CashbackTokens.gold)
    }

    private func capProgress(ratio: Double) -> some View {
        let nearlyFull = ratio > 0.85
        let fillColor: Color = nearlyFull ? CashbackTokens.warn : CashbackTokens.green
        return VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(CashbackTokens.text08)
                    .frame(width: 96, height: 3)
                Capsule()
                    .fill(fillColor)
                    .frame(width: 96 * CGFloat(min(max(ratio, 0), 1)), height: 3)
            }
            Text("\(Int((ratio * 100).rounded()))% claimed")
                .font(CashbackFont.mono(9.5, weight: .medium))
                .kerning(0.1)
                .foregroundStyle(CashbackTokens.text40)
        }
    }

    // MARK: Helpers

    /// Brand monogram color. Future: hydrate from backend `brand_color`.
    private var brandAccentColor: Color {
        // Stable per-brand color so the disc reads as a brand mark.
        let palette: [Color] = [
            Color(red: 0.902, green: 0.224, blue: 0.275),  // red
            Color(red: 0.357, green: 0.784, blue: 0.357),  // green
            Color(red: 0.058, green: 0.102, blue: 0.180),  // navy
            Color(red: 1.000, green: 0.780, blue: 0.165),  // amber
            Color(red: 0.843, green: 0.125, blue: 0.153),  // crimson
            Color(red: 0.110, green: 0.110, blue: 0.122),  // ink
        ]
        let hash = abs(deal.brandName.hashValue)
        return palette[hash % palette.count]
    }
}

// MARK: - Days-left pill

private struct DaysLeftPill: View {
    let days: Int  // negative = expired

    var body: some View {
        Text(label)
            .font(CashbackFont.sans(10.5, weight: .semibold))
            .monospacedDigit()
            .kerning(-0.05)
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(background))
            .overlay(Capsule().stroke(stroke, lineWidth: 1))
    }

    private var label: String {
        if days < 0 { return "Expired" }
        if days == 0 { return "Last day" }
        return "\(days)d left"
    }

    private var foreground: Color {
        switch days {
        case ..<0: return CashbackTokens.text40
        case 0: return CashbackTokens.gold
        case 1...3: return CashbackTokens.warn
        default: return CashbackTokens.text70
        }
    }
    private var background: Color {
        switch days {
        case ..<0: return Color.white.opacity(0.04)
        case 0: return CashbackTokens.gold.opacity(0.10)
        case 1...3: return CashbackTokens.warn.opacity(0.10)
        default: return Color.white.opacity(0.04)
        }
    }
    private var stroke: Color {
        switch days {
        case ..<0: return CashbackTokens.text15
        case 0: return CashbackTokens.gold.opacity(0.40)
        case 1...3: return CashbackTokens.warn.opacity(0.40)
        default: return CashbackTokens.text15
        }
    }
}

// MARK: - Photo placeholder

private struct PhotoPlaceholder: View {
    let label: String

    var body: some View {
        let size = CashbackTokens.gridPhotoSize
        ZStack {
            Color(red: 0.957, green: 0.949, blue: 0.933)
            // subtle diagonal stripes
            GeometryReader { geo in
                Path { p in
                    let step: CGFloat = 16
                    var x: CGFloat = -geo.size.height
                    while x < geo.size.width {
                        p.move(to: CGPoint(x: x, y: geo.size.height))
                        p.addLine(to: CGPoint(x: x + geo.size.height, y: 0))
                        x += step
                    }
                }
                .stroke(Color.black.opacity(0.04), lineWidth: 8)
            }
            Text(label)
                .font(CashbackFont.mono(9))
                .tracking(0.5)
                .foregroundStyle(.black.opacity(0.45))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: size - 16)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Press style

private struct DealRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

// MARK: - Legacy alias

/// Preserved so any out-of-tree references to `BrandCashbackGridCard`
/// continue to compile while we migrate. New code should use `DealRow`.
struct BrandCashbackGridCard: View {
    let deal: BrandCashbackDeal
    var onTap: () -> Void

    var body: some View {
        DealRow(deal: deal, onTap: onTap)
    }
}
