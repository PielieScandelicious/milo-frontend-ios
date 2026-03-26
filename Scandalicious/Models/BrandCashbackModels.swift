//
//  BrandCashbackModels.swift
//  Scandalicious
//
//  Data models for the brand cashback system.
//  FMCG brands sponsor deals; users claim them before uploading receipts.
//

import Foundation

// MARK: - Deal Status

enum DealStatus: String, Codable, CaseIterable {
    case available  // Not yet claimed by this user
    case claimed    // User tapped "Claim" — waiting for a matching receipt
    case pending    // Receipt uploaded, backend matching in progress
    case earned     // Cashback credited to wallet
    case expired    // Past validUntil date
}

// MARK: - Segment

enum DealsSegment: String, CaseIterable {
    case weekly = "Weekly Deals"
    case cashback = "Cashback"
}

// MARK: - Brand Cashback Deal

struct BrandCashbackDeal: Identifiable, Codable {
    let id: String
    let brandName: String         // e.g. "Coca-Cola"
    let productName: String       // e.g. "Coca-Cola Regular 1.5L"
    let description: String       // Short marketing copy
    let cashbackAmount: Double    // e.g. 0.50
    let imageSystemName: String   // SF Symbol name
    let validUntil: Date
    let eligibleStores: [String]  // GroceryStore rawValues; empty = all stores
    let requiresStore: Bool       // false when available everywhere
    var status: DealStatus

    var isExpired: Bool { Date() > validUntil }

    var formattedCashback: String { String(format: "€%.2f", cashbackAmount) }

    var formattedExpiry: String {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        f.locale = Locale(identifier: "nl_BE")
        return "Until \(f.string(from: validUntil))"
    }

    var storeDisplayList: String {
        requiresStore ? eligibleStores.joined(separator: ", ") : "All stores"
    }
}

// MARK: - Claimed Deal (persisted locally)

struct ClaimedDeal: Codable, Identifiable {
    let id: String          // == BrandCashbackDeal.id
    let claimedAt: Date
    var status: DealStatus
    var earnedAt: Date?
    var cashbackEarned: Double?
    var receiptId: String?
    var matchedStore: String?
}
