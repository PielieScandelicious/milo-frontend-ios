//
//  ReceiptModels.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation

// MARK: - Receipt Upload Response

struct ReceiptUploadResponse: Equatable, Sendable, Codable {
    let receiptId: String
    let status: ReceiptStatus
    let storeName: String?
    let receiptDate: String?  // ISO format "YYYY-MM-DD"
    let totalAmount: Double?
    let itemsCount: Int  // Required field from backend (not optional)
    let transactions: [ReceiptTransaction]
    let warnings: [String]  // Required field - always returned as array (may be empty)
    let averageHealthScore: Double?  // Average health score for food items in the receipt

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case status
        case storeName = "store_name"
        case receiptDate = "receipt_date"
        case totalAmount = "total_amount"
        case itemsCount = "items_count"
        case transactions  // Backend returns "transactions"
        case warnings
        case averageHealthScore = "average_health_score"
    }

    var parsedDate: Date? {
        guard let receiptDate = receiptDate else { return nil }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: receiptDate) ?? parseCustomDateFormat(receiptDate)
    }

    private func parseCustomDateFormat(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }

    /// Calculate average health score from transactions (if not provided by backend)
    var calculatedAverageHealthScore: Double? {
        // If backend provides it, use that
        if let avg = averageHealthScore {
            return avg
        }
        // Otherwise calculate from transactions
        let scores = transactions.compactMap { $0.healthScore }
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }
}

// MARK: - Receipt Status

enum ReceiptStatus: String, Codable, Sendable {
    case pending
    case processing
    case completed
    case failed
    case success // Keeping for backward compatibility
}

// MARK: - Receipt Transaction

struct ReceiptTransaction: Identifiable, Equatable, Sendable, Codable {
    let itemName: String
    let itemPrice: Double
    let quantity: Int
    let unitPrice: Double?
    let category: ReceiptCategory
    let healthScore: Int?  // 0-5 for food items, nil for non-food

    // Generate a unique ID using UUID to handle duplicate items
    let id: UUID

    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case itemPrice = "item_price"
        case quantity
        case unitPrice = "unit_price"
        case category
        case healthScore = "health_score"
    }

    // Custom initializer to generate UUID
    init(itemName: String, itemPrice: Double, quantity: Int, unitPrice: Double?, category: ReceiptCategory, healthScore: Int? = nil) {
        self.itemName = itemName
        self.itemPrice = itemPrice
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.category = category
        self.healthScore = healthScore
        self.id = UUID()
    }

    // Decode initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemName = try container.decode(String.self, forKey: .itemName)
        itemPrice = try container.decode(Double.self, forKey: .itemPrice)
        quantity = try container.decode(Int.self, forKey: .quantity)
        unitPrice = try container.decodeIfPresent(Double.self, forKey: .unitPrice)
        category = try container.decode(ReceiptCategory.self, forKey: .category)
        healthScore = try container.decodeIfPresent(Int.self, forKey: .healthScore)
        // Generate a unique ID for each decoded transaction
        id = UUID()
    }

    // Encode function (ID is not encoded, will be regenerated on decode)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(itemName, forKey: .itemName)
        try container.encode(itemPrice, forKey: .itemPrice)
        try container.encode(quantity, forKey: .quantity)
        try container.encodeIfPresent(unitPrice, forKey: .unitPrice)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(healthScore, forKey: .healthScore)
    }
}

// MARK: - Receipt Category

enum ReceiptCategory: String, Codable, CaseIterable, Sendable {
    case meatAndFish = "Meat & Fish"
    case alcohol = "Alcohol"
    case drinksSoftSoda = "Drinks (Soft/Soda)"
    case drinksWater = "Drinks (Water)"
    case household = "Household"
    case snacksAndSweets = "Snacks & Sweets"
    case freshProduce = "Fresh Produce"
    case dairyAndEggs = "Dairy & Eggs"
    case readyMeals = "Ready Meals"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case personalCare = "Personal Care"
    case frozen = "Frozen"
    case babyAndKids = "Baby & Kids"
    case petSupplies = "Pet Supplies"
    case other = "Other"
    
    var displayName: String {
        rawValue
    }
    
    var icon: String {
        switch self {
        case .meatAndFish: return "fish.fill"
        case .alcohol: return "wineglass.fill"
        case .drinksSoftSoda: return "cup.and.saucer.fill"
        case .drinksWater: return "waterbottle.fill"
        case .household: return "house.fill"
        case .snacksAndSweets: return "birthday.cake.fill"
        case .freshProduce: return "leaf.fill"
        case .dairyAndEggs: return "mug.fill"  // Changed from "carton.fill" which doesn't exist
        case .readyMeals: return "takeoutbag.and.cup.and.straw.fill"
        case .bakery: return "croissant.fill"
        case .pantry: return "cabinet.fill"
        case .personalCare: return "sparkles"
        case .frozen: return "snowflake"
        case .babyAndKids: return "figure.and.child.holdinghands"
        case .petSupplies: return "pawprint.fill"
        case .other: return "shippingbox.fill"
        }
    }
    
    var color: String {
        switch self {
        case .meatAndFish: return "red"
        case .alcohol: return "purple"
        case .drinksSoftSoda: return "orange"
        case .drinksWater: return "blue"
        case .household: return "gray"
        case .snacksAndSweets: return "pink"
        case .freshProduce: return "green"
        case .dairyAndEggs: return "yellow"
        case .readyMeals: return "brown"
        case .bakery: return "orange"
        case .pantry: return "brown"
        case .personalCare: return "mint"
        case .frozen: return "cyan"
        case .babyAndKids: return "pink"
        case .petSupplies: return "brown"
        case .other: return "gray"
        }
    }
}

// MARK: - Receipt Upload State

enum ReceiptUploadState: Equatable {
    case idle
    case uploading
    case processing
    case success(ReceiptUploadResponse)
    case failed(String)
}
