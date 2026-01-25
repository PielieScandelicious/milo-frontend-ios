//
//  FlippableChartView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI

// MARK: - Spending Trend Line Chart
struct SpendingTrendLineChart: View {
    let trends: [TrendPeriod]
    let size: CGFloat
    let subtitle: String
    let totalAmount: Double
    let accentColor: Color
    var selectedPeriod: String? = nil  // e.g., "January 2026"

    @State private var animationProgress: CGFloat = 0
    @State private var selectedIndex: Int? = nil

    private let yAxisWidth: CGFloat = 32
    private let gridLineCount = 4

    private var sortedTrends: [TrendPeriod] {
        // Sort by date, oldest first
        trends.sorted { $0.periodStart < $1.periodStart }
    }

    private var visibleTrends: [TrendPeriod] {
        // If a period is selected, filter to show only periods up to and including it
        let filteredTrends: [TrendPeriod]
        if let selectedPeriod = selectedPeriod {
            filteredTrends = sortedTrends.filter { trend in
                comparePeriods(trend.period, selectedPeriod) <= 0
            }
        } else {
            filteredTrends = sortedTrends
        }
        return Array(filteredTrends.suffix(5))
    }

    /// Compare two period strings (e.g., "January 2026" vs "December 2025")
    /// Returns: negative if period1 < period2, 0 if equal, positive if period1 > period2
    private func comparePeriods(_ period1: String, _ period2: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")

        guard let date1 = formatter.date(from: period1),
              let date2 = formatter.date(from: period2) else {
            return 0
        }

        if date1 < date2 { return -1 }
        if date1 > date2 { return 1 }
        return 0
    }

    private var maxSpend: Double {
        let max = visibleTrends.map { $0.totalSpend }.max() ?? 1
        // Round up to a nice number
        return ceil(max / 50) * 50
    }

    private var minSpend: Double {
        let min = visibleTrends.map { $0.totalSpend }.min() ?? 0
        // Round down to a nice number
        return max(0, floor(min / 50) * 50)
    }

    private var spendRange: Double {
        max(maxSpend - minSpend, 1)
    }

    private var yAxisValues: [Double] {
        let step = spendRange / Double(gridLineCount)
        return (0...gridLineCount).map { minSpend + step * Double($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(yAxisValues.reversed(), id: \.self) { value in
                        Text(formatYAxisLabel(value))
                            .font(.system(size: size * 0.035, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(height: size * 0.55 / CGFloat(gridLineCount), alignment: .top)
                    }
                }
                .frame(width: yAxisWidth)

                // Chart area
                GeometryReader { geometry in
                    let chartWidth = geometry.size.width
                    let chartHeight = geometry.size.height

                    ZStack {
                        // Horizontal grid lines
                        ForEach(0...gridLineCount, id: \.self) { index in
                            let y = chartHeight * CGFloat(index) / CGFloat(gridLineCount)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: chartWidth, y: y))
                            }
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        // Gradient fill under the line
                        if visibleTrends.count > 1 {
                            Path { path in
                                let points = calculatePoints(width: chartWidth, height: chartHeight)
                                guard !points.isEmpty else { return }

                                path.move(to: CGPoint(x: points[0].x, y: chartHeight))
                                path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))

                                for i in 1..<points.count {
                                    let current = points[i]
                                    let previous = points[i - 1]
                                    let control1 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: previous.y
                                    )
                                    let control2 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: current.y
                                    )
                                    path.addCurve(to: current, control1: control1, control2: control2)
                                }

                                path.addLine(to: CGPoint(x: points[points.count - 1].x, y: chartHeight))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.3 * animationProgress),
                                        accentColor.opacity(0.05 * animationProgress)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }

