//
//  BadgeGridView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct BadgeGridView: View {
    let badges: [Badge]
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Achievements")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                let unlocked = badges.filter(\.isUnlocked).count
                Text("\(unlocked)/\(badges.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(badges) { badge in
                    BadgeTile(badge: badge)
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Badge Tile

private struct BadgeTile: View {
    let badge: Badge
    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(badge.isUnlocked
                          ? badge.iconColor.color.opacity(0.15)
                          : Color(white: 0.1))
                    .frame(width: 52, height: 52)

                if badge.isUnlocked {
                    Circle()
                        .stroke(badge.iconColor.color.opacity(glowPulse ? 0.6 : 0.2), lineWidth: 1.5)
                        .frame(width: 52, height: 52)
                        .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: glowPulse)
                        .onAppear { glowPulse = true }
                }

                Image(systemName: badge.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(badge.isUnlocked ? badge.iconColor.color : Color(white: 0.25))
                    .shadow(color: badge.isUnlocked ? badge.iconColor.color.opacity(0.4) : .clear, radius: 4)
            }

            Text(badge.name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(badge.isUnlocked ? .white : .white.opacity(0.25))
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .grayscale(badge.isUnlocked ? 0 : 0.9)
    }
}
