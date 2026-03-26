//
//  ReferralRevealOverlay.swift
//  Scandalicious
//
//  App-wide referral bonus overlay. Matches CashbackEarnedOverlay style.
//  Auto-triggers when a referral reward is earned via GamificationManager.
//

import SwiftUI

struct ReferralRevealOverlay: View {
    let cashbackAmount: Double
    let onDismiss: () -> Void

    @State private var glowScale: CGFloat = 0.3
    @State private var glowOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.1
    @State private var cardOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var ringScale: CGFloat = 0.5
    @State private var ringOpacity: Double = 0
    @State private var ring2Scale: CGFloat = 0.3
    @State private var ring2Opacity: Double = 0
    @State private var ring3Scale: CGFloat = 0.2
    @State private var showParticles = false
    @State private var rotationAngle: Double = 0
    @State private var shimmerOffset: CGFloat = -200
    @State private var showCoinBadge = false
    @State private var dismissed = false

    private let accentBlue = Color(red: 0.35, green: 0.65, blue: 1.0)
    private let accentBlueDark = Color(red: 0.2, green: 0.45, blue: 0.9)

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            // Particle burst
            if showParticles {
                ReferralParticleBurst(color: accentBlue)
            }

            VStack(spacing: 28) {
                // Icon with rings
                ZStack {
                    // Outer rings
                    Circle()
                        .stroke(accentBlue.opacity(0.08), lineWidth: 1)
                        .frame(width: 200, height: 200)
                        .scaleEffect(ring3Scale)
                        .opacity(ring2Opacity)

                    Circle()
                        .stroke(accentBlue.opacity(0.12), lineWidth: 1.5)
                        .frame(width: 160, height: 160)
                        .scaleEffect(ring2Scale)
                        .opacity(ring2Opacity)

                    Circle()
                        .stroke(accentBlue.opacity(0.22), lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    // Radial glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [accentBlue.opacity(0.5), accentBlue.opacity(0.1), .clear],
                                center: .center, startRadius: 0, endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(glowScale)
                        .opacity(glowOpacity)
                        .blur(radius: 25)

                    // Rotating accent arc
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(
                            LinearGradient(
                                colors: [accentBlue, accentBlue.opacity(0)],
                                startPoint: .leading, endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 110, height: 110)
                        .rotationEffect(.degrees(rotationAngle))

                    // Icon circle with shimmer
                    Circle()
                        .fill(accentBlue.opacity(0.12))
                        .frame(width: 100, height: 100)
                        .overlay(Circle().stroke(accentBlue.opacity(0.35), lineWidth: 2))
                        .overlay(
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.2), .clear],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .offset(x: shimmerOffset)
                                .mask(Circle())
                        )

                    Image(systemName: "person.2.fill")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(accentBlue)
                        .shadow(color: accentBlue.opacity(0.7), radius: 16)
                        .shadow(color: accentBlue.opacity(0.3), radius: 30)

                    if showCoinBadge {
                        Image(systemName: "eurosign.circle.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(Color(red: 1.0, green: 0.80, blue: 0.20))
                            .background(Circle().fill(Color.black).frame(width: 20, height: 20))
                            .offset(x: 36, y: 36)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                // Text content
                VStack(spacing: 10) {
                    Text("REFERRAL BONUS")
                        .font(.system(size: 12, weight: .heavy))
                        .tracking(2)
                        .foregroundStyle(accentBlue)

                    Text(String(format: "€%.2f", cashbackAmount))
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .foregroundStyle(accentBlue)
                        .contentTransition(.numericText())
    

                    Text("Your friend earned their first cashback deal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Text("Added to your Milo wallet")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .opacity(textOpacity)

                Text("Tap anywhere to continue")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
                    .opacity(textOpacity)
            }
        }
        .onAppear { playEntrance() }
    }

    // MARK: - Animations

    private func playEntrance() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // Card slam-in
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55, blendDuration: 0)) {
            cardScale = 1.0
            cardOpacity = 1.0
        }

        // Glow bloom
        withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
            glowScale = 1.2
            glowOpacity = 1.0
        }

        // Expanding rings
        withAnimation(.easeOut(duration: 0.7).delay(0.15)) {
            ringScale = 1.0
            ringOpacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.8).delay(0.25)) {
            ring2Scale = 1.0
            ring2Opacity = 1.0
        }
        withAnimation(.easeOut(duration: 0.9).delay(0.35)) {
            ring3Scale = 1.0
        }

        // Shimmer sweep
        withAnimation(.easeInOut(duration: 0.8).delay(0.4)) {
            shimmerOffset = 200
        }

        // Particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showParticles = true
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }

        // Rotating arc
        withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }

        // Pulsing glow
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(0.8)) {
            glowOpacity = 0.5
        }

        // Text fade in
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            textOpacity = 1.0
        }

        // Coin badge pop
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                showCoinBadge = true
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        // Auto-dismiss after 5s
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            guard !dismissed else { return }
            dismissed = true
            onDismiss()
        }
    }
}

// MARK: - Referral Particle Burst

private struct ReferralParticleBurst: View {
    let color: Color
    @State private var particles: [ReferralParticle] = []

    private let gold = Color(red: 1.0, green: 0.80, blue: 0.20)

    var body: some View {
        ZStack {
            ForEach(particles) { p in
                ReferralParticlePiece(particle: p)
            }
        }
        .allowsHitTesting(false)
        .onAppear { generateParticles() }
    }

    private func generateParticles() {
        particles = (0..<40).map { _ in
            ReferralParticle(
                angle: Double.random(in: 0...(2 * .pi)),
                distance: CGFloat.random(in: 60...180),
                size: CGFloat.random(in: 3...8),
                color: [color, color.opacity(0.7), gold.opacity(0.8), .white.opacity(0.6)].randomElement()!,
                delay: Double.random(in: 0...0.15),
                duration: Double.random(in: 0.5...1.0),
                isCircle: Bool.random()
            )
        }
    }
}

private struct ReferralParticle: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let size: CGFloat
    let color: Color
    let delay: Double
    let duration: Double
    let isCircle: Bool
}

private struct ReferralParticlePiece: View {
    let particle: ReferralParticle
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1
    @State private var scale: CGFloat = 1

    private var targetX: CGFloat { cos(particle.angle) * particle.distance }
    private var targetY: CGFloat { sin(particle.angle) * particle.distance }

    var body: some View {
        Group {
            if particle.isCircle {
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
            } else {
                RoundedRectangle(cornerRadius: 1)
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size * 0.5)
                    .rotationEffect(.degrees(particle.angle * 180 / .pi))
            }
        }
        .offset(x: targetX * offset, y: targetY * offset)
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeOut(duration: particle.duration).delay(particle.delay)) {
                offset = 1
            }
            withAnimation(.easeIn(duration: particle.duration * 0.4).delay(particle.delay + particle.duration * 0.6)) {
                opacity = 0
                scale = 0.3
            }
        }
    }
}
