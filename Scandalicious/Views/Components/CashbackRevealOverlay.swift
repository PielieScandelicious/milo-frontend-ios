//
//  CashbackRevealOverlay.swift
//  Scandalicious
//
//  Fullscreen reward overlay shown after a receipt is processed.
//

import SwiftUI

struct CashbackRevealOverlay: View {
    @Bindable var viewModel: HomeViewModel

    @State private var backgroundOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.7
    @State private var cardOpacity: Double = 0
    @State private var showContent = false
    @State private var showDetails = false
    @State private var showPoints = false
    @State private var showSpinPill = false
    @State private var canDismiss = false
    @State private var dismissed = false
    @State private var displayedPoints: Int = 0

    private let champagne = Color(red: 0.94, green: 0.90, blue: 0.83)
    private let champagneDeep = Color(red: 0.70, green: 0.62, blue: 0.52)
    private let slate = Color(red: 0.40, green: 0.45, blue: 0.54)
    private let teal = Color(red: 0.28, green: 0.71, blue: 0.64)
    private let orange = Color(red: 0.82, green: 0.54, blue: 0.30)

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
            VStack(spacing: 18) {
                headerRow
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 8)

                pointsHeroCard
                    .opacity(showPoints ? 1 : 0)
                    .scaleEffect(showPoints ? 1 : 0.96)

