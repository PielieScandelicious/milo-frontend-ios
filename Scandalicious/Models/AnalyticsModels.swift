//
//  AnalyticsModels.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation

// MARK: - Period Types

enum PeriodType: String, Codable, CaseIterable {
    case week
    case month
    case year
    case custom
    case all

    var displayName: String {
        if self == .all { return "All Time" }
        return rawValue.capitalized
    }
}

// MARK: - Analytics Category (API Format)

enum AnalyticsCategory: String, Codable, CaseIterable {
    case meatFish = "MEAT_FISH"
    case alcohol = "ALCOHOL"
    case drinksSoftSoda = "DRINKS_SOFT_SODA"
    case drinksWater = "DRINKS_WATER"
    case household = "HOUSEHOLD"
    case snacksSweets = "SNACKS_SWEETS"
    case freshProduce = "FRESH_PRODUCE"
    case dairyEggs = "DAIRY_EGGS"
    case readyMeals = "READY_MEALS"
    case bakery = "BAKERY"
    case pantry = "PANTRY"
    case personalCare = "PERSONAL_CARE"
    case frozen = "FROZEN"
    case babyKids = "BABY_KIDS"
    case petSupplies = "PET_SUPPLIES"
    case other = "OTHER"
    
    var displayName: String {
        switch self {
        case .meatFish: return "Meat & Fish"
        case .alcohol: return "Alcohol"
        case .drinksSoftSoda: return "Drinks (Soft/Soda)"
        case .drinksWater: return "Drinks (Water)"
        case .household: return "Household"
        case .snacksSweets: return "Snacks & Sweets"
        case .freshProduce: return "Fresh Produce"
        case .dairyEggs: return "Dairy & Eggs"
        case .readyMeals: return "Ready Meals"
        case .bakery: return "Bakery"
        case .pantry: return "Pantry"
        case .personalCare: return "Personal Care"
        case .frozen: return "Frozen"
        case .babyKids: return "Baby & Kids"
        case .petSupplies: return "Pet Supplies"
        case .other: return "Other"
        }
    }
    
    var icon: String {
        switch self {
        case .meatFish: return "fish.fill"
        case .alcohol: return "wineglass.fill"
        case .drinksSoftSoda: return "cup.and.saucer.fill"
        case .drinksWater: return "waterbottle.fill"
        case .household: return "house.fill"
        case .snacksSweets: return "birthday.cake.fill"
        case .freshProduce: return "leaf.fill"
        case .dairyEggs: return "carton.fill"
        case .readyMeals: return "takeoutbag.and.cup.and.straw.fill"
        case .bakery: return "croissant.fill"
        case .pantry: return "cabinet.fill"
        case .personalCare: return "sparkles"
        case .frozen: return "snowflake"
        case .babyKids: return "figure.and.child.holdinghands"
        case .petSupplies: return "pawprint.fill"
        case .other: return "shippingbox.fill"
        }
    }
    
    // Convert from ReceiptCategory if needed
    init?(from receiptCategory: ReceiptCategory) {
        switch receiptCategory {
        case .meatAndFish: self = .meatFish
        case .alcohol: self = .alcohol
        case .drinksSoftSoda: self = .drinksSoftSoda
        case .drinksWater: self = .drinksWater
        case .household: self = .household
        case .snacksAndSweets: self = .snacksSweets
        case .freshProduce: self = .freshProduce
        case .dairyAndEggs: self = .dairyEggs
        case .readyMeals: self = .readyMeals
        case .bakery: self = .bakery
        case .pantry: self = .pantry
        case .personalCare: self = .personalCare
        case .frozen: self = .frozen
        case .babyAndKids: self = .babyKids
        case .petSupplies: self = .petSupplies
        case .other: self = .other
        }
    }
}

// MARK: - Trends Response

struct TrendsResponse: Codable {
    let periodType: PeriodType
    let trends: [TrendPeriod]

    enum CodingKeys: String, CodingKey {
        case periodType = "period_type"
        case trends
    }

    /// Alias for backwards compatibility
    var periods: [TrendPeriod] { trends }
}

struct TrendPeriod: Codable, Identifiable {
    let period: String           // e.g., "January 2026"
    let periodStart: String      // e.g., "2026-01-01"
    let periodEnd: String        // e.g., "2026-01-31"
    let totalSpend: Double
    let transactionCount: Int
    let averageHealthScore: Double?  // Average health score for this period

    var id: String { periodStart }

