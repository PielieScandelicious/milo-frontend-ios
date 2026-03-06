//
//  CashbackRevealOverlay.swift
//  Scandalicious
//
//  Fullscreen overlay that reveals the cashback earned from a processed receipt
//  with counting animation, confetti celebration, and smooth transitions.
//  Shows Gold Tier spins when awarded.
//

import SwiftUI

struct CashbackRevealOverlay: View {
    @Bindable var viewModel: HomeViewModel

    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var showContent = false
    @State private var showAmount = false
    @State private var showSpins = false
    @State private var canDismiss = false
    @State private var dismissed = false

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldGradient = [
        Color(red: 1.0, green: 0.88, blue: 0.35),
        Color(red: 0.80, green: 0.60, blue: 0.0)
    ]

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
                .onTapGesture {
                    guard canDismiss else { return }
                    dismissWithAnimation()
                }

            // Confetti
            if viewModel.showConfetti {
                ConfettiView()
            }

            // Card
            VStack(spacing: 24) {
                // Store badge
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(viewModel.processingStoreColor.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: "storefront.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(viewModel.processingStoreColor)
                    }

                    Text(viewModel.processingStoreName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)

                    Text(String(format: "€%.2f receipt", viewModel.processingAmount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                // Divider
                LinearGradient(
                    colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 0.5)
                .opacity(showContent ? 1 : 0)

                // Cashback amount
                VStack(spacing: 4) {
                    Text("You earned")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .opacity(showAmount ? 1 : 0)

                    Text(String(format: "+€%.2f", viewModel.animatedCashbackValue))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(gold)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.animatedCashbackValue)
                        .opacity(showAmount ? 1 : 0)
                        .scaleEffect(showAmount ? 1 : 0.5)

                    Text("cashback")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(gold.opacity(0.6))
                        .opacity(showAmount ? 1 : 0)
                }

                // Gold Tier spins section
                if viewModel.spinsAwarded > 0 {
                    VStack(spacing: 14) {
                        // Thin divider
                        LinearGradient(
                            colors: [gold.opacity(0), gold.opacity(0.3), gold.opacity(0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 0.5)

                        VStack(spacing: 8) {
                            // Spin icon
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: goldGradient.map { $0.opacity(0.15) },
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 44, height: 44)

                                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: goldGradient,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            }

                            Text("+\(viewModel.spinsAwarded) spin\(viewModel.spinsAwarded > 1 ? "s" : "")")
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(.white)

                            // Gold Tier tag
                            Text("Gold Tier")
                                .font(.system(size: 10, weight: .heavy))
                                .tracking(0.5)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(
                                        LinearGradient(
                                            colors: goldGradient,
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                )
                        }
                    }
                    .opacity(showSpins ? 1 : 0)
                    .offset(y: showSpins ? 0 : 10)
                }

                // Continue button
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
                .opacity(canDismiss ? 1 : 0)
                .allowsHitTesting(canDismiss)
            }
            .padding(28)
            .frame(width: UIScreen.main.bounds.width - 56)
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

    // MARK: - Animations

    private func playEntrance() {
        // Backdrop fade in
        withAnimation(.easeOut(duration: 0.3)) {
            backgroundOpacity = 1
        }

        // Card scale in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }

        // Show store info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showContent = true
            }
        }

        // Show amount and start counting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showAmount = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            startCountingAnimation()
        }

        // Show spins (after cashback counting finishes)
        if viewModel.spinsAwarded > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                    showSpins = true
                }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        // Confetti + enable dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            viewModel.showConfetti = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.3)) {
                canDismiss = true
            }
        }
    }

    private func startCountingAnimation() {
        let target = viewModel.cashbackAmount
        let steps = 30
        let interval = 1.2 / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                let progress = Double(i) / Double(steps)
                // Ease-out curve
                let eased = 1 - pow(1 - progress, 3)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.animatedCashbackValue = target * eased
                }
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
            viewModel.dismissReward()
        }
    }
}
