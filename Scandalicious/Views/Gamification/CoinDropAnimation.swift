//
//  CoinDropAnimation.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct CoinDropAnimation: View {
    let amount: Double
    var onComplete: (() -> Void)? = nil

    @State private var offsetY: CGFloat = -100
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.5
    @State private var bounceY: CGFloat = 0
    @State private var glowPulse = false

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)
    private let goldDark = Color(red: 0.80, green: 0.60, blue: 0.0)

    var body: some View {
        ZStack {
            // Glow behind coin
            Circle()
                .fill(gold.opacity(0.15))
                .frame(width: 100, height: 100)
                .blur(radius: 20)
                .scaleEffect(glowPulse ? 1.2 : 0.8)
                .opacity(opacity)

            // Shadow below
            Ellipse()
                .fill(Color.black.opacity(0.25))
                .frame(width: 50, height: 10)
                .blur(radius: 4)
                .offset(y: 48)
                .opacity(opacity)

            // Coin
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.95, blue: 0.6),
                                gold,
                                goldDark
                            ],
                            center: .init(x: 0.3, y: 0.3),
                            startRadius: 6,
                            endRadius: 44
                        )
                    )
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.5), goldDark.opacity(0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
                    .shadow(color: gold.opacity(0.5), radius: 16, y: 4)

                // Inner ring
                Circle()
                    .stroke(goldDark.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 66, height: 66)

                // Amount text
                VStack(spacing: 0) {
                    Text(String(format: "+€%.2f", amount))
                        .font(.system(size: amount >= 10 ? 14 : 16, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.35, green: 0.22, blue: 0.0))
                }
            }
            .scaleEffect(scale)
        }
        .offset(y: offsetY + bounceY)
        .opacity(opacity)
        .onAppear { startAnimation() }
    }

    private func startAnimation() {
        withAnimation(.easeIn(duration: 0.15)) { opacity = 1 }

        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) {
            offsetY = 0
            scale = 1.0
        }

        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.5)) {
            glowPulse = true
        }

        // Bounce
        withAnimation(.spring(response: 0.25, dampingFraction: 0.4).delay(0.45)) {
            bounceY = -10
        }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.7)) {
            bounceY = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onComplete?()
        }
    }
}
