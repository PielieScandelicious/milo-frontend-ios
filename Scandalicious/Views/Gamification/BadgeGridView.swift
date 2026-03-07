//
//  BadgeGridView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct BadgeGridView: View {
    let badges: [Badge]
    @State private var selectedBadge: Badge? = nil
    @State private var showDetail = false
    @State private var isExpanded = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    private var displayBadges: [Badge] {
        isExpanded ? badges : Array(badges.prefix(Badge.gridDisplayCount))
    }

    private var hasMoreBadges: Bool {
        badges.count > Badge.gridDisplayCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(GamificationManager.shared.badgeTestMode ? .green : .white)
                    .onLongPressGesture {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        GamificationManager.shared.badgeTestMode.toggle()
                    }
                Spacer()
                let unlocked = badges.filter(\.isUnlocked).count
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6))
                    Text("\(unlocked)/\(badges.count)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // Progress bar
            GeometryReader { geo in
                let progress = badges.isEmpty ? 0 : Double(badges.filter(\.isUnlocked).count) / Double(badges.count)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(white: 0.15))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 1.0, green: 0.84, blue: 0.0), Color(red: 1.0, green: 0.6, blue: 0.0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progress, height: 4)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 4)

            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(displayBadges) { badge in
                    BadgeTile(badge: badge)
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedBadge = badge
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                showDetail = true
                            }
                        }
                }
            }

            // Expand / Collapse button
            if hasMoreBadges {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(isExpanded ? "Show Less" : "Show All \(badges.count) Badges")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .glassCard()
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            if showDetail, let badge = selectedBadge {
                BadgeDetailOverlay(badge: badge) {
                    withAnimation(.easeOut(duration: 0.25)) {
                        showDetail = false
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
    }
}

// MARK: - Badge Tile

private struct BadgeTile: View {
    let badge: Badge
    @State private var glowPulse = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Outer ring for unlocked badges
                if badge.isUnlocked {
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [badge.iconColor.color, badge.iconColor.color.opacity(0.3), badge.iconColor.color],
                                center: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(glowPulse ? 360 : 0))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: glowPulse)
                }

                Circle()
                    .fill(badge.isUnlocked
                          ? badge.iconColor.color.opacity(0.15)
                          : Color(white: 0.08))
                    .frame(width: 52, height: 52)

                // Shimmer overlay for unlocked
                if badge.isUnlocked {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.15), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .opacity(glowPulse ? 0.6 : 0)
                        .animation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true), value: glowPulse)
                }

                // Lock icon for locked badges
                if !badge.isUnlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(white: 0.3))
                        .offset(x: 18, y: -18)
                }

                Image(systemName: badge.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(badge.isUnlocked ? badge.iconColor.color : Color(white: 0.2))
                    .shadow(color: badge.isUnlocked ? badge.iconColor.color.opacity(0.5) : .clear, radius: 6)
            }

            Text(badge.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badge.isUnlocked ? .white : .white.opacity(0.2))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Progress indicator for locked badges with progress
            if !badge.isUnlocked, let progress = badge.progress, progress > 0 {
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(white: 0.15))
                        .frame(width: 40, height: 3)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(badge.iconColor.color.opacity(0.5))
                        .frame(width: 40 * progress, height: 3)
                }
            }
        }
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .grayscale(badge.isUnlocked ? 0 : 0.9)
        .onAppear {
            glowPulse = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double.random(in: 0...0.3))) {
                appeared = true
            }
        }
    }
}

// MARK: - Badge Detail Overlay

private struct BadgeDetailOverlay: View {
    let badge: Badge
    let onDismiss: () -> Void
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                ZStack {
                    // Glow rings
                    if badge.isUnlocked {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(badge.iconColor.color.opacity(0.1 - Double(i) * 0.03), lineWidth: 1)
                                .frame(width: CGFloat(80 + i * 20), height: CGFloat(80 + i * 20))
                        }
                    }

                    Circle()
                        .fill(badge.isUnlocked
                              ? badge.iconColor.color.opacity(0.15)
                              : Color(white: 0.1))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Circle()
                                .stroke(badge.isUnlocked ? badge.iconColor.color.opacity(0.3) : Color(white: 0.15), lineWidth: 1.5)
                        )

                    Image(systemName: badge.icon)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(badge.isUnlocked ? badge.iconColor.color : Color(white: 0.3))
                        .shadow(color: badge.isUnlocked ? badge.iconColor.color.opacity(0.5) : .clear, radius: 8)
                }

                VStack(spacing: 6) {
                    Text(badge.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text(badge.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }

                if badge.isUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.green)
                        Text("Unlocked")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                } else {
                    if let label = badge.progressLabel {
                        Text(label)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(badge.iconColor.color.opacity(0.7))
                    }

                    if let progress = badge.progress, progress > 0 {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(white: 0.15))
                                .frame(width: 120, height: 6)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(badge.iconColor.color.opacity(0.6))
                                .frame(width: 120 * progress, height: 6)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("Locked")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(.white.opacity(0.3))
                    }
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(white: 0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                badge.isUnlocked
                                    ? badge.iconColor.color.opacity(0.2)
                                    : Color(white: 0.1),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: badge.isUnlocked ? badge.iconColor.color.opacity(0.15) : .clear, radius: 30)
            )
            .scaleEffect(appeared ? 1 : 0.8)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}
