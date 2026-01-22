//
//  ScandaLiciousAIChatService.swift
//  Scandalicious
//
//  BACKEND VERSION - Uses Railway API with Firebase Auth & SSE Streaming
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation
import FirebaseAuth

// Disambiguate Transaction type from SwiftData
typealias DobbyTransaction = Transaction

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    
    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum ChatRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

// MARK: - Backend API Models
struct ChatRequest: Sendable, Codable {
    let message: String
    let conversationHistory: [BackendChatMessage]
    
    enum CodingKeys: String, CodingKey {
        case message
        case conversationHistory = "conversation_history"
    }
}

struct BackendChatMessage: Sendable, Codable {
    let role: String
    let content: String
}

struct ChatResponse: Sendable, Codable {
    let response: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case response
        case createdAt = "created_at"
    }
}

// MARK: - SSE Stream Event Models
struct ChatStreamEvent: Sendable, Codable {
    let type: String
    let content: String?
    let error: String?
}

// MARK: - Chat Service Errors
enum ChatServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case authenticationRequired
    case tokenRefreshFailed
    case serverError(statusCode: Int, message: String)
    case streamingError(String)
    case rateLimitExceeded(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyResponse:
            return "Empty response from server"
        case .authenticationRequired:
            return "Authentication required. Please sign in again."
        case .tokenRefreshFailed:
            return "Failed to refresh authentication token"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        case .streamingError(let message):
            return "Streaming error: \(message)"
        case .rateLimitExceeded(let message):
            return message
        }
    }

    var isRateLimitError: Bool {
        if case .rateLimitExceeded = self { return true }
        return false
    }
}

