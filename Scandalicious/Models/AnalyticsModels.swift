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
    
    var displayName: String {
        rawValue.capitalized
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
    let periods: [TrendPeriod]
    
    enum CodingKeys: String, CodingKey {
        case periodType = "period_type"
        case periods
    }
}

struct TrendPeriod: Codable, Identifiable {
    let periodStart: String
    let periodEnd: String
    let totalSpend: Double
    let transactionCount: Int
    let averageHealthScore: Double?  // Average health score for this period

    var id: String { periodStart }

    enum CodingKeys: String, CodingKey {
        case periodStart = "period_start"
        case periodEnd = "period_end"
        case totalSpend = "total_spend"
        case transactionCount = "transaction_count"
        case averageHealthScore = "average_health_score"
    }

    init(periodStart: String, periodEnd: String, totalSpend: Double, transactionCount: Int, averageHealthScore: Double? = nil) {
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

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case period
        case startDate = "start_date"
        case endDate = "end_date"
        case totalSpend = "total_store_spend"
        case visitCount = "store_visits"
        case categories
        case averageHealthScore = "average_health_score"
    }

    init(storeName: String, period: String, startDate: String, endDate: String, totalSpend: Double, visitCount: Int, categories: [CategoryBreakdown], averageHealthScore: Double? = nil) {
        self.storeName = storeName
        self.period = period
        self.startDate = startDate
        self.endDate = endDate
        self.totalSpend = totalSpend
        self.visitCount = visitCount
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
        
        items.append(URLQueryItem(name: "period", value: period.rawValue))
        
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
