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
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            if viewModel.state.isLoading && transactions.isEmpty {
                // Loading state
                VStack(spacing: 0) {
                    statsBar
                    controlBar
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                        .frame(maxHeight: .infinity)
                }
            } else if transactions.isEmpty {
                VStack(spacing: 0) {
                    // Summary stats
                    statsBar
                    
                    // Search and sort bar
                    controlBar
                    
                    emptyState
                }
            } else {
                // Full screen scrollable
                ScrollView {
                    VStack(spacing: 0) {
                        // Summary stats
                        statsBar
                        
                        // Search and sort bar
                        controlBar
                        
                        // Table
                        VStack(spacing: 0) {
                            // Table header
                            tableHeader
                            
                            // Table rows
                            LazyVStack(spacing: 0) {
                                ForEach(transactions) { transaction in
                                    APITransactionTableRow(transaction: transaction)
                                    
                                    Divider()
                                        .background(Color.white.opacity(0.1))
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.03))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        
                        // Load more button
                        if viewModel.hasMorePages {
                            Button {
                                Task {
                                    await viewModel.loadNextPage()
                                }
                            } label: {
                                if viewModel.state.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Load More")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search transactions")
        .toolbar {
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
    }
    
    private func loadTransactions() async {
        // Parse period to get start and end dates
        let (startDate, endDate) = parsePeriod(period)
        
        print("📋 Loading transactions for:")
        print("   Store: \(storeName)")
        print("   Period: \(period)")
        print("   Start Date: \(startDate?.description ?? "nil")")
        print("   End Date: \(endDate?.description ?? "nil")")
        print("   Category: \(category ?? "nil")")
        
        // Configure filters
        var filters = TransactionFilters()
        filters.storeName = storeName
        filters.startDate = startDate
        filters.endDate = endDate
        
        // If category is specified, try to match it to an AnalyticsCategory
        if let categoryName = category {
            filters.category = AnalyticsCategory.allCases.first { $0.displayName == categoryName }
            print("   Mapped to AnalyticsCategory: \(filters.category?.rawValue ?? "nil")")
        }
        
        await viewModel.updateFilters(filters)
    }
    
    private func parsePeriod(_ period: String) -> (Date?, Date?) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        guard let date = dateFormatter.date(from: period) else {
            print("⚠️ Failed to parse period: \(period)")
            return (nil, nil)
        }
        
        let calendar = Calendar.current
        
        // Get start of month
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        
        // Get end of month (last second of the last day)
        var endComponents = DateComponents()
        endComponents.month = 1
        endComponents.second = -1
        let endOfMonth = calendar.date(byAdding: endComponents, to: startOfMonth ?? date)
        
        print("   Parsed dates: \(startOfMonth?.description ?? "nil") to \(endOfMonth?.description ?? "nil")")
        
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
                .frame(width: 80, alignment: .leading)
            
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
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.08))
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 60)
            
            Text("No Results")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("Try adjusting your search")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxHeight: .infinity)
    }
}

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
            if let date = transaction.dateParsed {
                Text(dateFormatter.string(from: date))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, alignment: .leading)
            } else {
                Text("--")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
                    .frame(width: 80, alignment: .leading)
            }
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.itemName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(transaction.category)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quantity
            Text("\(transaction.quantity)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 40, alignment: .center)
            
            // Amount
            Text(String(format: "€%.2f", transaction.totalPrice))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.clear)
        .contentShape(Rectangle())
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
