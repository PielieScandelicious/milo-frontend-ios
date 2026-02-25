//
//  TierProgressView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct TierProgressView: View {
    let tierProgress: TierProgress

    var body: some View {
        VStack(spacing: 18) {
            // Progress section: current tier + progress bar + next tier
            VStack(spacing: 12) {
                // Current tier highlight
                HStack(spacing: 10) {
                    // Current tier icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: tierProgress.currentTier.gradientColors,
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .shadow(color: (tierProgress.currentTier.gradientColors.first ?? .white).opacity(0.4), radius: 8)

                        Image(systemName: tierProgress.currentTier.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tierProgress.currentTier.rawValue)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                        Text("\(tierProgress.receiptsThisMonth) receipts this month")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    if let next = tierProgress.currentTier.next {
                        Text("\(tierProgress.receiptsNeededForNextTier) to \(next.rawValue)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(Color(white: 0.12))
                            )
                    }
                }

                // Progress bar with tier markers
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    ZStack(alignment: .leading) {
                        // Track
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(white: 0.12))
                            .frame(height: 5)

                        // Fill
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: tierProgress.currentTier.gradientColors,
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .frame(width: totalWidth * overallProgress, height: 5)
                            .shadow(color: (tierProgress.currentTier.gradientColors.first ?? .white).opacity(0.5), radius: 4, y: 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: overallProgress)

                        // Tier marker dots
                        ForEach(UserTier.allCases, id: \.self) { tier in
                            let pos = markerPosition(for: tier)
                            Circle()
                                .fill(
                                    tier.minReceipts <= tierProgress.receiptsThisMonth
                                        ? (tier.gradientColors.first ?? .white)
                                        : Color(white: 0.2)
                                )
                                .frame(width: 9, height: 9)
                                .overlay(
                                    Circle()
                                        .stroke(Color(white: 0.05), lineWidth: 1.5)
                                )
                                .position(x: totalWidth * pos, y: 2.5)
                        }
                    }
                }
                .frame(height: 9)
            }

            // Tier cards row
            HStack(spacing: 8) {
                ForEach(UserTier.allCases, id: \.self) { tier in
                    let isActive = tierProgress.currentTier == tier
                    let isReached = tier.minReceipts <= tierProgress.receiptsThisMonth

                    VStack(spacing: 8) {
                        // Icon
                        Image(systemName: tier.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(
                                isReached
                                    ? LinearGradient(colors: tier.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                                    : LinearGradient(colors: [Color(white: 0.25)], startPoint: .top, endPoint: .bottom)
                            )

                        // Name
                        Text(tier.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isActive ? .white : (isReached ? .white.opacity(0.6) : .white.opacity(0.25)))

                        // Bonus
                        Text(tier.bonusLabel)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundStyle(isReached ? .white : .white.opacity(0.25))

                        // Perk summary
                        Text("\(tier.spinsPerReceipt) spin\(tier.spinsPerReceipt > 1 ? "s" : "")")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(isReached ? .white.opacity(0.45) : .white.opacity(0.15))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isActive ? Color(white: 0.1) : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isActive
                                    ? (tier.gradientColors.first ?? .white).opacity(0.35)
                                    : Color.clear,
                                lineWidth: 1
                            )
                    )
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    // MARK: - Helpers

    private var overallProgress: Double {
        let allTiers = UserTier.allCases
        guard let lastTier = allTiers.last else { return 1.0 }
        let maxReceipts = Double(lastTier.minReceipts)
        guard maxReceipts > 0 else { return 1.0 }
        return min(1.0, Double(tierProgress.receiptsThisMonth) / maxReceipts)
    }

    private func markerPosition(for tier: UserTier) -> Double {
        guard let lastTier = UserTier.allCases.last else { return 0 }
        let maxReceipts = Double(lastTier.minReceipts)
        guard maxReceipts > 0 else { return 0 }
        return Double(tier.minReceipts) / maxReceipts
    }
}
