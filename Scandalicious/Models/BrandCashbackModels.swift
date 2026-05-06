//
//  BrandCashbackModels.swift
//  Scandalicious
//
//  Data models for the brand cashback system.
//  Users claim a deal once; every uploaded receipt is matched against the
//  claim until the campaign expires or the per-user redemption cap is hit.
//

import Foundation

// MARK: - Deal Status

enum DealStatus: String, Codable, CaseIterable {
    case available     // No claim from this user yet
    case claimed       // Claim exists; user can still earn (earnings < max)
    case pendingReview // A receipt for this campaign is queued for admin review
    case earned        // User has reached max_redemptions_per_user
}

// MARK: - Pending review / denial side-cars

/// Set on a BrandCashbackDeal when the user has an open admin review for it.
/// Drives the "Reviewing receipt" UI on the grid card and detail sheet.
struct PendingReviewInfo: Codable {
    let id: String
    let receiptId: String
    let candidateString: String
    let createdAt: Date
}

/// Set on a BrandCashbackDeal when the user has a denial in the last 7 days
/// for this campaign and no later approval. Drives the "not eligible" banner.
struct RecentDenialInfo: Codable {
    let id: String
    let receiptId: String
    let deniedAt: Date
    let reason: String
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
    let imageUrl: URL?            // Hero (original aspect, ≤1200px) — used in detail sheet
    let imageThumbUrl: URL?       // Thumbnail (400x400 square crop) — used in grid card
    let brandLogoUrl: URL?        // Brand mark (≤512px) — used in card disc
    let validUntil: Date          // Campaign end
    let eligibleStores: [String]  // GroceryStore rawValues; empty = all stores
    let requiresStore: Bool       // false when available everywhere
    var status: DealStatus

    // MARK: Curation

    /// Backend-provided category tag for filtering (food, drinks, household, ...).
    let category: String?

    /// Promote this campaign to the featured rail / hero spot.
    let featured: Bool

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

    /// How many times the current user has earned this cashback so far.
    let earningsCount: Int

    // MARK: Claim metadata (informational)

    /// When the current user claimed this deal (nil if not claimed).
    let claimedAt: Date?

    // MARK: Terms + explainer

    /// Ordered "how it works" steps shown in the detail sheet.
    let howItWorks: [String]?

    /// Legal terms / conditions, plain text.
    let terms: String?

    // MARK: Earning traceability

    /// The receipt that produced the most recent earning, if any.
    let matchedReceiptId: String?

    /// When the most recent earning happened (status == .earned or partial).
    let earnedAt: Date?

    // MARK: Manual-review queue

    /// Open admin review for this user+campaign. When non-nil the iOS layer
    /// resolves `status` to `.pendingReview` regardless of the server's
    /// underlying user_status string (which still describes the data model:
    /// claim row exists, just hasn't earned yet).
    let pendingReview: PendingReviewInfo?

    /// Latest denial (within 7 days) — drives the "Last receipt: not eligible"
    /// banner under the validity section of the detail sheet.
    let recentDenial: RecentDenialInfo?

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

    // MARK: Per-user redemption progress

    /// True when the campaign allows multiple redemptions per user.
    var supportsMultipleRedemptions: Bool {
        (maxRedemptionsPerUser ?? 1) > 1
    }

    /// Short label shown when max > 1 — e.g. "1 of 3 earned". nil for single-use deals.
    var redemptionProgressLabel: String? {
        guard supportsMultipleRedemptions, let max = maxRedemptionsPerUser else { return nil }
        return "\(earningsCount) of \(max) earned"
    }

    /// True for multi-redemption campaigns where the user has earned at least
    /// one but not all of their allowance. UI-only derived state — backend
    /// `user_status` is still "claimed" in this case (the persistent intent
    /// row exists and they can earn more).
    var isPartiallyEarned: Bool {
        let max = maxRedemptionsPerUser ?? 1
        return earningsCount > 0 && max > 1 && earningsCount < max
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

    // MARK: Banner copy for review states

    /// Short user-facing line for the pending/denial banners. Returns nil when
    /// neither a pending review nor a recent denial is attached to the deal.
    ///
    /// Deprecated: use `bannerKind` and let `DealStatusBanner` render the surface.
    var reviewBannerLabel: String? {
        if pendingReview != nil {
            return "Receipt under review — usually within 24h"
        }
        if let denial = recentDenial {
            return "Last receipt: not eligible — \(denial.reason)"
        }
        return nil
    }

    /// Priority-resolved kind consumed by `DealStatusBanner`.
    /// earned > denied > pending > nil. A `recentDenial` is suppressed
    /// while a fresh `pendingReview` is in flight (newer signal wins).
    var bannerKind: DealStatusKind? {
        if status == .earned || isPartiallyEarned {
            return .earned(amountFormatted: formattedCashback)
        }
        if pendingReview != nil {
            return .pending
        }
        if let denial = recentDenial {
            return .denied(reason: denial.reason)
        }
        return nil
    }
}

// MARK: - Claimed Deal (persisted locally, lightweight mirror)

struct ClaimedDeal: Codable, Identifiable {
    let id: String          // == BrandCashbackDeal.id
    let claimedAt: Date
    var status: DealStatus
    var earnedAt: Date?
    var cashbackEarned: Double?
    var receiptId: String?
    var matchedStore: String?
}
