//
//  BrandCashbackService.swift
//  Scandalicious
//
//  Real API-backed service for the brand cashback system.
//  Calls /api/v2/brand-cashback/* endpoints.
//

import Foundation
import Combine
import SwiftUI
import FirebaseAuth

// MARK: - Notification

extension Notification.Name {
    static let brandCashbackEarned = Notification.Name("brandCashback.earned")
    static let brandCashbackDenied = Notification.Name("brandCashback.denied")
}

// MARK: - API Response Models

private struct BrandCashbackDealAPIResponse: Codable {
    let id: String
    let brandName: String
    let productName: String
    let description: String
    let cashbackAmount: Double
    let imageUrl: URL?
    let imageThumbUrl: URL?
    let brandLogoUrl: URL?
    let validFrom: Date
    let validUntil: Date
    let eligibleStores: [String]
    let requiresStore: Bool
    let userStatus: String
    let earnedAt: Date?

    let eligibleSKUs: [String]?
    let totalRedemptionCap: Int?
    let currentRedemptions: Int?
    let maxRedemptionsPerUser: Int?
    let earningsCount: Int?
    let claimedAt: Date?
    let howItWorks: [String]?
    let terms: String?
    let matchedReceiptId: String?
    let category: String?
    let featured: Bool?
    let pendingReview: PendingReviewAPI?
    let recentDenial: RecentDenialAPI?

    enum CodingKeys: String, CodingKey {
        case id
        case brandName = "brand_name"
        case productName = "product_name"
        case description
        case cashbackAmount = "cashback_amount"
        case imageUrl = "image_url"
        case imageThumbUrl = "image_thumb_url"
        case brandLogoUrl = "brand_logo_url"
        case validFrom = "valid_from"
        case validUntil = "valid_until"
        case eligibleStores = "eligible_stores"
        case requiresStore = "requires_store"
        case userStatus = "user_status"
        case earnedAt = "earned_at"
        case eligibleSKUs = "eligible_skus"
        case totalRedemptionCap = "total_redemption_cap"
        case currentRedemptions = "current_redemptions"
        case maxRedemptionsPerUser = "max_redemptions_per_user"
        case earningsCount = "earnings_count"
        case claimedAt = "claimed_at"
        case howItWorks = "how_it_works"
        case terms
        case matchedReceiptId = "matched_receipt_id"
        case category
        case featured
        case pendingReview = "pending_review"
        case recentDenial = "recent_denial"
    }
}

private struct PendingReviewAPI: Codable {
    let id: String
    let receiptId: String
    let candidateString: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case receiptId = "receipt_id"
        case candidateString = "candidate_string"
        case createdAt = "created_at"
    }
}

private struct RecentDenialAPI: Codable {
    let id: String
    let receiptId: String
    let deniedAt: Date
    let reason: String

    enum CodingKeys: String, CodingKey {
        case id
        case receiptId = "receipt_id"
        case deniedAt = "denied_at"
        case reason
    }
}

private struct ClaimAPIResponse: Codable {
    let campaignId: String
    let claimedAt: Date

    enum CodingKeys: String, CodingKey {
        case campaignId = "campaign_id"
        case claimedAt = "claimed_at"
    }
}

// MARK: - Service

@MainActor
class BrandCashbackService: ObservableObject {
    static let shared = BrandCashbackService()

    // MARK: - Published State

    @Published private(set) var allDeals: [BrandCashbackDeal] = []
    @Published private(set) var claimedDeals: [ClaimedDeal] = []
    @Published private(set) var lastEarnedDeal: (deal: BrandCashbackDeal, earned: Double)? = nil

    // MARK: - Private

    private let baseURL: String = AppConfiguration.apiBase

    private var decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Init

    private init() {}

    // MARK: - Load Deals

    func loadDeals() async {
        guard let token = try? await getAuthToken() else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/brand-cashback/deals")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return }

        guard let apiDeals = try? decoder.decode([BrandCashbackDealAPIResponse].self, from: data) else { return }

        allDeals = apiDeals.map { mapAPIDeal($0) }
        claimedDeals = allDeals
            .filter { $0.status == .claimed }
            .map { ClaimedDeal(id: $0.id, claimedAt: $0.claimedAt ?? Date(), status: $0.status) }
    }

    // MARK: - Claim / Unclaim

