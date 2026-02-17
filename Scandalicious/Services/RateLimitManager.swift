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
    let receiptsUsed: Int
    let receiptsLimit: Int
    let receiptsRemaining: Int
    let periodStartDate: Date
    let periodEndDate: Date
    let daysUntilReset: Int

    enum CodingKeys: String, CodingKey {
        case messagesUsed = "messages_used"
        case messagesLimit = "messages_limit"
        case messagesRemaining = "messages_remaining"
        case receiptsUsed = "receipts_used"
        case receiptsLimit = "receipts_limit"
        case receiptsRemaining = "receipts_remaining"
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
    /// Default receipt upload limit (backend is source of truth)
    static let defaultReceiptsPerMonth: Int = 15
}

// MARK: - Rate Limit Manager

/// Manages rate limiting for AI chat messages
/// The backend is the source of truth - this class caches and displays the state
@MainActor
class RateLimitManager: ObservableObject {
    static let shared = RateLimitManager()

    // MARK: - Published Properties (Messages)

    /// Current message count this period
    @Published private(set) var messagesUsed: Int = 0

    /// Message limit for the period
    @Published private(set) var messagesLimit: Int = RateLimitConfig.defaultMessagesPerMonth

    /// Messages remaining
    @Published private(set) var messagesRemaining: Int = RateLimitConfig.defaultMessagesPerMonth

    // MARK: - Published Properties (Receipts)

    /// Current receipt upload count this period
    @Published private(set) var receiptsUsed: Int = 0

    /// Receipt upload limit for the period
    @Published private(set) var receiptsLimit: Int = RateLimitConfig.defaultReceiptsPerMonth

    /// Receipts remaining
    @Published private(set) var receiptsRemaining: Int = RateLimitConfig.defaultReceiptsPerMonth

    // MARK: - Published Properties (Period)

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

    // MARK: - Computed Properties (Messages)

    /// Whether user is rate limited for messages
    var isRateLimited: Bool {
        messagesRemaining <= 0
    }

    /// Message usage percentage (0.0 to 1.0)
    var usagePercentage: Double {
        guard messagesLimit > 0 else { return 1.0 }
        return min(1.0, Double(messagesUsed) / Double(messagesLimit))
    }

    /// Formatted message usage string
    var usageDisplayString: String {
        "\(messagesRemaining)/\(messagesLimit) \(L("messages"))"
    }

    /// Message to display when rate limited
    var rateLimitMessage: String? {
        guard isRateLimited else { return nil }
        if let endDate = periodEndDate {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let langCode = LanguageManager.currentLanguageCode
            formatter.locale = Locale(identifier: langCode == "nl" ? "nl_BE" : langCode == "fr" ? "fr_BE" : "en_US")
            return "\(L("message_limit_resets")) \(formatter.localizedString(for: endDate, relativeTo: Date()))"
        }
        return L("message_limit_period")
    }

    /// Formatted reset date
    var resetDateFormatted: String {
        periodEndDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown"
    }

    // MARK: - Computed Properties (Receipts)

    /// Whether user has exhausted receipt uploads
    var isReceiptLimitReached: Bool {
        receiptsRemaining <= 0
    }

    /// Receipt usage percentage (0.0 to 1.0)
    var receiptUsagePercentage: Double {
        guard receiptsLimit > 0 else { return 1.0 }
        return min(1.0, Double(receiptsUsed) / Double(receiptsLimit))
    }

    /// Formatted receipt usage string (e.g., "12/15 receipts remaining")
    var receiptUsageDisplayString: String {
        if receiptsRemaining == 0 {
            return "No receipts remaining"
        } else if receiptsRemaining == 1 {
            return "1 receipt remaining"
        } else {
            return "\(receiptsRemaining) receipts remaining"
        }
    }

    /// Receipt limit state for UI display
    var receiptLimitState: ReceiptLimitState {
        if receiptsRemaining <= 0 {
            return .exhausted
        } else if receiptsRemaining <= 5 {
            return .warning
        } else {
            return .normal
        }
    }

