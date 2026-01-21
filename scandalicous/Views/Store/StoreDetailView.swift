//
//  StoreDetailView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct StoreDetailView: View {
    let storeBreakdown: StoreBreakdown
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String?
    @State private var selectedCategoryColor: Color?
    @State private var showingAllTransactions = false
    @State private var showingCategoryTransactions = false
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header card - clickable to view all store transactions
                    Button {
                        showingAllTransactions = true
                    } label: {
                        VStack(spacing: 12) {
                            Text(storeBreakdown.storeName)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(.white)

                            Text(storeBreakdown.period)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))

                            Text(String(format: "€%.0f", storeBreakdown.totalStoreSpend))
                                .font(.system(size: 48, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.top, 8)

                            // Health Score indicator (placeholder - will show when backend provides data)
                            if let healthScore = storeBreakdown.averageHealthScore {
                                Divider()
                                    .background(Color.white.opacity(0.2))
                                    .padding(.horizontal, 40)
                                    .padding(.top, 8)

                                HStack(spacing: 8) {
                                    HealthScoreBadge(score: Int(healthScore.rounded()), size: .medium, style: .subtle)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Health Score")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.5))

                                        Text(healthScore.healthScoreLabel)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(healthScore.healthScoreColor)
                                    }
                                }
                                .padding(.top, 4)
                            }
                        }
                        .padding(.vertical, 32)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(Color.white.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(StoreHeaderButtonStyle())
                    .padding(.horizontal)
                    
                    // Large donut chart - clickable to view all transactions
                    VStack(spacing: 20) {
                        Button {
                            showingAllTransactions = true
                        } label: {
                            DonutChartView(
                                title: "",
                                subtitle: "visits",
                                totalAmount: Double(storeBreakdown.visitCount),
                                segments: storeBreakdown.categories.toChartSegments(),
                                size: 220
                            )
                            .padding(.top, 20)
                        }
                        .buttonStyle(DonutChartButtonStyle())
                        
                        // Legend with tap interaction
                        VStack(spacing: 12) {
                            ForEach(Array(storeBreakdown.categories.toChartSegments().enumerated()), id: \.element.id) { _, segment in
                                Button {
                                    selectedCategory = segment.label
                                    selectedCategoryColor = segment.color
                                    showingCategoryTransactions = true
                                } label: {
                                    categoryRow(segment: segment)
                                }
                                .buttonStyle(CategoryRowButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingAllTransactions) {
            TransactionListView(
                storeName: storeBreakdown.storeName,
                period: storeBreakdown.period,
                category: nil,
                categoryColor: nil
            )
        }
        .navigationDestination(isPresented: $showingCategoryTransactions) {
            TransactionListView(
                storeName: storeBreakdown.storeName,
                period: storeBreakdown.period,
                category: selectedCategory,
                categoryColor: selectedCategoryColor
            )
        }
    }
    
    private func categoryRow(segment: ChartSegment) -> some View {
        HStack {
            Circle()
                .fill(segment.color)
                .frame(width: 12, height: 12)
            
            Text(segment.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Text("\(segment.percentage)%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 45, alignment: .trailing)
            
            Text(String(format: "€%.0f", segment.value))
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

// MARK: - Custom Button Styles
struct StoreHeaderButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct CategoryRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

struct DonutChartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        StoreDetailView(storeBreakdown: StoreBreakdown(
            storeName: "COLRUYT",
            period: "January 2026",
            totalStoreSpend: 189.90,
            categories: [
                Category(name: "Meat & Fish", spent: 65.40, percentage: 34),
                Category(name: "Alcohol", spent: 42.50, percentage: 22),
                Category(name: "Drinks (Soft/Soda)", spent: 28.00, percentage: 15),
                Category(name: "Household", spent: 35.00, percentage: 18),
                Category(name: "Snacks & Sweets", spent: 19.00, percentage: 11)
            ],
            visitCount: 15
        ))
    }
    .preferredColorScheme(.dark)
}
