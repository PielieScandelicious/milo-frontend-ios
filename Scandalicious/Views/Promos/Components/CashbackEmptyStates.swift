//
//  CashbackEmptyStates.swift
//  Scandalicious
//
//  Two empty states for the redesigned Cashback tab:
//    • CashbackEmptyNewUser   — €0 wallet + how-it-works onboarding
//    • CashbackEmptyNoMatch   — filter active, 0 deals returned
//

import SwiftUI

// MARK: - New user (€0) state

struct CashbackEmptyNewUser: View {
    /// Total deals available (shown in the "Pick your first deal" CTA copy).
    var totalDeals: Int = 0
    /// First available deal — teases the scrollable feed below the CTA.
    var teaserDeal: BrandCashbackDeal? = nil
    var onPickFirstDeal: () -> Void = {}
    var onTeaserTap: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            WalletEmptyHeroCard()
                .padding(.horizontal, 16)

            // How it works
            VStack(alignment: .leading, spacing: 0) {
                Text("HOW IT WORKS")
                    .font(CashbackFont.sans(10.5, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(CashbackTokens.text55)
                    .padding(.bottom, 18)

                Step(n: "01",
                     title: "Claim a deal",
                     copy: "Tap a deal below to add it to your list. No coupon codes, no signup.",
                     divider: false)
                Step(n: "02",
                     title: "Buy & scan",
                     copy: "Buy the product at any store, then scan your receipt in the app.",
                     divider: true)
                Step(n: "03",
                     title: "Get paid",
                     copy: "Cashback hits your wallet. Withdraw to your bank when you reach €10.",
                     divider: true)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            // CTA card
            ctaCard
                .padding(.horizontal, 16)
                .padding(.top, 24)

            // Tease the deal feed
            if let deal = teaserDeal {
                VStack(alignment: .leading, spacing: 12) {
                    PromoSectionHeader(title: "ALL DEALS", icon: "tag.fill")
                        .padding(.horizontal, 20)

                    ZStack(alignment: .bottom) {
                        DealRow(deal: deal, onTap: onTeaserTap)
                            .opacity(0.6)
                            .padding(.horizontal, 16)

                        // 60pt gradient fade to background — pulls the eye downward
                        LinearGradient(
                            colors: [.clear, CashbackTokens.bg],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 60)
                        .allowsHitTesting(false)
                    }
                }
                .padding(.top, 32)
            }
        }
    }

    private var ctaCard: some View {
        Button(action: onPickFirstDeal) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick your first deal")
                        .font(CashbackFont.serif(22))
                        .kerning(-0.5)
                        .foregroundStyle(.white)
                        .lineSpacing(1)
                        .multilineTextAlignment(.leading)
                    Text(totalDeals > 0
                         ? "\(totalDeals) deals available right now"
                         : "Browse the full list of brand deals")
                        .font(CashbackFont.sans(12))
                        .foregroundStyle(CashbackTokens.text70)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                HStack(spacing: 4) {
                    Text("Browse")
                        .font(CashbackFont.sans(13, weight: .semibold))
                        .kerning(-0.1)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(CashbackTokens.greenInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(CashbackTokens.green))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [
                        CashbackTokens.green.opacity(0.18),
                        CashbackTokens.green.opacity(0.06),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(CashbackTokens.greenDim, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Numbered step row

private struct Step: View {
    let n: String
    let title: String
    let copy: String
    let divider: Bool

    var body: some View {
        VStack(spacing: 0) {
            if divider {
                Rectangle()
                    .fill(CashbackTokens.cardStroke)
                    .frame(height: 1)
            }
            HStack(alignment: .top, spacing: 14) {
                Text(n)
                    .font(CashbackFont.serif(22))
                    .monospacedDigit()
                    .kerning(-0.4)
                    .foregroundStyle(CashbackTokens.green)
                    .frame(minWidth: 28, alignment: .leading)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(CashbackFont.serif(19))
                        .kerning(-0.4)
                        .foregroundStyle(.white)
                        .lineSpacing(1)
                    Text(copy)
                        .font(CashbackFont.sans(12.5))
                        .kerning(-0.05)
                        .foregroundStyle(CashbackTokens.text55)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 14)
        }
    }
}

// MARK: - No-match state

struct CashbackEmptyNoMatch: View {
    let categoryLabel: String
    var onShowAll: () -> Void = {}
    var onNotify: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Tilted card-stack glyph
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CashbackTokens.text06)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CashbackTokens.cardStroke, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(-8))
                    .offset(x: -8)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CashbackTokens.text06)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CashbackTokens.cardStroke, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(6))
                    .offset(x: 8)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.08), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CashbackTokens.cardStroke, lineWidth: 1)
                    )
                    .overlay(
                        Text("0")
                            .font(CashbackFont.serif(36))
                            .kerning(-1)
                            .foregroundStyle(CashbackTokens.text40)
                    )
            }
            .frame(width: 96, height: 96)
            .padding(.bottom, 22)

            Text("No \(categoryLabel.lowercased()) deals right now")
                .font(CashbackFont.serif(28))
                .kerning(-0.7)
                .foregroundStyle(.white)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Text("We refresh deals every Monday. Try another category, or get notified when \(categoryLabel.lowercased()) deals drop.")
                .font(CashbackFont.sans(13.5))
                .kerning(-0.1)
                .foregroundStyle(CashbackTokens.text55)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
                .padding(.top, 10)

            HStack(spacing: 8) {
                Button(action: onShowAll) {
                    Text("Show all deals")
                        .font(CashbackFont.sans(13, weight: .medium))
                        .kerning(-0.1)
                        .foregroundStyle(Color(red: 0.043, green: 0.043, blue: 0.055))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)

                Button(action: onNotify) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Notify me")
                            .font(CashbackFont.sans(13, weight: .medium))
                            .kerning(-0.1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(CashbackTokens.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }
}
