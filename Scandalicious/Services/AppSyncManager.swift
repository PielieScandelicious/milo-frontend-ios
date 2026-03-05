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

        // Darwin notification: fires immediately when the share extension signals a new upload,
        // even if the main app is already in the foreground (didBecomeActiveNotification won't
        // fire in that case). Uses the singleton directly to avoid C-callback memory issues.
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                Task { @MainActor in
                    AppSyncManager.shared.checkForShareExtensionUploads()
                }
            },
            "com.deepmaind.scandalicious.shareExtensionDidUpload" as CFString,
            nil,
            .deliverImmediately
        )

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
        }
    }
}
