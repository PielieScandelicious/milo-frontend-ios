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

// Store colors
private let storeWall = Color(white: 0.10)
private let storeWallLight = Color(white: 0.13)
private let windowLit = Color(red: 0.95, green: 0.82, blue: 0.45)
private let awningRed = Color(red: 0.65, green: 0.18, blue: 0.15)
private let awningTeal = Color(red: 0.12, green: 0.50, blue: 0.45)

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
                    // Stores scrolling in the background
                    MovingStoresLayer(time: t)

                    // Grass behind dachshund
                    MovingGrassLayer(time: t)

                    // Ground line
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .offset(y: groundY)

                    // Dachshund walking and sniffing
                    DachshundBody(time: t)
                        .offset(x: -20, y: 12)
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

// MARK: - Moving Stores Background

/// Sporadic grocery store silhouettes scrolling slower than grass for parallax depth.
private struct MovingStoresLayer: View {
    let time: Double

    private let virtualWidth: CGFloat = 700
    private let scrollSpeed: Double = 12 // slower than grass (20) for parallax

    // Each store: (baseX, width, height, style 0-4)
    private let stores: [(CGFloat, CGFloat, CGFloat, Int)] = [
        (40,  46, 60, 0),
        (180, 56, 42, 1),
        (330, 42, 52, 2),
        (500, 50, 46, 3),
        (620, 38, 56, 4),
    ]

    var body: some View {
        let scrollOffset = CGFloat(fmod(time * scrollSpeed, Double(virtualWidth)))

        ForEach(0..<stores.count, id: \.self) { i in
            let store = stores[i]
            let x = fmod(store.0 - scrollOffset + virtualWidth * 1.5, virtualWidth) - virtualWidth / 2

            StoreBuilding(width: store.1, height: store.2, style: store.3, time: time)
                .offset(x: x, y: groundY - store.2 / 2)
        }
    }
}

/// A single grocery store silhouette with windows, awning, door, and sign.
private struct StoreBuilding: View {
    let width: CGFloat
    let height: CGFloat
    let style: Int
    let time: Double

    private var wallColor: Color {
        Color(white: 0.08 + Double(style) * 0.012)
    }

    private var awningColor: Color {
        switch style % 3 {
        case 0: return awningRed.opacity(0.35)
        case 1: return awningTeal.opacity(0.35)
        default: return sniffGreen.opacity(0.25)
        }
    }

    private var cols: Int { width > 48 ? 3 : 2 }
    private var rows: Int { height > 50 ? 3 : 2 }

    var body: some View {
        ZStack {
            // Building body
            RoundedRectangle(cornerRadius: 2)
                .fill(wallColor)
                .frame(width: width, height: height)

            // Subtle edge highlight
            RoundedRectangle(cornerRadius: 2)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
                .frame(width: width, height: height)

            // Roof cap
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(width: width + 4, height: 2)
                .offset(y: -height / 2 + 1)

            // Windows
            VStack(spacing: 5) {
                ForEach(0..<rows, id: \.self) { row in
                    HStack(spacing: 4) {
                        ForEach(0..<cols, id: \.self) { col in
                            let flicker = sin(time * 0.8 + Double(row * 3 + col + style * 7)) > -0.3
                            let lit = (row + col + style) % 3 != 0 && flicker
                            RoundedRectangle(cornerRadius: 0.5)
                                .fill(lit ? windowLit.opacity(0.18) : Color.white.opacity(0.03))
                                .frame(width: 7, height: 6)
                        }
                    }
                }
            }
            .offset(y: -height * 0.15)

            // Awning
            AwningShape()
                .fill(awningColor)
                .frame(width: width + 6, height: 7)
                .offset(y: height / 2 - 12)

            // Awning stripe
            AwningShape()
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                .frame(width: width + 6, height: 7)
                .offset(y: height / 2 - 12)

            // Store sign (small glowing rectangle above awning)
            RoundedRectangle(cornerRadius: 1)
                .fill(sniffGreen.opacity(0.10))
                .frame(width: width * 0.45, height: 4)
                .offset(y: height / 2 - 17)

            // Door
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.white.opacity(0.04))
                .frame(width: 8, height: 10)
                .offset(y: height / 2 - 5)

            // Door handle dot
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 1.5)
                .offset(x: 2.5, y: height / 2 - 5)
        }
    }
}

