//
//  SpinWheelView.swift
//  Scandalicious
//
//  Created by Claude on 20/02/2026.
//

import SwiftUI

struct SpinWheelView: View {
    @ObservedObject private var gm = GamificationManager.shared
    @State private var rotation: Double = 0
    @State private var isSpinning = false
    @State private var winningSegment: SpinSegment? = nil
    @State private var showResult = false
    @State private var showConfetti = false
    @Environment(\.dismiss) private var dismiss

    private let segments = SpinSegment.segments
    private let wheelSize: CGFloat = min(UIScreen.main.bounds.width - 64, 320)

    private let gold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(white: 0.04).ignoresSafeArea()

                // Subtle radial glow behind wheel
                RadialGradient(
                    colors: [gold.opacity(0.06), Color.clear],
                    center: .center, startRadius: 40, endRadius: 260
                )
                .ignoresSafeArea()

                if showConfetti { ConfettiView() }

                VStack(spacing: 24) {
                    spinsCounter

                    // Wheel + pointer
                    ZStack {
                        // Outer ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [gold.opacity(0.4), gold.opacity(0.1), gold.opacity(0.3)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: wheelSize + 8, height: wheelSize + 8)

                        WheelCanvas(segments: segments, rotation: rotation)
                            .frame(width: wheelSize, height: wheelSize)
                            .clipShape(Circle())

                        // Center hub
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(white: 0.18), Color(white: 0.06)],
                                    center: .center, startRadius: 0, endRadius: 22
                                )
                            )
                            .frame(width: 44, height: 44)
                            .overlay(
                                Circle()
                                    .stroke(gold.opacity(0.3), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.5), radius: 6)

                        // Pointer at top
                        VStack(spacing: 0) {
                            PointerShape()
                                .fill(
                                    LinearGradient(
                                        colors: [gold, Color(red: 0.85, green: 0.65, blue: 0.0)],
                                        startPoint: .top, endPoint: .bottom
                                    )
                                )
                                .frame(width: 22, height: 30)
                                .shadow(color: gold.opacity(0.5), radius: 6, y: 2)
                                .shadow(color: .black.opacity(0.4), radius: 3, y: 1)
                            Spacer()
                        }
                        .frame(height: wheelSize + 8)
                    }

                    spinButton

                    if let result = winningSegment, showResult {
                        resultCard(result)
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(white: 0.04), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - Spins Counter

    private var spinsCounter: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(gold)
            Text("\(gm.spinsAvailable) spin\(gm.spinsAvailable == 1 ? "" : "s") available")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color(white: 0.08))
                .overlay(
                    Capsule()
                        .stroke(gold.opacity(0.15), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Spin Button

    private var spinButton: some View {
        Button {
            guard gm.spinsAvailable > 0 && !isSpinning else { return }
            startSpin()
        } label: {
            HStack(spacing: 8) {
                if !isSpinning {
                    Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                        .font(.system(size: 15, weight: .bold))
                }
                Text(isSpinning ? "Spinning..." : (gm.spinsAvailable > 0 ? "SPIN" : "No Spins Left"))
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(gm.spinsAvailable > 0 && !isSpinning ? .black : .white.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        gm.spinsAvailable > 0 && !isSpinning
                            ? LinearGradient(
                                colors: [gold, Color(red: 0.9, green: 0.7, blue: 0.0)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(
                                colors: [Color(white: 0.12), Color(white: 0.08)],
                                startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .shadow(color: gold.opacity(
                        isSpinning || gm.spinsAvailable == 0 ? 0 : 0.3), radius: 12, y: 4)
            )
        }
        .buttonStyle(ScaleScanButtonStyle())
        .disabled(isSpinning || gm.spinsAvailable == 0)
    }

    // MARK: - Result Card

    private func resultCard(_ segment: SpinSegment) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(gold.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: segment.isJackpot ? "star.fill" : "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(gold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(segment.isJackpot ? "JACKPOT!" : "You won")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(gold.opacity(0.8))
                Text(segment.label)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            Spacer()

            Text("Added")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(white: 0.12)))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(white: 0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(gold.opacity(0.2), lineWidth: 1)
                )
        )
    }

    // MARK: - Spin Logic

    private func startSpin() {
        isSpinning = true
        showResult = false
        showConfetti = false
        winningSegment = nil

        guard let result = gm.spinWheel() else {
            isSpinning = false
            return
        }

        let targetSegment = segments[result.segmentIndex]
        let segCount = Double(segments.count)
        let segmentAngle = 360.0 / segCount

        // The pointer is at the top (0° / 12 o'clock).
        // Segments are drawn starting from -90° (top), going clockwise.
        // Segment N spans from N*segmentAngle to (N+1)*segmentAngle.
        // To land segment N under the pointer, we need to rotate so
        // the center of segment N aligns with 0° (top).
        // That means rotating by: -(N * segmentAngle + segmentAngle/2)
        // which in positive rotation terms is: 360 - (N + 0.5) * segmentAngle
        let targetStop = 360.0 - (Double(result.segmentIndex) + 0.5) * segmentAngle

        // Normalize current rotation to 0-360 to calculate how much more to spin
        let currentNormalized = rotation.truncatingRemainder(dividingBy: 360.0)
        let extra = targetStop - currentNormalized
        let fullSpins = Double(Int.random(in: 5...8)) * 360.0
        let totalSpin = fullSpins + extra

        withAnimation(.timingCurve(0.15, 0.85, 0.1, 1.0, duration: 4.5)) {
            rotation += totalSpin
        }

        startTickHaptics(duration: 4.5)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4.6) {
            winningSegment = targetSegment
            isSpinning = false

            UINotificationFeedbackGenerator().notificationOccurred(.success)

            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.15)) {
                showResult = true
            }

            if result.isJackpot || result.valueEuros >= 10.0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    showConfetti = true
                }
            }
        }
    }

    private func startTickHaptics(duration: TimeInterval) {
        let tickGenerator = UIImpactFeedbackGenerator(style: .light)
        tickGenerator.prepare()
        let totalTicks = 30
        for i in 0..<totalTicks {
            let t = Double(i) / Double(totalTicks)
            let eased = 1.0 - pow(1.0 - t, 3)
            let delay = eased * duration * 0.95
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                tickGenerator.impactOccurred()
            }
        }
    }
}

