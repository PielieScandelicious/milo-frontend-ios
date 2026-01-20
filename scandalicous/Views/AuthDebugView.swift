//
//  AuthDebugView.swift
//  Scandalicious
//
//  Created for debugging Share Extension authentication
//

import SwiftUI
import FirebaseAuth

struct AuthDebugView: View {
    @State private var debugInfo: String = "Tap 'Check Auth' to start"
    @State private var tokenInSharedStorage: String = ""
    private let appGroupIdentifier = "group.com.deepmaind.scandalicious"
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // Current User Info
                    GroupBox(label: Label("Current User", systemImage: "person.circle.fill")) {
                        if let user = Auth.auth().currentUser {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("UID: \(user.uid)")
                                    .font(.caption)
                                    .textSelection(.enabled)
                                
                                Text("Email: \(user.email ?? "N/A")")
                                    .font(.caption)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                        } else {
                            Text("No user logged in")
                                .foregroundColor(.red)
                                .padding(8)
                        }
                    }
                    
                    // Shared Storage Info
                    GroupBox(label: Label("Shared Storage", systemImage: "externaldrive.fill")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("App Group: \(appGroupIdentifier)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            if tokenInSharedStorage.isEmpty {
                                Text("No token in shared storage")
                                    .foregroundColor(.red)
                            } else {
                                Text("Token exists (\(tokenInSharedStorage.count) chars)")
                                    .foregroundColor(.green)
                                
                                Text(tokenInSharedStorage.prefix(50) + "...")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                    }
                    
                    // Debug Info
                    GroupBox(label: 
                        HStack {
                            Label("Debug Logs", systemImage: "doc.text.fill")
                            Spacer()
                            Button(action: copyToClipboard) {
                                Label("Copy All", systemImage: "doc.on.doc")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    ) {
                        ScrollView {
                            Text(debugInfo)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 300)
                        .padding(8)
                    }
                    
                    // Actions
                    VStack(spacing: 12) {
                        // Primary actions
                        Button(action: checkAuthentication) {
                            Label("Check Authentication", systemImage: "magnifyingglass")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: forceRefreshToken) {
                            Label("Force Refresh Token", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        // Copy everything button
                        Button(action: copyCompleteReport) {
                            Label("Copy Complete Report", systemImage: "doc.on.clipboard")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        
                        Button(action: clearSharedStorage) {
                            Label("Clear Shared Storage", systemImage: "trash")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Auth Debug")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                checkAuthentication()
            }
        }
    }
    
    private func checkAuthentication() {
        var info = "🔍 Starting authentication check...\n\n"
        
        // Check Firebase user
        if let user = Auth.auth().currentUser {
            info += "✅ Firebase User:\n"
            info += "   UID: \(user.uid)\n"
            info += "   Email: \(user.email ?? "N/A")\n\n"
            
            Task {
                do {
                    let token = try await user.getIDToken()
                    await MainActor.run {
                        debugInfo += "✅ Got token from Firebase:\n"
                        debugInfo += "   Length: \(token.count)\n"
                        debugInfo += "   Prefix: \(token.prefix(30))...\n\n"
                    }
                } catch {
                    await MainActor.run {
                        debugInfo += "❌ Failed to get token: \(error.localizedDescription)\n\n"
                    }
                }
            }
        } else {
            info += "❌ No Firebase user found\n\n"
        }
        
        // Check shared storage
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            info += "✅ Can access App Group UserDefaults\n"
            info += "   Group: \(appGroupIdentifier)\n\n"
            
            if let token = sharedDefaults.string(forKey: "firebase_auth_token") {
                info += "✅ Token found in shared storage:\n"
                info += "   Length: \(token.count)\n"
                info += "   Prefix: \(token.prefix(30))...\n\n"
                tokenInSharedStorage = token
            } else {
                info += "❌ NO token in shared storage\n"
                info += "   Key 'firebase_auth_token' is missing\n\n"
                tokenInSharedStorage = ""
            }
            
            // List all keys
            let allKeys = Array(sharedDefaults.dictionaryRepresentation().keys).sorted()
            info += "📋 All keys in shared storage (\(allKeys.count)):\n"
            for (index, key) in allKeys.prefix(10).enumerated() {
                info += "   [\(index + 1)] \(key)\n"
            }
            if allKeys.count > 10 {
                info += "   ... and \(allKeys.count - 10) more\n"
            }
            if allKeys.isEmpty {
                info += "   (empty)\n"
            }
        } else {
            info += "❌ CANNOT access App Group UserDefaults\n"
            info += "   This is a critical error!\n"
            info += "   Check that App Groups is enabled in:\n"
            info += "   - Main app target\n"
            info += "   - Share Extension target\n"
        }
        
        debugInfo = info
    }
    
    private func forceRefreshToken() {
        debugInfo += "\n🔄 Force refreshing token...\n"
        
        guard let user = Auth.auth().currentUser else {
            debugInfo += "❌ No user to refresh token for\n"
            return
        }
        
        Task {
            do {
                let token = try await user.getIDToken(forcingRefresh: true)
                
                await MainActor.run {
                    debugInfo += "✅ Got fresh token from Firebase\n"
                    debugInfo += "   Length: \(token.count)\n"
                    
                    // Save to shared storage
                    if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
                        sharedDefaults.set(token, forKey: "firebase_auth_token")
                        sharedDefaults.synchronize()
                        
                        debugInfo += "✅ Saved to shared storage\n"
                        
                        // Verify
                        if let savedToken = sharedDefaults.string(forKey: "firebase_auth_token") {
                            debugInfo += "✅ Verified: token is readable\n"
                            debugInfo += "   Saved length: \(savedToken.count)\n"
                            tokenInSharedStorage = savedToken
                        } else {
                            debugInfo += "❌ Could not read back token!\n"
                        }
                    } else {
                        debugInfo += "❌ Could not access shared storage!\n"
                    }
                    
                    debugInfo += "\n"
                }
            } catch {
                await MainActor.run {
                    debugInfo += "❌ Error: \(error.localizedDescription)\n\n"
                }
            }
        }
    }
    
    private func clearSharedStorage() {
        debugInfo += "\n🗑️ Clearing shared storage...\n"
        
        if let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier) {
            sharedDefaults.removeObject(forKey: "firebase_auth_token")
            sharedDefaults.synchronize()
            debugInfo += "✅ Cleared\n\n"
            tokenInSharedStorage = ""
        } else {
            debugInfo += "❌ Could not access shared storage\n\n"
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = debugInfo
        
        // Add visual feedback
        debugInfo += "\n📋 Copied to clipboard!\n"
        
        // Reset the feedback message after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if debugInfo.hasSuffix("\n📋 Copied to clipboard!\n") {
                    debugInfo = String(debugInfo.dropLast("\n📋 Copied to clipboard!\n".count))
                }
            }
        }
    }
    
