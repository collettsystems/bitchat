//
// NoiseChannelEncryption.swift
// bitchat
//
// This is free and unencumbered software released into the public domain.
// For more information, see <https://unlicense.org>
//

import Foundation
import CryptoKit
import os.log

// Crypto abstraction
private let defaultCryptoProvider: CryptoProvider = CryptoKitProvider()

// MARK: - Noise Channel Encryption

class NoiseChannelEncryption {
    private let crypto: CryptoProvider

    init(crypto: CryptoProvider = defaultCryptoProvider) {
        self.crypto = crypto
    }

    // Channel keys derived from passwords
    private var channelKeys: [String: SymmetricKey] = [:]
    private let keyQueue = DispatchQueue(label: "chat.bitchat.noise.channels", attributes: .concurrent)
    
    // Key rotation support
    private let keyRotation = NoiseChannelKeyRotation()
    private var rotationEnabled: [String: Bool] = [:] // channel -> enabled
    
    // Replay protection
    private var receivedNonces: Set<String> = []
    private let nonceExpirationTime: TimeInterval = 600 // 10 minutes
    private var nonceCleanupTimer: Timer?
    
    // MARK: - Channel Key Management
    
    /// Derive a channel key from password
    func deriveChannelKey(from password: String, channel: String, creatorFingerprint: String? = nil) -> SymmetricKey {
        // Use PBKDF2 with channel name + creator fingerprint as salt
        // This prevents rainbow table attacks across different channel instances
        var saltComponents = "bitchat-channel-\(channel)"
        if let fingerprint = creatorFingerprint {
            saltComponents += "-\(fingerprint)"
        }
        let salt = saltComponents.data(using: .utf8)!
        
        // Increased iterations for better security (OWASP recommends 210,000 for PBKDF2-SHA256)
        let keyData = crypto.pbkdf2SHA256(
            password: password.data(using: .utf8)!,
            salt: salt,
            iterations: 210_000,
            keyByteCount: 32
        )
        
        return SymmetricKey(data: keyData)
    }
    
    /// Set password for a channel
    func setChannelPassword(_ password: String, for channel: String, creatorFingerprint: String? = nil) {
        let key = deriveChannelKey(from: password, channel: channel, creatorFingerprint: creatorFingerprint)
        
        keyQueue.async(flags: .barrier) {
            self.channelKeys[channel] = key
        }
        
        // Store in keychain
        _ = KeychainManager.shared.saveChannelPassword(password, for: channel)
    }
    
    /// Get channel key
    func getChannelKey(for channel: String) -> SymmetricKey? {
        return keyQueue.sync {
            return channelKeys[channel]
        }
    }
    
    /// Load channel password from keychain
    func loadChannelPassword(for channel: String) -> Bool {
        guard let password = KeychainManager.shared.getChannelPassword(for: channel) else {
            return false
        }
        
        setChannelPassword(password, for: channel)
        return true
    }
    
    /// Remove channel password
    func removeChannelPassword(for channel: String) {
        keyQueue.async(flags: .barrier) {
            self.channelKeys.removeValue(forKey: channel)
        }
        
        _ = KeychainManager.shared.deleteChannelPassword(for: channel)
    }
    
    // MARK: - Replay Protection
    
