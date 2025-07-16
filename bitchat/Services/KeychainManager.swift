//
// KeychainManager.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import os.log

#if os(Windows)
import WinSDK
#else
import Security
#endif

#if os(Windows)
class KeychainManager {
    static let shared = KeychainManager()

    private init() {}

    private func utf16(_ string: String) -> [WCHAR] {
        return Array(string.utf16) + [0]
    }

    private func saveData(_ data: Data, account: String) -> Bool {
        var cred = CREDENTIALW()
        let target = utf16(account)
        return data.withUnsafeBytes { bytes in
            cred.Type = DWORD(CRED_TYPE_GENERIC)
            cred.TargetName = PWSTR(mutating: target)
            cred.CredentialBlobSize = DWORD(data.count)
            cred.CredentialBlob = UnsafeMutablePointer<UInt8>(mutating: bytes.bindMemory(to: UInt8.self).baseAddress)
            cred.Persist = DWORD(CRED_PERSIST_LOCAL_MACHINE)
            return CredWriteW(&cred, 0) != FALSE
        }
    }

    private func loadData(account: String) -> Data? {
        var pcred: PCREDENTIALW?
        let target = utf16(account)
        if CredReadW(target, DWORD(CRED_TYPE_GENERIC), 0, &pcred) == FALSE {
            return nil
        }
        guard let cred = pcred?.pointee, let blob = cred.CredentialBlob else { return nil }
        let data = Data(bytes: blob, count: Int(cred.CredentialBlobSize))
        CredFree(pcred)
        return data
    }

    private func deleteData(account: String) -> Bool {
        let target = utf16(account)
        return CredDeleteW(target, DWORD(CRED_TYPE_GENERIC), 0) != FALSE
    }

    func saveChannelPassword(_ password: String, for channel: String) -> Bool {
        guard let data = password.data(using: .utf8) else { return false }
        return saveData(data, account: "channel_\(channel)")
    }

    func getChannelPassword(for channel: String) -> String? {
        guard let data = loadData(account: "channel_\(channel)") else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func deleteChannelPassword(for channel: String) -> Bool {
        return deleteData(account: "channel_\(channel)")
    }

    func getAllChannelPasswords() -> [String: String] {
        var result: [String: String] = [:]
        var count: DWORD = 0
        var creds: PCREDENTIALW?
        if CredEnumerateW(nil, 0, &count, &creds) != FALSE, let list = creds {
            for i in 0..<Int(count) {
                let cred = list[i]
                if let name = cred.TargetName { let str = String(decodingCString: name, as: UTF16.self)
                    if str.hasPrefix("channel_") {
                        let channel = String(str.dropFirst(8))
                        if let data = loadData(account: str), let pwd = String(data: data, encoding: .utf8) {
                            result[channel] = pwd
                        }
                    }
                }
            }
            CredFree(creds)
        }
        return result
    }

    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool {
        return saveData(keyData, account: "identity_\(key)")
    }

    func getIdentityKey(forKey key: String) -> Data? {
        return loadData(account: "identity_\(key)")
    }

    func deleteIdentityKey(forKey key: String) -> Bool {
        return deleteData(account: "identity_\(key)")
    }

    func deleteAllKeychainData() -> Bool {
        var any = false
        var count: DWORD = 0
        var creds: PCREDENTIALW?
        if CredEnumerateW(nil, 0, &count, &creds) != FALSE, let list = creds {
            for i in 0..<Int(count) {
                let cred = list[i]
                if let name = cred.TargetName {
                    _ = deleteData(account: String(decodingCString: name, as: UTF16.self))
                    any = true
                }
            }
            CredFree(creds)
        }
        return any
    }
}
#else
import Security

class KeychainManager {
    static let shared = KeychainManager()
    
    // Use consistent service name for all keychain items
    private let service = "chat.bitchat"
    private let appGroup = "group.chat.bitchat"
    
    private init() {
        // Clean up legacy keychain items on first run
        cleanupLegacyKeychainItems()
    }
    
    private func cleanupLegacyKeychainItems() {
        // Check if we've already done cleanup
        let cleanupKey = "bitchat.keychain.cleanup.v2"
        if UserDefaults.standard.bool(forKey: cleanupKey) {
            return
        }
        
        
        // List of old service names to migrate from
        let legacyServices = [
            "com.bitchat.passwords",
            "com.bitchat.deviceidentity",
            "com.bitchat.noise.identity",
            "chat.bitchat.passwords",
            "bitchat.keychain"
        ]
        
        var migratedItems = 0
        
        // Try to migrate identity keys
        for oldService in legacyServices {
            // Check for noise identity key
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: oldService,
                kSecAttrAccount as String: "identity_noiseStaticKey",
                kSecReturnData as String: true
            ]
            
            var result: AnyObject?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            
            if status == errSecSuccess, let data = result as? Data {
                // Save to new service
                if saveIdentityKey(data, forKey: "noiseStaticKey") {
                    migratedItems += 1
                }
                // Delete from old service
                let deleteQuery: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: oldService,
                    kSecAttrAccount as String: "identity_noiseStaticKey"
                ]
                SecItemDelete(deleteQuery as CFDictionary)
            }
        }
        
