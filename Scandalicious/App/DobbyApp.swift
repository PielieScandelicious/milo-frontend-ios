//
//  ScandaLiciousApp.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn
import StoreKit
import UserNotifications

@main
struct ScandaLiciousApp: App {
    @StateObject private var authManager: AuthenticationManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCheckedSubscription = false
    @State private var hasPerformedInitialSync = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// Background sync manager singleton (not observable, uses NotificationCenter)
    private var backgroundSyncManager: BackgroundSyncManager { BackgroundSyncManager.shared }

    init() {
        // Configure Firebase FIRST
        FirebaseApp.configure()

        // Log environment configuration
        AppConfiguration.logConfiguration()

        // Now create the auth manager
        _authManager = StateObject(wrappedValue: AuthenticationManager())
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if authManager.isAuthenticated {
                    // Show onboarding if profile is not completed
                    if authManager.isCheckingProfile {
                        // Show loading while checking profile status
                        SyncLoadingView()
                    } else if !authManager.profileCompleted {
                        // Show onboarding for first-time users
                        OnboardingView()
                    } else {
                        // PAYWALL DISABLED: Always show content view
                        ContentView()
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(subscriptionManager)
            .onOpenURL { url in
                // Handle Google Sign-In OAuth callback
                if GIDSignIn.sharedInstance.handle(url) {
                    return
                }

                // Handle banking deep links (milo://banking/callback or milo://banking/error)
                if url.scheme == "milo" {
                    handleBankingDeepLink(url)
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(from: oldPhase, to: newPhase)
            }
            .onChange(of: authManager.isAuthenticated) { wasAuthenticated, isAuthenticated in
                // When auth state changes, refresh subscription status silently
                if isAuthenticated {
                    Task {
                        await subscriptionManager.loadProducts()
                        await subscriptionManager.updateSubscriptionStatus()
                        hasCheckedSubscription = true
                    }
                } else {
                    hasCheckedSubscription = false
                }
            }
            .task {
                // Load products and check subscription status silently on app launch
                if authManager.isAuthenticated {
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.updateSubscriptionStatus()
                }
                hasCheckedSubscription = true
            }
        }
    }

    // MARK: - Banking Deep Link Handling

    private func handleBankingDeepLink(_ url: URL) {
        guard let host = url.host else {
            print("🏦 [DeepLink] No host in URL: \(url)")
            return
        }

        print("🏦 [DeepLink] Handling banking deep link: \(url)")

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            print("🏦 [DeepLink] Failed to parse URL components")
            return
        }

        let queryItems = components.queryItems ?? []
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        switch host {
        case "banking":
            handleBankingPath(path: path, queryItems: queryItems)
        default:
            print("🏦 [DeepLink] Unknown host: \(host)")
        }
    }

    private func handleBankingPath(path: String, queryItems: [URLQueryItem]) {
        switch path {
        case "callback":
            // Success callback: milo://banking/callback?connection_id=xxx&status=success&accounts=2
            let connectionId = queryItems.first { $0.name == "connection_id" }?.value
            let status = queryItems.first { $0.name == "status" }?.value
            let accountsCount = Int(queryItems.first { $0.name == "accounts" }?.value ?? "0") ?? 0

            print("🏦 [DeepLink] Callback received - connection: \(connectionId ?? "nil"), status: \(status ?? "nil"), accounts: \(accountsCount)")

            let result = BankingCallbackResult(
                connectionId: connectionId,
                status: status == "success" ? .success : .error,
                accountCount: accountsCount,
                errorMessage: nil
            )

            NotificationCenter.default.post(
                name: .bankConnectionCompleted,
                object: nil,
                userInfo: ["result": result]
            )

        case "error":
            // Error callback: milo://banking/error?error=authorization_failed&message=User%20cancelled
            let error = queryItems.first { $0.name == "error" }?.value ?? "unknown_error"
            let message = queryItems.first { $0.name == "message" }?.value?.removingPercentEncoding

            print("🏦 [DeepLink] Error received - error: \(error), message: \(message ?? "nil")")

            let callbackStatus: BankingCallbackResult.CallbackStatus = error == "user_cancelled" ? .cancelled : .error

            let result = BankingCallbackResult(
                connectionId: nil,
                status: callbackStatus,
                accountCount: 0,
                errorMessage: message ?? error
            )

            NotificationCenter.default.post(
                name: .bankConnectionFailed,
                object: nil,
                userInfo: ["result": result]
            )

        default:
            print("🏦 [DeepLink] Unknown banking path: \(path)")
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // Refresh token when app becomes active
            authManager.refreshTokenInSharedStorage()

            // Silently refresh subscription status
            Task {
                await subscriptionManager.updateSubscriptionStatus()
            }

            // Auto-sync bank transactions when app becomes active
            if authManager.isAuthenticated && authManager.profileCompleted {
                Task {
                    await performAutoSync()
                }
            }

            // Clear badge when app opens
            backgroundSyncManager.clearBadge()

        case .background:
            // Schedule background refresh when app goes to background
            if authManager.isAuthenticated {
                backgroundSyncManager.scheduleBackgroundRefresh()
                print("🔄 [App] Scheduled background sync on entering background")
            }

        case .inactive:
            break

        @unknown default:
            break
        }
    }

    /// Perform auto-sync of bank transactions
    private func performAutoSync() async {
        // Skip if we've already done initial sync this session and it's been less than 5 minutes
        if hasPerformedInitialSync && !backgroundSyncManager.shouldRefresh {
            print("🔄 [App] Skipping auto-sync (recently synced)")
            return
        }

        print("🔄 [App] Performing auto-sync...")
        let result = await backgroundSyncManager.performForegroundSync()

        hasPerformedInitialSync = true

        if result.success {
            print("🔄 [App] Auto-sync complete: \(result.newTransactions) new, \(result.totalPending) pending")
        } else if let error = result.error {
            print("🔄 [App] Auto-sync failed: \(error)")
        }
    }
}

// MARK: - App Delegate

/// AppDelegate for registering background tasks early in app lifecycle
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Register background tasks
        BackgroundSyncManager.shared.registerBackgroundTasks()

        // Configure notification categories
        BackgroundSyncManager.shared.configureNotificationCategories()

        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self

        // Request notification permissions
        Task {
            _ = await BackgroundSyncManager.shared.requestNotificationPermissions()
        }

        print("🚀 [App] AppDelegate initialized with background sync support")
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if let type = userInfo["type"] as? String, type == "bank_transactions" {
            // Post notification for app to navigate to banking/review
            NotificationCenter.default.post(
                name: .bankTransactionsPendingReview,
                object: nil,
                userInfo: userInfo
            )

            // If review action tapped, signal immediate navigation
            if response.actionIdentifier == "REVIEW_ACTION" {
                NotificationCenter.default.post(
                    name: .bankTransactionsPendingReview,
                    object: nil,
                    userInfo: ["shouldNavigate": true]
                )
            }
        }

        completionHandler()
    }
}

