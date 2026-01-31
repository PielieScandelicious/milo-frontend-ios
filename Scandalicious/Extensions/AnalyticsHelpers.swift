//
//  AnalyticsHelpers.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import SwiftUI

// MARK: - Date Range Helpers

extension Date {
    /// Get the start of the current week
    static var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        return calendar.date(from: components) ?? Date()
    }
    
    /// Get the start of the current month
    static var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        return calendar.date(from: components) ?? Date()
    }
    
    /// Get the start of the current year
    static var startOfYear: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: Date())
        return calendar.date(from: components) ?? Date()
    }
    
    /// Get a date for a specific number of days ago
    static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }
    
    /// Get a date for a specific number of months ago
    static func monthsAgo(_ months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: -months, to: Date()) ?? Date()
    }
    
    /// Get a date for a specific number of years ago
    static func yearsAgo(_ years: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: -years, to: Date()) ?? Date()
    }
}

// MARK: - Period-based Date Range

struct DateRange {
    let start: Date
    let end: Date
    
    init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
    
    /// Get a date range for a specific period type
    static func forPeriod(_ period: PeriodType, offset: Int = 0) -> DateRange {
        let calendar = Calendar.current
        let today = Date()
        
        switch period {
        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today
            let adjustedStart = calendar.date(byAdding: .weekOfYear, value: offset, to: startOfWeek) ?? startOfWeek
            let end = calendar.date(byAdding: .day, value: 6, to: adjustedStart) ?? adjustedStart
            return DateRange(start: adjustedStart, end: end)
            
        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            let adjustedStart = calendar.date(byAdding: .month, value: offset, to: startOfMonth) ?? startOfMonth
            let end = calendar.date(byAdding: .month, value: 1, to: adjustedStart)?.addingTimeInterval(-1) ?? adjustedStart
            return DateRange(start: adjustedStart, end: end)
            
        case .year:
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: today)) ?? today
            let adjustedStart = calendar.date(byAdding: .year, value: offset, to: startOfYear) ?? startOfYear
            let end = calendar.date(byAdding: .year, value: 1, to: adjustedStart)?.addingTimeInterval(-1) ?? adjustedStart
            return DateRange(start: adjustedStart, end: end)

        case .custom:
            // Custom periods don't have a predefined range, fall back to month behavior
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
            let adjustedStart = calendar.date(byAdding: .month, value: offset, to: startOfMonth) ?? startOfMonth
            let end = calendar.date(byAdding: .month, value: 1, to: adjustedStart)?.addingTimeInterval(-1) ?? adjustedStart
            return DateRange(start: adjustedStart, end: end)

        case .all:
            // "All" periods span from distant past to today
            return DateRange(start: Date.distantPast, end: today)
        }
    }
    
    /// Get the current period (this week/month/year)
    static func current(_ period: PeriodType) -> DateRange {
        forPeriod(period, offset: 0)
    }
    
    /// Get the previous period
    static func previous(_ period: PeriodType) -> DateRange {
        forPeriod(period, offset: -1)
    }
    
    /// Last 7 days
    static var lastWeek: DateRange {
        DateRange(start: .daysAgo(7), end: Date())
    }
    
    /// Last 30 days
    static var last30Days: DateRange {
        DateRange(start: .daysAgo(30), end: Date())
    }
    
    /// Last 90 days
    static var last90Days: DateRange {
        DateRange(start: .daysAgo(90), end: Date())
    }
    
    /// Year to date
    static var yearToDate: DateRange {
        DateRange(start: .startOfYear, end: Date())
    }
}

// MARK: - Currency Formatting

extension Double {
    /// Format as currency with symbol
    func asCurrency(currencyCode: String = "USD") -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "$\(self)"
    }
    
    /// Format as currency without symbol
    func asCurrencyValue() -> String {
        String(format: "%.2f", self)
    }
}

// MARK: - Percentage Formatting

extension Double {
    /// Format as percentage
    var asPercentage: String {
        String(format: "%.1f%%", self)
    }
}

// MARK: - Analytics Filters Presets