// MARK: - Dobby AI Chat Service (Backend Version with Firebase Auth)
actor DobbyAIChatService {
    static let shared = DobbyAIChatService()

    private init() {}

    // MARK: - Rate Limit Header Parsing

    /// Parse X-RateLimit-* headers from response and sync with RateLimitManager
    private static func parseAndSyncRateLimitHeaders(from response: HTTPURLResponse) async {
        guard let limitStr = response.value(forHTTPHeaderField: "X-RateLimit-Limit"),
              let remainingStr = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
              let resetStr = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
              let limit = Int(limitStr),
              let remaining = Int(remainingStr),
              let reset = TimeInterval(resetStr) else {
            return
        }

        await MainActor.run {
            RateLimitManager.shared.syncFromHeaders(limit: limit, remaining: remaining, resetTimestamp: reset)
        }
    }
    
    // MARK: - Get Firebase Auth Token
    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw ChatServiceError.authenticationRequired
        }
        
        do {
            let token = try await user.getIDToken()
            return token
        } catch {
            print("❌ Failed to get Firebase ID token: \(error)")
            throw ChatServiceError.tokenRefreshFailed
        }
    }
    
    // MARK: - Send Chat Message (Streaming) - RECOMMENDED
    nonisolated func sendMessageStreaming(_ userMessage: String, transactions: [DobbyTransaction], conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let endpoint = await MainActor.run { AppConfiguration.chatStreamEndpoint }
                    guard let url = URL(string: endpoint) else {
                        continuation.finish(throwing: ChatServiceError.invalidURL)
                        return
                    }
                    
                    // Get auth token
                    let authToken = try await DobbyAIChatService.shared.getAuthToken()
                    
                    // Convert conversation history to backend format
                    let backendHistory = conversationHistory
                        .filter { $0.role != .system }
                        .map { BackendChatMessage(role: $0.role.rawValue, content: $0.content) }
                    
                    // Create request
                    let chatRequest = ChatRequest(
                        message: userMessage,
                        conversationHistory: backendHistory
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
                    request.timeoutInterval = 60 // 60 second timeout for streaming
                    
                    let encoder = JSONEncoder()
                    encoder.keyEncodingStrategy = .convertToSnakeCase
                    request.httpBody = try encoder.encode(chatRequest)
                    
                    // Create streaming session
                    let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: ChatServiceError.invalidResponse)
                        return
                    }
                    
                    // Handle authentication errors
                    if httpResponse.statusCode == 401 {
                        continuation.finish(throwing: ChatServiceError.authenticationRequired)
                        return
                    }

                    // Handle rate limit exceeded (429)
                    if httpResponse.statusCode == 429 {
                        // Try to parse the rate limit error response
                        var errorBody = ""
                        for try await byte in asyncBytes {
                            errorBody.append(Character(UnicodeScalar(byte)))
                        }

                        if let data = errorBody.data(using: .utf8) {
                            let decoder = JSONDecoder()
                            decoder.dateDecodingStrategy = .iso8601
                            if let rateLimitError = try? decoder.decode(RateLimitExceededError.self, from: data) {
                                // Update rate limit manager on main thread
                                await MainActor.run {
                                    RateLimitManager.shared.handleRateLimitExceeded(rateLimitError)
                                }
                                continuation.finish(throwing: ChatServiceError.rateLimitExceeded(rateLimitError.message))
                                return
                            }
                        }

                        continuation.finish(throwing: ChatServiceError.rateLimitExceeded("You've reached your message limit for this period."))
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        let errorMessage = "HTTP \(httpResponse.statusCode)"
                        continuation.finish(throwing: ChatServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage))
                        return
                    }

                    // Parse rate limit headers and sync
                    await Self.parseAndSyncRateLimitHeaders(from: httpResponse)
                    
                    // Parse SSE stream
                    var buffer = ""
                    for try await byte in asyncBytes {
                        let char = Character(UnicodeScalar(byte))
                        buffer.append(char)
                        
                        // SSE messages end with double newline
                        if buffer.hasSuffix("\n\n") {
                            let lines = buffer.components(separatedBy: "\n")
                            
                            for line in lines {
                                // SSE events start with "data: "
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
                                            let errorMsg = event.error ?? "Unknown streaming error"
                                            continuation.finish(throwing: ChatServiceError.streamingError(errorMsg))
                                            return
                                        default:
                                            print("⚠️ Unknown SSE event type: \(event.type)")
                                        }
                                    }
                                }
                            }
                            
                            buffer = ""
                        }
                    }
                    
                    // Stream ended without "done" event
                    continuation.finish()
                    
                } catch let error as ChatServiceError {
                    continuation.finish(throwing: error)
                } catch {
                    print("❌ Streaming error: \(error)")
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Send Chat Message (Non-streaming) - Fallback
    nonisolated func sendMessage(_ userMessage: String, transactions: [DobbyTransaction], conversationHistory: [ChatMessage]) async throws -> String {
        let endpoint = await MainActor.run { AppConfiguration.chatEndpoint }
        guard let url = URL(string: endpoint) else {
            throw ChatServiceError.invalidURL
        }
        
        // Get auth token with retry logic
        var authToken: String
        do {
            authToken = try await DobbyAIChatService.shared.getAuthToken()
        } catch {
            // Try one more time to refresh the token
            try? await Task.sleep(for: .milliseconds(500))
            authToken = try await DobbyAIChatService.shared.getAuthToken()
        }
        
        // Convert conversation history to backend format
        let backendHistory = conversationHistory
            .filter { $0.role != .system }
            .map { BackendChatMessage(role: $0.role.rawValue, content: $0.content) }
        
        // Create request
        let chatRequest = ChatRequest(
            message: userMessage,
            conversationHistory: backendHistory
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(chatRequest)
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }
        
        // Handle authentication errors with retry
        if httpResponse.statusCode == 401 {
            print("⚠️ 401 Unauthorized - attempting token refresh...")
            
            // Try to refresh token and retry once
            try? await Task.sleep(for: .milliseconds(500))
            let newToken = try await DobbyAIChatService.shared.getAuthToken()
            request.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            
            let (retryData, retryResponse) = try await URLSession.shared.data(for: request)
            
            guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                throw ChatServiceError.invalidResponse
            }
            
            if retryHttpResponse.statusCode == 401 {
                throw ChatServiceError.authenticationRequired
            }
            
            guard retryHttpResponse.statusCode == 200 else {
                let errorMessage = String(data: retryData, encoding: .utf8) ?? "Unknown error"
                throw ChatServiceError.serverError(statusCode: retryHttpResponse.statusCode, message: errorMessage)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let chatResponse = try decoder.decode(ChatResponse.self, from: retryData)
            
            guard !chatResponse.response.isEmpty else {
                throw ChatServiceError.emptyResponse
            }
            
            return chatResponse.response
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ChatServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let chatResponse = try decoder.decode(ChatResponse.self, from: data)
        
        guard !chatResponse.response.isEmpty else {
            throw ChatServiceError.emptyResponse
        }
        
        return chatResponse.response
    }
}

