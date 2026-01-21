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
                    // Show content only if user has active subscription or trial
                    if subscriptionManager.subscriptionStatus.isActive {
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
            .task {
                // Load products and check subscription status on app launch
                await subscriptionManager.loadProducts()
                await subscriptionManager.updateSubscriptionStatus()
            }
        }
    }
}