    enum CodingKeys: String, CodingKey {
        case period
        case periodStart = "start_date"
        case periodEnd = "end_date"
        case totalSpend = "total_spend"
        case transactionCount = "transaction_count"
        case averageHealthScore = "average_health_score"
    }

    init(period: String = "", periodStart: String, periodEnd: String, totalSpend: Double, transactionCount: Int, averageHealthScore: Double? = nil) {
        self.period = period
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.totalSpend = totalSpend
        self.transactionCount = transactionCount
        self.averageHealthScore = averageHealthScore
    }

    var startDate: Date? {
        ISO8601DateFormatter().date(from: periodStart) ??
        DateFormatter.yyyyMMdd.date(from: periodStart)
    }

    var endDate: Date? {
        ISO8601DateFormatter().date(from: periodEnd) ??
        DateFormatter.yyyyMMdd.date(from: periodEnd)
    }
}

// MARK: - Categories Response

struct CategoriesResponse: Codable {
    let period: String  // Backend returns "January 2026" format, not enum
    let startDate: String
    let endDate: String
    let totalSpend: Double
    let categories: [CategoryBreakdown]
    let averageHealthScore: Double?  // Overall average health score

    enum CodingKeys: String, CodingKey {
        case period
        case startDate = "start_date"
        case endDate = "end_date"
        case totalSpend = "total_spend"
        case categories
        case averageHealthScore = "average_health_score"
    }

    init(period: String, startDate: String, endDate: String, totalSpend: Double, categories: [CategoryBreakdown], averageHealthScore: Double? = nil) {
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.totalSpend = totalSpend
        self.categories = categories
        self.averageHealthScore = averageHealthScore
    }

    var startDateParsed: Date? {
        ISO8601DateFormatter().date(from: startDate) ??
        DateFormatter.yyyyMMdd.date(from: startDate)
    }

    var endDateParsed: Date? {
        ISO8601DateFormatter().date(from: endDate) ??
        DateFormatter.yyyyMMdd.date(from: endDate)
    }
}

struct CategoryBreakdown: Codable, Identifiable {
    let name: String
    let spent: Double
    let percentage: Double
    let transactionCount: Int
    let averageHealthScore: Double?  // Average health score for this category

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case spent
        case percentage
        case transactionCount = "transaction_count"
        case averageHealthScore = "average_health_score"
    }

    init(name: String, spent: Double, percentage: Double, transactionCount: Int, averageHealthScore: Double? = nil) {
        self.name = name
        self.spent = spent
        self.percentage = percentage
        self.transactionCount = transactionCount
        self.averageHealthScore = averageHealthScore
    }

    var analyticsCategory: AnalyticsCategory? {
        AnalyticsCategory.allCases.first { $0.displayName == name }
    }

    var icon: String {
        analyticsCategory?.icon ?? "shippingbox.fill"
    }
}

// MARK: - Summary Response

struct SummaryResponse: Codable {
    let period: String  // Backend returns "January 2026" format, not enum
    let startDate: String
    let endDate: String
    let totalSpend: Double
    let transactionCount: Int
    let stores: [APIStoreBreakdown]
    let averageHealthScore: Double?  // Overall average health score for the period

    enum CodingKeys: String, CodingKey {
        case period
        case startDate = "start_date"
        case endDate = "end_date"
        case totalSpend = "total_spend"
        case transactionCount = "transaction_count"
        case stores
        case averageHealthScore = "average_health_score"
    }

    init(period: String, startDate: String, endDate: String, totalSpend: Double, transactionCount: Int, stores: [APIStoreBreakdown], averageHealthScore: Double? = nil) {
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.totalSpend = totalSpend
        self.transactionCount = transactionCount
        self.stores = stores
        self.averageHealthScore = averageHealthScore
    }

    var startDateParsed: Date? {
        ISO8601DateFormatter().date(from: startDate) ??
        DateFormatter.yyyyMMdd.date(from: startDate)
    }

    var endDateParsed: Date? {
        ISO8601DateFormatter().date(from: endDate) ??
        DateFormatter.yyyyMMdd.date(from: endDate)
    }
}

struct APIStoreBreakdown: Codable, Identifiable {
    let storeName: String
    let amountSpent: Double
    let storeVisits: Int
    let percentage: Double
    let averageHealthScore: Double?  // Average health score for this store