    private func copyCompleteReport() {
        var report = "===== SCANDALICIOUS AUTH DEBUG REPORT =====\n\n"
        
        // User info
        report += "USER INFO:\n"
        if let user = Auth.auth().currentUser {
            report += "  ✅ Logged in\n"
            report += "  UID: \(user.uid)\n"
            report += "  Email: \(user.email ?? "N/A")\n"
        } else {
            report += "  ❌ Not logged in\n"
        }
        report += "\n"
        
        // Shared storage info
        report += "SHARED STORAGE:\n"
        report += "  App Group: \(appGroupIdentifier)\n"
        if tokenInSharedStorage.isEmpty {
            report += "  ❌ No token in shared storage\n"
        } else {
            report += "  ✅ Token exists (\(tokenInSharedStorage.count) chars)\n"
            report += "  Token preview: \(tokenInSharedStorage.prefix(50))...\n"
        }
        report += "\n"
        
        // Debug logs
        report += "DEBUG LOGS:\n"
        report += debugInfo
        report += "\n"
        
        report += "===== END OF REPORT =====\n"
        
        UIPasteboard.general.string = report
        
        // Visual feedback
        debugInfo += "\n📋 Complete report copied to clipboard!\n"
        
        // Reset the feedback message after 2 seconds
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if debugInfo.hasSuffix("\n📋 Complete report copied to clipboard!\n") {
                    debugInfo = String(debugInfo.dropLast("\n📋 Complete report copied to clipboard!\n".count))
                }
            }
        }
    }
}

#Preview {
    AuthDebugView()
}
