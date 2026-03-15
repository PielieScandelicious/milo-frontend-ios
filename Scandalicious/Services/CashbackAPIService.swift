//
//  CashbackAPIService.swift
//  Scandalicious
//
//  API service for the Milo Points cashback system.
//  Calls the backend /cashback/* and /streak/* and /spin/* endpoints.
//

import Foundation
import FirebaseAuth

// MARK: - Balance Response

struct CashbackBalanceResponse: Codable {
    // Milo Points (primary)
    let pointsBalance: Int
    let totalPointsEarned: Int
    let totalPointsPaidOut: Int
    let standardSpins: Int
    let premiumSpins: Int
    let tierLevel: String
    let kickstartProgress: KickstartProgress?
    let euroValue: Double
    let canWithdraw: Bool

    // Legacy fields (backward compat)
    let currentBalance: Double
    let totalEarned: Double
    let totalPaidOut: Double
    let isGoldTier: Bool
    let spinsAvailable: Int

    enum CodingKeys: String, CodingKey {
        case pointsBalance = "points_balance"
        case totalPointsEarned = "total_points_earned"
        case totalPointsPaidOut = "total_points_paid_out"
        case standardSpins = "standard_spins"
        case premiumSpins = "premium_spins"
        case tierLevel = "tier_level"
        case kickstartProgress = "kickstart_progress"
        case euroValue = "euro_value"
        case canWithdraw = "can_withdraw"
        case currentBalance = "current_balance"
        case totalEarned = "total_earned"
        case totalPaidOut = "total_paid_out"
        case isGoldTier = "is_gold_tier"
        case spinsAvailable = "spins_available"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pointsBalance      = try c.decodeIfPresent(Int.self,    forKey: .pointsBalance)      ?? 0
        totalPointsEarned  = try c.decodeIfPresent(Int.self,    forKey: .totalPointsEarned)  ?? 0
        totalPointsPaidOut = try c.decodeIfPresent(Int.self,    forKey: .totalPointsPaidOut) ?? 0
        standardSpins      = try c.decodeIfPresent(Int.self,    forKey: .standardSpins)      ?? 0
        premiumSpins       = try c.decodeIfPresent(Int.self,    forKey: .premiumSpins)       ?? 0
        tierLevel          = try c.decodeIfPresent(String.self, forKey: .tierLevel)          ?? "bronze"
        kickstartProgress  = try c.decodeIfPresent(KickstartProgress.self, forKey: .kickstartProgress)
        euroValue          = try c.decodeIfPresent(Double.self, forKey: .euroValue)          ?? 0
        canWithdraw        = try c.decodeIfPresent(Bool.self,   forKey: .canWithdraw)        ?? false
        currentBalance     = try c.decodeIfPresent(Double.self, forKey: .currentBalance)     ?? 0
        totalEarned        = try c.decodeIfPresent(Double.self, forKey: .totalEarned)        ?? 0
        totalPaidOut       = try c.decodeIfPresent(Double.self, forKey: .totalPaidOut)       ?? 0
        isGoldTier         = try c.decodeIfPresent(Bool.self,   forKey: .isGoldTier)         ?? false
        spinsAvailable     = try c.decodeIfPresent(Int.self,    forKey: .spinsAvailable)     ?? (standardSpins + premiumSpins)
    }

    /// Convenience: tier as a typed enum
    var tier: TierLevel { TierLevel(rawValue: tierLevel) ?? .bronze }
}

// MARK: - Transaction Response

struct CashbackTransactionResponse: Codable, Identifiable {
    let id: String
    let receiptId: String
    let receiptTotal: Double

    // Points breakdown (new)
    let pointsTotal: Int
    let fixedPoints: Int
    let groteKarPoints: Int
    let kickstartBonusPoints: Int
    let spinType: String?
    let isKickstart: Bool
    let isStreakSaver: Bool

    // Common fields
    let status: String
    let createdAt: String
    let storeName: String?
    let receiptDate: String?
    let spinsAwarded: Int
    let isReferralReward: Bool
    let isStreakReward: Bool

    // Legacy
    let cashbackAmount: Double

