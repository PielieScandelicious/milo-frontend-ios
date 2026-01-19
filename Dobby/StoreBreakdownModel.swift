//
//  StoreBreakdownModel.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
import Combine

struct StoreBreakdown: Codable, Identifiable, Equatable, Hashable {
    let storeName: String
    let period: String
    let totalStoreSpend: Double
    let categories: [Category]
    
    var id: String { "\(storeName)-\(period)" }
    
    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case period
        case totalStoreSpend = "total_store_spend"
        case categories
    }
    
    // Equatable conformance
    static func == (lhs: StoreBreakdown, rhs: StoreBreakdown) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct Category: Codable, Identifiable, Equatable, Hashable {
    let name: String
    let spent: Double
    let percentage: Int
    
    var id: String { name }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

// MARK: - Data Manager
class StoreDataManager: ObservableObject {
    @Published var storeBreakdowns: [StoreBreakdown] = []
    
    private var transactionManager: TransactionManager?
    
    init() {
        loadData()
    }
    
    // Inject transaction manager
    func configure(with transactionManager: TransactionManager) {
        self.transactionManager = transactionManager
        regenerateBreakdowns()
    }
    
    func loadData() {
        guard let url = Bundle.main.url(forResource: "store_breakdowns", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("Failed to load store_breakdowns.json")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            storeBreakdowns = try decoder.decode([StoreBreakdown].self, from: data)
        } catch {
            print("Failed to decode store breakdowns: \(error)")
        }
    }
    
    // Regenerate breakdowns from transactions
    func regenerateBreakdowns() {
        guard let transactionManager = transactionManager else { return }
        
        let transactions = transactionManager.transactions
        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        // Group by store and period
        var breakdownDict: [String: [Transaction]] = [:]
        
        for transaction in transactions {
            let period = dateFormatter.string(from: transaction.date)
            let key = "\(transaction.storeName)-\(period)"
            breakdownDict[key, default: []].append(transaction)
        }
        
        // Convert to StoreBreakdown objects
        storeBreakdowns = breakdownDict.map { key, transactions in
            let components = key.split(separator: "-")
            let storeName = String(components[0])
            let period = String(components[1])
            
            // Group by category
            let categoryDict = Dictionary(grouping: transactions, by: { $0.category })
            let totalSpend = transactions.reduce(0) { $0 + $1.amount }
            
            let categories = categoryDict.map { category, items in
                let spent = items.reduce(0) { $0 + $1.amount }
                let percentage = Int((spent / totalSpend) * 100)
                return Category(name: category, spent: spent, percentage: percentage)
            }.sorted { $0.spent > $1.spent }
            
            return StoreBreakdown(
                storeName: storeName,
                period: period,
                totalStoreSpend: totalSpend,
                categories: categories
            )
        }
    }
    
    // Group breakdowns by period for overview
    func breakdownsByPeriod() -> [String: [StoreBreakdown]] {
        Dictionary(grouping: storeBreakdowns, by: { $0.period })
    }
    
    // Calculate total spending per period
    func totalSpending(for period: String) -> Double {
        storeBreakdowns
            .filter { $0.period == period }
            .reduce(0) { $0 + $1.totalStoreSpend }
    }
    
    // Delete a store breakdown
    func deleteBreakdown(_ breakdown: StoreBreakdown) {
        storeBreakdowns.removeAll { $0.id == breakdown.id }
    }
    
    // Delete a store breakdown at specific indices
    func deleteBreakdowns(at offsets: IndexSet, from breakdowns: [StoreBreakdown]) {
        let breakdownsToDelete = offsets.map { breakdowns[$0] }
        for breakdown in breakdownsToDelete {
            deleteBreakdown(breakdown)
        }
    }
}
