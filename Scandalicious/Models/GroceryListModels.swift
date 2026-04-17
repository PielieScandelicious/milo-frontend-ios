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
    let storeName: String
    let promoPrice: Double
    let originalPrice: Double
    let savings: Double
    let discountPercentage: Int
    let mechanism: String
    let displayMechanism: String?
    let minPurchaseQty: Int?
    let validityEnd: String // "yyyy-MM-dd"
    let addedAt: Date
    var isChecked: Bool

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
            storeName: storeName
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
            storeName: storeName,
            promoPrice: item.promoPrice,
            originalPrice: item.originalPrice,
            savings: item.savings,
            discountPercentage: item.discountPercentage,
            mechanism: item.mechanism,
            displayMechanism: item.displayMechanism,
            minPurchaseQty: item.minPurchaseQty,
            validityEnd: validityEndOverride ?? item.validityEnd,
            addedAt: Date(),
            isChecked: false
        )
    }
}
