//
//  InsightService.swift
//  Scandalicious
//
//  Created by Claude on 21/01/2026.
//

import Foundation
import FirebaseAuth

// MARK: - Insight Types

enum InsightType {
    case totalSpending(amount: Double, period: String, storeCount: Int, topStore: String?)
    case healthScore(score: Double?, period: String, totalItems: Int)
    case storeBreakdown(storeName: String, amount: Double, period: String, healthScore: Double?)

    /// Unique cache key for storing daily insights
    /// The key is based on the insight type and period, so the same insight type + period combination
    /// will use the same cached value throughout the day
    var cacheKey: String {
        switch self {
        case .totalSpending(_, let period, _, _):
            return "daily_insight_totalSpending_\(period)"
        case .healthScore(_, let period, _):
            return "daily_insight_healthScore_\(period)"
        case .storeBreakdown(let storeName, _, let period, _):
            return "daily_insight_store_\(storeName)_\(period)"
        }
    }

    var prompt: String {
        switch self {
        case .totalSpending(let amount, let period, let storeCount, let topStore):
            var prompt = """
            Generate a brief, insightful observation about this spending data. Be concise (2-3 sentences max), friendly, and provide actionable perspective.

            Data:
            - Total spent: €\(String(format: "%.2f", amount))
            - Period: \(period)
            - Number of stores visited: \(storeCount)
            """
            if let top = topStore {
                prompt += "\n- Most visited store: \(top)"
            }
            prompt += "\n\nProvide a short, helpful insight about their spending habits. Don't repeat the numbers - give perspective or a tip."
            return prompt

        case .healthScore(let score, let period, let totalItems):
            let scoreText = score.map { String(format: "%.1f", $0) } ?? "N/A"
            return """
            Generate a brief, encouraging observation about this health score. Be concise (2-3 sentences max), supportive, and provide helpful perspective.

            Data:
            - Average health score: \(scoreText) out of 5.0
            - Period: \(period)
            - Total items tracked: \(totalItems)

            Health score scale: 5=Very Healthy (fresh produce), 4=Healthy, 3=Moderate, 2=Less Healthy, 1=Unhealthy, 0=Very Unhealthy.

            Provide a short, supportive insight. Focus on encouragement and one small actionable tip if relevant.
            """

        case .storeBreakdown(let storeName, let amount, let period, let healthScore):
            var prompt = """
            Generate a brief insight about shopping at this store. Be concise (2-3 sentences max) and helpful.

            Data:
            - Store: \(storeName)
            - Amount spent: €\(String(format: "%.2f", amount))
            - Period: \(period)
            """
            if let score = healthScore {
                prompt += "\n- Average health score at this store: \(String(format: "%.1f", score))/5.0"
            }
            prompt += "\n\nProvide a brief, helpful observation about their shopping at this store."
            return prompt
        }
    }
}

// MARK: - Insight Service

actor InsightService {
    static let shared = InsightService()

    private init() {}

    // MARK: - Get Auth Token

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ChatServiceError.authenticationRequired
        }
        return try await user.getIDToken()
    }

    // MARK: - Generate Insight (Streaming)

    // MARK: - Prefetch Insight (Background)

    /// Prefetches an insight in the background if not already cached
    /// This runs silently and doesn't block the UI
    nonisolated func prefetchInsight(for type: InsightType) {
        // Check if we already have a valid cached insight
        if DailyInsightCache.hasValidCache(for: type) {
            return
        }

        // Fetch in background
        Task(priority: .background) {
            do {
                var fullText = ""
                for try await chunk in generateInsight(for: type) {
                    fullText += chunk
                }
                // Save to cache
                await MainActor.run {
                    DailyInsightCache.save(text: fullText, for: type.cacheKey)
                }
            } catch {
                // Silently fail - user can still generate on demand
            }
        }
    }

    nonisolated func generateInsight(for type: InsightType) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let endpoint = await MainActor.run { AppConfiguration.chatStreamEndpoint }
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: ChatServiceError.invalidURL)
                        return
                    }

                    let authToken = try await InsightService.shared.getAuthToken()

                    let chatRequest = ChatRequest(
                        message: type.prompt,
                        conversationHistory: []
                    )

                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                    request.timeoutInterval = 30

                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    request.httpBody = try encoder.encode(chatRequest)

                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatServiceError.invalidResponse)
                        return
                    }

                    if httpResponse.statusCode == 401 {
                        continuation.finish(throwing: ChatServiceError.authenticationRequired)
                        return
                    }

                    if httpResponse.statusCode == 429 {
                        continuation.finish(throwing: ChatServiceError.rateLimitExceeded("Insight limit reached. Try again later."))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        continuation.finish(throwing: ChatServiceError.serverError(statusCode: httpResponse.statusCode, message: "Failed to generate insight"))
                        return
                    }

                    // Parse SSE stream
                    var buffer = ""
                    for try await byte in asyncBytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)

                        if buffer.hasSuffix("\n\n") {
                            let lines = buffer.components(separatedBy: "\n")

                            for line in lines {
                                if line.hasPrefix("data: ") {
                                    let jsonString = String(line.dropFirst(6))

                                    if let data = jsonString.data(using: .utf8),
                                       let event = try? JSONDecoder().decode(ChatStreamEvent.self, from: data) {

                                        switch event.type {
                                        case "text":
                                            if let content = event.content {
                                                continuation.yield(content)
                                            }
                                        case "done":
                                            continuation.finish()
                                            return
                                        case "error":
                                            continuation.finish(throwing: ChatServiceError.streamingError(event.error ?? "Unknown error"))
                                            return
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                            buffer = ""
                        }
                    }

                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
