//
//  AuthenticationManager.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import Foundation
import FirebaseAuth
import Combine

class AuthenticationManager: ObservableObject {
    @Published var user: User?
    @Published var profileCompleted: Bool = false
    @Published var isCheckingProfile: Bool = true

    var isAuthenticated: Bool {
        user != nil
    }

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private let appGroupIdentifier = "group.com.deepmaind.scandalicious"
    private let profileCompletedKey = "user_profile_completed"

    init() {
        // Set the current user immediately
        self.user = Auth.auth().currentUser

        // Load profile completed status from UserDefaults
        self.profileCompleted = UserDefaults.standard.bool(forKey: profileCompletedKey)

        // Save token to shared storage if user is already authenticated
        if let user = self.user {
            Task {
                await self.saveTokenToSharedStorage(for: user)
                await self.checkProfileStatus()
            }
        } else {
            self.isCheckingProfile = false
        }

        // Listen for authentication state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user

            // Save token when user state changes
            if let user = user {
                Task {
                    await self?.saveTokenToSharedStorage(for: user)
                    await self?.checkProfileStatus()
                }
            } else {
                // Clear token from shared storage on logout
                self?.clearTokenFromSharedStorage()
                self?.clearProfileStatus()
                self?.clearAllCachedData()
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

            // Method 1: Keychain (most reliable)
            let keychainSuccess = KeychainHelper.shared.saveToken(token)

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
            }
        } catch {
            // Failed to get Firebase ID token
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
        }
    }

    /// Refresh the token in shared storage (call when app becomes active)
    func refreshTokenInSharedStorage() {
        guard let user = Auth.auth().currentUser else {
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
        clearAllCachedData()
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

    // MARK: - Profile Status Management

    func checkProfileStatus() async {
        await MainActor.run {
            self.isCheckingProfile = true
        }

        // First check local storage
        let localProfileCompleted = UserDefaults.standard.bool(forKey: profileCompletedKey)

        if localProfileCompleted {
            // If we already know profile is completed, no need to check backend
            await MainActor.run {
                self.profileCompleted = true
                self.isCheckingProfile = false
            }
            return
        }

        // Check backend for profile completion status
        do {
            let profile = try await ProfileAPIService().getProfile()
            await MainActor.run {
                self.profileCompleted = profile.profileCompleted
                self.isCheckingProfile = false

                // Save to local storage
                if profile.profileCompleted {
                    UserDefaults.standard.set(true, forKey: self.profileCompletedKey)
                }
            }
        } catch {
            // If profile not found or error, treat as incomplete
            await MainActor.run {
                self.profileCompleted = false
                self.isCheckingProfile = false
            }
        }
    }

    func markProfileAsCompleted() {
        self.profileCompleted = true
        UserDefaults.standard.set(true, forKey: profileCompletedKey)
    }

    private func clearProfileStatus() {
        self.profileCompleted = false
        self.isCheckingProfile = false
        UserDefaults.standard.removeObject(forKey: profileCompletedKey)
    }

    /// Clear all cached user data (disk cache, split cache) on sign-out or account switch
    private func clearAllCachedData() {
        Task { @MainActor in
            AppDataCache.shared.invalidateAll()
            SplitCacheManager.shared.clearCache()
        }
    }
}
