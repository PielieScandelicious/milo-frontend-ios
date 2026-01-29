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
    let totalItems: Int?

    /// Visual gap between segments in degrees (the actual empty space you see)
    private let visualGapDegrees: Double = 4.0
    /// Stroke width as proportion of size
    private let strokeWidthRatio: CGFloat = 0.08

    @State private var globalScale: CGFloat = 0.6
    @State private var globalRotation: Double = -90 // Quarter turn back

    /// Unique identifier to track data changes and trigger re-animation
    private var dataFingerprint: String {
        data.map { "\($0.value)" }.joined(separator: "-")
    }

    /// Skip animation for small charts (store cards) to improve swipe performance
    private var shouldAnimate: Bool {
        size > 120
    }

    init(data: [ChartData], totalAmount: Double? = nil, size: CGFloat = 220, currencySymbol: String = "$", subtitle: String? = nil, totalItems: Int? = nil) {
        self.data = data
        self.totalAmount = totalAmount ?? data.reduce(0) { $0 + $1.value }
        self.size = size
        self.currencySymbol = currencySymbol
        self.subtitle = subtitle
        self.totalItems = totalItems
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
            // All segments visible, rotate and scale together
            ZStack {
                ForEach(segments) { segment in
                    // Subtle outer glow for depth
                    Circle()
                        .trim(from: segment.startAngle / 360.0, to: segment.endAngle / 360.0)
                        .stroke(
                            segment.data.color.opacity(0.25),
                            style: StrokeStyle(
                                lineWidth: strokeWidth + 3,
                                lineCap: .round
                            )
                        )
                        .blur(radius: 2)
                        .frame(width: size - strokeWidth, height: size - strokeWidth)

                    // Main segment with gradient
                    Circle()
                        .trim(from: segment.startAngle / 360.0, to: segment.endAngle / 360.0)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    segment.data.color.opacity(1.0),
                                    segment.data.color.opacity(0.7)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .round
                            )
                        )
                        .frame(width: size - strokeWidth, height: size - strokeWidth)

                    // Inner highlight for glass effect
                    Circle()
                        .trim(from: segment.startAngle / 360.0, to: segment.endAngle / 360.0)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.4),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .center
                            ),
                            style: StrokeStyle(
                                lineWidth: strokeWidth * 0.5,
                                lineCap: .round
                            )
                        )
                        .frame(width: size - strokeWidth, height: size - strokeWidth)
                }
            }
            .scaleEffect(globalScale)
            .rotationEffect(.degrees(-90 + globalRotation)) // -90 starts from top

            // Center content (doesn't scale - stays in place)
            centerContent
        }
        .frame(width: size, height: size)
        .onAppear {
            if shouldAnimate {
                // Start animation immediately for snappier feel
                withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                    globalScale = 1.0
                    globalRotation = 0
                }
            } else {
                globalScale = 1.0
                globalRotation = 0
            }
        }
        .onChange(of: dataFingerprint) { _, _ in
            // Re-animate when data changes (e.g., period switch)
            if shouldAnimate {
                // Reset to starting position
                globalScale = 0.6
                globalRotation = -90

                // Expand and rotate to final position
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                        globalScale = 1.0
                        globalRotation = 0
                    }
                }
            }
        }
    }

    // MARK: - Center Content

    private var centerContent: some View {
        ZStack {
            // Subtle gradient background circle
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.02)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.32
                    )
                )
                .frame(width: size * 0.58, height: size * 0.58)

            // Display items count if available, otherwise show stores
            if let items = totalItems {
                // Items count with cart icon
                VStack(spacing: 2) {
                    Image(systemName: "cart.fill")
                        .font(.system(size: size * 0.14, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("\(items)")
                        .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: items)

                    Text("items purchased")
                        .font(.system(size: size * 0.045, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            } else {
                // Fallback: Store icon with store count
                VStack(spacing: 4) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: size * 0.18, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.9),
                                    Color.white.opacity(0.6)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("\(data.count)")
                        .font(.system(size: size * 0.09, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                    +
                    Text(" stores")
                        .font(.system(size: size * 0.055, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .frame(maxWidth: size * 0.55)
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
