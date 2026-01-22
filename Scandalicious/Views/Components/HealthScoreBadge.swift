//
//  HealthScoreBadge.swift
//  Scandalicious
//
//  Created by Claude on 21/01/2026.
//

import SwiftUI

// MARK: - Health Score Badge Size

enum HealthScoreBadgeSize {
    case small      // 20x20 - for transaction rows
    case medium     // 32x32 - for receipt items
    case large      // 48x48 - for headers
    case extraLarge // 60x60 - for dashboard cards

    var dimension: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 32
        case .large: return 48
        case .extraLarge: return 60
        }
    }

    var fontSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 14
        case .large: return 20
        case .extraLarge: return 26
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 14
        case .large: return 20
        case .extraLarge: return 26
        }
    }
}

// MARK: - Health Score Badge

struct HealthScoreBadge: View {
    let score: Int?
    var size: HealthScoreBadgeSize = .medium
    var showLabel: Bool = false
    var style: HealthScoreBadgeStyle = .filled

    var body: some View {
        HStack(spacing: size == .small ? 4 : 6) {
            badgeCircle

            if showLabel {
                Text(score.healthScoreLabel)
                    .font(.system(size: labelFontSize, weight: .medium))
                    .foregroundColor(score.healthScoreColor)
            }
        }
    }

    private var badgeCircle: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: size.dimension, height: size.dimension)

            if let score = score {
                Text("\(score)")
                    .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
            } else {
                // Non-food: show dash or icon
                Image(systemName: "minus")
                    .font(.system(size: size.iconSize * 0.8, weight: .bold))
                    .foregroundColor(textColor)
            }
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .filled:
            return score.healthScoreColor
        case .outlined:
            return score.healthScoreColor.opacity(0.15)
        case .subtle:
            return score.healthScoreColor.opacity(0.2)
        }
    }

    private var textColor: Color {
        switch style {
        case .filled:
            return .white
        case .outlined, .subtle:
            return score.healthScoreColor
        }
    }

    private var labelFontSize: CGFloat {
        switch size {
        case .small: return 11
        case .medium: return 13
        case .large: return 15
        case .extraLarge: return 17
        }
    }
}

// MARK: - Badge Style

enum HealthScoreBadgeStyle {
    case filled     // Solid background with white text
    case outlined   // Light background with colored text
    case subtle     // Lighter background, good for dark mode
}

// MARK: - Health Score Badge with Icon

struct HealthScoreBadgeWithIcon: View {
    let score: Int?
    var size: HealthScoreBadgeSize = .medium

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: score.healthScoreIcon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundColor(score.healthScoreColor)

            if let score = score {
                Text("\(score)")
                    .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(score.healthScoreColor)
            } else {
                Text("-")
                    .font(.system(size: size.fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(score.healthScoreColor.opacity(0.15))
        )
    }
}

// MARK: - Compact Health Score Indicator

/// A minimal health score indicator for tight spaces (just a colored dot)
struct HealthScoreIndicator: View {
    let score: Int?
    var diameter: CGFloat = 8

    var body: some View {
        Circle()
            .fill(score.healthScoreColor)
            .frame(width: diameter, height: diameter)
    }
}

// MARK: - Health Score Stars

/// Display health score as stars (5-star rating)
struct HealthScoreStars: View {
    let score: Int?
    var size: CGFloat = 12
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: starImageName(for: index))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(starColor(for: index))
            }
        }
    }

    private func starImageName(for index: Int) -> String {
        guard let score = score else {
            return "star"
        }
        return index <= score ? "star.fill" : "star"
    }

    private func starColor(for index: Int) -> Color {
        guard let score = score else {
            return Color(white: 0.3)
        }
        return index <= score ? score.healthScoreColor : Color(white: 0.3)
    }
}

// MARK: - Health Score Hearts

/// Display health score as hearts (alternative to stars)
struct HealthScoreHearts: View {
    let score: Int?
    var size: CGFloat = 12
    var spacing: CGFloat = 2

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: heartImageName(for: index))
                    .font(.system(size: size, weight: .semibold))
                    .foregroundColor(heartColor(for: index))
            }
        }
    }

    private func heartImageName(for index: Int) -> String {
        guard let score = score else {
            return "heart"
        }
        return index <= score ? "heart.fill" : "heart"
    }

    private func heartColor(for index: Int) -> Color {
        guard let score = score else {
            return Color(white: 0.3)
        }
        return index <= score ? score.healthScoreColor : Color(white: 0.3)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 24) {
            // Badge sizes
            Text("Badge Sizes")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 16) {
                HealthScoreBadge(score: 5, size: .small)
                HealthScoreBadge(score: 4, size: .medium)
                HealthScoreBadge(score: 3, size: .large)
                HealthScoreBadge(score: 2, size: .extraLarge)
            }

            // All scores
            Text("All Scores")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                ForEach(0...5, id: \.self) { score in
                    HealthScoreBadge(score: score, size: .medium)
                }
                HealthScoreBadge(score: nil, size: .medium)
            }

            // With labels
            Text("With Labels")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                HealthScoreBadge(score: 5, size: .medium, showLabel: true)
                HealthScoreBadge(score: 3, size: .medium, showLabel: true)
                HealthScoreBadge(score: 1, size: .medium, showLabel: true)
                HealthScoreBadge(score: nil, size: .medium, showLabel: true)
            }

            // Styles
            Text("Styles")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 16) {
                HealthScoreBadge(score: 4, size: .large, style: .filled)
                HealthScoreBadge(score: 4, size: .large, style: .outlined)
                HealthScoreBadge(score: 4, size: .large, style: .subtle)
            }

            // Stars & Hearts
            Text("Stars & Hearts")
                .font(.headline)
                .foregroundColor(.white)

            VStack(spacing: 8) {
                HealthScoreStars(score: 4, size: 16)
                HealthScoreHearts(score: 3, size: 16)
                HealthScoreStars(score: nil, size: 16)
            }

            // Badge with icon
            Text("Badge with Icon")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 12) {
                HealthScoreBadgeWithIcon(score: 5)
                HealthScoreBadgeWithIcon(score: 2)
                HealthScoreBadgeWithIcon(score: nil)
            }
        }
        .padding()
    }
}
