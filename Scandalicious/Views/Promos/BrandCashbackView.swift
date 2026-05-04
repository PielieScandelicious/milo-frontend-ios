//
//  BrandCashbackView.swift
//  Scandalicious
//
//  Brand cashback feature views:
//  - BrandCashbackView      — feed (filter bar + rails + grid)
//  - CashbackEarnedOverlay  — full-screen celebration when cashback is credited
//
//  The grid card itself lives in Components/BrandCashbackGridCard.swift.
//

import SwiftUI

// MARK: - Colour constant

private let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
private let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)
private let shareBlue     = Color(red: 0.35, green: 0.65, blue: 1.0)

// MARK: - BrandCashbackView

struct BrandCashbackView: View {
    @ObservedObject var viewModel: BrandCashbackViewModel
    var onViewReceipt: ((String) -> Void)? = nil

    @State private var selectedDeal: BrandCashbackDeal? = nil
    @State private var selectedCategory: CashbackCategory = .all
    @State private var showOnboarding: Bool = BrandCashbackOnboardingCard.shouldShow

    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 20) {

            // Wallet entry card — sits above onboarding to anchor the tab on the
            // user's collected cashback balance.
            BrandCashbackWalletEntryCard()
                .padding(.horizontal, 16)

            // Onboarding / share-extension hint
            if showOnboarding {
                BrandCashbackOnboardingCard(onDismiss: { showOnboarding = false })
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            } else {
                ShareExtensionHintCard()
                    .padding(.horizontal, 16)
            }

            // Category filter
            CashbackCategoryFilterBar(
                selected: $selectedCategory,
                availableCategories: availableCategories
            )

            // MY DEALS rail (horizontal scroll)
            if !filteredMyDeals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    PromoSectionHeader(title: "MY DEALS", icon: "checkmark.seal.fill")
                        .padding(.horizontal, 20)
                    horizontalRail(deals: filteredMyDeals)
                }
            }

            // FEATURED rail (horizontal scroll)
            if !featuredDeals.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    PromoSectionHeader(title: "FEATURED", icon: "star.fill")
                        .padding(.horizontal, 20)
                    horizontalRail(deals: featuredDeals)
                }
            }

            // AVAILABLE grid (2-col)
            VStack(alignment: .leading, spacing: 10) {
                PromoSectionHeader(title: availableHeaderTitle, icon: "tag.fill")
                    .padding(.horizontal, 20)

                if regularAvailable.isEmpty && filteredMyDeals.isEmpty && featuredDeals.isEmpty {
                    emptyState
                        .transition(.opacity)
                } else if !regularAvailable.isEmpty {
                    LazyVGrid(columns: gridColumns, spacing: 12) {
                        ForEach(regularAvailable) { deal in
                            BrandCashbackGridCard(deal: deal, onTap: { selectedDeal = deal })
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            // Disclaimer
            Text("Deals are sponsored by brands. Cashback is credited to your Milo wallet after receipt verification.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.3))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
        .sheet(item: $selectedDeal) { deal in
            BrandCashbackDealDetailSheet(
                deal: deal,
                onClaim: {
                    viewModel.claimDeal(deal)
                    selectedDeal = nil
                },
                onUnclaim: {
                    viewModel.unclaimDeal(deal)
                    selectedDeal = nil
                },
                onViewReceipt: onViewReceipt
            )
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.deniedToast {
                CashbackDeniedToast(toast: toast) {
                    withAnimation { viewModel.deniedToast = nil }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(toast.id)
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(5))
                    withAnimation { viewModel.deniedToast = nil }
                }
            }
        }
    }

    // MARK: - Derived collections

    private var availableCategories: Set<CashbackCategory> {
        Set((viewModel.availableDeals + viewModel.myDeals).compactMap {
            $0.category.flatMap(CashbackCategory.init(rawValue:))
        })
    }

    private func matchesCategory(_ deal: BrandCashbackDeal) -> Bool {
        if selectedCategory == .all { return true }
        return deal.category == selectedCategory.rawValue
    }

    private var filteredMyDeals: [BrandCashbackDeal] {
        viewModel.myDeals.filter(matchesCategory)
    }

    private var featuredDeals: [BrandCashbackDeal] {
        viewModel.availableDeals.filter { $0.featured && matchesCategory($0) }
    }

    private var regularAvailable: [BrandCashbackDeal] {
        viewModel.availableDeals.filter { !$0.featured && matchesCategory($0) }
    }

    private var availableHeaderTitle: String {
        selectedCategory == .all
            ? "AVAILABLE"
            : selectedCategory.label.uppercased()
    }

    // MARK: - Rail

    private func horizontalRail(deals: [BrandCashbackDeal]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(deals) { deal in
                    BrandCashbackGridCard(deal: deal, onTap: { selectedDeal = deal })
                        .frame(width: 220)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tag.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.15))
            Text(selectedCategory == .all
                ? "No deals available right now"
                : "No \(selectedCategory.label.lowercased()) deals right now")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
            Text(selectedCategory == .all
                ? "Check back soon for new brand offers"
                : "Try a different category")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.25))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 16)
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

