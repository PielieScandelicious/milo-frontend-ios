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

@main
struct ScandaLiciousApp: App {
    @StateObject private var authManager: AuthenticationManager
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCheckedSubscription = false

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
                // Refresh token when app becomes active
                if newPhase == .active {
                    authManager.refreshTokenInSharedStorage()
                    // Silently refresh subscription status
                    Task {
                        await subscriptionManager.updateSubscriptionStatus()
                    }
                }
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
}

