#if os(Windows)
import Foundation
import Sodium

struct WindowsCryptoProvider: CryptoProvider {
    private let sodium = Sodium()

    func randomBytes(count: Int) -> Data {
        return sodium.randomBytes.buf(length: count) ?? Data()
    }

    func sha256(_ data: Data) -> Data {
        return sodium.genericHash.hash(message: data, outputLength: 32) ?? Data()
    }

    func hmacSHA256(_ data: Data, key: Data) -> Data {
        return sodium.auth.hmacsha256.authenticate(message: data, secretKey: key) ?? Data()
    }

    func chachaPolyEncrypt(_ plaintext: Data, key: Data, nonce: Data, aad: Data) throws -> Data {
        guard let sealed = sodium.aead.xchacha20poly1305ietf.seal(message: plaintext, additionalData: aad, secretKey: key, nonce: nonce) else { throw NSError(domain: "Crypto", code: -1) }
        return sealed.cipherText + sealed.mac
    }

    func chachaPolyDecrypt(_ ciphertext: Data, key: Data, nonce: Data, aad: Data) throws -> Data {
        guard ciphertext.count >= sodium.aead.xchacha20poly1305ietf.macBytes else { throw NSError(domain: "Crypto", code: -1) }
        let c = ciphertext.prefix(ciphertext.count - sodium.aead.xchacha20poly1305ietf.macBytes)
        let mac = ciphertext.suffix(sodium.aead.xchacha20poly1305ietf.macBytes)
        guard let msg = sodium.aead.xchacha20poly1305ietf.open(authenticatedCipherText: c + mac, additionalData: aad, nonce: nonce, secretKey: key) else { throw NSError(domain: "Crypto", code: -1) }
        return msg
    }

    func aesGCMEncrypt(_ plaintext: Data, key: Data) throws -> Data {
        guard let sealed = sodium.aead.aes256gcm.seal(message: plaintext, secretKey: key) else { throw NSError(domain: "Crypto", code: -1) }
        return sealed.combined
    }

    func aesGCMDecrypt(_ ciphertext: Data, key: Data) throws -> Data {
        guard let msg = sodium.aead.aes256gcm.open(authenticatedCipherText: ciphertext, secretKey: key) else { throw NSError(domain: "Crypto", code: -1) }
        return msg
    }

    func generatePrivateKey() -> Data {
        return sodium.box.keyPair()!.secretKey
    }

    func publicKey(from privateKey: Data) -> Data {
        let pk = sodium.box.keyPair(secretKey: privateKey)?.publicKey
        return pk ?? Data()
    }

    func sharedSecret(privateKey: Data, publicKey: Data) -> Data {
        return sodium.scalarmult.mult(base: publicKey, scalar: privateKey) ?? Data()
    }

    func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyByteCount: Int) -> Data {
        return sodium.pwHash.hash(outputLength: keyByteCount, passwd: password, salt: salt, opsLimit: UInt64(iterations), memLimit: 128 * 1024 * 1024) ?? Data()
    }
}
#endif
