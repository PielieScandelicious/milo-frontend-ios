//
//  ReceiptUploadService.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import UIKit
import FirebaseAuth

// MARK: - Receipt Rate Limit Error

struct ReceiptRateLimitExceededError: Codable, Error {
    let error: String
    let message: String
    let details: ReceiptRateLimitDetails

    struct ReceiptRateLimitDetails: Codable {
        let receiptsUsed: Int
        let receiptsLimit: Int
        let periodEndDate: Date
        let retryAfterSeconds: Int

        enum CodingKeys: String, CodingKey {
            case receiptsUsed = "receipts_used"
            case receiptsLimit = "receipts_limit"
            case periodEndDate = "period_end_date"
            case retryAfterSeconds = "retry_after_seconds"
        }
    }
}

// MARK: - Receipt Upload Error

enum ReceiptUploadError: LocalizedError {
    case noImage
    case invalidResponse
    case noAuthToken
    case serverError(String)
    case networkError(Error)
    case rateLimitExceeded(ReceiptRateLimitExceededError)
    case deleteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "No image provided"
        case .invalidResponse:
            return "Invalid server response"
        case .noAuthToken:
            return "Not authenticated"
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded(let error):
            return error.message
        case .deleteFailed(let message):
            return "Failed to delete receipt: \(message)"
        }
    }

    /// User-friendly message for rate limit exceeded
    var rateLimitUserMessage: String? {
        guard case .rateLimitExceeded(let error) = self else { return nil }
        let daysUntilReset = Calendar.current.dateComponents([.day], from: Date(), to: error.details.periodEndDate).day ?? 0
        if daysUntilReset > 0 {
            return "You've used all \(error.details.receiptsLimit) receipt uploads this month. Your limit resets in \(daysUntilReset) day\(daysUntilReset == 1 ? "" : "s")."
        } else {
            return "You've used all \(error.details.receiptsLimit) receipt uploads this month. Your limit resets soon."
        }
    }
}