    var id: String { storeName }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case amountSpent = "amount_spent"
        case storeVisits = "store_visits"
        case percentage
        case averageHealthScore = "average_health_score"
    }

    init(storeName: String, amountSpent: Double, storeVisits: Int, percentage: Double, averageHealthScore: Double? = nil) {
        self.storeName = storeName
        self.amountSpent = amountSpent
        self.storeVisits = storeVisits
        self.percentage = percentage
        self.averageHealthScore = averageHealthScore
    }
}

// MARK: - Store Details Response

struct StoreDetailsResponse: Codable {
    let storeName: String
    let period: String  // Backend returns "January 2026" format, not enum
    let startDate: String
    let endDate: String
    let totalSpend: Double
    let visitCount: Int
    let categories: [CategoryBreakdown]
    let averageHealthScore: Double?  // Average health score for this store
    let totalItems: Int?             // NEW: Sum of all item quantities (for average item price)
    let averageItemPrice: Double?    // NEW: Backend-computed average item price

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case period
        case startDate = "start_date"
        case endDate = "end_date"
        case totalSpend = "total_store_spend"
        case visitCount = "store_visits"
        case categories
        case averageHealthScore = "average_health_score"
        case totalItems = "total_items"
        case averageItemPrice = "average_item_price"
    }

    init(storeName: String, period: String, startDate: String, endDate: String, totalSpend: Double, visitCount: Int, categories: [CategoryBreakdown], averageHealthScore: Double? = nil, totalItems: Int? = nil, averageItemPrice: Double? = nil) {
        self.storeName = storeName
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.totalSpend = totalSpend
        self.visitCount = visitCount
        self.categories = categories
        self.averageHealthScore = averageHealthScore
        self.totalItems = totalItems
        self.averageItemPrice = averageItemPrice
    }

    var startDateParsed: Date? {
        ISO8601DateFormatter().date(from: startDate) ??
        DateFormatter.yyyyMMdd.date(from: startDate)
    }

    var endDateParsed: Date? {
        ISO8601DateFormatter().date(from: endDate) ??
        DateFormatter.yyyyMMdd.date(from: endDate)
    }

    /// Computed total items from categories if not provided by backend (legacy fallback)
    var computedTotalItems: Int {
        totalItems ?? categories.reduce(0) { $0 + $1.transactionCount }
    }

    /// Computed average item price (prefers backend value, falls back to local calculation)
    var computedAverageItemPrice: Double? {
        if let backendPrice = averageItemPrice {
            return backendPrice
        }
        let items = computedTotalItems
        guard items > 0 else { return nil }
        return totalSpend / Double(items)
    }
}

// MARK: - Transactions Response

struct TransactionsResponse: Codable {
    let transactions: [APITransaction]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int
    
    enum CodingKeys: String, CodingKey {
        case transactions
        case total
        case page
        case pageSize = "page_size"
        case totalPages = "total_pages"
    }
}

struct APITransaction: Codable, Identifiable {
    let id: String
    let storeName: String
    let itemName: String
    let itemPrice: Double
    let quantity: Int
    let unitPrice: Double?  // Price per unit when quantity > 1
    let category: String
    let date: String
    let healthScore: Int?  // 0-5 for food items, nil for non-food

    enum CodingKeys: String, CodingKey {
        case id
        case storeName = "store_name"
        case itemName = "item_name"
        case itemPrice = "item_price"
        case quantity
        case unitPrice = "unit_price"
        case category
        case date
        case healthScore = "health_score"
    }

    init(id: String, storeName: String, itemName: String, itemPrice: Double, quantity: Int, unitPrice: Double? = nil, category: String, date: String, healthScore: Int? = nil) {
        self.id = id
        self.storeName = storeName
        self.itemName = itemName
        self.itemPrice = itemPrice
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.category = category
        self.date = date
        self.healthScore = healthScore
    }

    var dateParsed: Date? {
        ISO8601DateFormatter().date(from: date) ??
        DateFormatter.yyyyMMdd.date(from: date)
    }

    var analyticsCategory: AnalyticsCategory? {
        AnalyticsCategory.allCases.first { $0.displayName == category }
    }

    var totalPrice: Double {
        itemPrice  // Total price from backend (already accounts for quantity)
    }
}

// MARK: - Filter Parameters

struct AnalyticsFilters {
    var period: PeriodType = .month
    var startDate: Date?
    var endDate: Date?
    var storeName: String?
    var category: AnalyticsCategory?
    var numPeriods: Int = 12
    
    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        // For "all" period, don't add period filter - let backend return all data
        if period != .all {
            items.append(URLQueryItem(name: "period", value: period.rawValue))
        }

