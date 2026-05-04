//
//  WalletAPIError.swift
//  Scandalicious
//
//  Shared error enum for the wallet/withdrawal API surface.
//

import Foundation

enum WalletAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case noAuthToken
    case decodingError(String)
    case serverError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .unauthorized: return "Authentication required"
        case .noAuthToken: return "No auth token available"
        case .decodingError(let msg): return "Decoding error: \(msg)"
        case .serverError(let msg): return msg
        case .networkError(let err): return err.localizedDescription
        }
    }
}
