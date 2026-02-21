//
//  BadgeUnlockView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct BadgeUnlockView: View {
    let badge: Badge
    let onDismiss: () -> Void

    @State private var glowScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0
    @State private var badgeScale: CGFloat = 0.3
    @State private var badgeOpacity: Double = 0
    @State private var textOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                // Glow + badge
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [badge.iconColor.color.opacity(0.5), Color.clear],
                                center: .center, startRadius: 0, endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 160)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                        .blur(radius: 20)

                    Circle()
                        .fill(badge.iconColor.color.opacity(0.15))
                        .frame(width: 100, height: 100)
                        .overlay(Circle().stroke(badge.iconColor.color.opacity(0.3), lineWidth: 2))

                    Image(systemName: badge.icon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(badge.iconColor.color)
                        .shadow(color: badge.iconColor.color.opacity(0.6), radius: 12)
                }
                .scaleEffect(badgeScale)
                .opacity(badgeOpacity)

                VStack(spacing: 8) {
                    Text("Badge Unlocked!")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(badge.iconColor.color)
                    Text(badge.name)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text(badge.description)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .opacity(textOpacity)

                Text("Tap to dismiss")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .opacity(textOpacity)
            }
        }
        .onAppear {
            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                badgeScale = 1.0
                badgeOpacity = 1.0
                glowScale = 1.0
                glowOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                textOpacity = 1.0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.6)) {
                glowOpacity = 0.4
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onDismiss()
            }
        }
    }
}
