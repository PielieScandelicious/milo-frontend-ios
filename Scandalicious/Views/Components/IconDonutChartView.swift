//
//  IconDonutChartView.swift
//  Scandalicious
//
//  A reusable donut chart with pill-shaped segments and gaps
//

import SwiftUI

// MARK: - Data Model

struct ChartData: Identifiable {
    // Use label as stable ID - prevents SwiftUI animation issues when chart data is recomputed
    var id: String { label }
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
    let averageItemPrice: Double?
    let centerIcon: String?
    let centerLabel: String?

    /// Visual gap between segments in degrees (the actual empty space you see)
    private let visualGapDegrees: Double = 4.0
    /// Stroke width as proportion of size
    private let strokeWidthRatio: CGFloat = 0.08

    @State private var globalScale: CGFloat = 0.6
    @State private var globalRotation: Double = -90 // Quarter turn back
    @State private var selectedSegmentIndex: Int? = nil

    /// Unique identifier to track data changes and trigger re-animation
    private var dataFingerprint: String {
        data.map { "\($0.value)" }.joined(separator: "-")
    }

    /// Skip animation for small charts (store cards) to improve swipe performance
    private var shouldAnimate: Bool {
        size > 120
    }

    init(data: [ChartData], totalAmount: Double? = nil, size: CGFloat = 220, currencySymbol: String = "$", subtitle: String? = nil, totalItems: Int? = nil, averageItemPrice: Double? = nil, centerIcon: String? = nil, centerLabel: String? = nil) {
        self.data = data
        self.totalAmount = totalAmount ?? data.reduce(0) { $0 + $1.value }
        self.size = size
        self.currencySymbol = currencySymbol
        self.subtitle = subtitle
        self.totalItems = totalItems
        self.averageItemPrice = averageItemPrice
        self.centerIcon = centerIcon
        self.centerLabel = centerLabel
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

    /// Check if a segment at index is currently selected
    private func isSelected(_ index: Int) -> Bool {
        selectedSegmentIndex == index
    }

    /// Get the selected segment info
    private var selectedSegment: SegmentInfo? {
        guard let index = selectedSegmentIndex, index < segments.count else { return nil }
        return segments[index]
    }

    /// Calculate percentage for a segment
    private func percentage(for segment: SegmentInfo) -> Int {
        let total = data.reduce(0) { $0 + $1.value }
        guard total > 0 else { return 0 }
        return Int((segment.data.value / total) * 100)
    }

    var body: some View {
        ZStack {
            // All segments visible, rotate and scale together
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                    // Segment - clean, solid color
                    Circle()
                        .trim(from: segment.startAngle / 360.0, to: segment.endAngle / 360.0)
                        .stroke(
                            segment.data.color,
                            style: StrokeStyle(
                                lineWidth: strokeWidth,
                                lineCap: .round
                            )
                        )
                        .frame(width: size - strokeWidth, height: size - strokeWidth)
                    .scaleEffect(isSelected(index) ? 1.08 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSegmentIndex)
                    // Overlay invisible tap target with proper arc shape
                    .overlay(
                        ArcSegmentShape(
                            startAngle: segment.startAngle,
                            endAngle: segment.endAngle,
                            innerRadius: (size - strokeWidth) / 2 - strokeWidth,
                            outerRadius: (size - strokeWidth) / 2 + strokeWidth
                        )
                        .fill(Color.white.opacity(0.001)) // Nearly invisible but tappable
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if selectedSegmentIndex == index {
                                    selectedSegmentIndex = nil
                                } else {
                                    selectedSegmentIndex = index
                                }
                            }
                        }
                    )
                }
            }
            .scaleEffect(globalScale)
            .rotationEffect(.degrees(-90 + globalRotation)) // -90 starts from top

            // Center content - shows segment info when selected, otherwise default
            if let selected = selectedSegment {
                selectedSegmentContent(selected)
            } else {
                centerContent
            }
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
            // Clear selection when data changes
            selectedSegmentIndex = nil

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
        .onDisappear {
            // Reset animation state so it plays again on next appearance
            if shouldAnimate {
                globalScale = 0.6
                globalRotation = -90
                selectedSegmentIndex = nil
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

            // Custom center icon and label (highest priority)
            if let icon = centerIcon, let label = centerLabel {
                VStack(spacing: 6) {
                    // Icon with gradient styling
                    Image(systemName: icon)
                        .font(.system(size: size * 0.18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.95),
                                    Color.white.opacity(0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text(label)
                        .font(.system(size: size * 0.07, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .tracking(0.3)
                }
            }
            // Display average item price if available
            else if let avgPrice = averageItemPrice, avgPrice > 0 {
                // Average item price display
                VStack(spacing: 2) {
                    Text("AVG PRICE")
                        .font(.system(size: size * 0.045, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.4))
                        .lineLimit(1)

                    Text(String(format: "€%.2f", avgPrice))
                        .font(.system(size: size * 0.14, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("per item")
                        .font(.system(size: size * 0.05, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                        .lineLimit(1)
                }
            } else if let items = totalItems {
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
            }
        }
        .frame(maxWidth: size * 0.55)
    }

    // MARK: - Selected Segment Content

    private func selectedSegmentContent(_ segment: SegmentInfo) -> some View {
        ZStack {
            // Background circle with segment color tint
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            segment.data.color.opacity(0.15),
                            segment.data.color.opacity(0.05)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.32
                    )
                )
                .frame(width: size * 0.58, height: size * 0.58)

            VStack(spacing: 4) {
                // Store/category name
                Text(segment.data.label.localizedCapitalized)
                    .font(.system(size: size * 0.07, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                // Amount
                Text(String(format: "€%.0f", segment.data.value))
                    .font(.system(size: size * 0.11, weight: .heavy, design: .rounded))
                    .foregroundColor(segment.data.color)

                // Percentage
                Text("\(percentage(for: segment))% of total")
                    .font(.system(size: size * 0.045, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

            }
        }
        .frame(maxWidth: size * 0.55)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedSegmentIndex = nil
            }
        }
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
    let id: String  // Use the ChartData's id for stability
    let data: ChartData
    let startAngle: Double
    let endAngle: Double
    let midAngle: Double

    init(data: ChartData, startAngle: Double, endAngle: Double, midAngle: Double) {
        self.id = data.id  // Use ChartData's stable id (label-based)
        self.data = data
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.midAngle = midAngle
    }
}

// MARK: - Arc Segment Shape (for hit testing)

private struct ArcSegmentShape: Shape {
    let startAngle: Double
    let endAngle: Double
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()

        // No offset here - the parent view already applies -90 rotation
        let start = Angle(degrees: startAngle)
        let end = Angle(degrees: endAngle)

        // Outer arc
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)

        // Inner arc (reverse direction)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)

        path.closeSubpath()

        return path
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
