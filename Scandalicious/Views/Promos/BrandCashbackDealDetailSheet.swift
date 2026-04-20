//
//  BrandCashbackDealDetailSheet.swift
//  Scandalicious
//
//  Full-screen sheet showing a cashback deal's details: claim window,
//  how-it-works, eligible stores, products, cap progress, and terms.
//

import SwiftUI

// MARK: - Colours

private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
private let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)
private let warningAmber  = Color(red: 1.0, green: 0.72, blue: 0.20)
private let warningOrange = Color(red: 1.0, green: 0.55, blue: 0.20)

// MARK: - BrandCashbackDealDetailSheet

struct BrandCashbackDealDetailSheet: View {
    let deal: BrandCashbackDeal
    let onClaim: () -> Void
    let onUnclaim: () -> Void
    let onViewReceipt: ((String) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var termsExpanded = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    claimWindowSection
                    howItWorksSection
                    eligibleStoresSection

                    if let skus = deal.eligibleSKUs, !skus.isEmpty {
                        eligibleProductsSection(skus: skus)
                    }

                    if deal.capProgressLabel != nil {
                        campaignStatusSection
                    }

                    termsSection

                    // Padding so sticky CTA doesn't overlap last item
                    Color.clear.frame(height: 96)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            stickyActionButton
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(Color(red: 0.06, green: 0.06, blue: 0.08))
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(cashbackGreen.opacity(0.12))
                    .frame(width: 88, height: 88)
                Circle()
                    .stroke(cashbackGreen.opacity(0.35), lineWidth: 1.5)
                    .frame(width: 88, height: 88)
                Image(systemName: deal.imageSystemName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(cashbackGreen)
            }

            Text(deal.brandName.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(cashbackGold)

            Text(deal.productName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text(deal.formattedCashback)
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundStyle(cashbackGreen)
                .padding(.top, 4)

            if !deal.description.isEmpty {
                Text(deal.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Claim Window

    private var claimWindowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "CLAIM WINDOW", icon: "clock.fill")

            VStack(alignment: .leading, spacing: 8) {
                if deal.isClaimExpired {
                    claimWindowRow(
                        icon: "xmark.circle.fill",
                        text: "Your claim window expired",
                        color: .white.opacity(0.35)
                    )
                } else if deal.status == .claimed, let days = deal.daysUntilClaimExpires {
                    let color: Color = days <= 3 ? warningAmber : cashbackGreen
                    claimWindowRow(
                        icon: "clock.fill",
                        text: days == 0 ? "Last day to buy and scan your receipt" :
                              days == 1 ? "1 day left to buy and scan your receipt" :
                              "\(days) days left to buy and scan your receipt",
                        color: color
                    )
                    claimProgressBar(remaining: days, total: 14, color: color)
                } else if deal.status == .earned {
                    claimWindowRow(
                        icon: "checkmark.seal.fill",
                        text: "Cashback earned and added to your wallet",
                        color: cashbackGold
                    )
                } else {
                    claimWindowRow(
                        icon: "hourglass",
                        text: "Buy within 14 days of claiming",
                        color: .white.opacity(0.70)
                    )
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private func claimWindowRow(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    private func claimProgressBar(remaining: Int, total: Int, color: Color) -> some View {
        let ratio = max(0, min(1, Double(remaining) / Double(total)))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * ratio)
            }
        }
        .frame(height: 4)
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "HOW IT WORKS", icon: "checklist")

            let steps = deal.howItWorks ?? defaultSteps
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepRow(number: index + 1, text: step)
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private var defaultSteps: [String] {
        [
            "Claim this deal now",
            deal.requiresStore && !deal.eligibleStores.isEmpty
                ? "Buy \(deal.productName) at \(deal.eligibleStores.joined(separator: ", "))"
                : "Buy \(deal.productName) at any eligible store",
            "Open your receipt, tap Share, and select Milo",
        ]
    }

    private func stepRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(cashbackGreen))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Eligible Stores

    private var eligibleStoresSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "ELIGIBLE STORES", icon: "storefront.fill")

            if deal.requiresStore && !deal.eligibleStores.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(deal.eligibleStores, id: \.self) { storeName in
                            storePill(for: storeName)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(cashbackGreen)
                    Text("Valid at all supported stores")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassCard()
            }
        }
    }