        // Clean up all other legacy items
        for oldService in legacyServices {
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: oldService
            ]
            
            SecItemDelete(deleteQuery as CFDictionary)
        }
        
        
        // Mark cleanup as done
        UserDefaults.standard.set(true, forKey: cleanupKey)
    }
    
    
    private func isSandboxed() -> Bool {
        #if os(macOS)
        let environment = ProcessInfo.processInfo.environment
        return environment["APP_SANDBOX_CONTAINER_ID"] != nil
        #else
        return false
        #endif
    }
    
    // MARK: - Channel Passwords
    
    func saveChannelPassword(_ password: String, for channel: String) -> Bool {
        let key = "channel_\(channel)"
        return save(password, forKey: key)
    }
    
    func getChannelPassword(for channel: String) -> String? {
        let key = "channel_\(channel)"
        return retrieve(forKey: key)
    }
    
    func deleteChannelPassword(for channel: String) -> Bool {
        let key = "channel_\(channel)"
        return delete(forKey: key)
    }
    
    func getAllChannelPasswords() -> [String: String] {
        var passwords: [String: String] = [:]
        
        // Build query without kSecReturnData to avoid error -50
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        // For sandboxed apps, use the app group
        if isSandboxed() {
            query[kSecAttrAccessGroup as String] = appGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                if let account = item[kSecAttrAccount as String] as? String,
                   account.hasPrefix("channel_") {
                    // Now retrieve the actual password data for this specific item
                    let channel = String(account.dropFirst(8)) // Remove "channel_" prefix
                    if let password = getChannelPassword(for: channel) {
                        passwords[channel] = password
                    }
                }
            }
        }
        
        return passwords
    }
    
    // MARK: - Identity Keys
    
    func saveIdentityKey(_ keyData: Data, forKey key: String) -> Bool {
        let fullKey = "identity_\(key)"
        return saveData(keyData, forKey: fullKey)
    }
    
    func getIdentityKey(forKey key: String) -> Data? {
        let fullKey = "identity_\(key)"
        return retrieveData(forKey: fullKey)
    }
    
    func deleteIdentityKey(forKey key: String) -> Bool {
        return delete(forKey: "identity_\(key)")
    }
    
    // MARK: - Generic Operations
    
    private func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        return saveData(data, forKey: key)
    }
    
    private func saveData(_ data: Data, forKey key: String) -> Bool {
        // Delete any existing item first to ensure clean state
        _ = delete(forKey: key)
        
        // Build query with all necessary attributes for sandboxed apps
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrService as String: service,
            // Important for sandboxed apps: make it accessible when unlocked
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Add a label for easier debugging
        query[kSecAttrLabel as String] = "bitchat-\(key)"
        
        // For sandboxed apps, use the app group for sharing between app instances
        if isSandboxed() {
            query[kSecAttrAccessGroup as String] = appGroup
        }
        
        // For sandboxed macOS apps, we need to ensure the item is NOT synchronized
        #if os(macOS)
        query[kSecAttrSynchronizable as String] = false
        #endif
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        if status == errSecSuccess {
            return true
        } else if status == -34018 {
            SecurityLogger.logError(NSError(domain: "Keychain", code: -34018), context: "Missing keychain entitlement", category: SecurityLogger.keychain)
        } else if status != errSecDuplicateItem {
            SecurityLogger.logError(NSError(domain: "Keychain", code: Int(status)), context: "Error saving to keychain", category: SecurityLogger.keychain)
        }
        
        return false
    }
    
    private func retrieve(forKey key: String) -> String? {
        guard let data = retrieveData(forKey: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func retrieveData(forKey key: String) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        // For sandboxed apps, use the app group
        if isSandboxed() {
            query[kSecAttrAccessGroup as String] = appGroup
        }
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess {
            return result as? Data
        } else if status == -34018 {
            SecurityLogger.logError(NSError(domain: "Keychain", code: -34018), context: "Missing keychain entitlement", category: SecurityLogger.keychain)
        }
        
        return nil
    }
    
    private func delete(forKey key: String) -> Bool {
        // Build basic query
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: service
        ]
        
        // For sandboxed apps, use the app group
        if isSandboxed() {
            query[kSecAttrAccessGroup as String] = appGroup
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Cleanup
    
    func deleteAllPasswords() -> Bool {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword
        ]
        
        // Add service if not empty
        if !service.isEmpty {
            query[kSecAttrService as String] = service
        }
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // Force cleanup to run again (for development/testing)
    func resetCleanupFlag() {
        UserDefaults.standard.removeObject(forKey: "bitchat.keychain.cleanup.v2")
    }
    
    
    // Delete ALL keychain data for panic mode
    func deleteAllKeychainData() -> Bool {
        
        var totalDeleted = 0
        
        // Search without service restriction to catch all items
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let searchStatus = SecItemCopyMatching(searchQuery as CFDictionary, &result)
        
        if searchStatus == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                var shouldDelete = false
                let account = item[kSecAttrAccount as String] as? String ?? ""
                let service = item[kSecAttrService as String] as? String ?? ""
                
                // ONLY delete if service name contains "bitchat"
                // This is the safest approach - we only touch items we know are ours
                if service.lowercased().contains("bitchat") {
                    shouldDelete = true
                }
                
                if shouldDelete {
                    // Build delete query with all available attributes for precise deletion
                    var deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword
                    ]
                    
                    if !account.isEmpty {
                        deleteQuery[kSecAttrAccount as String] = account
                    }
                    if !service.isEmpty {
                        deleteQuery[kSecAttrService as String] = service
                    }
                    
                    // Add access group if present
                    if let accessGroup = item[kSecAttrAccessGroup as String] as? String,
                       !accessGroup.isEmpty && accessGroup != "test" {
                        deleteQuery[kSecAttrAccessGroup as String] = accessGroup
                    }
                    
                    let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                    if deleteStatus == errSecSuccess {
                        totalDeleted += 1
                    }
                }
            }
        }
        
        // Also try to delete by known service names (in case we missed any)
        let knownServices = [
            "chat.bitchat",
            "com.bitchat.passwords",
            "com.bitchat.deviceidentity", 
            "com.bitchat.noise.identity",
            "chat.bitchat.passwords",
            "bitchat.keychain",
            "bitchat",
            "com.bitchat"
        ]
        
        for serviceName in knownServices {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName
            ]
            
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess {
                totalDeleted += 1
            }
        }
        
        
        return totalDeleted > 0
    }
    
    // MARK: - Debug
    
    func verifyIdentityKeyExists() -> Bool {
        let key = "identity_noiseStaticKey"
        return retrieveData(forKey: key) != nil
    }
    
    // Aggressive cleanup for legacy items - can be called manually
    func aggressiveCleanupLegacyItems() -> Int {
        var deletedCount = 0
        
        // List of KNOWN bitchat service names from our development history
        let knownBitchatServices = [
            "com.bitchat.passwords",
            "com.bitchat.deviceidentity",
            "com.bitchat.noise.identity",
            "chat.bitchat.passwords",
            "bitchat.keychain",
            "Bitchat",
            "BitChat"
        ]
        
        // First, delete all items from known legacy services
        for legacyService in knownBitchatServices {
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: legacyService
            ]
            
            let status = SecItemDelete(deleteQuery as CFDictionary)
            if status == errSecSuccess {
                deletedCount += 1
            }
        }
        
        // Now search for items that have our specific account patterns with bitchat service names
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnAttributes as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(searchQuery as CFDictionary, &result)
        
        if status == errSecSuccess, let items = result as? [[String: Any]] {
            for item in items {
                let account = item[kSecAttrAccount as String] as? String ?? ""
                let service = item[kSecAttrService as String] as? String ?? ""
                
                // ONLY delete if service name contains "bitchat" somewhere
                // This ensures we never touch other apps' keychain items
                var shouldDelete = false
                
                // Check if service contains "bitchat" (case insensitive) but NOT our current service
                let serviceLower = service.lowercased()
                if service != self.service && serviceLower.contains("bitchat") {
                    shouldDelete = true
                }
                
                if shouldDelete {
                    // Build precise delete query
                    let deleteQuery: [String: Any] = [
                        kSecClass as String: kSecClassGenericPassword,
                        kSecAttrService as String: service,
                        kSecAttrAccount as String: account
                    ]
                    
                    let deleteStatus = SecItemDelete(deleteQuery as CFDictionary)
                    if deleteStatus == errSecSuccess {
                        deletedCount += 1
                    }
                }
            }
        }
        
        return deletedCount
    }
}#endif
