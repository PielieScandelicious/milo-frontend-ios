//
//  ScandaLiciousApp.swift
//  Scandalicious
//
//  Created by Gilles Moenaert on 18/01/2026.
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct ScandaLiciousApp: App {
    @StateObject private var authManager: AuthenticationManager
    
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
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(authManager)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}

