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
    var isVisible: Bool = true  // Whether chart is currently visible (for scroll triggering)

    @State private var animationProgress: CGFloat = 0

    private let yAxisWidth: CGFloat = 32
    private let gridLineCount = 4
    private let periodWidth: CGFloat = 50  // Width per period in scrollable area

    private var sortedTrends: [TrendPeriod] {
        // Sort by date, oldest first
        trends.sorted { $0.periodStart < $1.periodStart }
    }

    /// All periods from oldest to newest
    private var allPeriods: [TrendPeriod] {
        sortedTrends
    }

    /// Index of the selected period in allPeriods
    private var selectedPeriodIndex: Int {
        guard let selectedPeriod = selectedPeriod else {
            return allPeriods.count - 1
        }
        return allPeriods.firstIndex { $0.period == selectedPeriod } ?? allPeriods.count - 1
    }

    private var maxSpend: Double {
        let max = allPeriods.map { $0.totalSpend }.max() ?? 1
        // Round up to a nice number
        return ceil(max / 50) * 50
    }

    private var minSpend: Double {
        let min = allPeriods.map { $0.totalSpend }.min() ?? 0
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

                // Scrollable chart area
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(allPeriods.enumerated()), id: \.element.id) { index, trend in
                                periodColumn(index: index, trend: trend)
                                    .frame(width: periodWidth)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.trailing)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(selectedPeriodIndex, anchor: .trailing)
                        }
                    }
                    .onChange(of: isVisible) { _, visible in
                        if visible {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(selectedPeriodIndex, anchor: .trailing)
                            }
                        }
                    }
                    .onChange(of: selectedPeriod) { _, _ in
                        withAnimation {
                            proxy.scrollTo(selectedPeriodIndex, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(width: size * 1.33, height: size * 1.09)
        .clipped()
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private func periodColumn(index: Int, trend: TrendPeriod) -> some View {
        let chartHeight = size * 0.55
        let normalizedY = spendRange > 0 ? (trend.totalSpend - minSpend) / spendRange : 0.5
        let yPosition = chartHeight - (CGFloat(normalizedY) * chartHeight)

        VStack(spacing: 0) {
            // Chart area for this period
            ZStack {
                // Data point
                Circle()
                    .fill(index == selectedPeriodIndex ? accentColor : accentColor.opacity(0.7))
                    .frame(width: index == selectedPeriodIndex ? 8 : 6, height: index == selectedPeriodIndex ? 8 : 6)
                    .scaleEffect(animationProgress)
                    .position(x: periodWidth / 2, y: yPosition)

                // Line to next point (if not last)
                if index < allPeriods.count - 1 {
                    let nextTrend = allPeriods[index + 1]
                    let nextNormalizedY = spendRange > 0 ? (nextTrend.totalSpend - minSpend) / spendRange : 0.5
                    let nextYPosition = chartHeight - (CGFloat(nextNormalizedY) * chartHeight)

                    Path { path in
                        path.move(to: CGPoint(x: periodWidth / 2, y: yPosition))
                        let control1 = CGPoint(x: periodWidth, y: yPosition)
                        let control2 = CGPoint(x: periodWidth, y: nextYPosition)
                        path.addCurve(to: CGPoint(x: periodWidth + periodWidth / 2, y: nextYPosition),
                                      control1: control1, control2: control2)
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
            }
            .frame(height: chartHeight)

            // Period label
            Text(formatPeriodLabel(trend.periodStart))
                .font(.system(size: size * 0.045, weight: index == selectedPeriodIndex ? .bold : .medium))
                .foregroundColor(index == selectedPeriodIndex ? .white.opacity(0.8) : .white.opacity(0.5))
                .frame(height: 20)
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
    var isVisible: Bool = true  // Whether chart is currently visible (for scroll triggering)

    @State private var animationProgress: CGFloat = 0

    private let yAxisWidth: CGFloat = 32
    private let gridLineCount = 4
    private let periodWidth: CGFloat = 50  // Width per period in scrollable area

    private var sortedTrends: [TrendPeriod] {
        trends.sorted { $0.periodStart < $1.periodStart }
    }

    /// All periods from oldest to newest
    private var allPeriods: [TrendPeriod] {
        sortedTrends
    }

    /// Index of the selected period in allPeriods
    private var selectedPeriodIndex: Int {
        guard let selectedPeriod = selectedPeriod else {
            return allPeriods.count - 1
        }
        return allPeriods.firstIndex { $0.period == selectedPeriod } ?? allPeriods.count - 1
    }

    private var maxSpend: Double {
        let max = allPeriods.map { $0.totalSpend }.max() ?? 1
        return ceil(max / 50) * 50
    }

    private var minSpend: Double {
        let min = allPeriods.map { $0.totalSpend }.min() ?? 0
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

                // Scrollable chart area
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(allPeriods.enumerated()), id: \.element.id) { index, trend in
                                periodColumn(index: index, trend: trend)
                                    .frame(width: periodWidth)
                                    .id(index)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollBounceBehavior(.basedOnSize)
                    .defaultScrollAnchor(.trailing)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            proxy.scrollTo(selectedPeriodIndex, anchor: .trailing)
                        }
                    }
                    .onChange(of: isVisible) { _, visible in
                        if visible {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                proxy.scrollTo(selectedPeriodIndex, anchor: .trailing)
                            }
                        }
                    }
                    .onChange(of: selectedPeriod) { _, _ in
                        withAnimation {
                            proxy.scrollTo(selectedPeriodIndex, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(width: size * 1.33, height: size * 1.09)
        .clipped()
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private func periodColumn(index: Int, trend: TrendPeriod) -> some View {
        let chartHeight = size * 0.7
        let normalizedY = spendRange > 0 ? (trend.totalSpend - minSpend) / spendRange : 0.5
        let yPosition = chartHeight - (CGFloat(normalizedY) * chartHeight)

        VStack(spacing: 0) {
            // Chart area for this period
            ZStack {
                // Data point
                Circle()
                    .fill(index == selectedPeriodIndex ? accentColor : accentColor.opacity(0.7))
                    .frame(width: index == selectedPeriodIndex ? 8 : 6, height: index == selectedPeriodIndex ? 8 : 6)
                    .scaleEffect(animationProgress)
                    .position(x: periodWidth / 2, y: yPosition)

                // Line to next point (if not last)
                if index < allPeriods.count - 1 {
                    let nextTrend = allPeriods[index + 1]
                    let nextNormalizedY = spendRange > 0 ? (nextTrend.totalSpend - minSpend) / spendRange : 0.5
                    let nextYPosition = chartHeight - (CGFloat(nextNormalizedY) * chartHeight)

                    Path { path in
                        path.move(to: CGPoint(x: periodWidth / 2, y: yPosition))
                        let control1 = CGPoint(x: periodWidth, y: yPosition)
                        let control2 = CGPoint(x: periodWidth, y: nextYPosition)
                        path.addCurve(to: CGPoint(x: periodWidth + periodWidth / 2, y: nextYPosition),
                                      control1: control1, control2: control2)
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
            }
            .frame(height: chartHeight)

            // Period label
            Text(formatPeriodLabel(trend.periodStart))
                .font(.system(size: size * 0.045, weight: index == selectedPeriodIndex ? .bold : .medium))
                .foregroundColor(index == selectedPeriodIndex ? .white.opacity(0.8) : .white.opacity(0.5))
                .frame(height: 20)
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
            // Back side - Spending Trend Line Chart or empty state
            Group {
                if trends.isEmpty {
                    // Empty state when no trends data
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No trend data")
                            .font(.system(size: size * 0.08, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text("Tap to flip back")
                            .font(.system(size: size * 0.06))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .frame(width: size * 1.33, height: size * 1.09)
                } else {
                    SpendingTrendLineChart(
                        trends: trends,
                        size: size,
                        subtitle: subtitle,
                        totalAmount: totalAmount,
                        accentColor: accentColor,
                        selectedPeriod: selectedPeriod,
                        isVisible: isFlipped
                    )
                }
            }
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
                currencySymbol: ["visits", "receipt", "receipts"].contains(subtitle) ? "" : "€",
                subtitle: ["visits", "receipt", "receipts"].contains(subtitle) ? subtitle : nil
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
    var totalReceipts: Int = 0  // Total receipts to show in chart center
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
            // Back side - Spending Trend Line Chart or empty state
            Group {
                if trends.isEmpty {
                    // Empty state when no trends data
                    VStack(spacing: 12) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No trend data")
                            .font(.system(size: size * 0.08, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text("Tap to flip back")
                            .font(.system(size: size * 0.06))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .frame(width: size * 1.33, height: size * 1.09)
                } else {
                    StoreTrendLineChart(
                        trends: trends,
                        size: size,
                        totalAmount: totalAmount,
                        accentColor: accentColor,
                        selectedPeriod: selectedPeriod,
                        isVisible: isFlipped
                    )
                }
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(180),
                axis: (x: 0, y: 1, z: 0)
            )

            // Front side - Icon Donut Chart (shows receipts in center)
            IconDonutChartView(
                data: chartData,
                totalAmount: Double(totalReceipts),
                size: size,
                currencySymbol: "",
                subtitle: "receipts"
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
