//
//  BrandCashbackView.swift
//  Scandalicious
//
//  Brand cashback feature views:
//  - BrandCashbackView      — scrollable deal list (available + my deals)
//  - CashbackDealCard       — individual deal card
//  - CashbackEarnedOverlay  — full-screen celebration when cashback is credited
//

import SwiftUI

// MARK: - Colour constant

private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
private let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)
private let shareBlue     = Color(red: 0.35, green: 0.65, blue: 1.0)

// MARK: - BrandCashbackView

struct BrandCashbackView: View {
    @ObservedObject var viewModel: BrandCashbackViewModel

    var body: some View {
        VStack(spacing: 20) {

            // Upload hint
            ShareExtensionHintCard()
                .padding(.horizontal, 16)

            // MY DEALS section
            if !viewModel.myDeals.isEmpty {
                VStack(spacing: 12) {
                    PromoSectionHeader(title: "MY DEALS", icon: "checkmark.seal.fill")
                        .padding(.horizontal, 4)

                    ForEach(Array(viewModel.myDeals.enumerated()), id: \.element.id) { index, deal in
                        CashbackDealCard(
                            deal: deal,
                            animationDelay: Double(index) * 0.05,
                            onClaim: { viewModel.claimDeal(deal) },
                            onUnclaim: { viewModel.unclaimDeal(deal) }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            // AVAILABLE DEALS section
            VStack(spacing: 12) {
                PromoSectionHeader(title: "AVAILABLE DEALS", icon: "tag.fill")
                    .padding(.horizontal, 4)

                if viewModel.availableDeals.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else {
                    ForEach(Array(viewModel.availableDeals.enumerated()), id: \.element.id) { index, deal in
                        CashbackDealCard(
                            deal: deal,
                            animationDelay: Double(index) * 0.06,
                            onClaim: { viewModel.claimDeal(deal) },
                            onUnclaim: { viewModel.unclaimDeal(deal) }
                        )
                    }
                }
            }
            .padding(.horizontal, 16)

            // Disclaimer
            Text("Deals are sponsored by brands. Cashback is credited to your Milo wallet after receipt verification.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.15))
            Text("No deals available right now")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text("Check back soon for new brand offers")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

// MARK: - CashbackDealCard

struct CashbackDealCard: View {
    let deal: BrandCashbackDeal
    let animationDelay: Double
    let onClaim: () -> Void
    let onUnclaim: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .leading) {
            // Claimed indicator bar
            if deal.status == .claimed {
                RoundedRectangle(cornerRadius: 3)
                    .fill(cashbackGreen)
                    .frame(width: 3)
                    .padding(.vertical, 12)
                    .padding(.leading, 0)
            }

            HStack(alignment: .top, spacing: 12) {
                // Brand icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 44, height: 44)
                    Image(systemName: deal.imageSystemName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconForegroundColor)
                }

                // Deal info
                VStack(alignment: .leading, spacing: 4) {
                    Text(deal.brandName.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(.white.opacity(0.45))

                    Text(deal.productName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    // Store pills
                    storePills

                    Text(deal.formattedExpiry)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.30))
                }

                Spacer(minLength: 8)

                // Right side: badge + action
                VStack(alignment: .trailing, spacing: 8) {
                    // Cashback amount badge
                    Text(deal.formattedCashback)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(badgeTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule().fill(badgeFillColor)
                        )

                    // Action button
                    actionButton
                }
                .padding(.leading, deal.status == .claimed ? 3 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.leading, deal.status == .claimed ? 6 : 0)
        }
        .glassCard(
            borderGradient: deal.status == .claimed
                ? LinearGradient(
                    colors: [cashbackGreen.opacity(0.35), cashbackGreen.opacity(0.10)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                : nil
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8).delay(animationDelay)) {
                appeared = true
            }
        }
    }

    // MARK: - Store Pills

    @ViewBuilder
    private var storePills: some View {
        if deal.requiresStore && !deal.eligibleStores.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(deal.eligibleStores, id: \.self) { storeName in
                        let storeColor = GroceryStore(rawValue: storeName)?.accentColor ?? .white.opacity(0.5)
                        Text(storeName)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(storeColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule().fill(storeColor.opacity(0.12))
                            )
                    }
                }
            }
            .frame(height: 22)
        } else {
            Text("All stores")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(cashbackGreen.opacity(0.8))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(Capsule().fill(cashbackGreen.opacity(0.12)))
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch deal.status {
        case .available:
            Button(action: onClaim) {
                Text("Claim")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(cashbackGreen))
            }
        case .claimed:
            Button(action: onUnclaim) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                    Text("Claimed")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(cashbackGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().stroke(cashbackGreen, lineWidth: 1.5))
            }
        case .pending:
            HStack(spacing: 4) {
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(cashbackGreen)
                Text("Pending")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(cashbackGreen.opacity(0.7))
            }
        case .earned:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11))
                Text("Earned")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(cashbackGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(cashbackGold.opacity(0.15)))
        case .expired:
            Text("Expired")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.3))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.white.opacity(0.06)))
        }
    }

    // MARK: - Helpers

    private var iconBackgroundColor: Color {
        switch deal.status {
        case .earned: return cashbackGold.opacity(0.15)
        default: return cashbackGreen.opacity(0.12)
        }
    }

    private var iconForegroundColor: Color {
        switch deal.status {
        case .earned: return cashbackGold
        default: return cashbackGreen
        }
    }

    private var badgeFillColor: Color {
        switch deal.status {
        case .earned: return cashbackGold.opacity(0.20)
        case .available: return cashbackGreen.opacity(0.20)
        default: return Color.white.opacity(0.08)
        }
    }

    private var badgeTextColor: Color {
        switch deal.status {
        case .earned: return cashbackGold
        case .available: return cashbackGreen
        default: return .white.opacity(0.5)
        }
    }
}