        if let startDate = startDate {
            items.append(URLQueryItem(name: "start_date", value: DateFormatter.yyyyMMdd.string(from: startDate)))
        }

        if let endDate = endDate {
            items.append(URLQueryItem(name: "end_date", value: DateFormatter.yyyyMMdd.string(from: endDate)))
        }

        if let storeName = storeName {
            items.append(URLQueryItem(name: "store_name", value: storeName))
        }

        if let category = category {
            items.append(URLQueryItem(name: "category", value: category.rawValue))
        }

        return items
    }
    
    func toTrendsQueryItems() -> [URLQueryItem] {
        return [
            URLQueryItem(name: "period_type", value: period.rawValue),
            URLQueryItem(name: "num_periods", value: String(numPeriods))
        ]
    }
}

struct TransactionFilters {
    var startDate: Date?
    var endDate: Date?
    var storeName: String?
    var category: AnalyticsCategory?
    var page: Int = 1
    var pageSize: Int = 50

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let startDate = startDate {
            items.append(URLQueryItem(name: "start_date", value: DateFormatter.yyyyMMdd.string(from: startDate)))
        }

        if let endDate = endDate {
            items.append(URLQueryItem(name: "end_date", value: DateFormatter.yyyyMMdd.string(from: endDate)))
        }

        if let storeName = storeName {
            items.append(URLQueryItem(name: "store_name", value: storeName))
        }

        if let category = category {
            items.append(URLQueryItem(name: "category", value: category.displayName))
        }

        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "page_size", value: String(pageSize)))

        return items
    }
}

// MARK: - Receipts List Response

struct ReceiptsListResponse: Codable {
    let receipts: [APIReceipt]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case receipts
        case total
        case page
        case pageSize = "page_size"
        case totalPages = "total_pages"
    }
}

struct APIReceipt: Codable, Identifiable {
    let receiptId: String
    let storeName: String?
    let receiptDate: String?
    let totalAmount: Double?
    let itemsCount: Int
    let averageHealthScore: Double?
    let transactions: [APIReceiptItem]

    var id: String { receiptId }

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case storeName = "store_name"
        case receiptDate = "receipt_date"
        case totalAmount = "total_amount"
        case itemsCount = "items_count"
        case averageHealthScore = "average_health_score"
        case transactions
    }

    var dateParsed: Date? {
        guard let receiptDate = receiptDate else { return nil }
        return DateFormatter.yyyyMMdd.date(from: receiptDate)
    }

    var formattedDate: String {
        guard let date = dateParsed else { return receiptDate ?? "Unknown Date" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    var displayStoreName: String {
        storeName ?? "Unknown Store"
    }

    var displayTotalAmount: Double {
        totalAmount ?? 0
    }
}

struct APIReceiptItem: Codable, Identifiable {
    let itemName: String
    let itemPrice: Double
    let quantity: Int
    let unitPrice: Double?
    let category: String
    let healthScore: Int?

    var id: String { "\(itemName)-\(itemPrice)-\(quantity)" }

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case itemPrice = "item_price"
        case quantity
        case unitPrice = "unit_price"
        case category
        case healthScore = "health_score"
    }

    var totalPrice: Double {
        itemPrice
    }

    var categoryDisplayName: String {
        // Category comes as display name from backend (e.g., "Dairy & Eggs")
        category
    }
}

struct ReceiptFilters {
    var startDate: Date?
    var endDate: Date?
    var storeName: String?
    var page: Int = 1
    var pageSize: Int = 20

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if let startDate = startDate {
            items.append(URLQueryItem(name: "start_date", value: DateFormatter.yyyyMMdd.string(from: startDate)))
        }

        if let endDate = endDate {
            items.append(URLQueryItem(name: "end_date", value: DateFormatter.yyyyMMdd.string(from: endDate)))
        }

        if let storeName = storeName {
            items.append(URLQueryItem(name: "store_name", value: storeName))
        }

        items.append(URLQueryItem(name: "page", value: String(page)))
        items.append(URLQueryItem(name: "page_size", value: String(pageSize)))

        return items
    }
}

// MARK: - Aggregate Analytics Response

struct AggregateResponse: Codable {
    let periodType: String
    let numPeriods: Int
    let startDate: String
    let endDate: String
    let totals: AggregateTotals
    let averages: AggregateAverages
    let extremes: AggregateExtremes
    let topCategories: [AggregateCategory]
    let topStores: [AggregateStore]
    let healthScoreDistribution: HealthScoreDistribution?

