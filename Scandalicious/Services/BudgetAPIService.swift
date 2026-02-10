//
//  BudgetAPIService.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
//  Simplified on 05/02/2026 - Removed AI features
//

import Foundation
import FirebaseAuth

// MARK: - Budget API Errors

enum BudgetAPIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case unauthorized
    case notFound
    case noBudgetSet
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
            return "Budget not found"
        case .noBudgetSet:
            return "No budget has been set yet"
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

// MARK: - Budget API Service

actor BudgetAPIService {
    static let shared = BudgetAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Budget Endpoints

    /// Get the user's current budget
    func fetchBudget() async throws -> UserBudget {
        return try await performRequest(
            endpoint: "/budgets",
            method: "GET"
        )
    }

    /// Create a new budget
    func createBudget(request: CreateBudgetRequest) async throws -> UserBudget {
        return try await performRequestWithBody(
            endpoint: "/budgets",
            method: "POST",
            body: request
        )
    }

    /// Update an existing budget
    func updateBudget(request: UpdateBudgetRequest) async throws -> UserBudget {
        return try await performRequestWithBody(
            endpoint: "/budgets",
            method: "PUT",
            body: request
        )
    }

    /// Delete the user's budget
    /// - Parameter month: Optional month in "yyyy-MM" format. If nil, deletes current month's budget.
    func deleteBudget(month: String? = nil) async throws {
        var queryItems: [URLQueryItem] = []
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: month))
        }

        // DELETE endpoints often return 204 No Content, so we don't try to decode response
        try await performRequestWithoutResponse(
            endpoint: "/budgets",
            method: "DELETE",
            queryItems: queryItems
        )
    }

    /// Get current budget progress (spending vs budget)
    /// - Parameter month: Optional month in "yyyy-MM" format. If nil, returns current month.
    func fetchBudgetProgress(month: String? = nil) async throws -> BudgetProgressResponse {
        var queryItems: [URLQueryItem] = []
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: month))
        }

        return try await performRequest(
            endpoint: "/budgets/progress",
            method: "GET",
            queryItems: queryItems
        )
    }

    // MARK: - Budget Suggestion Endpoint

    /// Get budget suggestion based on historical spending
    func fetchBudgetSuggestion(basedOnMonths: Int = 3) async throws -> SimpleBudgetSuggestionResponse {
        let queryItems = [
            URLQueryItem(name: "months", value: String(basedOnMonths))
        ]

        let response: SimpleBudgetSuggestionResponse = try await performRequest(
            endpoint: "/budgets/ai-suggestion",
            method: "GET",
            queryItems: queryItems
        )

        return response
    }

    /// Get budget insights based on spending history (no AI)
    func fetchBudgetInsights(
        includeBenchmarks: Bool = true,
        includeFlags: Bool = true,
        includeQuickWins: Bool = true,
        includeVolatility: Bool = true,
        includeProgress: Bool = true
    ) async throws -> BudgetInsightsResponse {
        var queryItems = [
            URLQueryItem(name: "include_benchmarks", value: String(includeBenchmarks)),
            URLQueryItem(name: "include_flags", value: String(includeFlags)),
            URLQueryItem(name: "include_quick_wins", value: String(includeQuickWins)),
            URLQueryItem(name: "include_volatility", value: String(includeVolatility)),
            URLQueryItem(name: "include_progress", value: String(includeProgress))
        ]

        return try await performRequest(
            endpoint: "/budgets/insights",
            method: "GET",
            queryItems: queryItems
        )
    }

    // MARK: - Category Monthly Spending (Smart Anchor)

    /// Get per-category monthly spending for the Smart Anchor modal
    func fetchCategoryMonthlySpend(months: Int = 3, category: String? = nil) async throws -> CategoryMonthlySpendResponse {
        var queryItems = [
            URLQueryItem(name: "months", value: String(months))
        ]
        if let category = category {
            queryItems.append(URLQueryItem(name: "category", value: category))
        }

        return try await performRequest(
            endpoint: "/budgets/category-monthly-spend",
            method: "GET",
            queryItems: queryItems
        )
    }

    // MARK: - Budget History Endpoints

    /// Get budget history for all past months
    func fetchBudgetHistory() async throws -> BudgetHistoryResponse {
        let response: BudgetHistoryResponse = try await performRequest(
            endpoint: "/budgets/history",
            method: "GET"
        )

        return response
    }

    /// Check if a budget should be auto-created for the current month based on smart budget settings
    func checkAutoRollover() async throws {
        let _: EmptyResponse = try await performRequest(
            endpoint: "/budgets/auto-rollover",
            method: "POST"
        )
    }

    // MARK: - Helper Methods

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        // Build URL
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw BudgetAPIError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw BudgetAPIError.invalidURL
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
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BudgetAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch let decodingError as DecodingError {
                    logDecodingError(decodingError, data: data, endpoint: endpoint)
                    throw BudgetAPIError.decodingError(decodingError.localizedDescription)
                }

            case 401:
                throw BudgetAPIError.unauthorized

            case 404:
                // Check if it's specifically "no budget" vs general not found
                if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
                   errorDict["code"] == "NO_BUDGET" {
                    throw BudgetAPIError.noBudgetSet
                }
                throw BudgetAPIError.notFound

            case 400...499:
                let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw BudgetAPIError.serverError(errorMessage)

            case 500...599:
                let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                throw BudgetAPIError.serverError(errorMessage)

            default:
                throw BudgetAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }

        } catch let error as BudgetAPIError {
            throw error
        } catch {
            throw BudgetAPIError.networkError(error)
        }
    }

    private func performRequestWithBody<T: Decodable, B: Encodable>(
        endpoint: String,
        method: String,
        body: B
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw BudgetAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BudgetAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch let decodingError as DecodingError {
                    logDecodingError(decodingError, data: data, endpoint: endpoint)
                    throw BudgetAPIError.decodingError(decodingError.localizedDescription)
                }

            case 401:
                throw BudgetAPIError.unauthorized

            case 404:
                throw BudgetAPIError.notFound

            case 400...499:
                let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw BudgetAPIError.serverError(errorMessage)

            case 500...599:
                let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                throw BudgetAPIError.serverError(errorMessage)

            default:
                throw BudgetAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }

        } catch let error as BudgetAPIError {
            throw error
        } catch {
            throw BudgetAPIError.networkError(error)
        }
    }

    /// Perform a request that doesn't expect a response body (e.g., DELETE with 204 No Content)
    private func performRequestWithoutResponse(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws {
        // Build URL
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw BudgetAPIError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw BudgetAPIError.invalidURL
        }

        // Get auth token
        let token = try await getAuthToken()

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        // Perform request
        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BudgetAPIError.invalidResponse
            }

            // Check for success (2xx status codes)
            switch httpResponse.statusCode {
            case 200...299:
                // Success - no need to decode response
                return
            case 401:
                throw BudgetAPIError.unauthorized
            case 404:
                throw BudgetAPIError.notFound
            default:
                throw BudgetAPIError.serverError("Server returned status \(httpResponse.statusCode)")
            }
        } catch let error as BudgetAPIError {
            throw error
        } catch {
            throw BudgetAPIError.networkError(error)
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw BudgetAPIError.noAuthToken
        }

        do {
            let token = try await user.getIDToken()
            return token
        } catch {
            throw BudgetAPIError.unauthorized
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data) {
            return errorDict["error"] ?? errorDict["message"]
        }
        return nil
    }

    private func logDecodingError(_ error: DecodingError, data: Data, endpoint: String) {
        // Decoding error logging disabled for production
    }
}

