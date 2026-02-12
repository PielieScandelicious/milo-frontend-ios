//
//  DachshundSniffingView.swift
//  Scandalicious
//
//  Animated Dachshund sniffing the ground for promotions — brand mascot loading screen.
//

import SwiftUI

// MARK: - Colors

private let furBrown = Color(red: 0.60, green: 0.38, blue: 0.22)
private let furDark = Color(red: 0.45, green: 0.26, blue: 0.14)
private let furLight = Color(red: 0.70, green: 0.48, blue: 0.30)
private let noseBlack = Color(red: 0.12, green: 0.10, blue: 0.08)
private let grassGreen = Color(red: 0.25, green: 0.60, blue: 0.28)
private let sniffGreen = Color(red: 0.20, green: 0.85, blue: 0.50)
private let sniffGreenDark = Color(red: 0.10, green: 0.65, blue: 0.40)

// Ground level offset from ZStack center
private let groundY: CGFloat = 40

// MARK: - Full Sniffing Loading View

struct DachshundSniffingView: View {
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            // Animated scene
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    // Grass behind dachshund
                    MovingGrassLayer(time: t)

                    // Ground line
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: groundY)

                    // Dachshund walking and sniffing
                    DachshundBody(time: t)
                        .offset(y: 12)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.07), Color(white: 0.04)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(sniffGreen.opacity(0.15), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))

            // Loading text
            VStack(spacing: 8) {
                Text("Sniffing out your deals...")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                Text("Checking promotions across stores")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                appeared = true
            }
        }
    }
}

// MARK: - Moving Grass Layer

/// Grass blades scrolling right-to-left, swaying gently.
private struct MovingGrassLayer: View {
    let time: Double

    private let bladeCount = 22
    private let virtualWidth: CGFloat = 360
    private let scrollSpeed: Double = 20
    private let heights: [CGFloat] = [
        11, 7, 14, 9, 13, 8, 16, 10, 12, 6,
        14, 9, 11, 8, 15, 10, 13, 7, 15, 9, 12, 8,
    ]

    var body: some View {
        let scrollOffset = CGFloat(fmod(time * scrollSpeed, Double(virtualWidth)))

        ForEach(0..<22) { i in
            let baseX = CGFloat(i) * (virtualWidth / CGFloat(bladeCount))
            let x = fmod(baseX - scrollOffset + virtualWidth * 1.5, virtualWidth) - virtualWidth / 2
            let h = heights[i % heights.count]
            let sway = sin(time * 2.5 + Double(i) * 0.7) * 6

            Capsule()
                .fill(grassGreen.opacity(0.35 + Double(i % 3) * 0.08))
                .frame(width: 2, height: h)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .offset(x: x, y: groundY - h / 2)
        }
    }
}

// MARK: - Dachshund Body (walking & sniffing pose)

/// All coordinates relative to body center at (0, 0).
/// Parent applies .offset(y: 12) so leg bottoms land at groundY (40).
private struct DachshundBody: View {
    let time: Double

    var body: some View {
        // Walking animation
        let walk = sin(time * 7) * 14.0           // leg swing angle
        let bob = abs(sin(time * 7)) * 1.5         // body bounce from walking
        let tailWag = sin(time * 10) * 15.0        // tail wag

        ZStack {
            // — Tail (Capsule, attached to rear of body, wagging)
            Capsule()
                .fill(furBrown)
                .frame(width: 5, height: 22)
                .rotationEffect(.degrees(-50 + tailWag * 0.8), anchor: .bottom)
                .offset(x: -42, y: -12 - bob)

            // — Back legs (diagonal gait: opposite to front legs)
            // Back-left leg
            RoundedRectangle(cornerRadius: 3)
                .fill(furDark.opacity(0.7))
                .frame(width: 8, height: 16)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: -25, y: 20 - bob)

            // Back-right leg
            RoundedRectangle(cornerRadius: 3)
                .fill(furDark.opacity(0.7))
                .frame(width: 8, height: 16)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: -18, y: 20 - bob)

            // — Body (long capsule, tilted slightly forward for sniffing posture)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [furLight, furBrown],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 85, height: 26)
                .rotationEffect(.degrees(4))
                .offset(y: -bob)

            // Belly shadow
            Capsule()
                .fill(furDark.opacity(0.2))
                .frame(width: 70, height: 6)
                .rotationEffect(.degrees(4))
                .offset(x: 0, y: 10 - bob)

