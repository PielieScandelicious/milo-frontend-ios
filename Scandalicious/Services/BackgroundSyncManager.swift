//
//  BackgroundSyncManager.swift
//  Scandalicious
//
//  Created by Claude on 02/02/2026.
//

import Foundation
import BackgroundTasks
import UserNotifications
import FirebaseAuth
import UIKit

// MARK: - Background Sync Manager

/// Manages automatic bank transaction syncing in background and foreground
/// Handles BGTaskScheduler for periodic refresh and local notifications
final class BackgroundSyncManager: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = BackgroundSyncManager()

    // MARK: - Task Identifiers

    /// Background app refresh task identifier (must match Info.plist)
    static let backgroundRefreshTaskId = "com.deepmaind.scandalicious.bankSync"

    // MARK: - State (thread-safe via serial queue)

    private let stateQueue = DispatchQueue(label: "com.deepmaind.scandalicious.backgroundsync")
    private var _isSyncing = false
    private var _lastSyncDate: Date?
    private var _lastSyncResult: SyncResult?

    var isSyncing: Bool {
        stateQueue.sync { _isSyncing }
    }

    var lastSyncDate: Date? {
        stateQueue.sync { _lastSyncDate }
    }

    var lastSyncResult: SyncResult? {
        stateQueue.sync { _lastSyncResult }
    }

    // MARK: - Private Properties

    private let apiService = BankingAPIService.shared

    /// Minimum interval between background syncs (15 minutes)
    private let minimumBackgroundInterval: TimeInterval = 15 * 60

    /// Key for storing last sync date in UserDefaults
    private let lastSyncDateKey = "BackgroundSyncManager.lastSyncDate"

    /// Key for storing pending transaction count for comparison
    private let lastPendingCountKey = "BackgroundSyncManager.lastPendingCount"

    // MARK: - Initialization

    private init() {
        // Load last sync date from UserDefaults
        if let date = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date {
            _lastSyncDate = date
        }
    }

    // MARK: - Background Task Registration

    /// Register background tasks with the system - call this in app launch
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.backgroundRefreshTaskId,
            using: nil
        ) { [weak self] task in
            guard let self = self, let refreshTask = task as? BGAppRefreshTask else { return }
            Task {
                await self.handleBackgroundRefresh(task: refreshTask)
            }
        }
    }

    /// Schedule the next background refresh
    func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: minimumBackgroundInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Background refresh scheduling failed
        }
    }

    /// Cancel any pending background refresh tasks
    func cancelBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: Self.backgroundRefreshTaskId)
    }

    // MARK: - Notification Permissions

    /// Request notification permissions from the user
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            return false
        }
    }

    /// Check current notification authorization status
    func checkNotificationPermissions() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Sync Operations

    /// Perform automatic sync when app becomes active
    /// This is the main entry point for foreground auto-sync
    func performForegroundSync() async -> SyncResult {
        // Thread-safe check and set
        let shouldProceed = stateQueue.sync { () -> Bool in
            if _isSyncing { return false }
            _isSyncing = true
            return true
        }

        guard shouldProceed else {
            return SyncResult(newTransactions: 0, totalPending: 0, success: false, error: "Sync already in progress")
        }

        // Check if user is authenticated
        guard Auth.auth().currentUser != nil else {
            stateQueue.sync { _isSyncing = false }
            return SyncResult(newTransactions: 0, totalPending: 0, success: false, error: "Not authenticated")
        }

        let result = await performSync(isBackground: false)

        // Update state thread-safely
        stateQueue.sync {
            _isSyncing = false
            _lastSyncDate = Date()
            _lastSyncResult = result
        }
        UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)

        // Post notification for UI updates on main thread
        // Show notification when there are pending transactions (even if not "new" from this sync)
        if result.success && result.totalPending > 0 {
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .bankTransactionsPendingReview,
                    object: nil,
                    userInfo: [
                        "newTransactions": result.newTransactions,
                        "totalPending": result.totalPending
                    ]
                )
            }
        }

        return result
    }

    /// Handle background refresh task
    private func handleBackgroundRefresh(task: BGAppRefreshTask) async {
        // Schedule the next refresh
        scheduleBackgroundRefresh()

        // Set expiration handler
        task.expirationHandler = { [weak self] in
            self?.stateQueue.sync { self?._isSyncing = false }
        }

        // Check if user is authenticated
        guard Auth.auth().currentUser != nil else {
            task.setTaskCompleted(success: false)
            return
        }

        // Perform sync
        let result = await performSync(isBackground: true)

        // Update state thread-safely
        stateQueue.sync {
            _lastSyncDate = Date()
            _lastSyncResult = result
        }
        UserDefaults.standard.set(Date(), forKey: lastSyncDateKey)

        // Show local notification if new transactions found
        if result.success && result.newTransactions > 0 {
            await showNewTransactionsNotification(count: result.newTransactions, total: result.totalPending)
        }

        task.setTaskCompleted(success: result.success)
    }

    /// Core sync logic - fetches and syncs all accounts
    private func performSync(isBackground: Bool) async -> SyncResult {
        do {
            // Get accounts
            let accounts = try await apiService.getAccounts()

            if accounts.isEmpty {
                return SyncResult(newTransactions: 0, totalPending: 0, success: true, error: nil)
            }

            var totalNew = 0
            var syncedAccounts = 0

            // Sync each account
            for account in accounts {
                do {
                    let syncResult = try await apiService.syncAccountTransactions(accountId: account.id)
                    totalNew += syncResult.newTransactions
                    syncedAccounts += 1
                } catch BankingAPIError.connectionExpired {
                    // Skip expired connections silently
                } catch {
                    // Error syncing account - continue with next
                }
            }

            // Get updated pending count
            let pendingResponse = try await apiService.getPendingTransactions(page: 1, pageSize: 1)
            let totalPending = pendingResponse.total

            // Store pending count for comparison
            let previousPending = UserDefaults.standard.integer(forKey: lastPendingCountKey)
            UserDefaults.standard.set(totalPending, forKey: lastPendingCountKey)

            // Calculate truly new transactions (for notification purposes)
            let newForNotification = max(0, totalPending - previousPending)

            return SyncResult(
                newTransactions: isBackground ? newForNotification : totalNew,
                totalPending: totalPending,
                success: true,
                error: nil
            )

        } catch {
            return SyncResult(newTransactions: 0, totalPending: 0, success: false, error: error.localizedDescription)
        }
    }

    // MARK: - Local Notifications

    /// Show a local notification for new transactions
    private func showNewTransactionsNotification(count: Int, total: Int) async {
        let content = UNMutableNotificationContent()
        content.title = "New Bank Transactions"
        content.body = count == 1
            ? "You have 1 new transaction to review"
            : "You have \(count) new transactions to review"
        content.sound = .default
        content.badge = NSNumber(value: total)

        // Add category for actions
        content.categoryIdentifier = "BANK_TRANSACTIONS"

        // Add user info for deep linking
        content.userInfo = [
            "type": "bank_transactions",
            "count": count,
            "total": total
        ]

        // Create trigger (immediate)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        // Create request
        let request = UNNotificationRequest(
            identifier: "bank-transactions-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            // Failed to schedule notification
        }
    }

    /// Configure notification categories and actions
    func configureNotificationCategories() {
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_ACTION",
            title: "Review Now",
            options: [.foreground]
        )

        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Later",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: "BANK_TRANSACTIONS",
            actions: [reviewAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Clear badge count
    @MainActor
    func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
    }

    /// Update badge with pending transaction count
    @MainActor
    func updateBadge(count: Int) {
        UIApplication.shared.applicationIconBadgeNumber = count
    }
}

// MARK: - Sync Result

extension BackgroundSyncManager {
    struct SyncResult: Sendable {
        let newTransactions: Int
        let totalPending: Int
        let success: Bool
        let error: String?
    }
}

// MARK: - Convenience Extensions

extension BackgroundSyncManager {

    /// Check if enough time has passed since last sync for background refresh
    var shouldRefresh: Bool {
        guard let lastSync = lastSyncDate else { return true }
        return Date().timeIntervalSince(lastSync) >= minimumBackgroundInterval
    }

    /// Format last sync date for display
    var lastSyncDescription: String? {
        guard let date = lastSyncDate else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
