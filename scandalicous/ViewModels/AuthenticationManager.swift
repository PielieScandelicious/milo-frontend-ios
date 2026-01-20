//
//  AuthenticationManager.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import FirebaseAuth
import Combine
import CryptoKit
import AuthenticationServices

class AuthenticationManager: ObservableObject {
    @Published var user: User?
    var isAuthenticated: Bool {
        user != nil
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let appGroupIdentifier = "group.com.deepmaind.scandalicious"
    
    init() {
        // Set the current user immediately
        self.user = Auth.auth().currentUser
        
        // Save token to shared storage if user is already authenticated
        if let user = self.user {
            Task {
                await self.saveTokenToSharedStorage(for: user)
            }
        }
        
        // Listen for authentication state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            
            // Save token when user state changes
            if let user = user {
                Task {
                    await self?.saveTokenToSharedStorage(for: user)
                }
            } else {
                // Clear token from shared storage on logout
                self?.clearTokenFromSharedStorage()
            }
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Token Management for Share Extension
    
    private func saveTokenToSharedStorage(for user: User) async {
        do {
            let token = try await user.getIDToken()
            
            print("💾 Attempting to save token to shared storage...")
            print("   Token length: \(token.count)")
            print("   Token prefix: \(token.prefix(20))...")
            
            // Method 1: Keychain (most reliable)
            let keychainSuccess = KeychainHelper.shared.saveToken(token)
            if keychainSuccess {
                print("✅ Token saved to Keychain")
            }
            
            // Method 2: UserDefaults (backup)
            if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                // Save token with MULTIPLE keys to test
                sharedDefaults.set(token, forKey: "firebase_auth_token")
                sharedDefaults.set(token, forKey: "SCANDALICIOUS_AUTH_TOKEN") // New obvious key
                sharedDefaults.set(token, forKey: "auth_token")
                
                // Also save a timestamp to verify write operations
                let timestamp = Date().timeIntervalSince1970
                sharedDefaults.set(timestamp, forKey: "firebase_auth_token_timestamp")
                sharedDefaults.set("TEST_VALUE_FROM_MAIN_APP", forKey: "SCANDALICIOUS_TEST")
                
                sharedDefaults.synchronize() // Force immediate write
                
                // Verify it was saved
                if let savedToken = sharedDefaults.string(forKey: "firebase_auth_token") {
                    print("✅ Token successfully saved and verified in UserDefaults")
                    print("   App Group: \(appGroupIdentifier)")
                    print("   Saved token length: \(savedToken.count)")
                    print("   Timestamp: \(timestamp)")
                    
                    // Debug: Print container URL
                    if let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) {
                        print("   Container path: \(containerURL.path)")
                    }
                } else {
                    print("❌ Token was set but could not be read back from UserDefaults!")
                }
            } else {
                print("❌ FAILED to access shared UserDefaults!")
                print("   App Group: \(appGroupIdentifier)")
            }
        } catch {
            print("❌ Failed to get Firebase ID token: \(error.localizedDescription)")
        }
    }
    
    private func clearTokenFromSharedStorage() {
        // Clear from Keychain
        KeychainHelper.shared.deleteToken()
        
        // Clear from UserDefaults
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults.removeObject(forKey: "firebase_auth_token")
            sharedDefaults.removeObject(forKey: "firebase_auth_token_timestamp")
            sharedDefaults.removeObject(forKey: "auth_token")
            print("🗑️ Cleared Firebase auth token from shared storage")
        }
    }
    
    /// Refresh the token in shared storage (call when app becomes active)
    func refreshTokenInSharedStorage() {
        guard let user = Auth.auth().currentUser else {
            print("⚠️ No user to refresh token for")
            return
        }
        
        Task {
            await saveTokenToSharedStorage(for: user)
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = result.user
        await saveTokenToSharedStorage(for: result.user)
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.user = result.user
        await saveTokenToSharedStorage(for: result.user)
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
        clearTokenFromSharedStorage()
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(credential: AuthCredential) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        self.user = result.user
        await saveTokenToSharedStorage(for: result.user)
    }
    
    // MARK: - Apple Sign In
    
    func signInWithApple(credential: AuthCredential) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        self.user = result.user
        await saveTokenToSharedStorage(for: result.user)
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
