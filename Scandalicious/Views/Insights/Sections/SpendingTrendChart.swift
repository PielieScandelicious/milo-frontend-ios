//
//  SpendingTrendChart.swift
//  Scandalicious
//
//  Created by Claude on 23/02/2026.
//

import SwiftUI

struct SpendingTrendChart: View {
    @ObservedObject var viewModel: InsightsViewModel

    private var trends: [TrendPeriod] {
        viewModel.trendData?.trends ?? []
    }

    private var maxSpend: Double {
        trends.map(\.totalSpend).max() ?? 1
    }

    private var averageSpend: Double {
        guard !trends.isEmpty else { return 0 }
        return trends.map(\.totalSpend).reduce(0, +) / Double(trends.count)
    }

    private let barSpacing: CGFloat = 6
    private let chartHeight: CGFloat = 150

    var body: some View {
        if viewModel.trendState == .loading && trends.isEmpty {
            chartSkeleton
        } else if trends.isEmpty {
            emptyState
        } else {
            VStack(spacing: 14) {
                // Bar chart
                barChart

                // Month labels
                monthLabels
            }
        }
    }

    // MARK: - Bar Chart (custom drawn for reliable tap handling)

    private var barChart: some View {
        GeometryReader { geo in
            let barWidth = (geo.size.width - barSpacing * CGFloat(trends.count - 1)) / CGFloat(trends.count)

            ZStack(alignment: .bottom) {
                // Average line
                if averageSpend > 0 {
                    let avgY = chartHeight * CGFloat(1 - averageSpend / maxSpend)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: avgY))
                        path.addLine(to: CGPoint(x: geo.size.width, y: avgY))
                    }
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .foregroundStyle(.white.opacity(0.12))
                }

                // Bars
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(Array(trends.enumerated()), id: \.element.id) { index, period in
                        let isSelected = index == viewModel.selectedTrendIndex
                        let proportion = maxSpend > 0 ? period.totalSpend / maxSpend : 0
                        let barHeight = max(chartHeight * CGFloat(proportion), 4)

                        RoundedRectangle(cornerRadius: barWidth * 0.3)
                            .fill(
                                isSelected
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.7)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    : AnyShapeStyle(Color.white.opacity(0.12))
                            )
                            .frame(width: barWidth, height: barHeight)
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.selectedTrendIndex)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectPeriod(at: index)
                            }
                    }
                }
                .frame(height: chartHeight, alignment: .bottom)
            }
        }
        .frame(height: chartHeight)
    }

    // MARK: - Month Labels

    private var monthLabels: some View {
        GeometryReader { geo in
            let barWidth = (geo.size.width - barSpacing * CGFloat(trends.count - 1)) / CGFloat(trends.count)

            HStack(alignment: .top, spacing: barSpacing) {
                ForEach(Array(trends.enumerated()), id: \.element.id) { index, period in
                    let isSelected = index == viewModel.selectedTrendIndex

                    Text(shortLabel(for: period))
                        .font(.system(size: 10, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.3))
                        .frame(width: barWidth)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.selectedTrendIndex)
                }
            }
        }
        .frame(height: 14)
    }

    // MARK: - Helpers

    private func shortLabel(for period: TrendPeriod) -> String {
        let parts = period.period.split(separator: " ")
        if let monthName = parts.first {
            return String(monthName.prefix(3))
        }
        return period.period
    }

    // MARK: - States

    private var chartSkeleton: some View {
        HStack(alignment: .bottom, spacing: barSpacing) {
            ForEach(0..<8, id: \.self) { i in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: CGFloat(40 + (i * 12) % 80))
            }
        }
        .frame(height: chartHeight)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title2)
                .foregroundStyle(.white.opacity(0.2))
            Text("No spending data yet")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(height: chartHeight)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - No-op selection handler (kept for API compatibility)

extension SpendingTrendChart {
    func withSelectionHandling() -> some View {
        self // Tap handling is now built into the bars directly
    }
}