    enum CodingKeys: String, CodingKey {
        case id
        case receiptId = "receipt_id"
        case receiptTotal = "receipt_total"
        case pointsTotal = "points_total"
        case fixedPoints = "fixed_points"
        case groteKarPoints = "grote_kar_points"
        case kickstartBonusPoints = "kickstart_bonus_points"
        case spinType = "spin_type"
        case isKickstart = "is_kickstart"
        case isStreakSaver = "is_streak_saver"
        case status
        case createdAt = "created_at"
        case storeName = "store_name"
        case receiptDate = "receipt_date"
        case spinsAwarded = "spins_awarded"
        case isReferralReward = "is_referral_reward"
        case isStreakReward = "is_streak_reward"
        case cashbackAmount = "cashback_amount"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                   = try c.decode(String.self,  forKey: .id)
        receiptId            = try c.decode(String.self,  forKey: .receiptId)
        receiptTotal         = try c.decodeIfPresent(Double.self, forKey: .receiptTotal) ?? 0
        pointsTotal          = try c.decodeIfPresent(Int.self,    forKey: .pointsTotal)          ?? 0
        fixedPoints          = try c.decodeIfPresent(Int.self,    forKey: .fixedPoints)          ?? 0
        groteKarPoints       = try c.decodeIfPresent(Int.self,    forKey: .groteKarPoints)       ?? 0
        kickstartBonusPoints = try c.decodeIfPresent(Int.self,    forKey: .kickstartBonusPoints) ?? 0
        spinType             = try c.decodeIfPresent(String.self, forKey: .spinType)
        isKickstart          = try c.decodeIfPresent(Bool.self,   forKey: .isKickstart)   ?? false
        isStreakSaver        = try c.decodeIfPresent(Bool.self,   forKey: .isStreakSaver)  ?? false
        status               = try c.decode(String.self,  forKey: .status)
        createdAt            = try c.decode(String.self,  forKey: .createdAt)
        storeName            = try c.decodeIfPresent(String.self, forKey: .storeName)
        receiptDate          = try c.decodeIfPresent(String.self, forKey: .receiptDate)
        spinsAwarded         = try c.decodeIfPresent(Int.self,    forKey: .spinsAwarded) ?? 0
        isReferralReward     = try c.decodeIfPresent(Bool.self,   forKey: .isReferralReward) ?? false
        isStreakReward       = try c.decodeIfPresent(Bool.self,   forKey: .isStreakReward)   ?? false
        cashbackAmount       = try c.decodeIfPresent(Double.self, forKey: .cashbackAmount)
            ?? Double(pointsTotal) / 1000.0
    }

    var spinWheelType: SpinWheelType? {
        guard let s = spinType else { return nil }
        return SpinWheelType(rawValue: s)
    }
}

// MARK: - Summary / History / Claim Responses

struct CashbackSummaryResponse: Codable {
    let balance: CashbackBalanceResponse
    let recentTransactions: [CashbackTransactionResponse]
    let avgPointsPerReceipt: Double
    let totalReceiptsWithRewards: Int
    let tierLevel: String

    // Legacy
    let avgCashbackPerReceipt: Double
    let totalReceiptsWithCashback: Int
    let isGoldTier: Bool

    enum CodingKeys: String, CodingKey {
        case balance
        case recentTransactions = "recent_transactions"
        case avgPointsPerReceipt = "avg_points_per_receipt"
        case totalReceiptsWithRewards = "total_receipts_with_rewards"
        case tierLevel = "tier_level"
        case avgCashbackPerReceipt = "avg_cashback_per_receipt"
        case totalReceiptsWithCashback = "total_receipts_with_cashback"
        case isGoldTier = "is_gold_tier"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        balance                   = try c.decode(CashbackBalanceResponse.self,          forKey: .balance)
        recentTransactions        = try c.decode([CashbackTransactionResponse].self,    forKey: .recentTransactions)
        avgPointsPerReceipt       = try c.decodeIfPresent(Double.self, forKey: .avgPointsPerReceipt)       ?? 0
        totalReceiptsWithRewards  = try c.decodeIfPresent(Int.self,    forKey: .totalReceiptsWithRewards)  ?? 0
        tierLevel                 = try c.decodeIfPresent(String.self, forKey: .tierLevel)                 ?? "bronze"
        avgCashbackPerReceipt     = try c.decodeIfPresent(Double.self, forKey: .avgCashbackPerReceipt)     ?? 0
        totalReceiptsWithCashback = try c.decodeIfPresent(Int.self,    forKey: .totalReceiptsWithCashback) ?? 0
        isGoldTier                = try c.decodeIfPresent(Bool.self,   forKey: .isGoldTier)                ?? false
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
    let pointsTotal: Int
    let spinType: String?
    let newPointsBalance: Int
    let euroValue: Double

