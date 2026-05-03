//
//  CashbackChip.swift
//  Scandalicious
//
//  Reusable cashback amount pill (e.g. "€1.50 back").
//  Used on grid cards (overlaid on the photo) and in the detail sheet hero.
//

import SwiftUI

struct CashbackChip: View {
    let amount: Double
    var size: Size = .medium
    var emphasis: Emphasis = .filled

    enum Size { case small, medium, large }
    enum Emphasis { case filled, outlined, muted }

    private static let cashbackGreen = Color(red: 0.25, green: 0.90, blue: 0.55)
    private static let cashbackGold  = Color(red: 1.00, green: 0.80, blue: 0.20)

    var body: some View {
        HStack(spacing: 4) {
            Text(String(format: "€%.2f", amount))
                .monospacedDigit()
            Text("back")
                .font(.system(size: subFontSize, weight: .semibold))
                .opacity(0.7)
        }
        .font(.system(size: amountFontSize, weight: .heavy, design: .rounded))
        .foregroundStyle(foreground)
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(background)
        .overlay(border)
        .shadow(color: shadowColor, radius: shadowRadius, y: 2)
    }

    private var amountFontSize: CGFloat {
        switch size { case .small: 13; case .medium: 16; case .large: 22 }
    }
    private var subFontSize: CGFloat {
        switch size { case .small: 9; case .medium: 11; case .large: 14 }
    }
    private var hPadding: CGFloat {
        switch size { case .small: 8; case .medium: 10; case .large: 14 }
    }
    private var vPadding: CGFloat {
        switch size { case .small: 4; case .medium: 6; case .large: 9 }
    }
    private var foreground: Color {
        switch emphasis {
        case .filled: return .black
        case .outlined: return Self.cashbackGreen
        case .muted: return .white.opacity(0.55)
        }
    }
    @ViewBuilder
    private var background: some View {
        switch emphasis {
        case .filled:
            Capsule().fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.35, green: 0.95, blue: 0.62),
                        Color(red: 0.20, green: 0.85, blue: 0.50),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .outlined:
            Capsule().fill(Self.cashbackGreen.opacity(0.10))
        case .muted:
            Capsule().fill(Color.white.opacity(0.06))
        }
    }
    @ViewBuilder
    private var border: some View {
        switch emphasis {
        case .outlined:
            Capsule().stroke(Self.cashbackGreen.opacity(0.45), lineWidth: 1)
        default:
            EmptyView()
        }
    }
    private var shadowColor: Color {
        emphasis == .filled ? Self.cashbackGreen.opacity(0.35) : .clear
    }
    private var shadowRadius: CGFloat {
        emphasis == .filled ? 6 : 0
    }
}
