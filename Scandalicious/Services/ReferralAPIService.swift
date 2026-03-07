//
//  ReferralAPIService.swift
//  Scandalicious
//
//  API service for the dual-sided referral program.
//

import Foundation
import FirebaseAuth

// MARK: - Response Models

struct ReferralInfoResponse: Codable {
    let referralCode: String
    let totalReferrals: Int
    let completedReferrals: Int
    let pendingReferrals: Int
    let totalEarned: Double
    let hasUnclaimedReward: Bool
    let unclaimedRewardEuros: Double
    let unclaimedRewardSpins: Int
    let unclaimedReferralId: String?
    let unclaimedReferralRole: String?

    enum CodingKeys: String, CodingKey {
        case referralCode = "referral_code"
        case totalReferrals = "total_referrals"
        case completedReferrals = "completed_referrals"
        case pendingReferrals = "pending_referrals"
        case totalEarned = "total_earned"
        case hasUnclaimedReward = "has_unclaimed_reward"
        case unclaimedRewardEuros = "unclaimed_reward_euros"
        case unclaimedRewardSpins = "unclaimed_reward_spins"
        case unclaimedReferralId = "unclaimed_referral_id"
        case unclaimedReferralRole = "unclaimed_referral_role"
    }
}

struct ClaimReferralRewardResponse: Codable {
    let success: Bool
    let message: String
    let eurosCredited: Double
    let spinsCredited: Int
    let newBalance: Double

    enum CodingKeys: String, CodingKey {
        case success, message
        case eurosCredited = "euros_credited"
        case spinsCredited = "spins_credited"
        case newBalance = "new_balance"
    }
}

struct ApplyReferralCodeResponse: Codable {
    let success: Bool
    let message: String
    let referrerName: String?

    enum CodingKeys: String, CodingKey {
        case success, message
        case referrerName = "referrer_name"
    }
}

// MARK: - Referral API Service

actor ReferralAPIService {
    static let shared = ReferralAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Endpoints

    func fetchReferralInfo() async throws -> ReferralInfoResponse {
        return try await performRequest(endpoint: "/referral/info")
    }

    func applyReferralCode(_ code: String) async throws -> ApplyReferralCodeResponse {
        let body = ["referral_code": code]
        let jsonData = try JSONEncoder().encode(body)
        return try await performPostRequest(endpoint: "/referral/apply", bodyData: jsonData)
    }

    func claimReferralReward() async throws -> ClaimReferralRewardResponse {
        return try await performPostRequest(endpoint: "/referral/claim", bodyData: Data())
    }

    // MARK: - Nonisolated Wrappers

    nonisolated func getReferralInfo() async throws -> ReferralInfoResponse {
        return try await fetchReferralInfo()
    }

    nonisolated func applyCode(_ code: String) async throws -> ApplyReferralCodeResponse {
        return try await applyReferralCode(code)
    }

    nonisolated func claimReward() async throws -> ClaimReferralRewardResponse {
        return try await claimReferralReward()
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(endpoint: String) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CashbackAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CashbackAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw CashbackAPIError.unauthorized
        case 400...499:
            let msg = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
            throw CashbackAPIError.serverError(msg)
        default:
            throw CashbackAPIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }

    private func performPostRequest<T: Decodable>(endpoint: String, bodyData: Data) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CashbackAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CashbackAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw CashbackAPIError.unauthorized
        case 400...499:
            let msg = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
            throw CashbackAPIError.serverError(msg)
        default:
            throw CashbackAPIError.serverError("Server error: \(httpResponse.statusCode)")
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw CashbackAPIError.noAuthToken
        }
        return try await user.getIDToken()
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict["error"] ?? dict["message"] ?? dict["detail"]
        }
        return nil
    }
}
