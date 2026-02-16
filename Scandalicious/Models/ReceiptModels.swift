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
    let isDuplicate: Bool  // Whether this receipt was already uploaded before
    let duplicateScore: Double?  // Confidence score for duplicate detection (0.0 - 1.0)

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
        case isDuplicate = "is_duplicate"
        case duplicateScore = "duplicate_score"
    }

    // Custom init for manual construction (e.g., previews)
    init(receiptId: String, status: ReceiptStatus, storeName: String?, receiptDate: String?, totalAmount: Double?, itemsCount: Int, transactions: [ReceiptTransaction], warnings: [String], averageHealthScore: Double?, isDuplicate: Bool = false, duplicateScore: Double? = nil) {
        self.receiptId = receiptId
        self.status = status
        self.storeName = storeName
        self.receiptDate = receiptDate
        self.totalAmount = totalAmount
        self.itemsCount = itemsCount
        self.transactions = transactions
        self.warnings = warnings
        self.averageHealthScore = averageHealthScore
        self.isDuplicate = isDuplicate
        self.duplicateScore = duplicateScore
    }

    // Custom decoder for backward compatibility (handles missing is_duplicate)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        receiptId = try container.decode(String.self, forKey: .receiptId)
        status = try container.decode(ReceiptStatus.self, forKey: .status)
        storeName = try container.decodeIfPresent(String.self, forKey: .storeName)
        receiptDate = try container.decodeIfPresent(String.self, forKey: .receiptDate)
        totalAmount = try container.decodeIfPresent(Double.self, forKey: .totalAmount)
        itemsCount = try container.decode(Int.self, forKey: .itemsCount)
        transactions = try container.decode([ReceiptTransaction].self, forKey: .transactions)
        warnings = try container.decode([String].self, forKey: .warnings)
        averageHealthScore = try container.decodeIfPresent(Double.self, forKey: .averageHealthScore)
        isDuplicate = try container.decodeIfPresent(Bool.self, forKey: .isDuplicate) ?? false
        duplicateScore = try container.decodeIfPresent(Double.self, forKey: .duplicateScore)
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
    let itemId: String?  // Backend item ID for deletion (may be nil for older responses)
    let itemName: String
    let itemPrice: Double
    let quantity: Int
    let unitPrice: Double?
    let category: String
    let healthScore: Int?  // 0-5 for food items, nil for non-food
    let originalDescription: String?  // Raw OCR text
    let normalizedBrand: String?  // Brand name
    let normalizedName: String?  // Cleaned product name

    // Generate a unique ID using UUID to handle duplicate items
    let id: UUID

    /// Display name: prefer original_description if available, else item_name
    var displayName: String {
        (originalDescription ?? itemName).capitalized
    }

    /// Subtitle: normalized_brand shown beneath the description
    var displayDescription: String? {
        normalizedBrand?.capitalized
    }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case itemName = "item_name"
        case itemPrice = "item_price"
        case quantity
        case unitPrice = "unit_price"
        case category
        case healthScore = "health_score"
        case originalDescription = "original_description"
        case normalizedBrand = "normalized_brand"
        case normalizedName = "normalized_name"
    }

    // Custom initializer to generate UUID
    init(itemId: String? = nil, itemName: String, itemPrice: Double, quantity: Int, unitPrice: Double?, category: String, healthScore: Int? = nil, originalDescription: String? = nil, normalizedBrand: String? = nil, normalizedName: String? = nil) {
        self.itemId = itemId
        self.itemName = itemName
        self.itemPrice = itemPrice
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.category = category
        self.healthScore = healthScore
        self.originalDescription = originalDescription
        self.normalizedBrand = normalizedBrand
        self.normalizedName = normalizedName
        self.id = UUID()
    }

    // Decode initializer
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try container.decodeIfPresent(String.self, forKey: .itemId)
        itemName = try container.decode(String.self, forKey: .itemName)
        itemPrice = try container.decode(Double.self, forKey: .itemPrice)
        quantity = try container.decode(Int.self, forKey: .quantity)
        unitPrice = try container.decodeIfPresent(Double.self, forKey: .unitPrice)
        category = try container.decode(String.self, forKey: .category)
        healthScore = try container.decodeIfPresent(Int.self, forKey: .healthScore)
        originalDescription = try container.decodeIfPresent(String.self, forKey: .originalDescription)
        normalizedBrand = try container.decodeIfPresent(String.self, forKey: .normalizedBrand)
        normalizedName = try container.decodeIfPresent(String.self, forKey: .normalizedName)
        // Generate a unique ID for each decoded transaction
        id = UUID()
    }

    // Encode function (ID is not encoded, will be regenerated on decode)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(itemId, forKey: .itemId)
        try container.encode(itemName, forKey: .itemName)
        try container.encode(itemPrice, forKey: .itemPrice)
        try container.encode(quantity, forKey: .quantity)
        try container.encodeIfPresent(unitPrice, forKey: .unitPrice)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(healthScore, forKey: .healthScore)
        try container.encodeIfPresent(originalDescription, forKey: .originalDescription)
        try container.encodeIfPresent(normalizedBrand, forKey: .normalizedBrand)
        try container.encodeIfPresent(normalizedName, forKey: .normalizedName)
    }
}

// MARK: - Receipt Upload Accepted Response (HTTP 202)

struct ReceiptUploadAcceptedResponse: Codable, Sendable, Equatable {
    let receiptId: String
    let status: ReceiptStatus
    let filename: String

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case status
        case filename
    }
}

// MARK: - Receipt Status Response (Polling)

struct ReceiptStatusResponse: Codable, Sendable {
    let receiptId: String
    let status: ReceiptStatus
    let filename: String?
    let detectedDate: String?
    let storeName: String?
    let totalAmount: Double?
    let itemsCount: Int
    let errorMessage: String?

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case status
        case filename
        case detectedDate = "detected_date"
        case storeName = "store_name"
        case totalAmount = "total_amount"
        case itemsCount = "items_count"
        case errorMessage = "error_message"
    }
}

// MARK: - Processing Receipt (Local Tracking)

struct ProcessingReceipt: Identifiable, Codable, Equatable {
    let id: String          // receipt_id from backend
    let filename: String
    let startedAt: Date
    var status: ReceiptStatus
    var storeName: String?
    var totalAmount: Double?
    var itemsCount: Int
    var errorMessage: String?
    var detectedDate: String?
    var completedAt: Date?

    var isTerminal: Bool {
        status == .completed || status == .success || status == .failed
    }

    var displayName: String {
        if let store = storeName {
            return store.localizedCapitalized
        }
        let name = (filename as NSString).deletingPathExtension
        return name.count > 25 ? String(name.prefix(22)) + "..." : name
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
