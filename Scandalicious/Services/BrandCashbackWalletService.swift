//
//  BrandCashbackWalletService.swift
//  Scandalicious
//
//  Read-only client for /api/v2/brand-cashback/wallet.
//

import Foundation
import FirebaseAuth

actor BrandCashbackWalletService {
    static let shared = BrandCashbackWalletService()

    private var baseURL: String { AppConfiguration.apiBase }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private init() {}

    func fetchWallet(earningsLimit: Int = 50) async throws -> BrandCashbackWallet {
        guard var components = URLComponents(string: "\(baseURL)/brand-cashback/wallet") else {
            throw WalletAPIError.invalidURL
        }
        components.queryItems = [URLQueryItem(name: "earnings_limit", value: String(earningsLimit))]
        guard let url = components.url else { throw WalletAPIError.invalidURL }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw WalletAPIError.invalidResponse
            }
            switch http.statusCode {
            case 200...299:
                do { return try decoder.decode(BrandCashbackWallet.self, from: data) }
                catch { throw WalletAPIError.decodingError(error.localizedDescription) }
            case 401:
                throw WalletAPIError.unauthorized
            case 400...499:
                throw WalletAPIError.serverError("Client error: \(http.statusCode)")
            default:
                throw WalletAPIError.serverError("Server error: \(http.statusCode)")
            }
        } catch let error as WalletAPIError {
            throw error
        } catch {
            throw WalletAPIError.networkError(error)
        }
    }

    nonisolated func getWallet(earningsLimit: Int = 50) async throws -> BrandCashbackWallet {
        return try await fetchWallet(earningsLimit: earningsLimit)
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw WalletAPIError.noAuthToken
        }
        return try await user.getIDToken()
    }
}