            // — Front legs (diagonal gait: opposite to back legs)
            // Front-left leg
            RoundedRectangle(cornerRadius: 3)
                .fill(furBrown)
                .frame(width: 8, height: 16)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: 18, y: 20 - bob)

            // Front-right leg
            RoundedRectangle(cornerRadius: 3)
                .fill(furBrown)
                .frame(width: 8, height: 16)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: 25, y: 20 - bob)

            // — Head (tilted down — sniffing the ground)
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [furLight, furBrown],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28, height: 26)
                .rotationEffect(.degrees(20))
                .offset(x: 44, y: 10 - bob)

            // — Ear (floppy, hangs from top of head, dark brown)
            Ellipse()
                .fill(furDark)
                .frame(width: 14, height: 22)
                .rotationEffect(.degrees(15))
                .offset(x: 38, y: 14 - bob)

            // — Snout (angled down toward ground, static)
            Capsule()
                .fill(furBrown)
                .frame(width: 18, height: 11)
                .rotationEffect(.degrees(30))
                .offset(x: 55, y: 22 - bob)

            // — Nose (static, near ground)
            Ellipse()
                .fill(noseBlack)
                .frame(width: 8, height: 6)
                .offset(x: 60, y: 26 - bob)

            // Nose shine
            Ellipse()
                .fill(Color.white.opacity(0.25))
                .frame(width: 3, height: 2)
                .offset(x: 61, y: 24 - bob)

            // — Eye (on head, above snout)
            Circle()
                .fill(noseBlack)
                .frame(width: 5, height: 5)
                .offset(x: 48, y: 7 - bob)

            // Eye highlight
            Circle()
                .fill(Color.white.opacity(0.8))
                .frame(width: 2, height: 2)
                .offset(x: 49, y: 6 - bob)
        }
    }
}

// MARK: - Compact Banner Version (for OverviewView)

struct DachshundBannerView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 12) {
                // Mini scene: dachshund + grass
                ZStack {
                    miniGrass(time: t)
                    miniDachshund(time: t)
                        .offset(y: 2)
                }
                .frame(width: 60, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Sniffing for deals...")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))

                    Text("Finding promotions")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.35))
                }

                Spacer()

                ProgressView()
                    .tint(sniffGreen)
            }
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(white: 0.08))
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: [sniffGreen.opacity(0.05), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [sniffGreen.opacity(0.25), sniffGreenDark.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.5
                    )
            )
        }
    }

    // MARK: Mini grass (banner)

    @ViewBuilder
    private func miniGrass(time: Double) -> some View {
        let miniGround: CGFloat = 14
        let bladeCount = 8
        let virtualW: CGFloat = 90
        let scroll = CGFloat(fmod(time * 15, Double(virtualW)))

        ForEach(0..<8) { i in
            let baseX = CGFloat(i) * (virtualW / CGFloat(bladeCount))
            let x = fmod(baseX - scroll + virtualW * 1.5, virtualW) - virtualW / 2
            let heights: [CGFloat] = [5, 3, 6, 4, 5, 3, 7, 4]
            let h = heights[i]
            let sway = sin(time * 2.5 + Double(i) * 0.9) * 4

            Capsule()
                .fill(grassGreen.opacity(0.35))
                .frame(width: 1.5, height: h)
                .rotationEffect(.degrees(sway), anchor: .bottom)
                .offset(x: x, y: miniGround - h / 2)
        }

        // Ground line
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .offset(y: miniGround)
    }

    // MARK: Mini dachshund (banner, scaled ~0.35)

    @ViewBuilder
    private func miniDachshund(time: Double) -> some View {
        let s: CGFloat = 0.35
        let walk = sin(time * 7) * 10.0
        let bob = abs(sin(time * 7)) * 0.8
        let tailWag = sin(time * 10) * 10.0

        ZStack {
            // Tail (Capsule)
            Capsule()
                .fill(furBrown)
                .frame(width: 2.5, height: 22 * s)
                .rotationEffect(.degrees(-50 + tailWag * 0.8), anchor: .bottom)
                .offset(x: -42 * s, y: (-12 - bob) * s)

            // Back legs (walking)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(furDark.opacity(0.7))
                .frame(width: 3, height: 16 * s)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: -22 * s, y: (20 - bob) * s)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(furDark.opacity(0.7))
                .frame(width: 3, height: 16 * s)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: -16 * s, y: (20 - bob) * s)

            // Body
            Capsule()
                .fill(furBrown)
                .frame(width: 85 * s, height: 26 * s)
                .rotationEffect(.degrees(4))
                .offset(y: -bob * s)

            // Front legs (walking, opposite phase)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(furBrown)
                .frame(width: 3, height: 16 * s)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: 18 * s, y: (20 - bob) * s)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(furBrown)
                .frame(width: 3, height: 16 * s)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: 24 * s, y: (20 - bob) * s)

            // Head
            Ellipse()
                .fill(furBrown)
                .frame(width: 28 * s, height: 26 * s)
                .rotationEffect(.degrees(20))
                .offset(x: 44 * s, y: (10 - bob) * s)

            // Ear
            Ellipse()
                .fill(furDark)
                .frame(width: 14 * s, height: 22 * s)
                .rotationEffect(.degrees(15))
                .offset(x: 38 * s, y: (14 - bob) * s)

            // Snout (static)
            Capsule()
                .fill(furBrown)
                .frame(width: 18 * s, height: 11 * s)
                .rotationEffect(.degrees(30))
                .offset(x: 55 * s, y: (22 - bob) * s)

            // Nose (static)
            Ellipse()
                .fill(noseBlack)
                .frame(width: 8 * s, height: 6 * s)
                .offset(x: 60 * s, y: (26 - bob) * s)

            // Eye
            Circle()
                .fill(noseBlack)
                .frame(width: 2.5)
                .offset(x: 48 * s, y: (7 - bob) * s)
        }
    }
}
