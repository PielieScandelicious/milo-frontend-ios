//
//  ReceiptUploadService.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import UIKit
import FirebaseAuth

enum ReceiptUploadError: LocalizedError {
    case noImage
    case invalidResponse
    case noAuthToken
    case serverError(String)
    case networkError(Error)
    
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
        }
    }
}

actor ReceiptUploadService {
    static let shared = ReceiptUploadService()
    
    private let baseURL = "https://scandalicious-api-production.up.railway.app/api/v1"
    
    private init() {}
    
    // MARK: - Upload Receipt
    
    func uploadReceipt(image: UIImage) async throws -> ReceiptUploadResponse {
        // Get auth token (from Firebase or shared storage)
        let idToken = try await getAuthToken()
        
        // Convert image to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw ReceiptUploadError.noImage
        }
        
        // Create multipart form data
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
        
        // Set timeout for upload
        request.timeoutInterval = 60
        
        // Perform upload
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReceiptUploadError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - parse response
                
                // Print raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Raw server response (image upload):\n\(jsonString)")
                }
                
                do {
                    let uploadResponse = try await decodeResponse(from: data)
                    
                    // Debug: Print parsed response
                    print("✅ Successfully parsed response:")
                    print("   Receipt ID: \(uploadResponse.receiptId)")
                    print("   Status: \(uploadResponse.status.rawValue)")
                    print("   Store: \(uploadResponse.storeName ?? "N/A")")
                    print("   Items Count: \(uploadResponse.itemsCount)")
                    print("   Transactions count: \(uploadResponse.transactions.count)")
                    print("   Transaction details:")
                    for (index, transaction) in uploadResponse.transactions.enumerated() {
                        print("      [\(index)] \(transaction.itemName) - €\(transaction.itemPrice) x\(transaction.quantity)")
                    }
                    
                    // Check if the receipt processing failed
                    if uploadResponse.status == .failed {
                        throw ReceiptUploadError.serverError("Receipt processing failed")
                    }
                    
                    return uploadResponse
                } catch let decodingError as DecodingError {
                    print("❌ Decoding error: \(decodingError)")
                    // Print raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 Raw server response:\n\(jsonString)")
                    }
                    
                    // Detailed decoding error information
                    switch decodingError {
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
                    
                    throw ReceiptUploadError.invalidResponse
                }
                
            case 400...499:
                // Client error
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] ?? errorMessage["message"] {
                    throw ReceiptUploadError.serverError(message)
                }
                throw ReceiptUploadError.serverError("Client error: \(httpResponse.statusCode)")
                
            case 500...599:
                // Server error
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
    
    // MARK: - Upload PDF Receipt
    
    func uploadPDFReceipt(from pdfURL: URL) async throws -> ReceiptUploadResponse {
        // Get auth token (from Firebase or shared storage)
        let idToken = try await getAuthToken()
        
        // Read PDF data
        let pdfData = try Data(contentsOf: pdfURL)
        
        // Create multipart form data
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
        
        // Set timeout for upload
        request.timeoutInterval = 60
        
        // Perform upload
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Check HTTP status
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReceiptUploadError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                // Success - parse response
                
                // Print raw JSON for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Raw server response (PDF upload):\n\(jsonString)")
                }
                
                do {
                    let uploadResponse = try await decodeResponse(from: data)
                    
                    // Debug: Print parsed response
                    print("✅ Successfully parsed response:")
                    print("   Receipt ID: \(uploadResponse.receiptId)")
                    print("   Status: \(uploadResponse.status.rawValue)")
                    print("   Store: \(uploadResponse.storeName ?? "N/A")")
                    print("   Items Count: \(uploadResponse.itemsCount)")
                    print("   Transactions count: \(uploadResponse.transactions.count)")
                    print("   Transaction details:")
                    for (index, transaction) in uploadResponse.transactions.enumerated() {
                        print("      [\(index)] \(transaction.itemName) - €\(transaction.itemPrice) x\(transaction.quantity)")
                    }
                    
                    // Check if the receipt processing failed
                    if uploadResponse.status == .failed {
                        throw ReceiptUploadError.serverError("Receipt processing failed")
                    }
                    
                    return uploadResponse
                } catch let decodingError as DecodingError {
                    print("❌ Decoding error: \(decodingError)")
                    // Print raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 Raw server response:\n\(jsonString)")
                    }
                    
                    // Detailed decoding error information
                    switch decodingError {
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
                    
                    throw ReceiptUploadError.invalidResponse
                }
                
            case 400...499:
                // Client error
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] ?? errorMessage["message"] {
                    throw ReceiptUploadError.serverError(message)
                }
                throw ReceiptUploadError.serverError("Client error: \(httpResponse.statusCode)")
                
            case 500...599:
                // Server error
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
}

// MARK: - Data Extension for Multipart Form Data

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

