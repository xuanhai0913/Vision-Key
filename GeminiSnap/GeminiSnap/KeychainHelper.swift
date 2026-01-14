//
//  KeychainHelper.swift
//  GeminiSnap
//
//  Secure storage for API keys using macOS Keychain
//  Supports multiple providers: Gemini, Deepseek, OpenAI
//

import Foundation
import Security

class KeychainHelper {
    private static let serviceName = "com.geminisnap.app"
    
    // Provider key identifiers
    static let geminiKey = "gemini-api-key"
    static let deepseekKey = "deepseek-api-key"
    static let openaiKey = "openai-api-key"
    
    // MARK: - Multi-Provider Support (String-based)
    
    /// Save API key for a specific provider key identifier
    static func saveAPIKey(_ apiKey: String, forKey accountName: String) -> Bool {
        deleteAPIKey(forKey: accountName)
        
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
    
    /// Get API key for a specific provider key identifier
    static func getAPIKey(forKey accountName: String) -> String? {
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
            return nil
        }
        
        return apiKey
    }
    
    /// Delete API key for a specific provider key identifier
    @discardableResult
    static func deleteAPIKey(forKey accountName: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: accountName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    /// Check if API key exists for a specific provider key identifier
    static func hasAPIKey(forKey accountName: String) -> Bool {
        guard let key = getAPIKey(forKey: accountName) else { return false }
        return !key.isEmpty
    }
    
    // MARK: - Legacy Support (backward compatibility)
    
    /// Save API key (legacy - defaults to Gemini)
    static func saveAPIKey(_ apiKey: String) -> Bool {
        return saveAPIKey(apiKey, forKey: geminiKey)
    }
    
    /// Get API key (legacy - defaults to Gemini, with env fallback)
    static func getAPIKey() -> String? {
        if let key = getAPIKey(forKey: geminiKey), !key.isEmpty {
            return key
        }
        // Fallback to environment variable for development
        return ProcessInfo.processInfo.environment["GEMINI_API_KEY"]
    }
    
    /// Delete API key (legacy - defaults to Gemini)
    @discardableResult
    static func deleteAPIKey() -> Bool {
        return deleteAPIKey(forKey: geminiKey)
    }
    
    /// Check if has API key (legacy - defaults to Gemini)
    static func hasAPIKey() -> Bool {
        return hasAPIKey(forKey: geminiKey)
    }
}


