//
//  BudgetAPIService.swift
//  Scandalicious
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
        case .invalidURL: return "Invalid API URL"
        case .noAuthToken: return "No authentication token available"
        case .unauthorized: return "Unauthorized - please sign in again"
        case .notFound: return "Budget not found"
        case .noBudgetSet: return "No budget has been set yet"
        case .serverError(let message): return "Server error: \(message)"
        case .decodingError(let message): return "Failed to decode response: \(message)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        case .invalidResponse: return "Invalid server response"
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

    func fetchBudget() async throws -> UserBudget {
        return try await performRequest(endpoint: "/budgets", method: "GET")
    }

    func createBudget(request: CreateBudgetRequest) async throws -> UserBudget {
        return try await performRequestWithBody(endpoint: "/budgets", method: "POST", body: request)
    }

    func updateBudget(request: UpdateBudgetRequest) async throws -> UserBudget {
        return try await performRequestWithBody(endpoint: "/budgets", method: "PUT", body: request)
    }

    func deleteBudget(month: String? = nil) async throws {
        var queryItems: [URLQueryItem] = []
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: month))
        }
        try await performRequestWithoutResponse(endpoint: "/budgets", method: "DELETE", queryItems: queryItems)
    }

    func fetchBudgetProgress(month: String? = nil) async throws -> BudgetProgressResponse {
        var queryItems: [URLQueryItem] = []
        if let month = month {
            queryItems.append(URLQueryItem(name: "month", value: month))
        }
        print("[BudgetAPI] GET /budgets/progress (month=\(month ?? "current"), baseURL=\(baseURL))")
        do {
            let result: BudgetProgressResponse = try await performRequest(endpoint: "/budgets/progress", method: "GET", queryItems: queryItems)
            print("[BudgetAPI] ✅ Success: spend=€\(result.currentSpend), budget=€\(result.budget.monthlyAmount)")
            return result
        } catch {
            print("[BudgetAPI] ❌ Error: \(error)")
            throw error
        }
    }

    // MARK: - Budget History

    func fetchBudgetHistory() async throws -> BudgetHistoryResponse {
        return try await performRequest(endpoint: "/budgets/history", method: "GET")
    }

    func checkAutoRollover() async throws {
        let _: EmptyResponse = try await performRequest(endpoint: "/budgets/auto-rollover", method: "POST")
    }

    // MARK: - Helper Methods

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw BudgetAPIError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw BudgetAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BudgetAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch let decodingError as DecodingError {
                    throw BudgetAPIError.decodingError(decodingError.localizedDescription)
                }
            case 401:
                throw BudgetAPIError.unauthorized
            case 404:
                // FastAPI wraps detail as: {"detail": {"error": "...", "code": "NO_BUDGET"}}
                if let wrapper = try? JSONDecoder().decode([String: [String: String]].self, from: data),
                   wrapper["detail"]?["code"] == "NO_BUDGET" {
                    throw BudgetAPIError.noBudgetSet
                }
                // Fallback: flat format {"code": "NO_BUDGET"}
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
                    return try decoder.decode(T.self, from: data)
                } catch let decodingError as DecodingError {
                    throw BudgetAPIError.decodingError(decodingError.localizedDescription)
                }
            case 401:
                throw BudgetAPIError.unauthorized
            case 404:
                if let wrapper = try? JSONDecoder().decode([String: [String: String]].self, from: data),
                   wrapper["detail"]?["code"] == "NO_BUDGET" {
                    throw BudgetAPIError.noBudgetSet
                }
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

    private func performRequestWithoutResponse(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw BudgetAPIError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw BudgetAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BudgetAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
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
            return try await user.getIDToken()
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

    nonisolated func getBudgetHistory() async throws -> BudgetHistoryResponse {
        return try await fetchBudgetHistory()
    }

    nonisolated func performAutoRollover() async throws {
        return try await checkAutoRollover()
    }
}

// MARK: - Empty Response for DELETE

private struct EmptyResponse: Decodable {}
