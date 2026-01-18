//
//  StoreBreakdownModel.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
import Combine

struct StoreBreakdown: Codable, Identifiable {
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
}

struct Category: Codable, Identifiable {
    let name: String
    let spent: Double
    let percentage: Int
    
    var id: String { name }
}

// MARK: - Data Manager
class StoreDataManager: ObservableObject {
    @Published var storeBreakdowns: [StoreBreakdown] = []
    
    init() {
        loadData()
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
}
