//
//
//  OverviewView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import UniformTypeIdentifiers
import FirebaseAuth

// MARK: - View Extension for Hiding Drag Preview
extension View {
    func hideDragPreview() -> some View {
        self.overlay(
            Color.clear
                .contentShape(Rectangle())
        )
    }
}

// MARK: - Notification for Receipt Upload Success
extension Notification.Name {
    static let receiptUploadedSuccessfully = Notification.Name("receiptUploadedSuccessfully")
}

enum SortOption: String, CaseIterable {
    case highestSpend = "Highest Spend"
    case lowestSpend = "Lowest Spend"
    case storeName = "Store Name"
}



struct OverviewView: View {
    @EnvironmentObject var transactionManager: TransactionManager
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var dataManager: StoreDataManager
    @State private var selectedPeriod: String = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        return dateFormatter.string(from: Date())
    }()
    @State private var selectedSort: SortOption = .highestSpend
    @State private var showingFilterSheet = false
    @State private var isEditMode = false {
        didSet {
            print("🔵🔵🔵 isEditMode changed from \(oldValue) to \(isEditMode)")
        }
    }
    @State private var draggingItem: StoreBreakdown?
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    @State private var displayedBreakdowns: [StoreBreakdown] = []
    @State private var selectedBreakdown: StoreBreakdown?
    @State private var showingAllStoresBreakdown = false
    @State private var showingAllTransactions = false
    @State private var showingProfileMenu = false
    @State private var breakdownToDelete: StoreBreakdown?
    @State private var showingDeleteConfirmation = false
    @Binding var showSignOutConfirmation: Bool
    
    // User defaults key for storing order
    private let orderStorageKey = "StoreBreakdownsOrder"
    
    private var availablePeriods: [String] {
        let periods = dataManager.breakdownsByPeriod().keys.sorted()
        
        // If no periods available, generate at least the last 6 months
        if periods.isEmpty {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMMM yyyy"
            let calendar = Calendar.current
            
            return (0..<6).compactMap { monthsAgo in
                guard let date = calendar.date(byAdding: .month, value: -monthsAgo, to: Date()) else {
                    return nil
                }
                return dateFormatter.string(from: date)
            }
        }
        
        return periods
    }
    
    private var currentBreakdowns: [StoreBreakdown] {
        // Always use displayedBreakdowns to maintain consistent ordering
        // This prevents items from jumping when entering/exiting edit mode
        if displayedBreakdowns.isEmpty {
            updateDisplayedBreakdownsSync()
        }
        return displayedBreakdowns
    }
    
    // Synchronous version for use in computed properties
    private func updateDisplayedBreakdownsSync() {
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
        
        // Apply saved custom order if available
        breakdowns = applyCustomOrder(to: breakdowns, for: selectedPeriod)
        
        displayedBreakdowns = breakdowns
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
        
        // Apply saved custom order if available
        breakdowns = applyCustomOrder(to: breakdowns, for: selectedPeriod)
        
        displayedBreakdowns = breakdowns
    }
    
    // MARK: - Custom Order Persistence
    
    private func saveCustomOrder() {
        // Save the current order for this period
        let storeIds = displayedBreakdowns.map { $0.id }
        let key = "\(orderStorageKey)_\(selectedPeriod)"
        UserDefaults.standard.set(storeIds, forKey: key)
        print("💾 Saved custom order for \(selectedPeriod): \(storeIds)")
    }
    
    private func applyCustomOrder(to breakdowns: [StoreBreakdown], for period: String) -> [StoreBreakdown] {
        let key = "\(orderStorageKey)_\(period)"
        guard let savedOrder = UserDefaults.standard.array(forKey: key) as? [String] else {
            // No saved order, return as-is
            return breakdowns
        }
        
        // Create a dictionary for quick lookup
        var breakdownDict = Dictionary(uniqueKeysWithValues: breakdowns.map { ($0.id, $0) })
        
        // Build ordered array based on saved order
        var orderedBreakdowns: [StoreBreakdown] = []
        
        // First, add items in the saved order
        for id in savedOrder {
            if let breakdown = breakdownDict[id] {
                orderedBreakdowns.append(breakdown)
                breakdownDict.removeValue(forKey: id)
            }
        }
        
        // Then append any new items that weren't in the saved order
        orderedBreakdowns.append(contentsOf: breakdownDict.values.sorted { $0.storeName < $1.storeName })
        
        print("📋 Applied custom order for \(period), \(orderedBreakdowns.count) items")
        return orderedBreakdowns
    }
    
    private var totalPeriodSpending: Double {
        currentBreakdowns.reduce(0) { $0 + $1.totalStoreSpend }
    }
    
    // MARK: - Delete Functions
    private func deleteBreakdowns(at offsets: IndexSet) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            for index in offsets {
                let breakdown = displayedBreakdowns[index]
                dataManager.deleteBreakdownLocally(breakdown)
            }
            updateDisplayedBreakdowns()
        }
    }

    private func deleteBreakdown(_ breakdown: StoreBreakdown) async {
        // Determine period type from selected period
        let periodType: PeriodType = {
            switch selectedPeriod.lowercased() {
            case let p where p.contains("week"): return .week
            case let p where p.contains("year"): return .year
            default: return .month
            }
        }()

        let success = await dataManager.deleteBreakdown(breakdown, periodType: periodType)

        if success {
            await MainActor.run {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    displayedBreakdowns.removeAll { $0.id == breakdown.id }
                    isEditMode = false
                }
            }
        }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            // Subtle overlay in edit mode - catches taps on empty space
            if isEditMode {
                Color.black.opacity(0.15)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .contentShape(Rectangle()) // Make entire overlay tappable
                    .onTapGesture {
                        // Exit edit mode when tapping background
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditMode = false
                        }
                    }
                    .allowsHitTesting(true) // Ensure it catches taps
                    .zIndex(0.5) // Above background but below content
            }
            
            // Loading overlay - only show on initial load
            if dataManager.isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.3))
                .transition(.opacity)
            } else if let error = dataManager.error {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.red)
                    
                    Text("Failed to load data")
                        .font(.headline)
                    
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button {
                        Task {
                            await dataManager.fetchFromBackend(for: .month)
                        }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .transition(.opacity)
            } else {
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Liquid Glass Period Filter at the top
                        liquidGlassPeriodFilter
                            .padding(.top, 12)
                            .padding(.bottom, 12)
                        
                        // Content
                        VStack(spacing: 24) {
                            // Total spending card
                            totalSpendingCard

                            // Health score card
                            healthScoreCard

                            // Store breakdowns grid
                            storeBreakdownsGrid
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 32)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always)
                .scrollDismissesKeyboard(.interactively)
                .background(Color(white: 0.05))
                .zIndex(1) // Above the overlay
                .refreshable {
                    // Pull to refresh - smooth animation
                    let startTime = Date()
                    
                    await dataManager.refreshData(for: .month)
                    
                    // Ensure minimum refresh duration for smooth UX (at least 0.8 seconds)
                    let elapsed = Date().timeIntervalSince(startTime)
                    if elapsed < 0.8 {
                        try? await Task.sleep(for: .seconds(0.8 - elapsed))
                    }
                    
                    // Add haptic feedback on completion
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
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
                            // Haptic feedback
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        } label: {
                            Text("Done")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .fill(Color.blue)
                                        .shadow(color: .blue.opacity(0.5), radius: 10, x: 0, y: 4)
                                )
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 20)
                    }
                    Spacer()
                }
                .allowsHitTesting(true)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedBreakdown) { breakdown in
            StoreDetailView(storeBreakdown: breakdown)
        }
        .navigationDestination(isPresented: $showingAllStoresBreakdown) {
            AllStoresBreakdownView(period: selectedPeriod, breakdowns: currentBreakdowns)
        }
        .navigationDestination(isPresented: $showingAllTransactions) {
            TransactionListView(
                storeName: "All Stores",
                period: selectedPeriod,
                category: nil,
                categoryColor: nil
            )
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(
                selectedSort: $selectedSort
            )
        }
        .confirmationDialog(
            "Delete \(breakdownToDelete?.storeName ?? "Store")?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()

                if let breakdown = breakdownToDelete {
                    Task {
                        await deleteBreakdown(breakdown)
                    }
                }
                breakdownToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                breakdownToDelete = nil
            }
        } message: {
            Text("This will remove all transactions for this store from \(selectedPeriod). This action cannot be undone.")
        }
        .alert("Delete Failed", isPresented: .init(
            get: { dataManager.deleteError != nil },
            set: { if !$0 { dataManager.deleteError = nil } }
        )) {
            Button("OK", role: .cancel) {
                dataManager.deleteError = nil
            }
        } message: {
            Text(dataManager.deleteError ?? "An error occurred while deleting.")
        }
        .overlay {
            if dataManager.isDeleting {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Deleting...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color(white: 0.15).cornerRadius(16))
                }
            }
        }
        .onAppear {
            // Configure with transaction manager if not already configured
            if dataManager.transactionManager == nil {
                dataManager.configure(with: transactionManager)
            }
            updateDisplayedBreakdowns()
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptUploadedSuccessfully)) { _ in
            print("📬 Received receipt upload notification - refreshing backend data")
            Task {
                // Wait a moment for backend to fully process
                try? await Task.sleep(for: .seconds(1))
                await dataManager.refreshData(for: .month)
                print("✅ Backend data refreshed after receipt upload")
            }
        }
        .onChange(of: transactionManager.transactions) { oldValue, newValue in
            // Regenerate breakdowns when transactions change
            print("🔄 Transactions changed - regenerating breakdowns")
            print("   Old count: \(oldValue.count), New count: \(newValue.count)")
            dataManager.regenerateBreakdowns()
            updateDisplayedBreakdowns()
            
            // Update selected period to current month if we added new transactions
            if newValue.count > oldValue.count, let latestTransaction = newValue.first {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                let newPeriod = dateFormatter.string(from: latestTransaction.date)
                selectedPeriod = newPeriod
                print("   📅 Switched to period: \(newPeriod)")
            }
        }
        .onDisappear {
            // Exit edit mode when switching tabs or navigating away
            if isEditMode {
                isEditMode = false
            }
        }
        .onChange(of: selectedPeriod) { oldValue, newValue in
            // Exit edit mode when changing periods to avoid inconsistency
            if isEditMode {
                isEditMode = false
            }
            updateDisplayedBreakdowns()
        }
        .onChange(of: selectedSort) { oldValue, newValue in
            // Exit edit mode when changing sort to avoid inconsistency
            if isEditMode {
                isEditMode = false
            }
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
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
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
            
            // Profile button
            Menu {
                // User Email
                if let user = authManager.user {
                    Section {
                        Text(user.email ?? "No email")
                            .font(.headline)
                    }
                }
                
                // Sign Out
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            }
        }
        .padding(.horizontal)
    }
    
    private var liquidGlassPeriodFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(availablePeriods, id: \.self) { period in
                    periodButton(for: period)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    private func periodButton(for period: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                selectedPeriod = period
                // Haptic feedback
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
        } label: {
            Text(period)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(selectedPeriod == period ? Color.black : Color.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background {
                    if selectedPeriod == period {
                        Capsule()
                            .fill(Color.white)
                            .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                    }
                }
        }
        .buttonStyle(PlainButtonStyle())
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
        Button {
            showingAllStoresBreakdown = true
        } label: {
            VStack(spacing: 8) {
                Text("Total Spending")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1.2)
                
                Text(String(format: "€%.0f", totalPeriodSpending))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                
                Text(selectedPeriod)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                
                // Last updated indicator
                if let lastFetch = dataManager.lastFetchDate {
                    Text("Updated \(timeAgo(from: lastFetch))")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.white.opacity(0.4))
                        .padding(.top, 4)
                }
            }
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(TotalSpendingCardButtonStyle())
        .padding(.horizontal)
    }
    
    // Helper function to format time ago
    private func timeAgo(from date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))

        if seconds < 60 {
            return "just now"
        } else if seconds < 3600 {
            let minutes = seconds / 60
            return "\(minutes)m ago"
        } else if seconds < 86400 {
            let hours = seconds / 3600
            return "\(hours)h ago"
        } else {
            let days = seconds / 86400
            return "\(days)d ago"
        }
    }

    // MARK: - Health Score Card

    private var healthScoreCard: some View {
        // Use the average health score from the data manager (fetched from backend)
        let averageScore: Double? = dataManager.averageHealthScore

        return VStack(spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(averageScore.healthScoreColor)

                Text("Health Score")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(1)

                Spacer()

                if let score = averageScore {
                    Text(score.healthScoreLabel)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(score.healthScoreColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(score.healthScoreColor.opacity(0.15))
                        )
                }
            }

            HStack(alignment: .center, spacing: 16) {
                HealthScoreGauge(
                    score: averageScore,
                    size: 70,
                    showTrend: false,
                    showLabel: false
                )

                VStack(alignment: .leading, spacing: 6) {
                    if let score = averageScore {
                        Text("\(score.formattedHealthScore) / 5.0")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Average for \(selectedPeriod)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("No Data Yet")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))

                        Text("Upload receipts to see your health score")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private var storeBreakdownsGrid: some View {
        VStack(spacing: 0) {
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
                                .modifier(JiggleModifier(isJiggling: isEditMode && draggingItem?.id != breakdown.id))
                                .scaleEffect(draggingItem?.id == breakdown.id ? 1.05 : 1.0)
                                .opacity(draggingItem?.id == breakdown.id ? 0.5 : 1.0) // Show we're dragging
                                .zIndex(draggingItem?.id == breakdown.id ? 1 : 0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: draggingItem?.id == breakdown.id)
                                .onDrag {
                                    self.draggingItem = breakdown
                                    // Haptic feedback when starting drag
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                                    generator.impactOccurred()
                                    
                                    return NSItemProvider(object: breakdown.id as NSString)
                                }
                                .onDrop(of: [UTType.text], delegate: DropViewDelegate(
                                    destinationItem: breakdown,
                                    items: $displayedBreakdowns,
                                    draggingItem: $draggingItem,
                                    onReorder: saveCustomOrder
                                ))
                        } else {
                            // Use gesture with high priority to ensure long press works
                            storeChartCard(breakdown)
                                .contentShape(Rectangle()) // Ensure entire card area is tappable
                                .onTapGesture {
                                    selectedBreakdown = breakdown
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
                                // Show confirmation dialog
                                breakdownToDelete = breakdown
                                showingDeleteConfirmation = true
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
                            .buttonStyle(DeleteButtonStyle())
                            .offset(x: 8, y: -8)
                            .transition(.scale.combined(with: .opacity))
                            .zIndex(1)
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Spacer that catches taps in empty space (in edit mode)
            if isEditMode {
                Color.clear
                    .frame(height: 100)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isEditMode = false
                        }
                    }
            }
        }
    }
    
// MARK: - Drop Delegate for Drag and Drop Reordering
struct DropViewDelegate: DropDelegate {
    let destinationItem: StoreBreakdown
    @Binding var items: [StoreBreakdown]
    @Binding var draggingItem: StoreBreakdown?
    let onReorder: () -> Void // Callback to save order
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        // Haptic feedback on drop completion
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        draggingItem = nil
        
        // Save the new order after drop completes
        onReorder()
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem else { return }
        
        if draggingItem != destinationItem {
            let fromIndex = items.firstIndex(of: draggingItem)
            let toIndex = items.firstIndex(of: destinationItem)
            
            if let fromIndex = fromIndex, let toIndex = toIndex {
                // Haptic feedback on reorder
                let generator = UISelectionFeedbackGenerator()
                generator.selectionChanged()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    items.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                }
            }
        }
    }
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
            .padding(.top, 16)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
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

