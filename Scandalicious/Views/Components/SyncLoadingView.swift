//
//  SyncLoadingView.swift
//  Scandalicious
//
//  Created by Claude on 24/01/2026.
//

import SwiftUI

struct SyncLoadingView: View {
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Background
            Color(white: 0.05)
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Animated sync icon
                ZStack {
                    // Outer pulsing ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.3), .blue.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                        .opacity(2 - pulseScale)

                    // Middle ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.purple.opacity(0.2), .blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 110, height: 110)

                    // Inner gradient circle
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .shadow(color: .purple.opacity(0.5), radius: 20, y: 5)

                    // Rotating sync arrows
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                }

                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }

    private func startAnimations() {
        // Rotating arrows animation
        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
            isAnimating = true
        }

        // Pulse animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
            pulseScale = 1.3
        }
    }
}

#Preview {
    SyncLoadingView()
}
