//
//  RateLimitManager.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 21/01/2026.
//

import Foundation
import Combine
import FirebaseAuth

// MARK: - Rate Limit API Models

struct RateLimitStatusResponse: Codable {
    let messagesUsed: Int
    let messagesLimit: Int
    let messagesRemaining: Int
    let periodStartDate: Date
    let periodEndDate: Date
    let daysUntilReset: Int

    enum CodingKeys: String, CodingKey {
        case messagesUsed = "messages_used"
        case messagesLimit = "messages_limit"
        case messagesRemaining = "messages_remaining"
        case periodStartDate = "period_start_date"
        case periodEndDate = "period_end_date"
        case daysUntilReset = "days_until_reset"
    }
}

struct RateLimitExceededError: Codable, Error {
    let error: String
    let message: String
    let messagesUsed: Int
    let messagesLimit: Int
    let periodEndDate: Date
    let retryAfterSeconds: Int

    enum CodingKeys: String, CodingKey {
        case error, message
        case messagesUsed = "messages_used"
        case messagesLimit = "messages_limit"
        case periodEndDate = "period_end_date"
        case retryAfterSeconds = "retry_after_seconds"
    }
}

// MARK: - Rate Limit Configuration

enum RateLimitConfig {
    /// Default message limit (backend is source of truth)
    static let defaultMessagesPerMonth: Int = 100
}

// MARK: - Rate Limit Manager

/// Manages rate limiting for AI chat messages
/// The backend is the source of truth - this class caches and displays the state
@MainActor
class RateLimitManager: ObservableObject {
    static let shared = RateLimitManager()

    // MARK: - Published Properties

    /// Current message count this period
    @Published private(set) var messagesUsed: Int = 0

    /// Message limit for the period
    @Published private(set) var messagesLimit: Int = RateLimitConfig.defaultMessagesPerMonth

    /// Messages remaining
    @Published private(set) var messagesRemaining: Int = RateLimitConfig.defaultMessagesPerMonth

    /// Period end date
    @Published private(set) var periodEndDate: Date?

    /// Days until reset
    @Published private(set) var daysUntilReset: Int = 30

    /// Whether currently syncing with backend
    @Published private(set) var isSyncing: Bool = false

    /// Last sync error (if any)
    @Published private(set) var lastSyncError: String?

    // MARK: - Private Properties

    private var currentUserId: String?
    private let userDefaults = UserDefaults.standard

    // MARK: - Computed Properties

    /// Whether user is rate limited
    var isRateLimited: Bool {
        messagesRemaining <= 0
    }

    /// Usage percentage (0.0 to 1.0)
    var usagePercentage: Double {
        guard messagesLimit > 0 else { return 1.0 }
        return min(1.0, Double(messagesUsed) / Double(messagesLimit))
    }

    /// Formatted usage string
    var usageDisplayString: String {
        "\(messagesRemaining)/\(messagesLimit) messages left"
    }

