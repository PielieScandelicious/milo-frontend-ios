//
//  ConfettiView.swift
//  Scandalicious
//
//  Premium celebration overlay with metallic ribbons, glow halos, and sparkles.
//

import SwiftUI

struct ConfettiView: View {
    @State private var ribbons: [CelebrationRibbon] = []
    @State private var sparkles: [CelebrationSparkle] = []
    @State private var halos: [CelebrationHalo] = []

    private let palette: [Color] = [
        Color(red: 0.95, green: 0.92, blue: 0.86),
        Color(red: 0.73, green: 0.66, blue: 0.58),
        Color(red: 0.46, green: 0.53, blue: 0.62),
        Color(red: 0.27, green: 0.66, blue: 0.62)
    ]

    var body: some View {
        GeometryReader { geo in
            let anchor = CGPoint(
                x: geo.size.width * 0.5,
                y: min(max(geo.size.height * 0.28, 150), 260)
            )

            ZStack {
                ForEach(halos) { halo in
                    CelebrationHaloView(halo: halo, anchor: anchor)
                }

                ForEach(ribbons) { ribbon in
                    CelebrationRibbonView(ribbon: ribbon, anchor: anchor)
                }

                ForEach(sparkles) { sparkle in
                    CelebrationSparkleView(sparkle: sparkle, anchor: anchor)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .drawingGroup()
        .onAppear { generateCelebration() }
    }

    private func generateCelebration() {
        halos = [
            CelebrationHalo(
                size: 160,
                alpha: 0.18,
                color: palette[0],
                delay: 0.0,
                duration: 1.2,
                finalScale: 1.3
            ),
            CelebrationHalo(
                size: 250,
                alpha: 0.10,
                color: palette[3],
                delay: 0.08,
                duration: 1.45,
                finalScale: 1.18
            )
        ]

        ribbons = (0..<26).map { index in
            let angle: Double
            if index.isMultiple(of: 2) {
                angle = Double.random(in: -162 ... -102)
            } else {
                angle = Double.random(in: -78 ... -18)
            }

            return CelebrationRibbon(
                angle: angle,
                distance: CGFloat.random(in: 80 ... 210),
                length: CGFloat.random(in: 18 ... 42),
                thickness: CGFloat.random(in: 4 ... 8),
                delay: Double.random(in: 0.02 ... 0.18),
                duration: Double.random(in: 0.85 ... 1.35),
                rotation: Double.random(in: -110 ... 110),
                color: palette.randomElement() ?? palette[0],
                alpha: Double.random(in: 0.75 ... 0.98),
                lift: CGFloat.random(in: -35 ... 30),
                blur: CGFloat.random(in: 0.0 ... 1.0)
            )
        }

        let sparkleSymbols = ["sparkle", "diamond.fill", "circle.fill"]
        sparkles = (0..<18).map { _ in
            CelebrationSparkle(
                symbol: sparkleSymbols.randomElement() ?? "sparkle",
                startX: CGFloat.random(in: -40 ... 40),
                startY: CGFloat.random(in: -12 ... 18),
                endX: CGFloat.random(in: -160 ... 160),
                endY: CGFloat.random(in: -150 ... 120),
                size: CGFloat.random(in: 8 ... 18),
                delay: Double.random(in: 0.04 ... 0.28),
                duration: Double.random(in: 1.1 ... 1.9),
                rotation: Double.random(in: -80 ... 80),
                color: palette.randomElement() ?? palette[0],
                alpha: Double.random(in: 0.55 ... 0.95),
                blur: CGFloat.random(in: 0.0 ... 1.5),
                finalScale: CGFloat.random(in: 0.86 ... 1.18)
            )
        }
    }
}

private struct CelebrationHaloView: View {
    let halo: CelebrationHalo
    let anchor: CGPoint

    @State private var scale: CGFloat = 0.72
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        halo.color.opacity(halo.alpha),
                        halo.color.opacity(halo.alpha * 0.45),
                        .clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: halo.size * 0.5
                )
            )
            .frame(width: halo.size, height: halo.size)
            .position(anchor)
            .scaleEffect(scale)
            .opacity(opacity)
            .blur(radius: 18)
            .blendMode(.screen)
            .onAppear {
                withAnimation(.easeOut(duration: halo.duration * 0.4).delay(halo.delay)) {
                    opacity = 1
                    scale = halo.finalScale
                }

                withAnimation(.easeOut(duration: halo.duration).delay(halo.delay + 0.16)) {
                    opacity = 0
                }
            }
    }
}

