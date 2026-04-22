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
    /// Full-tile crop (product + price label + brand + badge + background) — used by the product-detail view.
    /// Nil on older payloads; callers should fall back to `imageUrl`.
    let heroUrl: String?
    let storeName: String?

    // Post-promo effective unit price + pack metadata (backend >= 2026-04-20)
    let priceUnavailable: Bool
    let unitPriceValue: Double?
    let unitPriceUnit: String?
    let unitPriceQuality: String?
    let packSizeValue: Double?
    let packSizeUnit: String?
    let packCount: Int?

    // Canonical mechanism + multi-brand (backend >= 2026-04-20)
    let primaryBrand: String?
    let additionalBrands: [String]?
    let mechanismKind: String?
    let mechanismX: Double?
    let mechanismY: Double?
    let promoCampaign: String?
    /// Parent consumer category (~22 values). Distinct from the server-side granular category used for similarity.
    let category: String?

    /// Verbatim promo tile text, reformatted as Markdown by Gemini. Rendered in the detail sheet.
    let promoTextMarkdown: String?

    /// Brand to render in the UI — primaryBrand wins when the server provides it.
    var primaryBrandLabel: String {
        if let p = primaryBrand, !p.isEmpty { return p }
        return brand
    }

    /// All brands on the tile in display order (primary first), when the promo covers more than one.
    var allBrandsLabel: String? {
        guard let extra = additionalBrands, !extra.isEmpty else { return nil }
        let head = primaryBrandLabel
        return ([head] + extra).joined(separator: ", ")
    }

    var id: String { itemKey ?? "\(brand)-\(productName)-\(mechanism)" }

    var hasPrices: Bool { originalPrice > 0 && promoPrice > 0 }

    var label: String { (displayName?.isEmpty == false ? displayName : productName) ?? productName }

    var mechanismLabel: String { (displayMechanism?.isEmpty == false ? displayMechanism : mechanism) ?? mechanism }

    var savingsLabel: String? { displaySavingsLabel }

    /// Human-readable pack size, e.g. "500 g", "6 × 25 cl", "pak van 12 capsules".
    /// Returns nil when no pack info is available.
    var packSizeLabel: String? {
        guard let value = packSizeValue, value > 0, let unit = packSizeUnit, !unit.isEmpty else {
            return nil
        }
        let formattedValue: String = {
            if value == value.rounded() {
                return String(Int(value))
            }
            return String(value).replacingOccurrences(of: ".", with: ",")
        }()
        let unitLabel: String = {
            switch unit.lowercased() {
            case "g", "kg", "ml", "cl", "l": return unit.lowercased() == "l" ? "L" : unit.lowercased()
            case "stuk": return "stuks"
            case "rol": return "rollen"
            case "capsule": return "capsules"
            case "tab": return "tabs"
            case "doekje": return "doekjes"
            case "zakje": return "zakjes"
            default: return unit
            }
        }()
        let core = "\(formattedValue) \(unitLabel)"
        if let count = packCount, count > 1 {
            return "\(count) × \(core)"
        }
        return core
    }

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
        case heroUrl = "hero_url"
        case storeName = "store_name"
        case priceUnavailable = "price_unavailable"
        case unitPriceValue = "unit_price_value"
        case unitPriceUnit = "unit_price_unit"
        case unitPriceQuality = "unit_price_quality"
        case packSizeValue = "pack_size_value"
        case packSizeUnit = "pack_size_unit"
        case packCount = "pack_count"
        case primaryBrand = "primary_brand"
        case additionalBrands = "additional_brands"
        case mechanismKind = "mechanism_kind"
        case mechanismX = "mechanism_x"
        case mechanismY = "mechanism_y"
        case promoCampaign = "promo_campaign"
        case category
        case promoTextMarkdown = "promo_text_markdown"
    }

    // Memberwise init with defaults for new fields, so older call sites keep compiling.
    init(
        itemKey: String?,
        brand: String,
        productName: String,
        originalPrice: Double,
        promoPrice: Double,
        savings: Double,
        discountPercentage: Int,
        mechanism: String,
        validityStart: String,
        validityEnd: String,
        pageNumber: Int?,
        promoFolderUrl: String?,
        savingsAmount: Double?,
        minPurchaseQty: Int?,
        effectiveUnitPrice: Double?,
        displayName: String?,
        displayMechanism: String?,
        displayDescription: String?,
        displayUnitPrice: String?,
        displaySavingsLabel: String?,
        bucket: String?,
        bucketLabel: String?,
        thumbnailUrl: String?,
        imageUrl: String?,
        heroUrl: String? = nil,
        storeName: String?,
        priceUnavailable: Bool = false,
        unitPriceValue: Double? = nil,
        unitPriceUnit: String? = nil,
        unitPriceQuality: String? = nil,
        packSizeValue: Double? = nil,
        packSizeUnit: String? = nil,
        packCount: Int? = nil,
        primaryBrand: String? = nil,
        additionalBrands: [String]? = nil,
        mechanismKind: String? = nil,
        mechanismX: Double? = nil,
        mechanismY: Double? = nil,
        promoCampaign: String? = nil,
        category: String? = nil,
        promoTextMarkdown: String? = nil
    ) {
        self.itemKey = itemKey
        self.brand = brand
        self.productName = productName
        self.originalPrice = originalPrice
        self.promoPrice = promoPrice
        self.savings = savings
        self.discountPercentage = discountPercentage
        self.mechanism = mechanism
        self.validityStart = validityStart
        self.validityEnd = validityEnd
        self.pageNumber = pageNumber
        self.promoFolderUrl = promoFolderUrl
        self.savingsAmount = savingsAmount
        self.minPurchaseQty = minPurchaseQty
        self.effectiveUnitPrice = effectiveUnitPrice
        self.displayName = displayName
        self.displayMechanism = displayMechanism
        self.displayDescription = displayDescription
        self.displayUnitPrice = displayUnitPrice
        self.displaySavingsLabel = displaySavingsLabel
        self.bucket = bucket
        self.bucketLabel = bucketLabel
        self.thumbnailUrl = thumbnailUrl
        self.imageUrl = imageUrl
        self.heroUrl = heroUrl
        self.storeName = storeName
        self.priceUnavailable = priceUnavailable
        self.unitPriceValue = unitPriceValue
        self.unitPriceUnit = unitPriceUnit
        self.unitPriceQuality = unitPriceQuality
        self.packSizeValue = packSizeValue
        self.packSizeUnit = packSizeUnit
        self.packCount = packCount
        self.primaryBrand = primaryBrand
        self.additionalBrands = additionalBrands
        self.mechanismKind = mechanismKind
        self.mechanismX = mechanismX
        self.mechanismY = mechanismY
        self.promoCampaign = promoCampaign
        self.category = category
        self.promoTextMarkdown = promoTextMarkdown
    }

    // Backward-compatible decoder: older API responses (no unit-pricing fields) stay decodable.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.itemKey = try c.decodeIfPresent(String.self, forKey: .itemKey)
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        self.productName = try c.decodeIfPresent(String.self, forKey: .productName) ?? ""
        self.originalPrice = try c.decodeIfPresent(Double.self, forKey: .originalPrice) ?? 0
        self.promoPrice = try c.decodeIfPresent(Double.self, forKey: .promoPrice) ?? 0
        self.savings = try c.decodeIfPresent(Double.self, forKey: .savings) ?? 0
        self.discountPercentage = try c.decodeIfPresent(Int.self, forKey: .discountPercentage) ?? 0
        self.mechanism = try c.decodeIfPresent(String.self, forKey: .mechanism) ?? ""
        self.validityStart = try c.decodeIfPresent(String.self, forKey: .validityStart) ?? ""
        self.validityEnd = try c.decodeIfPresent(String.self, forKey: .validityEnd) ?? ""
        self.pageNumber = try c.decodeIfPresent(Int.self, forKey: .pageNumber)
        self.promoFolderUrl = try c.decodeIfPresent(String.self, forKey: .promoFolderUrl)
        self.savingsAmount = try c.decodeIfPresent(Double.self, forKey: .savingsAmount)
        self.minPurchaseQty = try c.decodeIfPresent(Int.self, forKey: .minPurchaseQty)
        self.effectiveUnitPrice = try c.decodeIfPresent(Double.self, forKey: .effectiveUnitPrice)
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.displayMechanism = try c.decodeIfPresent(String.self, forKey: .displayMechanism)
        self.displayDescription = try c.decodeIfPresent(String.self, forKey: .displayDescription)
        self.displayUnitPrice = try c.decodeIfPresent(String.self, forKey: .displayUnitPrice)
        self.displaySavingsLabel = try c.decodeIfPresent(String.self, forKey: .displaySavingsLabel)
        self.bucket = try c.decodeIfPresent(String.self, forKey: .bucket)
        self.bucketLabel = try c.decodeIfPresent(String.self, forKey: .bucketLabel)
        self.thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        self.imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        self.heroUrl = try c.decodeIfPresent(String.self, forKey: .heroUrl)
        self.storeName = try c.decodeIfPresent(String.self, forKey: .storeName)
        self.priceUnavailable = try c.decodeIfPresent(Bool.self, forKey: .priceUnavailable) ?? false
        self.unitPriceValue = try c.decodeIfPresent(Double.self, forKey: .unitPriceValue)
        self.unitPriceUnit = try c.decodeIfPresent(String.self, forKey: .unitPriceUnit)
        self.unitPriceQuality = try c.decodeIfPresent(String.self, forKey: .unitPriceQuality)
        self.packSizeValue = try c.decodeIfPresent(Double.self, forKey: .packSizeValue)
        self.packSizeUnit = try c.decodeIfPresent(String.self, forKey: .packSizeUnit)
        self.packCount = try c.decodeIfPresent(Int.self, forKey: .packCount)
        self.primaryBrand = try c.decodeIfPresent(String.self, forKey: .primaryBrand)
        self.additionalBrands = try c.decodeIfPresent([String].self, forKey: .additionalBrands)
        self.mechanismKind = try c.decodeIfPresent(String.self, forKey: .mechanismKind)
        self.mechanismX = try c.decodeIfPresent(Double.self, forKey: .mechanismX)
        self.mechanismY = try c.decodeIfPresent(Double.self, forKey: .mechanismY)
        self.promoCampaign = try c.decodeIfPresent(String.self, forKey: .promoCampaign)
        self.category = try c.decodeIfPresent(String.self, forKey: .category)
        self.promoTextMarkdown = try c.decodeIfPresent(String.self, forKey: .promoTextMarkdown)
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