// MARK: - ShareExtensionHintCard

private struct ShareExtensionHintCard: View {
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Tappable header row
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(shareBlue)
                    Text("HOW TO UPLOAD")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(1.2)
                        .foregroundStyle(shareBlue)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(shareBlue.opacity(0.5))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(18)

            // Expandable content
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    // Step chips
                    HStack(spacing: 8) {
                        ForEach(["1 Claim deal", "2 Open receipt", "3 Share → Milo"], id: \.self) { step in
                            Text(step)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(shareBlue)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(shareBlue.opacity(0.12)))
                        }
                        Spacer()
                    }

                    // Body
                    Text("Upload receipts directly from your store app. Open your receipt, tap Share, and select Milo to submit.")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineSpacing(2)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
                .transition(.opacity)
            }
        }
        .clipped()
        .glassCard(
            borderGradient: LinearGradient(
                colors: [shareBlue.opacity(0.35), shareBlue.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isExpanded)
    }
}

// MARK: - CashbackEarnedOverlay

struct CashbackEarnedOverlay: View {
    let dealName: String
    let cashbackAmount: Double
    let onDismiss: () -> Void

    @State private var glowScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.1
    @State private var cardOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var ring2Scale: CGFloat = 0.3
    @State private var ring2Opacity: Double = 0
    @State private var ring3Scale: CGFloat = 0.2
    @State private var showParticles = false
    @State private var rotationAngle: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var showCheckmark = false

    private let formattedAmount: String = ""

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Particle burst
            if showParticles {
                CashbackParticleBurst(color: cashbackGreen)
            }