                        // Line
                        if visibleTrends.count > 1 {
                            Path { path in
                                let points = calculatePoints(width: chartWidth, height: chartHeight)
                                guard !points.isEmpty else { return }

                                path.move(to: points[0])

                                for i in 1..<points.count {
                                    let current = points[i]
                                    let previous = points[i - 1]
                                    let control1 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: previous.y
                                    )
                                    let control2 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: current.y
                                    )
                                    path.addCurve(to: current, control1: control1, control2: control2)
                                }
                            }
                            .trim(from: 0, to: animationProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        }

                        // Data points
                        let points = calculatePoints(width: chartWidth, height: chartHeight)
                        ForEach(Array(visibleTrends.enumerated()), id: \.element.id) { index, trend in
                            if index < points.count {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(animationProgress)
                                    .position(points[index])
                            }
                        }
                    }
                }
                .frame(height: size * 0.55)
            }

            // Period labels
            if visibleTrends.count > 0 {
                HStack(spacing: 0) {
                    Spacer().frame(width: yAxisWidth + 4)
                    ForEach(Array(visibleTrends.enumerated()), id: \.element.id) { index, trend in
                        Text(formatPeriodLabel(trend.periodStart))
                            .font(.system(size: size * 0.045, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(width: size * 1.33, height: size * 1.09)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }

    private func calculatePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !visibleTrends.isEmpty else { return [] }

        let padding: CGFloat = 8
        let effectiveWidth = width - padding * 2
        let stepX = visibleTrends.count > 1 ? effectiveWidth / CGFloat(visibleTrends.count - 1) : effectiveWidth / 2

        return visibleTrends.enumerated().map { index, trend in
            let x = padding + (visibleTrends.count > 1 ? CGFloat(index) * stepX : effectiveWidth / 2)
            let normalizedY = (trend.totalSpend - minSpend) / spendRange
            let y = height - (CGFloat(normalizedY) * height)
            return CGPoint(x: x, y: y)
        }
    }

    private func formatYAxisLabel(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "€%.0fK", value / 1000)
        }
        return String(format: "€%.0f", value)
    }

    private func formatPeriodLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            return monthFormatter.string(from: date)
        }
        if let date = ISO8601DateFormatter().date(from: dateString) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            return monthFormatter.string(from: date)
        }
        return ""
    }
}

// MARK: - Store Spending Trend Line Chart (for individual stores)
struct StoreTrendLineChart: View {
    let trends: [TrendPeriod]
    let size: CGFloat
    let totalAmount: Double
    let accentColor: Color
    var selectedPeriod: String? = nil  // e.g., "January 2026"

    @State private var animationProgress: CGFloat = 0

    private let yAxisWidth: CGFloat = 32
    private let gridLineCount = 4

    private var sortedTrends: [TrendPeriod] {
        trends.sorted { $0.periodStart < $1.periodStart }
    }

    private var visibleTrends: [TrendPeriod] {
        // If a period is selected, filter to show only periods up to and including it
        let filteredTrends: [TrendPeriod]
        if let selectedPeriod = selectedPeriod {
            filteredTrends = sortedTrends.filter { trend in
                comparePeriods(trend.period, selectedPeriod) <= 0
            }
        } else {
            filteredTrends = sortedTrends
        }
        return Array(filteredTrends.suffix(5))
    }

