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

// MARK: - Upload Result

enum UploadResult: Sendable {
    case accepted(ReceiptUploadAcceptedResponse)  // HTTP 202 — async processing
    case completed(ReceiptUploadResponse)          // HTTP 200 — legacy synchronous
}

actor ReceiptUploadService {
    static let shared = ReceiptUploadService()

    private var baseURL: String { AppConfiguration.apiBase }
    private var uploadURL: String { AppConfiguration.receiptUploadEndpoint }

    private init() {}

    // MARK: - Upload Receipt

    func uploadReceipt(image: UIImage) async throws -> UploadResult {
        // Get auth token
        let idToken = try await getAuthToken()

        // Convert image to JPEG without compression
        guard let imageData = image.jpegData(compressionQuality: 1.0) else {
            throw ReceiptUploadError.noImage
        }

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
        guard let url = URL(string: uploadURL) else {
            throw ReceiptUploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 30 // Fast — backend returns 202 immediately

        // Use shared upload logic
        return try await performUpload(request: request)
    }

    // MARK: - Upload PDF Receipt

    func uploadPDFReceipt(from pdfURL: URL) async throws -> UploadResult {
        // Get auth token
        let idToken = try await getAuthToken()

        // Read PDF data
        let pdfData = try Data(contentsOf: pdfURL)

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
        guard let url = URL(string: uploadURL) else {
            throw ReceiptUploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = body
        request.timeoutInterval = 30

        // Perform upload (reuse same logic as image upload)
        return try await performUpload(request: request)
    }

    // MARK: - Delete Receipt

    func deleteReceipt(receiptId: String) async throws {
        // Get auth token
        let idToken = try await getAuthToken()

        // Create request
        guard let url = URL(string: "\(baseURL)/receipts/\(receiptId)") else {
            throw ReceiptUploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReceiptUploadError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return

            case 401:
                throw ReceiptUploadError.noAuthToken

            case 404:
                throw ReceiptUploadError.deleteFailed("Receipt not found")

            case 400...499:
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] ?? errorMessage["message"] {
                    throw ReceiptUploadError.deleteFailed(message)
                }
                throw ReceiptUploadError.deleteFailed("Client error: \(httpResponse.statusCode)")

            case 500...599:
                throw ReceiptUploadError.deleteFailed("Server error: \(httpResponse.statusCode)")

            default:
                throw ReceiptUploadError.deleteFailed("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch let error as ReceiptUploadError {
            throw error
        } catch {
            throw ReceiptUploadError.networkError(error)
        }
    }

    // MARK: - Get Receipt Status (Polling)

    func getReceiptStatus(receiptId: String) async throws -> ReceiptStatusResponse {
        let idToken = try await getAuthToken()

        guard let url = URL(string: "\(baseURL)/receipts/\(receiptId)/status") else {
            throw ReceiptUploadError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ReceiptUploadError.invalidResponse
        }

        return try JSONDecoder().decode(ReceiptStatusResponse.self, from: data)
    }

    // MARK: - Shared Upload Logic

    private func performUpload(request: URLRequest) async throws -> UploadResult {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReceiptUploadError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 202:
                // Async processing — backend accepted the receipt
                do {
                    let accepted = try JSONDecoder().decode(
                        ReceiptUploadAcceptedResponse.self, from: data
                    )
                    return .accepted(accepted)
                } catch {
                    throw ReceiptUploadError.invalidResponse
                }

            case 200...201, 203...299:
                // Legacy synchronous response
                do {
                    let uploadResponse = try await decodeResponse(from: data)

                    if uploadResponse.status == .failed {
                        throw ReceiptUploadError.serverError("Receipt processing failed")
                    }

                    return .completed(uploadResponse)
                } catch let decodingError as DecodingError {
                    logDecodingError(decodingError)
                    throw ReceiptUploadError.invalidResponse
                }

            case 429:
                // Rate limit exceeded
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .iso8601
                    let rateLimitError = try decoder.decode(ReceiptRateLimitExceededError.self, from: data)
                    throw ReceiptUploadError.rateLimitExceeded(rateLimitError)
                } catch let error as ReceiptUploadError {
                    throw error
                } catch {
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

                // Also save to shared storage for faster future access
                KeychainHelper.shared.saveToken(token)
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    sharedDefaults.set(token, forKey: "firebase_auth_token")
                }

                return token
            } catch {
                // Fall through to try other methods
            }
        }

        // Method 2: Try Keychain (most reliable for sharing)
        if let token = KeychainHelper.shared.retrieveToken() {
            return token
        }

        // Method 3: Try to read from shared App Group UserDefaults (obvious key first)
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let token = sharedDefaults.string(forKey: "SCANDALICIOUS_AUTH_TOKEN") {
            return token
        }

        // Method 4: Try primary key
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let token = sharedDefaults.string(forKey: "firebase_auth_token") {
            return token
        }

        // Method 5: Try alternative key
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
           let token = sharedDefaults.string(forKey: "auth_token") {
            return token
        }

        // If all methods fail, throw error
        throw ReceiptUploadError.noAuthToken
    }

    // MARK: - Decode Response

    private func decodeResponse(from data: Data) async throws -> ReceiptUploadResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ReceiptUploadResponse.self, from: data)
    }

    // MARK: - Logging Helpers

    private func logDecodingError(_ error: DecodingError) {
        // Decoding error logging disabled for production
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
