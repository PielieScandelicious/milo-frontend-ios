//
//  AllStoresBreakdownView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 19/01/2026.
//

import SwiftUI

struct AllStoresBreakdownView: View {
    let period: String
    let breakdowns: [StoreBreakdown]
    let totalSpend: Double  // Total spend from backend (sum of item_price)
    let totalReceipts: Int  // Total receipt count from backend
    @Environment(\.dismiss) private var dismiss
    @State private var selectedStoreName: String?
    @State private var showingStoreTransactions = false

    // Calculate weighted average health score across all stores
    private var overallHealthScore: Double? {
        let storesWithScores = breakdowns.filter { $0.averageHealthScore != nil }
        guard !storesWithScores.isEmpty else { return nil }

        // Weight by spend amount for more accurate representation
        let totalSpendWithScores = storesWithScores.reduce(0.0) { $0 + $1.totalStoreSpend }
        guard totalSpendWithScores > 0 else { return nil }

        let weightedSum = storesWithScores.reduce(0.0) { sum, breakdown in
            guard let score = breakdown.averageHealthScore else { return sum }
            return sum + (score * breakdown.totalStoreSpend)
        }

        return weightedSum / totalSpendWithScores
    }

    private var storeSegments: [StoreChartSegment] {
        var currentAngle: Double = 0
        let colors: [Color] = [
            Color(red: 0.3, green: 0.7, blue: 1.0),   // Blue
            Color(red: 0.4, green: 0.8, blue: 0.5),   // Green
            Color(red: 1.0, green: 0.7, blue: 0.3),   // Orange
            Color(red: 0.9, green: 0.4, blue: 0.6),   // Pink
            Color(red: 0.7, green: 0.5, blue: 1.0),   // Purple
            Color(red: 0.3, green: 0.9, blue: 0.9),   // Cyan
            Color(red: 1.0, green: 0.6, blue: 0.4),   // Coral
            Color(red: 0.6, green: 0.9, blue: 0.4),   // Lime
        ]

        return breakdowns.enumerated().map { index, breakdown in
            let percentage = breakdown.totalStoreSpend / totalSpend
            let angleRange = 360.0 * percentage
            let segment = StoreChartSegment(
                startAngle: .degrees(currentAngle),
                endAngle: .degrees(currentAngle + angleRange),
                color: colors[index % colors.count],
                storeName: breakdown.storeName,
                amount: breakdown.totalStoreSpend,
                percentage: Int(percentage * 100),
                healthScore: breakdown.averageHealthScore,
                group: breakdown.primaryGroup,
                groupColorHex: breakdown.primaryGroupColorHex,
                groupIcon: breakdown.primaryGroupIcon
            )
            currentAngle += angleRange
            return segment
        }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Nutri Score Header
                    NutriScoreHeader(
                        healthScore: overallHealthScore,
                        period: period,
                        totalSpend: totalSpend
                    )
                    .padding(.horizontal)
                    
                    // Large combined donut chart - tap to flip to line chart
                    VStack(spacing: 32) {
                        FlippableAllStoresChartView(
                            totalAmount: totalSpend,
                            segments: storeSegments,
                            size: 220,
                            totalReceipts: totalReceipts,
                            accentColor: Color(red: 0.95, green: 0.25, blue: 0.3),
                            selectedPeriod: period
                        )
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                        
                        // Legend grouped by category group
                        VStack(spacing: 20) {
                            let groupedSegments = Dictionary(grouping: storeSegments, by: { $0.group ?? "Other" })
                            let sortedGroups = groupedSegments.keys.sorted { a, b in
                                let totalA = groupedSegments[a]!.reduce(0.0) { $0 + $1.amount }
                                let totalB = groupedSegments[b]!.reduce(0.0) { $0 + $1.amount }
                                return totalA > totalB
                            }

                            ForEach(sortedGroups, id: \.self) { groupName in
                                if let groupStores = groupedSegments[groupName], !groupStores.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        // Group header
                                        groupSectionHeader(
                                            groupName: groupName,
                                            icon: groupStores.first?.groupIcon ?? "square.grid.2x2.fill",
                                            colorHex: groupStores.first?.groupColorHex ?? "#95A5A6"
                                        )

                                        // Store rows in this group
                                        ForEach(groupStores, id: \.id) { segment in
                                            Button {
                                                selectedStoreName = segment.storeName
                                                showingStoreTransactions = true
                                            } label: {
                                                storeRow(segment: segment)
                                            }
                                            .buttonStyle(StoreRowButtonStyle())
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingStoreTransactions) {
            if let storeName = selectedStoreName {
                ReceiptsListView(
                    period: period,
                    storeName: storeName
                )
            }
        }
    }

    private func groupSectionHeader(groupName: String, icon: String, colorHex: String) -> some View {
        HStack(spacing: 10) {
            let groupColor = Color(hex: colorHex) ?? .white.opacity(0.7)

            ZStack {
                Circle()
                    .fill(groupColor.opacity(0.15))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(groupColor)
            }

            Text(groupName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.85))

            Spacer()
        }
        .padding(.top, 4)
    }

    private func storeRow(segment: StoreChartSegment) -> some View {
        HStack {
            Circle()
                .fill(segment.color)
                .frame(width: 12, height: 12)

            Text(segment.storeName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)

            // Health Score Badge (if available)
            if let healthScore = segment.healthScore {
                HealthScoreBadge(score: Int(healthScore.rounded()), size: .small, style: .subtle)
            }

            Spacer()

            Text("\(segment.percentage)%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 45, alignment: .trailing)

            Text(String(format: "€%.0f", segment.amount))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .trailing)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - All Stores Donut Chart
struct AllStoresDonutChart: View {
    let totalAmount: Double
    let segments: [StoreChartSegment]
    let size: CGFloat
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.15)
                .frame(width: size, height: size)
            
            // Segments
            ForEach(segments) { segment in
                DonutSegment(
                    startAngle: segment.startAngle,
                    endAngle: segment.endAngle,
                    color: segment.color,
                    lineWidth: size * 0.15,
                    animationProgress: animationProgress
                )
                .frame(width: size, height: size)
            }
            
            // Center content
            VStack(spacing: 4) {
                Text(String(format: "€%.0f", totalAmount))
                    .font(.system(size: size * 0.16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Total")
                    .font(.system(size: size * 0.09, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.8)) {
                animationProgress = 1.0
            }
        }
    }
}

// MARK: - Store Chart Segment
struct StoreChartSegment: Identifiable {
    // Use storeName as stable ID - prevents SwiftUI duplication when segments are recomputed
    var id: String { storeName }
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let storeName: String
    let amount: Double
    let percentage: Int
    let healthScore: Double?  // Average health score for this store
    let group: String?  // Primary category group (e.g., "Food & Dining")
    let groupColorHex: String?  // Hex color for the group
    let groupIcon: String?  // SF Symbol icon for the group
}

// MARK: - Button Styles

struct StoreRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Nutri Score Header

struct NutriScoreHeader: View {
    let healthScore: Double?
    let period: String
    let totalSpend: Double

    private var nutriScoreLetter: String {
        guard let score = healthScore else { return "-" }
        let rounded = Int(score.rounded())
        return rounded.nutriScoreLetter
    }

    private var scoreColor: Color {
        guard let score = healthScore else { return Color(white: 0.4) }
        return score.healthScoreColor
    }

    private var scoreLabel: String {
        guard let score = healthScore else { return "No Data" }
        return score.healthScoreLabel
    }

    var body: some View {
        HStack(spacing: 16) {
            // Nutri Score Circle
            ZStack {
                Circle()
                    .fill(scoreColor.opacity(0.15))
                    .frame(width: 72, height: 72)

                Circle()
                    .stroke(scoreColor, lineWidth: 3)
                    .frame(width: 72, height: 72)

                Text(nutriScoreLetter)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(scoreColor)
            }

            // Score Details
            VStack(alignment: .leading, spacing: 4) {
                Text("Nutri Score")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(1)

                Text(scoreLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                if let score = healthScore {
                    Text(String(format: "%.1f / 5", score))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
            }

            Spacer()

            // Spend Summary
            VStack(alignment: .trailing, spacing: 4) {
                Text(period)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))

                Text(String(format: "€%.0f", totalSpend))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(scoreColor.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        AllStoresBreakdownView(
            period: "January 2026",
            breakdowns: [
                StoreBreakdown(
                    storeName: "COLRUYT",
                    period: "January 2026",
                    totalStoreSpend: 189.90,
                    categories: [
                        Category(name: "Meat & Fish", spent: 65.40, percentage: 34)
                    ],
                    visitCount: 15,
                    averageHealthScore: 3.8
                ),
                StoreBreakdown(
                    storeName: "ALDI",
                    period: "January 2026",
                    totalStoreSpend: 94.50,
                    categories: [
                        Category(name: "Fresh Produce", spent: 32.10, percentage: 34)
                    ],
                    visitCount: 10,
                    averageHealthScore: 4.2
                )
            ],
            totalSpend: 284.40,
            totalReceipts: 25
        )
    }
    .preferredColorScheme(.dark)
}
