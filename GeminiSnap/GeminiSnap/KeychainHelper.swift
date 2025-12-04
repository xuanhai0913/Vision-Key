//
//  KeychainHelper.swift
//  GeminiSnap
//
//  Secure storage for API key using macOS Keychain
//

import Foundation
import Security

class KeychainHelper {
    private static let serviceName = "com.geminisnap.app"
    private static let accountName = "gemini-api-key"
    
    static func saveAPIKey(_ apiKey: String) -> Bool {
        // Delete existing key first
        deleteAPIKey()
        
        guard let data = apiKey.data(using: .utf8) else { return false }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    static func getAPIKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            // Fallback to environment variable for development
            return ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
        }
        
        return apiKey
    }
    
    @discardableResult
    static func deleteAPIKey() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    static func hasAPIKey() -> Bool {
        return getAPIKey() != nil && !getAPIKey()!.isEmpty
    }
}