// MARK: - CashbackDeniedToast

/// Transient denial banner shown when a previously-pending review flips to
/// denied. Visual language is shared with `DealStatusBanner.full` so the
/// toast and the persistent surface on the deal sheet feel like one system.
/// Tappable to dismiss; auto-dismisses via the .task on the parent overlay.
struct CashbackDeniedToast: View {
    let toast: DeniedToast
    let onDismiss: () -> Void

    var body: some View {
        DealStatusBanner(
            kind: .denied(reason: "\(toast.brandName) — \(toast.reason)"),
            size: .full,
            onDismiss: onDismiss
        )
    }
}


// MARK: - CashbackEarnedOverlay

struct CashbackEarnedOverlay: View {
    let dealName: String
    let cashbackAmount: Double
    let imageUrl: URL?
    let matchedReceiptId: String?
    let onDismiss: () -> Void
    let onViewReceipt: ((String) -> Void)?

    init(
        dealName: String,
        cashbackAmount: Double,
        imageUrl: URL? = nil,
        matchedReceiptId: String? = nil,
        onDismiss: @escaping () -> Void,
        onViewReceipt: ((String) -> Void)? = nil
    ) {
        self.dealName = dealName
        self.cashbackAmount = cashbackAmount
        self.imageUrl = imageUrl
        self.matchedReceiptId = matchedReceiptId
        self.onDismiss = onDismiss
        self.onViewReceipt = onViewReceipt
    }

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

                    // Product image circle (or SF Symbol fallback)
                    ZStack {
                        Circle()
                            .fill(cashbackGreen.opacity(0.12))
                            .frame(width: 100, height: 100)
                            .overlay(Circle().stroke(cashbackGreen.opacity(0.35), lineWidth: 2))

                        Group {
                            if let url = imageUrl {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 44, weight: .bold))
                                            .foregroundStyle(cashbackGreen)
                                    }
                                }
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                                    .font(.system(size: 44, weight: .bold))
                                    .foregroundStyle(cashbackGreen)
                            }
                        }
                        .frame(width: 92, height: 92)
                        .clipShape(Circle())

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .white.opacity(0.2), .clear],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .offset(x: shimmerOffset)
                            .frame(width: 100, height: 100)
                            .mask(Circle())
                    }
                    .shadow(color: cashbackGreen.opacity(0.5), radius: 16)
                    .shadow(color: cashbackGreen.opacity(0.25), radius: 30)

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

                if let receiptId = matchedReceiptId, let onViewReceipt {
                    Button {
                        onViewReceipt(receiptId)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "receipt.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("View receipt")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(cashbackGreen)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Capsule().stroke(cashbackGreen.opacity(0.5), lineWidth: 1.2))
                    }
                    .opacity(textOpacity)
                }

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
