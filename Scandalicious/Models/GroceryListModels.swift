//
//  GroceryListModels.swift
//  Scandalicious
//

import Foundation

struct GroceryListItem: Codable, Identifiable, Equatable {
    let id: String
    let itemKey: String?
    let brand: String
    let productName: String
    let displayName: String?
    let imageUrl: String?
    /// Full-tile crop URL — shown in the product-detail sheet when opened from the grocery list.
    /// Nil for entries saved before the field existed; detail sheet falls back to `imageUrl`.
    let heroUrl: String?
    let storeName: String
    let promoPrice: Double
    let originalPrice: Double
    let savings: Double
    let discountPercentage: Int
    let mechanism: String
    let displayMechanism: String?
    let minPurchaseQty: Int?
    let promoTextMarkdown: String?
    let validityEnd: String // "yyyy-MM-dd"
    let addedAt: Date
    var isChecked: Bool

    // Coupon fields. When isCoupon is true the item is rendered in the
    // dedicated "Coupons" lane at the top of the list instead of the grocery
    // section, and the detail sheet renders a scannable barcode.
    let isCoupon: Bool
    let couponType: String?
    let couponBarcodeValue: String?
    let couponBarcodeFormat: String?
    let couponValue: Double?
    let couponMinPurchase: String?
    let couponValidityEnd: String?

    var label: String {
        (displayName?.isEmpty == false ? displayName : productName) ?? productName
    }

    var mechanismLabel: String {
        (displayMechanism?.isEmpty == false ? displayMechanism : mechanism) ?? mechanism
    }

    var daysRemaining: Int? {
        let parts = validityEnd.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let endDate = Calendar.current.date(from: components) else { return nil }
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.startOfDay(for: endDate)
        return Calendar.current.dateComponents([.day], from: today, to: end).day
    }

