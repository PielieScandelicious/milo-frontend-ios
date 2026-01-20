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
    var isAuthenticated: Bool {
        user != nil
    }
    
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        // Set the current user immediately
        self.user = Auth.auth().currentUser
        
        // Listen for authentication state changes
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
        }
    }
    
    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }
    
    // MARK: - Email/Password Authentication
    
    func signIn(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        self.user = result.user
    }
    
    func signUp(email: String, password: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        self.user = result.user
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
        self.user = nil
    }
    
    // MARK: - Google Sign In
    
    func signInWithGoogle(credential: AuthCredential) async throws {
        let result = try await Auth.auth().signIn(with: credential)
        self.user = result.user
    }
    
    // MARK: - Password Reset
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
