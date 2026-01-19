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
    
    @StateObject private var transactionManager = TransactionManager()
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
    
    private var transactions: [Transaction] {
        let baseTransactions: [Transaction]
        if let category = category {
            baseTransactions = transactionManager.transactions(for: storeName, period: period, category: category)
        } else {
            baseTransactions = transactionManager.transactions(for: storeName, period: period)
        }
        
        // Filter by search
        let filtered = searchText.isEmpty ? baseTransactions : baseTransactions.filter {
            $0.itemName.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
        
        // Sort
        switch sortOrder {
        case .dateDescending:
            return filtered.sorted { $0.date > $1.date }
        case .dateAscending:
            return filtered.sorted { $0.date < $1.date }
        case .amountDescending:
            return filtered.sorted { $0.amount > $1.amount }
        case .amountAscending:
            return filtered.sorted { $0.amount < $1.amount }
        case .nameAscending:
            return filtered.sorted { $0.itemName < $1.itemName }
        case .nameDescending:
            return filtered.sorted { $0.itemName > $1.itemName }
        }
    }
    
    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            if transactions.isEmpty {
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
                                    TransactionTableRow(transaction: transaction)
                                    
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
                        .padding(.bottom, 32)
                    }
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

struct TransactionTableRow: View {
    let transaction: Transaction
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Date
            Text(dateFormatter.string(from: transaction.date))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
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
            Text(String(format: "€%.2f", transaction.amount))
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
