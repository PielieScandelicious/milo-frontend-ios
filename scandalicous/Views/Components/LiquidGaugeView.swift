//
//  LiquidGaugeView.swift
//  Scandalicious
//
//  Created by Claude on 21/01/2026.
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Liquid Gauge View

/// A beautiful liquid-filled circular gauge that responds to device motion
struct LiquidGaugeView: View {
    let score: Double?
    var size: CGFloat = 120
    var showLabel: Bool = true

    @StateObject private var motionManager = MotionManager()
    @State private var fillProgress: CGFloat = 0

    private var normalizedScore: CGFloat {
        guard let score = score else { return 0 }
        return CGFloat(score / 5.0)
    }

    private var liquidColor: Color {
        score.healthScoreColor
    }

    var body: some View {
        VStack(spacing: size * 0.08) {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    // Background circle
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: size, height: size)

                    // Outer ring glow
                    Circle()
                        .stroke(liquidColor.opacity(0.3), lineWidth: 2)
                        .frame(width: size, height: size)
                        .blur(radius: 4)

                    // Liquid fill with wave
                    LiquidWave(
                        progress: fillProgress * normalizedScore,
                        waveHeight: size * 0.04,
                        phase: time,
                        tiltX: motionManager.tiltX
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                liquidColor.opacity(0.95),
                                liquidColor.opacity(0.75),
                                liquidColor.opacity(0.55)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size - 6, height: size - 6)
                    .clipShape(Circle())

                    // Secondary wave highlight
                    LiquidWave(
                        progress: fillProgress * normalizedScore,
                        waveHeight: size * 0.025,
                        phase: time * 0.8 + 1.5,
                        tiltX: motionManager.tiltX * 0.6
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.1),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .frame(width: size - 6, height: size - 6)
                    .clipShape(Circle())

                    // Glass reflection
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.12),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size - 6, height: size - 6)

                    // Outer ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(width: size, height: size)

                }
            }

            if showLabel {
                Text(score.healthScoreLabel)
                    .font(.system(size: size * 0.11, weight: .semibold))
                    .foregroundColor(liquidColor)
            }
        }
        .onAppear {
            motionManager.start()

            withAnimation(.easeOut(duration: 1.0)) {
                fillProgress = 1.0
            }
        }
        .onDisappear {
            motionManager.stop()
        }
    }
}

// MARK: - Liquid Wave Shape

struct LiquidWave: Shape {
    var progress: CGFloat
    var waveHeight: CGFloat
    var phase: Double
    var tiltX: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(progress, tiltX) }
        set {
            progress = newValue.first
            tiltX = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Base water level (inverted - 0 at bottom, 1 at top)
        let waterLevel = height * (1.0 - progress)

        // Tilt effect - creates the gyroscope response
        let maxTilt = height * 0.12
        let tiltAmount = tiltX * maxTilt

        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: height))

        // Left edge to water
        path.addLine(to: CGPoint(x: 0, y: waterLevel + tiltAmount))

        // Wave across the top
        let steps = Int(width)
        for i in 0...steps {
            let x = CGFloat(i)
            let relativeX = x / width

            // Primary wave
            let wave1 = sin(relativeX * .pi * 2 + phase * 2) * waveHeight

            // Secondary wave for organic feel
            let wave2 = sin(relativeX * .pi * 3 + phase * 1.5) * waveHeight * 0.4

            // Tilt interpolation (left side higher when tilted right)
            let tiltEffect = tiltAmount * (1.0 - 2.0 * relativeX)

            let y = waterLevel + wave1 + wave2 + tiltEffect

            path.addLine(to: CGPoint(x: x, y: y))
        }

        // Close the shape
        path.addLine(to: CGPoint(x: width, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Motion Manager

final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    private let queue = OperationQueue()

    @Published var tiltX: CGFloat = 0
    @Published var tiltY: CGFloat = 0

    init() {
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }

    func start() {
        guard manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, _ in
            guard let self = self, let motion = motion else { return }

            let gravity = motion.gravity

            DispatchQueue.main.async {
                // Smooth interpolation
                let smoothing: CGFloat = 0.12
                let newTiltX = self.tiltX + smoothing * (CGFloat(gravity.x) - self.tiltX)
                let newTiltY = self.tiltY + smoothing * (CGFloat(gravity.y) - self.tiltY)

                self.tiltX = newTiltX
                self.tiltY = newTiltY
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 40) {
            Text("Liquid Gauge")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: 30) {
                LiquidGaugeView(score: 4.5, size: 80)
                LiquidGaugeView(score: 3.2, size: 80)
                LiquidGaugeView(score: 1.5, size: 80)
            }

            LiquidGaugeView(score: 3.8, size: 140)

            LiquidGaugeView(score: nil, size: 100)
        }
        .padding()
    }
}
