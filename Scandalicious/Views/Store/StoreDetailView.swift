//
//  StoreDetailView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct StoreDetailView: View {
    let storeBreakdown: StoreBreakdown
    var storeColor: Color = Color(red: 0.3, green: 0.7, blue: 1.0)  // Default to blue if not provided
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: String?
    @State private var selectedCategoryColor: Color?
    // Removed showingAllTransactions - header no longer navigates
    @State private var showingCategoryTransactions = false
    @State private var showingReceipts = false

    // Live data that can be refreshed from backend
    @State private var currentTotalSpend: Double = 0
    @State private var currentVisitCount: Int = 0
    @State private var currentCategories: [Category] = []
    @State private var currentHealthScore: Double?
    @State private var currentTotalItems: Int = 0
    @State private var isRefreshing = false
    @State private var hasInitialized = false

    // Expandable receipts section
    @StateObject private var receiptsViewModel = ReceiptsViewModel()
    @State private var isReceiptsSectionExpanded = false
    @State private var expandedReceiptId: String?
    @State private var isDeletingReceipt = false
    @State private var receiptDeleteError: String?

    // Expandable transactions section (for bank-imported transactions)
    @State private var isTransactionsSectionExpanded = false

    // Split expense
    @State private var receiptToSplit: APIReceipt?

    // Expandable category transactions
    @StateObject private var transactionsViewModel = TransactionsViewModel()
    @State private var expandedCategoryName: String?
    @State private var categoryTransactions: [String: [APITransaction]] = [:]
    @State private var loadingCategories: Set<String> = []

    // Split cache for displaying friend avatars on transactions
    @ObservedObject private var splitCache = SplitCacheManager.shared

    // Accent color for the line chart - modern red
    private var chartAccentColor: Color {
        Color(red: 0.95, green: 0.25, blue: 0.3)
    }

    // Backend-provided average item price (set during refresh)
    @State private var backendAverageItemPrice: Double?

    // Average item price - prefers backend value, falls back to local calculation
    private var averageItemPrice: Double? {
        // Use backend-computed value if available
        if let backendPrice = backendAverageItemPrice {
            return backendPrice
        }
        // Fallback: compute locally
        guard currentTotalItems > 0 else { return nil }
        return currentTotalSpend / Double(currentTotalItems)
    }

    // Store accent color for header border - uses the color from donut chart segment
    private var storeAccentColor: Color {
        storeColor
    }

    // Top 5 categories + "Other" grouping - uses refreshable currentCategories
    private var groupedChartSegments: [ChartSegment] {
        let sortedCategories = currentCategories.sorted { $0.spent > $1.spent }

        if sortedCategories.count <= 5 {
            return sortedCategories.toChartSegments()
        }

        // Take top 5 and sum the rest into "Other"
        let top5 = Array(sortedCategories.prefix(5))
        let remaining = Array(sortedCategories.dropFirst(5))
        let otherSpent = remaining.reduce(0) { $0 + $1.spent }
        let totalSpent = sortedCategories.reduce(0) { $0 + $1.spent }
        let otherPercentage = totalSpent > 0 ? Int((otherSpent / totalSpent) * 100) : 0

        // Create a Category for "Other"
        let otherCategory = Category(name: "Other", spent: otherSpent, percentage: otherPercentage)

        // Combine top 5 + Other and convert to segments
        let combinedCategories = top5 + [otherCategory]
        return combinedCategories.toChartSegments()
    }

    // MARK: - Store Header with Nutri Score

    private var storeHeader: some View {
        let scoreColor = currentHealthScore?.healthScoreColor ?? Color(white: 0.4)
        let nutriLetter: String = {
            guard let score = currentHealthScore else { return "-" }
            return Int(score.rounded()).nutriScoreLetter
        }()

        return HStack(spacing: 0) {
            // Left side: Store info
            VStack(alignment: .leading, spacing: 6) {
                Text(storeBreakdown.storeName)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(storeBreakdown.period == "All" ? "All Time" : storeBreakdown.period)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))

                Text(String(format: "€%.0f", currentTotalSpend))
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, 2)

                Text("\(currentVisitCount) receipt\(currentVisitCount == 1 ? "" : "s")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Right side: Nutri Score
            VStack(spacing: 8) {
                if currentHealthScore != nil {
                    // Has score - show the letter grade
                    ZStack {
                        Circle()
                            .fill(scoreColor.opacity(0.15))
                            .frame(width: 64, height: 64)

                        Circle()
                            .stroke(scoreColor, lineWidth: 3)
                            .frame(width: 64, height: 64)

                        Text(nutriLetter)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                    }
                } else {
                    // No score - show clean N/A state
                    ZStack {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 64, height: 64)

                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            .frame(width: 64, height: 64)

                        Text("N/A")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.35))
                    }
                }

                Text("NUTRI SCORE")
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundColor(currentHealthScore != nil ? scoreColor : .white.opacity(0.35))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(storeAccentColor.opacity(0.25), lineWidth: 1)
        )
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Sleek header card with Nutri Score
                    storeHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Donut chart section
                    FlippableDonutChartView(
                        title: "",
                        subtitle: currentVisitCount == 1 ? "receipt" : "receipts",
                        totalAmount: Double(currentVisitCount),
                        segments: groupedChartSegments,
                        size: 200,
                        accentColor: chartAccentColor,
                        selectedPeriod: storeBreakdown.period,
                        averageItemPrice: averageItemPrice
                    )
                    .padding(.top, 24)

                    // Categories Section Header
                    categoriesSectionHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    // Expandable category rows
                    VStack(spacing: 8) {
                        ForEach(Array(groupedChartSegments.enumerated()), id: \.element.id) { _, segment in
                            expandableCategoryRow(segment: segment, isOther: segment.label == "Other")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Expandable Receipts Section
                    receiptsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                    // Expandable Transactions Section (Bank-Imported)
                    transactionsSection
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    // Bottom spacing
                    Color.clear.frame(height: 32)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showingCategoryTransactions) {
            TransactionListView(
                storeName: storeBreakdown.storeName,
                period: storeBreakdown.period,
                category: selectedCategory,
                categoryColor: selectedCategoryColor
            )
        }
        .navigationDestination(isPresented: $showingReceipts) {
            ReceiptsListView(
                period: storeBreakdown.period,
                storeName: storeBreakdown.storeName
            )
        }
        .sheet(item: $receiptToSplit) { receipt in
            SplitExpenseView(receipt: receipt.toReceiptUploadResponse())
        }
        .onAppear {
            if !hasInitialized {
                // First appearance: initialize state from the passed-in breakdown
                currentTotalSpend = storeBreakdown.totalStoreSpend
                currentVisitCount = storeBreakdown.visitCount
                currentCategories = storeBreakdown.categories
                currentHealthScore = storeBreakdown.averageHealthScore
                currentTotalItems = 0  // Will be populated when we fetch detailed data
                hasInitialized = true
                // Fetch detailed data to get item count
                Task {
                    await refreshStoreData()
                }
                // Load receipts and transactions on first appearance
                loadReceipts()
            } else {
                // Subsequent appearances (navigating back): refresh from backend
                // This handles the case where a receipt was deleted in ReceiptsListView
                print("🔄 [StoreDetailView] Re-appeared - refreshing from backend")
                Task {
                    await refreshStoreData()
                }
                // Reload receipts when returning to view
                loadReceipts()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDataDidChange)) { _ in
            print("🗑️ [StoreDetailView] Received receiptsDataDidChange - refreshing store data")
            Task {
                // Wait for backend to process the change
                try? await Task.sleep(for: .seconds(0.5))
                await refreshStoreData()
            }
        }
    }

    // MARK: - Refresh Store Data from Backend

    private func refreshStoreData() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            // Create filters for this store
            var filters = AnalyticsFilters()
            filters.storeName = storeBreakdown.storeName

            // Handle "All" period - no date filtering
            if storeBreakdown.period == "All" {
                filters.period = .all
                print("📡 [StoreDetailView] Fetching all-time data for \(storeBreakdown.storeName)")
            } else {
                // Parse the period to get date range
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MMMM yyyy"
                dateFormatter.locale = Locale(identifier: "en_US")
                dateFormatter.timeZone = TimeZone(identifier: "UTC")

                guard let parsedDate = dateFormatter.date(from: storeBreakdown.period) else {
                    print("❌ [StoreDetailView] Could not parse period: \(storeBreakdown.period)")
                    return
                }

                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!

                let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
                let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

                filters.period = .month
                filters.startDate = startOfMonth
                filters.endDate = endOfMonth
                print("📡 [StoreDetailView] Fetching fresh data for \(storeBreakdown.storeName)")
            }

            let storeDetails = try await AnalyticsAPIService.shared.getStoreDetails(
                storeName: storeBreakdown.storeName,
                filters: filters
            )

            // Convert categories
            let categories = storeDetails.categories.map { categoryBreakdown in
                Category(
                    name: categoryBreakdown.name,
                    spent: categoryBreakdown.spent,
                    percentage: Int(categoryBreakdown.percentage)
                )
            }

            // Use backend totalItems if available, otherwise calculate from category transaction counts
            let totalItems = storeDetails.totalItems ?? storeDetails.categories.reduce(0) { $0 + $1.transactionCount }

            // Update state on main thread
            await MainActor.run {
                currentTotalSpend = storeDetails.totalSpend
                currentVisitCount = storeDetails.visitCount
                currentCategories = categories
                currentHealthScore = storeDetails.averageHealthScore
                currentTotalItems = totalItems
                backendAverageItemPrice = storeDetails.averageItemPrice  // Use backend value if available
                print("✅ [StoreDetailView] Updated: €\(storeDetails.totalSpend), \(storeDetails.visitCount) receipts, \(totalItems) items, avg price: \(storeDetails.averageItemPrice.map { String(format: "€%.2f", $0) } ?? "computed locally")")
            }

        } catch {
            print("❌ [StoreDetailView] Failed to refresh store data: \(error.localizedDescription)")
        }
    }

    // MARK: - Categories Section Header

    private var categoriesSectionHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 36, height: 36)
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Categories")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Text("\(currentCategories.count) categories")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()
        }
    }

    // MARK: - Expandable Receipts Section

    private var receiptsSection: some View {
        VStack(spacing: 0) {
            // Header button with glass-morphism
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isReceiptsSectionExpanded.toggle()
                }
                if isReceiptsSectionExpanded && receiptsViewModel.receipts.isEmpty {
                    loadReceipts()
                }
            } label: {
                HStack(spacing: 14) {
                    // Receipt icon
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 40, height: 40)

                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }

                    // Title
                    Text("Receipts")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Count badge (only actual receipts)
                    if actualReceipts.count > 0 {
                        Text("\(actualReceipts.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                            )
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isReceiptsSectionExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Glass base
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.04))

                        // Gradient overlay
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ReceiptsHeaderButtonStyle())

            // Expanded receipts list (no container background)
            if isReceiptsSectionExpanded {
                VStack(spacing: 12) {
                    if receiptsViewModel.state.isLoading && actualReceipts.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.0)
                            Text("Loading receipts...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else if actualReceipts.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No Receipts")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("No receipts found for this store")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(sortedReceipts) { receipt in
                                ExpandableReceiptCard(
                                    receipt: receipt,
                                    isExpanded: expandedReceiptId == receipt.id,
                                    onTap: {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            if expandedReceiptId == receipt.id {
                                                expandedReceiptId = nil
                                            } else {
                                                expandedReceiptId = receipt.id
                                            }
                                        }
                                    },
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            deleteReceipt(receipt)
                                        }
                                    },
                                    onDeleteItem: { receiptId, itemId in
                                        deleteReceiptItem(receiptId: receiptId, itemId: itemId)
                                    },
                                    onSplit: {
                                        receiptToSplit = receipt
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: receiptsViewModel.receipts.count)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
    }

    // MARK: - Filtered Receipts and Transactions

    /// Actual scanned receipts (source == receiptUpload)
    private var actualReceipts: [APIReceipt] {
        receiptsViewModel.receipts
            .filter { $0.source == .receiptUpload }
            .sorted { receipt1, receipt2 in
                let date1 = receipt1.dateParsed ?? Date.distantPast
                let date2 = receipt2.dateParsed ?? Date.distantPast
                return date1 > date2
            }
    }

    /// Bank-imported transactions (source == bankImport)
    private var bankTransactions: [APIReceipt] {
        receiptsViewModel.receipts
            .filter { $0.source == .bankImport }
            .sorted { receipt1, receipt2 in
                let date1 = receipt1.dateParsed ?? Date.distantPast
                let date2 = receipt2.dateParsed ?? Date.distantPast
                return date1 > date2
            }
    }

    private var sortedReceipts: [APIReceipt] {
        actualReceipts
    }

    // MARK: - Transactions Section (Bank-Imported)

    private var transactionsSection: some View {
        VStack(spacing: 0) {
            // Header button with glass-morphism
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isTransactionsSectionExpanded.toggle()
                }
                if isTransactionsSectionExpanded && receiptsViewModel.receipts.isEmpty {
                    loadReceipts()
                }
            } label: {
                HStack(spacing: 14) {
                    // Transaction icon
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.15))
                            .frame(width: 40, height: 40)

                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color(red: 0.3, green: 0.7, blue: 1.0))
                    }

                    // Title
                    Text("Transactions")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    // Count badge
                    if bankTransactions.count > 0 {
                        Text("\(bankTransactions.count)")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.2))
                            )
                    }

                    // Chevron
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.4))
                        .rotationEffect(.degrees(isTransactionsSectionExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    ZStack {
                        // Glass base
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.04))

                        // Gradient overlay
                        RoundedRectangle(cornerRadius: 20)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [Color(red: 0.3, green: 0.7, blue: 1.0).opacity(0.3), Color.white.opacity(0.04)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(ReceiptsHeaderButtonStyle())

            // Expanded transactions list
            if isTransactionsSectionExpanded {
                VStack(spacing: 12) {
                    if receiptsViewModel.state.isLoading && bankTransactions.isEmpty {
                        HStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.0)
                            Text("Loading transactions...")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    } else if bankTransactions.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.3))
                            Text("No Transactions")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                            Text("No bank transactions found for this store")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(bankTransactions) { transaction in
                                BankTransactionCard(
                                    receipt: transaction,
                                    onDelete: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            deleteReceipt(transaction)
                                        }
                                    },
                                    onSplit: {
                                        receiptToSplit = transaction
                                    }
                                )
                                .transition(.asymmetric(
                                    insertion: .opacity,
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: bankTransactions.count)
                    }
                }
                .padding(.top, 12)
                .transition(.opacity)
            }
        }
    }

    private func loadReceipts() {
        Task {
            await receiptsViewModel.loadReceipts(period: storeBreakdown.period, storeName: storeBreakdown.storeName)
        }
    }

    private func deleteReceipt(_ receipt: APIReceipt) {
        isDeletingReceipt = true
        Task {
            do {
                try await receiptsViewModel.deleteReceipt(receipt, period: storeBreakdown.period, storeName: storeBreakdown.storeName)
                NotificationCenter.default.post(name: .receiptsDataDidChange, object: nil)
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                receiptDeleteError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
            isDeletingReceipt = false
        }
    }

    private func deleteReceiptItem(receiptId: String, itemId: String) {
        Task {
            do {
                try await receiptsViewModel.deleteReceiptItem(receiptId: receiptId, itemId: itemId)
            } catch {
                receiptDeleteError = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    // MARK: - Expandable Category Row

    private func expandableCategoryRow(segment: ChartSegment, isOther: Bool) -> some View {
        VStack(spacing: 0) {
            // Category header button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if expandedCategoryName == segment.label {
                        expandedCategoryName = nil
                    } else {
                        expandedCategoryName = segment.label
                        loadCategoryTransactions(category: segment.label)
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Color accent bar on the left (matching StoreRowButton)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isOther ? segment.color.opacity(0.5) : segment.color)
                        .frame(width: 4, height: 32)

                    Text(segment.label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(isOther ? .white.opacity(0.5) : .white)
                        .lineLimit(1)

                    Spacer()

                    // Percentage badge with colored background (matching StoreRowButton)
                    Text("\(segment.percentage)%")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(isOther ? .white.opacity(0.4) : segment.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(isOther ? Color.white.opacity(0.05) : segment.color.opacity(0.15))
                        )

                    Text(String(format: "€%.0f", segment.value))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(isOther ? .white.opacity(0.5) : .white)
                        .frame(width: 65, alignment: .trailing)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.25))
                        .rotationEffect(.degrees(expandedCategoryName == segment.label ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .buttonStyle(CategoryRowButtonStyle())

            // Expanded transactions list
            if expandedCategoryName == segment.label {
                VStack(spacing: 0) {
                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 1)
                        .padding(.horizontal, 14)

                    VStack(spacing: 8) {
                        if loadingCategories.contains(segment.label) {
                            HStack(spacing: 10) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.6)))
                                    .scaleEffect(0.7)
                                Text("Loading...")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .padding(.vertical, 16)
                        } else if let transactions = categoryTransactions[segment.label], !transactions.isEmpty {
                            // Sort by health score (healthiest first), then alphabetically
                            let sortedTransactions = transactions.sorted { t1, t2 in
                                let score1 = t1.healthScore
                                let score2 = t2.healthScore
                                // Both have scores - sort by score descending (higher = healthier first)
                                if let s1 = score1, let s2 = score2 {
                                    return s1 > s2
                                }
                                // Item with score comes before item without score
                                if score1 != nil && score2 == nil { return true }
                                if score1 == nil && score2 != nil { return false }
                                // Neither has score - sort alphabetically
                                return t1.itemName.localizedCaseInsensitiveCompare(t2.itemName) == .orderedAscending
                            }
                            ForEach(sortedTransactions) { transaction in
                                // Get split participants for this transaction
                                let splitParticipants: [SplitParticipantInfo] = {
                                    guard let receiptId = transaction.receiptId else { return [] }
                                    guard let splitData = splitCache.getSplit(for: receiptId) else { return [] }
                                    return splitData.participantsForTransaction(transaction.id)
                                }()
                                let friendsOnly = splitParticipants.filter { !$0.isMe }

                                HStack(spacing: 10) {
                                    // Sleek Nutri-Score letter badge (matching receipt style)
                                    Text(transaction.healthScore.nutriScoreLetter)
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundColor(transaction.healthScore.healthScoreColor)
                                        .frame(width: 16, height: 16)
                                        .background(
                                            Circle()
                                                .fill(transaction.healthScore.healthScoreColor.opacity(0.15))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(transaction.healthScore.healthScoreColor.opacity(0.3), lineWidth: 0.5)
                                        )

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text(transaction.itemName)
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.white.opacity(0.85))
                                                .lineLimit(1)

                                            if transaction.quantity > 1 {
                                                Text("×\(transaction.quantity)")
                                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                                    .foregroundColor(.white.opacity(0.4))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(
                                                        Capsule()
                                                            .fill(Color.white.opacity(0.08))
                                                    )
                                            }

                                            // Split participant avatars
                                            if !friendsOnly.isEmpty {
                                                MiniSplitAvatars(participants: friendsOnly)
                                            }
                                        }
                                    }

                                    Spacer()

                                    Text(String(format: "€%.2f", transaction.totalPrice))
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .task {
                                    // Fetch split data if we have a receipt ID and it's not cached
                                    if let receiptId = transaction.receiptId, !splitCache.hasSplit(for: receiptId) {
                                        await splitCache.fetchSplit(for: receiptId)
                                    }
                                }
                            }
                        } else {
                            Text("No transactions")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.4))
                                .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)
                }
                .transition(.opacity)
            }
        }
        .background(
            ZStack {
                // Base glass effect
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.04))

                // Subtle gradient
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.02)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Colored accent glow on the left (matching StoreRowButton)
                if !isOther {
                    HStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        segment.color.opacity(0.15),
                                        Color.clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 60)
                        Spacer()
                    }
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(expandedCategoryName == segment.label ? 0.15 : 0.1),
                            Color.white.opacity(expandedCategoryName == segment.label ? 0.06 : 0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    private func loadCategoryTransactions(category: String) {
        guard categoryTransactions[category] == nil else { return }

        loadingCategories.insert(category)

        Task {
            do {
                var filters = TransactionFilters()
                filters.storeName = storeBreakdown.storeName
                filters.category = AnalyticsCategory.allCases.first { $0.displayName == category }
                filters.pageSize = 100

                // Handle "All" period - no date filtering
                if storeBreakdown.period != "All" {
                    // Parse the period to get date range
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "MMMM yyyy"
                    dateFormatter.locale = Locale(identifier: "en_US")
                    dateFormatter.timeZone = TimeZone(identifier: "UTC")

                    guard let parsedDate = dateFormatter.date(from: storeBreakdown.period) else {
                        loadingCategories.remove(category)
                        return
                    }

                    var calendar = Calendar(identifier: .gregorian)
                    calendar.timeZone = TimeZone(identifier: "UTC")!

                    let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: parsedDate))!
                    let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!

                    filters.startDate = startOfMonth
                    filters.endDate = endOfMonth
                }

                let response = try await AnalyticsAPIService.shared.getTransactions(filters: filters)

                await MainActor.run {
                    categoryTransactions[category] = response.transactions
                    loadingCategories.remove(category)
                }
            } catch {
                print("❌ Failed to load transactions for \(category): \(error)")
                await MainActor.run {
                    loadingCategories.remove(category)
                }
            }
        }
    }

    private func categoryRow(segment: ChartSegment, isOther: Bool = false) -> some View {
        HStack {
            Circle()
                .fill(segment.color)
                .frame(width: 12, height: 12)

            Text(segment.label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isOther ? .white.opacity(0.7) : .white)

            Spacer()

            Text("\(segment.percentage)%")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 45, alignment: .trailing)

            Text(String(format: "€%.0f", segment.value))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(isOther ? .white.opacity(0.7) : .white)
                .frame(width: 70, alignment: .trailing)

            if !isOther {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.3))
            } else {
                // Placeholder to maintain alignment
                Color.clear
                    .frame(width: 12)
            }
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
        StoreDetailView(
            storeBreakdown: StoreBreakdown(
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
            ),
            storeColor: Color(red: 0.3, green: 0.7, blue: 1.0)  // Blue from donut chart
        )
    }
    .preferredColorScheme(.dark)
}
