//
//  AnthropicService.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation

// MARK: - Category Definitions
enum TransactionCategory: String, CaseIterable, Codable {
    case meatFish = "Meat & Fish"
    case alcohol = "Alcohol"
    case drinks = "Drinks (Soft/Soda)"
    case drinksWater = "Drinks (Water)"
    case household = "Household"
    case snacksSweets = "Snacks & Sweets"
    case freshProduce = "Fresh Produce"
    case dairyEggs = "Dairy & Eggs"
    case readyMeals = "Ready Meals"
    case bakery = "Bakery"
    case pantry = "Pantry"
    case personalCare = "Personal Care"
    case others = "Others"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - Receipt Item
struct ReceiptItem: Codable {
    let itemName: String
    let quantity: Int
    let amount: Double
    let category: String
}

// MARK: - Anthropic Request/Response Models
struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

struct AnthropicRequest: Codable {
    let model: String
    let maxTokens: Int
    let messages: [AnthropicMessage]
    
    enum CodingKeys: String, CodingKey {
        case model
        case maxTokens = "max_tokens"
        case messages
    }
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

// MARK: - Categorization Response
struct CategorizationResponse: Codable {
    let items: [CategorizedItem]
    
    struct CategorizedItem: Codable {
        let itemName: String
        let category: String
        let quantity: Int
        let amount: Double
    }
}

// MARK: - Anthropic Service
actor AnthropicService {
    static let shared = AnthropicService()
    
    private let apiKey: String
    private let apiURL = "https://api.anthropic.com/v1/messages"
    
    private init() {
        self.apiKey = AppConfiguration.anthropicAPIKey
    }
    
    // MARK: - Categorize Receipt Items
    func categorizeReceiptItems(_ receiptText: String) async throws -> CategorizationResponse {
        let prompt = buildCategorizationPrompt(receiptText: receiptText)
        let response = try await sendRequest(prompt: prompt)
        return try parseCategorizationResponse(response)
    }
    
    // MARK: - Build Prompt
    private func buildCategorizationPrompt(receiptText: String) -> String {
        let categories = TransactionCategory.allCases.map { $0.rawValue }.joined(separator: ", ")
        
        return """
        Analyze this receipt and categorize each item into one of the following categories:
        \(categories)
        
        If an item doesn't fit into any of these categories, use "Others".
        
        Receipt text:
        \(receiptText)
        
        Return your response as a JSON object with the following structure:
        {
            "items": [
                {
                    "itemName": "Item name",
                    "category": "Category name",
                    "quantity": 1,
                    "amount": 0.00
                }
            ]
        }
        
        Important:
        - Extract the exact item name from the receipt
        - Assign the most appropriate category from the list above
        - Include the quantity (default to 1 if not specified)
        - Include the price as a decimal number
        - Respond ONLY with the JSON object, no additional text
        """
    }
    
    // MARK: - Send Request to Anthropic
    private func sendRequest(prompt: String) async throws -> String {
        guard let url = URL(string: apiURL) else {
            throw AnthropicError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let anthropicRequest = AnthropicRequest(
            model: "claude-3-5-sonnet-20241022",
            maxTokens: 4096,
            messages: [
                AnthropicMessage(role: "user", content: prompt)
            ]
        )
        
        request.httpBody = try JSONEncoder().encode(anthropicRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnthropicError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AnthropicError.apiError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        
        guard let firstContent = anthropicResponse.content.first else {
            throw AnthropicError.emptyResponse
        }
        
        return firstContent.text
    }
    
    // MARK: - Parse Response
    private func parseCategorizationResponse(_ responseText: String) throws -> CategorizationResponse {
        // Clean the response text to extract JSON
        var jsonText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if jsonText.hasPrefix("```json") {
            jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
        }
        if jsonText.hasPrefix("```") {
            jsonText = jsonText.replacingOccurrences(of: "```", with: "")
        }
        if jsonText.hasSuffix("```") {
            jsonText = String(jsonText.dropLast(3))
        }
        
        jsonText = jsonText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonText.data(using: .utf8) else {
            throw AnthropicError.invalidJSON
        }
        
        do {
            return try JSONDecoder().decode(CategorizationResponse.self, from: jsonData)
        } catch {
            throw AnthropicError.parsingError(error)
        }
    }
}

// MARK: - Anthropic Errors
enum AnthropicError: LocalizedError {
    case invalidURL
    case invalidResponse
    case emptyResponse
    case invalidJSON
    case parsingError(Error)
    case apiError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from API"
        case .emptyResponse:
            return "Empty response from API"
        case .invalidJSON:
            return "Could not parse JSON response"
        case .parsingError(let error):
            return "Parsing error: \(error.localizedDescription)"
        case .apiError(let statusCode, let message):
            return "API error (\(statusCode)): \(message)"
        }
    }
}
