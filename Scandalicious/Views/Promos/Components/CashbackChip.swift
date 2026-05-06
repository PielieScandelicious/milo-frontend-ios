//
//  CashbackChip.swift
//  Scandalicious
//
//  The single "loud green" element on the Cashback tab. Reproduces the chip
//  spec from the Variation A handoff: gradient capsule, mono digits, inset
//  highlight, soft green drop shadow.
//

import SwiftUI

struct CashbackChip: View {
    let amount: Double
    var size: Size = .medium
    var emphasis: Emphasis = .filled

    enum Size { case small, medium, large }
    enum Emphasis { case filled, outlined, muted }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 3) {
            Text(String(format: "€%.2f", amount))
                .font(CashbackFont.mono(amountFontSize, weight: .semibold))
                .monospacedDigit()
                .kerning(-0.2)
            Text("back")
                .font(CashbackFont.sans(subFontSize, weight: .semibold))
                .opacity(0.6)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(background)
        .overlay(border)
        .overlay(insetHighlight)
        .shadow(color: shadowColor, radius: shadowRadius, y: 4)
    }

    // MARK: Sizing

    private var amountFontSize: CGFloat {
        switch size { case .small: 12; case .medium: 14; case .large: 20 }
    }
    private var subFontSize: CGFloat {
        switch size { case .small: 9; case .medium: 10; case .large: 12 }
    }
    private var hPadding: CGFloat {
        switch size { case .small: 9; case .medium: 11; case .large: 15 }
    }
    private var vPadding: CGFloat {
        switch size { case .small: 4; case .medium: 5; case .large: 9 }
    }

    // MARK: Style

    private var foreground: Color {
        switch emphasis {
        case .filled:   return CashbackTokens.greenInk
        case .outlined: return CashbackTokens.green
        case .muted:    return .white.opacity(0.55)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch emphasis {
        case .filled:
            Capsule().fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.365, green: 0.937, blue: 0.627), // #5DEFA0
                        Color(red: 0.180, green: 0.761, blue: 0.451), // #2EC273
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .outlined:
            Capsule().fill(CashbackTokens.green.opacity(0.10))
        case .muted:
            Capsule().fill(Color.white.opacity(0.06))
        }
    }

    @ViewBuilder
    private var border: some View {
        if emphasis == .outlined {
            Capsule().stroke(CashbackTokens.green.opacity(0.45), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var insetHighlight: some View {
        if emphasis == .filled {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)
        }
    }

    private var shadowColor: Color {
        emphasis == .filled ? CashbackTokens.green.opacity(0.28) : .clear
    }
    private var shadowRadius: CGFloat {
        emphasis == .filled ? 14 : 0
    }
}
