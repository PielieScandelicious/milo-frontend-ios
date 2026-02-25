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
    @StateObject private var languageManager = LanguageManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var hasCheckedSubscription = false
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

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
                        // PAYWALL DISABLED: Paywall is bypassed during beta/pre-launch.
                        // SubscriptionManager.subscriptionStatus is hardcoded to .subscribed.
                        // To re-enable: restore subscription checking logic in SubscriptionManager.updateSubscriptionStatus()
                        // and gate ContentView behind subscriptionManager.subscriptionStatus.isActive.
                        ContentView()
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(subscriptionManager)
            .environmentObject(languageManager)
            .onOpenURL { url in
                // Handle Google Sign-In OAuth callback
                GIDSignIn.sharedInstance.handle(url)
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
                        await CategoryRegistryManager.shared.loadIfNeeded()
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
                    // Load category hierarchy for mid-level category lookups
                    await CategoryRegistryManager.shared.loadIfNeeded()
                }
                hasCheckedSubscription = true
            }
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

        case .background:
            break

        case .inactive:
            break

        @unknown default:
            break
        }
    }
}

// MARK: - App Delegate

/// AppDelegate for app lifecycle handling
class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        return true
    }
}