extension AnalyticsFilters {
    /// This week
    static var thisWeek: AnalyticsFilters {
        var filters = AnalyticsFilters()
        filters.period = .week
        let range = DateRange.current(.week)
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
    
    /// This month
    static var thisMonth: AnalyticsFilters {
        var filters = AnalyticsFilters()
        filters.period = .month
        let range = DateRange.current(.month)
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
    
    /// This year
    static var thisYear: AnalyticsFilters {
        var filters = AnalyticsFilters()
        filters.period = .year
        let range = DateRange.current(.year)
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
    
    /// Last 30 days
    static var last30Days: AnalyticsFilters {
        var filters = AnalyticsFilters()
        filters.period = .month
        let range = DateRange.last30Days
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
    
    /// Last 90 days
    static var last90Days: AnalyticsFilters {
        var filters = AnalyticsFilters()
        filters.period = .month
        let range = DateRange.last90Days
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
}

extension TransactionFilters {
    /// Last 30 days
    static var last30Days: TransactionFilters {
        var filters = TransactionFilters()
        let range = DateRange.last30Days
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
    
    /// This month
    static var thisMonth: TransactionFilters {
        var filters = TransactionFilters()
        let range = DateRange.current(.month)
        filters.startDate = range.start
        filters.endDate = range.end
        return filters
    }
}

// MARK: - Color Helpers for Charts

extension AnalyticsCategory {
    /// SwiftUI Color for category
    var chartColor: Color {
        switch self {
        case .meatFish: return .red
        case .alcohol: return .purple
        case .drinksSoftSoda: return .orange
        case .drinksWater: return .blue
        case .household: return .gray
        case .snacksSweets: return .pink
        case .freshProduce: return .green
        case .dairyEggs: return .yellow
        case .readyMeals: return .brown
        case .bakery: return .orange
        case .pantry: return Color(red: 0.6, green: 0.4, blue: 0.2)
        case .personalCare: return .mint
        case .frozen: return .cyan
        case .babyKids: return .pink
        case .petSupplies: return Color(red: 0.5, green: 0.3, blue: 0.1)
        case .other: return .secondary
        }
    }
}

extension CategoryBreakdown {
    /// SwiftUI Color for category
    var chartColor: Color {
        analyticsCategory?.chartColor ?? .gray
    }
}

// MARK: - Sorting Helpers

extension Array where Element == CategoryBreakdown {
    /// Sort by amount spent (descending)
    func sortedBySpending() -> [CategoryBreakdown] {
        sorted { $0.spent > $1.spent }
    }
    
    /// Sort by percentage (descending)
    func sortedByPercentage() -> [CategoryBreakdown] {
        sorted { $0.percentage > $1.percentage }
    }
    
    /// Sort by transaction count (descending)
    func sortedByTransactionCount() -> [CategoryBreakdown] {
        sorted { $0.transactionCount > $1.transactionCount }
    }
}

extension Array where Element == APIStoreBreakdown {
    /// Sort by amount spent (descending)
    func sortedBySpending() -> [APIStoreBreakdown] {
        sorted { $0.amountSpent > $1.amountSpent }
    }

    /// Sort by visit count (descending)
    func sortedByVisits() -> [APIStoreBreakdown] {
        sorted { $0.storeVisits > $1.storeVisits }
    }
}

extension Array where Element == TrendPeriod {
    /// Sort by date (ascending)
    func sortedByDate() -> [TrendPeriod] {
        sorted { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }
    
    /// Sort by spending (descending)
    func sortedBySpending() -> [TrendPeriod] {
        sorted { $0.totalSpend > $1.totalSpend }
    }
}

// MARK: - Chart Data Helpers

extension TrendsResponse {
    /// Get the highest spending period
    /// - Note: Prefer using `AggregateResponse.extremes.maxSpendingPeriod` from `/analytics/aggregate` endpoint
    @available(*, deprecated, message: "Use AggregateResponse.extremes.maxSpendingPeriod from backend instead")
    var maxSpendingPeriod: TrendPeriod? {
        periods.max(by: { $0.totalSpend < $1.totalSpend })
    }

    /// Get the average spending across all periods
    /// - Note: Prefer using `AggregateResponse.averages.averageSpendPerPeriod` from `/analytics/aggregate` endpoint
    @available(*, deprecated, message: "Use AggregateResponse.averages.averageSpendPerPeriod from backend instead")
    var averageSpending: Double {
        guard !periods.isEmpty else { return 0 }
        let total = periods.reduce(0) { $0 + $1.totalSpend }
        return total / Double(periods.count)
    }

    /// Get the total spending across all periods
    /// - Note: Prefer using `AggregateResponse.totals.totalSpend` from `/analytics/aggregate` endpoint
    @available(*, deprecated, message: "Use AggregateResponse.totals.totalSpend from backend instead")
    var totalSpending: Double {
        periods.reduce(0) { $0 + $1.totalSpend }
    }
}

extension CategoriesResponse {
    /// Get the top N categories by spending
    /// - Note: Prefer using `AggregateResponse.topCategories` from `/analytics/aggregate` endpoint with `top_categories_limit` parameter
    @available(*, deprecated, message: "Use AggregateResponse.topCategories from backend instead")
    func topCategories(limit: Int) -> [CategoryBreakdown] {
        Array(categories.sortedBySpending().prefix(limit))
    }

    /// Get categories that represent at least X% of spending
    /// - Note: Prefer using `AggregateResponse.topCategories` from `/analytics/aggregate` endpoint with `min_category_percentage` parameter
    @available(*, deprecated, message: "Use AggregateResponse.topCategories with min_category_percentage filter from backend instead")
    func categoriesAbovePercentage(_ percentage: Double) -> [CategoryBreakdown] {
        categories.filter { $0.percentage >= percentage }
    }
}

extension SummaryResponse {
    /// Get the average transaction value
    /// - Note: Prefer using `AggregateResponse.averages.averageTransactionValue` from `/analytics/aggregate` endpoint
    @available(*, deprecated, message: "Use AggregateResponse.averages.averageTransactionValue from backend instead")
    var averageTransactionValue: Double {
        guard let count = transactionCount, count > 0 else { return 0 }
        return totalSpend / Double(count)
    }

    /// Get the top N stores by spending
    /// - Note: Prefer using `AggregateResponse.topStores` from `/analytics/aggregate` endpoint with `top_stores_limit` parameter
    @available(*, deprecated, message: "Use AggregateResponse.topStores from backend instead")
    func topStores(limit: Int) -> [APIStoreBreakdown] {
        Array((stores ?? []).sortedBySpending().prefix(limit))
    }
}

// MARK: - Aggregate Response Helpers

extension AggregateResponse {
    /// Convenience: Total spending across all periods
    var totalSpend: Double { totals.totalSpend }

    /// Convenience: Total transaction count across all periods
    var totalTransactions: Int { totals.totalTransactions }

    /// Convenience: Total receipt count across all periods
    var totalReceipts: Int { totals.totalReceipts }

    /// Convenience: Total items (quantities summed) across all periods
    var totalItems: Int { totals.totalItems }

    /// Convenience: Average spending per period
    var averageSpendPerPeriod: Double { averages.averageSpendPerPeriod }

    /// Convenience: Average value per transaction
    var averageTransactionValue: Double { averages.averageTransactionValue }

    /// Convenience: Average price per item (total_spend / total_items)
    var averageItemPrice: Double { averages.averageItemPrice }

    /// Convenience: Average items per receipt
    var averageItemsPerReceipt: Double { averages.averageItemsPerReceipt }

    /// Convenience: Overall average health score
    var averageHealthScore: Double? { averages.averageHealthScore }

    /// Convenience: Period with maximum spending
    var maxSpendingPeriod: AggregatePeriodSpend? { extremes.maxSpendingPeriod }

    /// Convenience: Period with minimum spending
    var minSpendingPeriod: AggregatePeriodSpend? { extremes.minSpendingPeriod }
}

// MARK: - All-Time Stats Helpers

extension AllTimeStatsResponse {
    /// Top 3 stores by visits for display in scan view
    var top3StoresByVisits: [(name: String, visits: Int)] {
        topStoresByVisits.prefix(3).map { ($0.storeName, $0.visitCount) }
    }

    /// Duration string showing how long the user has been tracking
    var trackingDuration: String? {
        guard let firstDate = firstReceiptDate,
              let lastDate = lastReceiptDate,
              let first = DateFormatter.yyyyMMdd.date(from: firstDate),
              let last = DateFormatter.yyyyMMdd.date(from: lastDate) else {
            return nil
        }

        let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0
        if days < 30 {
            return "\(days) days"
        } else if days < 365 {
            let months = days / 30
            return "\(months) month\(months == 1 ? "" : "s")"
        } else {
            let years = days / 365
            let remainingMonths = (days % 365) / 30
            if remainingMonths > 0 {
                return "\(years) year\(years == 1 ? "" : "s"), \(remainingMonths) month\(remainingMonths == 1 ? "" : "s")"
            }
            return "\(years) year\(years == 1 ? "" : "s")"
        }
    }
}

extension AggregateCategory {
    /// Convert to CategoryBreakdown for compatibility with existing UI components
    var asCategoryBreakdown: CategoryBreakdown {
        CategoryBreakdown(
            name: name,
            spent: totalSpent,
            percentage: percentage,
            transactionCount: transactionCount,
            averageHealthScore: averageHealthScore
        )
    }
}

extension Array where Element == AggregateCategory {
    /// Convert array to CategoryBreakdown array for compatibility with existing UI components
    var asCategoryBreakdowns: [CategoryBreakdown] {
        map { $0.asCategoryBreakdown }
    }
}

extension AggregateStore {
    /// Convert to APIStoreBreakdown for compatibility with existing UI components
    var asAPIStoreBreakdown: APIStoreBreakdown {
        APIStoreBreakdown(
            storeName: storeName,
            amountSpent: totalSpent,
            storeVisits: visitCount,
            percentage: percentage,
            averageHealthScore: averageHealthScore
        )
    }
}

extension Array where Element == AggregateStore {
    /// Convert array to APIStoreBreakdown array for compatibility with existing UI components
    var asAPIStoreBreakdowns: [APIStoreBreakdown] {
        map { $0.asAPIStoreBreakdown }
    }
}

// MARK: - SwiftUI View Helpers

struct ErrorView: View {
    let error: String
    let retry: () async -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Oops!")
                .font(.title2)
                .bold()
            
            Text(error)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task { await retry() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let icon: String
    
    init(title: String = "No Data", 
         message: String = "No data available for the selected period",
         icon: String = "chart.bar.xaxis") {
        self.title = title
        self.message = message
        self.icon = icon
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(title)
                .font(.title2)
                .bold()
            
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension TrendsResponse {
    static var preview: TrendsResponse {
        TrendsResponse(
            periodType: .month,
            trends: [
                TrendPeriod(period: "January 2024", periodStart: "2024-01-01", periodEnd: "2024-01-31", totalSpend: 450.00, transactionCount: 42),
                TrendPeriod(period: "February 2024", periodStart: "2024-02-01", periodEnd: "2024-02-29", totalSpend: 520.00, transactionCount: 48),
                TrendPeriod(period: "March 2024", periodStart: "2024-03-01", periodEnd: "2024-03-31", totalSpend: 480.00, transactionCount: 45),
                TrendPeriod(period: "April 2024", periodStart: "2024-04-01", periodEnd: "2024-04-30", totalSpend: 510.00, transactionCount: 50)
            ]
        )
    }
}

extension CategoriesResponse {
    static var preview: CategoriesResponse {
        CategoriesResponse(
            period: "January 2024",
            startDate: "2024-01-01",
            endDate: "2024-01-31",
            totalSpend: 500.00,
            categories: [
                CategoryBreakdown(name: "Fresh Produce", spent: 120.00, percentage: 24.0, transactionCount: 15),
                CategoryBreakdown(name: "Meat & Fish", spent: 100.00, percentage: 20.0, transactionCount: 8),
                CategoryBreakdown(name: "Dairy & Eggs", spent: 80.00, percentage: 16.0, transactionCount: 12),
                CategoryBreakdown(name: "Bakery", spent: 60.00, percentage: 12.0, transactionCount: 10),
                CategoryBreakdown(name: "Other", spent: 140.00, percentage: 28.0, transactionCount: 25)
            ]
        )
    }
}

extension SummaryResponse {
    static var preview: SummaryResponse {
        SummaryResponse(
            period: "January 2024",
            startDate: "2024-01-01",
            endDate: "2024-01-31",
            totalSpend: 500.00,
            transactionCount: 45,
            stores: [
                APIStoreBreakdown(storeName: "Tesco", amountSpent: 250.00, storeVisits: 5, percentage: 50.0),
                APIStoreBreakdown(storeName: "Sainsbury's", amountSpent: 150.00, storeVisits: 3, percentage: 30.0),
                APIStoreBreakdown(storeName: "Waitrose", amountSpent: 100.00, storeVisits: 2, percentage: 20.0)
            ]
        )
    }
}

extension APITransaction {
    static var preview: APITransaction {
        APITransaction(
            id: UUID().uuidString,
            storeName: "Tesco",
            itemName: "Organic Milk",
            itemPrice: 1.50,
            quantity: 2,
            category: "Dairy & Eggs",
            date: "2024-01-20"
        )
    }

    static var previewArray: [APITransaction] {
        [
            APITransaction(id: "1", storeName: "Tesco", itemName: "Organic Milk", itemPrice: 1.50, quantity: 2, category: "Dairy & Eggs", date: "2024-01-20"),
            APITransaction(id: "2", storeName: "Tesco", itemName: "Bread", itemPrice: 2.00, quantity: 1, category: "Bakery", date: "2024-01-20"),
            APITransaction(id: "3", storeName: "Sainsbury's", itemName: "Chicken Breast", itemPrice: 5.50, quantity: 1, category: "Meat & Fish", date: "2024-01-19"),
            APITransaction(id: "4", storeName: "Waitrose", itemName: "Salad", itemPrice: 3.00, quantity: 1, category: "Fresh Produce", date: "2024-01-18")
        ]
    }
}
#endif