    // Legacy
    let cashbackAmount: Double
    let spinsAwarded: Int
    let newBalance: Double

    enum CodingKeys: String, CodingKey {
        case receiptId = "receipt_id"
        case pointsTotal = "points_total"
        case spinType = "spin_type"
        case newPointsBalance = "new_points_balance"
        case euroValue = "euro_value"
        case cashbackAmount = "cashback_amount"
        case spinsAwarded = "spins_awarded"
        case newBalance = "new_balance"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        receiptId       = try c.decode(String.self, forKey: .receiptId)
        pointsTotal     = try c.decodeIfPresent(Int.self,    forKey: .pointsTotal)     ?? 0
        spinType        = try c.decodeIfPresent(String.self, forKey: .spinType)
        newPointsBalance = try c.decodeIfPresent(Int.self,   forKey: .newPointsBalance) ?? 0
        euroValue       = try c.decodeIfPresent(Double.self, forKey: .euroValue)        ?? 0
        cashbackAmount  = try c.decodeIfPresent(Double.self, forKey: .cashbackAmount)   ?? Double(pointsTotal) / 1000.0
        spinsAwarded    = try c.decodeIfPresent(Int.self,    forKey: .spinsAwarded)     ?? 0
        newBalance      = try c.decodeIfPresent(Double.self, forKey: .newBalance)       ?? euroValue
    }

    var spinWheelType: SpinWheelType? {
        guard let s = spinType else { return nil }
        return SpinWheelType(rawValue: s)
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
    let pointsAmount: Int
    let spinType: String?
    let streakLevel: Int

    // Legacy
    let cashAmount: Double

    enum CodingKeys: String, CodingKey {
        case rewardId = "reward_id"
        case weekNumber = "week_number"
        case rewardType = "reward_type"
        case spinsAmount = "spins_amount"
        case pointsAmount = "points_amount"
        case spinType = "spin_type"
        case streakLevel = "streak_level"
        case cashAmount = "cash_amount"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rewardId    = try c.decode(String.self, forKey: .rewardId)
        weekNumber  = try c.decode(Int.self,    forKey: .weekNumber)
        rewardType  = try c.decode(String.self, forKey: .rewardType)
        spinsAmount = try c.decodeIfPresent(Int.self,    forKey: .spinsAmount) ?? 0
        pointsAmount = try c.decodeIfPresent(Int.self,   forKey: .pointsAmount) ?? 0
        spinType    = try c.decodeIfPresent(String.self, forKey: .spinType)
        streakLevel = try c.decodeIfPresent(Int.self,    forKey: .streakLevel) ?? 1
        cashAmount  = try c.decodeIfPresent(Double.self, forKey: .cashAmount)  ?? Double(pointsAmount) / 1000.0
    }

    var spinWheelType: SpinWheelType? {
        guard let s = spinType else { return nil }
        return SpinWheelType(rawValue: s)
    }
}

struct StreakStatusResponse: Codable {
    let weekCount: Int
    let streakLevel: Int
    let currentCycle: [StreakCycleEntryResponse]
    let claimableReward: StreakClaimableRewardResponse?
    let isAtRisk: Bool

