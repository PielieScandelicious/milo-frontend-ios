//
//  ReferralRevealOverlay.swift
//  Scandalicious
//
//  Fullscreen overlay that reveals the referral bonus reward
//  with counting animation, confetti celebration, and smooth transitions.
//  Follows CashbackRevealOverlay's animation pattern exactly.
//

import SwiftUI

struct ReferralRevealOverlay: View {
    @Bindable var viewModel: HomeViewModel

    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var showContent = false
    @State private var showAmount = false
    @State private var showSpins = false
    @State private var canDismiss = false
    @State private var dismissed = false

    private let accentBlue = Color(red: 0.35, green: 0.65, blue: 1.0)
    private let blueGradient = [
        Color(red: 0.4, green: 0.7, blue: 1.0),
        Color(red: 0.2, green: 0.4, blue: 0.9)
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
            if viewModel.showReferralConfetti {
                ConfettiView()
            }

            // Card
            VStack(spacing: 24) {
                // Referral badge
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(accentBlue.opacity(0.15))
                            .frame(width: 52, height: 52)

                        Image(systemName: "person.2.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(accentBlue)
                    }

                    Text("Referral Bonus!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
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

                // Amount
                VStack(spacing: 4) {
                    Text("You earned")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .opacity(showAmount ? 1 : 0)

                    Text(String(format: "+\u{20AC}%.2f", viewModel.animatedReferralValue))
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(accentBlue)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.animatedReferralValue)
                        .opacity(showAmount ? 1 : 0)
                        .scaleEffect(showAmount ? 1 : 0.5)

                    Text("referral bonus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentBlue.opacity(0.6))
                        .opacity(showAmount ? 1 : 0)
                }

                // Spins section
                VStack(spacing: 14) {
                    // Divider
                    LinearGradient(
                        colors: [accentBlue.opacity(0), accentBlue.opacity(0.3), accentBlue.opacity(0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 0.5)

                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: blueGradient.map { $0.opacity(0.15) },
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 44, height: 44)

                            Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: blueGradient,
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }

                        Text("+\(viewModel.referralSpinsAwarded) spins")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundStyle(.white)

                        Text("Free Spins")
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(0.5)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: blueGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            )
                    }
                }
                .opacity(showSpins ? 1 : 0)
                .offset(y: showSpins ? 0 : 10)

                // Continue button
                Button {
                    dismissWithAnimation()
                } label: {
                    Text("Continue")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        colors: blueGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
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
                                    colors: [accentBlue.opacity(0.25), Color.white.opacity(0.05)],
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

        // Show referral info
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

        // Show spins
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                showSpins = true
            }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        // Confetti + enable dismiss
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            viewModel.showReferralConfetti = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.3)) {
                canDismiss = true
            }
        }
    }

    private func startCountingAnimation() {
        let target = viewModel.referralEurosAwarded
        let steps = 30
        let interval = 1.2 / Double(steps)

        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                let progress = Double(i) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.animatedReferralValue = target * eased
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
            viewModel.dismissReferralReveal()
        }
    }
}
