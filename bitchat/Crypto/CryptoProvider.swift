import Foundation

protocol CryptoProvider {
    func randomBytes(count: Int) -> Data
    func sha256(_ data: Data) -> Data
    func hmacSHA256(_ data: Data, key: Data) -> Data
    func chachaPolyEncrypt(_ plaintext: Data, key: Data, nonce: Data, aad: Data) throws -> Data
    func chachaPolyDecrypt(_ ciphertext: Data, key: Data, nonce: Data, aad: Data) throws -> Data
    func aesGCMEncrypt(_ plaintext: Data, key: Data) throws -> Data
    func aesGCMDecrypt(_ ciphertext: Data, key: Data) throws -> Data
    func generatePrivateKey() -> Data
    func publicKey(from privateKey: Data) -> Data
    func sharedSecret(privateKey: Data, publicKey: Data) -> Data
    func pbkdf2SHA256(password: Data, salt: Data, iterations: Int, keyByteCount: Int) -> Data
}
