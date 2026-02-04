//
//  ExpenseSplitAPIService.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 02/02/2026.
//

import Foundation
import FirebaseAuth

// MARK: - Expense Split API Service

actor ExpenseSplitAPIService {
    static let shared = ExpenseSplitAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - API Methods

    /// Save or update an expense split
    func saveSplit(_ request: ExpenseSplitCreateRequest) async throws -> ExpenseSplit {
        return try await performRequest(
            endpoint: "/expense-splits",
            method: "POST",
            body: request
        )
    }

    /// Get split by ID
    func getSplit(splitId: String) async throws -> ExpenseSplit {
        return try await performRequest(
            endpoint: "/expense-splits/\(splitId)",
            method: "GET"
        )
    }

    /// Get split for a receipt (returns nil if none exists)
    func getSplitForReceipt(receiptId: String) async throws -> ExpenseSplit? {
        do {
            let result: ExpenseSplit? = try await performOptionalRequest(
                endpoint: "/expense-splits/receipt/\(receiptId)",
                method: "GET"
            )
            return result
        } catch let error as ExpenseSplitAPIError {
            if case .notFound = error {
                return nil
            }
            throw error
        }
    }

    /// Update an existing split
    func updateSplit(splitId: String, request: ExpenseSplitCreateRequest) async throws -> ExpenseSplit {
        return try await performRequest(
            endpoint: "/expense-splits/\(splitId)",
            method: "PUT",
            body: request
        )
    }

    /// Delete a split
    func deleteSplit(splitId: String) async throws {
        let _: SplitEmptyResponse = try await performRequest(
            endpoint: "/expense-splits/\(splitId)",
            method: "DELETE"
        )
    }

    /// Get recent friends for quick-add
    func getRecentFriends(limit: Int = 10) async throws -> [RecentFriend] {
        return try await performRequest(
            endpoint: "/expense-splits/recent-friends?limit=\(limit)",
            method: "GET"
        )
    }

    /// Calculate split totals
    func calculateSplit(splitId: String) async throws -> SplitCalculationResponse {
        return try await performRequest(
            endpoint: "/expense-splits/\(splitId)/calculate",
            method: "GET"
        )
    }

    /// Get shareable text for a split
    func getShareText(splitId: String) async throws -> String {
        let response: ShareTextResponse = try await performRequest(
            endpoint: "/expense-splits/\(splitId)/share",
            method: "GET"
        )
        return response.text
    }

    // MARK: - Private Helpers

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String
    ) async throws -> T {
        return try await performRequestInternal(
            endpoint: endpoint,
            method: method,
            body: nil as EmptyBody?
        )
    }

    /// Perform request that may return null (for Optional types)
    private func performOptionalRequest<T: Decodable>(
        endpoint: String,
        method: String
    ) async throws -> T? {
        // Build URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ExpenseSplitAPIError.invalidURL
        }

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExpenseSplitAPIError.invalidResponse
        }

        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Check for null/empty response
            let responseString = String(data: data, encoding: .utf8)
            if data.isEmpty || responseString == "null" || responseString?.trimmingCharacters(in: .whitespaces) == "null" {
                return nil
            }

            // Decode response
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw ExpenseSplitAPIError.decodingError(error.localizedDescription)
            }

        case 401:
            throw ExpenseSplitAPIError.unauthorized

        case 404:
            throw ExpenseSplitAPIError.notFound

        case 400...499:
            let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
            throw ExpenseSplitAPIError.serverError(errorMessage)

        case 500...599:
            let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
            throw ExpenseSplitAPIError.serverError(errorMessage)

        default:
            throw ExpenseSplitAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
        }
    }

    private func performRequest<T: Decodable, B: Encodable>(
        endpoint: String,
        method: String,
        body: B
    ) async throws -> T {
        return try await performRequestInternal(
            endpoint: endpoint,
            method: method,
            body: body
        )
    }

    private func performRequestInternal<T: Decodable, B: Encodable>(
        endpoint: String,
        method: String,
        body: B?
    ) async throws -> T {
        // Build URL
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw ExpenseSplitAPIError.invalidURL
        }

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        // Add body if present
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }

        // Perform request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ExpenseSplitAPIError.invalidResponse
        }

        // Handle status codes
        switch httpResponse.statusCode {
        case 200...299:
            // Success - decode response
            do {
                // Handle empty responses
                if data.isEmpty || (String(data: data, encoding: .utf8) == "null") {
                    if T.self == SplitEmptyResponse.self {
                        return SplitEmptyResponse() as! T
                    }
                }
                return try decoder.decode(T.self, from: data)
            } catch {
                throw ExpenseSplitAPIError.decodingError(error.localizedDescription)
            }

        case 401:
            throw ExpenseSplitAPIError.unauthorized

        case 404:
            throw ExpenseSplitAPIError.notFound

        case 400...499:
            let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
            throw ExpenseSplitAPIError.serverError(errorMessage)

        case 500...599:
            let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
            throw ExpenseSplitAPIError.serverError(errorMessage)

        default:
            throw ExpenseSplitAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ExpenseSplitAPIError.noAuthToken
        }

        do {
            return try await user.getIDToken()
        } catch {
            throw ExpenseSplitAPIError.unauthorized
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data) {
            return errorDict["error"] ?? errorDict["message"] ?? errorDict["detail"]
        }
        return nil
    }
}

// MARK: - API Errors

enum ExpenseSplitAPIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError(String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noAuthToken:
            return "No authentication token available"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .notFound:
            return "Resource not found"
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        }
    }
}

// MARK: - Helper Types

private struct EmptyBody: Encodable {}

fileprivate struct SplitEmptyResponse: Decodable {}

// MARK: - Nonisolated Convenience Methods

extension ExpenseSplitAPIService {
    nonisolated func fetchRecentFriends(limit: Int = 10) async throws -> [RecentFriend] {
        return try await getRecentFriends(limit: limit)
    }

    nonisolated func fetchSplitForReceipt(receiptId: String) async throws -> ExpenseSplit? {
        return try await getSplitForReceipt(receiptId: receiptId)
    }

    nonisolated func createSplit(_ request: ExpenseSplitCreateRequest) async throws -> ExpenseSplit {
        return try await saveSplit(request)
    }
}