    enum CodingKeys: String, CodingKey {
        case periodType = "period_type"
        case numPeriods = "num_periods"
        case startDate = "start_date"
        case endDate = "end_date"
        case totals
        case averages
        case extremes
        case topCategories = "top_categories"
        case topStores = "top_stores"
        case healthScoreDistribution = "health_score_distribution"
    }
}

struct AggregateTotals: Codable {
    let totalSpend: Double
    let totalTransactions: Int
    let totalReceipts: Int
    let totalItems: Int

    enum CodingKeys: String, CodingKey {
        case totalSpend = "total_spend"
        case totalTransactions = "total_transactions"
        case totalReceipts = "total_receipts"
        case totalItems = "total_items"
    }
}

struct AggregateAverages: Codable {
    let averageSpendPerPeriod: Double
    let averageTransactionValue: Double
    let averageItemPrice: Double          // NEW: total_spend / total_items
    let averageHealthScore: Double?
    let averageReceiptsPerPeriod: Double
    let averageTransactionsPerPeriod: Double
    let averageItemsPerReceipt: Double    // NEW: total_items / total_receipts

    enum CodingKeys: String, CodingKey {
        case averageSpendPerPeriod = "average_spend_per_period"
        case averageTransactionValue = "average_transaction_value"
        case averageItemPrice = "average_item_price"
        case averageHealthScore = "average_health_score"
        case averageReceiptsPerPeriod = "average_receipts_per_period"
        case averageTransactionsPerPeriod = "average_transactions_per_period"
        case averageItemsPerReceipt = "average_items_per_receipt"
    }
}

struct AggregateExtremes: Codable {
    let maxSpendingPeriod: AggregatePeriodSpend?
    let minSpendingPeriod: AggregatePeriodSpend?
    let highestHealthScorePeriod: AggregatePeriodHealth?
    let lowestHealthScorePeriod: AggregatePeriodHealth?

    enum CodingKeys: String, CodingKey {
        case maxSpendingPeriod = "max_spending_period"
        case minSpendingPeriod = "min_spending_period"
        case highestHealthScorePeriod = "highest_health_score_period"
        case lowestHealthScorePeriod = "lowest_health_score_period"
    }
}

struct AggregatePeriodSpend: Codable {
    let period: String
    let periodStart: String
    let periodEnd: String
    let totalSpend: Double

    enum CodingKeys: String, CodingKey {
        case period
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case totalSpend = "total_spend"
    }
}

struct AggregatePeriodHealth: Codable {
    let period: String
    let averageHealthScore: Double

    enum CodingKeys: String, CodingKey {
        case period
        case averageHealthScore = "average_health_score"
    }
}

struct AggregateCategory: Codable, Identifiable {
    let name: String
    let totalSpent: Double
    let percentage: Double
    let transactionCount: Int
    let averageHealthScore: Double?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case totalSpent = "total_spent"
        case percentage
        case transactionCount = "transaction_count"
        case averageHealthScore = "average_health_score"
    }
}

struct AggregateStore: Codable, Identifiable {
    let storeName: String
    let totalSpent: Double
    let percentage: Double
    let visitCount: Int
    let averageHealthScore: Double?

    var id: String { storeName }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case totalSpent = "total_spent"
        case percentage
        case visitCount = "visit_count"
        case averageHealthScore = "average_health_score"
    }
}

struct HealthScoreDistribution: Codable {
    let veryHealthy5: Double
    let healthy4: Double
    let moderate3: Double
    let lessHealthy2: Double
    let unhealthy1: Double
    let veryUnhealthy0: Double

    enum CodingKeys: String, CodingKey {
        case veryHealthy5 = "very_healthy_5"
        case healthy4 = "healthy_4"
        case moderate3 = "moderate_3"
        case lessHealthy2 = "less_healthy_2"
        case unhealthy1 = "unhealthy_1"
        case veryUnhealthy0 = "very_unhealthy_0"
    }

    /// Returns the distribution as an array of (score, percentage) tuples for easy iteration
    var asArray: [(score: Int, percentage: Double)] {
        [
            (5, veryHealthy5),
            (4, healthy4),
            (3, moderate3),
            (2, lessHealthy2),
            (1, unhealthy1),
            (0, veryUnhealthy0)
        ]
    }
}

