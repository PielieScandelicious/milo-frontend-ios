//
//  BrandCashbackDealDetailSheet.swift
//  Scandalicious
//
//  Full-screen sheet showing a cashback deal's details: validity, how-it-works,
//  eligible stores, products, cap progress, and terms.
//

import SwiftUI

// MARK: - Colours

private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
private let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)
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
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    productHero

                    VStack(alignment: .leading, spacing: 24) {
                        heroTitleBlock
                        validitySection
                        howItWorksSection
                        eligibleStoresSection

                        if let skus = deal.eligibleSKUs, !skus.isEmpty {
                            eligibleProductsSection(skus: skus)
                        }

                        if deal.capProgressLabel != nil {
                            campaignStatusSection
                        }

                        termsSection
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 120)  // clearance for sticky CTA
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.06, green: 0.09, blue: 0.14), location: 0.0),
                        .init(color: Color(red: 0.04, green: 0.06, blue: 0.10), location: 0.4),
                        .init(color: Color(red: 0.03, green: 0.04, blue: 0.07), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .overlay(alignment: .bottom) {
                stickyActionButton
            }
            .overlay(alignment: .topTrailing) {
                closeButton
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Hero

    private var productHero: some View {
        ZStack {
            Color.white

            AsyncImage(url: deal.imageUrl) { phase in
                switch phase {
                case .empty:
                    EmptyView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                case .failure:
                    Image(systemName: "tag.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.18))
                @unknown default:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
        .overlay(alignment: .bottomTrailing) {
            CashbackChip(amount: deal.cashbackAmount, size: .large, emphasis: .filled)
                .padding(.trailing, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Close button (sheet dismiss affordance)

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
                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
        .padding(.trailing, 16)
        .padding(.top, 12)
    }

    // MARK: - Title Block

    private var heroTitleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(deal.brandName.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(cashbackGold)

            Text(deal.productName)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)

            if !deal.description.isEmpty {
                Text(deal.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Validity (campaign expiration + per-user progress + review state)

    private var validitySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "VALIDITY", icon: "calendar")

            VStack(alignment: .leading, spacing: 8) {
                validityRow(
                    icon: "calendar",
                    text: "Valid \(deal.formattedExpiry.lowercased())",
                    color: deal.isExpired ? .white.opacity(0.35) : cashbackGreen
                )

                if deal.isPartiallyEarned, let max = deal.maxRedemptionsPerUser {
                    let earnedSoFar = Double(deal.earningsCount) * deal.cashbackAmount
                    let perEarning = String(format: "€%.2f", deal.cashbackAmount)
                    validityRow(
                        icon: "seal.fill",
                        text: "Earned \(deal.earningsCount) of \(max) · \(String(format: "€%.2f", earnedSoFar)) in your wallet so far",
                        color: cashbackGold
                    )
                    validityRow(
                        icon: "cart.fill",
                        text: "Buy this product again to earn another \(perEarning)",
                        color: .white.opacity(0.70)
                    )
                } else if deal.status == .claimed, let progress = deal.redemptionProgressLabel {
                    validityRow(
                        icon: "checkmark.circle.fill",
                        text: progress,
                        color: cashbackGreen
                    )
                } else if deal.status == .earned {
                    validityRow(
                        icon: "checkmark.seal.fill",
                        text: "Cashback earned and added to your wallet",
                        color: cashbackGold
                    )
                }

                if deal.pendingReview != nil {
                    validityRow(
                        icon: "hourglass.bottomhalf.filled",
                        text: "Receipt under review — usually within 24h",
                        color: warningOrange
                    )
                }
                if let denial = deal.recentDenial {
                    validityRow(
                        icon: "xmark.octagon.fill",
                        text: "Last receipt: not eligible — \(denial.reason)",
                        color: .white.opacity(0.55)
                    )
                }
            }
            .padding(14)
            .glassCard()
        }
    }

    private func validityRow(icon: String, text: String, color: Color) -> some View {
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
        Cashback is paid to your Milo wallet within 48 hours of receipt verification. Limited per campaign as set by the brand. Receipt must be dated within the campaign period. Milo reserves the right to reject fraudulent submissions. By claiming this offer, you consent to sharing anonymised purchase data with the sponsoring brand for campaign analytics.
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
        if deal.isExpired {
            disabledCTA(text: "Campaign expired")
        } else {
            switch deal.status {
            case .available:
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
            case .claimed:
                if deal.isPartiallyEarned, let max = deal.maxRedemptionsPerUser {
                    // Mid-progress: celebrate the win, invite repeat purchase.
                    // Tap still releases the claim — earnings already in the
                    // wallet are preserved by the backend.
                    Button {
                        onUnclaim()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        ctaLabel(
                            text: "Earned \(deal.earningsCount) of \(max) · tap to release",
                            textColor: cashbackGold,
                            fill: .clear,
                            border: cashbackGold
                        )
                    }
                } else {
                    Button {
                        onUnclaim()
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        let label = deal.redemptionProgressLabel ?? "Claimed"
                        ctaLabel(
                            text: "Claimed · \(label)",
                            textColor: cashbackGreen,
                            fill: .clear,
                            border: cashbackGreen
                        )
                    }
                }
            case .pendingReview:
                // Disabled while a review is open — claim/unclaim would
                // interfere with the in-flight admin decision.
                disabledCTA(text: "Pending review", textColor: warningOrange)
            case .earned:
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
            }
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
