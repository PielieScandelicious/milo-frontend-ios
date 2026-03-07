//
//  WithdrawalAPIService.swift
//  Scandalicious
//

import Foundation
import FirebaseAuth

// MARK: - Response Models

struct WithdrawalInfoResponse: Codable {
    let currentBalance: Double
    let maxWithdrawable: Double
    let availableAmounts: [Double]
    let hasPendingWithdrawal: Bool
    let activeWithdrawal: WithdrawalItemResponse?
    let lastIban: String?
    let lastIbanLast4: String?
    let canWithdraw: Bool
    let cannotWithdrawReason: String?

    enum CodingKeys: String, CodingKey {
        case currentBalance = "current_balance"
        case maxWithdrawable = "max_withdrawable"
        case availableAmounts = "available_amounts"
        case hasPendingWithdrawal = "has_pending_withdrawal"
        case activeWithdrawal = "active_withdrawal"
        case lastIban = "last_iban"
        case lastIbanLast4 = "last_iban_last4"
        case canWithdraw = "can_withdraw"
        case cannotWithdrawReason = "cannot_withdraw_reason"
    }
}

struct WithdrawalItemResponse: Codable, Identifiable {
    let id: String
    let amount: Double
    let ibanLast4: String
    let status: String
    let fraudCheckPassed: Bool
    let adminNotes: String?
    let createdAt: String
    let reviewedAt: String?
    let paidOutAt: String?

    enum CodingKeys: String, CodingKey {
        case id, amount, status
        case ibanLast4 = "iban_last4"
        case fraudCheckPassed = "fraud_check_passed"
        case adminNotes = "admin_notes"
        case createdAt = "created_at"
        case reviewedAt = "reviewed_at"
        case paidOutAt = "paid_out_at"
    }
}

struct WithdrawalCreateResponse: Codable {
    let id: String
    let amount: Double
    let ibanLast4: String
    let status: String
    let fraudCheckPassed: Bool
    let fraudCheckDetails: [String: AnyCodable]?
    let newBalance: Double

    enum CodingKeys: String, CodingKey {
        case id, amount, status
        case ibanLast4 = "iban_last4"
        case fraudCheckPassed = "fraud_check_passed"
        case fraudCheckDetails = "fraud_check_details"
        case newBalance = "new_balance"
    }
}

struct WithdrawalHistoryResponse: Codable {
    let withdrawals: [WithdrawalItemResponse]
    let hasPending: Bool

    enum CodingKeys: String, CodingKey {
        case withdrawals
        case hasPending = "has_pending"
    }
}

struct WithdrawalCreateRequest: Codable {
    let amount: Double
    let iban: String
}

// Simple AnyCodable for fraud_check_details
struct AnyCodable: Codable {
    let value: Any

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) { value = b }
        else if let i = try? container.decode(Int.self) { value = i }
        else if let d = try? container.decode(Double.self) { value = d }
        else if let s = try? container.decode(String.self) { value = s }
        else { value = "unknown" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let b = value as? Bool { try container.encode(b) }
        else if let i = value as? Int { try container.encode(i) }
        else if let d = value as? Double { try container.encode(d) }
        else if let s = value as? String { try container.encode(s) }
        else { try container.encode("unknown") }
    }
}

// MARK: - Withdrawal API Service

actor WithdrawalAPIService {
    static let shared = WithdrawalAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Endpoints

    func fetchInfo() async throws -> WithdrawalInfoResponse {
        return try await performRequest(endpoint: "/withdrawal/info")
    }

    func createWithdrawal(amount: Double, iban: String) async throws -> WithdrawalCreateResponse {
        let body = WithdrawalCreateRequest(amount: amount, iban: iban)
        return try await performPostRequest(endpoint: "/withdrawal/request", body: body)
    }

    func fetchHistory() async throws -> WithdrawalHistoryResponse {
        return try await performRequest(endpoint: "/withdrawal/history")
    }

    func testAutoProcess(withdrawalId: String) async throws -> WithdrawalItemResponse {
        return try await performPostRequestWithData(
            endpoint: "/withdrawal/test/auto-process/\(withdrawalId)",
            bodyData: Data()
        )
    }

    func testReset() async throws -> [String: String] {
        return try await performPostRequestWithData(
            endpoint: "/withdrawal/test/reset",
            bodyData: Data()
        )
    }

    // MARK: - Nonisolated Wrappers

    nonisolated func getInfo() async throws -> WithdrawalInfoResponse {
        return try await fetchInfo()
    }

    nonisolated func submitWithdrawal(amount: Double, iban: String) async throws -> WithdrawalCreateResponse {
        return try await createWithdrawal(amount: amount, iban: iban)
    }

    nonisolated func getHistory() async throws -> WithdrawalHistoryResponse {
        return try await fetchHistory()
    }

    nonisolated func autoProcess(withdrawalId: String) async throws -> WithdrawalItemResponse {
        return try await testAutoProcess(withdrawalId: withdrawalId)
    }

    nonisolated func resetWithdrawals() async throws -> [String: String] {
        return try await testReset()
    }

    // MARK: - Private

    private func performRequest<T: Decodable>(
        endpoint: String,
        queryItems: [URLQueryItem] = []
    ) async throws -> T {
        guard var urlComponents = URLComponents(string: "\(baseURL)\(endpoint)") else {
            throw CashbackAPIError.invalidURL
        }
        if !queryItems.isEmpty {
            urlComponents.queryItems = queryItems
        }
        guard let url = urlComponents.url else {
            throw CashbackAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CashbackAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw CashbackAPIError.decodingError(error.localizedDescription)
                }
            case 401:
                throw CashbackAPIError.unauthorized
            case 400...499:
                let msg = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw CashbackAPIError.serverError(msg)
            default:
                throw CashbackAPIError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as CashbackAPIError {
            throw error
        } catch {
            throw CashbackAPIError.networkError(error)
        }
    }

    private func performPostRequest<T: Decodable, B: Encodable>(
        endpoint: String,
        body: B
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CashbackAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        request.httpBody = try JSONEncoder().encode(body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CashbackAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw CashbackAPIError.decodingError(error.localizedDescription)
                }
            case 401:
                throw CashbackAPIError.unauthorized
            case 400...499:
                let msg = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw CashbackAPIError.serverError(msg)
            default:
                throw CashbackAPIError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as CashbackAPIError {
            throw error
        } catch {
            throw CashbackAPIError.networkError(error)
        }
    }

    private func performPostRequestWithData<T: Decodable>(
        endpoint: String,
        bodyData: Data
    ) async throws -> T {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw CashbackAPIError.invalidURL
        }

        let token = try await getAuthToken()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        request.httpBody = bodyData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw CashbackAPIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw CashbackAPIError.decodingError(error.localizedDescription)
                }
            case 401:
                throw CashbackAPIError.unauthorized
            case 400...499:
                let msg = parseErrorMessage(from: data) ?? "Client error: \(httpResponse.statusCode)"
                throw CashbackAPIError.serverError(msg)
            default:
                throw CashbackAPIError.serverError("Server error: \(httpResponse.statusCode)")
            }
        } catch let error as CashbackAPIError {
            throw error
        } catch {
            throw CashbackAPIError.networkError(error)
        }
    }

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw CashbackAPIError.noAuthToken
        }
        return try await user.getIDToken()
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict["detail"] ?? dict["error"] ?? dict["message"]
        }
        return nil
    }
}
