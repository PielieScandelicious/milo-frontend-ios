//
//  IconDonutChartView.swift
//  Scandalicious
//
//  A reusable donut chart with pill-shaped segments and gaps
//

import SwiftUI

// MARK: - Data Model

struct ChartData: Identifiable {
    let id = UUID()
    let value: Double
    let color: Color
    let iconName: String
    let label: String

    init(value: Double, color: Color, iconName: String = "", label: String = "") {
        self.value = value
        self.color = color
        self.iconName = iconName
        self.label = label
    }
}

// MARK: - Icon Donut Chart View

struct IconDonutChartView: View {
    let data: [ChartData]
    let totalAmount: Double
    let size: CGFloat
    let currencySymbol: String
    let subtitle: String?

    /// Visual gap between segments in degrees (the actual empty space you see)
    private let visualGapDegrees: Double = 4.0
    /// Stroke width as proportion of size (thicker pills)
    private let strokeWidthRatio: CGFloat = 0.12

    @State private var animationTrigger: Bool = false

    /// Unique identifier to track data changes and trigger re-animation
    private var dataFingerprint: String {
        data.map { "\($0.value)" }.joined(separator: "-")
    }

    /// Skip animation for small charts (store cards) to improve swipe performance
    private var shouldAnimate: Bool {
        size > 120
    }

    init(data: [ChartData], totalAmount: Double? = nil, size: CGFloat = 220, currencySymbol: String = "$", subtitle: String? = nil) {
        self.data = data
        self.totalAmount = totalAmount ?? data.reduce(0) { $0 + $1.value }
        self.size = size
        self.currencySymbol = currencySymbol
        self.subtitle = subtitle
    }

    private var strokeWidth: CGFloat {
        size * strokeWidthRatio
    }

    private var ringRadius: CGFloat {
        (size - strokeWidth) / 2
    }

    /// Calculate the cap extension in degrees (round lineCap extends by strokeWidth/2 on each end)
    private var capExtensionDegrees: Double {
        // Arc length = radius * angle(radians), so angle = arcLength / radius
        // Cap extends by strokeWidth/2, convert to degrees
        let capLength = Double(strokeWidth) / 2.0
        let radiansPerCap = capLength / Double(ringRadius)
        return radiansPerCap * 180.0 / .pi
    }

    /// Total gap needed in arc degrees to achieve the visual gap (accounting for round caps)
    private var effectiveGapDegrees: Double {
        // Each segment's round cap extends into the gap, so we need extra space
        // Two adjacent caps (one from each segment) extend into the gap
        visualGapDegrees + (2 * capExtensionDegrees)
    }

    /// Calculate segments with gaps that account for round cap extensions
    private var segments: [SegmentInfo] {
        guard !data.isEmpty else { return [] }

        let totalValue = data.reduce(0) { $0 + $1.value }
        guard totalValue > 0 else { return [] }

        // Total gap space needed (accounting for cap extensions)
        let totalGapDegrees = effectiveGapDegrees * Double(data.count)
        let availableDegrees = 360.0 - totalGapDegrees

        var segments: [SegmentInfo] = []
        var currentAngle: Double = 0 // Start from top (will rotate by -90 in view)

        for item in data {
            let proportion = item.value / totalValue
            let segmentDegrees = availableDegrees * proportion

            let startAngle = currentAngle + effectiveGapDegrees / 2
            let endAngle = startAngle + segmentDegrees
            let midAngle = (startAngle + endAngle) / 2

            segments.append(SegmentInfo(
                data: item,
                startAngle: startAngle,
                endAngle: endAngle,
                midAngle: midAngle
            ))

            currentAngle = endAngle + effectiveGapDegrees / 2
        }

        return segments
    }

