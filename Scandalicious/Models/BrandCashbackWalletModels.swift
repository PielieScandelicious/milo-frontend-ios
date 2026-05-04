//
//  BrandCashbackWalletModels.swift
//  Scandalicious
//
//  Wire models for GET /api/v2/brand-cashback/wallet. Mirrors
//  BrandCashbackWalletResponse on the backend (denominated in EUR cents).
//

import Foundation

struct BrandCashbackWallet: Codable, Equatable {
    let balanceCents: Int
    let totalEarnedCents: Int
    let totalWithdrawnCents: Int
    let recentEarnings: [BrandCashbackEarningEvent]

    static let empty = BrandCashbackWallet(
        balanceCents: 0,
        totalEarnedCents: 0,
        totalWithdrawnCents: 0,
        recentEarnings: []
    )

    enum CodingKeys: String, CodingKey {
        case balanceCents = "balance_cents"
        case totalEarnedCents = "total_earned_cents"
        case totalWithdrawnCents = "total_withdrawn_cents"
        case recentEarnings = "recent_earnings"
    }
}

struct BrandCashbackEarningEvent: Codable, Equatable, Identifiable {
    let id: String
    let campaignId: String
    let brandName: String
    let productName: String
    let imageThumbUrl: URL?
    let cashbackEarnedCents: Int
    let earnedAt: Date
    let receiptId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case campaignId = "campaign_id"
        case brandName = "brand_name"
        case productName = "product_name"
        case imageThumbUrl = "image_thumb_url"
        case cashbackEarnedCents = "cashback_earned_cents"
        case earnedAt = "earned_at"
        case receiptId = "receipt_id"
    }
}
