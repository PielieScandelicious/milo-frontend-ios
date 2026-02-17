//
//  TransactionTableView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct TransactionTableView: View {
    let storeName: String
    let period: String
    let category: String?

    @StateObject private var viewModel = TransactionsViewModel()
    @State private var sortOrder: SortOrder = .dateDescending
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

    enum SortOrder: String, CaseIterable {
        case dateDescending = "Date (Newest)"
        case dateAscending = "Date (Oldest)"
        case amountDescending = "Amount (High)"
        case amountAscending = "Amount (Low)"
        case nameAscending = "Name (A-Z)"
        case nameDescending = "Name (Z-A)"
    }

    private var transactions: [APITransaction] {
        let baseTransactions = viewModel.transactions

        // Filter by search
        let filtered = searchText.isEmpty ? baseTransactions : baseTransactions.filter {
            $0.itemName.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }

        // Sort
        switch sortOrder {
        case .dateDescending:
            return filtered.sorted { ($0.dateParsed ?? Date()) > ($1.dateParsed ?? Date()) }
        case .dateAscending:
            return filtered.sorted { ($0.dateParsed ?? Date()) < ($1.dateParsed ?? Date()) }
        case .amountDescending:
            return filtered.sorted { $0.totalPrice > $1.totalPrice }
        case .amountAscending:
            return filtered.sorted { $0.totalPrice < $1.totalPrice }
        case .nameAscending:
            return filtered.sorted { $0.itemName < $1.itemName }
        case .nameDescending:
            return filtered.sorted { $0.itemName > $1.itemName }
        }
    }

    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.totalPrice }
    }

    var body: some View {
        mainContent
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                await loadTransactions()
            }
            .alert("Error", isPresented: .constant(viewModel.state.error != nil)) {
                Button("OK") { }
            } message: {
                Text(viewModel.state.error ?? "Unknown error")
            }
            .confirmationDialog("Delete Transaction", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                deleteDialogButtons
            } message: {
                Text(transactionToDelete.map { "Are you sure you want to delete \"\($0.itemName)\"? This action cannot be undone." } ?? "")
            }
            .alert("Delete Failed", isPresented: $showDeleteError) {
                Button("OK") { deleteError = nil }
            } message: {
                Text(deleteError ?? "An error occurred while deleting the transaction.")
            }
            .sheet(isPresented: $showSplitView) {
                splitSheetContent
            }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            contentForState
        }
    }

    @ViewBuilder
    private var contentForState: some View {
        if viewModel.state.isLoading && transactions.isEmpty {
            loadingState
        } else if transactions.isEmpty {
            emptyContentState
        } else {
            transactionsScrollView
        }
    }

    private var loadingState: some View {
        VStack(spacing: 0) {
            statsBar
            controlBar
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(1.5)
                .frame(maxHeight: .infinity)
        }
    }

    private var emptyContentState: some View {
        VStack(spacing: 0) {
            statsBar
            searchBar
            controlBar
            emptyState
        }
    }

    private var transactionsScrollView: some View {
        ScrollView {
            VStack(spacing: 0) {
                statsBar
                searchBar
                controlBar
                transactionsTable
                loadingIndicator
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private var transactionsTable: some View {
        VStack(spacing: 0) {
            tableHeader
            transactionsList
        }
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var transactionsList: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                TransactionRowWithMenu(
                    transaction: transaction,
                    onSplit: { transactionToSplit = transaction; showSplitView = true },
                    onDelete: { transactionToDelete = transaction; showDeleteConfirmation = true },
                    onAppear: { loadMoreIfNeeded(at: index) }
                )
                Divider().background(Color.white.opacity(0.1))
            }
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        if viewModel.state.isLoading && !viewModel.transactions.isEmpty {
            HStack {
                Spacer()
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
                Spacer()
            }
            .padding(.vertical, 20)
            .padding(.bottom, 16)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text(category ?? storeName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(period)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    @ViewBuilder
    private var deleteDialogButtons: some View {
        Button("Delete", role: .destructive) {
            if let transaction = transactionToDelete {
                Task { await deleteTransaction(transaction) }
            }
        }
        Button("Cancel", role: .cancel) { transactionToDelete = nil }
    }

    @ViewBuilder
    private var splitSheetContent: some View {
        if let transaction = transactionToSplit {
            SplitTransactionView(transaction: transaction, storeName: storeName)
        }
    }

    private func loadMoreIfNeeded(at index: Int) {
        if index == transactions.count - 1 && viewModel.hasMorePages {
            Task { await viewModel.loadNextPage() }
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

        // If category is specified, use the category name directly
        if let categoryName = category {
            filters.category = categoryName
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

    private var controlBar: some View {
        HStack(spacing: 12) {
            // Sort menu
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            sortOrder = order
                        }
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var statsBar: some View {
        HStack(spacing: 20) {
            VStack(spacing: 4) {
                Text("Transactions")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text("\(transactions.count)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Divider()
                .frame(height: 40)
                .background(Color.white.opacity(0.2))

            VStack(spacing: 4) {
                Text("Total Amount")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text(String(format: "€%.0f", totalAmount))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private var tableHeader: some View {
        HStack(spacing: 12) {
            Text("Date")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
                .frame(width: 70, alignment: .leading)

            Text("Item")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Qty")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
                .frame(width: 40, alignment: .center)

            Text("Amount")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.8)
                .frame(width: 70, alignment: .trailing)

            // Spacer for menu column
            Spacer()
                .frame(width: 40)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
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
            TextField("Search transactions", text: $searchText)
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.spring(response: 0.3), value: isSearchFocused)
    }
}

// MARK: - Transaction Row With Dropdown Menu

struct TransactionRowWithMenu: View {
    let transaction: APITransaction
    let onSplit: () -> Void
    let onDelete: () -> Void
    let onAppear: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Transaction content
            APITransactionTableRow(transaction: transaction)

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
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 32, height: 44)
                    .contentShape(Rectangle())
            }
            .padding(.trailing, 8)
        }
        .onAppear {
            onAppear()
        }
    }
}

// MARK: - Transaction Table Row

struct APITransactionTableRow: View {
    let transaction: APITransaction

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter
    }

    var body: some View {
        HStack(spacing: 12) {
            // Date
            dateText

            // Item details
            itemDetails

            // Quantity
            Text("\(transaction.quantity)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 40, alignment: .center)

            // Amount
            Text(String(format: "€%.2f", transaction.totalPrice))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .trailing)
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.vertical, 14)
        .background(Color.clear)
    }

    @ViewBuilder
    private var dateText: some View {
        if let date = transaction.dateParsed {
            Text(dateFormatter.string(from: date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 70, alignment: .leading)
        } else {
            Text("--")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 70, alignment: .leading)
        }
    }

    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(transaction.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(2)

            if let description = transaction.displayDescription {
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.45))
                    .lineLimit(2)
            }

            Text(transaction.category.localizedCategoryName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        TransactionTableView(
            storeName: "COLRUYT",
            period: "January 2026",
            category: nil
        )
    }
    .preferredColorScheme(.dark)
}