    /// Compare two period strings (e.g., "January 2026" vs "December 2025")
    private func comparePeriods(_ period1: String, _ period2: String) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "en_US")

        guard let date1 = formatter.date(from: period1),
              let date2 = formatter.date(from: period2) else {
            return 0
        }

        if date1 < date2 { return -1 }
        if date1 > date2 { return 1 }
        return 0
    }

    private var maxSpend: Double {
        let max = visibleTrends.map { $0.totalSpend }.max() ?? 1
        return ceil(max / 50) * 50
    }

    private var minSpend: Double {
        let min = visibleTrends.map { $0.totalSpend }.min() ?? 0
        return max(0, floor(min / 50) * 50)
    }

    private var spendRange: Double {
        max(maxSpend - minSpend, 1)
    }

    private var yAxisValues: [Double] {
        let step = spendRange / Double(gridLineCount)
        return (0...gridLineCount).map { minSpend + step * Double($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                // Y-axis labels
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(yAxisValues.reversed(), id: \.self) { value in
                        Text(formatYAxisLabel(value))
                            .font(.system(size: size * 0.04, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(height: size * 0.7 / CGFloat(gridLineCount), alignment: .top)
                    }
                }
                .frame(width: yAxisWidth)

                // Chart area
                GeometryReader { geometry in
                    let chartWidth = geometry.size.width
                    let chartHeight = geometry.size.height

                    ZStack {
                        // Horizontal grid lines
                        ForEach(0...gridLineCount, id: \.self) { index in
                            let y = chartHeight * CGFloat(index) / CGFloat(gridLineCount)
                            Path { path in
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: chartWidth, y: y))
                            }
                            .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }

                        // Gradient fill under the line
                        if visibleTrends.count > 1 {
                            Path { path in
                                let points = calculatePoints(width: chartWidth, height: chartHeight)
                                guard !points.isEmpty else { return }

                                path.move(to: CGPoint(x: points[0].x, y: chartHeight))
                                path.addLine(to: CGPoint(x: points[0].x, y: points[0].y))

                                for i in 1..<points.count {
                                    let current = points[i]
                                    let previous = points[i - 1]
                                    let control1 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: previous.y
                                    )
                                    let control2 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: current.y
                                    )
                                    path.addCurve(to: current, control1: control1, control2: control2)
                                }

                                path.addLine(to: CGPoint(x: points[points.count - 1].x, y: chartHeight))
                                path.closeSubpath()
                            }
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accentColor.opacity(0.3 * animationProgress),
                                        accentColor.opacity(0.05 * animationProgress)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }

                        // Line
                        if visibleTrends.count > 1 {
                            Path { path in
                                let points = calculatePoints(width: chartWidth, height: chartHeight)
                                guard !points.isEmpty else { return }

                                path.move(to: points[0])

                                for i in 1..<points.count {
                                    let current = points[i]
                                    let previous = points[i - 1]
                                    let control1 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: previous.y
                                    )
                                    let control2 = CGPoint(
                                        x: previous.x + (current.x - previous.x) * 0.5,
                                        y: current.y
                                    )
                                    path.addCurve(to: current, control1: control1, control2: control2)
                                }
                            }
                            .trim(from: 0, to: animationProgress)
                            .stroke(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(0.7)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                            )
                        }

                        // Data points
                        let points = calculatePoints(width: chartWidth, height: chartHeight)
                        ForEach(Array(visibleTrends.enumerated()), id: \.element.id) { index, trend in
                            if index < points.count {
                                Circle()
                                    .fill(accentColor)
                                    .frame(width: 6, height: 6)
                                    .scaleEffect(animationProgress)
                                    .position(points[index])
                            }
                        }
                    }
                }
                .frame(height: size * 0.7)
            }

            // Period labels
            if visibleTrends.count > 0 {
                HStack(spacing: 0) {
                    Spacer().frame(width: yAxisWidth + 4)
                    ForEach(Array(visibleTrends.enumerated()), id: \.element.id) { index, trend in
                        Text(formatPeriodLabel(trend.periodStart))
                            .font(.system(size: size * 0.045, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(width: size * 1.33, height: size * 1.09)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }

    private func calculatePoints(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard !visibleTrends.isEmpty else { return [] }

        let padding: CGFloat = 8
        let effectiveWidth = width - padding * 2
        let stepX = visibleTrends.count > 1 ? effectiveWidth / CGFloat(visibleTrends.count - 1) : effectiveWidth / 2

        return visibleTrends.enumerated().map { index, trend in
            let x = padding + (visibleTrends.count > 1 ? CGFloat(index) * stepX : effectiveWidth / 2)
            let normalizedY = (trend.totalSpend - minSpend) / spendRange
            let y = height - (CGFloat(normalizedY) * height)
            return CGPoint(x: x, y: y)
        }
    }

    private func formatYAxisLabel(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "€%.0fK", value / 1000)
        }
        return String(format: "€%.0f", value)
    }

    private func formatPeriodLabel(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            return monthFormatter.string(from: date)
        }
        if let date = ISO8601DateFormatter().date(from: dateString) {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "MMM"
            return monthFormatter.string(from: date)
        }
        return ""
    }
}

// MARK: - Flippable Donut Chart View
struct FlippableDonutChartView: View {
    let title: String
    let subtitle: String
    let totalAmount: Double
    let segments: [ChartSegment]
    let size: CGFloat
    var trends: [TrendPeriod] = []
    var accentColor: Color = Color(red: 0.95, green: 0.25, blue: 0.3) // Modern red
    var selectedPeriod: String? = nil  // e.g., "January 2026"

    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0

