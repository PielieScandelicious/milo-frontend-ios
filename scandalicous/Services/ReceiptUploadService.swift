//
//  ReceiptUploadService.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import UIKit
#if !SHARE_EXTENSION
import FirebaseAuth
#endif

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
        #if SHARE_EXTENSION
        // In Share Extension: Read from shared keychain/user defaults
        // First, try to read from App Group UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: "group.com.deepmaind.scandalicious"),
           let token = sharedDefaults.string(forKey: "firebase_auth_token") {
            return token
        }
        
        // If not found, throw error
        throw ReceiptUploadError.noAuthToken
        #else
        // In Main App: Use Firebase Auth
        guard let user = Auth.auth().currentUser else {
            throw ReceiptUploadError.noAuthToken
        }
        
        let token = try await user.getIDToken()
        
        // Save to shared storage for extension to use
        if let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.scandalicious") {
            sharedDefaults.set(token, forKey: "firebase_auth_token")
        }
        
        return token
        #endif
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

