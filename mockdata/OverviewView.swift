//
//  OverviewView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct OverviewView: View {
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedPeriod: String = "January 2026"
    
    private var availablePeriods: [String] {
        dataManager.breakdownsByPeriod().keys.sorted()
    }
    
    private var currentBreakdowns: [StoreBreakdown] {
        dataManager.storeBreakdowns.filter { $0.period == selectedPeriod }
    }
    
    private var totalPeriodSpending: Double {
        dataManager.totalSpending(for: selectedPeriod)
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Period selector
                    if availablePeriods.count > 1 {
                        periodSelector
                    }
                    
                    // Total spending card
                    totalSpendingCard
                    
                    // Store breakdowns grid
                    storeBreakdownsGrid
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
    }
    
    private var periodSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePeriods, id: \.self) { period in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPeriod = period
                        }
                    } label: {
                        Text(period)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedPeriod == period ? .black : .white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedPeriod == period ? Color.white : Color.white.opacity(0.1))
                            )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var totalSpendingCard: some View {
        VStack(spacing: 8) {
            Text("Total Spending")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(1.2)
            
            Text(String(format: "€%.2f", totalPeriodSpending))
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            
            Text(selectedPeriod)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.3, blue: 0.5).opacity(0.3),
                            Color(red: 0.3, green: 0.2, blue: 0.5).opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .padding(.horizontal)
    }
    
    private var storeBreakdownsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 20) {
            ForEach(currentBreakdowns) { breakdown in
                NavigationLink(destination: StoreDetailView(storeBreakdown: breakdown)) {
                    storeChartCard(breakdown)
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .padding(.horizontal)
    }
    
    private func storeChartCard(_ breakdown: StoreBreakdown) -> some View {
        VStack(spacing: 0) {
            DonutChartView(
                title: breakdown.storeName,
                subtitle: "Store",
                totalAmount: breakdown.totalStoreSpend,
                segments: breakdown.categories.toChartSegments(),
                size: 90
            )
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Custom Button Style for Scale Effect
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        OverviewView()
            .navigationTitle("View")
            .navigationBarTitleDisplayMode(.large)
    }
    .preferredColorScheme(.dark)
}
