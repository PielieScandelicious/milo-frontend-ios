//
//  TransactionListView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

enum TransactionSortOrder {
    case date
    case healthScoreDescending // Healthiest first (5 -> 0 -> nil)
}

struct TransactionListView: View {
    let storeName: String
    let period: String
    let category: String?
    let categoryColor: Color?
    var sortOrder: TransactionSortOrder = .date

    @StateObject private var viewModel = TransactionsViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    // Delete states
    @State private var transactionToDelete: APITransaction?
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showDeleteError = false

    // Split states
    @State private var transactionToSplit: APITransaction?
    @State private var showSplitView = false

    private var transactions: [APITransaction] {
        var baseTransactions = viewModel.transactions

        // Apply sorting based on sortOrder
        if sortOrder == .healthScoreDescending {
            baseTransactions.sort { first, second in
                // Health score sorting: highest first (5 -> 0), nil values last
                switch (first.healthScore, second.healthScore) {
                case (nil, nil): return false
                case (nil, _): return false  // nil goes last
                case (_, nil): return true   // non-nil comes before nil
                case (let a?, let b?): return a > b  // Higher score first
                }
            }
        }

        // Filter by search text
        if searchText.isEmpty {
            return baseTransactions
        } else {
            return baseTransactions.filter {
                $0.itemName.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.totalPrice }
    }

    private var groupedTransactions: [(String, [APITransaction])] {
        // When sorting by health score, group by score ranges instead of dates
        if sortOrder == .healthScoreDescending {
            let grouped = Dictionary(grouping: transactions) { transaction -> String in
                guard let score = transaction.healthScore else { return "Non-Food Items" }
                switch score {
                case 5: return "Very Healthy"
                case 4: return "Healthy"
                case 3: return "Moderate"
                case 2: return "Less Healthy"
                case 1: return "Unhealthy"
                case 0: return "Very Unhealthy"
                default: return "Other"
                }
            }
            // Sort groups by health score order (highest first)
            let order = ["Very Healthy", "Healthy", "Moderate", "Less Healthy", "Unhealthy", "Very Unhealthy", "Non-Food Items"]
            return grouped.sorted { first, second in
                let firstIndex = order.firstIndex(of: first.0) ?? order.count
                let secondIndex = order.firstIndex(of: second.0) ?? order.count
                return firstIndex < secondIndex
            }
        }

        // Default: group by date
        let grouped = Dictionary(grouping: transactions) { transaction -> String in
            guard let date = transaction.dateParsed else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: date)
        }
        return grouped.sorted { first, second in
            guard let firstDate = transactions.first(where: { transaction in
                guard let date = transaction.dateParsed else { return false }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                return formatter.string(from: date) == first.0
            })?.dateParsed,
            let secondDate = transactions.first(where: { transaction in
                guard let date = transaction.dateParsed else { return false }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                return formatter.string(from: date) == second.0
            })?.dateParsed else {
                return false
            }
            return firstDate > secondDate
        }
    }

    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()