// MARK: - Wheel Canvas

private struct WheelCanvas: View {
    let segments: [SpinSegment]
    let rotation: Double

    // Premium dark palette — alternating dark tones
    private let sliceColors: [(Color, Color)] = [
        (Color(white: 0.13), Color(white: 0.10)),
        (Color(white: 0.09), Color(white: 0.06)),
    ]

    private let accentGold = Color(red: 1.0, green: 0.84, blue: 0.0)

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let sliceAngle = 2.0 * .pi / Double(segments.count)

            for segment in segments {
                let startAngle = Double(segment.id) * sliceAngle - .pi / 2
                let endAngle = startAngle + sliceAngle

                var segPath = Path()
                segPath.move(to: center)
                segPath.addArc(center: center, radius: radius,
                               startAngle: Angle(radians: startAngle),
                               endAngle: Angle(radians: endAngle), clockwise: false)
                segPath.closeSubpath()

                // Alternating dark slices
                let colorPair = sliceColors[segment.id % 2]
                context.fill(segPath, with: .color(colorPair.0))

                // Subtle separator line
                var linePath = Path()
                linePath.move(to: center)
                let lineEnd = CGPoint(
                    x: center.x + cos(startAngle) * radius,
                    y: center.y + sin(startAngle) * radius
                )
                linePath.addLine(to: lineEnd)
                context.stroke(linePath, with: .color(.white.opacity(0.06)), lineWidth: 1)

                // Label
                let midAngle = startAngle + sliceAngle / 2.0
                let labelRadius = radius * 0.62
                let labelPt = CGPoint(
                    x: center.x + cos(midAngle) * labelRadius,
                    y: center.y + sin(midAngle) * labelRadius
                )
                let rotDeg = midAngle * 180 / .pi + 90

                context.drawLayer { ctx in
                    ctx.translateBy(x: labelPt.x, y: labelPt.y)
                    ctx.rotate(by: Angle(degrees: rotDeg))

                    let text = Text(segment.label)
                        .font(.system(
                            size: segment.isJackpot ? 12 : 14,
                            weight: .bold,
                            design: .rounded
                        ))
                        .foregroundStyle(
                            segment.isJackpot
                                ? Color(red: 1.0, green: 0.84, blue: 0.0)
                                : .white.opacity(0.85)
                        )
                    ctx.draw(text, at: .zero)
                }

                // Small dot accent at outer edge
                let dotRadius: CGFloat = 2.5
                let dotDist = radius - 12
                let dotPt = CGPoint(
                    x: center.x + cos(midAngle) * dotDist,
                    y: center.y + sin(midAngle) * dotDist
                )
                let dotRect = CGRect(x: dotPt.x - dotRadius, y: dotPt.y - dotRadius,
                                     width: dotRadius * 2, height: dotRadius * 2)
                context.fill(
                    Circle().path(in: dotRect),
                    with: .color(segment.isJackpot
                                 ? Color(red: 1.0, green: 0.84, blue: 0.0).opacity(0.6)
                                 : .white.opacity(0.12))
                )
            }
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Pointer Shape

private struct PointerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Sleek downward-pointing arrow
        let tipY = rect.maxY
        let topY = rect.minY
        let midX = rect.midX
        let halfW = rect.width / 2

        path.move(to: CGPoint(x: midX, y: tipY))
        path.addLine(to: CGPoint(x: midX - halfW, y: topY))
        path.addQuadCurve(
            to: CGPoint(x: midX + halfW, y: topY),
            control: CGPoint(x: midX, y: topY + rect.height * 0.25)
        )
        path.closeSubpath()
        return path
    }
}
