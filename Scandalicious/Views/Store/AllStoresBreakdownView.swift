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
    @Environment(\.dismiss) private var dismiss
    @State private var showingAllTransactions = false
    @State private var selectedStoreName: String?
    @State private var showingStoreTransactions = false
    
    private var totalSpending: Double {
        breakdowns.reduce(0) { $0 + $1.totalStoreSpend }
    }

    private var totalTransactions: Int {
        breakdowns.reduce(0) { $0 + $1.visitCount }
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
            let percentage = breakdown.totalStoreSpend / totalSpending
            let angleRange = 360.0 * percentage
            let segment = StoreChartSegment(
                startAngle: .degrees(currentAngle),
                endAngle: .degrees(currentAngle + angleRange),
                color: colors[index % colors.count],
                storeName: breakdown.storeName,
                amount: breakdown.totalStoreSpend,
                percentage: Int(percentage * 100),
                healthScore: breakdown.averageHealthScore
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
                    // Header - clickable to view all transactions
                    Button {
                        showingAllTransactions = true
                    } label: {
                        VStack(spacing: 8) {
                            Text("Total Transactions")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                                .textCase(.uppercase)
                                .tracking(1.2)

                            Text("\(totalTransactions)")
                                .font(.system(size: 44, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)

                            Text(period)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(StoresHeaderButtonStyle())
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.05))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .padding(.horizontal)
                    
                    // Large combined donut chart - tap to flip to bar chart
                    VStack(spacing: 32) {
                        FlippableAllStoresChartView(
                            totalAmount: totalSpending,
                            segments: storeSegments,
                            size: 220
                        )
                        .padding(.top, 24)
                        .padding(.bottom, 12)
                        
                        // Legend
                        VStack(spacing: 12) {
                            ForEach(storeSegments, id: \.id) { segment in
                                Button {
                                    selectedStoreName = segment.storeName
                                    showingStoreTransactions = true
                                } label: {
                                    storeRow(segment: segment)
                                }
                                .buttonStyle(StoreRowButtonStyle())
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
        .navigationDestination(isPresented: $showingAllTransactions) {
            TransactionListView(
                storeName: "All Stores",
                period: period,
                category: nil,
                categoryColor: nil
            )
        }
        .navigationDestination(isPresented: $showingStoreTransactions) {
            if let storeName = selectedStoreName {
                TransactionListView(
                    storeName: storeName,
                    period: period,
                    category: nil,
                    categoryColor: nil
                )
            }
        }
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
    let id = UUID()
    let startAngle: Angle
    let endAngle: Angle
    let color: Color
    let storeName: String
    let amount: Double
    let percentage: Int
    let healthScore: Double?  // Average health score for this store
}

// MARK: - Button Styles
// Note: DonutChartButtonStyle is defined in StoreDetailView.swift

struct StoresHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct StoreRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
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
                    visitCount: 15
                ),
                StoreBreakdown(
                    storeName: "ALDI",
                    period: "January 2026",
                    totalStoreSpend: 94.50,
                    categories: [
                        Category(name: "Fresh Produce", spent: 32.10, percentage: 34)
                    ],
                    visitCount: 10
                )
            ]
        )
    }
    .preferredColorScheme(.dark)
}