    /// Message to display when receipt limit is reached
    var receiptLimitMessage: String? {
        guard isReceiptLimitReached else { return nil }
        if daysUntilReset > 0 {
            return "Upload limit reached. Resets in \(daysUntilReset) day\(daysUntilReset == 1 ? "" : "s")"
        }
        return "Upload limit reached for this period."
    }

    /// Reset days formatted string
    var resetDaysFormatted: String {
        if daysUntilReset == 0 {
            return "Resets today"
        } else if daysUntilReset == 1 {
            return "Resets in 1 day"
        } else {
            return "Resets in \(daysUntilReset) days"
        }
    }

    /// Enum for receipt limit states
    enum ReceiptLimitState {
        case normal   // >5 remaining
        case warning  // 1-5 remaining
        case exhausted // 0 remaining
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
        receiptsUsed = 0
        receiptsLimit = RateLimitConfig.defaultReceiptsPerMonth
        receiptsRemaining = RateLimitConfig.defaultReceiptsPerMonth
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
        // PAYWALL DISABLED: Always allow messages
        return true
    }

    /// Optimistically decrement the local message counter (call after successful message)
    func decrementLocal() {
        guard currentUserId != nil else { return }
        messagesUsed += 1
        messagesRemaining = max(0, messagesLimit - messagesUsed)
        saveLocalState()
        objectWillChange.send()
    }

    /// Check if user can upload a receipt
    func canUploadReceipt() -> Bool {
        return receiptsRemaining > 0
    }

    /// Optimistically decrement the local receipt counter (call after successful upload)
    func decrementReceiptLocal() {
        guard currentUserId != nil else { return }
        receiptsUsed += 1
        receiptsRemaining = max(0, receiptsLimit - receiptsUsed)
        saveLocalState()
        objectWillChange.send()
    }

    /// Optimistically increment the local receipt counter (call after successful delete)
    func incrementReceiptLocal() {
        guard currentUserId != nil else { return }
        receiptsUsed = max(0, receiptsUsed - 1)
        receiptsRemaining = min(receiptsLimit, receiptsRemaining + 1)
        saveLocalState()
        objectWillChange.send()
    }

    // MARK: - Backend Sync

    /// Sync rate limit state from backend
    func syncFromBackend() async {
        // Check if we have a user - either cached or from Firebase Auth
        if currentUserId == nil {
            // Try to get user from Firebase Auth directly
            if let user = Auth.auth().currentUser {
                currentUserId = user.uid
            } else {
                return
            }
        }

        guard !isSyncing else {
            return
        }

        isSyncing = true
        lastSyncError = nil

        do {
            let status = try await fetchRateLimitStatus()
            syncFromResponse(status)
        } catch {
            // Check if it's a timeout error - these are non-critical and shouldn't alarm the user
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut {
                // Timeout is non-critical - continue with cached values
            } else {
                // Only set lastSyncError for actual failures, not timeouts
                lastSyncError = error.localizedDescription
            }
            // Non-critical - app continues with cached/default values
        }

        isSyncing = false
    }

