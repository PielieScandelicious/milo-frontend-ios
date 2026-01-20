//
//  DobbyAIChatService.swift
//  dobby-ios
//
//  BACKEND VERSION - Uses Railway API
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation

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
    let transactions: [TransactionData]
}

struct BackendChatMessage: Sendable, Codable {
    let role: String
    let content: String
}

struct TransactionData: Sendable, Codable {
    let id: String
    let storeName: String
    let category: String
    let itemName: String
    let amount: Double
    let date: String
    let quantity: Int
    let paymentMethod: String
}

struct ChatResponse: Sendable, Codable {
    let response: String
}

// MARK: - Chat Service Errors
enum ChatServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case serverError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .emptyResponse:
            return "Empty response from server"
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode)): \(message)"
        }
    }
}

// MARK: - Dobby AI Chat Service (Backend Version)
actor DobbyAIChatService {
    static let shared = DobbyAIChatService()
    
    private init() {}
    
    // MARK: - Send Chat Message (Streaming)
    func sendMessageStreaming(_ userMessage: String, transactions: [DobbyTransaction], conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    // For now, use non-streaming and yield the full response
                    // You can update this when backend supports streaming
                    let response = try await sendMessage(userMessage, transactions: transactions, conversationHistory: conversationHistory)
                    continuation.yield(response)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Send Chat Message
    nonisolated func sendMessage(_ userMessage: String, transactions: [DobbyTransaction], conversationHistory: [ChatMessage]) async throws -> String {
        let endpoint = await MainActor.run { AppConfiguration.chatEndpoint }
        guard let url = URL(string: endpoint) else {
            throw ChatServiceError.invalidURL
        }
        
        // Convert conversation history to backend format
        let backendHistory = conversationHistory
            .filter { $0.role != .system }
            .map { BackendChatMessage(role: $0.role.rawValue, content: $0.content) }
        
        // Convert transactions to backend format
        let transactionData = transactions.map { transaction in
            TransactionData(
                id: transaction.id.uuidString,
                storeName: transaction.storeName,
                category: transaction.category,
                itemName: transaction.itemName,
                amount: transaction.amount,
                date: ISO8601DateFormatter().string(from: transaction.date),
                quantity: transaction.quantity,
                paymentMethod: transaction.paymentMethod
            )
        }
        
        // Create request
        let chatRequest = ChatRequest(
            message: userMessage,
            conversationHistory: backendHistory,
            transactions: transactionData
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        request.httpBody = try await MainActor.run {
            try JSONEncoder().encode(chatRequest)
        }
        
        // Send request
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw ChatServiceError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Parse response
        let chatResponse = try await MainActor.run {
            try JSONDecoder().decode(ChatResponse.self, from: data)
        }
        
        guard !chatResponse.response.isEmpty else {
            throw ChatServiceError.emptyResponse
        }
        
        return chatResponse.response
    }
}