            if viewModel.state.isLoading && transactions.isEmpty {
                // Loading state
                VStack(spacing: 0) {
                    if sortOrder != .healthScoreDescending {
                        headerSection
                    }

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .frame(maxHeight: .infinity)
                }
            } else if transactions.isEmpty {
                VStack(spacing: 0) {
                    // Header (hidden for health score view)
                    if sortOrder != .healthScoreDescending {
                        headerSection
                    }

                    // Search bar
                    searchBar

                    emptyState
                }
            } else {
                // Full screen scrollable
                ScrollView {
                    VStack(spacing: 0) {
                        // Header (hidden for health score view)
                        if sortOrder != .healthScoreDescending {
                            headerSection
                        }

                        // Search bar
                        searchBar

                        // Transaction list
                        LazyVStack(spacing: 24) {
                            ForEach(groupedTransactions, id: \.0) { date, dayTransactions in
                                transactionSection(date: date, transactions: dayTransactions)
                                    .onAppear {
                                        // Auto-load more when reaching near the end
                                        if date == groupedTransactions.last?.0 && viewModel.hasMorePages {
                                            Task {
                                                await viewModel.loadNextPage()
                                            }
                                        }
                                    }
                            }

                            // Loading indicator at bottom when fetching more
                            if viewModel.state.isLoading && !viewModel.transactions.isEmpty {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.2)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text(sortOrder == .healthScoreDescending ? "Health Score" : (category ?? storeName))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)

                    Text(period)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .task {
            await loadTransactions()
        }
        .alert("Error", isPresented: .constant(viewModel.state.error != nil)) {
            Button("OK") { }
        } message: {
            if let error = viewModel.state.error {
                Text(error)
            }
        }
        // Delete confirmation
        .confirmationDialog("Delete Transaction", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let transaction = transactionToDelete {
                    Task { await deleteTransaction(transaction) }
                }
            }
            Button("Cancel", role: .cancel) { transactionToDelete = nil }
        } message: {
            Text(transactionToDelete.map { "Are you sure you want to delete \"\($0.itemName)\"? This action cannot be undone." } ?? "")
        }
        // Delete error alert
        .alert("Delete Failed", isPresented: $showDeleteError) {
            Button("OK") { deleteError = nil }
        } message: {
            Text(deleteError ?? "An error occurred while deleting the transaction.")
        }
        // Split expense sheet
        .sheet(isPresented: $showSplitView) {
            if let transaction = transactionToSplit {
                SplitTransactionView(transaction: transaction, storeName: storeName)
            }
        }
    }

    // MARK: - Delete Transaction

    private func deleteTransaction(_ transaction: APITransaction) async {
        isDeleting = true
        do {
            try await viewModel.deleteTransaction(transaction)
            transactionToDelete = nil
        } catch {
            deleteError = error.localizedDescription
            showDeleteError = true
        }
        isDeleting = false
    }

    private func loadTransactions() async {
        // Parse period to get start and end dates
        let (startDate, endDate) = parsePeriod(period)

        // Configure filters
        var filters = TransactionFilters()

        // Only filter by store name if it's not "All Stores"
        if storeName != "All Stores" {
            filters.storeName = storeName
        }

        filters.startDate = startDate
        filters.endDate = endDate

        // If category is specified, try to match it to an AnalyticsCategory
        if let categoryName = category {
            filters.category = AnalyticsCategory.allCases.first { $0.displayName == categoryName }
        }

        await viewModel.updateFilters(filters)
    }

    private func parsePeriod(_ period: String) -> (Date?, Date?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = TimeZone(identifier: "UTC") // Use UTC to avoid timezone shifts

        guard let date = dateFormatter.date(from: period) else {
            return (nil, nil)
        }

        // Use UTC calendar to avoid timezone issues
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        // Get start of month
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))