actor ReceiptUploadService {
    static let shared = ReceiptUploadService()
    
    private let baseURL = "https://scandalicious-api-production.up.railway.app/api/v3"
    
    private init() {}
    
    // MARK: - Upload Receipt
    
    func uploadReceipt(image: UIImage) async throws -> ReceiptUploadResponse {
        print("🚀 Starting receipt upload process")

        // Get auth token
        let idToken = try await getAuthToken()

        // Convert image to JPEG without compression
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            throw ReceiptUploadError.noImage
        }

        print("📦 Image size: \(imageData.count / 1024)KB")
        
        // Create multipart form data for SINGLE receipt upload
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add image data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        guard let url = URL(string: "\(baseURL)/receipts/upload") else {
            throw ReceiptUploadError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 90 // Increased timeout for Claude Vision API processing
        
        // Use shared upload logic
        return try await performUpload(request: request)
    }
    
    // MARK: - Upload PDF Receipt
    
    func uploadPDFReceipt(from pdfURL: URL) async throws -> ReceiptUploadResponse {
        print("🚀 Starting PDF receipt upload process")
        
        // Get auth token
        let idToken = try await getAuthToken()
        
        // Read PDF data
        let pdfData = try Data(contentsOf: pdfURL)
        print("📦 PDF size: \(pdfData.count / 1024)KB")
        
        // Create multipart form data for SINGLE PDF receipt upload
        let boundary = UUID().uuidString
        var body = Data()
        
        // Add PDF data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.pdf\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/pdf\r\n\r\n".data(using: .utf8)!)
        body.append(pdfData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        // Create request
        guard let url = URL(string: "\(baseURL)/receipts/upload") else {
            throw ReceiptUploadError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 90
        
        // Perform upload (reuse same logic as image upload)
        return try await performUpload(request: request)
    }
    
    // MARK: - Delete Receipt

    func deleteReceipt(receiptId: String) async throws {
        print("🗑️ Starting receipt deletion for ID: \(receiptId)")

        // Get auth token
        let idToken = try await getAuthToken()
        print("✅ Got auth token for deletion (length: \(idToken.count))")

        // Create request
        guard let url = URL(string: "\(baseURL)/receipts/\(receiptId)") else {
            print("❌ Failed to create URL for receipt deletion")
            throw ReceiptUploadError.invalidResponse
        }

        print("📡 DELETE URL: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw ReceiptUploadError.invalidResponse
            }

            print("📥 Delete response: HTTP \(httpResponse.statusCode)")

            // Log response data for debugging
            if let responseString = String(data: data, encoding: .utf8), !responseString.isEmpty {
                print("📄 Delete response body: \(responseString)")
            }

            switch httpResponse.statusCode {
            case 200...299:
                print("✅ Receipt deleted successfully")
                return

            case 401:
                print("❌ Authentication failed (401)")
                throw ReceiptUploadError.noAuthToken

            case 404:
                print("❌ Receipt not found (404)")
                throw ReceiptUploadError.deleteFailed("Receipt not found")

            case 400...499:
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] ?? errorMessage["message"] {
                    print("❌ Client error: \(message)")
                    throw ReceiptUploadError.deleteFailed(message)
                }
                print("❌ Client error: \(httpResponse.statusCode)")
                throw ReceiptUploadError.deleteFailed("Client error: \(httpResponse.statusCode)")

            case 500...599:
                print("❌ Server error: \(httpResponse.statusCode)")
                throw ReceiptUploadError.deleteFailed("Server error: \(httpResponse.statusCode)")

            default:
                print("❌ Unexpected status code: \(httpResponse.statusCode)")
                throw ReceiptUploadError.deleteFailed("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch let error as ReceiptUploadError {
            throw error
        } catch {
            print("❌ Network error during deletion: \(error.localizedDescription)")
            throw ReceiptUploadError.networkError(error)
        }
    }

    // MARK: - Shared Upload Logic

    private func performUpload(request: URLRequest) async throws -> ReceiptUploadResponse {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReceiptUploadError.invalidResponse
            }
            
            print("📥 Server response: HTTP \(httpResponse.statusCode)")
            
            switch httpResponse.statusCode {
            case 200...299:
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 Raw server response:\n\(jsonString)")
                }

                do {
                    let uploadResponse = try await decodeResponse(from: data)

                    print("✅ Successfully parsed response:")
                    print("   Receipt ID: \(uploadResponse.receiptId)")
                    print("   Status: \(uploadResponse.status.rawValue)")
                    print("   Items: \(uploadResponse.transactions.count)")

                    if uploadResponse.status == .failed {
                        throw ReceiptUploadError.serverError("Receipt processing failed")
                    }

                    return uploadResponse
                } catch let decodingError as DecodingError {
                    print("❌ Decoding error: \(decodingError)")
                    logDecodingError(decodingError)
                    throw ReceiptUploadError.invalidResponse
                }

            case 429:
                // Rate limit exceeded
                print("⚠️ Receipt upload rate limit exceeded")
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let rateLimitError = try decoder.decode(ReceiptRateLimitExceededError.self, from: data)
                    print("   Used: \(rateLimitError.details.receiptsUsed)/\(rateLimitError.details.receiptsLimit)")
                    throw ReceiptUploadError.rateLimitExceeded(rateLimitError)
                } catch let error as ReceiptUploadError {
                    throw error
                } catch {
                    print("❌ Failed to decode rate limit error: \(error)")
                    throw ReceiptUploadError.serverError("Upload limit exceeded. Please try again later.")
                }

            case 400...428, 430...499:
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] ?? errorMessage["message"] {
                    throw ReceiptUploadError.serverError(message)
                }
                throw ReceiptUploadError.serverError("Client error: \(httpResponse.statusCode)")
                
            case 500...599:
                throw ReceiptUploadError.serverError("Server error: \(httpResponse.statusCode)")
                
            default:
                throw ReceiptUploadError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch let error as ReceiptUploadError {
            throw error
        } catch {
            throw ReceiptUploadError.networkError(error)
        }
    }
    
    // MARK: - Get Auth Token
    
    private func getAuthToken() async throws -> String {
        // Use consistent App Group identifier
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        
        // Try method 1: Get directly from Firebase Auth (works if Firebase is configured in extension)
        if let user = Auth.auth().currentUser {
            do {
                let token = try await user.getIDToken()
                print("✅ Retrieved auth token directly from Firebase Auth")
                
                // Also save to shared storage for faster future access
                KeychainHelper.shared.saveToken(token)
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    sharedDefaults.set(token, forKey: "firebase_auth_token")
                }
                
                return token
            } catch {
                print("⚠️ Failed to get token from Firebase Auth: \(error.localizedDescription)")
                // Fall through to try other methods
            }
        } else {
            print("⚠️ No Firebase user found, trying shared storage...")
        }
        
        // Method 2: Try Keychain (most reliable for sharing)
        if let token = KeychainHelper.shared.retrieveToken() {
            print("✅ Retrieved auth token from Keychain")
            return token
        } else {
            print("⚠️ No token in Keychain, trying UserDefaults...")
        }
        
        // Method 3: Try to read from shared App Group UserDefaults (obvious key first)
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let token = sharedDefaults.string(forKey: "SCANDALICIOUS_AUTH_TOKEN") {
            print("✅ Retrieved auth token from shared UserDefaults (SCANDALICIOUS_AUTH_TOKEN)")
            return token
        }
        
        // Method 4: Try primary key
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let token = sharedDefaults.string(forKey: "firebase_auth_token") {
            print("✅ Retrieved auth token from shared UserDefaults (firebase_auth_token)")
            return token
        }
        
        // Method 5: Try alternative key
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let token = sharedDefaults.string(forKey: "auth_token") {
            print("✅ Retrieved auth token from UserDefaults (auth_token)")
            return token
        }
        
        // If all methods fail, throw error
        print("❌ No auth token found - tried all methods:")
        print("   1. Firebase Auth")
        print("   2. Keychain")
        print("   3. UserDefaults (firebase_auth_token)")
        print("   4. UserDefaults (auth_token)")
        print("   App Group: \(appGroupIdentifier)")
        
        // Debug: List all available keys in shared defaults
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let allKeys = sharedDefaults.dictionaryRepresentation().keys
            print("   Available keys in shared defaults: \(Array(allKeys))")
        } else {
            print("   ❌ Could not access shared UserDefaults!")
        }
        
        throw ReceiptUploadError.noAuthToken
    }
    
    // MARK: - Decode Response
    
    private func decodeResponse(from data: Data) async throws -> ReceiptUploadResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ReceiptUploadResponse.self, from: data)
    }
    
    // MARK: - Logging Helpers
    
    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .keyNotFound(let key, let context):
            print("🔑 Missing key '\(key.stringValue)' - \(context.debugDescription)")
            print("📍 Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .typeMismatch(let type, let context):
            print("⚠️ Type mismatch for type '\(type)' - \(context.debugDescription)")
            print("📍 Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .valueNotFound(let type, let context):
            print("❓ Value not found for type '\(type)' - \(context.debugDescription)")
            print("📍 Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .dataCorrupted(let context):
            print("💥 Data corrupted - \(context.debugDescription)")
            print("📍 Coding path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        @unknown default:
            print("❔ Unknown decoding error")
        }
    }
}

// MARK: - Data Extension for Multipart Form Data

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