struct AggregateFilters {
    var periodType: PeriodType = .month
    var numPeriods: Int = 12
    var startDate: Date?
    var endDate: Date?
    var topCategoriesLimit: Int = 5
    var topStoresLimit: Int = 5
    var minCategoryPercentage: Double = 0
    var allTime: Bool = false             // NEW: If true, return all-time stats (ignores date filters)

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "period_type", value: periodType.rawValue),
            URLQueryItem(name: "num_periods", value: String(numPeriods)),
            URLQueryItem(name: "top_categories_limit", value: String(topCategoriesLimit)),
            URLQueryItem(name: "top_stores_limit", value: String(topStoresLimit))
        ]

        if allTime {
            items.append(URLQueryItem(name: "all_time", value: "true"))
        }

        if let startDate = startDate {
            items.append(URLQueryItem(name: "start_date", value: DateFormatter.yyyyMMdd.string(from: startDate)))
        }

        if let endDate = endDate {
            items.append(URLQueryItem(name: "end_date", value: DateFormatter.yyyyMMdd.string(from: endDate)))
        }

        if minCategoryPercentage > 0 {
            items.append(URLQueryItem(name: "min_category_percentage", value: String(minCategoryPercentage)))
        }

        return items
    }
}

// MARK: - All-Time Stats Response (for Scan View hero cards)

struct AllTimeStatsResponse: Codable {
    let totalReceipts: Int
    let totalItems: Int
    let totalSpend: Double
    let totalTransactions: Int
    let averageItemPrice: Double
    let averageHealthScore: Double?
    let topStoresByVisits: [TopStoreVisit]
    let topStoresBySpend: [TopStoreSpend]
    let topCategories: [TopCategory]?
    let firstReceiptDate: String?
    let lastReceiptDate: String?

    enum CodingKeys: String, CodingKey {
        case totalReceipts = "total_receipts"
        case totalItems = "total_items"
        case totalSpend = "total_spend"
        case totalTransactions = "total_transactions"
        case averageItemPrice = "average_item_price"
        case averageHealthScore = "average_health_score"
        case topStoresByVisits = "top_stores_by_visits"
        case topStoresBySpend = "top_stores_by_spend"
        case topCategories = "top_categories"
        case firstReceiptDate = "first_receipt_date"
        case lastReceiptDate = "last_receipt_date"
    }
}

struct TopStoreVisit: Codable, Identifiable {
    let storeName: String
    let visitCount: Int
    let rank: Int

    var id: String { storeName }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case visitCount = "visit_count"
        case rank
    }
}

struct TopStoreSpend: Codable, Identifiable {
    let storeName: String
    let totalSpent: Double
    let rank: Int

    var id: String { storeName }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case totalSpent = "total_spent"
        case rank
    }
}

struct TopCategory: Codable, Identifiable {
    let name: String
    let totalSpent: Double
    let percentage: Double
    let transactionCount: Int
    let averageHealthScore: Double?
    let rank: Int

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case name
        case totalSpent = "total_spent"
        case percentage
        case transactionCount = "transaction_count"
        case averageHealthScore = "average_health_score"
        case rank
    }

    /// Get the corresponding AnalyticsCategory for icon/display
    var analyticsCategory: AnalyticsCategory? {
        AnalyticsCategory.allCases.first { $0.displayName == name }
    }

    /// Get the SF Symbol icon for this category
    var icon: String {
        analyticsCategory?.icon ?? "shippingbox.fill"
    }
}

// MARK: - Periods Response (Lightweight period metadata for fast loading)

struct PeriodsResponse: Codable {
    let periods: [PeriodMetadata]
    let totalPeriods: Int

    enum CodingKeys: String, CodingKey {
        case periods
        case totalPeriods = "total_periods"
    }
}

struct PeriodMetadata: Codable, Identifiable {
    let period: String              // e.g., "January 2026"
    let periodStart: String         // e.g., "2026-01-01"
    let periodEnd: String           // e.g., "2026-01-31"
    let totalSpend: Double
    let receiptCount: Int
    let storeCount: Int
    let transactionCount: Int       // Number of line items (rows)
    let totalItems: Int?            // Sum of all quantities (actual items purchased)
    let averageHealthScore: Double?

    var id: String { period }

    enum CodingKeys: String, CodingKey {
        case period
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case totalSpend = "total_spend"
        case receiptCount = "receipt_count"
        case storeCount = "store_count"
        case transactionCount = "transaction_count"
        case totalItems = "total_items"
        case averageHealthScore = "average_health_score"
    }

    var startDate: Date? {
        DateFormatter.yyyyMMdd.date(from: periodStart)
    }

    var endDate: Date? {
        DateFormatter.yyyyMMdd.date(from: periodEnd)
    }
}
