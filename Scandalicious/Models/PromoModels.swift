//
//  PromoModels.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import Foundation

// MARK: - Promo Recommendation Response

enum PromoReportStatus: String, Codable {
    case ready
    case noEnrichedProfile = "no_enriched_profile"
    case noReportAvailable = "no_report_available"
}

struct PromoRecommendationResponse: Codable {
    let reportId: String?
    let reportStatus: PromoReportStatus
    let message: String
    let generatedAt: String?
    let weeklySavings: Double
    let dealCount: Int
    let promoWeek: PromoWeek
    let stores: [PromoStore]
    let preferredStores: [String]?
    let summary: PromoSummary

    var isReady: Bool { reportStatus == .ready }
    var weekKey: String { "\(promoWeek.isoYear)-W\(String(format: "%02d", promoWeek.isoWeek))" }

    enum CodingKeys: String, CodingKey {
        case reportId = "report_id"
        case reportStatus = "report_status"
        case message
        case generatedAt = "generated_at"
        case weeklySavings = "weekly_savings"
        case dealCount = "deal_count"
        case promoWeek = "promo_week"
        case stores
        case preferredStores = "preferred_stores"
        case summary
    }
}

// MARK: - Promo Week

struct PromoWeek: Codable {
    let start: String   // DD/MM format
    let end: String     // DD/MM format
    let label: String   // e.g. "Week 5"
    let isoYear: Int
    let isoWeek: Int

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case label
        case isoYear = "iso_year"
        case isoWeek = "iso_week"
    }
}

// MARK: - Store Item

struct PromoStoreItem: Codable, Identifiable {
    let itemKey: String?
    let brand: String
    let productName: String
    let originalPrice: Double
    let promoPrice: Double
    let savings: Double
    let discountPercentage: Int
    let mechanism: String
    let validityStart: String
    let validityEnd: String
    let pageNumber: Int?
    let promoFolderUrl: String?
    let savingsAmount: Double?
    let minPurchaseQty: Int?
    let effectiveUnitPrice: Double?
    let displayName: String?
    let displayMechanism: String?
    let displayDescription: String?
    let displayUnitPrice: String?
    let displaySavingsLabel: String?
    let bucket: String?
    let bucketLabel: String?

    var id: String { "\(brand)-\(productName)-\(mechanism)" }

    /// Whether both original and promo prices are available for display
    var hasPrices: Bool { originalPrice > 0 && promoPrice > 0 }

    /// Whether this is a multi-buy deal (original == promo price, savings come from quantity)
    var isMultiBuy: Bool {
        originalPrice > 0 && promoPrice > 0 && abs(originalPrice - promoPrice) < 0.01
    }

    /// Best available product label: display_name if available, else product_name
    var label: String { (displayName?.isEmpty == false ? displayName : productName) ?? productName }

    /// Best available mechanism text
    var mechanismLabel: String { (displayMechanism?.isEmpty == false ? displayMechanism : mechanism) ?? mechanism }

    /// Savings text — always use the backend's localized label
    var savingsLabel: String? { displaySavingsLabel }

    enum CodingKeys: String, CodingKey {
        case itemKey = "item_key"
        case brand
        case productName = "product_name"
        case originalPrice = "original_price"
        case promoPrice = "promo_price"
        case savings
        case discountPercentage = "discount_percentage"
        case mechanism
        case validityStart = "validity_start"
        case validityEnd = "validity_end"
        case pageNumber = "page_number"
        case promoFolderUrl = "promo_folder_url"
        case savingsAmount = "savings_amount"
        case minPurchaseQty = "min_purchase_qty"
        case effectiveUnitPrice = "effective_unit_price"
        case displayName = "display_name"
        case displayMechanism = "display_mechanism"
        case displayDescription = "display_description"
        case displayUnitPrice = "display_unit_price"
        case displaySavingsLabel = "display_savings_label"
        case bucket
        case bucketLabel = "bucket_label"
    }
}

// MARK: - Promo Store

struct PromoStore: Codable, Identifiable {
    let storeName: String
    let totalSavings: Double
    let validityEnd: String
    let items: [PromoStoreItem]

    var id: String { storeName }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case totalSavings = "total_savings"
        case validityEnd = "validity_end"
        case items
    }
}

// MARK: - Promo Summary

struct PromoSummary: Codable {
    let totalItems: Int
    let totalSavings: Double
    let storesBreakdown: [PromoStoreBreakdown]
    let bestValueStore: String?
    let bestValueSavings: Double
    let bestValueItems: Int

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case totalSavings = "total_savings"
        case storesBreakdown = "stores_breakdown"
        case bestValueStore = "best_value_store"
        case bestValueSavings = "best_value_savings"
        case bestValueItems = "best_value_items"
    }
}

// MARK: - Store Breakdown (in summary)

struct PromoStoreBreakdown: Codable, Identifiable {
    let store: String
    let items: Int
    let savings: Double

    var id: String { store }
}
