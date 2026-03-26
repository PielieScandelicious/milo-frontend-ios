//
//  CharityAPIService.swift
//  Scandalicious
//

import Foundation
import FirebaseAuth

// MARK: - Models

struct CharityItem: Codable, Identifiable {
    let id: String
    let name: String
    let description: String
    let icon: String        // SF Symbol name
    let color: String       // color name
    let communityTotal: Double
    let userTotal: Double

    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, color
        case communityTotal = "community_total"
        case userTotal = "user_total"
    }
}

struct CharityListResponse: Codable {
    let charities: [CharityItem]
    let userBalance: Double

    enum CodingKeys: String, CodingKey {
        case charities
        case userBalance = "user_balance"
    }
}

struct CharityDonateRequest: Codable {
    let charityId: String
    let amount: Double

    enum CodingKeys: String, CodingKey {
        case charityId = "charity_id"
        case amount
    }
}

struct CharityDonateResponse: Codable {
    let id: String
    let charityId: String
    let charityName: String
    let amount: Double
    let status: String
    let fraudCheckPassed: Bool
    let newBalance: Double

    enum CodingKeys: String, CodingKey {
        case id, amount, status
        case charityId = "charity_id"
        case charityName = "charity_name"
        case fraudCheckPassed = "fraud_check_passed"
        case newBalance = "new_balance"
    }
}

struct CharityDonationItem: Codable, Identifiable {
    let id: String
    let charityId: String
    let charityName: String
    let amount: Double
    let status: String
    let createdAt: String
    let transferredAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, status
        case charityId = "charity_id"
        case charityName = "charity_name"
        case createdAt = "created_at"
        case transferredAt = "transferred_at"
    }

    var isPending: Bool { status == "pending" || status == "pending_review" }
    var isTransferred: Bool { status == "transferred" }
    var isRejected: Bool { status == "rejected" }

    var statusLabel: String {
        switch status {
        case "transferred":    return "Transferred ✓"
        case "pending":        return "Pending transfer"
        case "pending_review": return "Under review"
        case "rejected":       return "Rejected"
        default:               return status
        }
    }

    var statusColorName: String {
        switch status {
        case "transferred":    return "green"
        case "pending":        return "yellow"
        case "pending_review": return "orange"
        case "rejected":       return "red"
        default:               return "gray"
        }
    }
}

struct CharityHistoryResponse: Codable {
    let donations: [CharityDonationItem]
    let totalDonated: Double

    enum CodingKeys: String, CodingKey {
        case donations
        case totalDonated = "total_donated"
    }
}

// MARK: - Charity API Service

actor CharityAPIService {
    static let shared = CharityAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Endpoints

    func fetchCharities() async throws -> CharityListResponse {
        return try await performRequest(endpoint: "/charity/list")
    }

    func submitDonation(charityId: String, amount: Double) async throws -> CharityDonateResponse {
        let body = CharityDonateRequest(charityId: charityId, amount: amount)
        return try await performPostRequest(endpoint: "/charity/donate", body: body)
    }

    func fetchHistory() async throws -> CharityHistoryResponse {
        return try await performRequest(endpoint: "/charity/history")
    }

    // MARK: - Nonisolated Wrappers

    nonisolated func getCharities() async throws -> CharityListResponse {
        return try await fetchCharities()
    }

    nonisolated func donate(charityId: String, amount: Double) async throws -> CharityDonateResponse {
        return try await submitDonation(charityId: charityId, amount: amount)
    }

    nonisolated func getHistory() async throws -> CharityHistoryResponse {
        return try await fetchHistory()
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
        guard let http = response as? HTTPURLResponse else { throw CashbackAPIError.invalidResponse }
        switch http.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw CashbackAPIError.unauthorized
        case 400...499:
            let msg = parseErrorMessage(from: data) ?? "Error \(http.statusCode)"
            throw CashbackAPIError.serverError(msg)
        default:
            throw CashbackAPIError.serverError("Server error: \(http.statusCode)")
        }
    }

    private func performPostRequest<T: Decodable, B: Encodable>(
        endpoint: String, body: B
    ) async throws -> T {
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
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw CashbackAPIError.invalidResponse }
        switch http.statusCode {
        case 200...299:
            return try decoder.decode(T.self, from: data)
        case 401:
            throw CashbackAPIError.unauthorized
        case 400...499:
            let msg = parseErrorMessage(from: data) ?? "Error \(http.statusCode)"
            throw CashbackAPIError.serverError(msg)
        default:
            throw CashbackAPIError.serverError("Server error: \(http.statusCode)")
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else { throw CashbackAPIError.noAuthToken }
        return try await user.getIDToken()
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict["detail"] ?? dict["error"] ?? dict["message"]
        }
        return nil
    }
}
