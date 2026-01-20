//
//  TransactionListView.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI

struct TransactionListView: View {
    let storeName: String
    let period: String
    let category: String?
    let categoryColor: Color?
    
    @StateObject private var transactionManager = TransactionManager()
    @Environment(\.dismiss) private var dismiss
    
    private var transactions: [Transaction] {
        if let category = category {
            return transactionManager.transactions(for: storeName, period: period, category: category)
        } else {
            return transactionManager.transactions(for: storeName, period: period)
        }
    }
    
    private var totalAmount: Double {
        transactions.reduce(0) { $0 + $1.amount }
    }
    
    private var groupedTransactions: [(String, [Transaction])] {
        let grouped = Dictionary(grouping: transactions) { transaction -> String in
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMMM d"
            return formatter.string(from: transaction.date)
        }
        return grouped.sorted { first, second in
            guard let firstDate = transactions.first(where: { transaction in
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                return formatter.string(from: transaction.date) == first.0
            })?.date,
            let secondDate = transactions.first(where: { transaction in
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                return formatter.string(from: transaction.date) == second.0
            })?.date else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        ZStack {
            Color(white: 0.05).ignoresSafeArea()
            
            if transactions.isEmpty {
                VStack(spacing: 0) {
                    // Header
                    headerSection
                    
                    emptyState
                }
            } else {
                // Full screen scrollable
                ScrollView {
                    VStack(spacing: 0) {
                        // Header
                        headerSection
                        
                        // Transaction list
                        LazyVStack(spacing: 24) {
                            ForEach(groupedTransactions, id: \.0) { date, dayTransactions in
                                transactionSection(date: date, transactions: dayTransactions)
                            }
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
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
            Image(systemName: "cart.fill.badge.questionmark")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
                .padding(.top, 60)
            
            Text("No Transactions")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)
            
            Text("No transactions found for this period")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func transactionSection(date: String, transactions: [Transaction]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Date header
            HStack {
                Text(date)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.5)
                
                Spacer()
                
                Text(String(format: "€%.0f", transactions.reduce(0) { $0 + $1.amount }))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 24)
            
            // Transaction cards
            VStack(spacing: 8) {
                ForEach(transactions) { transaction in
                    TransactionRowView(transaction: transaction)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct TransactionRowView: View {
    let transaction: Transaction
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(categoryColor(for: transaction.category).opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: categoryIcon(for: transaction.category))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(categoryColor(for: transaction.category))
            }
            
            // Item details
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.itemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
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
            }
            
            Spacer()
            
            // Amount
            Text(String(format: "€%.2f", transaction.amount))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
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