/// Awning shape — slight trapezoid / scalloped bottom for a storefront look.
private struct AwningShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: w, y: 0))
        path.addLine(to: CGPoint(x: w - 3, y: h))
        // Scalloped bottom edge
        let scallops = 5
        let scW = (w - 6) / CGFloat(scallops)
        for i in stride(from: scallops - 1, through: 0, by: -1) {
            let sx = 3 + CGFloat(i) * scW
            path.addQuadCurve(
                to: CGPoint(x: sx, y: h),
                control: CGPoint(x: sx + scW / 2, y: h + 3)
            )
        }
        path.addLine(to: CGPoint(x: 3, y: h))
        path.closeSubpath()
        return path
    }
}

// MARK: - Custom Dog Shapes

/// Dog head side profile — wider forehead, tapered jaw (not a plain circle)
private struct DogHeadShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.5, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.38),
            control1: CGPoint(x: w * 0.78, y: 0),
            control2: CGPoint(x: w, y: h * 0.12)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.6, y: h),
            control1: CGPoint(x: w, y: h * 0.68),
            control2: CGPoint(x: w * 0.82, y: h * 0.92)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.3, y: h),
            control1: CGPoint(x: w * 0.5, y: h * 1.06),
            control2: CGPoint(x: w * 0.4, y: h * 1.06)
        )
        path.addCurve(
            to: CGPoint(x: 0, y: h * 0.38),
            control1: CGPoint(x: w * 0.12, y: h * 0.92),
            control2: CGPoint(x: 0, y: h * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.5, y: 0),
            control1: CGPoint(x: 0, y: h * 0.12),
            control2: CGPoint(x: w * 0.22, y: 0)
        )
        path.closeSubpath()
        return path
    }
}

/// Floppy dachshund ear — hooks out at top, hangs down with rounded tip
private struct FlopEarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.4, y: 0))
        path.addCurve(
            to: CGPoint(x: w, y: h * 0.15),
            control1: CGPoint(x: w * 0.6, y: -h * 0.06),
            control2: CGPoint(x: w * 0.95, y: -h * 0.02)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.6, y: h * 0.9),
            control1: CGPoint(x: w * 1.05, y: h * 0.45),
            control2: CGPoint(x: w * 0.85, y: h * 0.8)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.15, y: h * 0.75),
            control1: CGPoint(x: w * 0.4, y: h * 1.05),
            control2: CGPoint(x: w * 0.1, y: h * 0.98)
        )
        path.addCurve(
            to: CGPoint(x: w * 0.4, y: 0),
            control1: CGPoint(x: w * 0.2, y: h * 0.4),
            control2: CGPoint(x: w * 0.3, y: h * 0.05)
        )
        path.closeSubpath()
        return path
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
        let earFlap = sin(time * 7) * 3.0          // subtle ear bounce from trotting

        ZStack {
            // — Tail (Capsule, tucked into rear of body, wagging)
            Capsule()
                .fill(furBrown)
                .frame(width: 5, height: 22)
                .rotationEffect(.degrees(-50 + tailWag * 0.8), anchor: .bottom)
                .offset(x: -36, y: -10 - bob)

            // — Back legs (diagonal gait: opposite to front legs)
            // Back-left leg
            RoundedRectangle(cornerRadius: 3)
                .fill(furDark.opacity(0.7))
                .frame(width: 8, height: 28)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: -25, y: 14 - bob)

            // Back-right leg
            RoundedRectangle(cornerRadius: 3)
                .fill(furDark.opacity(0.7))
                .frame(width: 8, height: 28)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: -18, y: 14 - bob)

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

            // — Head (dog-shaped — wider forehead, tapered jaw)
            DogHeadShape()
                .fill(
                    LinearGradient(
                        colors: [furLight, furBrown],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 30, height: 28)
                .rotationEffect(.degrees(20))
                .offset(x: 44, y: 10 - bob)

            // Head highlight (subtle forehead glow)
            Ellipse()
                .fill(furLight.opacity(0.4))
                .frame(width: 16, height: 10)
                .rotationEffect(.degrees(20))
                .offset(x: 42, y: 4 - bob)

            // — Front ear (big floppy, prominent — cute like Milo avatar)
            FlopEarShape()
                .fill(furDark)
                .frame(width: 18, height: 30)
                .rotationEffect(.degrees(22 + earFlap), anchor: .top)
                .offset(x: 39, y: 4 - bob)

            // — Snout (angled down toward ground)
            Capsule()
                .fill(furBrown)
                .frame(width: 18, height: 11)
                .rotationEffect(.degrees(30))
                .offset(x: 55, y: 22 - bob)

            // — Nose (near ground)
            Ellipse()
                .fill(noseBlack)
                .frame(width: 8, height: 6)
                .offset(x: 60, y: 26 - bob)

            // Nose shine
            Ellipse()
                .fill(Color.white.opacity(0.25))
                .frame(width: 3, height: 2)
                .offset(x: 61, y: 24 - bob)

            // — Eye (on head, with Milo-style shine highlights)
            Circle()
                .fill(noseBlack)
                .frame(width: 5, height: 5)
                .offset(x: 47, y: 6 - bob)

            // Eye primary highlight
            Circle()
                .fill(Color.white.opacity(0.85))
                .frame(width: 2.5, height: 2.5)
                .offset(x: 48.5, y: 4.5 - bob)

            // Eye secondary highlight
            Circle()
                .fill(Color.white.opacity(0.4))
                .frame(width: 1.5, height: 1.5)
                .offset(x: 46, y: 7.5 - bob)
        }
    }
}

