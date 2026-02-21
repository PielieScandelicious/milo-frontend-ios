//
//  RewardCelebrationView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct RewardCelebrationView: View {
    let event: RewardEvent
    let onDismiss: () -> Void

    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var showContent = false
    @State private var bonusFlipped = false
    @State private var showConfetti = false
    @State private var canDismiss = false
    @State private var dismissed = false
    @State private var animatedBalance: Double = 0

    @ObservedObject private var gm = GamificationManager.shared
    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
                .onTapGesture {
                    guard canDismiss else { return }
                    dismissWithAnimation()
                }

            if showConfetti {
                ConfettiView()
            }

            // Fixed-size card
            VStack(spacing: 20) {
                // Title
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(gold)

                    Text("Receipt Reward")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Reward items
                VStack(spacing: 10) {
                    // Cash earned
                    rewardRow(
                        icon: "plus.circle.fill",
                        iconColor: gold,
                        title: String(format: "+€%.2f", event.coinsAwarded),
                        subtitle: "Added to wallet"
                    )

                    // Spins earned
                    rewardRow(
                        icon: "arrow.trianglehead.2.clockwise.rotate.90",
                        iconColor: Color(red: 0.6, green: 0.9, blue: 1.0),
                        title: "\(event.spinsAwarded) spin\(event.spinsAwarded == 1 ? "" : "s") earned",
                        subtitle: "\(gm.tierProgress.currentTier.rawValue) tier perk"
                    )
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Wallet balance
                HStack(spacing: 6) {
                    Image(systemName: "wallet.bifold.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(gold)
                    Text("Balance:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(String(format: "€%.2f", animatedBalance))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(gold)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animatedBalance)
                }
                .opacity(showContent ? 1 : 0)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Mystery bonus
                MysteryBonusCard(bonus: event.mysteryBonus, isFlipped: $bonusFlipped) {
                    if case .nothing = event.mysteryBonus { } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showConfetti = true
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        withAnimation(.easeOut(duration: 0.3)) { canDismiss = true }
                    }
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Continue button
                if canDismiss {
                    Button {
                        dismissWithAnimation()
                    } label: {
                        Text("Continue")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(gold)
                            )
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(24)
            .frame(width: UIScreen.main.bounds.width - 48)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(Color(white: 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(
                                LinearGradient(
                                    colors: [gold.opacity(0.25), Color.white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            )
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear { playEntrance() }
    }

    // MARK: - Reward Row

    private func rewardRow(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.12))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
        )
    }

    // MARK: - Animations

    private func playEntrance() {
        withAnimation(.easeOut(duration: 0.3)) { backgroundOpacity = 1 }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
            animateBalanceCounter()
        }
    }

    private func animateBalanceCounter() {
        let target = gm.wallet.euros
        let start = target - event.coinsAwarded
        animatedBalance = max(0, start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                animatedBalance = target
            }
        }
    }

    private func dismissWithAnimation() {
        guard !dismissed else { return }
        dismissed = true
        withAnimation(.easeIn(duration: 0.25)) {
            cardOpacity = 0
            cardScale = 0.9
            backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Mystery Bonus Card

private struct MysteryBonusCard: View {
    let bonus: MysteryBonusType
    @Binding var isFlipped: Bool
    var onReveal: (() -> Void)?

    @State private var tapPulse = false

    var body: some View {
        ZStack {
            mysteryBackFace
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? 90 : 0), axis: (x: 0, y: 1, z: 0))

            bonusFrontFace
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -90), axis: (x: 0, y: 1, z: 0))
        }
        .onTapGesture {
            guard !isFlipped else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isFlipped = true
            }
            onReveal?()
        }
    }

    private var mysteryBackFace: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.12))
                    .frame(width: 38, height: 38)
                    .scaleEffect(tapPulse ? 1.12 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: tapPulse)

                Image(systemName: "gift.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Mystery Bonus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text("Tap to reveal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }

            Spacer()

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.2))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.15), lineWidth: 1)
                )
        )
        .onAppear { tapPulse = true }
    }

    private var bonusFrontFace: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(bonusIconBackground)
                    .frame(width: 38, height: 38)
                Image(systemName: bonusIconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(bonusIconColor)
            }

            bonusText
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(bonusBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(bonusBorderColor.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var bonusIconName: String {
        switch bonus {
        case .cashBonus: return "plus.circle.fill"
        case .spinToken: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .nothing:   return "minus"
        }
    }

    private var bonusIconColor: Color {
        switch bonus {
        case .cashBonus: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .spinToken: return Color(red: 0.6, green: 0.9, blue: 1.0)
        case .nothing:   return .white.opacity(0.3)
        }
    }

    private var bonusIconBackground: Color {
        switch bonus {
        case .cashBonus: return Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.12)
        case .spinToken: return Color(red: 0.6, green: 0.9, blue: 1.0).opacity(0.12)
        case .nothing:   return Color(white: 0.1)
        }
    }

    @ViewBuilder
    private var bonusText: some View {
        switch bonus {
        case .cashBonus(let amount):
            VStack(alignment: .leading, spacing: 1) {
                Text("Cash Bonus!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0))
                Text(String(format: "+€%.2f added", amount))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .spinToken:
            VStack(alignment: .leading, spacing: 1) {
                Text("Free Spin!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.6, green: 0.9, blue: 1.0))
                Text("Extra spin added")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        case .nothing:
            VStack(alignment: .leading, spacing: 1) {
                Text("No bonus this time")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Keep scanning!")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var bonusBackground: Color {
        switch bonus {
        case .cashBonus: return Color(red: 0.12, green: 0.10, blue: 0.03)
        case .spinToken: return Color(red: 0.04, green: 0.08, blue: 0.12)
        case .nothing:   return Color(white: 0.07)
        }
    }

    private var bonusBorderColor: Color {
        switch bonus {
        case .cashBonus: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .spinToken: return Color(red: 0.6, green: 0.9, blue: 1.0)
        case .nothing:   return Color.white.opacity(0.08)
        }
    }
}
