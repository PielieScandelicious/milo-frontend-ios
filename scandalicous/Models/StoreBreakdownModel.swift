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
    let averageHealthScore: Double?  // Average health score for this store

    var id: String { "\(storeName)-\(period)" }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case period
        case totalStoreSpend = "total_store_spend"
        case categories
        case visitCount = "visit_count"
        case averageHealthScore = "average_health_score"
    }

    // Initializer with default nil for averageHealthScore
    init(storeName: String, period: String, totalStoreSpend: Double, categories: [Category], visitCount: Int, averageHealthScore: Double? = nil) {
        self.storeName = storeName
        self.period = period
        self.totalStoreSpend = totalStoreSpend
        self.categories = categories
        self.visitCount = visitCount
        self.averageHealthScore = averageHealthScore
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
    @Published var isRefreshing = false
    @Published var error: String?
    @Published var lastFetchDate: Date?
    @Published var averageHealthScore: Double?  // Overall average health score for the current period
    @Published var isDeleting = false
    @Published var deleteError: String?
    @Published var deleteSuccessMessage: String?

    var transactionManager: TransactionManager?
    private var hasInitiallyFetched = false
    
    init() {
        // Don't load local JSON anymore - will fetch from backend
    }
    
    // Inject transaction manager
    func configure(with transactionManager: TransactionManager) {
        self.transactionManager = transactionManager
    }
    
    // MARK: - Fetch Data from Backend
    
    /// Fetch analytics data from backend API - Initial load
    func fetchFromBackend(for period: PeriodType = .month) async {
        // Only show full loading indicator on initial fetch
        let isInitialFetch = !hasInitiallyFetched
        
        await MainActor.run {
            if isInitialFetch {
                isLoading = true
            } else {
                isRefreshing = true
            }
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
                self.averageHealthScore = summary.averageHealthScore
                self.isLoading = false
                self.isRefreshing = false
                self.lastFetchDate = Date()
                self.hasInitiallyFetched = true
                print("✅ Updated storeBreakdowns with \(breakdowns.count) stores")
                if let healthScore = summary.averageHealthScore {
                    print("   Average health score: \(healthScore)")
                }
            }
            
        } catch let apiError as AnalyticsAPIError {
            // Check if it's a cancellation error
            if case .networkError(let underlyingError) = apiError,
               (underlyingError as NSError).code == NSURLErrorCancelled {
                print("⚠️ Request was cancelled - ignoring error")
                await MainActor.run {
                    self.isLoading = false
                    self.isRefreshing = false
                }
                return
            }
            
            print("❌ Backend fetch error: \(apiError.localizedDescription)")
            await MainActor.run {
                // Only show error if this is not a refresh (initial load is more important)
                if isInitialFetch {
                    self.error = apiError.localizedDescription
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch is CancellationError {
            // Task was cancelled - this is normal, don't show error
            print("⚠️ Task cancelled - ignoring")
            await MainActor.run {
                self.isLoading = false
                self.isRefreshing = false
            }
        } catch {
            print("❌ Unexpected error fetching from backend: \(error.localizedDescription)")
            await MainActor.run {
                if isInitialFetch {
                    self.error = error.localizedDescription
                }
                self.isLoading = false
                self.isRefreshing = false
            }
        }
    }
    
    /// Refresh data from backend - for pull-to-refresh
    func refreshData(for period: PeriodType = .month) async {
        await fetchFromBackend(for: period)
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
        
        print("🔄 Regenerating breakdowns from \(transactions.count) transactions")
        
        // Group by store and period
        var breakdownDict: [String: [Transaction]] = [:]
        
        for transaction in transactions {
            let period = dateFormatter.string(from: transaction.date)
            let key = "\(transaction.storeName)-\(period)"
            breakdownDict[key, default: []].append(transaction)
        }
        
        print("   Found \(breakdownDict.count) store-period combinations")
        
        // Convert to StoreBreakdown objects
        let localBreakdowns = breakdownDict.map { key, transactions -> StoreBreakdown in
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
            
            print("   📊 Created breakdown: \(storeName) - \(period) (€\(totalSpend), \(categories.count) categories)")
            
            return StoreBreakdown(
                storeName: storeName,
                period: period,
                totalStoreSpend: totalSpend,
                categories: categories,
                visitCount: visitCount
            )
        }
        
        // Update or add breakdowns
        // First, create a dictionary of existing breakdowns for fast lookup
        var existingBreakdownsDict = Dictionary(uniqueKeysWithValues: storeBreakdowns.map { ($0.id, $0) })
        
        // Update or add local breakdowns
        for localBreakdown in localBreakdowns {
            existingBreakdownsDict[localBreakdown.id] = localBreakdown
            print("   ✅ Updated/Added: \(localBreakdown.storeName) - \(localBreakdown.period)")
        }
        
        // Convert back to array and sort by date (most recent first)
        storeBreakdowns = Array(existingBreakdownsDict.values).sorted { breakdown1, breakdown2 in
            // Extract date from period string for sorting
            let date1 = dateFormatter.date(from: breakdown1.period) ?? Date.distantPast
            let date2 = dateFormatter.date(from: breakdown2.period) ?? Date.distantPast
            return date1 > date2
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
    
    // Delete a store breakdown - removes from local state only (for immediate UI feedback)
    func deleteBreakdownLocally(_ breakdown: StoreBreakdown) {
        storeBreakdowns.removeAll { $0.id == breakdown.id }
    }

    // Delete a store breakdown from backend and local state
    func deleteBreakdown(_ breakdown: StoreBreakdown, periodType: PeriodType = .month) async -> Bool {
        await MainActor.run {
            isDeleting = true
            deleteError = nil
            deleteSuccessMessage = nil
        }

        do {
            // Parse the period string (e.g., "January 2026") to get date range
            let (startDate, endDate) = parsePeriodToDates(breakdown.period, periodType: periodType)

            print("🗑️ Deleting transactions for \(breakdown.storeName)")
            print("   Period: \(periodType.rawValue)")
            print("   Start: \(startDate), End: \(endDate)")

            // Call backend API
            let response = try await AnalyticsAPIService.shared.removeTransactions(
                storeName: breakdown.storeName,
                period: periodType.rawValue,
                startDate: startDate,
                endDate: endDate
            )

            print("✅ Deleted \(response.deletedCount) transactions")

            await MainActor.run {
                // Remove from local state after successful API call
                self.storeBreakdowns.removeAll { $0.id == breakdown.id }
                self.isDeleting = false
                self.deleteSuccessMessage = response.message
            }

            return true

        } catch let apiError as AnalyticsAPIError {
            print("❌ Delete failed: \(apiError.localizedDescription)")
            await MainActor.run {
                self.isDeleting = false
                self.deleteError = apiError.localizedDescription
            }
            return false

        } catch {
            print("❌ Unexpected delete error: \(error.localizedDescription)")
            await MainActor.run {
                self.isDeleting = false
                self.deleteError = error.localizedDescription
            }
            return false
        }
    }

    // Parse period string to date range
    private func parsePeriodToDates(_ period: String, periodType: PeriodType) -> (startDate: String, endDate: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMMM yyyy"

        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "yyyy-MM-dd"

        guard let parsedDate = dateFormatter.date(from: period) else {
            // Fallback to current month if parsing fails
            let now = Date()
            let calendar = Calendar.current
            let components = calendar.dateComponents([.year, .month], from: now)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (outputFormatter.string(from: startOfMonth), outputFormatter.string(from: endOfMonth))
        }

        let calendar = Calendar.current

        switch periodType {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: parsedDate))!
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek)!
            return (outputFormatter.string(from: startOfWeek), outputFormatter.string(from: endOfWeek))

        case .month:
            let components = calendar.dateComponents([.year, .month], from: parsedDate)
            let startOfMonth = calendar.date(from: components)!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            return (outputFormatter.string(from: startOfMonth), outputFormatter.string(from: endOfMonth))

        case .year:
            let components = calendar.dateComponents([.year], from: parsedDate)
            let startOfYear = calendar.date(from: components)!
            let endOfYear = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
            return (outputFormatter.string(from: startOfYear), outputFormatter.string(from: endOfYear))
        }
    }

    // Delete a store breakdown at specific indices
    func deleteBreakdowns(at offsets: IndexSet, from breakdowns: [StoreBreakdown]) {
        let breakdownsToDelete = offsets.map { breakdowns[$0] }
        for breakdown in breakdownsToDelete {
            deleteBreakdownLocally(breakdown)
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

