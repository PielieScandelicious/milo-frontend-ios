//
//  PromoModels.swift
//  Scandalicious
//
//  Promo item + similar-promos models. Weekly personalized report is gone;
//  the folder browser is now the primary discovery surface, and similar-promo
//  recommendations live inside the folder detail sheet.
//

import Foundation

// MARK: - Promo Store Item (single promo from a folder or similar-promos list)

struct PromoStoreItem: Codable, Identifiable, Hashable {
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
    let thumbnailUrl: String?
    let imageUrl: String?
    let storeName: String?

    var id: String { itemKey ?? "\(brand)-\(productName)-\(mechanism)" }

    var hasPrices: Bool { originalPrice > 0 && promoPrice > 0 }

    var label: String { (displayName?.isEmpty == false ? displayName : productName) ?? productName }

    var mechanismLabel: String { (displayMechanism?.isEmpty == false ? displayMechanism : mechanism) ?? mechanism }

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
        case thumbnailUrl = "thumbnail_url"
        case imageUrl = "image_url"
        case storeName = "store_name"
    }
}

// MARK: - Grid Item (view-layer wrapper binding an item to its store)

struct PromoGridItem: Identifiable, Hashable {
    let id: String
    let item: PromoStoreItem
    let storeName: String
}

// MARK: - Similar Promos Response

struct SimilarPromosSource: Codable, Hashable {
    let id: String
    let displayName: String
    let displayBrand: String?
    let normalizedBrand: String?
    let granularCategory: String
    let sourceRetailer: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case displayBrand = "display_brand"
        case normalizedBrand = "normalized_brand"
        case granularCategory = "granular_category"
        case sourceRetailer = "source_retailer"
    }
}

struct SimilarPromosResponse: Codable {
    let source: SimilarPromosSource
    let items: [PromoStoreItem]
    let generatedAt: String

    enum CodingKeys: String, CodingKey {
        case source
        case items
        case generatedAt = "generated_at"
    }
}
