//
//  PromoFolderModels.swift
//  Scandalicious
//
//  Models for browsable promo folder pages served from R2.
//

import Foundation
import SwiftUI

// MARK: - Folder Page Hotspot

struct PromoFolderHotspot: Codable, Identifiable {
    let itemId: String
    let pageNumber: Int
    let tileBboxXMin: CGFloat
    let tileBboxYMin: CGFloat
    let tileBboxXMax: CGFloat
    let tileBboxYMax: CGFloat
    let displayName: String
    let displayBrand: String?
    let displayMechanism: String
    let originalPrice: Double
    let promoPrice: Double
    let savingsAmount: Double
    let discountPercentage: Int
    let minPurchaseQty: Int
    let validityEnd: String
    let thumbnailUrl: String?
    let imageUrl: String?
    let storeName: String
    let promoTextMarkdown: String?

    var id: String { itemId }

    /// Convert normalized 0-1 coordinates to a CGRect within the actual displayed image area,
    /// accounting for scaleAspectFit letterboxing.
    func tileRect(in imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.origin.x + tileBboxXMin * imageRect.width,
            y: imageRect.origin.y + tileBboxYMin * imageRect.height,
            width: (tileBboxXMax - tileBboxXMin) * imageRect.width,
            height: (tileBboxYMax - tileBboxYMin) * imageRect.height
        )
    }

    /// Convert to PromoStoreItem for GroceryListItem.from()
    func toPromoStoreItem() -> PromoStoreItem {
        PromoStoreItem(
            itemKey: itemId,
            brand: displayBrand ?? "",
            productName: displayName,
            originalPrice: originalPrice,
            promoPrice: promoPrice,
            savings: savingsAmount,
            discountPercentage: discountPercentage,
            mechanism: displayMechanism,
            validityStart: "",
            validityEnd: validityEnd,
            pageNumber: pageNumber,
            promoFolderUrl: nil,
            savingsAmount: savingsAmount,
            minPurchaseQty: minPurchaseQty,
            effectiveUnitPrice: nil,
            displayName: displayName,
            displayMechanism: displayMechanism,
            displayDescription: nil,
            displayUnitPrice: nil,
            displaySavingsLabel: nil,
            bucket: nil,
            bucketLabel: nil,
            thumbnailUrl: thumbnailUrl,
            imageUrl: imageUrl,
            storeName: storeName,
            promoTextMarkdown: promoTextMarkdown
        )
    }

    enum CodingKeys: String, CodingKey {
        case itemId = "item_id"
        case pageNumber = "page_number"
        case tileBboxXMin = "tile_bbox_x_min"
        case tileBboxYMin = "tile_bbox_y_min"
        case tileBboxXMax = "tile_bbox_x_max"
        case tileBboxYMax = "tile_bbox_y_max"
        case displayName = "display_name"
        case displayBrand = "display_brand"
        case displayMechanism = "display_mechanism"
        case originalPrice = "original_price"
        case promoPrice = "promo_price"
        case savingsAmount = "savings_amount"
        case discountPercentage = "discount_percentage"
        case minPurchaseQty = "min_purchase_qty"
        case validityEnd = "validity_end"
        case thumbnailUrl = "thumbnail_url"
        case imageUrl = "image_url"
        case storeName = "store_name"
        case promoTextMarkdown = "promo_text_markdown"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        itemId = try c.decode(String.self, forKey: .itemId)
        pageNumber = try c.decode(Int.self, forKey: .pageNumber)
        tileBboxXMin = try c.decode(CGFloat.self, forKey: .tileBboxXMin)
        tileBboxYMin = try c.decode(CGFloat.self, forKey: .tileBboxYMin)
        tileBboxXMax = try c.decode(CGFloat.self, forKey: .tileBboxXMax)
        tileBboxYMax = try c.decode(CGFloat.self, forKey: .tileBboxYMax)
        displayName = try c.decode(String.self, forKey: .displayName)
        displayBrand = try c.decodeIfPresent(String.self, forKey: .displayBrand)
        displayMechanism = try c.decode(String.self, forKey: .displayMechanism)
        originalPrice = try c.decodeIfPresent(Double.self, forKey: .originalPrice) ?? 0
        promoPrice = try c.decodeIfPresent(Double.self, forKey: .promoPrice) ?? 0
        savingsAmount = try c.decodeIfPresent(Double.self, forKey: .savingsAmount) ?? 0
        discountPercentage = try c.decodeIfPresent(Int.self, forKey: .discountPercentage) ?? 0
        minPurchaseQty = try c.decodeIfPresent(Int.self, forKey: .minPurchaseQty) ?? 1
        validityEnd = try c.decodeIfPresent(String.self, forKey: .validityEnd) ?? ""
        thumbnailUrl = try c.decodeIfPresent(String.self, forKey: .thumbnailUrl)
        imageUrl = try c.decodeIfPresent(String.self, forKey: .imageUrl)
        storeName = try c.decodeIfPresent(String.self, forKey: .storeName) ?? ""
        promoTextMarkdown = try c.decodeIfPresent(String.self, forKey: .promoTextMarkdown)
    }
}

