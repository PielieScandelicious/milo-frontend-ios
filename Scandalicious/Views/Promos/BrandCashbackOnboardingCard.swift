//
//  BrandCashbackOnboardingCard.swift
//  Scandalicious
//
//  First-time explainer shown above the deal list on the Cashback tab.
//  Teaches the Claim → Shop → Share-receipt flow. Dismissable.
//

import SwiftUI

private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
private let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)
private let shareBlue     = Color(red: 0.35, green: 0.65, blue: 1.0)

private let onboardingSeenKey = "brandCashback.onboardingSeen"

// MARK: - Onboarding Card

struct BrandCashbackOnboardingCard: View {
    let onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            VStack(spacing: 12) {
                stepRow(
                    number: 1,
                    icon: "tag.fill",
                    iconColor: cashbackGreen,
                    title: "Claim a deal",
                    subtitle: "Tap \"Claim\" on any offer below"
                )
                stepRow(
                    number: 2,
                    icon: "cart.fill",
                    iconColor: cashbackGold,
                    title: "Buy the product",
                    subtitle: "Within 14 days, at any eligible store"
                )
                stepRow(
                    number: 3,
                    icon: "square.and.arrow.up.fill",
                    iconColor: shareBlue,
                    title: "Share your receipt",
                    subtitle: "Open it in your store app → Share → Milo"
                )
            }

            Button {
                UserDefaults.standard.set(true, forKey: onboardingSeenKey)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    onDismiss()
                }
            } label: {
                Text("Got it")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(cashbackGreen))
            }
            .padding(.top, 4)
        }
        .padding(20)
        .glassCard(
            borderGradient: LinearGradient(
                colors: [cashbackGreen.opacity(0.35), cashbackGreen.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(cashbackGold)
                Text("WELCOME")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(cashbackGold)
                Spacer()
            }
            Text("Earn real cash with Milo")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
            Text("Brands pay you when you buy their products. Three steps:")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.60))
                .padding(.top, 2)
        }
    }

    private func stepRow(number: Int, icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(number)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(.black)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(Color.white.opacity(0.9)))
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Helper

extension BrandCashbackOnboardingCard {
    /// True when the user hasn't seen and dismissed the onboarding yet.
    static var shouldShow: Bool {
        !UserDefaults.standard.bool(forKey: onboardingSeenKey)
    }
}
