//
//  LoginView.swift
//  dobby-ios
//
//  Created by Gilles Moenaert on 20/01/2026.
//

import SwiftUI
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var showResetPassword = false
    @State private var currentNonce: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Logo/Title
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        
                        Text("Welcome to Dobby")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(isSignUp ? "Create your account" : "Sign in to continue")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.bottom, 32)
                    
                    // Form
                    VStack(spacing: 16) {
                        // Email field
                        TextField("Email", text: $email)
                            .padding()
                            .background(Color(red: 1.0, green: 1.0, blue: 1.0))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .tint(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(isLoading)
                            .colorScheme(.light)
                        
                        // Password field
                        SecureField("Password", text: $password)
                            .padding()
                            .background(Color(red: 1.0, green: 1.0, blue: 1.0))
                            .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                            .tint(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .textContentType(isSignUp ? .newPassword : .password)
                            .disabled(isLoading)
                            .colorScheme(.light)
                        
                        // Error message
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Sign In/Up Button
                        Button {
                            Task {
                                await handleEmailAuth()
                            }
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                        
                        // Forgot Password
                        if !isSignUp {
                            Button("Forgot Password?") {
                                showResetPassword = true
                            }
                            .font(.footnote)
                            .disabled(isLoading)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Divider
                    HStack {
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 1)
                        
                        Text("OR")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                        
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .frame(height: 1)
                    }
                    .padding(.horizontal, 32)
                    
                    // Google Sign In
                    Button {
                        Task {
                            await handleGoogleSignIn()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            // Modern Google G logo
                            Image(systemName: "g.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(.black)
                            
                            Text("Continue with Google")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                    .disabled(isLoading)
                    
                    // Apple Sign In
                    SignInWithAppleButton(
                        onRequest: { request in
                            let nonce = randomNonceString()
                            currentNonce = nonce
                            request.requestedScopes = [.fullName, .email]
                            request.nonce = sha256(nonce)
                        },
                        onCompletion: { result in
                            Task {
                                await handleAppleSignIn(result: result)
                            }
                        }
                    )
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)
                    .disabled(isLoading)
                    
                    Spacer()
                    
                    // Toggle Sign Up/Sign In
                    Button {
                        isSignUp.toggle()
                        errorMessage = ""
                    } label: {
                        Text(isSignUp ? "Already have an account? **Sign In**" : "Don't have an account? **Sign Up**")
                            .font(.footnote)
                    }
                    .disabled(isLoading)
                    .padding(.bottom, 32)
                }
            }
            .preferredColorScheme(.dark)
            .alert("Reset Password", isPresented: $showResetPassword) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                
                Button("Send Reset Link") {
                    Task {
                        await handlePasswordReset()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enter your email address to receive a password reset link.")
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    private func handleEmailAuth() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        
        do {
            if isSignUp {
                try await authManager.signUp(email: email, password: password)
            } else {
                try await authManager.signIn(email: email, password: password)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func handleGoogleSignIn() async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase configuration error"
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            errorMessage = "Unable to get root view controller"
            return
        }
        
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token"
                return
            }
            
            let accessToken = result.user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            try await authManager.signInWithGoogle(credential: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func handlePasswordReset() async {
        guard !email.isEmpty else { return }
        
        do {
            try await authManager.resetPassword(email: email)
            errorMessage = "Password reset email sent!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Apple Sign In Helper Methods
    
    private func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        errorMessage = ""
        isLoading = true
        defer { isLoading = false }
        
        do {
            let authorization = try result.get()
            
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Failed to get Apple ID credential"
                return
            }
            
            guard let nonce = currentNonce else {
                errorMessage = "Invalid state: A login callback was received, but no login request was sent."
                return
            }
            
            guard let appleIDToken = appleIDCredential.identityToken else {
                errorMessage = "Unable to fetch identity token"
                return
            }
            
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                errorMessage = "Unable to serialize token string from data: \(appleIDToken.debugDescription)"
                return
            }
            
            let credential = OAuthProvider.appleCredential(withIDToken: idTokenString,
                                                          rawNonce: nonce,
                                                          fullName: appleIDCredential.fullName)
            
            try await authManager.signInWithApple(credential: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthenticationManager())
}