// MARK: - Folder Page

struct PromoFolderPage: Codable, Identifiable {
    let pageNumber: Int
    let imageUrl: String
    let hotspots: [PromoFolderHotspot]

    var id: Int { pageNumber }

    init(pageNumber: Int, imageUrl: String, hotspots: [PromoFolderHotspot] = []) {
        self.pageNumber = pageNumber
        self.imageUrl = imageUrl
        self.hotspots = hotspots
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pageNumber = try container.decode(Int.self, forKey: .pageNumber)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        hotspots = try container.decodeIfPresent([PromoFolderHotspot].self, forKey: .hotspots) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case pageNumber = "page_number"
        case imageUrl = "image_url"
        case hotspots
    }
}

// MARK: - Folder

struct PromoFolder: Codable, Identifiable {
    let folderId: String
    let storeId: String
    let storeDisplayName: String
    let folderName: String
    let sourceUrl: String
    let validityStart: String
    let validityEnd: String
    let pageCount: Int
    let pages: [PromoFolderPage]

    var id: String { folderId }

    /// First page image URL, used as cover thumbnail
    var coverImageUrl: String? { pages.first?.imageUrl }

    /// Days remaining until validity_end
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

    /// Validity display matching the Deals tab style: text + color + optional icon
    var validityDisplay: (text: String, color: Color, icon: String?) {
        guard let days = daysRemaining else {
            return (validityFallback, .white.opacity(0.4), nil)
        }
        switch days {
        case _ where days < 0:
            return ("Expired", .white.opacity(0.25), nil)
        case 0:
            return ("Last day!", Color(red: 0.95, green: 0.25, blue: 0.25), "exclamationmark.circle.fill")
        case 1...2:
            return ("\(days) day\(days == 1 ? "" : "s") left", Color(red: 0.95, green: 0.40, blue: 0.30), "clock.badge.exclamationmark")
        case 3...5:
            return ("\(days) days left", Color(red: 1.0, green: 0.75, blue: 0.25), "clock")
        default:
            return ("\(days) days left", .white.opacity(0.4), nil)
        }
    }

    private var validityFallback: String {
        let parts = validityEnd.split(separator: "-")
        guard parts.count == 3 else { return validityEnd }
        return "Until \(parts[2])/\(parts[1])"
    }

    enum CodingKeys: String, CodingKey {
        case folderId = "folder_id"
        case storeId = "store_id"
        case storeDisplayName = "store_display_name"
        case folderName = "folder_name"
        case sourceUrl = "source_url"
        case validityStart = "validity_start"
        case validityEnd = "validity_end"
        case pageCount = "page_count"
        case pages
    }
}

// MARK: - Response

struct PromoFoldersResponse: Codable {
    let folders: [PromoFolder]
}
