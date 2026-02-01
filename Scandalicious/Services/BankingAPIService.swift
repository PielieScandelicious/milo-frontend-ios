//
//  BankingAPIService.swift
//  Scandalicious
//
//  Created by Claude on 01/02/2026.
//

import Foundation
import FirebaseAuth

// MARK: - Banking API Errors

enum BankingAPIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case unauthorized
    case notFound
    case connectionExpired
    case serverError(String)
    case decodingError(String)
    case networkError(Error)
    case invalidResponse
    case syncInProgress

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noAuthToken:
            return "No authentication token available"
        case .unauthorized:
            return "Unauthorized - please sign in again"
        case .notFound:
            return "Resource not found"
        case .connectionExpired:
            return "Bank connection has expired. Please reconnect."
        case .serverError(let message):
            return "Server error: \(message)"
        case .decodingError(let message):
            return "Failed to decode response: \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid server response"
        case .syncInProgress:
            return "Sync already in progress"
        }
    }
}

// MARK: - Banking API Service

actor BankingAPIService {
    static let shared = BankingAPIService()

    private var baseURL: String { AppConfiguration.bankingEndpoint }
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Banks Endpoints

    /// Get list of available banks for a country
    func fetchBanks(country: String) async throws -> BankListResponse {
        print("🏦 [Banking] Fetching banks for country: \(country)")

        let response: BankListResponse = try await performRequest(
            endpoint: "/banks",
            method: "GET",
            queryItems: [URLQueryItem(name: "country", value: country)]
        )

        print("🏦 [Banking] ✅ Found \(response.banks.count) banks")
        return response
    }

    // MARK: - Bank Connections Endpoints

    /// Start OAuth flow for bank connection
    func createConnection(bankName: String, country: String) async throws -> BankConnectionAuthResponse {
        print("🏦 [Banking] Creating connection for bank: \(bankName)")

        let request = BankConnectionCreate(bankName: bankName, country: country)

        let response: BankConnectionAuthResponse = try await performRequestWithBody(
            endpoint: "/bank-connections",
            method: "POST",
            body: request
        )

        print("🏦 [Banking] ✅ Connection created, redirect URL: \(response.redirectUrl)")
        return response
    }

    /// Get all bank connections for user
    func fetchConnections() async throws -> [BankConnectionResponse] {
        print("🏦 [Banking] Fetching connections...")

        let response: BankConnectionListResponse = try await performRequest(
            endpoint: "/bank-connections",
            method: "GET"
        )

        print("🏦 [Banking] ✅ Found \(response.connections.count) connections")
        return response.connections
    }

    /// Delete a bank connection
    func deleteConnection(connectionId: String) async throws {
        print("🏦 [Banking] Deleting connection: \(connectionId)")

        let _: EmptyResponse = try await performRequest(
            endpoint: "/bank-connections/\(connectionId)",
            method: "DELETE"
        )

        print("🏦 [Banking] ✅ Connection deleted")
    }

    // MARK: - Bank Accounts Endpoints

    /// Get all bank accounts
    func fetchAccounts() async throws -> [BankAccountResponse] {
        print("🏦 [Banking] Fetching accounts...")

        let response: BankAccountListResponse = try await performRequest(
            endpoint: "/bank-accounts",
            method: "GET"
        )

        print("🏦 [Banking] ✅ Found \(response.accounts.count) accounts")
        return response.accounts
    }

    /// Sync transactions for an account
    func syncAccount(accountId: String) async throws -> BankAccountSyncResponse {
        print("🏦 [Banking] Syncing account: \(accountId)")

        let response: BankAccountSyncResponse = try await performRequest(
            endpoint: "/bank-accounts/\(accountId)/sync",
            method: "POST"
        )

        print("🏦 [Banking] ✅ Synced \(response.transactionsFetched) transactions, \(response.newTransactions) new")
        return response
    }

    // MARK: - Bank Transactions Endpoints

    /// Get pending transactions for review
    func fetchPendingTransactions(page: Int = 1, pageSize: Int = 50) async throws -> BankTransactionListResponse {
        print("🏦 [Banking] Fetching pending transactions (page \(page))...")

        let response: BankTransactionListResponse = try await performRequest(
            endpoint: "/bank-transactions",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "status", value: "pending"),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize))
            ]
        )

        print("🏦 [Banking] ✅ Found \(response.transactions.count) pending transactions (page \(page)/\(response.totalPages))")
        return response
    }

    /// Import selected transactions
    func importTransactions(request: TransactionImportRequest) async throws -> TransactionImportResponse {
        print("🏦 [Banking] Importing \(request.transactions.count) transactions...")

        let response: TransactionImportResponse = try await performRequestWithBody(
            endpoint: "/bank-transactions/import",
            method: "POST",
            body: request
        )

        print("🏦 [Banking] ✅ Imported \(response.importedCount), failed \(response.failedCount)")
        return response
    }

    /// Mark transactions as ignored
    func ignoreTransactions(request: TransactionIgnoreRequest) async throws {
        print("🏦 [Banking] Ignoring \(request.transactionIds.count) transactions...")

        let _: EmptyResponse = try await performRequestWithBody(
            endpoint: "/bank-transactions/ignore",
            method: "POST",
            body: request
        )

        print("🏦 [Banking] ✅ Transactions ignored")
    }

    // MARK: - Helper Methods

    private func performRequest<T: Decodable>(
        endpoint: String,
        method: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw BankingAPIError.invalidURL
        }

        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw BankingAPIError.invalidURL
        }

        print("📡 Banking API Request: \(method) \(url.absoluteString)")

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BankingAPIError.invalidResponse
            }

            print("📥 Banking response: HTTP \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch let decodingError as DecodingError {
                    logDecodingError(decodingError, data: data, endpoint: endpoint)
                    throw BankingAPIError.decodingError(decodingError.localizedDescription)
                }

            case 401:
                throw BankingAPIError.unauthorized

            case 404:
                throw BankingAPIError.notFound

            case 409:
                throw BankingAPIError.syncInProgress

            case 410:
                throw BankingAPIError.connectionExpired

            case 400...499:
                let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw BankingAPIError.serverError(errorMessage)

            case 500...599:
                let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                throw BankingAPIError.serverError(errorMessage)

            default:
                throw BankingAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }

        } catch let error as BankingAPIError {
            throw error
        } catch {
            throw BankingAPIError.networkError(error)
        }
    }

    private func performRequestWithBody<T: Decodable, B: Encodable>(
        endpoint: String,
        method: String,
        body: B
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw BankingAPIError.invalidURL
        }

        print("📡 Banking API Request: \(method) \(url.absoluteString)")

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30
        request.httpBody = try encoder.encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw BankingAPIError.invalidResponse
            }

            print("📥 Banking response: HTTP \(httpResponse.statusCode)")

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    let decodedResponse = try decoder.decode(T.self, from: data)
                    return decodedResponse
                } catch let decodingError as DecodingError {
                    logDecodingError(decodingError, data: data, endpoint: endpoint)
                    throw BankingAPIError.decodingError(decodingError.localizedDescription)
                }

            case 401:
                throw BankingAPIError.unauthorized

            case 404:
                throw BankingAPIError.notFound

            case 409:
                throw BankingAPIError.syncInProgress

            case 410:
                throw BankingAPIError.connectionExpired

            case 400...499:
                let errorMessage = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw BankingAPIError.serverError(errorMessage)

            case 500...599:
                let errorMessage = parseErrorMessage(from: data) ?? "Server error: \(httpResponse.statusCode)"
                throw BankingAPIError.serverError(errorMessage)

            default:
                throw BankingAPIError.serverError("Unexpected status code: \(httpResponse.statusCode)")
            }

        } catch let error as BankingAPIError {
            throw error
        } catch {
            throw BankingAPIError.networkError(error)
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw BankingAPIError.noAuthToken
        }

        do {
            let token = try await user.getIDToken()
            return token
        } catch {
            throw BankingAPIError.unauthorized
        }
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let errorDict = try? JSONDecoder().decode([String: String].self, from: data) {
            return errorDict["error"] ?? errorDict["message"]
        }
        return nil
    }

    private func logDecodingError(_ error: DecodingError, data: Data, endpoint: String) {
        print("❌ Banking decoding error for endpoint: \(endpoint)")

        if let jsonString = String(data: data, encoding: .utf8) {
            print("📄 Raw server response:\n\(jsonString)")
        }

        switch error {
        case .keyNotFound(let key, let context):
            print("🔑 Missing key '\(key.stringValue)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .typeMismatch(let type, let context):
            print("⚠️ Type mismatch for type '\(type)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .valueNotFound(let type, let context):
            print("❓ Value not found for type '\(type)'")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        case .dataCorrupted(let context):
            print("💥 Data corrupted")
            print("📍 Path: \(context.codingPath.map { $0.stringValue }.joined(separator: " -> "))")
        @unknown default:
            print("❓ Unknown decoding error")
        }
    }
}

// MARK: - Nonisolated Convenience Methods

extension BankingAPIService {
    nonisolated func getBanks(country: String) async throws -> BankListResponse {
        return try await fetchBanks(country: country)
    }

    nonisolated func startBankConnection(bankName: String, country: String) async throws -> BankConnectionAuthResponse {
        return try await createConnection(bankName: bankName, country: country)
    }

    nonisolated func getConnections() async throws -> [BankConnectionResponse] {
        return try await fetchConnections()
    }

    nonisolated func disconnectBank(connectionId: String) async throws {
        return try await deleteConnection(connectionId: connectionId)
    }

    nonisolated func getAccounts() async throws -> [BankAccountResponse] {
        return try await fetchAccounts()
    }

    nonisolated func syncAccountTransactions(accountId: String) async throws -> BankAccountSyncResponse {
        return try await syncAccount(accountId: accountId)
    }

    nonisolated func getPendingTransactions(page: Int = 1, pageSize: Int = 50) async throws -> BankTransactionListResponse {
        return try await fetchPendingTransactions(page: page, pageSize: pageSize)
    }

    nonisolated func importSelectedTransactions(request: TransactionImportRequest) async throws -> TransactionImportResponse {
        return try await importTransactions(request: request)
    }

    nonisolated func ignoreSelectedTransactions(request: TransactionIgnoreRequest) async throws {
        return try await ignoreTransactions(request: request)
    }
}

// MARK: - Empty Response

private struct EmptyResponse: Decodable {}