    func claimDeal(id: String) async {
        guard let token = try? await getAuthToken() else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/brand-cashback/claim/\(id)")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 || http.statusCode == 201 else { return }

        if let index = allDeals.firstIndex(where: { $0.id == id }) {
            allDeals[index].status = .claimed
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func unclaimDeal(id: String) async {
        guard let token = try? await getAuthToken() else { return }

        var request = URLRequest(url: URL(string: "\(baseURL)/brand-cashback/claim/\(id)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 204 else { return }

        if let index = allDeals.firstIndex(where: { $0.id == id }) {
            allDeals[index].status = .available
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Refresh and Detect Earnings

    /// Reloads deals from server. Detects three transitions and fires the
    /// matching notification (the iOS layer cares about all three because they
    /// represent distinct user-visible outcomes after a receipt upload):
    ///   • previously claimed (or pending) → earned  →  .brandCashbackEarned
    ///   • previously claimed → pending review        →  no notification (UI
    ///     just renders the new state next time the tab opens)
    ///   • previously pending → denied (recentDenial) →  .brandCashbackDenied
    func refreshAndDetectEarnings(receiptId: String) async {
        let previousClaimedIds = Set(allDeals.filter { $0.status == .claimed }.map { $0.id })
        let previousPendingIds = Set(allDeals.filter { $0.status == .pendingReview }.map { $0.id })

        await loadDeals()

        // Re-fetch my-claims to detect newly earned and newly denied ones.
        guard let token = try? await getAuthToken() else { return }
        var req = URLRequest(url: URL(string: "\(baseURL)/brand-cashback/my-claims")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let myClaims = try? decoder.decode([BrandCashbackDealAPIResponse].self, from: data) else { return }

        // Earned: claim/pending row from before is now earned.
        for claim in myClaims where claim.userStatus == "earned"
            && (previousClaimedIds.contains(claim.id) || previousPendingIds.contains(claim.id)) {
            let deal = mapAPIDeal(claim)
            lastEarnedDeal = (deal: deal, earned: deal.cashbackAmount)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            NotificationCenter.default.post(name: .brandCashbackEarned, object: nil, userInfo: [
                "dealId": deal.id,
                "cashbackAmount": deal.cashbackAmount,
            ])
            break  // surface one at a time
        }

        // Denied: previously pending row now carries a recent_denial.
        for claim in myClaims where previousPendingIds.contains(claim.id) {
            guard let denial = claim.recentDenial else { continue }
            NotificationCenter.default.post(name: .brandCashbackDenied, object: nil, userInfo: [
                "dealId": claim.id,
                "brandName": claim.brandName,
                "productName": claim.productName,
                "reason": denial.reason,
            ])
            break
        }
    }

    func clearEarnedDeal() {
        lastEarnedDeal = nil
    }

    // MARK: - Private Helpers

    private func mapAPIDeal(_ api: BrandCashbackDealAPIResponse) -> BrandCashbackDeal {
        // Resolve display status: pending_review takes precedence over the
        // server's data-model status ("claimed"), since for the UI a pending
        // review is the most actionable state.
        let status: DealStatus
        if api.pendingReview != nil {
            status = .pendingReview
        } else {
            switch api.userStatus {
            case "claimed":  status = .claimed
            case "earned":   status = .earned
            default:         status = .available
            }
        }
        let pending = api.pendingReview.map {
            PendingReviewInfo(
                id: $0.id,
                receiptId: $0.receiptId,
                candidateString: $0.candidateString,
                createdAt: $0.createdAt
            )
        }
        let denial = api.recentDenial.map {
            RecentDenialInfo(
                id: $0.id,
                receiptId: $0.receiptId,
                deniedAt: $0.deniedAt,
                reason: $0.reason
            )
        }
        return BrandCashbackDeal(
            id: api.id,
            brandName: api.brandName,
            productName: api.productName,
            description: api.description,
            cashbackAmount: api.cashbackAmount,
            imageUrl: api.imageUrl,
            imageThumbUrl: api.imageThumbUrl,
            brandLogoUrl: api.brandLogoUrl,
            validUntil: api.validUntil,
            eligibleStores: api.eligibleStores,
            requiresStore: api.requiresStore,
            status: status,
            category: api.category,
            featured: api.featured ?? false,
            eligibleSKUs: api.eligibleSKUs,
            totalRedemptionCap: api.totalRedemptionCap,
            currentRedemptions: api.currentRedemptions,
            maxRedemptionsPerUser: api.maxRedemptionsPerUser,
            earningsCount: api.earningsCount ?? 0,
            claimedAt: api.claimedAt,
            howItWorks: api.howItWorks,
            terms: api.terms,
            matchedReceiptId: api.matchedReceiptId,
            earnedAt: api.earnedAt,
            pendingReview: pending,
            recentDenial: denial
        )
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await user.getIDToken()
    }
}
