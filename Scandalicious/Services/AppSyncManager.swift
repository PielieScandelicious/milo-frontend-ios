//
//  AppSyncManager.swift
//  Scandalicious
//
//  Share extension detection. Checks whether the share extension uploaded
//  a receipt while the main app was backgrounded and tells the processing
//  manager to pick it up.
//

import UIKit

@MainActor
class AppSyncManager {
    static let shared = AppSyncManager()

    // MARK: - Share Extension Detection

    private var lastCheckedUploadTimestamp: TimeInterval = 0

    // MARK: - Init

    private init() {
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

            // Tell processing manager to pick up any persisted receipts from the share extension
            ReceiptProcessingManager.shared.reloadPersistedReceipts()

            // Optimistically decrement the local rate limit counter
            RateLimitManager.shared.decrementReceiptLocal()
        }
    }
}
