//
//  BudgetAPIService.swift
//  Scandalicious
//
//  Created by Claude on 31/01/2026.
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
    func deleteBudget() async throws {
        let _: EmptyResponse = try await performRequest(
            endpoint: "/budgets",
            method: "DELETE"
        )
    }

    /// Get current budget progress (spending vs budget)
    func fetchBudgetProgress() async throws -> BudgetProgressResponse {
        return try await performRequest(
            endpoint: "/budgets/progress",
            method: "GET"
        )
    }

    // MARK: - AI-Powered Endpoints (All budget calculations are AI-powered)

    /// Get AI-powered budget suggestion with personalized insights
    func fetchAISuggestion(basedOnMonths: Int = 3) async throws -> AIBudgetSuggestionResponse {
        print("🤖 [AI Budget] Fetching AI suggestion for \(basedOnMonths) months...")

        let queryItems = [
            URLQueryItem(name: "months", value: String(basedOnMonths))
        ]

        let response: AIBudgetSuggestionResponse = try await performRequest(
            endpoint: "/budgets/ai-suggestion",
            method: "GET",
            queryItems: queryItems
        )

        // Log AI response details
        print("🤖 [AI Budget] ✅ AI Suggestion received:")
        print("   📅 Based on Months: \(response.basedOnMonths) (Data Collection Phase: \(response.dataCollectionPhase.title))")
        print("   💵 Total Spend Analyzed: €\(response.totalSpendAnalyzed)")
        print("   📊 Recommended Budget: €\(response.recommendedBudget.amount) (confidence: \(response.recommendedBudget.confidence))")
        print("   📈 Health Score: \(response.budgetHealthScore)/100")
        print("   📦 Category Allocations (\(response.categoryAllocations.count) categories):")
        for allocation in response.categoryAllocations {
            print("      - \(allocation.category): €\(allocation.suggestedAmount) (\(allocation.percentage)%) - Savings potential: \(allocation.savingsPotential)")
        }
        print("   💡 Tips: \(response.personalizedTips.count) personalized tips")
        print("   💰 Savings Opportunities: \(response.savingsOpportunities.count)")
        print("   📝 Summary: \(response.summary)")

        return response
    }

    /// Get weekly AI check-in with budget progress analysis
    func fetchAICheckIn() async throws -> AICheckInResponse {
        print("🤖 [AI Budget] Fetching AI check-in...")

        let response: AICheckInResponse = try await performRequest(
            endpoint: "/budgets/ai-check-in",
            method: "GET"
        )

        print("🤖 [AI Budget] ✅ AI Check-in received:")
        print("   👋 Greeting: \(response.greeting)")
        print("   📊 Status: \(response.statusSummary.headline)")
        print("   💵 Daily Budget Remaining: €\(response.dailyBudgetRemaining)")

        return response
    }

    /// Analyze a receipt for budget impact
    func fetchAIReceiptAnalysis(receiptId: String) async throws -> AIReceiptAnalysisResponse {
        print("🤖 [AI Budget] Analyzing receipt \(receiptId) for budget impact...")

        let response: AIReceiptAnalysisResponse = try await performRequestWithBody(
            endpoint: "/budgets/ai-analyze-receipt",
            method: "POST",
            body: ["receipt_id": receiptId]
        )

        print("🤖 [AI Budget] ✅ Receipt analysis received:")
        print("   \(response.emoji) Status: \(response.status)")
        print("   📝 Summary: \(response.impactSummary)")
        if let tip = response.quickTip {
            print("   💡 Quick Tip: \(tip)")
        }

        return response
    }

    /// Get AI-generated monthly budget report
    func fetchAIMonthlyReport(month: String) async throws -> AIMonthlyReportResponse {
        print("🤖 [AI Budget] Fetching AI monthly report for \(month)...")

        let queryItems = [
            URLQueryItem(name: "month", value: month)
        ]

        let response: AIMonthlyReportResponse = try await performRequest(
            endpoint: "/budgets/ai-month-report",
            method: "GET",
            queryItems: queryItems
        )

        print("🤖 [AI Budget] ✅ Monthly report received:")
        print("   📊 Grade: \(response.grade) (Score: \(response.score))")
        print("   📝 Headline: \(response.headline)")
        print("   ✅ Wins: \(response.wins.count)")
        print("   ⚠️ Challenges: \(response.challenges.count)")

        return response
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

        print("📡 Budget API Request: \(method) \(url.absoluteString)")

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

            print("📥 Budget response: HTTP \(httpResponse.statusCode)")

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

        print("📡 Budget API Request: \(method) \(url.absoluteString)")

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

            print("📥 Budget response: HTTP \(httpResponse.statusCode)")

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
        print("❌ Budget decoding error for endpoint: \(endpoint)")

        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Raw server response:\n\(jsonString)")
        }

        switch error {
        case .keyNotFound(let key, let context):
            print("🔑 Missing key '\(key.stringValue)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")

        case .typeMismatch(let type, let context):
            print("⚠️ Type mismatch for type '\(type)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")

        case .valueNotFound(let type, let context):
            print("❓ Value not found for type '\(type)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")

        case .dataCorrupted(let context):
            print("💥 Data corrupted")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")

        @unknown default:
            print("❔ Unknown decoding error")
        }
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

    nonisolated func removeBudget() async throws {
        return try await deleteBudget()
    }

    nonisolated func getBudgetProgress() async throws -> BudgetProgressResponse {
        return try await fetchBudgetProgress()
    }

    // MARK: - AI Nonisolated Methods (All budget suggestions are AI-powered)

    nonisolated func getAISuggestion(basedOnMonths: Int = 3) async throws -> AIBudgetSuggestionResponse {
        return try await fetchAISuggestion(basedOnMonths: basedOnMonths)
    }

    nonisolated func getAICheckIn() async throws -> AICheckInResponse {
        return try await fetchAICheckIn()
    }

    nonisolated func getAIReceiptAnalysis(receiptId: String) async throws -> AIReceiptAnalysisResponse {
        return try await fetchAIReceiptAnalysis(receiptId: receiptId)
    }

    nonisolated func getAIMonthlyReport(month: String) async throws -> AIMonthlyReportResponse {
        return try await fetchAIMonthlyReport(month: month)
    }
}

// MARK: - Empty Response for DELETE

private struct EmptyResponse: Decodable {}
