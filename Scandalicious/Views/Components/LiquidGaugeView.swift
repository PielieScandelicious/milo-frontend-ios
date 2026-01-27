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

    /// Skip animation and motion for small gauges (overview cards) to improve swipe performance
    private var shouldAnimate: Bool {
        size > 100
    }

    private var normalizedScore: CGFloat {
        guard let score = score else { return 0 }
        let linearProgress = CGFloat(score / 5.0)
        // Convert linear progress to height that fills the correct circular AREA
        // This makes visual perception match the actual score percentage
        return circularAreaToHeight(linearProgress)
    }

    /// Converts a desired fill percentage (0-1) to the height needed in a circle
    /// so that the filled AREA matches the percentage, not just the height
    private func circularAreaToHeight(_ targetAreaFraction: CGFloat) -> CGFloat {
        // For a circle, filling to height h doesn't fill h% of the area
        // We need to solve for h such that the circular segment area equals the target
        // Using Newton-Raphson approximation for efficiency

        guard targetAreaFraction > 0 else { return 0 }
        guard targetAreaFraction < 1 else { return 1 }

        // Binary search for the height that gives us the target area fraction
        var low: CGFloat = 0
        var high: CGFloat = 1
        let tolerance: CGFloat = 0.001

        for _ in 0..<20 { // Max 20 iterations
            let mid = (low + high) / 2
            let areaAtMid = circularSegmentAreaFraction(height: mid)

            if abs(areaAtMid - targetAreaFraction) < tolerance {
                return mid
            }

            if areaAtMid < targetAreaFraction {
                low = mid
            } else {
                high = mid
            }
        }

        return (low + high) / 2
    }

    /// Calculates what fraction of a circle's area is filled when filled to a given height (0-1)
    private func circularSegmentAreaFraction(height: CGFloat) -> CGFloat {
        // For a unit circle centered at (0, 0), water at height h from bottom
        // means water surface is at y = h - 1 (since circle goes from -1 to 1)
        // Area below y = circular segment area

        let h = height * 2 - 1 // Convert 0-1 height to -1 to 1 coordinate

        // Area of circular segment below height h for unit circle
        // A = (1/2) * (arccos(-h) - (-h) * sqrt(1 - h²))
        // Normalized to total circle area (π)

        let clampedH = max(-1, min(1, h))
        let theta = acos(-clampedH)
        let segmentArea = theta - (-clampedH) * sqrt(1 - clampedH * clampedH)

        return segmentArea / .pi
    }

    /// Interpolated color on a green-to-red gradient based on score (0-5)
    /// Provides instant emotional feedback: green = healthy, red = unhealthy
    private var liquidColor: Color {
        guard let score = score else {
            return Color(white: 0.5)
        }

        // Normalize score to 0-1 range
        let normalized = min(max(score / 5.0, 0), 1)

        // Green (healthy) to Red (unhealthy) gradient
        // Score 5.0 = vibrant green, Score 0.0 = deep red
        let red = 1.0 - normalized * 0.7      // 1.0 -> 0.3
        let green = 0.3 + normalized * 0.5    // 0.3 -> 0.8
        let blue = 0.3 + normalized * 0.15    // 0.3 -> 0.45

        return Color(red: red, green: green, blue: blue)
    }

    var body: some View {
        VStack(spacing: size * 0.08) {
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let liquidProgress = fillProgress * normalizedScore

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
                        progress: liquidProgress,
                        waveHeight: size * 0.035,
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
                        progress: liquidProgress,
                        waveHeight: size * 0.02,
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

                    // Bubbles effect
                    BubblesView(
                        time: time,
                        liquidProgress: liquidProgress,
                        color: liquidColor,
                        size: size
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
            // Skip animation and motion for small gauges to improve swipe performance
            if shouldAnimate {
                motionManager.start()
                withAnimation(.easeOut(duration: 1.0)) {
                    fillProgress = 1.0
                }
            } else {
                // Instant display for small gauges
                fillProgress = 1.0
            }
        }
        .onDisappear {
            if shouldAnimate {
                motionManager.stop()
            }
        }
    }
}

// MARK: - Bubbles View

struct BubblesView: View {
    let time: Double
    let liquidProgress: CGFloat
    let color: Color
    let size: CGFloat

    private let bubbleCount = 8

    var body: some View {
        Canvas { context, canvasSize in
            guard liquidProgress > 0.05 else { return }

            let liquidTop = canvasSize.height * (1.0 - liquidProgress)

            for i in 0..<bubbleCount {
                let seed = Double(i * 137 + 42)
                let cycleSpeed = 0.3 + fmod(seed * 0.1, 0.4)
                let cyclePosition = fmod(time * cycleSpeed + seed, 1.0)

                // Bubble rises from bottom to liquid surface
                let startY = canvasSize.height
                let endY = liquidTop + canvasSize.height * 0.05
                let y = startY - cyclePosition * (startY - endY)

                // Horizontal wobble
                let baseX = fmod(seed * 0.618, 1.0) * canvasSize.width * 0.7 + canvasSize.width * 0.15
                let wobble = sin(time * 3 + seed) * canvasSize.width * 0.03
                let x = baseX + wobble

                // Bubble size varies
                let bubbleSize = (2.0 + fmod(seed * 0.3, 3.0)) * (size / 120.0)

                // Fade in at bottom, fade out near surface
                let fadeIn = min(1.0, cyclePosition * 4)
                let fadeOut = min(1.0, (1.0 - cyclePosition) * 3)
                let opacity = fadeIn * fadeOut * 0.6

                let rect = CGRect(
                    x: x - bubbleSize / 2,
                    y: y - bubbleSize / 2,
                    width: bubbleSize,
                    height: bubbleSize
                )

                // Draw bubble with highlight
                context.opacity = opacity
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(0.7))
                )

                // Small highlight on bubble
                let highlightSize = bubbleSize * 0.3
                let highlightRect = CGRect(
                    x: x - bubbleSize * 0.2,
                    y: y - bubbleSize * 0.2,
                    width: highlightSize,
                    height: highlightSize
                )
                context.opacity = opacity * 0.8
                context.fill(
                    Path(ellipseIn: highlightRect),
                    with: .color(Color.white)
                )
            }
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
