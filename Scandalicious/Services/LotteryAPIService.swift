//
//  LotteryAPIService.swift
//  Scandalicious
//
//  Created by Claude on 10/03/2026.
//

import Foundation
import FirebaseAuth

actor LotteryAPIService {
    private var baseURL: String { AppConfiguration.apiBase }

    enum LotteryError: LocalizedError {
        case unauthorized
        case notFound
        case invalidResponse
        case serverError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "You must be signed in to access lottery status"
            case .notFound:
                return "Lottery status not found"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let message):
                return message
            case .networkError(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - Get Lottery Status

    func getLotteryStatus() async throws -> LotteryStatus {
        guard let token = try await getFirebaseToken() else {
            throw LotteryError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/lottery/status") else {
            throw LotteryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw LotteryError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                return try decoder.decode(LotteryStatus.self, from: data)
            case 404:
                throw LotteryError.notFound
            case 401:
                throw LotteryError.unauthorized
            case 400..<500:
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] {
                    throw LotteryError.serverError(message)
                }
                throw LotteryError.invalidResponse
            default:
                throw LotteryError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as LotteryError {
            throw error
        } catch {
            throw LotteryError.networkError(error)
        }
    }

    // MARK: - Declare Share

    func declareShare() async throws {
        guard let token = try await getFirebaseToken() else {
            throw LotteryError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/lottery/declare-share") else {
            throw LotteryError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw LotteryError.serverError("Failed to declare share")
            }
        } catch let error as LotteryError {
            throw error
        } catch {
            throw LotteryError.networkError(error)
        }
    }

    // MARK: - Helper Methods

    private func getFirebaseToken() async throws -> String? {
        guard let user = Auth.auth().currentUser else {
            return nil
        }
        return try await user.getIDToken()
    }
}