    /// Message to display when rate limited
    var rateLimitMessage: String? {
        guard isRateLimited else { return nil }
        if let endDate = periodEndDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return "Message limit reached. Resets \(formatter.localizedString(for: endDate, relativeTo: Date()))"
        }
        return "Message limit reached for this period."
    }

    /// Formatted reset date
    var resetDateFormatted: String {
        periodEndDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
    }

    // MARK: - Initialization

    private init() {
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.handleUserChange(user)
            }
        }

        // Load initial state if user is already logged in
        if let user = Auth.auth().currentUser {
            handleUserChange(user)
        }
    }

    // MARK: - User Management

    private func handleUserChange(_ user: User?) {
        let newUserId = user?.uid

        if newUserId != currentUserId {
            currentUserId = newUserId

            if newUserId != nil {
                loadLocalState()
                // Sync with backend when user logs in
                Task {
                    await syncFromBackend()
                }
            } else {
                clearOnLogout()
            }
        }
    }

    func clearOnLogout() {
        currentUserId = nil
        messagesUsed = 0
        messagesLimit = RateLimitConfig.defaultMessagesPerMonth
        messagesRemaining = RateLimitConfig.defaultMessagesPerMonth
        periodEndDate = nil
        daysUntilReset = 30
        lastSyncError = nil
        objectWillChange.send()
    }

    // MARK: - Storage Keys (per-user)

    private var storageKeyPrefix: String {
        guard let userId = currentUserId else { return "rateLimit_anonymous" }
        return "rateLimit_\(userId)"
    }

    // MARK: - Public API

    /// Check if user can send a message
    func canSendMessage(for subscriptionStatus: SubscriptionStatus) -> Bool {
        guard subscriptionStatus.isActive else { return false }
        // If we don't have user ID yet, allow message - backend will enforce
        if currentUserId == nil { return true }
        return !isRateLimited
    }

    /// Optimistically decrement the local counter (call after successful message)
    func decrementLocal() {
        guard currentUserId != nil else { return }
        messagesUsed += 1
        messagesRemaining = max(0, messagesLimit - messagesUsed)
        saveLocalState()
        objectWillChange.send()
    }

    // MARK: - Backend Sync

    /// Sync rate limit state from backend
    func syncFromBackend() async {
        guard currentUserId != nil else { return }
        guard !isSyncing else { return }

        isSyncing = true
        lastSyncError = nil

        do {
            let status = try await fetchRateLimitStatus()
            syncFromResponse(status)
            print("✅ Rate limit synced: \(messagesUsed)/\(messagesLimit) used")
        } catch {
            lastSyncError = error.localizedDescription
            print("⚠️ Failed to sync rate limit: \(error)")
            // Non-critical - app continues with cached/default values
        }

        isSyncing = false
    }

    /// Sync from GET /api/v1/rate-limit response
    func syncFromResponse(_ response: RateLimitStatusResponse) {
        messagesUsed = response.messagesUsed
        messagesLimit = response.messagesLimit
        messagesRemaining = response.messagesRemaining
        periodEndDate = response.periodEndDate
        daysUntilReset = response.daysUntilReset
        saveLocalState()
        objectWillChange.send()
    }

    /// Sync from X-RateLimit-* headers after chat response
    func syncFromHeaders(limit: Int, remaining: Int, resetTimestamp: TimeInterval) {
        messagesLimit = limit
        messagesRemaining = remaining
        messagesUsed = limit - remaining
        periodEndDate = Date(timeIntervalSince1970: resetTimestamp)

        // Calculate days until reset
        if let endDate = periodEndDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: endDate)
            daysUntilReset = max(0, components.day ?? 0)
        }

        saveLocalState()
        objectWillChange.send()
    }

    /// Handle rate limit exceeded error from backend
    func handleRateLimitExceeded(_ error: RateLimitExceededError) {
        messagesUsed = error.messagesUsed
        messagesLimit = error.messagesLimit
        messagesRemaining = 0
        periodEndDate = error.periodEndDate

        if let endDate = periodEndDate {
            let calendar = Calendar.current
            let components = calendar.dateComponents([.day], from: Date(), to: endDate)
            daysUntilReset = max(0, components.day ?? 0)
        }

        saveLocalState()
        objectWillChange.send()
    }

    // MARK: - API Call

    private func fetchRateLimitStatus() async throws -> RateLimitStatusResponse {
        guard let user = Auth.auth().currentUser else {
            throw ChatServiceError.authenticationRequired
        }

        let token = try await user.getIDToken()

        guard let url = URL(string: "\(AppConfiguration.backendBaseURL)/api/v1/rate-limit") else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw ChatServiceError.serverError(
                statusCode: httpResponse.statusCode,
                message: String(data: data, encoding: .utf8) ?? "Unknown error"
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RateLimitStatusResponse.self, from: data)
    }

    // MARK: - Local Storage

    private func loadLocalState() {
        let prefix = storageKeyPrefix
        messagesUsed = userDefaults.integer(forKey: "\(prefix)_messagesUsed")
        messagesLimit = userDefaults.integer(forKey: "\(prefix)_messagesLimit")
        if messagesLimit == 0 { messagesLimit = RateLimitConfig.defaultMessagesPerMonth }
        messagesRemaining = userDefaults.integer(forKey: "\(prefix)_messagesRemaining")
        if messagesRemaining == 0 && messagesUsed == 0 { messagesRemaining = messagesLimit }
        daysUntilReset = userDefaults.integer(forKey: "\(prefix)_daysUntilReset")
        if daysUntilReset == 0 { daysUntilReset = 30 }

        if let endDateTimestamp = userDefaults.object(forKey: "\(prefix)_periodEndDate") as? TimeInterval {
            periodEndDate = Date(timeIntervalSince1970: endDateTimestamp)
        }
    }

    private func saveLocalState() {
        let prefix = storageKeyPrefix
        userDefaults.set(messagesUsed, forKey: "\(prefix)_messagesUsed")
        userDefaults.set(messagesLimit, forKey: "\(prefix)_messagesLimit")
        userDefaults.set(messagesRemaining, forKey: "\(prefix)_messagesRemaining")
        userDefaults.set(daysUntilReset, forKey: "\(prefix)_daysUntilReset")
        if let endDate = periodEndDate {
            userDefaults.set(endDate.timeIntervalSince1970, forKey: "\(prefix)_periodEndDate")
        }
    }
}
