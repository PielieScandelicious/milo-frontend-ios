//
//  ReceiptImportService.swift
//  Dobby
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import Foundation
import UIKit
import Vision

// MARK: - Store Detection
enum SupportedStore: String, CaseIterable {
    case aldi = "ALDI"
    case colruyt = "COLRUYT"
    case delhaize = "DELHAIZE"
    case carrefour = "CARREFOUR"
    case lidl = "LIDL"
    case unknown = "Unknown Store"
    
    var displayName: String {
        return self.rawValue
    }
    
    // Store detection keywords
    var keywords: [String] {
        switch self {
        case .aldi:
            return ["aldi", "aldi nord", "aldi süd"]
        case .colruyt:
            return ["colruyt", "okay", "bio-planet"]
        case .delhaize:
            return ["delhaize", "ad delhaize", "proxy delhaize"]
        case .carrefour:
            return ["carrefour", "carrefour express", "carrefour market"]
        case .lidl:
            return ["lidl"]
        case .unknown:
            return []
        }
    }
}

// MARK: - Receipt Import Result
struct ReceiptImportResult: Identifiable {
    let id = UUID()
    let storeName: String
    let receiptText: String
    let detectedStore: SupportedStore
    let date: Date
    let transactions: [Transaction]
}

// MARK: - Receipt Categorization Models (Backend Response)
struct ReceiptCategorizationResult: Codable {
    let items: [CategorizedItem]
}

struct CategorizedItem: Codable {
    let itemName: String
    let category: String
    let amount: Double
    let quantity: Int
}

// MARK: - Receipt Import Service
actor ReceiptImportService {
    static let shared = ReceiptImportService()
    
    private init() {}
    
    // MARK: - Import Receipt from Text
    func importReceipt(from text: String) async throws -> ReceiptImportResult {
        // Detect store
        let detectedStore = detectStore(from: text)
        
        // Extract date from receipt (or use current date)
        let receiptDate = extractDate(from: text) ?? Date()
        
        // Process receipt using backend API
        let categorization = try await processReceiptWithBackend(text: text)
        
        // Convert to transactions
        let transactions = categorization.items.map { item in
            Transaction(
                id: UUID(),
                storeName: detectedStore.rawValue,
                category: item.category,
                itemName: item.itemName,
                amount: item.amount,
                date: receiptDate,
                quantity: item.quantity,
                paymentMethod: "Unknown"
            )
        }
        
        return ReceiptImportResult(
            storeName: detectedStore.rawValue,
            receiptText: text,
            detectedStore: detectedStore,
            date: receiptDate,
            transactions: transactions
        )
    }
    
    // MARK: - Process Receipt with Backend API
    private func processReceiptWithBackend(text: String) async throws -> ReceiptCategorizationResult {
        guard let url = URL(string: AppConfiguration.processReceiptEndpoint) else {
            throw ReceiptImportError.invalidReceiptFormat
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "text": text
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptImportError.invalidReceiptFormat
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ReceiptImportError.invalidReceiptFormat
        }
        
        let categorization = try JSONDecoder().decode(ReceiptCategorizationResult.self, from: data)
        return categorization
    }
    
    // MARK: - Import Receipt from Image
    func importReceipt(from image: UIImage) async throws -> ReceiptImportResult {
        // Extract text from image using Vision
        let text = try await extractText(from: image)
        
        // Import using the text
        return try await importReceipt(from: text)
    }
    
    // MARK: - Extract Text from Image
    private func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw ReceiptImportError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: ReceiptImportError.textRecognitionFailed)
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Detect Store
    private func detectStore(from text: String) -> SupportedStore {
        let lowercasedText = text.lowercased()
        
        for store in SupportedStore.allCases where store != .unknown {
            for keyword in store.keywords {
                if lowercasedText.contains(keyword.lowercased()) {
                    return store
                }
            }
        }
        
        return .unknown
    }
    
    // MARK: - Extract Date
    private func extractDate(from text: String) -> Date? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        
        if let match = matches?.first, let date = match.date {
            return date
        }
        
        return nil
    }
}

// MARK: - Receipt Import Errors
enum ReceiptImportError: LocalizedError {
    case invalidImage
    case textRecognitionFailed
    case noItemsFound
    case invalidReceiptFormat
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image format"
        case .textRecognitionFailed:
            return "Failed to extract text from image"
        case .noItemsFound:
            return "No items found on receipt"
        case .invalidReceiptFormat:
            return "Receipt format not recognized"
        }
    }
}
