//
//  PromoModels.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import Foundation
import SwiftUI

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
    let topPicks: [PromoTopPick]
    let stores: [PromoStore]
    let smartSwitch: PromoSmartSwitch?
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
        case topPicks = "top_picks"
        case stores
        case smartSwitch = "smart_switch"
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

// MARK: - Top Pick

struct PromoTopPick: Codable, Identifiable {
    let itemKey: String?
    let brand: String
    let productName: String
    let emoji: String
    let store: String
    let originalPrice: Double
    let promoPrice: Double
    let savings: Double
    let discountPercentage: Int
    let mechanism: String
    let validityStart: String
    let validityEnd: String
    let reason: String
    let pageNumber: Int?
    let promoFolderUrl: String?

    var id: String { "\(brand)-\(productName)-\(store)" }

    enum CodingKeys: String, CodingKey {
        case itemKey = "item_key"
        case brand
        case productName = "product_name"
        case emoji
        case store
        case originalPrice = "original_price"
        case promoPrice = "promo_price"
        case savings
        case discountPercentage = "discount_percentage"
        case mechanism
        case validityStart = "validity_start"
        case validityEnd = "validity_end"
        case reason
        case pageNumber = "page_number"
        case promoFolderUrl = "promo_folder_url"
    }
}

// MARK: - Store Item

struct PromoStoreItem: Codable, Identifiable {
    let itemKey: String?
    let brand: String
    let productName: String
    let emoji: String
    let originalPrice: Double
    let promoPrice: Double
    let savings: Double
    let discountPercentage: Int
    let mechanism: String
    let validityStart: String
    let validityEnd: String
    let pageNumber: Int?
    let promoFolderUrl: String?

    var id: String { "\(brand)-\(productName)-\(mechanism)" }

    enum CodingKeys: String, CodingKey {
        case itemKey = "item_key"
        case brand
        case productName = "product_name"
        case emoji
        case originalPrice = "original_price"
        case promoPrice = "promo_price"
        case savings
        case discountPercentage = "discount_percentage"
        case mechanism
        case validityStart = "validity_start"
        case validityEnd = "validity_end"
        case pageNumber = "page_number"
        case promoFolderUrl = "promo_folder_url"
    }
}

// MARK: - Promo Store

struct PromoStore: Codable, Identifiable {
    let storeName: String
    let storeColor: String      // Emoji: "🟧", "🟥", etc.
    let totalSavings: Double
    let validityEnd: String
    let items: [PromoStoreItem]
    let tip: String

    var id: String { storeName }

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case storeColor = "store_color"
        case totalSavings = "total_savings"
        case validityEnd = "validity_end"
        case items
        case tip
    }

    /// Maps store_color emoji to SwiftUI Color
    var color: Color {
        switch storeColor {
        case "🟦": return Color(red: 0.20, green: 0.55, blue: 0.85)   // Carrefour blue
        case "🟧": return Color(red: 0.95, green: 0.55, blue: 0.15)   // Colruyt orange
        case "🟩": return Color(red: 0.20, green: 0.70, blue: 0.40)   // Delhaize green
        case "🟨": return Color(red: 0.95, green: 0.80, blue: 0.20)   // Albert Heijn yellow
        case "🟪": return Color(red: 0.55, green: 0.35, blue: 0.85)   // Lidl purple
        case "🟥": return Color(red: 0.90, green: 0.25, blue: 0.25)   // Aldi red
        case "⬜": return Color(red: 0.60, green: 0.60, blue: 0.65)   // Other gray
        default:
            let colors: [Color] = [.orange, .blue, .green, .red, .purple, .cyan, .pink, .yellow]
            let index = abs(storeName.hashValue) % colors.count
            return colors[index]
        }
    }
}

// MARK: - Smart Switch

struct PromoSmartSwitch: Codable {
    let fromBrand: String
    let toBrand: String
    let emoji: String
    let productType: String
    let savings: Double
    let mechanism: String
    let reason: String

    enum CodingKeys: String, CodingKey {
        case fromBrand = "from_brand"
        case toBrand = "to_brand"
        case emoji
        case productType = "product_type"
        case savings
        case mechanism
        case reason
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
    let closingNudge: String

    enum CodingKeys: String, CodingKey {
        case totalItems = "total_items"
        case totalSavings = "total_savings"
        case storesBreakdown = "stores_breakdown"
        case bestValueStore = "best_value_store"
        case bestValueSavings = "best_value_savings"
        case bestValueItems = "best_value_items"
        case closingNudge = "closing_nudge"
    }
}

// MARK: - Store Breakdown (in summary)

struct PromoStoreBreakdown: Codable, Identifiable {
    let store: String
    let items: Int
    let savings: Double

    var id: String { store }
}
