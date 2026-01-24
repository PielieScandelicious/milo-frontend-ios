//
//  FlippableChartView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI

// MARK: - iOS-Style Mini Line Chart
struct MiniLineChart: View {
    let segments: [ChartSegment]
    let size: CGFloat
    let subtitle: String
    let totalAmount: Double

    @State private var animationProgress: CGFloat = 0

    private var sortedSegments: [ChartSegment] {
        segments.sorted { $0.value > $1.value }
    }

    private var maxValue: Double {
        segments.map { $0.value }.max() ?? 1
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle matching donut style
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: size * 0.15)
                    .frame(width: size, height: size)

                // Inner chart area
                VStack(spacing: 8) {
                    // Mini bar chart visualization
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(sortedSegments.prefix(5).enumerated()), id: \.element.id) { index, segment in
                            VStack(spacing: 4) {
                                // Animated bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [segment.color, segment.color.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(
                                        width: max(8, (size * 0.5) / CGFloat(min(5, sortedSegments.count)) - 6),
                                        height: max(4, CGFloat(segment.value / maxValue) * (size * 0.35) * animationProgress)
                                    )
                            }
                        }
                    }
                    .frame(height: size * 0.4)

                    // Center amount
                    if subtitle == "visits" {
                        Text(String(format: "%.0f", totalAmount))
                            .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    } else {
                        Text(String(format: "€%.0f", totalAmount))
                            .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: size * 0.07, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(size * 0.12)
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Store Mini Bar Chart (for AllStoresBreakdownView)
struct StoreMiniBarChart: View {
    let segments: [StoreChartSegment]
    let size: CGFloat
    let totalAmount: Double

    @State private var animationProgress: CGFloat = 0

    private var sortedSegments: [StoreChartSegment] {
        segments.sorted { $0.amount > $1.amount }
    }

    private var maxValue: Double {
        segments.map { $0.amount }.max() ?? 1
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background circle matching donut style
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: size * 0.15)
                    .frame(width: size, height: size)

                // Inner chart area
                VStack(spacing: 8) {
                    // Mini bar chart visualization
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(sortedSegments.prefix(5).enumerated()), id: \.element.id) { index, segment in
                            VStack(spacing: 4) {
                                // Animated bar
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [segment.color, segment.color.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(
                                        width: max(8, (size * 0.5) / CGFloat(min(5, sortedSegments.count)) - 6),
                                        height: max(4, CGFloat(segment.amount / maxValue) * (size * 0.35) * animationProgress)
                                    )
                            }
                        }
                    }
                    .frame(height: size * 0.4)

                    // Center amount
                    Text(String(format: "€%.0f", totalAmount))
                        .font(.system(size: size * 0.12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Total")
                        .font(.system(size: size * 0.07, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(size * 0.12)
            }
            .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Flippable Donut Chart View
struct FlippableDonutChartView: View {
    let title: String
    let subtitle: String
    let totalAmount: Double
    let segments: [ChartSegment]
    let size: CGFloat

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
            // Back side - Mini Bar Chart
            MiniLineChart(
                segments: segments,
                size: size,
                subtitle: subtitle,
                totalAmount: totalAmount
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
                currencySymbol: subtitle == "visits" ? "" : "€"
            )
            .opacity(isFlipped ? 0 : 1)
        }
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

    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0

    /// Convert StoreChartSegments to ChartData for IconDonutChartView
    private var chartData: [ChartData] {
        segments.toIconChartData()
    }

    var body: some View {
        ZStack {
            // Back side - Mini Bar Chart
            StoreMiniBarChart(
                segments: segments,
                size: size,
                totalAmount: totalAmount
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