    private func scheduleNonceCleanup() {
        DispatchQueue.main.async { [weak self] in
            self?.nonceCleanupTimer?.invalidate()
            self?.nonceCleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                self?.cleanupExpiredNonces()
            }
        }
    }
    
    private func cleanupExpiredNonces() {
        keyQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // In production, we'd need to store timestamps with nonces
            // For now, we'll clear all nonces periodically
            if self.receivedNonces.count > 1000 {
                self.receivedNonces.removeAll()
            }
        }
    }
    
    deinit {
        nonceCleanupTimer?.invalidate()
    }
    
    // MARK: - Channel Message Encryption
    
    /// Encrypt message for a channel
    func encryptChannelMessage(_ message: String, for channel: String) throws -> Data {
        guard let key = getChannelKey(for: channel) else {
            throw NoiseChannelError.noChannelKey
        }
        
        let messageData = message.data(using: .utf8)!
        
        // Generate random nonce
        let nonce = crypto.randomBytes(count: 12)

        // Encrypt with channel key
        let ciphertext = try crypto.chachaPolyEncrypt(messageData, key: key.withUnsafeBytes { Data($0) }, nonce: nonce, aad: Data())

        // Return nonce + ciphertext
        return nonce + ciphertext
    }
    
    /// Decrypt channel message
    func decryptChannelMessage(_ encryptedData: Data, for channel: String) throws -> String {
        guard let key = getChannelKey(for: channel) else {
            throw NoiseChannelError.noChannelKey
        }
        
        guard encryptedData.count >= 12 + 16 else { // nonce + tag minimum
            throw NoiseChannelError.invalidCiphertext
        }
        
        // Extract components
        let nonceData = encryptedData.prefix(12)
        let ciphertext = encryptedData.dropFirst(12).dropLast(16)
        let tag = encryptedData.suffix(16)
        
        // Create sealed box
        let combined = ciphertext + tag
        let decryptedData = try crypto.chachaPolyDecrypt(combined, key: key.withUnsafeBytes { Data($0) }, nonce: nonceData, aad: Data())
        
        guard let message = String(data: decryptedData, encoding: .utf8) else {
            throw NoiseChannelError.decryptionFailed
        }
        
        return message
    }
    
    // MARK: - Channel Key Sharing
    
    /// Create encrypted channel key packet for sharing via Noise session
    func createChannelKeyPacket(password: String, channel: String) -> Data? {
        // Generate a unique nonce for replay protection
        let nonceData = crypto.randomBytes(count: 16)
        let nonce = nonceData.base64EncodedString()
        
        let packet = ChannelKeyPacket(
            channel: channel,
            password: password,
            timestamp: Date(),
            nonce: nonce
        )
        
        return try? JSONEncoder().encode(packet)
    }
    
    /// Process received channel key packet
    func processChannelKeyPacket(_ data: Data) -> (channel: String, password: String)? {
        guard let packet = try? JSONDecoder().decode(ChannelKeyPacket.self, from: data) else {
            return nil
        }
        
        // Verify timestamp is recent (within 5 minutes)
        let age = Date().timeIntervalSince(packet.timestamp)
        guard age < 300 else { return nil }
        
        return keyQueue.sync(flags: .barrier) {
            // Check for replay attack
            if receivedNonces.contains(packet.nonce) {
                SecurityLogger.logSecurityEvent(.replayAttackDetected(channel: packet.channel), level: .warning)
                return nil // This nonce was already processed
            }
            
            // Add nonce to received set
            receivedNonces.insert(packet.nonce)
            
            // Schedule cleanup if not already scheduled
            if nonceCleanupTimer == nil {
                scheduleNonceCleanup()
            }
            
            return (packet.channel, packet.password)
        }
    }
}

// MARK: - Supporting Types

private struct ChannelKeyPacket: Codable {
    let channel: String
    let password: String
    let timestamp: Date
    let nonce: String
}

enum NoiseChannelError: Error {
    case noChannelKey
    case invalidCiphertext
    case decryptionFailed
}

// MARK: - PBKDF2 Implementation

private struct PBKDF2<H: HashFunction> {
    let password: Data
    let salt: Data
    let iterations: Int
    let keyByteCount: Int
    
    init(password: Data, salt: Data, iterations: Int, keyByteCount: Int) {
        self.password = password
        self.salt = salt
        self.iterations = iterations
        self.keyByteCount = keyByteCount
    }
    
    func makeIterator() -> Data {
        var derivedKey = Data()
        var blockNum: UInt32 = 1
        
        while derivedKey.count < keyByteCount {
            var block = salt
            withUnsafeBytes(of: blockNum.bigEndian) { bytes in
                block.append(contentsOf: bytes)
            }
            
            var u = Data(HMAC<H>.authenticationCode(for: block, using: SymmetricKey(data: password)))
            var xor = u
            
            for _ in 1..<iterations {
                u = Data(HMAC<H>.authenticationCode(for: u, using: SymmetricKey(data: password)))
                for i in 0..<xor.count {
                    xor[i] ^= u[i]
                }
            }
            
            derivedKey.append(xor)
            blockNum += 1
        }
        
        return derivedKey.prefix(keyByteCount)
    }
}