// MARK: - Compact Banner Version (for OverviewView)

struct DachshundBannerView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            HStack(spacing: 12) {
                // Mini scene: stores + dachshund + grass
                ZStack {
                    miniStores(time: t)
                    miniGrass(time: t)
                    miniDachshund(time: t)
                        .offset(x: -6, y: 4)
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

    // MARK: Mini stores (banner)

    @ViewBuilder
    private func miniStores(time: Double) -> some View {
        let miniGround: CGFloat = 14
        let virtualW: CGFloat = 180
        let scroll = CGFloat(fmod(time * 8, Double(virtualW))) // slower parallax

        // 3 tiny store silhouettes
        let storeData: [(CGFloat, CGFloat, CGFloat)] = [
            (10, 16, 18),   // (baseX, width, height)
            (70, 20, 14),
            (140, 14, 20),
        ]

        ForEach(0..<storeData.count, id: \.self) { i in
            let store = storeData[i]
            let x = fmod(store.0 - scroll + virtualW * 1.5, virtualW) - virtualW / 2
            let w = store.1
            let h = store.2

            ZStack {
                // Building
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(white: 0.10))
                    .frame(width: w, height: h)

                // Tiny windows
                HStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(windowLit.opacity(0.15))
                        .frame(width: 2.5, height: 2)
                    RoundedRectangle(cornerRadius: 0.5)
                        .fill(windowLit.opacity(0.10))
                        .frame(width: 2.5, height: 2)
                }
                .offset(y: -h * 0.15)

                // Tiny awning
                Rectangle()
                    .fill(i % 2 == 0 ? awningRed.opacity(0.25) : awningTeal.opacity(0.25))
                    .frame(width: w + 2, height: 1.5)
                    .offset(y: h / 2 - 3)
            }
            .offset(x: x, y: miniGround - h / 2)
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
            // Tail (tucked into body)
            Capsule()
                .fill(furBrown)
                .frame(width: 2.5, height: 22 * s)
                .rotationEffect(.degrees(-50 + tailWag * 0.8), anchor: .bottom)
                .offset(x: -36 * s, y: (-10 - bob) * s)

            // Back legs (walking)
            RoundedRectangle(cornerRadius: 1.5)
                .fill(furDark.opacity(0.7))
                .frame(width: 3, height: 28 * s)
                .rotationEffect(.degrees(walk), anchor: .top)
                .offset(x: -22 * s, y: (14 - bob) * s)

            RoundedRectangle(cornerRadius: 1.5)
                .fill(furDark.opacity(0.7))
                .frame(width: 3, height: 28 * s)
                .rotationEffect(.degrees(-walk), anchor: .top)
                .offset(x: -16 * s, y: (14 - bob) * s)

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

            // Head (dog-shaped)
            DogHeadShape()
                .fill(furBrown)
                .frame(width: 30 * s, height: 28 * s)
                .rotationEffect(.degrees(20))
                .offset(x: 44 * s, y: (10 - bob) * s)

            // Front ear (mini)
            FlopEarShape()
                .fill(furDark)
                .frame(width: 18 * s, height: 30 * s)
                .rotationEffect(.degrees(22), anchor: .top)
                .offset(x: 39 * s, y: (4 - bob) * s)

            // Snout
            Capsule()
                .fill(furBrown)
                .frame(width: 18 * s, height: 11 * s)
                .rotationEffect(.degrees(30))
                .offset(x: 55 * s, y: (22 - bob) * s)

            // Nose
            Ellipse()
                .fill(noseBlack)
                .frame(width: 8 * s, height: 6 * s)
                .offset(x: 60 * s, y: (26 - bob) * s)

            // Eye
            Circle()
                .fill(noseBlack)
                .frame(width: 2.5)
                .offset(x: 47 * s, y: (6 - bob) * s)
        }
    }
}
