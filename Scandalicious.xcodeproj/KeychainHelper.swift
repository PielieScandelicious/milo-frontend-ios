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
    
    // App Group for Keychain sharing
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
        
        // Create query
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
            kSecValueData as String: tokenData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Add to keychain
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            print("✅ Keychain: Token saved successfully")
            return true
        } else {
            print("❌ Keychain: Failed to save token (status: \(status))")
            return false
        }
    }
    
    // MARK: - Retrieve Token
    
    func retrieveToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let tokenData = result as? Data,
           let token = String(data: tokenData, encoding: .utf8) {
            print("✅ Keychain: Token retrieved successfully (\(token.count) chars)")
            return token
        } else {
            print("❌ Keychain: Failed to retrieve token (status: \(status))")
            return nil
        }
    }
    
    // MARK: - Delete Token
    
    func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: accessGroup
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        if status == errSecSuccess || status == errSecItemNotFound {
            print("✅ Keychain: Token deleted (or didn't exist)")
        } else {
            print("⚠️ Keychain: Delete status: \(status)")
        }
    }
}
