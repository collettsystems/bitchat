import Foundation
import CryptoKit
import Security

struct CryptoKitProvider: CryptoProvider {
    func randomBytes(count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        _ = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        return Data(bytes)
    }

    func sha256(_ data: Data) -> Data {
        return Data(SHA256.hash(data: data))
    }

    func hmacSHA256(_ data: Data, key: Data) -> Data {
        let mac = HMAC<SHA256>.authenticationCode(for: data, using: SymmetricKey(data: key))
        return Data(mac)
    }

    func chachaPolyEncrypt(_ plaintext: Data, key: Data, nonce: Data, aad: Data) throws -> Data {
        let k = SymmetricKey(data: key)
        let n = try ChaChaPoly.Nonce(data: nonce)
        let sealed = try ChaChaPoly.seal(plaintext, using: k, nonce: n, authenticating: aad)
        return sealed.ciphertext + sealed.tag
    }

    func chachaPolyDecrypt(_ ciphertext: Data, key: Data, nonce: Data, aad: Data) throws -> Data {
        let k = SymmetricKey(data: key)
        let n = try ChaChaPoly.Nonce(data: nonce)
        guard ciphertext.count >= 16 else { throw NSError(domain: "Crypto", code: -1) }
        let c = ciphertext.prefix(ciphertext.count - 16)
        let tag = ciphertext.suffix(16)
        let box = try ChaChaPoly.SealedBox(nonce: n, ciphertext: c, tag: tag)
        return try ChaChaPoly.open(box, using: k, authenticating: aad)
    }

    func aesGCMEncrypt(_ plaintext: Data, key: Data) throws -> Data {
        let k = SymmetricKey(data: key)
        let sealed = try AES.GCM.seal(plaintext, using: k)
        return sealed.combined!
    }

    func aesGCMDecrypt(_ ciphertext: Data, key: Data) throws -> Data {
        let k = SymmetricKey(data: key)
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: k)
    }

    func generatePrivateKey() -> Data {
        let key = Curve25519.KeyAgreement.PrivateKey()
        return key.rawRepresentation
    }

    func publicKey(from privateKey: Data) -> Data {
        let priv = try! Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        return priv.publicKey.rawRepresentation
    }

    func sharedSecret(privateKey: Data, publicKey: Data) -> Data {
        let priv = try! Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
        let pub = try! Curve25519.KeyAgreement.PublicKey(rawRepresentation: publicKey)
        let secret = try! priv.sharedSecretFromKeyAgreement(with: pub)
        return secret.withUnsafeBytes { Data($0) }
    }

    func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyByteCount: Int) -> Data {
        return PBKDF2<SHA256>(password: password, salt: salt, iterations: iterations, keyByteCount: keyByteCount).makeIterator()
    }
}
