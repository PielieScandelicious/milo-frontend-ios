//
//  CashbackAPIService.swift
//  Scandalicious
//
//  API service for the progressive cashback system.
//  Calls the backend /cashback/* endpoints.
//

import Foundation
import FirebaseAuth

// MARK: - Response Models

struct CashbackBalanceResponse: Codable {
    let totalEarned: Double
    let totalPaidOut: Double
    let currentBalance: Double

    enum CodingKeys: String, CodingKey {
        case totalEarned = "total_earned"
        case totalPaidOut = "total_paid_out"
        case currentBalance = "current_balance"
    }
}

struct CashbackTransactionResponse: Codable, Identifiable {
    let id: String
    let receiptId: String
    let receiptTotal: Double
    let cashbackAmount: Double
    let effectiveRate: Double
    let status: String
    let createdAt: String
    let storeName: String?
    let receiptDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case receiptId = "receipt_id"
        case receiptTotal = "receipt_total"
        case cashbackAmount = "cashback_amount"
        case effectiveRate = "effective_rate"
        case status
        case createdAt = "created_at"
        case storeName = "store_name"
        case receiptDate = "receipt_date"
    }
}

struct CashbackSummaryResponse: Codable {
    let balance: CashbackBalanceResponse
    let recentTransactions: [CashbackTransactionResponse]
    let avgCashbackPerReceipt: Double
    let totalReceiptsWithCashback: Int

    enum CodingKeys: String, CodingKey {
        case balance
        case recentTransactions = "recent_transactions"
        case avgCashbackPerReceipt = "avg_cashback_per_receipt"
        case totalReceiptsWithCashback = "total_receipts_with_cashback"
    }
}

struct CashbackHistoryResponse: Codable {
    let transactions: [CashbackTransactionResponse]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int

    enum CodingKeys: String, CodingKey {
        case transactions, total, page
        case pageSize = "page_size"
        case totalPages = "total_pages"
    }
}

struct CashbackPreviewSegment: Codable {
    let segment: Int
    let sliceStart: Double
    let sliceEnd: Double
    let rate: Double
    let cashback: Double

    enum CodingKeys: String, CodingKey {
        case segment
        case sliceStart = "slice_start"
        case sliceEnd = "slice_end"
        case rate, cashback
    }
}

struct CashbackPreviewResponse: Codable {
    let receiptTotal: Double
    let cashbackAmount: Double
    let effectiveRate: Double
    let segments: [CashbackPreviewSegment]

    enum CodingKeys: String, CodingKey {
        case receiptTotal = "receipt_total"
        case cashbackAmount = "cashback_amount"
        case effectiveRate = "effective_rate"
        case segments
    }
}

// MARK: - API Errors

enum CashbackAPIError: LocalizedError {
    case invalidURL
    case noAuthToken
    case unauthorized
    case serverError(String)
    case decodingError(String)
    case networkError(Error)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid API URL"
        case .noAuthToken: return "No authentication token available"
        case .unauthorized: return "Unauthorized - please sign in again"
        case .serverError(let msg): return "Server error: \(msg)"
        case .decodingError(let msg): return "Failed to decode response: \(msg)"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .invalidResponse: return "Invalid server response"
        }
    }
}

// MARK: - Cashback API Service

actor CashbackAPIService {
    static let shared = CashbackAPIService()

    private var baseURL: String { AppConfiguration.apiBase }
    private let decoder = JSONDecoder()

    private init() {}

    // MARK: - Endpoints

    func fetchBalance() async throws -> CashbackBalanceResponse {
        return try await performRequest(endpoint: "/cashback/balance")
    }

    func fetchSummary() async throws -> CashbackSummaryResponse {
        return try await performRequest(endpoint: "/cashback/summary")
    }

    func fetchHistory(page: Int = 1, pageSize: Int = 20) async throws -> CashbackHistoryResponse {
        return try await performRequest(
            endpoint: "/cashback/history",
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "page_size", value: String(pageSize)),
            ]
        )
    }

    func fetchPreview(amount: Double) async throws -> CashbackPreviewResponse {
        return try await performRequest(
            endpoint: "/cashback/preview",
            queryItems: [URLQueryItem(name: "amount", value: String(amount))]
        )
    }

    // MARK: - Nonisolated Wrappers

    nonisolated func getBalance() async throws -> CashbackBalanceResponse {
        return try await fetchBalance()
    }

    nonisolated func getSummary() async throws -> CashbackSummaryResponse {
        return try await fetchSummary()
    }

    nonisolated func getHistory(page: Int = 1, pageSize: Int = 20) async throws -> CashbackHistoryResponse {
        return try await fetchHistory(page: page, pageSize: pageSize)
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

    private func getAuthToken() async throws -> String {
        guard let user = Auth.auth().currentUser else {
            throw CashbackAPIError.noAuthToken
        }
        return try await user.getIDToken()
    }

    private func parseErrorMessage(from data: Data) -> String? {
        if let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            return dict["error"] ?? dict["message"]
        }
        return nil
    }
}
