//
//  CashbackRevealOverlay.swift
//  Scandalicious
//
//  Fullscreen overlay that reveals Milo Points earned from a processed receipt.
//  Shows animated points count-up, breakdown (tier/Grote Kar/kickstart), and spin type pill.
//

import SwiftUI

struct CashbackRevealOverlay: View {
    @Bindable var viewModel: HomeViewModel

    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var showContent = false
    @State private var showBreakdown = false
    @State private var showPoints = false
    @State private var showSpinPill = false
    @State private var canDismiss = false
    @State private var dismissed = false
    @State private var displayedPoints: Int = 0

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldGradient = [Color(red: 1.0, green: 0.88, blue: 0.35),
                                Color(red: 0.80, green: 0.60, blue: 0.0)]
    private let teal = Color(red: 0.2, green: 0.85, blue: 0.7)

    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .opacity(backgroundOpacity)
                .onTapGesture { guard canDismiss else { return }; dismissWithAnimation() }

            // Confetti
            if viewModel.showConfetti { ConfettiView() }

            // Card
            VStack(spacing: 20) {
                // Store / kickstart badge
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(viewModel.processingStoreColor.opacity(0.15))
                            .frame(width: 52, height: 52)
                        Image(systemName: viewModel.isKickstart ? "gift.fill" : "storefront.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(viewModel.isKickstart ? gold : viewModel.processingStoreColor)
                    }
                    Text(viewModel.processingStoreName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                    Text(String(format: "€%.2f kassaticket", viewModel.processingAmount))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 8)

                dividerLine.opacity(showContent ? 1 : 0)

                // Points total (animated count-up)
                VStack(spacing: 4) {
                    Text(viewModel.isStreakSaver ? "Streak Saver 🔥" : "Je verdiende")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .opacity(showPoints ? 1 : 0)

                    Text("+\(displayedPoints) pts")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(gold)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedPoints)
                        .opacity(showPoints ? 1 : 0)
                        .scaleEffect(showPoints ? 1 : 0.5)

                    Text(String(format: "= €%.2f", Double(viewModel.pointsTotal) / 1000.0))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(gold.opacity(0.5))
                        .opacity(showPoints ? 1 : 0)
                }

                // Points breakdown rows
                if showBreakdown && hasBreakdown {
                    VStack(spacing: 0) {
                        dividerLine

                        VStack(alignment: .leading, spacing: 8) {
                            if viewModel.kickstartBonusPoints > 0 {
                                breakdownRow(icon: "gift.fill", color: gold,
                                             label: "Kickstart bonus",
                                             points: viewModel.kickstartBonusPoints)
                            }
                            if viewModel.fixedPoints > 0 {
                                let tier = GamificationManager.shared.tierLevel
                                let label = tier == .silver ? "Zilver tier bonus" : "Goud tier bonus"
                                breakdownRow(icon: "medal.fill",
                                             color: tier.gradientColors.first ?? .white,
                                             label: label,
                                             points: viewModel.fixedPoints)
                            }
                            if viewModel.groteKarPoints > 0 {
                                breakdownRow(icon: "cart.fill", color: teal,
                                             label: "Grote Kar bonus",
                                             points: viewModel.groteKarPoints)
                            }
                        }
                        .padding(.top, 12)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Spin type pill
                if let spinType = viewModel.spinType {
                    spinPill(for: spinType)
                        .opacity(showSpinPill ? 1 : 0)
                        .offset(y: showSpinPill ? 0 : 10)
                }

                // Continue button
                Button { dismissWithAnimation() } label: {
                    Text("Doorgaan")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 12).fill(gold))
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
                                    startPoint: .topLeading, endPoint: .bottomTrailing
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

    // MARK: - Helpers

    private var hasBreakdown: Bool {
        viewModel.fixedPoints > 0 || viewModel.groteKarPoints > 0 || viewModel.kickstartBonusPoints > 0
    }

    private var dividerLine: some View {
        LinearGradient(
            colors: [.white.opacity(0), .white.opacity(0.2), .white.opacity(0)],
            startPoint: .leading, endPoint: .trailing
        )
        .frame(height: 0.5)
    }

    private func breakdownRow(icon: String, color: Color, label: String, points: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text("+\(points) pts")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func spinPill(for spinType: SpinWheelType) -> some View {
        let isPremium = spinType == .premium
        let pillColors: [Color] = isPremium
            ? [Color(red: 1.0, green: 0.7, blue: 0.1), Color(red: 0.85, green: 0.45, blue: 0.0)]
            : [Color(red: 0.3, green: 0.75, blue: 1.0), Color(red: 0.1, green: 0.55, blue: 0.9)]

        return HStack(spacing: 8) {
            Image(systemName: isPremium ? "crown.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
            Text(spinType.displayName)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundStyle(.white)
            Text("verdiend!")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(LinearGradient(colors: pillColors, startPoint: .leading, endPoint: .trailing))
                .shadow(color: pillColors.first!.opacity(0.4), radius: 10, y: 3)
        )
    }

    // MARK: - Animations

    private func playEntrance() {
        withAnimation(.easeOut(duration: 0.3)) { backgroundOpacity = 1 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
            cardScale = 1.0; cardOpacity = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showContent = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPoints = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            startPointsCountAnimation()
        }

        if hasBreakdown {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showBreakdown = true }
            }
        }

        let spinDelay: Double = hasBreakdown ? 2.8 : 2.2
        if viewModel.spinType != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + spinDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showSpinPill = true }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + spinDelay + 0.9) {
            viewModel.showConfetti = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.easeOut(duration: 0.3)) { canDismiss = true }
        }
    }

    private func startPointsCountAnimation() {
        let target = viewModel.pointsTotal
        guard target > 0 else { displayedPoints = 0; return }
        let steps = 30
        let interval = 1.2 / Double(steps)
        for i in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * interval) {
                let eased = 1 - pow(1 - Double(i) / Double(steps), 3)
                displayedPoints = Int(Double(target) * eased)
            }
        }
    }

    private func dismissWithAnimation() {
        guard !dismissed else { return }
        dismissed = true
        withAnimation(.easeIn(duration: 0.25)) {
            cardOpacity = 0; cardScale = 0.9; backgroundOpacity = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { viewModel.dismissReward() }
    }
}
