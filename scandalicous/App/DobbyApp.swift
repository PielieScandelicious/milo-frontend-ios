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
    @State private var isCheckingSubscription = true

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
                    // Show loading while checking subscription
                    if isCheckingSubscription {
                        ProgressView("Checking subscription...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color(.systemBackground))
                    }
                    // Show content only if user has active subscription or trial
                    else if subscriptionManager.subscriptionStatus.isActive {
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
                    // Also refresh subscription status
                    Task {
                        await subscriptionManager.updateSubscriptionStatus()
                    }
                }
            }
            .onChange(of: authManager.isAuthenticated) { wasAuthenticated, isAuthenticated in
                // When auth state changes, refresh subscription status
                if isAuthenticated {
                    isCheckingSubscription = true
                    Task {
                        await subscriptionManager.loadProducts()
                        await subscriptionManager.updateSubscriptionStatus()
                        isCheckingSubscription = false
                    }
                }
            }
            .task {
                // Load products and check subscription status on app launch
                if authManager.isAuthenticated {
                    await subscriptionManager.loadProducts()
                    await subscriptionManager.updateSubscriptionStatus()
                }
                isCheckingSubscription = false
            }
        }
    }
}