    enum CodingKeys: String, CodingKey {
        case weekCount = "week_count"
        case streakLevel = "streak_level"
        case currentCycle = "current_cycle"
        case claimableReward = "claimable_reward"
        case isAtRisk = "is_at_risk"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        weekCount       = try c.decodeIfPresent(Int.self, forKey: .weekCount)   ?? 0
        streakLevel     = try c.decodeIfPresent(Int.self, forKey: .streakLevel) ?? 1
        currentCycle    = try c.decodeIfPresent([StreakCycleEntryResponse].self, forKey: .currentCycle) ?? []
        claimableReward = try c.decodeIfPresent(StreakClaimableRewardResponse.self, forKey: .claimableReward)
        isAtRisk        = try c.decodeIfPresent(Bool.self, forKey: .isAtRisk) ?? false
    }
}

struct StreakClaimResponse: Codable {
    let success: Bool
    let rewardType: String
    let pointsCredited: Int
    let spinType: String?
    let newPointsBalance: Int
    let newStandardSpins: Int
    let newPremiumSpins: Int

    // Legacy
    let spinsCredited: Int
    let newBalance: Double
    let newSpinsAvailable: Int

    enum CodingKeys: String, CodingKey {
        case success
        case rewardType = "reward_type"
        case pointsCredited = "points_credited"
        case spinType = "spin_type"
        case newPointsBalance = "new_points_balance"
        case newStandardSpins = "new_standard_spins"
        case newPremiumSpins = "new_premium_spins"
        case spinsCredited = "spins_credited"
        case newBalance = "new_balance"
        case newSpinsAvailable = "new_spins_available"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success          = try c.decodeIfPresent(Bool.self,   forKey: .success)          ?? true
        rewardType       = try c.decodeIfPresent(String.self, forKey: .rewardType)       ?? ""
        pointsCredited   = try c.decodeIfPresent(Int.self,    forKey: .pointsCredited)   ?? 0
        spinType         = try c.decodeIfPresent(String.self, forKey: .spinType)
        newPointsBalance = try c.decodeIfPresent(Int.self,    forKey: .newPointsBalance) ?? 0
        newStandardSpins = try c.decodeIfPresent(Int.self,    forKey: .newStandardSpins) ?? 0
        newPremiumSpins  = try c.decodeIfPresent(Int.self,    forKey: .newPremiumSpins)  ?? 0
        spinsCredited    = try c.decodeIfPresent(Int.self,    forKey: .spinsCredited)    ?? (newStandardSpins + newPremiumSpins)
        newBalance       = try c.decodeIfPresent(Double.self, forKey: .newBalance)       ?? Double(newPointsBalance) / 1000.0
        newSpinsAvailable = try c.decodeIfPresent(Int.self,   forKey: .newSpinsAvailable) ?? (newStandardSpins + newPremiumSpins)
    }

    var spinWheelType: SpinWheelType? {
        guard let s = spinType else { return nil }
        return SpinWheelType(rawValue: s)
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

    // MARK: - Cashback Endpoints

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

    func testSetStreakWeek(_ week: Int, streakLevel: Int = 1) async throws -> StreakStatusResponse {
        return try await performPostRequestWithData(
            endpoint: "/streak/test/set-week?week=\(week)&streak_level=\(streakLevel)",
            bodyData: Data()
        )
    }

    func testResetStreak() async throws -> StreakStatusResponse {
        return try await performPostRequestWithData(endpoint: "/streak/test/reset", bodyData: Data())
    }

    // MARK: - Spin Endpoints

    func spinWheel(spinType: SpinWheelType = .standard, isRespin: Bool = false, forceSegment: Int? = nil) async throws -> SpinResult {
        var body: [String: Any] = [
            "spin_type": spinType.rawValue,
            "is_respin": isRespin,
        ]
        if let forceSegment { body["force_segment"] = forceSegment }
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

    nonisolated func performSpin(spinType: SpinWheelType = .standard, isRespin: Bool = false, forceSegment: Int? = nil) async throws -> SpinResult {
        return try await spinWheel(spinType: spinType, isRespin: isRespin, forceSegment: forceSegment)
    }

    nonisolated func getStreakStatus() async throws -> StreakStatusResponse {
        return try await fetchStreakStatus()
    }

    nonisolated func claimStreak() async throws -> StreakClaimResponse {
        return try await claimStreakReward()
    }

    // MARK: - Private Networking

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
                do { return try decoder.decode(T.self, from: data) }
                catch { throw CashbackAPIError.decodingError(error.localizedDescription) }
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
                do { return try decoder.decode(T.self, from: data) }
                catch { throw CashbackAPIError.decodingError(error.localizedDescription) }
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
