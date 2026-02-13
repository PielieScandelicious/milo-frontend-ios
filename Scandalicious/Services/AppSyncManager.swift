//
//  AppSyncManager.swift
//  Scandalicious
//
//  Centralized sync state manager. Owns the syncing/synced banner state
//  and share extension detection, replacing scattered logic across tabs.
//

import UIKit
import Combine

@MainActor
class AppSyncManager: ObservableObject {
    static let shared = AppSyncManager()

    // MARK: - Sync State

    enum SyncState: Equatable {
        case idle
        case syncing
        case synced
    }

    @Published private(set) var syncState: SyncState = .idle

    // MARK: - Share Extension Detection

    private var lastCheckedUploadTimestamp: TimeInterval = 0

    // MARK: - Private

    private var syncedResetTask: Task<Void, Never>?

    // MARK: - Init

    private init() {
        // Listen for receipt upload lifecycle
        NotificationCenter.default.addObserver(
            forName: .receiptUploadStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setSyncing()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .receiptUploadedSuccessfully,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setSynced()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .shareExtensionUploadDetected,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.setSyncing()
            }
        }

        // Listen for app becoming active to check share extension uploads
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkForShareExtensionUploads()
            }
        }

        // Initialize share extension timestamp
        initializeLastCheckedTimestamp()
    }

    // MARK: - State Transitions

    func setSyncing() {
        syncedResetTask?.cancel()
        syncedResetTask = nil
        syncState = .syncing
    }

    func setSynced() {
        syncedResetTask?.cancel()
        syncState = .synced
        syncedResetTask = Task {
            try? await Task.sleep(for: .seconds(2.0))
            guard !Task.isCancelled else { return }
            syncState = .idle
        }
    }

    func setIdle() {
        syncedResetTask?.cancel()
        syncedResetTask = nil
        syncState = .idle
    }

    // MARK: - Share Extension Detection

    private func initializeLastCheckedTimestamp() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            let persistedLastChecked = sharedDefaults.double(forKey: "lastCheckedUploadTimestamp")
            if persistedLastChecked > 0 {
                lastCheckedUploadTimestamp = persistedLastChecked
            } else {
                let existingTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")
                if existingTimestamp > 0 {
                    lastCheckedUploadTimestamp = existingTimestamp
                    sharedDefaults.set(existingTimestamp, forKey: "lastCheckedUploadTimestamp")
                }
            }
        }
    }

    func checkForShareExtensionUploads() {
        let appGroupIdentifier = "group.com.deepmaind.scandalicious"
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) else { return }

        let uploadTimestamp = sharedDefaults.double(forKey: "receipt_upload_timestamp")

        if uploadTimestamp > lastCheckedUploadTimestamp && uploadTimestamp > 0 {
            lastCheckedUploadTimestamp = uploadTimestamp
            sharedDefaults.set(uploadTimestamp, forKey: "lastCheckedUploadTimestamp")

            // Post notification so OverviewView can trigger its data refresh
            NotificationCenter.default.post(name: .shareExtensionUploadDetected, object: nil)

            // Optimistically decrement the local rate limit counter
            RateLimitManager.shared.decrementReceiptLocal()
        }
    }
}