    /// Convert ChartSegments to ChartData for IconDonutChartView
    private var chartData: [ChartData] {
        segments.map { segment in
            // Get icon from AnalyticsCategory if available
            let icon = AnalyticsCategory.allCases
                .first { $0.displayName == segment.label }?.icon ?? "shippingbox.fill"

            return ChartData(
                value: segment.value,
                color: segment.color,
                iconName: icon,
                label: segment.label
            )
        }
    }

    var body: some View {
        ZStack {
            // Back side - Spending Trend Line Chart
            SpendingTrendLineChart(
                trends: trends,
                size: size,
                subtitle: subtitle,
                totalAmount: totalAmount,
                accentColor: accentColor,
                selectedPeriod: selectedPeriod
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(180),
                axis: (x: 0, y: 1, z: 0)
            )

            // Front side - Icon Donut Chart
            IconDonutChartView(
                data: chartData,
                totalAmount: totalAmount,
                size: size,
                currencySymbol: subtitle == "visits" ? "" : "€",
                subtitle: subtitle == "visits" ? "visits" : nil
            )
            .opacity(isFlipped ? 0 : 1)
        }
        .frame(width: size * 1.33, height: size * 1.09)
        .contentShape(Rectangle())
        .rotation3DEffect(
            .degrees(flipDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
                flipDegrees += 180
            }
        }
    }
}

// MARK: - Flippable All Stores Chart View
struct FlippableAllStoresChartView: View {
    let totalAmount: Double
    let segments: [StoreChartSegment]
    let size: CGFloat
    var trends: [TrendPeriod] = []
    var accentColor: Color = Color(red: 0.95, green: 0.25, blue: 0.3) // Modern red
    var selectedPeriod: String? = nil  // e.g., "January 2026"

    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0

    /// Convert StoreChartSegments to ChartData for IconDonutChartView
    private var chartData: [ChartData] {
        segments.toIconChartData()
    }

    var body: some View {
        ZStack {
            // Back side - Spending Trend Line Chart
            StoreTrendLineChart(
                trends: trends,
                size: size,
                totalAmount: totalAmount,
                accentColor: accentColor,
                selectedPeriod: selectedPeriod
            )
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(180),
                axis: (x: 0, y: 1, z: 0)
            )

            // Front side - Icon Donut Chart
            IconDonutChartView(
                data: chartData,
                totalAmount: totalAmount,
                size: size,
                currencySymbol: "€"
            )
            .opacity(isFlipped ? 0 : 1)
        }
        .frame(width: size * 1.33, height: size * 1.09)
        .contentShape(Rectangle())
        .rotation3DEffect(
            .degrees(flipDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isFlipped.toggle()
                flipDegrees += 180
            }
        }
    }
}

// MARK: - Preview
#Preview("Flippable Chart") {
    ZStack {
        Color(white: 0.05).ignoresSafeArea()

        VStack(spacing: 40) {
            FlippableDonutChartView(
                title: "COLRUYT",
                subtitle: "visits",
                totalAmount: 15,
                segments: [
                    ChartSegment(startAngle: .degrees(0), endAngle: .degrees(120), color: .green, value: 65.40, label: "Meat & Fish", percentage: 34),
                    ChartSegment(startAngle: .degrees(120), endAngle: .degrees(200), color: .purple, value: 42.50, label: "Alcohol", percentage: 22),
                    ChartSegment(startAngle: .degrees(200), endAngle: .degrees(255), color: .orange, value: 28.00, label: "Drinks", percentage: 15),
                    ChartSegment(startAngle: .degrees(255), endAngle: .degrees(320), color: .blue, value: 35.00, label: "Household", percentage: 18),
                    ChartSegment(startAngle: .degrees(320), endAngle: .degrees(360), color: .pink, value: 19.00, label: "Snacks", percentage: 11)
                ],
                size: 220
            )

            Text("Tap to flip")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    .preferredColorScheme(.dark)
}
