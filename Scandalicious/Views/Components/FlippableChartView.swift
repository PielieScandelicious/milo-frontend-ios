//
//  FlippableChartView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import SwiftUI

// MARK: - Flippable Donut Chart View
struct FlippableDonutChartView: View {
    let title: String
    let subtitle: String
    let totalAmount: Double
    let segments: [ChartSegment]
    let size: CGFloat
    var accentColor: Color = Color(red: 0.95, green: 0.25, blue: 0.3) // Modern red
    var selectedPeriod: String? = nil  // e.g., "January 2026"
    var averageItemPrice: Double? = nil  // Average price per item for store detail view

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
        IconDonutChartView(
            data: chartData,
            totalAmount: totalAmount,
            size: size,
            currencySymbol: ["visits", "receipt", "receipts"].contains(subtitle) ? "" : "€",
            subtitle: ["visits", "receipt", "receipts"].contains(subtitle) ? subtitle : nil,
            averageItemPrice: averageItemPrice
        )
        .frame(width: size * 1.33, height: size * 1.09)
    }
}

// MARK: - Flippable All Stores Chart View
struct FlippableAllStoresChartView: View {
    let totalAmount: Double
    let segments: [StoreChartSegment]
    let size: CGFloat
    var totalReceipts: Int = 0  // Total receipts to show in chart center
    var accentColor: Color = Color(red: 0.95, green: 0.25, blue: 0.3) // Modern red
    var selectedPeriod: String? = nil  // e.g., "January 2026"

    /// Convert StoreChartSegments to ChartData for IconDonutChartView
    private var chartData: [ChartData] {
        segments.toIconChartData()
    }

    var body: some View {
        IconDonutChartView(
            data: chartData,
            totalAmount: Double(totalReceipts),
            size: size,
            currencySymbol: "",
            subtitle: "receipts"
        )
        .frame(width: size * 1.33, height: size * 1.09)
    }
}

// MARK: - Flippable All-Time Stores/Categories Chart View
/// A flippable donut chart that shows All-Time Top Stores on the front
/// and All-Time Top Categories on the back when tapped.
struct FlippableAllTimeChartView: View {
    let topStores: [TopStoreSpend]
    let topCategories: [TopCategory]?
    let totalSpend: Double
    let totalReceipts: Int
    let size: CGFloat

    @State private var isFlipped = false
    @State private var flipDegrees: Double = 0

    private let colors: [Color] = [
        Color(red: 0.3, green: 0.7, blue: 1.0),   // Blue
        Color(red: 0.4, green: 0.8, blue: 0.5),   // Green
        Color(red: 1.0, green: 0.7, blue: 0.3),   // Orange
        Color(red: 0.9, green: 0.4, blue: 0.6),   // Pink
        Color(red: 0.7, green: 0.5, blue: 1.0),   // Purple
        Color(red: 0.3, green: 0.9, blue: 0.9),   // Cyan
        Color(red: 1.0, green: 0.6, blue: 0.4),   // Coral
        Color(red: 0.6, green: 0.9, blue: 0.4),   // Lime
    ]

    /// Convert top stores to ChartData for the donut chart
    private var storesChartData: [ChartData] {
        topStores.enumerated().map { index, store in
            ChartData(
                value: store.totalSpent,
                color: colors[index % colors.count],
                iconName: "storefront.fill",
                label: store.storeName
            )
        }
    }

    /// Convert top categories to ChartData for the donut chart
    private var categoriesChartData: [ChartData] {
        guard let categories = topCategories else { return [] }
        return categories.enumerated().map { index, category in
            ChartData(
                value: category.totalSpent,
                color: colors[index % colors.count],
                iconName: category.icon,
                label: category.name
            )
        }
    }

    /// Whether categories data is available
    private var hasCategoriesData: Bool {
        guard let categories = topCategories else { return false }
        return !categories.isEmpty
    }

    var body: some View {
        ZStack {
            // Back side - Categories Donut Chart
            Group {
                if hasCategoriesData {
                    IconDonutChartView(
                        data: categoriesChartData,
                        totalAmount: totalSpend,
                        size: size,
                        currencySymbol: "€",
                        subtitle: nil
                    )
                } else {
                    // Empty state when no categories data
                    VStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: size * 0.2))
                            .foregroundColor(.white.opacity(0.3))

                        Text("No category data")
                            .font(.system(size: size * 0.08, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))

                        Text("Tap to flip back")
                            .font(.system(size: size * 0.06))
                            .foregroundColor(.white.opacity(0.25))
                    }
                    .frame(width: size, height: size)
                }
            }
            .opacity(isFlipped ? 1 : 0)
            .rotation3DEffect(
                .degrees(180),
                axis: (x: 0, y: 1, z: 0)
            )

            // Front side - Stores Donut Chart
            IconDonutChartView(
                data: storesChartData,
                totalAmount: Double(totalReceipts),
                size: size,
                currencySymbol: "",
                subtitle: "receipts"
            )
            .opacity(isFlipped ? 0 : 1)
        }
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