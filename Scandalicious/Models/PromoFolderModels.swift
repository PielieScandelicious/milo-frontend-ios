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
    /// Full-tile crop for the product-detail view (nil on older payloads).
    let heroUrl: String?
    let storeName: String
    let promoTextMarkdown: String?
    // Coupon fields. When isCoupon == true, couponBarcodeValue + couponBarcodeFormat
    // are almost always non-nil (a failed decode is logged and flagged by backend QA,
    // but can still slip through as a coupon with no barcode — UI must guard).
    let isCoupon: Bool
    let couponType: String?
    let couponBarcodeValue: String?
    let couponBarcodeFormat: String?
    let couponValue: Double?
    let couponMinPurchase: String?
    let couponValidityEnd: String?
    let barcodeBboxXMin: CGFloat?
    let barcodeBboxYMin: CGFloat?
    let barcodeBboxXMax: CGFloat?
    let barcodeBboxYMax: CGFloat?

    var id: String { itemId }

    /// Barcode region in the page's normalized 0-1 coord space, if available.
    /// Drawn as a secondary outline inside the tile hotspot for coupons so the
    /// user can spot the scannable part at a glance.
    func barcodeRect(in imageRect: CGRect) -> CGRect? {
        guard let x1 = barcodeBboxXMin, let y1 = barcodeBboxYMin,
              let x2 = barcodeBboxXMax, let y2 = barcodeBboxYMax else { return nil }
        return CGRect(
            x: imageRect.origin.x + x1 * imageRect.width,
            y: imageRect.origin.y + y1 * imageRect.height,
            width: (x2 - x1) * imageRect.width,
            height: (y2 - y1) * imageRect.height
        )
    }

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
        case heroUrl = "hero_url"
        case storeName = "store_name"
        case promoTextMarkdown = "promo_text_markdown"
        case isCoupon = "is_coupon"
        case couponType = "coupon_type"
        case couponBarcodeValue = "coupon_barcode_value"
        case couponBarcodeFormat = "coupon_barcode_format"
        case couponValue = "coupon_value"
        case couponMinPurchase = "coupon_min_purchase"
        case couponValidityEnd = "coupon_validity_end"
        case barcodeBboxXMin = "barcode_bbox_x_min"
        case barcodeBboxYMin = "barcode_bbox_y_min"
        case barcodeBboxXMax = "barcode_bbox_x_max"
        case barcodeBboxYMax = "barcode_bbox_y_max"
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
        heroUrl = try c.decodeIfPresent(String.self, forKey: .heroUrl)
        storeName = try c.decodeIfPresent(String.self, forKey: .storeName) ?? ""
        promoTextMarkdown = try c.decodeIfPresent(String.self, forKey: .promoTextMarkdown)
        isCoupon = try c.decodeIfPresent(Bool.self, forKey: .isCoupon) ?? false
        couponType = try c.decodeIfPresent(String.self, forKey: .couponType)
        couponBarcodeValue = try c.decodeIfPresent(String.self, forKey: .couponBarcodeValue)
        couponBarcodeFormat = try c.decodeIfPresent(String.self, forKey: .couponBarcodeFormat)
        couponValue = try c.decodeIfPresent(Double.self, forKey: .couponValue)
        couponMinPurchase = try c.decodeIfPresent(String.self, forKey: .couponMinPurchase)
        couponValidityEnd = try c.decodeIfPresent(String.self, forKey: .couponValidityEnd)
        barcodeBboxXMin = try c.decodeIfPresent(CGFloat.self, forKey: .barcodeBboxXMin)
        barcodeBboxYMin = try c.decodeIfPresent(CGFloat.self, forKey: .barcodeBboxYMin)
        barcodeBboxXMax = try c.decodeIfPresent(CGFloat.self, forKey: .barcodeBboxXMax)
        barcodeBboxYMax = try c.decodeIfPresent(CGFloat.self, forKey: .barcodeBboxYMax)
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
