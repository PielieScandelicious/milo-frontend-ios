//
//  ProfileAPIService.swift
//  Scandalicious
//
//  Created by Claude on 23/01/2026.
//

import Foundation
import FirebaseAuth

actor ProfileAPIService {
    private var baseURL: String { AppConfiguration.apiBase }

    enum ProfileError: LocalizedError {
        case unauthorized
        case notFound
        case invalidResponse
        case serverError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "You must be signed in to access your profile"
            case .notFound:
                return "Profile not found"
            case .invalidResponse:
                return "Invalid response from server"
            case .serverError(let message):
                return message
            case .networkError(let error):
                return error.localizedDescription
            }
        }
    }

    // MARK: - Get Profile

    func getProfile() async throws -> UserProfile {
        guard let token = try await getFirebaseToken() else {
            throw ProfileError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/profile") else {
            throw ProfileError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                return try decoder.decode(UserProfile.self, from: data)
            case 404:
                throw ProfileError.notFound
            case 401:
                throw ProfileError.unauthorized
            case 400..<500:
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] {
                    throw ProfileError.serverError(message)
                }
                throw ProfileError.invalidResponse
            default:
                throw ProfileError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.networkError(error)
        }
    }

    // MARK: - Create or Update Profile

    func updateProfile(nickname: String?, gender: String?, age: Int?, language: String?) async throws -> UserProfile {
        guard let token = try await getFirebaseToken() else {
            throw ProfileError.unauthorized
        }

        guard let url = URL(string: "\(baseURL)/profile") else {
            throw ProfileError.invalidResponse
        }

        let profileUpdate = UserProfileUpdate(
            nickname: nickname,
            gender: gender,
            age: age,
            language: language
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(profileUpdate)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ProfileError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200, 201:
                let decoder = JSONDecoder()
                return try decoder.decode(UserProfile.self, from: data)
            case 401:
                throw ProfileError.unauthorized
            case 400..<500:
                if let errorMessage = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorMessage["error"] {
                    throw ProfileError.serverError(message)
                }
                throw ProfileError.invalidResponse
            default:
                throw ProfileError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as ProfileError {
            throw error
        } catch {
            throw ProfileError.networkError(error)
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
