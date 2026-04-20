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
}

// MARK: - API Response Models

private struct BrandCashbackDealAPIResponse: Codable {
    let id: String
    let brandName: String
    let productName: String
    let description: String
    let cashbackAmount: Double
    let imageSystemName: String
    let validFrom: Date
    let validUntil: Date
    let eligibleStores: [String]
    let requiresStore: Bool
    let userStatus: String
    let earnedAt: Date?

    // New fields (all optional for backward compat with older backend)
    let eligibleSKUs: [String]?
    let totalRedemptionCap: Int?
    let currentRedemptions: Int?
    let maxRedemptionsPerUser: Int?
    let claimedAt: Date?
    let claimExpiresAt: Date?
    let howItWorks: [String]?
    let terms: String?
    let matchedReceiptId: String?

    enum CodingKeys: String, CodingKey {
        case id
        case brandName = "brand_name"
        case productName = "product_name"
        case description
        case cashbackAmount = "cashback_amount"
        case imageSystemName = "image_system_name"
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
        case claimedAt = "claimed_at"
        case claimExpiresAt = "claim_expires_at"
        case howItWorks = "how_it_works"
        case terms
        case matchedReceiptId = "matched_receipt_id"
    }
}

// MARK: - Earned Brand Cashback Entry (for Recent Rewards display)

struct EarnedBrandCashbackEntry {
    let id: String
    let productName: String
    let brandName: String
    let cashbackAmount: Double
    let imageSystemName: String
    let earnedAt: Date
}

private struct ClaimAPIResponse: Codable {
    let campaignId: String
    let status: String
    let claimedAt: Date

    enum CodingKeys: String, CodingKey {
        case campaignId = "campaign_id"
        case status
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
            .filter { $0.status == .claimed || $0.status == .pending }
            .map { ClaimedDeal(id: $0.id, claimedAt: Date(), status: $0.status) }
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

    /// Reloads deals from server. Any deal that transitioned from claimed → earned
    /// triggers the earned overlay and notification.
    func refreshAndDetectEarnings(receiptId: String) async {
        let previousClaimedIds = Set(allDeals.filter { $0.status == .claimed }.map { $0.id })
        await loadDeals()
        let nowEarned = allDeals.filter { deal in
            // Backend excludes earned deals; so if a previously claimed deal is gone, check via claimedDeals
            false
        }
        _ = nowEarned  // suppress warning; earnings detected via my-claims diff below

        // Re-fetch my-claims to detect newly earned ones
        guard let token = try? await getAuthToken() else { return }
        var req = URLRequest(url: URL(string: "\(baseURL)/brand-cashback/my-claims")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let myClaims = try? decoder.decode([BrandCashbackDealAPIResponse].self, from: data) else { return }

        // Any claim from the previous set that is now .earned
        for claim in myClaims where claim.userStatus == "earned" && previousClaimedIds.contains(claim.id) {
            let deal = mapAPIDeal(claim)
            lastEarnedDeal = (deal: deal, earned: deal.cashbackAmount)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            NotificationCenter.default.post(name: .brandCashbackEarned, object: nil, userInfo: [
                "dealId": deal.id,
                "cashbackAmount": deal.cashbackAmount,
            ])
            break  // surface one at a time
        }
    }

    func clearEarnedDeal() {
        lastEarnedDeal = nil
    }

    /// Fetches earned brand cashback claims for display in Recent Rewards.
    func fetchEarnedDeals() async -> [EarnedBrandCashbackEntry] {
        guard let token = try? await getAuthToken() else { return [] }
        var req = URLRequest(url: URL(string: "\(baseURL)/brand-cashback/my-claims")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let claims = try? decoder.decode([BrandCashbackDealAPIResponse].self, from: data) else { return [] }

        return claims
            .filter { $0.userStatus == "earned" }
            .map {
                EarnedBrandCashbackEntry(
                    id: $0.id,
                    productName: $0.productName,
                    brandName: $0.brandName,
                    cashbackAmount: $0.cashbackAmount,
                    imageSystemName: $0.imageSystemName,
                    earnedAt: $0.earnedAt ?? Date()
                )
            }
    }

    // MARK: - Private Helpers

    private func mapAPIDeal(_ api: BrandCashbackDealAPIResponse) -> BrandCashbackDeal {
        let status: DealStatus
        switch api.userStatus {
        case "claimed":  status = .claimed
        case "pending":  status = .pending
        case "earned":   status = .earned
        case "expired":  status = .expired
        default:         status = .available
        }
        return BrandCashbackDeal(
            id: api.id,
            brandName: api.brandName,
            productName: api.productName,
            description: api.description,
            cashbackAmount: api.cashbackAmount,
            imageSystemName: api.imageSystemName,
            validUntil: api.validUntil,
            eligibleStores: api.eligibleStores,
            requiresStore: api.requiresStore,
            status: status,
            eligibleSKUs: api.eligibleSKUs,
            totalRedemptionCap: api.totalRedemptionCap,
            currentRedemptions: api.currentRedemptions,
            maxRedemptionsPerUser: api.maxRedemptionsPerUser,
            claimedAt: api.claimedAt,
            claimExpiresAt: api.claimExpiresAt,
            howItWorks: api.howItWorks,
            terms: api.terms,
            matchedReceiptId: api.matchedReceiptId,
            earnedAt: api.earnedAt
        )
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw URLError(.userAuthenticationRequired)
        }
        return try await user.getIDToken()
    }
}
