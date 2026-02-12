//
//  WalletPassService.swift
//  Scandalicious
//
//  Service for creating Apple Wallet loyalty passes
//

import Foundation
import UIKit
import PassKit
import SwiftUI

// MARK: - API Request/Response Models

struct WalletPassCreateRequest: Codable, Sendable {
    let storeName: String
    let barcodeValue: String
    let barcodeFormat: String
    let backgroundColor: ColorComponents
    let foregroundColor: ColorComponents
    let labelColor: ColorComponents
    let logoBase64: String?

    enum CodingKeys: String, CodingKey {
        case storeName = "store_name"
        case barcodeValue = "barcode_value"
        case barcodeFormat = "barcode_format"
        case backgroundColor = "background_color"
        case foregroundColor = "foreground_color"
        case labelColor = "label_color"
        case logoBase64 = "logo_base64"
    }
}

struct ColorComponents: Codable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
}

struct WalletPassCreateResponse: Codable, Sendable {
    let success: Bool
    let passData: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case success
        case passData = "pass_data"
        case error
    }
}

// MARK: - Wallet Pass Service

class WalletPassService {
    static let shared = WalletPassService()

    private init() {}

    // MARK: - Check PassKit Availability

    func canAddPasses() -> Bool {
        return PKPassLibrary.isPassLibraryAvailable() && PKAddPassesViewController.canAddPasses()
    }

    // MARK: - Create Pass via Backend

    func createPass(request: WalletPassCreateRequest, authToken: String) async throws -> Data {
        let baseURL = AppConfiguration.apiBase
        guard let url = URL(string: "\(baseURL)/wallet-pass/create") else {
            throw WalletPassError.invalidURL
        }

        // Create HTTP request
        var httpRequest = URLRequest(url: url)
        httpRequest.httpMethod = "POST"
        httpRequest.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        httpRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        httpRequest.httpBody = try encoder.encode(request)

        // Make request
        let (data, response) = try await URLSession.shared.data(for: httpRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WalletPassError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(WalletPassCreateResponse.self, from: data) {
                throw WalletPassError.signingFailed(errorResponse.error ?? "Server error")
            }
            throw WalletPassError.signingFailed("Server returned status \(httpResponse.statusCode)")
        }

        // Parse response
        let decoder = JSONDecoder()
        let passResponse = try decoder.decode(WalletPassCreateResponse.self, from: data)

        guard passResponse.success, let passBase64 = passResponse.passData else {
            throw WalletPassError.signingFailed(passResponse.error ?? "Failed to create pass")
        }

        // Decode base64 pass data
        guard let passDataBytes = Data(base64Encoded: passBase64) else {
            throw WalletPassError.passCreationFailed
        }

        return passDataBytes
    }

    // MARK: - Load Pass from Data

    func loadPass(from data: Data) throws -> PKPass {
        return try PKPass(data: data)
    }

    // MARK: - Check if Pass Already Exists

    func passExists(withSerialNumber serialNumber: String, passTypeIdentifier: String) -> Bool {
        let library = PKPassLibrary()
        let passes = library.passes()

        return passes.contains { pass in
            pass.serialNumber == serialNumber && pass.passTypeIdentifier == passTypeIdentifier
        }
    }
}

// MARK: - Errors

enum WalletPassError: LocalizedError {
    case invalidURL
    case invalidResponse
    case signingFailed(String)
    case passCreationFailed
    case cannotAddPasses
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid service URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .signingFailed(let message):
            return message
        case .passCreationFailed:
            return "Failed to create pass"
        case .cannotAddPasses:
            return "This device cannot add passes to Wallet"
        case .notConfigured:
            return "Apple Wallet integration is not yet configured"
        }
    }
}

// MARK: - Color Extension

extension Color {
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
    }
}