    /// Sync from rate-limit API response
    func syncFromResponse(_ response: RateLimitStatusResponse) {
        messagesUsed = response.messagesUsed
        messagesLimit = response.messagesLimit
        messagesRemaining = response.messagesRemaining
        receiptsUsed = response.receiptsUsed
        receiptsLimit = response.receiptsLimit
        receiptsRemaining = response.receiptsRemaining
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

    /// Handle rate limit exceeded error from backend (messages)
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

    /// Handle receipt rate limit exceeded error from backend
    func handleReceiptRateLimitExceeded(_ error: ReceiptRateLimitExceededError) {
        receiptsUsed = error.details.receiptsUsed
        receiptsLimit = error.details.receiptsLimit
        receiptsRemaining = 0
        periodEndDate = error.details.periodEndDate

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
        // Get auth token using multiple fallback methods
        let token = try await getAuthToken()

        guard let url = URL(string: AppConfiguration.rateLimitEndpoint) else {
            throw ChatServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("no-cache, no-store, must-revalidate", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30

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

    // MARK: - Get Auth Token

    private func getAuthToken() async throws -> String {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"

        // Method 1: Try Firebase Auth with force refresh
        if let user = Auth.auth().currentUser {
            do {
                // Force refresh to get a fresh token
                let token = try await user.getIDToken(forcingRefresh: true)

                // Also save to shared storage for Share Extension
                if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                    sharedDefaults.set(token, forKey: "SCANDALICIOUS_AUTH_TOKEN")
                    sharedDefaults.set(token, forKey: "firebase_auth_token")
                    sharedDefaults.synchronize()
                }

                return token
            } catch {
                // Fall through to try other methods
            }
        }

        // Method 2: Try Keychain
        if let token = KeychainHelper.shared.retrieveToken() {
            return token
        }

        // Method 3: Try shared UserDefaults (SCANDALICIOUS_AUTH_TOKEN)
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            if let token = sharedDefaults.string(forKey: "SCANDALICIOUS_AUTH_TOKEN") {
                return token
            }

            // Method 4: Try firebase_auth_token
            if let token = sharedDefaults.string(forKey: "firebase_auth_token") {
                return token
            }
        }

        throw ChatServiceError.authenticationRequired
    }

    // MARK: - Local Storage

    private func loadLocalState() {
        let prefix = storageKeyPrefix

        // Messages
        messagesUsed = userDefaults.integer(forKey: "\(prefix)_messagesUsed")
        messagesLimit = userDefaults.integer(forKey: "\(prefix)_messagesLimit")
        if messagesLimit == 0 { messagesLimit = RateLimitConfig.defaultMessagesPerMonth }
        messagesRemaining = userDefaults.integer(forKey: "\(prefix)_messagesRemaining")
        if messagesRemaining == 0 && messagesUsed == 0 { messagesRemaining = messagesLimit }

        // Receipts
        receiptsUsed = userDefaults.integer(forKey: "\(prefix)_receiptsUsed")
        receiptsLimit = userDefaults.integer(forKey: "\(prefix)_receiptsLimit")
        if receiptsLimit == 0 { receiptsLimit = RateLimitConfig.defaultReceiptsPerMonth }
        receiptsRemaining = userDefaults.integer(forKey: "\(prefix)_receiptsRemaining")
        if receiptsRemaining == 0 && receiptsUsed == 0 { receiptsRemaining = receiptsLimit }

        // Period
        daysUntilReset = userDefaults.integer(forKey: "\(prefix)_daysUntilReset")
        if daysUntilReset == 0 { daysUntilReset = 30 }

        if let endDateTimestamp = userDefaults.object(forKey: "\(prefix)_periodEndDate") as? TimeInterval {
            periodEndDate = Date(timeIntervalSince1970: endDateTimestamp)
        }
    }

    private func saveLocalState() {
        let prefix = storageKeyPrefix

        // Messages
        userDefaults.set(messagesUsed, forKey: "\(prefix)_messagesUsed")
        userDefaults.set(messagesLimit, forKey: "\(prefix)_messagesLimit")
        userDefaults.set(messagesRemaining, forKey: "\(prefix)_messagesRemaining")

        // Receipts
        userDefaults.set(receiptsUsed, forKey: "\(prefix)_receiptsUsed")
        userDefaults.set(receiptsLimit, forKey: "\(prefix)_receiptsLimit")
        userDefaults.set(receiptsRemaining, forKey: "\(prefix)_receiptsRemaining")

        // Period
        userDefaults.set(daysUntilReset, forKey: "\(prefix)_daysUntilReset")
        if let endDate = periodEndDate {
            userDefaults.set(endDate.timeIntervalSince1970, forKey: "\(prefix)_periodEndDate")
        }

        // Also save to shared App Group UserDefaults for Share Extension access
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults.set(receiptsRemaining, forKey: "\(prefix)_receiptsRemaining")
            sharedDefaults.set(daysUntilReset, forKey: "\(prefix)_daysUntilReset")
            // Save the user ID so the share extension can look up rate limit data
            // without needing Firebase Auth
            if let userId = currentUserId {
                sharedDefaults.set(userId, forKey: "rateLimit_currentUserId")
            }
            sharedDefaults.synchronize()
        }
    }
}
