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
    let receiptDate: String?
    let totalAmount: Double?
    let itemsCount: Int  // Required field from backend (not optional)
    let transactions: [ReceiptTransaction]
    let warnings: [String]  // Added missing warnings array
    
    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case status
        case storeName = "store_name"
        case receiptDate = "receipt_date"
        case totalAmount = "total_amount"
        case itemsCount = "items_count"
        case transactions
        case warnings
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
    
    var id: String {
        "\(itemName)_\(itemPrice)_\(quantity)"
    }
    
    enum CodingKeys: String, CodingKey {
        case itemName = "item_name"
        case itemPrice = "item_price"
        case quantity
        case unitPrice = "unit_price"
        case category
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
        case .dairyAndEggs: return "carton.fill"
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
