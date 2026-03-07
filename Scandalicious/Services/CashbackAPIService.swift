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
    let isGoldTier: Bool
    let spinsAvailable: Int

    enum CodingKeys: String, CodingKey {
        case totalEarned = "total_earned"
        case totalPaidOut = "total_paid_out"
        case currentBalance = "current_balance"
        case isGoldTier = "is_gold_tier"
        case spinsAvailable = "spins_available"
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
    let spinsAwarded: Int
    let isReferralReward: Bool
    let isStreakReward: Bool

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
        case spinsAwarded = "spins_awarded"
        case isReferralReward = "is_referral_reward"
        case isStreakReward = "is_streak_reward"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        receiptId = try container.decode(String.self, forKey: .receiptId)
        receiptTotal = try container.decode(Double.self, forKey: .receiptTotal)
        cashbackAmount = try container.decode(Double.self, forKey: .cashbackAmount)
        effectiveRate = try container.decode(Double.self, forKey: .effectiveRate)
        status = try container.decode(String.self, forKey: .status)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        storeName = try container.decodeIfPresent(String.self, forKey: .storeName)
        receiptDate = try container.decodeIfPresent(String.self, forKey: .receiptDate)
        spinsAwarded = try container.decodeIfPresent(Int.self, forKey: .spinsAwarded) ?? 0
        isReferralReward = try container.decodeIfPresent(Bool.self, forKey: .isReferralReward) ?? false
        isStreakReward = try container.decodeIfPresent(Bool.self, forKey: .isStreakReward) ?? false
    }
}

struct CashbackSummaryResponse: Codable {
    let balance: CashbackBalanceResponse
    let recentTransactions: [CashbackTransactionResponse]
    let avgCashbackPerReceipt: Double
    let totalReceiptsWithCashback: Int
    let isGoldTier: Bool

    enum CodingKeys: String, CodingKey {
        case balance
        case recentTransactions = "recent_transactions"
        case avgCashbackPerReceipt = "avg_cashback_per_receipt"
        case totalReceiptsWithCashback = "total_receipts_with_cashback"
        case isGoldTier = "is_gold_tier"
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

struct CashbackClaimResponse: Codable {
    let receiptId: String
    let cashbackAmount: Double
    let spinsAwarded: Int
    let newBalance: Double

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case cashbackAmount = "cashback_amount"
        case spinsAwarded = "spins_awarded"
        case newBalance = "new_balance"
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

// MARK: - Streak Response Models

struct StreakCycleEntryResponse: Codable {
    let week: Int
    let label: String
    let rewardType: String
    let completed: Bool

    enum CodingKeys: String, CodingKey {
        case week, label, completed
        case rewardType = "reward_type"
    }
}

struct StreakClaimableRewardResponse: Codable {
    let rewardId: String
    let weekNumber: Int
    let rewardType: String
    let spinsAmount: Int
    let cashAmount: Double

    enum CodingKeys: String, CodingKey {
        case rewardId = "reward_id"
        case weekNumber = "week_number"
        case rewardType = "reward_type"
        case spinsAmount = "spins_amount"
        case cashAmount = "cash_amount"
    }
}

struct StreakStatusResponse: Codable {
    let weekCount: Int
    let currentCycle: [StreakCycleEntryResponse]
    let claimableReward: StreakClaimableRewardResponse?
    let isAtRisk: Bool

    enum CodingKeys: String, CodingKey {
        case weekCount = "week_count"
        case currentCycle = "current_cycle"
        case claimableReward = "claimable_reward"
        case isAtRisk = "is_at_risk"
    }
}

struct StreakClaimResponse: Codable {
    let success: Bool
    let rewardType: String
    let spinsCredited: Int
    let cashCredited: Double
    let newBalance: Double
    let newSpinsAvailable: Int

    enum CodingKeys: String, CodingKey {
        case success
        case rewardType = "reward_type"
        case spinsCredited = "spins_credited"
        case cashCredited = "cash_credited"
        case newBalance = "new_balance"
        case newSpinsAvailable = "new_spins_available"
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

    // MARK: - Claim Endpoint

    func claimCashback(receiptId: String) async throws -> CashbackClaimResponse {
        return try await performPostRequestWithData(
            endpoint: "/cashback/claim/\(receiptId)",
            bodyData: Data()
        )
    }

    // MARK: - Streak Endpoints

    func fetchStreakStatus() async throws -> StreakStatusResponse {
        return try await performRequest(endpoint: "/streak/status")
    }

    func claimStreakReward() async throws -> StreakClaimResponse {
        return try await performPostRequestWithData(endpoint: "/streak/claim", bodyData: Data())
    }

    func testAdvanceStreak(amount: Double = 100) async throws -> StreakStatusResponse {
        return try await performPostRequestWithData(
            endpoint: "/streak/test/advance?amount=\(amount)",
            bodyData: Data()
        )
    }

    func testSetStreakWeek(_ week: Int) async throws -> StreakStatusResponse {
        return try await performPostRequestWithData(
            endpoint: "/streak/test/set-week?week=\(week)",
            bodyData: Data()
        )
    }

    func testResetStreak() async throws -> StreakStatusResponse {
        return try await performPostRequestWithData(endpoint: "/streak/test/reset", bodyData: Data())
    }

    // MARK: - Spin Endpoints

    func spinWheel(hasDoubleNext: Bool = false, isRespin: Bool = false, forceSegment: Int? = nil) async throws -> SpinResult {
        var body: [String: Any] = ["has_double_next": hasDoubleNext, "is_respin": isRespin]
        if let forceSegment { body["force_segment"] = forceSegment }
        // Encode manually since [String: Any] isn't Encodable
        let jsonData = try JSONSerialization.data(withJSONObject: body)
        return try await performPostRequestWithData(endpoint: "/spin/spin", bodyData: jsonData)
    }

    // MARK: - Nonisolated Wrappers

    nonisolated func claim(receiptId: String) async throws -> CashbackClaimResponse {
        return try await claimCashback(receiptId: receiptId)
    }

    nonisolated func getBalance() async throws -> CashbackBalanceResponse {
        return try await fetchBalance()
    }

    nonisolated func getSummary() async throws -> CashbackSummaryResponse {
        return try await fetchSummary()
    }

    nonisolated func getHistory(page: Int = 1, pageSize: Int = 20) async throws -> CashbackHistoryResponse {
        return try await fetchHistory(page: page, pageSize: pageSize)
    }

    nonisolated func performSpin(hasDoubleNext: Bool = false, isRespin: Bool = false, forceSegment: Int? = nil) async throws -> SpinResult {
        return try await spinWheel(hasDoubleNext: hasDoubleNext, isRespin: isRespin, forceSegment: forceSegment)
    }

    nonisolated func getStreakStatus() async throws -> StreakStatusResponse {
        return try await fetchStreakStatus()
    }

    nonisolated func claimStreak() async throws -> StreakClaimResponse {
        return try await claimStreakReward()
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
            return dict["error"] ?? dict["message"]
        }
        return nil
    }
}
