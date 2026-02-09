//
//  PromoAPIService.swift
//  Scandalicious
//
//  Created by Claude on 09/02/2026.
//

import Foundation
import FirebaseAuth

actor PromoAPIService {
    static let shared = PromoAPIService()

    private var baseURL: String { AppConfiguration.apiBase }

    enum PromoError: LocalizedError {
        case unauthorized
        case notFound
        case serviceUnavailable
        case invalidResponse
        case serverError(String)
        case decodingError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "You must be signed in to view deals"
            case .notFound:
                return "Keep scanning receipts to unlock personalized deals"
            case .serviceUnavailable:
                return "Deals service is temporarily unavailable"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let message):
                return message
            case .decodingError(let message):
                return "Failed to parse deals: \(message)"
            case .networkError(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - Fetch Promos

    func getRecommendations() async throws -> PromoRecommendationResponse {
        guard let token = try await getFirebaseToken() else {
            throw PromoError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/promos") else {
            throw PromoError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120  // Pinecone search + Gemini generation is slow

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PromoError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                do {
                    let decoder = JSONDecoder()
                    return try decoder.decode(PromoRecommendationResponse.self, from: data)
                } catch {
                    throw PromoError.decodingError(error.localizedDescription)
                }
            case 401:
                throw PromoError.unauthorized
            case 404:
                throw PromoError.notFound
            case 503:
                throw PromoError.serviceUnavailable
            case 400..<500:
                if let errorDict = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorDict["detail"] ?? errorDict["error"] {
                    throw PromoError.serverError(message)
                }
                throw PromoError.invalidResponse
            default:
                throw PromoError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as PromoError {
            throw error
        } catch {
            throw PromoError.networkError(error)
        }
    }

    // MARK: - Helper

    private func getFirebaseToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else {
            return nil
        }
        return try await user.getIDToken()
    }
}
