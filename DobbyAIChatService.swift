//
//  DobbyAIChatService.swift
//  Dobby
//
//  CLEAN VERSION - Copy this EXACTLY
//  Created by Gilles Moenaert on 19/01/2026.
//

import Foundation

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Codable {
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

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - Anthropic API Models
struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

struct AnthropicResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [ContentBlock]
    let model: String
    let stopReason: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model
        case stopReason = "stop_reason"
    }
    
    struct ContentBlock: Codable {
        let type: String
        let text: String
    }
}

enum AnthropicError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case invalidAPIKey
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .emptyResponse:
            return "Empty response from API"
        case .invalidAPIKey:
            return "Invalid or missing Anthropic API key. Please check your configuration in env.swift"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}

// MARK: - Dobby AI Chat Service
actor DobbyAIChatService {
    static let shared = DobbyAIChatService()
    
    private let apiKey: String
    private let apiURL = "https://api.anthropic.com/v1/messages"
    
    private init() {
        self.apiKey = AppConfiguration.anthropicAPIKey
    }
    
    // MARK: - Send Chat Message (Streaming)
    func sendMessageStreaming(_ userMessage: String, transactions: [Transaction], conversationHistory: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let systemPrompt = buildSystemPrompt(transactions: transactions)
                    
                    var messages: [AnthropicMessage] = []
                    
                    for message in conversationHistory {
                        if message.role != .system {
                            messages.append(AnthropicMessage(role: message.role.rawValue, content: message.content))
                        }
                    }
                    
                    messages.append(AnthropicMessage(role: "user", content: userMessage))
                    
                    try await streamRequest(systemPrompt: systemPrompt, messages: messages) { chunk in
                        continuation.yield(chunk)
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Send Chat Message (Non-Streaming - for compatibility)
    func sendMessage(_ userMessage: String, transactions: [Transaction], conversationHistory: [ChatMessage]) async throws -> String {
        let systemPrompt = buildSystemPrompt(transactions: transactions)
        
        var messages: [AnthropicMessage] = []
        
        for message in conversationHistory {
            if message.role != .system {
                messages.append(AnthropicMessage(role: message.role.rawValue, content: message.content))
            }
        }
        
        messages.append(AnthropicMessage(role: "user", content: userMessage))
        
        let response = try await sendRequest(systemPrompt: systemPrompt, messages: messages)
        return response
    }
    
    // MARK: - Build System Prompt
    private func buildSystemPrompt(transactions: [Transaction]) -> String {
        let nutritionData = calculateNutritionInsights(from: transactions)
        let spendingData = calculateSpendingInsights(from: transactions)
        let allTransactionsData = formatAllTransactions(transactions)
        
        return """
        You are Dobby, a friendly and knowledgeable AI assistant specialized in analyzing grocery shopping data and providing personalized dietary and financial insights.
        
        Your personality:
        - Friendly and conversational
        - Data-driven but explain insights in simple terms
        - Proactive in suggesting improvements
        - Supportive and non-judgmental
        
        IMPORTANT: You have access to the COMPLETE transaction data below. When asked questions about spending or shopping:
        1. Count and calculate from the actual transaction list, not from summaries
        2. Be precise with numbers - verify your calculations
        3. Reference specific items and dates when relevant
        4. If you need to count items or sum amounts, do so carefully from the full list
        
        ## Complete Transaction Data
        Total transactions: \(transactions.count)
        
        \(allTransactionsData)
        
        ## Pre-calculated Summaries (for reference)
        
        ### Nutrition Overview:
        \(nutritionData.summary)
        
        ### Spending Overview:
        \(spendingData.summary)
        
        When answering questions:
        1. ALWAYS refer to the complete transaction list above for accurate counts and totals
        2. Double-check your math when calculating totals or percentages
        3. Provide actionable insights and suggestions
        4. Compare spending/nutrition to general healthy guidelines
        5. Be specific about numbers and reference actual items from the list
        6. Suggest healthier or more cost-effective alternatives when appropriate
        
        Common questions you should be able to answer:
        - "Do I have enough protein in my diet?"
        - "Am I spending too much on alcohol?"
        - "What's my biggest expense category?"
        - "How can I eat healthier?"
        - "Am I buying enough vegetables?"
        - "Where can I save money?"
        - "How many times did I buy [item]?"
        - "How much did I spend on [category/store]?"
        
        Always be helpful, specific, and reference the actual data from the complete transaction list.
        """
    }
    
    // MARK: - Calculate Nutrition Insights
    private func calculateNutritionInsights(from transactions: [Transaction]) -> (summary: String, details: [String: Double]) {
        var categoryTotals: [String: Double] = [:]
        var categoryItems: [String: Int] = [:]
        
        for transaction in transactions {
            categoryTotals[transaction.category, default: 0] += transaction.amount
            categoryItems[transaction.category, default: 0] += transaction.quantity
        }
        
        let proteinCategories = ["Meat & Fish", "Dairy & Eggs"]
        let vegetableCategories = ["Fresh Produce"]
        let unhealthyCategories = ["Snacks & Sweets", "Alcohol", "Drinks (Soft/Soda)"]
        
        let proteinSpending = proteinCategories.reduce(0.0) { $0 + (categoryTotals[$1] ?? 0) }
        let vegetableSpending = vegetableCategories.reduce(0.0) { $0 + (categoryTotals[$1] ?? 0) }
        let unhealthySpending = unhealthyCategories.reduce(0.0) { $0 + (categoryTotals[$1] ?? 0) }
        let totalSpending = categoryTotals.values.reduce(0, +)
        
        let proteinItems = proteinCategories.reduce(0) { $0 + (categoryItems[$1] ?? 0) }
        let vegetableItems = vegetableCategories.reduce(0) { $0 + (categoryItems[$1] ?? 0) }
        
        let proteinPercentage = totalSpending > 0 ? (proteinSpending/totalSpending)*100 : 0
        let vegetablePercentage = totalSpending > 0 ? (vegetableSpending/totalSpending)*100 : 0
        
        let summary = """
        - Protein sources (Meat, Fish, Dairy): €\(String(format: "%.2f", proteinSpending)) (\(proteinItems) items)
        - Vegetables & Produce: €\(String(format: "%.2f", vegetableSpending)) (\(vegetableItems) items)
        - Less healthy items (Snacks, Sweets, Alcohol, Soda): €\(String(format: "%.2f", unhealthySpending))
        - Total grocery spending: €\(String(format: "%.2f", totalSpending))
        - Protein percentage of total: \(String(format: "%.1f", proteinPercentage))%
        - Vegetables percentage of total: \(String(format: "%.1f", vegetablePercentage))%
        """
        
        return (summary, categoryTotals)
    }
    
    // MARK: - Calculate Spending Insights
    private func calculateSpendingInsights(from transactions: [Transaction]) -> (summary: String, details: [String: Double]) {
        var storeTotals: [String: Double] = [:]
        var categoryTotals: [String: Double] = [:]
        
        for transaction in transactions {
            storeTotals[transaction.storeName, default: 0] += transaction.amount
            categoryTotals[transaction.category, default: 0] += transaction.amount
        }
        
        let topCategories = categoryTotals.sorted { $0.value > $1.value }.prefix(5)
        let topStores = storeTotals.sorted { $0.value > $1.value }
        
        var summary = "Top spending by category:\n"
        for (index, category) in topCategories.enumerated() {
            summary += "\(index + 1). \(category.key): €\(String(format: "%.2f", category.value))\n"
        }
        
        summary += "\nSpending by store:\n"
        for store in topStores {
            summary += "- \(store.key): €\(String(format: "%.2f", store.value))\n"
        }
        
        return (summary, categoryTotals)
    }
    
    // MARK: - Format All Transactions (Complete Data)
    private func formatAllTransactions(_ transactions: [Transaction]) -> String {
        let sorted = transactions.sorted { $0.date > $1.date }
        
        var formatted = "### All Transactions (sorted by date, newest first):\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Group by category for better organization
        var categorizedTransactions: [String: [Transaction]] = [:]
        for transaction in sorted {
            categorizedTransactions[transaction.category, default: []].append(transaction)
        }
        
        // Also provide a chronological list
        formatted += "**Chronological List:**\n"
        for (index, transaction) in sorted.enumerated() {
            formatted += "\(index + 1). [\(dateFormatter.string(from: transaction.date))] \(transaction.itemName) - €\(String(format: "%.2f", transaction.amount)) (Qty: \(transaction.quantity)) - \(transaction.category) at \(transaction.storeName)\n"
        }
        
        formatted += "\n**Grouped by Category:**\n"
        for (category, items) in categorizedTransactions.sorted(by: { $0.key < $1.key }) {
            let categoryTotal = items.reduce(0.0) { $0 + $1.amount }
            formatted += "\n### \(category) (Total: €\(String(format: "%.2f", categoryTotal)), \(items.count) items):\n"
            for item in items {
                formatted += "  - \(item.itemName): €\(String(format: "%.2f", item.amount)) x\(item.quantity) on \(dateFormatter.string(from: item.date)) at \(item.storeName)\n"
            }
        }
        
        return formatted
    }
    
    // MARK: - Format Recent Transactions (Legacy - kept for reference)
    private func formatRecentTransactions(_ transactions: [Transaction]) -> String {
        let recent = transactions.sorted { $0.date > $1.date }.prefix(20)
        var formatted = "Last 20 transactions:\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        
        for transaction in recent {
            formatted += "- \(dateFormatter.string(from: transaction.date)): \(transaction.itemName) (\(transaction.category)) - €\(String(format: "%.2f", transaction.amount)) at \(transaction.storeName)\n"
        }
        
        return formatted
    }
    
    // MARK: - Send Request to Anthropic (Streaming)
    private func streamRequest(systemPrompt: String, messages: [AnthropicMessage], onChunk: @escaping (String) -> Void) async throws {
        // Check API key validity
        guard AppConfiguration.isAPIKeyValid else {
            throw AnthropicError.invalidAPIKey
        }
        
        guard let url = URL(string: apiURL) else {
            throw AnthropicError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "stream": true
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AnthropicError.invalidAPIKey
            }
            throw AnthropicError.apiError(statusCode: httpResponse.statusCode, message: "Stream request failed")
        }
        
        for try await line in bytes.lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    break
                }
                
                if let data = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let type = json["type"] as? String,
                   type == "content_block_delta",
                   let delta = json["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    onChunk(text)
                }
            }
        }
    }
    
    // MARK: - Send Request to Anthropic (Non-Streaming)
    private func sendRequest(systemPrompt: String, messages: [AnthropicMessage]) async throws -> String {
        // Check API key validity
        guard AppConfiguration.isAPIKeyValid else {
            throw AnthropicError.invalidAPIKey
        }
        
        guard let url = URL(string: apiURL) else {
            throw AnthropicError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": "claude-sonnet-4-5-20250929",
            "max_tokens": 2048,
            "system": systemPrompt,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 {
                throw AnthropicError.invalidAPIKey
            }
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AnthropicError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        
        guard let firstContent = anthropicResponse.content.first else {
            throw AnthropicError.emptyResponse
        }
        
        return firstContent.text
    }
}
