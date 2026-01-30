//
//  SyncLoadingView.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import SwiftUI

struct SyncLoadingView: View {
    // Milo brand colors
    private let miloPurple = Color(red: 0.45, green: 0.15, blue: 0.85)
    private let miloPurpleLight = Color(red: 0.55, green: 0.25, blue: 0.95)
    private let miloPurpleDark = Color(red: 0.35, green: 0.10, blue: 0.70)

    // Animation states
    @State private var viewAppeared = false
    @State private var contentOpacity: Double = 0
    @State private var glowOpacity: Double = 0
    @State private var ringRotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var innerPulse: CGFloat = 0.95

    var body: some View {
        ZStack {
            // Dark background
            Color(white: 0.05)
                .ignoresSafeArea()

            // Ambient glow effect
            RadialGradient(
                gradient: Gradient(colors: [
                    miloPurple.opacity(0.25),
                    miloPurple.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .ignoresSafeArea()
            .opacity(glowOpacity)

            // Centered animated logo
            ZStack {
                // Outer rotating ring
                Circle()
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                miloPurple.opacity(0.0),
                                miloPurple.opacity(0.5),
                                miloPurpleLight.opacity(0.8),
                                miloPurple.opacity(0.5),
                                miloPurple.opacity(0.0)
                            ]),
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 130, height: 130)
                    .rotationEffect(.degrees(ringRotation))

                // Pulsing outer glow ring
                Circle()
                    .stroke(miloPurple.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulseScale)
                    .opacity(Double(2 - pulseScale))

                // Inner gradient circle background
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [
                                miloPurpleLight.opacity(0.15),
                                miloPurple.opacity(0.08),
                                Color.clear
                            ]),
                            center: .center,
                            startRadius: 20,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)

                // Main icon circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [miloPurpleLight, miloPurple, miloPurpleDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                    .shadow(color: miloPurple.opacity(0.6), radius: 25, y: 8)
                    .scaleEffect(innerPulse)

                // Milo logo/icon
                Image(systemName: "sparkles")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(innerPulse)
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            guard !viewAppeared else { return }
            viewAppeared = true

            // Entrance fade animation
            withAnimation(.easeOut(duration: 0.5)) {
                glowOpacity = 1.0
                contentOpacity = 1.0
            }

            // Start continuous animations
            startAnimations()
        }
        .onDisappear {
            viewAppeared = false
            contentOpacity = 0
            glowOpacity = 0
            ringRotation = 0
            pulseScale = 1.0
            innerPulse = 0.95
        }
    }

    private func startAnimations() {
        // Ring rotation
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            ringRotation = 360
        }

        // Outer pulse
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
            pulseScale = 1.4
        }

        // Inner subtle pulse
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            innerPulse = 1.05
        }
    }
}

#Preview {
    SyncLoadingView()
}