    var isExpired: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let endDate = formatter.date(from: validityEnd) else { return false }
        return endDate < Calendar.current.startOfDay(for: Date())
    }

    func toPromoStoreItem() -> PromoStoreItem {
        PromoStoreItem(
            itemKey: itemKey,
            brand: brand,
            productName: productName,
            originalPrice: originalPrice,
            promoPrice: promoPrice,
            savings: savings,
            discountPercentage: discountPercentage,
            mechanism: mechanism,
            validityStart: "",
            validityEnd: validityEnd,
            pageNumber: nil,
            promoFolderUrl: nil,
            savingsAmount: savings,
            minPurchaseQty: minPurchaseQty,
            effectiveUnitPrice: nil,
            displayName: displayName,
            displayMechanism: displayMechanism,
            displayDescription: nil,
            displayUnitPrice: nil,
            displaySavingsLabel: nil,
            bucket: nil,
            bucketLabel: nil,
            thumbnailUrl: imageUrl,
            imageUrl: imageUrl,
            heroUrl: heroUrl,
            storeName: storeName,
            promoTextMarkdown: promoTextMarkdown,
            isCoupon: isCoupon,
            couponType: couponType,
            couponBarcodeValue: couponBarcodeValue,
            couponBarcodeFormat: couponBarcodeFormat,
            couponValue: couponValue,
            couponMinPurchase: couponMinPurchase,
            couponValidityEnd: couponValidityEnd
        )
    }

    static func from(item: PromoStoreItem, storeName: String, validityEndOverride: String? = nil) -> GroceryListItem {
        GroceryListItem(
            id: UUID().uuidString,
            itemKey: item.itemKey,
            brand: item.brand,
            productName: item.productName,
            displayName: item.displayName,
            imageUrl: item.imageUrl ?? item.thumbnailUrl,
            heroUrl: item.heroUrl,
            storeName: storeName,
            promoPrice: item.promoPrice,
            originalPrice: item.originalPrice,
            savings: item.savings,
            discountPercentage: item.discountPercentage,
            mechanism: item.mechanism,
            displayMechanism: item.displayMechanism,
            minPurchaseQty: item.minPurchaseQty,
            promoTextMarkdown: item.promoTextMarkdown,
            validityEnd: validityEndOverride ?? item.validityEnd,
            addedAt: Date(),
            isChecked: false,
            isCoupon: item.isCoupon,
            couponType: item.couponType,
            couponBarcodeValue: item.couponBarcodeValue,
            couponBarcodeFormat: item.couponBarcodeFormat,
            couponValue: item.couponValue,
            couponMinPurchase: item.couponMinPurchase,
            couponValidityEnd: item.couponValidityEnd
        )
    }

    // Custom decoder so entries saved by older app versions (no coupon fields)
    // still decode — otherwise the whole grocery list fails to load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.itemKey = try c.decodeIfPresent(String.self, forKey: .itemKey)
        self.brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        self.productName = try c.decodeIfPresent(String.self, forKey: .productName) ?? ""
        self.displayName = try c.decodeIfPresent(String.self, forKey: .displayName)
        self.imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        self.heroUrl = try c.decodeIfPresent(String.self, forKey: .heroUrl)
        self.storeName = try c.decodeIfPresent(String.self, forKey: .storeName) ?? ""
        self.promoPrice = try c.decodeIfPresent(Double.self, forKey: .promoPrice) ?? 0
        self.originalPrice = try c.decodeIfPresent(Double.self, forKey: .originalPrice) ?? 0
        self.savings = try c.decodeIfPresent(Double.self, forKey: .savings) ?? 0
        self.discountPercentage = try c.decodeIfPresent(Int.self, forKey: .discountPercentage) ?? 0
        self.mechanism = try c.decodeIfPresent(String.self, forKey: .mechanism) ?? ""
        self.displayMechanism = try c.decodeIfPresent(String.self, forKey: .displayMechanism)
        self.minPurchaseQty = try c.decodeIfPresent(Int.self, forKey: .minPurchaseQty)
        self.promoTextMarkdown = try c.decodeIfPresent(String.self, forKey: .promoTextMarkdown)
        self.validityEnd = try c.decodeIfPresent(String.self, forKey: .validityEnd) ?? ""
        self.addedAt = try c.decodeIfPresent(Date.self, forKey: .addedAt) ?? Date()
        self.isChecked = try c.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        self.isCoupon = try c.decodeIfPresent(Bool.self, forKey: .isCoupon) ?? false
        self.couponType = try c.decodeIfPresent(String.self, forKey: .couponType)
        self.couponBarcodeValue = try c.decodeIfPresent(String.self, forKey: .couponBarcodeValue)
        self.couponBarcodeFormat = try c.decodeIfPresent(String.self, forKey: .couponBarcodeFormat)
        self.couponValue = try c.decodeIfPresent(Double.self, forKey: .couponValue)
        self.couponMinPurchase = try c.decodeIfPresent(String.self, forKey: .couponMinPurchase)
        self.couponValidityEnd = try c.decodeIfPresent(String.self, forKey: .couponValidityEnd)
    }

    // Explicit memberwise init (adds defaults for coupon fields so existing call sites compile).
    init(
        id: String,
        itemKey: String?,
        brand: String,
        productName: String,
        displayName: String?,
        imageUrl: String?,
        heroUrl: String?,
        storeName: String,
        promoPrice: Double,
        originalPrice: Double,
        savings: Double,
        discountPercentage: Int,
        mechanism: String,
        displayMechanism: String?,
        minPurchaseQty: Int?,
        promoTextMarkdown: String? = nil,
        validityEnd: String,
        addedAt: Date,
        isChecked: Bool,
        isCoupon: Bool = false,
        couponType: String? = nil,
        couponBarcodeValue: String? = nil,
        couponBarcodeFormat: String? = nil,
        couponValue: Double? = nil,
        couponMinPurchase: String? = nil,
        couponValidityEnd: String? = nil
    ) {
        self.id = id
        self.itemKey = itemKey
        self.brand = brand
        self.productName = productName
        self.displayName = displayName
        self.imageUrl = imageUrl
        self.heroUrl = heroUrl
        self.storeName = storeName
        self.promoPrice = promoPrice
        self.originalPrice = originalPrice
        self.savings = savings
        self.discountPercentage = discountPercentage
        self.mechanism = mechanism
        self.displayMechanism = displayMechanism
        self.minPurchaseQty = minPurchaseQty
        self.promoTextMarkdown = promoTextMarkdown
        self.validityEnd = validityEnd
        self.addedAt = addedAt
        self.isChecked = isChecked
        self.isCoupon = isCoupon
        self.couponType = couponType
        self.couponBarcodeValue = couponBarcodeValue
        self.couponBarcodeFormat = couponBarcodeFormat
        self.couponValue = couponValue
        self.couponMinPurchase = couponMinPurchase
        self.couponValidityEnd = couponValidityEnd
    }
}