                if showDetails {
                    rewardDetailsSection
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
                        .foregroundStyle(Color(red: 0.15, green: 0.15, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(primaryButtonBackground)
                }
                .opacity(canDismiss ? 1 : 0)
                .allowsHitTesting(canDismiss)
            }
            .padding(24)
            .frame(width: min(UIScreen.main.bounds.width - 32, 410))
            .background(cardBackground)
            .scaleEffect(cardScale)
            .opacity(cardOpacity)
        }
        .onAppear { playEntrance() }
    }

    // MARK: - Helpers

    private var rewardSource: RewardSource {
        if viewModel.isKickstart { return .kickstart }
        if viewModel.isStreakSaver { return .streakSaver }
        return .tier(viewModel.displayTierLevel)
    }

    private var rewardAccent: Color {
        rewardSource.colors.first ?? champagneDeep
    }

    private var pointsGradient: LinearGradient {
        LinearGradient(
            colors: [champagne, champagneDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var headerRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(viewModel.processingStoreColor.opacity(0.15))
                    .frame(width: 52, height: 52)

                Image(systemName: viewModel.isKickstart ? "gift.fill" : "storefront.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(viewModel.isKickstart ? rewardAccent : viewModel.processingStoreColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.processingStoreName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)

                Text(String(format: "Bon van €%.2f", viewModel.processingAmount))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }

            Spacer(minLength: 10)

            sourceBadge
        }
    }

    private var sourceBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: rewardSource.badgeIcon)
                .font(.system(size: 10, weight: .bold))
            Text(rewardSource.badgeTitle)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: rewardSource.colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: rewardAccent.opacity(0.35), radius: 12, y: 4)
        )
    }

    private var pointsHeroCard: some View {
        VStack(spacing: 10) {
            Text("Je beloning")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white.opacity(0.92))

            Text("+\(displayedPoints) pts")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundStyle(pointsGradient)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: displayedPoints)

            Text(rewardSource.supportingText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))

            Text(String(format: "= €%.2f", Double(viewModel.pointsTotal) / 1000.0))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(champagne.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .background(panelBackground(accent: rewardAccent, cornerRadius: 22))
    }

    private var rewardDetailsSection: some View {
        LazyVGrid(columns: summaryColumns, spacing: 10) {
            ForEach(detailItems) { item in
                summaryTile(item)
            }
        }
    }

    private var summaryColumns: [GridItem] {
        let count = max(1, min(detailItems.count, 2))
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: count)
    }

    private func summaryTile(_ item: RewardSummaryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            HStack(spacing: 5) {
                Image(systemName: item.icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(item.accent)
                Text(item.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }

    private var tierFixedPoints: Int {
        guard viewModel.displayTierLevel == .silver else { return 0 }
        return min(viewModel.fixedPoints, 75)
    }

    private var inferredExtraFixedPoints: Int {
        guard !viewModel.isKickstart && !viewModel.isStreakSaver else { return 0 }
        return max(0, viewModel.fixedPoints - tierFixedPoints)
    }

    private var detailItems: [RewardSummaryItem] {
        var items: [RewardSummaryItem] = []

        if viewModel.kickstartBonusPoints > 0 {
            items.append(
                RewardSummaryItem(
                    label: "Kickstart bonus",
                    value: "+\(viewModel.kickstartBonusPoints) pts",
                    icon: "gift.fill",
                    accent: rewardAccent
                )
            )
        } else if viewModel.isStreakSaver {
            items.append(
                RewardSummaryItem(
                    label: "Streak Saver",
                    value: "+\(viewModel.fixedPoints) pts",
                    icon: "sparkles",
                    accent: rewardAccent
                )
            )
        }

        if viewModel.groteKarPoints > 0 {
            items.append(
                RewardSummaryItem(
                    label: "Grote Kar",
                    value: "+\(viewModel.groteKarPoints) pts",
                    icon: "cart.fill",
                    accent: teal
                )
            )
        }

        if inferredExtraFixedPoints > 0 {
            items.append(
                RewardSummaryItem(
                    label: "Extra bonus",
                    value: "+\(inferredExtraFixedPoints) pts",
                    icon: "sparkles",
                    accent: orange
                )
            )
        }

        return items
    }

    private var hasDetailItems: Bool {
        !detailItems.isEmpty
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.10, blue: 0.14),
                            Color(red: 0.05, green: 0.05, blue: 0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [rewardAccent.opacity(0.22), .clear],
                        center: .topTrailing,
                        startRadius: 10,
                        endRadius: 220
                    )
                )

            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [rewardAccent.opacity(0.28), Color.white.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.52), radius: 30, y: 12)
    }

    private func panelBackground(accent: Color, cornerRadius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.045))

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.16), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [accent.opacity(0.28), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    private var primaryButtonBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.88, green: 0.84, blue: 0.78),
                        Color(red: 0.68, green: 0.62, blue: 0.56)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: champagneDeep.opacity(0.20), radius: 16, y: 8)
    }

    private func spinPill(for spinType: SpinWheelType) -> some View {
        let isPremium = spinType == .premium
        let pillColors: [Color] = isPremium
            ? [Color(red: 0.62, green: 0.54, blue: 0.43), Color(red: 0.35, green: 0.30, blue: 0.24)]
            : [slate, Color(red: 0.21, green: 0.24, blue: 0.30)]
        let iconColor = isPremium ? champagne : Color.white.opacity(0.9)

        return HStack(spacing: 8) {
            Image(systemName: isPremium ? "crown.fill" : "arrow.trianglehead.2.clockwise.rotate.90")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(iconColor)
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
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
                .shadow(color: pillColors.last!.opacity(0.28), radius: 10, y: 4)
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

        if hasDetailItems {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) { showDetails = true }
            }
        }

        let spinDelay: Double = hasDetailItems ? 2.45 : 1.95
        if viewModel.spinType != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + spinDelay) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { showSpinPill = true }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }

        let completionDelay = viewModel.spinType == nil ? 2.55 : spinDelay + 0.85
        DispatchQueue.main.asyncAfter(deadline: .now() + completionDelay) {
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

private extension CashbackRevealOverlay {
    enum RewardSource: Equatable {
        case tier(TierLevel)
        case kickstart
        case streakSaver

        var badgeTitle: String {
            switch self {
            case .tier(let tier): return "\(tier.displayName) level"
            case .kickstart: return "Kickstart"
            case .streakSaver: return "Streak Saver"
            }
        }

        var badgeIcon: String {
            switch self {
            case .tier(let tier): return tier.icon
            case .kickstart: return "gift.fill"
            case .streakSaver: return "shield.fill"
            }
        }

        var supportingText: String {
            switch self {
            case .tier(let tier): return "Gebaseerd op je \(tier.displayName)-level"
            case .kickstart: return "Extra punten met je Kickstart"
            case .streakSaver: return "Je streak blijft actief"
            }
        }

        var colors: [Color] {
            switch self {
            case .tier(let tier):
                return tier.gradientColors
            case .kickstart:
                return [
                    Color(red: 0.40, green: 0.72, blue: 1.0),
                    Color(red: 0.20, green: 0.42, blue: 0.92)
                ]
            case .streakSaver:
                return [
                    Color(red: 0.10, green: 0.84, blue: 0.74),
                    Color(red: 0.05, green: 0.56, blue: 0.54)
                ]
            }
        }
    }

    struct RewardSummaryItem: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let icon: String
        let accent: Color
    }
}
