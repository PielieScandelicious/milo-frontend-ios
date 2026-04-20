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
    case expired    // Past validUntil date OR claim window elapsed
}

// MARK: - Segment

enum DealsSegment: String, CaseIterable {
    case weekly = "Weekly Deals"
    case cashback = "Cashback"
}

// MARK: - Brand Cashback Deal

struct BrandCashbackDeal: Identifiable, Codable {
    let id: String
    let brandName: String         // e.g. "Alpro"
    let productName: String       // e.g. "Alpro Soya Original 1L"
    let description: String       // Short marketing copy
    let cashbackAmount: Double    // e.g. 1.00
    let imageSystemName: String   // SF Symbol name
    let validUntil: Date          // Campaign end
    let eligibleStores: [String]  // GroceryStore rawValues; empty = all stores
    let requiresStore: Bool       // false when available everywhere
    var status: DealStatus

    // MARK: User-facing product variants

    /// Human-readable product variants shown to the user
    /// (e.g. "Alpro Soya Original 1L", "Alpro Soya Original 500ml").
    /// Actual receipt matching happens server-side via line-items.
    let eligibleSKUs: [String]?

    // MARK: Campaign economics

    /// Campaign-wide redemption cap set by the brand. nil = uncapped.
    let totalRedemptionCap: Int?

    /// How many have been redeemed so far across all users.
    let currentRedemptions: Int?

    /// Max redemptions per user per campaign. Defaults to 1 if omitted.
    let maxRedemptionsPerUser: Int?

    // MARK: Claim window

    /// When the current user claimed this deal (nil if not claimed).
    let claimedAt: Date?

    /// When the user's claim expires — they must buy+scan before this.
    /// Typically `claimedAt + 14 days` but brand-configurable.
    let claimExpiresAt: Date?

    // MARK: Terms + explainer

    /// Ordered "how it works" steps shown in the detail sheet.
    let howItWorks: [String]?

    /// Legal terms / conditions, plain text.
    let terms: String?

    // MARK: Earning traceability

    /// Set once the user has earned: the receipt ID that matched this claim.
    let matchedReceiptId: String?

    /// When the cashback was credited (status == .earned).
    let earnedAt: Date?

    // MARK: - Computed properties

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

    // MARK: Claim countdown

    /// Days remaining on the user's claim window. nil if not claimed.
    /// Returns 0 if already expired.
    var daysUntilClaimExpires: Int? {
        guard let expires = claimExpiresAt else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expires).day ?? 0
        return max(0, days)
    }

    /// True if the claim window has elapsed (user claimed but didn't shop in time).
    var isClaimExpired: Bool {
        guard let expires = claimExpiresAt else { return false }
        return Date() > expires
    }

    /// Short label for the card: "8 days left" / "2 days left" / "Today" / nil.
    var claimCountdownLabel: String? {
        guard let days = daysUntilClaimExpires else { return nil }
        if days == 0 { return "Last day" }
        if days == 1 { return "1 day left" }
        return "\(days) days left"
    }

    // MARK: Cap progress

    /// 0.0–1.0 fullness of the campaign. nil if uncapped.
    var capFillRatio: Double? {
        guard let cap = totalRedemptionCap, cap > 0,
              let current = currentRedemptions else { return nil }
        return min(1.0, Double(current) / Double(cap))
    }

    /// Short label: "247 / 2000 claimed" — nil if uncapped.
    var capProgressLabel: String? {
        guard let cap = totalRedemptionCap,
              let current = currentRedemptions else { return nil }
        return "\(current) / \(cap) claimed"
    }

    /// True when >85% of the cap is filled — triggers urgency UI.
    var isNearlyFull: Bool {
        (capFillRatio ?? 0) >= 0.85
    }
}

// MARK: - Claimed Deal (persisted locally, legacy lightweight mirror)

struct ClaimedDeal: Codable, Identifiable {
    let id: String          // == BrandCashbackDeal.id
    let claimedAt: Date
    var status: DealStatus
    var earnedAt: Date?
    var cashbackEarned: Double?
    var receiptId: String?
    var matchedStore: String?
}
