//
//  TransactionModel.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
import Combine

struct Transaction: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let storeName: String
    let category: String
    let itemName: String
    let amount: Double
    let date: Date
    let quantity: Int
    let paymentMethod: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case storeName = "store_name"
        case category
        case itemName = "item_name"
        case amount
        case date
        case quantity
        case paymentMethod = "payment_method"
    }
}



// MARK: - Transaction Manager
class TransactionManager: ObservableObject {
    @Published var transactions: [Transaction] = []
    
    init() {
        // Start with empty transactions - data will come from Railway API
    }
    
    // Add new transactions
    func addTransactions(_ newTransactions: [Transaction]) {
        transactions.append(contentsOf: newTransactions)
        // Sort by date
        transactions.sort { $0.date > $1.date }
    }
    
    // Add a single transaction
    func addTransaction(_ transaction: Transaction) {
        transactions.append(transaction)
        transactions.sort { $0.date > $1.date }
    }
    
    // Delete a transaction
    func deleteTransaction(_ transaction: Transaction) {
        transactions.removeAll { $0.id == transaction.id }
    }
    
    // Get transactions for a specific store and period
    func transactions(for storeName: String, period: String) -> [Transaction] {
        let calendar = Calendar.current
        let periodComponents = period.components(separatedBy: " ")
        
        guard periodComponents.count == 2,
              let month = DateFormatter().monthSymbols.firstIndex(of: periodComponents[0]),
              let year = Int(periodComponents[1]) else {
            return []
        }
        
        return transactions.filter { transaction in
            let transactionComponents = calendar.dateComponents([.month, .year], from: transaction.date)
            return transaction.storeName == storeName &&
                   transactionComponents.month == month + 1 &&
                   transactionComponents.year == year
        }.sorted { $0.date > $1.date }
    }
    
    // Get transactions for a specific category
    func transactions(for storeName: String, period: String, category: String) -> [Transaction] {
        transactions(for: storeName, period: period)
            .filter { $0.category == category }
            .sorted { $0.date > $1.date }
    }
}