        // Get end of month (last second of the last day)
        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.second = -1
        let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth ?? date)

        return (startOfMonth, endOfMonth)
    }

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Category indicator if present
            if let category = category, let color = categoryColor {
                HStack(spacing: 12) {
                    Circle()
                        .fill(color)
                        .frame(width: 12, height: 12)

                    Text(category)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }

            // Total amount
            VStack(spacing: 8) {
                Text("Total Transactions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(1)

                Text(String(format: "€%.0f", totalAmount))
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("\(transactions.count) transaction\(transactions.count == 1 ? "" : "s")")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [
                                (categoryColor ?? Color.blue).opacity(0.2),
                                (categoryColor ?? Color.purple).opacity(0.1)
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
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "cart.fill.badge.questionmark" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 60)

            Text(searchText.isEmpty ? "No Transactions" : "No Results")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Text(searchText.isEmpty ? "No transactions found for this period" : "Try adjusting your search")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(searchText.isEmpty ? .white.opacity(0.4) : .white.opacity(0.6))

            // Text field
            TextField("Search Items", text: $searchText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .accentColor(.blue)
                .focused($isSearchFocused)
                .autocorrectionDisabled()

            // Clear button
            if !searchText.isEmpty {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        searchText = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isSearchFocused ? Color.blue.opacity(0.5) : Color.white.opacity(0.15),
                    lineWidth: isSearchFocused ? 2 : 1
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
        .animation(.spring(response: 0.3), value: isSearchFocused)
    }

    private func transactionSection(date: String, transactions: [APITransaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header
            HStack {
                Text(date)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Text(String(format: "€%.0f", transactions.reduce(0) { $0 + $1.totalPrice }))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)

            // Transaction cards with dropdown menu
            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionCardWithMenu(
                        transaction: transaction,
                        onSplit: {
                            transactionToSplit = transaction
                            showSplitView = true
                        },
                        onDelete: {
                            transactionToDelete = transaction
                            showDeleteConfirmation = true
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Transaction Card With Dropdown Menu

struct TransactionCardWithMenu: View {
    let transaction: APITransaction
    let onSplit: () -> Void
    let onDelete: () -> Void

    @ObservedObject private var splitCache = SplitCacheManager.shared

    /// Get split participants for this transaction
    private var splitParticipants: [SplitParticipantInfo] {
        guard let receiptId = transaction.receiptId,
              let splitData = splitCache.getSplit(for: receiptId) else {
            return []
        }
        return splitData.participantsForTransaction(transaction.id)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Transaction card content
            APITransactionRowView(transaction: transaction, splitParticipants: splitParticipants)

            // Dropdown menu button
            Menu {
                Button {
                    onSplit()
                } label: {
                    Label("Split with Friends", systemImage: "person.2.fill")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 44, height: 44)

                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 44, height: 44)
            }
            .padding(.leading, 8)
        }
        .task {
            // Fetch split data if we have a receipt ID and it's not cached
            if let receiptId = transaction.receiptId, !splitCache.hasSplit(for: receiptId) {
                await splitCache.fetchSplit(for: receiptId)
            }
        }
    }
}

struct APITransactionRowView: View {
    let transaction: APITransaction
    var splitParticipants: [SplitParticipantInfo] = []

    /// Filter out "Me" - only show friends
    private var friendsOnly: [SplitParticipantInfo] {
        splitParticipants.filter { !$0.isMe }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon with quantity badge
            ZStack(alignment: .topTrailing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(categoryColor(for: transaction.category).opacity(0.2))
                        .frame(width: 50, height: 50)

                    Image(systemName: categoryIcon(for: transaction.category))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(categoryColor(for: transaction.category))
                }

                // Quantity badge (only show if quantity > 1)
                if transaction.quantity > 1 {
                    Text("×\(transaction.quantity)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(categoryColor(for: transaction.category))
                        )
                        .offset(x: 6, y: -4)
                }
            }
            .frame(width: 50, height: 50)

            // Item details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Text(transaction.itemName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .fixedSize(horizontal: true, vertical: false)

                            // Split participant avatars (inline with item name)
                            if !friendsOnly.isEmpty {
                                TransactionSplitAvatars(participants: friendsOnly)
                            }
                        }
                    }

                    // Health Score Badge
                    HealthScoreBadge(score: transaction.healthScore, size: .small, style: .subtle)
                }

                HStack(spacing: 8) {
                    Text(transaction.category)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))

                    if transaction.quantity > 1 {
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))

                        Text("Qty: \(transaction.quantity)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }

                // Unit price (only show if quantity > 1 and unitPrice is available)
                if let unitPrice = transaction.unitPrice, transaction.quantity > 1 {
                    Text(unitPrice, format: .currency(code: "EUR"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Amount and Health Score
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "€%.2f", transaction.totalPrice))
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Health score label
                if let score = transaction.healthScore {
                    Text(score.healthScoreShortLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(score.healthScoreColor)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Meat & Fish": return "fish.fill"
        case "Alcohol": return "wineglass.fill"
        case "Drinks (Soft/Soda)", "Drinks (Water)": return "cup.and.saucer.fill"
        case "Household": return "house.fill"
        case "Snacks & Sweets": return "birthday.cake.fill"
        case "Fresh Produce": return "leaf.fill"
        case "Dairy & Eggs": return "cup.and.saucer.fill"
        case "Ready Meals": return "takeoutbag.and.cup.and.straw.fill"
        case "Bakery": return "birthday.cake.fill"
        case "Pantry": return "cabinet.fill"
        case "Personal Care": return "sparkles"
        default: return "cart.fill"
        }
    }

    private func categoryColor(for category: String) -> Color {
        // Use the smart category color extension
        return category.categoryColor
    }
}

// MARK: - Transaction Split Avatars

/// Compact display of friend avatars for split transactions (excludes "Me")
struct TransactionSplitAvatars: View {
    let participants: [SplitParticipantInfo]

    /// Maximum avatars to show before "+N"
    private let maxVisible = 3

    var body: some View {
        if !participants.isEmpty {
            HStack(spacing: -4) {
                // Show up to maxVisible avatars
                ForEach(Array(participants.prefix(maxVisible).enumerated()), id: \.element.id) { index, participant in
                    Circle()
                        .fill(participant.swiftUIColor)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text(String(participant.name.prefix(1)).uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.1), lineWidth: 1)
                        )
                        .zIndex(Double(maxVisible - index))
                }

                // Show "+N" if more participants
                if participants.count > maxVisible {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 16, height: 16)
                        .overlay(
                            Text("+\(participants.count - maxVisible)")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color(white: 0.1), lineWidth: 1)
                        )
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        TransactionListView(
            storeName: "COLRUYT",
            period: "January 2026",
            category: "Meat & Fish",
            categoryColor: Color(red: 0.9, green: 0.4, blue: 0.4)
        )
    }
    .preferredColorScheme(.dark)
}