            VStack(spacing: 28) {
                // Icon with rings
                ZStack {
                    // Outer rings
                    Circle()
                        .stroke(cashbackGreen.opacity(0.08), lineWidth: 1)
                        .frame(width: 200, height: 200)
                        .scaleEffect(ring3Scale)
                        .opacity(ring2Opacity)

                    Circle()
                        .stroke(cashbackGreen.opacity(0.12), lineWidth: 1.5)
                        .frame(width: 160, height: 160)
                        .scaleEffect(ring2Scale)
                        .opacity(ring2Opacity)

                    Circle()
                        .stroke(cashbackGreen.opacity(0.22), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Radial glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [cashbackGreen.opacity(0.5), cashbackGreen.opacity(0.1), .clear],
                                center: .center, startRadius: 0, endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                        .blur(radius: 25)

                    // Rotating accent arc
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                colors: [cashbackGreen, cashbackGreen.opacity(0)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(rotationAngle))

                    // Icon circle
                    Circle()
                        .fill(cashbackGreen.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .overlay(Circle().stroke(cashbackGreen.opacity(0.35), lineWidth: 2))
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.2), .clear],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .offset(x: shimmerOffset)
                                .mask(Circle())
                        )

                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(cashbackGreen)
                        .shadow(color: cashbackGreen.opacity(0.7), radius: 16)
                        .shadow(color: cashbackGreen.opacity(0.3), radius: 30)

                    if showCheckmark {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(cashbackGold)
                            .background(Circle().fill(Color.black).frame(width: 20, height: 20))
                            .offset(x: 36, y: 36)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                // Text content
                VStack(spacing: 10) {
                    Text("CASHBACK EARNED")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(cashbackGreen)

                    Text(String(format: "€%.2f", cashbackAmount))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(cashbackGreen)
                        .contentTransition(.numericText())

                    Text(dealName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("Added to your Milo wallet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .opacity(textOpacity)

                Text("Tap anywhere to continue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .opacity(textOpacity)
            }
        }
        .onAppear { playEntrance() }
    }

    private func playEntrance() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Card slam-in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55, blendDuration: 0)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }

        // Glow bloom
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            glowScale = 1.2
            glowOpacity = 1.0
        }

        // Expanding rings
        withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.25)) {
            ring2Scale = 1.0
            ring2Opacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.35)) {
            ring3Scale = 1.0
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.8).delay(0.4)) {
            shimmerOffset = 200
        }

        // Particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showParticles = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // Rotating arc
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Pulsing glow
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.8)) {
            glowOpacity = 0.5
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }

        // Coin badge pop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                showCheckmark = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Auto-dismiss after 5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            onDismiss()
        }
    }
}

// MARK: - Cashback Particle Burst

private struct CashbackParticleBurst: View {
    let color: Color
    @State private var particles: [CashbackParticle] = []

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                CashbackParticlePiece(particle: p)
            }
        }
        .allowsHitTesting(false)
        .onAppear { generateParticles() }
    }

    private func generateParticles() {
        particles = (0..<40).map { _ in
            CashbackParticle(
                angle: Double.random(in: 0...(2 * .pi)),
                distance: CGFloat.random(in: 60...180),
                size: CGFloat.random(in: 3...8),
                color: [color, color.opacity(0.7), cashbackGold.opacity(0.8), .white.opacity(0.6)].randomElement()!,
                delay: Double.random(in: 0...0.15),
                duration: Double.random(in: 0.5...1.0),
                isCircle: Bool.random()
            )
        }
    }
}

private struct CashbackParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
    let duration: Double
    let isCircle: Bool
}

private struct CashbackParticlePiece: View {
    let particle: CashbackParticle
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1

    private var targetX: CGFloat { cos(particle.angle) * particle.distance }
    private var targetY: CGFloat { sin(particle.angle) * particle.distance }

    var body: some View {
        Group {
            if particle.isCircle {
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.5)
                    .rotationEffect(.degrees(particle.angle * 180 / .pi))
            }
        }
        .offset(x: targetX * offset, y: targetY * offset)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: particle.duration).delay(particle.delay)) {
                offset = 1
            }
            withAnimation(.easeIn(duration: particle.duration * 0.4).delay(particle.delay + particle.duration * 0.6)) {
                opacity = 0
                scale = 0.3
            }
        }
    }
}
