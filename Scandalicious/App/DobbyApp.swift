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
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(1.5)
                    } else if !authManager.profileCompleted {
                        // Show onboarding for first-time users
                        OnboardingView()
                    } else if !hasCheckedSubscription || subscriptionManager.subscriptionStatus.isActive {
                        // Show content immediately - subscription check happens in background
                        // Only show paywall after check confirms no active subscription
                        ContentView()
                    } else {
                        // Show paywall - user must subscribe to access the app
                        PaywallView()
                            .interactiveDismissDisabled(true)
                    }
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .environmentObject(subscriptionManager)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
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
}

