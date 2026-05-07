//
//  CashbackEmptyStates.swift
//  Scandalicious
//
//  Empty state for the Cashback tab:
//    • CashbackEmptyNoMatch — filter active, 0 deals returned
//

import SwiftUI

// MARK: - No-match state

struct CashbackEmptyNoMatch: View {
    let categoryLabel: String
    var onShowAll: () -> Void = {}
    var onNotify: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // Tilted card-stack glyph
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CashbackTokens.text06)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CashbackTokens.cardStroke, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(-8))
                    .offset(x: -8)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(CashbackTokens.text06)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CashbackTokens.cardStroke, lineWidth: 1)
                    )
                    .rotationEffect(.degrees(6))
                    .offset(x: 8)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.08), .white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(CashbackTokens.cardStroke, lineWidth: 1)
                    )
                    .overlay(
                        Text("0")
                            .font(CashbackFont.serif(36))
                            .kerning(-1)
                            .foregroundStyle(CashbackTokens.text40)
                    )
            }
            .frame(width: 96, height: 96)
            .padding(.bottom, 22)

            Text("No \(categoryLabel.lowercased()) deals right now")
                .font(CashbackFont.serif(28))
                .kerning(-0.7)
                .foregroundStyle(.white)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Text("We refresh deals every Monday. Try another category, or get notified when \(categoryLabel.lowercased()) deals drop.")
                .font(CashbackFont.sans(13.5))
                .kerning(-0.1)
                .foregroundStyle(CashbackTokens.text55)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 290)
                .padding(.top, 10)

            HStack(spacing: 8) {
                Button(action: onShowAll) {
                    Text("Show all deals")
                        .font(CashbackFont.sans(13, weight: .medium))
                        .kerning(-0.1)
                        .foregroundStyle(Color(red: 0.043, green: 0.043, blue: 0.055))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(.plain)

                Button(action: onNotify) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Notify me")
                            .font(CashbackFont.sans(13, weight: .medium))
                            .kerning(-0.1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .overlay(Capsule().stroke(CashbackTokens.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 22)
        }
        .padding(.horizontal, 32)
        .padding(.top, 24)
        .frame(maxWidth: .infinity)
    }
}
