//
//  OverviewView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

enum SortOption: String, CaseIterable {
    case highestSpend = "Highest Spend"
    case lowestSpend = "Lowest Spend"
    case storeName = "Store Name"
}

enum StoreFilter: String, CaseIterable {
    case all = "All Stores"
    case colruyt = "COLRUYT"
    case aldi = "ALDI"
}

struct OverviewView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedPeriod: String = "January 2026"
    @State private var selectedSort: SortOption = .highestSpend
    @State private var selectedStoreFilter: StoreFilter = .all
    @State private var showingFilterSheet = false
    
    private var availablePeriods: [String] {
        dataManager.breakdownsByPeriod().keys.sorted()
    }
    
    private var currentBreakdowns: [StoreBreakdown] {
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == selectedPeriod }
        
        // Apply store filter
        if selectedStoreFilter != .all {
            breakdowns = breakdowns.filter { $0.storeName == selectedStoreFilter.rawValue }
        }
        
        // Apply sorting
        switch selectedSort {
        case .highestSpend:
            breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        case .lowestSpend:
            breakdowns.sort { $0.totalStoreSpend < $1.totalStoreSpend }
        case .storeName:
            breakdowns.sort { $0.storeName < $1.storeName }
        }
        
        return breakdowns
    }
    
    private var totalPeriodSpending: Double {
        currentBreakdowns.reduce(0) { $0 + $1.totalStoreSpend }
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
                    
                    // Filter bar
                    filterBar
                    
                    // Total spending card
                    totalSpendingCard
                    
                    // Store breakdowns grid
                    storeBreakdownsGrid
                }
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedSort: $selectedSort,
                selectedStoreFilter: $selectedStoreFilter
            )
        }
        .onAppear {
            dataManager.configure(with: transactionManager)
        }
        .onChange(of: transactionManager.transactions) { oldValue, newValue in
            dataManager.regenerateBreakdowns()
        }
    }
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Store filter button
            Menu {
                ForEach(StoreFilter.allCases, id: \.self) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedStoreFilter = filter
                        }
                    } label: {
                        HStack {
                            Text(filter.rawValue)
                            if selectedStoreFilter == filter {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 16, weight: .medium))
                    Text(selectedStoreFilter.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedStoreFilter != .all ? Color.blue.opacity(0.2) : Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedStoreFilter != .all ? Color.blue.opacity(0.4) : Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            
            // Sort button
            Menu {
                ForEach(SortOption.allCases, id: \.self) { option in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedSort = option
                        }
                    } label: {
                        HStack {
                            Text(option.rawValue)
                            if selectedSort == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 16, weight: .medium))
                    Text(selectedSort.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            
            Spacer()
        }
        .padding(.horizontal)
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

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedSort: SortOption
    @Binding var selectedStoreFilter: StoreFilter
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                List {
                    Section {
                        ForEach(StoreFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedStoreFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.rawValue)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedStoreFilter == filter {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Store")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    
                    Section {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Button {
                                selectedSort = option
                            } label: {
                                HStack {
                                    Text(option.rawValue)
                                        .foregroundColor(.white)
                                    Spacer()
                                    if selectedSort == option {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text("Sort By")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
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