private struct CelebrationRibbonView: View {
    let ribbon: CelebrationRibbon
    let anchor: CGPoint

    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.3
    @State private var rotation: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: ribbon.thickness * 0.5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(ribbon.alpha * 0.85),
                        ribbon.color.opacity(ribbon.alpha)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: ribbon.length, height: ribbon.thickness)
            .overlay(
                RoundedRectangle(cornerRadius: ribbon.thickness * 0.5, style: .continuous)
                    .stroke(Color.white.opacity(0.15), lineWidth: 0.7)
            )
            .shadow(color: ribbon.color.opacity(0.18), radius: 10, y: 3)
            .blur(radius: ribbon.blur)
            .position(anchor)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .blendMode(.screen)
            .onAppear {
                let radians = ribbon.angle * .pi / 180
                let finalOffset = CGSize(
                    width: cos(radians) * ribbon.distance,
                    height: sin(radians) * ribbon.distance + ribbon.lift
                )

                withAnimation(.easeOut(duration: 0.14).delay(ribbon.delay)) {
                    opacity = ribbon.alpha
                    scale = 1
                    rotation = ribbon.rotation * 0.35
                }

                withAnimation(.timingCurve(0.18, 0.84, 0.22, 1, duration: ribbon.duration).delay(ribbon.delay)) {
                    offset = finalOffset
                    rotation = ribbon.rotation
                }

                withAnimation(.easeOut(duration: 0.5).delay(ribbon.delay + ribbon.duration * 0.54)) {
                    opacity = 0
                    scale = 0.9
                }
            }
    }
}

private struct CelebrationSparkleView: View {
    let sparkle: CelebrationSparkle
    let anchor: CGPoint

    @State private var offset: CGSize = .zero
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.25
    @State private var rotation: Double = 0

    var body: some View {
        Image(systemName: sparkle.symbol)
            .font(.system(size: sparkle.size, weight: .medium))
            .foregroundStyle(sparkle.color.opacity(sparkle.alpha))
            .shadow(color: sparkle.color.opacity(sparkle.alpha * 0.4), radius: 10, y: 2)
            .blur(radius: sparkle.blur)
            .position(x: anchor.x + sparkle.startX, y: anchor.y + sparkle.startY)
            .offset(offset)
            .rotationEffect(.degrees(rotation))
            .scaleEffect(scale)
            .opacity(opacity)
            .blendMode(.screen)
            .onAppear {
                withAnimation(.easeOut(duration: 0.16).delay(sparkle.delay)) {
                    opacity = sparkle.alpha
                    scale = 1
                }

                withAnimation(.timingCurve(0.22, 0.82, 0.24, 1, duration: sparkle.duration).delay(sparkle.delay)) {
                    offset = CGSize(width: sparkle.endX, height: sparkle.endY)
                    rotation = sparkle.rotation
                }

                withAnimation(.easeOut(duration: 0.65).delay(sparkle.delay + sparkle.duration * 0.5)) {
                    opacity = 0
                    scale = sparkle.finalScale
                }
            }
    }
}

private struct CelebrationRibbon: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let length: CGFloat
    let thickness: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let color: Color
    let alpha: Double
    let lift: CGFloat
    let blur: CGFloat
}

private struct CelebrationSparkle: Identifiable {
    let id = UUID()
    let symbol: String
    let startX: CGFloat
    let startY: CGFloat
    let endX: CGFloat
    let endY: CGFloat
    let size: CGFloat
    let delay: Double
    let duration: Double
    let rotation: Double
    let color: Color
    let alpha: Double
    let blur: CGFloat
    let finalScale: CGFloat
}

private struct CelebrationHalo: Identifiable {
    let id = UUID()
    let size: CGFloat
    let alpha: Double
    let color: Color
    let delay: Double
    let duration: Double
    let finalScale: CGFloat
}