    private func storePill(for storeName: String) -> some View {
        let color = GroceryStore(rawValue: storeName)?.accentColor ?? .white.opacity(0.6)
        return HStack(spacing: 6) {
            StoreLogoView(storeName: storeName, height: 14)
            Text(storeName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(color.opacity(0.12)))
        .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Eligible Products

    private func eligibleProductsSection(skus: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "ELIGIBLE PRODUCTS", icon: "shippingbox.fill")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(skus, id: \.self) { sku in
                    HStack(alignment: .top, spacing: 10) {
                        Circle()
                            .fill(cashbackGreen.opacity(0.6))
                            .frame(width: 5, height: 5)
                            .padding(.top, 6)
                        Text(sku)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    // MARK: - Campaign Status

    private var campaignStatusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "CAMPAIGN STATUS", icon: "chart.bar.fill")

            let ratio = deal.capFillRatio ?? 0
            let nearlyFull = deal.isNearlyFull
            let color: Color = nearlyFull ? warningOrange : cashbackGreen

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if nearlyFull {
                        Text("Almost full")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(color)
                    } else {
                        Text("Available")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if let label = deal.capProgressLabel {
                        Text(label)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 6)

                Text("Campaign ends \(deal.formattedExpiry.lowercased())")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(14)
            .glassCard()
        }
    }

    // MARK: - Terms

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    termsExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("TERMS & CONDITIONS")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .rotationEffect(.degrees(termsExpanded ? 180 : 0))
                }
                .foregroundStyle(.white.opacity(0.55))
            }
            .buttonStyle(.plain)

            if termsExpanded {
                Text(deal.terms ?? defaultTerms)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineSpacing(3)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            }
        }
    }

    private var defaultTerms: String {
        """
        Cashback is paid to your Milo wallet within 48 hours of receipt verification. Limited to once per household per campaign. Receipt must be dated within the campaign period and no older than 14 days at time of scan. Milo reserves the right to reject fraudulent submissions. By claiming this offer, you consent to sharing anonymised purchase data with the sponsoring brand for campaign analytics.
        """
    }

    // MARK: - Sticky CTA

    private var stickyActionButton: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Color.clear, Color(red: 0.06, green: 0.06, blue: 0.08)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 24)

            HStack {
                primaryCTA
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .padding(.top, 4)
            .background(Color(red: 0.06, green: 0.06, blue: 0.08))
        }
    }

    @ViewBuilder
    private var primaryCTA: some View {
        switch (deal.status, deal.isClaimExpired) {
        case (_, true):
            disabledCTA(text: "Claim expired")
        case (.available, false):
            Button {
                onClaim()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } label: {
                ctaLabel(
                    text: "Claim \(deal.formattedCashback)",
                    textColor: .black,
                    fill: cashbackGreen
                )
            }
        case (.claimed, false):
            Button {
                onUnclaim()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                let daysText = deal.claimCountdownLabel ?? "Claimed"
                ctaLabel(
                    text: "Claimed · \(daysText)",
                    textColor: cashbackGreen,
                    fill: .clear,
                    border: cashbackGreen
                )
            }
        case (.pending, false):
            disabledCTA(text: "Processing...")
        case (.earned, false):
            if let matchedId = deal.matchedReceiptId, let onViewReceipt {
                Button {
                    dismiss()
                    onViewReceipt(matchedId)
                } label: {
                    ctaLabel(
                        text: "Earned — view receipt",
                        textColor: .black,
                        fill: cashbackGold
                    )
                }
            } else {
                disabledCTA(text: "Earned", textColor: cashbackGold)
            }
        case (.expired, false):
            disabledCTA(text: "Expired")
        }
    }

    private func ctaLabel(text: String, textColor: Color, fill: Color, border: Color? = nil) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(fill))
            .overlay(
                Capsule().stroke(border ?? .clear, lineWidth: border == nil ? 0 : 1.5)
            )
    }

    private func disabledCTA(text: String, textColor: Color = .white.opacity(0.35)) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Capsule().fill(Color.white.opacity(0.06)))
    }

    // MARK: - Section Header

    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(cashbackGreen)
            Text(title)
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.55))
            Spacer()
        }
    }
}