// MARK: - Nonisolated Convenience Methods

extension BudgetAPIService {
    nonisolated func getBudget() async throws -> UserBudget {
        return try await fetchBudget()
    }

    nonisolated func saveBudget(request: CreateBudgetRequest) async throws -> UserBudget {
        return try await createBudget(request: request)
    }

    nonisolated func modifyBudget(request: UpdateBudgetRequest) async throws -> UserBudget {
        return try await updateBudget(request: request)
    }

    nonisolated func removeBudget(month: String? = nil) async throws {
        return try await deleteBudget(month: month)
    }

    nonisolated func getBudgetProgress(month: String? = nil) async throws -> BudgetProgressResponse {
        return try await fetchBudgetProgress(month: month)
    }

    // MARK: - Budget Suggestion

    nonisolated func getBudgetSuggestion(basedOnMonths: Int = 3) async throws -> SimpleBudgetSuggestionResponse {
        return try await fetchBudgetSuggestion(basedOnMonths: basedOnMonths)
    }

    // Legacy alias for backward compatibility
    nonisolated func getAISuggestion(basedOnMonths: Int = 3) async throws -> SimpleBudgetSuggestionResponse {
        return try await fetchBudgetSuggestion(basedOnMonths: basedOnMonths)
    }

    // MARK: - Budget Insights

    nonisolated func getBudgetInsights(
        includeBenchmarks: Bool = true,
        includeFlags: Bool = true,
        includeQuickWins: Bool = true,
        includeVolatility: Bool = true,
        includeProgress: Bool = true
    ) async throws -> BudgetInsightsResponse {
        return try await fetchBudgetInsights(
            includeBenchmarks: includeBenchmarks,
            includeFlags: includeFlags,
            includeQuickWins: includeQuickWins,
            includeVolatility: includeVolatility,
            includeProgress: includeProgress
        )
    }

    // MARK: - Category Monthly Spending

    nonisolated func getCategoryMonthlySpend(months: Int = 3, category: String? = nil) async throws -> CategoryMonthlySpendResponse {
        return try await fetchCategoryMonthlySpend(months: months, category: category)
    }

    // MARK: - Budget History

    nonisolated func getBudgetHistory() async throws -> BudgetHistoryResponse {
        return try await fetchBudgetHistory()
    }

    nonisolated func performAutoRollover() async throws {
        return try await checkAutoRollover()
    }
}

// MARK: - Empty Response for DELETE

private struct EmptyResponse: Decodable {}