    var body: some View {
        ZStack {
            // Donut segments - each appears one by one with staggered animation
            ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
                ExpandingArcSegment(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    color: segment.data.color,
                    lineWidth: strokeWidth,
                    frameSize: size - strokeWidth,
                    index: index,
                    isAnimating: animationTrigger
                )
            }

            // Center content (doesn't scale - stays in place)
            centerContent
        }
        .frame(width: size, height: size)
        .onAppear {
            if shouldAnimate {
                // Trigger animation on appear
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    animationTrigger = true
                }
            } else {
                animationTrigger = true
            }
        }
        .onChange(of: dataFingerprint) { _, _ in
            // Re-animate when data changes (e.g., period switch)
            if shouldAnimate {
                // Reset and re-trigger animation
                animationTrigger = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    animationTrigger = true
                }
            }
        }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        VStack(spacing: 2) {
            Text("\(currencySymbol)\(formattedTotal)")
                .font(.system(size: size * 0.20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: formattedTotal)

            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitleText)
                    .font(.system(size: size * 0.07, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .frame(maxWidth: size * 0.55) // Keep text within inner circle
    }

    private var subtitleText: String {
        guard let subtitle = subtitle else { return "" }
        // Handle singular/plural for "visits" and "receipts"
        if Int(totalAmount) == 1 {
            if subtitle == "visits" { return "visit" }
            if subtitle == "receipts" { return "receipt" }
        }
        return subtitle
    }

    private var formattedTotal: String {
        if totalAmount >= 1000 {
            return String(format: "%.0fK", totalAmount / 1000)
        } else {
            return String(format: "%.0f", totalAmount)
        }
    }
}

// MARK: - Segment Info

private struct SegmentInfo: Identifiable {
    let id = UUID()
    let data: ChartData
    let startAngle: Double
    let endAngle: Double
    let midAngle: Double
}

// MARK: - Expanding Arc Segment (with staggered animation)

private struct ExpandingArcSegment: View {
    let startAngle: Double
    let endAngle: Double
    let color: Color
    let lineWidth: CGFloat
    let frameSize: CGFloat
    let index: Int
    let isAnimating: Bool

    @State private var scale: CGFloat = 0.3
    @State private var progress: CGFloat = 0
    @State private var opacity: CGFloat = 0

    private var delay: Double {
        Double(index) * 0.15 // Stagger delay per segment
    }

    var body: some View {
        let startFraction = startAngle / 360.0
        let endFraction = endAngle / 360.0
        let animatedEndFraction = startFraction + (endFraction - startFraction) * progress

        Circle()
            .trim(from: startFraction, to: animatedEndFraction)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .frame(width: frameSize, height: frameSize)
            .scaleEffect(scale)
            .opacity(opacity)
            .rotationEffect(.degrees(-90)) // Start from top
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    // Animate in with delay
                    withAnimation(Animation.spring(response: 0.7, dampingFraction: 0.75).delay(delay)) {
                        scale = 1.0
                        progress = 1.0
                        opacity = 1.0
                    }
                } else {
                    // Reset immediately without animation
                    scale = 0.3
                    progress = 0
                    opacity = 0
                }
            }
            .onAppear {
                if isAnimating {
                    // If already animating on appear, trigger animation
                    withAnimation(Animation.spring(response: 0.7, dampingFraction: 0.75).delay(delay)) {
                        scale = 1.0
                        progress = 1.0
                        opacity = 1.0
                    }
                }
            }
    }
}

// MARK: - Donut Arc Segment (legacy, kept for reference)

private struct DonutArcSegment: View {
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let lineWidth: CGFloat
    let animationProgress: CGFloat

    var body: some View {
        let startFraction = startAngle.degrees / 360.0
        let endFraction = endAngle.degrees / 360.0
        let animatedEndFraction = startFraction + (endFraction - startFraction) * animationProgress

        Circle()
            .trim(from: startFraction, to: animatedEndFraction)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: lineWidth,
                    lineCap: .round
                )
            )
            .rotationEffect(.degrees(-90)) // Start from top
    }
}

// MARK: - Preview

#Preview("Pill Donut Chart") {
    ZStack {
        Color.black.ignoresSafeArea()

        IconDonutChartView(
            data: [
                ChartData(value: 450, color: .cyan, label: "Meat & Fish"),
                ChartData(value: 280, color: .green, label: "Fresh Produce"),
                ChartData(value: 180, color: .purple, label: "Alcohol"),
                ChartData(value: 150, color: .orange, label: "Pantry"),
                ChartData(value: 120, color: .pink, label: "Drinks")
            ],
            size: 220,
            currencySymbol: "$"
        )
    }
}

#Preview("Pill Donut Chart - Euro") {
    ZStack {
        Color(white: 0.1).ignoresSafeArea()

        IconDonutChartView(
            data: [
                ChartData(value: 89.50, color: .cyan),
                ChartData(value: 67.25, color: .green),
                ChartData(value: 45.00, color: .purple),
                ChartData(value: 38.75, color: .orange)
            ],
            size: 200,
            currencySymbol: "€"
        )
    }
}

// MARK: - CategoryBreakdown Extension

extension Array where Element == CategoryBreakdown {
    /// Convert CategoryBreakdown array to ChartData for IconDonutChartView
    func toIconChartData() -> [ChartData] {
        return map { category in
            ChartData(
                value: category.spent,
                color: category.name.categoryColor,
                iconName: category.icon,
                label: category.name
            )
        }
    }
}

// MARK: - Category Extension (for StoreBreakdown.categories)

extension Array where Element == Category {
    /// Convert Category array to ChartData for IconDonutChartView
    func toIconChartData() -> [ChartData] {
        return map { category in
            // Get icon from AnalyticsCategory if available
            let icon = AnalyticsCategory.allCases
                .first { $0.displayName == category.name }?.icon ?? "shippingbox.fill"

            return ChartData(
                value: category.spent,
                color: category.name.categoryColor,
                iconName: icon,
                label: category.name
            )
        }
    }
}

// MARK: - StoreChartSegment Extension

extension Array where Element == StoreChartSegment {
    /// Convert StoreChartSegment array to ChartData for IconDonutChartView
    func toIconChartData() -> [ChartData] {
        return map { segment in
            ChartData(
                value: segment.amount,
                color: segment.color,
                iconName: "cart.fill",
                label: segment.storeName
            )
        }
    }
}
