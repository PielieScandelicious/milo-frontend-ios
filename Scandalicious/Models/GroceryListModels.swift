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

    var isExpired: Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let endDate = formatter.date(from: validityEnd) else { return false }
        return endDate < Calendar.current.startOfDay(for: Date())
    }

    static func from(item: PromoStoreItem, storeName: String) -> GroceryListItem {
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
            validityEnd: item.validityEnd,
            addedAt: Date(),
            isChecked: false
        )
    }
}