// MARK: - Jiggle Modifier for Edit Mode
struct JiggleModifier: ViewModifier {
    let isJiggling: Bool
    @State private var rotation: Double = 0
    @State private var offset: CGSize = .zero
    
    // Random but consistent values per instance
    private let rotationAngle: Double
    private let duration: Double
    private let offsetMagnitude: CGFloat
    
    init(isJiggling: Bool) {
        self.isJiggling = isJiggling
        // Slight randomization for more natural feel
        self.rotationAngle = Double.random(in: 2.0...3.0)
        self.duration = Double.random(in: 0.12...0.14)
        self.offsetMagnitude = CGFloat.random(in: 0.3...0.6)
    }
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .offset(offset)
            .task(id: isJiggling) {
                guard isJiggling else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        rotation = 0
                        offset = .zero
                    }
                    return
                }
                
                // Start with random direction for natural look
                let startRotation: Double = Bool.random() ? rotationAngle : -rotationAngle
                let startOffsetX: CGFloat = Bool.random() ? offsetMagnitude : -offsetMagnitude
                let startOffsetY: CGFloat = Bool.random() ? offsetMagnitude : -offsetMagnitude
                
                rotation = startRotation
                offset = CGSize(width: startOffsetX, height: startOffsetY)
                
                // Continuous jiggle loop with varied timing
                while isJiggling {
                    // Rotation jiggle
                    withAnimation(.easeInOut(duration: duration)) {
                        rotation = -rotation
                    }
                    
                    // Offset jiggle (slightly different timing for organic feel)
                    withAnimation(.easeInOut(duration: duration * 1.1)) {
                        offset.width = -offset.width
                        offset.height = offset.height * 0.9 // Subtle variation
                    }
                    
                    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                }
            }
    }
}

// MARK: - Store Card Button Style
struct StoreCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Total Spending Card Button Style
struct TotalSpendingCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Delete Button Style
struct DeleteButtonStyle: ButtonStyle {
    @State private var isPulsing = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.85 : (isPulsing ? 1.1 : 1.0))
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .onAppear {
                // Subtle pulse animation on appear
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

#Preview {
    NavigationStack {
        OverviewView(
            dataManager: StoreDataManager(),
            showSignOutConfirmation: .constant(false)
        )
        .environmentObject(TransactionManager())
        .environmentObject(AuthenticationManager())
    }
    .preferredColorScheme(.dark)
}
