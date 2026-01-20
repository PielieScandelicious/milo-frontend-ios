//
//  StoreBreakdownModel.swift
//  dobby-ios
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
    let visitCount: Int
    
    var id: String { "\(storeName)-\(period)" }
    
    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case period
        case totalStoreSpend = "total_store_spend"
        case categories
        case visitCount = "visit_count"
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
    @Published var isLoading = false
    @Published var error: String?
    
    private var transactionManager: TransactionManager?
    
    init() {
        // Don't load local JSON anymore - will fetch from backend
    }
    
    // Inject transaction manager
    func configure(with transactionManager: TransactionManager) {
        self.transactionManager = transactionManager
    }
    
    // MARK: - Fetch Data from Backend
    
    /// Fetch analytics data from backend API
    func fetchFromBackend(for period: PeriodType = .month) async {
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            print("📥 Fetching analytics from backend for period: \(period.rawValue)")
            
            // Create filters for the selected period
            let filters: AnalyticsFilters
            switch period {
            case .week:
                filters = .thisWeek
            case .month:
                filters = .thisMonth
            case .year:
                filters = .thisYear
            }
            
            // Fetch summary from backend
            let summary = try await AnalyticsAPIService.shared.getSummary(filters: filters)
            
            print("✅ Received \(summary.stores.count) stores from backend")
            print("   Total spend: €\(summary.totalSpend)")
            print("   Transaction count: \(summary.transactionCount)")
            
            // Convert API response to StoreBreakdown format
            let breakdowns = await convertToStoreBreakdowns(summary: summary, periodType: period)
            
            await MainActor.run {
                self.storeBreakdowns = breakdowns
                self.isLoading = false
                print("✅ Updated storeBreakdowns with \(breakdowns.count) stores")
            }
            
        } catch let apiError as AnalyticsAPIError {
            print("❌ Backend fetch error: \(apiError.localizedDescription)")
            await MainActor.run {
                self.error = apiError.localizedDescription
                self.isLoading = false
            }
        } catch {
            print("❌ Unexpected error fetching from backend: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Convert API Response to StoreBreakdown
    
    private func convertToStoreBreakdowns(summary: SummaryResponse, periodType: PeriodType) async -> [StoreBreakdown] {
        var breakdowns: [StoreBreakdown] = []
        
        // Format period string (e.g., "January 2026")
        let periodString = formatPeriod(from: summary.startDate, to: summary.endDate, period: periodType)
        
        for apiStore in summary.stores {
            // Fetch detailed breakdown for each store to get category info
            do {
                let filters = AnalyticsFilters(
                    period: periodType,
                    startDate: summary.startDateParsed,
                    endDate: summary.endDateParsed,
                    storeName: apiStore.storeName
                )
                
                let storeDetails = try await AnalyticsAPIService.shared.getStoreDetails(
                    storeName: apiStore.storeName,
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
                
                let breakdown = StoreBreakdown(
                    storeName: apiStore.storeName,
                    period: periodString,
                    totalStoreSpend: apiStore.amountSpent,
                    categories: categories,
                    visitCount: apiStore.storeVisits
                )
                
                breakdowns.append(breakdown)
                
            } catch {
                print("⚠️ Failed to fetch details for \(apiStore.storeName): \(error.localizedDescription)")
                
                // Fallback: Create breakdown without category details
                let breakdown = StoreBreakdown(
                    storeName: apiStore.storeName,
                    period: periodString,
                    totalStoreSpend: apiStore.amountSpent,
                    categories: [],
                    visitCount: apiStore.storeVisits
                )
                
                breakdowns.append(breakdown)
            }
        }
        
        return breakdowns
    }
    
    private func formatPeriod(from startDateStr: String, to endDateStr: String, period: PeriodType) -> String {
        guard let startDate = ISO8601DateFormatter().date(from: startDateStr) ??
                DateFormatter.yyyyMMdd.date(from: startDateStr) else {
            return "Unknown Period"
        }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .year], from: startDate)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"
        
        return dateFormatter.string(from: startDate)
    }
    
    func loadData() {
        // Deprecated - now fetching from backend
        // Keeping for backward compatibility but does nothing
        print("⚠️ loadData() called - this is deprecated, use fetchFromBackend() instead")
    }
    
    // Regenerate breakdowns from transactions (for local data)
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
        let localBreakdowns = breakdownDict.map { key, transactions in
            let components = key.split(separator: "-")
            let storeName = String(components[0])
            let period = components.dropFirst().joined(separator: "-")
            
            // Group by category
            let categoryDict = Dictionary(grouping: transactions, by: { $0.category })
            let totalSpend = transactions.reduce(0) { $0 + $1.amount }
            
            let categories = categoryDict.map { category, items in
                let spent = items.reduce(0) { $0 + $1.amount }
                let percentage = Int((spent / totalSpend) * 100)
                return Category(name: category, spent: spent, percentage: percentage)
            }.sorted { $0.spent > $1.spent }
            
            // Calculate visit count (unique dates)
            let uniqueDates = Set(transactions.map { calendar.startOfDay(for: $0.date) })
            let visitCount = uniqueDates.count
            
            return StoreBreakdown(
                storeName: storeName,
                period: period,
                totalStoreSpend: totalSpend,
                categories: categories,
                visitCount: visitCount
            )
        }
        
        // Merge with existing backend data (avoid duplicates)
        for localBreakdown in localBreakdowns {
            if !storeBreakdowns.contains(where: { $0.id == localBreakdown.id }) {
                storeBreakdowns.append(localBreakdown)
            }
        }
        
        print("✅ Regenerated breakdowns - total: \(storeBreakdowns.count)")
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
// MARK: - DateFormatter Extension

extension DateFormatter {
    static var yyyyMMdd: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}

