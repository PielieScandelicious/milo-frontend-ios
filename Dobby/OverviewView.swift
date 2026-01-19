//
//  OverviewView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers

enum SortOption: String, CaseIterable {
    case highestSpend = "Highest Spend"
    case lowestSpend = "Lowest Spend"
    case storeName = "Store Name"
}



struct OverviewView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @StateObject private var dataManager = StoreDataManager()
    @State private var selectedPeriod: String = "January 2026"
    @State private var selectedSort: SortOption = .highestSpend
    @State private var showingFilterSheet = false
    @State private var isEditMode = false
    @State private var draggingItem: StoreBreakdown?
    @State private var displayedBreakdowns: [StoreBreakdown] = []
    
    private var availablePeriods: [String] {
        dataManager.breakdownsByPeriod().keys.sorted()
    }
    
    private var currentBreakdowns: [StoreBreakdown] {
        // If in edit mode, use the displayed breakdowns to maintain order
        if isEditMode {
            return displayedBreakdowns
        }
        
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == selectedPeriod }
        
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
    
    // Update displayed breakdowns when filters change
    private func updateDisplayedBreakdowns() {
        var breakdowns = dataManager.storeBreakdowns.filter { $0.period == selectedPeriod }
        
        // Apply sorting
        switch selectedSort {
        case .highestSpend:
            breakdowns.sort { $0.totalStoreSpend > $1.totalStoreSpend }
        case .lowestSpend:
            breakdowns.sort { $0.totalStoreSpend < $1.totalStoreSpend }
        case .storeName:
            breakdowns.sort { $0.storeName < $1.storeName }
        }
        
        displayedBreakdowns = breakdowns
    }
    
    private var totalPeriodSpending: Double {
        currentBreakdowns.reduce(0) { $0 + $1.totalStoreSpend }
    }
    
    // MARK: - Delete Functions
    private func deleteBreakdowns(at offsets: IndexSet) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            for index in offsets {
                let breakdown = displayedBreakdowns[index]
                dataManager.deleteBreakdown(breakdown)
            }
            updateDisplayedBreakdowns()
        }
    }
    
    private func deleteBreakdown(_ breakdown: StoreBreakdown) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            dataManager.deleteBreakdown(breakdown)
            displayedBreakdowns.removeAll { $0.id == breakdown.id }
        }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Fixed header
                VStack(spacing: 12) {
                    // Period selector
                    if availablePeriods.count > 1 {
                        periodSelector
                    }
                    
                    // Filter bar
                    filterBar
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .background(Color(white: 0.05))
                .zIndex(1)
                
                // Scrollable content
                ScrollView {
                    VStack(spacing: 24) {
                        // Total spending card
                        totalSpendingCard
                        
                        // Store breakdowns grid
                        storeBreakdownsGrid
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                }
                .background(Color(white: 0.05))
            }
            
            // Edit mode exit button overlay
            if isEditMode {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                isEditMode = false
                            }
                        } label: {
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                )
                        }
                        .padding(.trailing)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
                .transition(.opacity)
            }
        }
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedSort: $selectedSort
            )
        }
        .onAppear {
            dataManager.configure(with: transactionManager)
            updateDisplayedBreakdowns()
        }
        .onChange(of: transactionManager.transactions) { oldValue, newValue in
            dataManager.regenerateBreakdowns()
            updateDisplayedBreakdowns()
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            updateDisplayedBreakdowns()
        }
        .onChange(of: selectedSort) { oldValue, newValue in
            updateDisplayedBreakdowns()
        }
        .onChange(of: dataManager.storeBreakdowns) { oldValue, newValue in
            if !isEditMode {
                updateDisplayedBreakdowns()
            }
        }
    }
    
    private var filterBar: some View {
        HStack(spacing: 12) {
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
                ZStack(alignment: .topTrailing) {
                    // The card itself
                    if isEditMode {
                        storeChartCard(breakdown)
                            .modifier(JiggleModifier(isJiggling: isEditMode))
                            .onDrag {
                                self.draggingItem = breakdown
                                return NSItemProvider(object: breakdown.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: DropViewDelegate(
                                destinationItem: breakdown,
                                items: $displayedBreakdowns,
                                draggingItem: $draggingItem
                            ))
                    } else {
                        storeChartCard(breakdown)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                // Navigate to detail - will implement with NavigationLink later
                            }
                            .onLongPressGesture(minimumDuration: 0.5) {
                                // Enter edit mode on long press
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isEditMode = true
                                }
                                // Haptic feedback
                                let generator = UIImpactFeedbackGenerator(style: .medium)
                                generator.impactOccurred()
                            }
                    }
                    
                    // Delete button (X) in edit mode
                    if isEditMode {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                                deleteBreakdown(breakdown)
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.red)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 18, height: 18)
                                )
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        }
                        .offset(x: 8, y: -8)
                        .transition(.scale.combined(with: .opacity))
                        .zIndex(1)
                    }
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func storeChartCard(_ breakdown: StoreBreakdown) -> some View {
        VStack(spacing: 0) {
            DonutChartView(
                title: breakdown.storeName,
                subtitle: "",
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
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(white: 0.05).ignoresSafeArea()
                
                List {
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

// MARK: - Drop Delegate for Drag and Drop Reordering
struct DropViewDelegate: DropDelegate {
    let destinationItem: StoreBreakdown
    @Binding var items: [StoreBreakdown]
    @Binding var draggingItem: StoreBreakdown?
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        if draggingItem != destinationItem {
            let fromIndex = items.firstIndex(of: draggingItem)
            let toIndex = items.firstIndex(of: destinationItem)
            
            if let fromIndex = fromIndex, let toIndex = toIndex {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                }
            }
        }
    }
}

// MARK: - Jiggle Modifier for Edit Mode
struct JiggleModifier: ViewModifier {
    let isJiggling: Bool
    @State private var rotation: Double = 0
    
    private let rotationAngle: Double = 2.5
    private let duration: Double = 0.13
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .task(id: isJiggling) {
                guard isJiggling else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rotation = 0
                    }
                    return
                }
                
                // Start with random direction for natural look
                let startDirection: Double = Bool.random() ? rotationAngle : -rotationAngle
                rotation = startDirection
                
                // Continuous jiggle loop
                while isJiggling {
                    withAnimation(.easeInOut(duration: duration)) {
                        rotation = -rotation
                    }
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }
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
