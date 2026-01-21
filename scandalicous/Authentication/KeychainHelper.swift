//
//  KeychainHelper.swift
//  Scandalicious
//
//  Created for sharing auth token between app and extension
//

import Foundation
import Security

class KeychainHelper {
    static let shared = KeychainHelper()
    
    private let service = "com.deepmaind.scandalicious.auth"
    private let account = "firebase_token"
    
    // Keychain access group - optional, only use if entitlements are set up
    // For now, we'll try WITHOUT access group first, which still shares between app and extension
    private let useAccessGroup = false
    private let accessGroup = "group.com.deepmaind.scandalicious"
    
    private init() {}
    
    // MARK: - Save Token
    
    func saveToken(_ token: String) -> Bool {
        // Convert token to data
        guard let tokenData = token.data(using: .utf8) else {
            print("❌ Keychain: Failed to convert token to data")
            return false
        }
        
        // Delete existing token first
        deleteToken()
        
        // Create query - WITHOUT access group to avoid entitlement issues
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Only add access group if explicitly enabled (requires Keychain entitlements)
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Keychain: Token saved successfully")
            return true
        } else {
            print("❌ Keychain: Failed to save token (status: \(status), \(statusMessage(status)))")
            return false
        }
    }
    
    // MARK: - Retrieve Token
    
    func retrieveToken() -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let tokenData = result as? Data,
           let token = String(data: tokenData, encoding: .utf8) {
            print("✅ Keychain: Token retrieved successfully (\(token.count) chars)")
            return token
        } else {
            print("❌ Keychain: Failed to retrieve token (status: \(status), \(statusMessage(status)))")
            return nil
        }
    }
    
    // MARK: - Delete Token
    
    func deleteToken() {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        
        if useAccessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            // Success or item didn't exist - both are fine
        } else {
            print("⚠️ Keychain: Delete status: \(status), \(statusMessage(status))")
        }
    }
    
    // MARK: - Helper
    
    private func statusMessage(_ status: OSStatus) -> String {
        switch status {
        case errSecSuccess: return "Success"
        case errSecItemNotFound: return "Item not found"
        case errSecDuplicateItem: return "Duplicate item"
        case errSecParam: return "Invalid parameter"
        case errSecAllocate: return "Failed to allocate memory"
        case errSecNotAvailable: return "Not available"
        case errSecAuthFailed: return "Authentication failed"
        case errSecMissingEntitlement: return "Missing entitlement (need Keychain Access Group)"
        case -34018: return "Missing entitlement or device locked"
        default: return "Error code \(status)"
        }
    }
}
