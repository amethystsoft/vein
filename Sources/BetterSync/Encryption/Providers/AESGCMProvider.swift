import Crypto
import Foundation

public class AESGCMProvider: EncryptionProvider {
    private let key: SymmetricKey
    private let nonce: AES.GCM.Nonce
    
    // Key Derivation via Password
    public init(password: String) throws(EncryptionError) {
        let salt = "default-salt".data(using: .utf8) ?? Data()
        guard let passwordData = password.data(using: .utf8) else {
            throw EncryptionError.invalidPasswordFormatting
        }
        let keyMaterial = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: passwordData),
            salt: salt,
            info: Data("encryption-key".utf8),
            outputByteCount: 32
        )
        self.key = keyMaterial
        self.nonce = AES.GCM.Nonce()
    }
    
    public init(key: SymmetricKey) {
        self.key = key
        self.nonce = AES.GCM.Nonce()
    }
    
    public func encrypt(_ data: Data) throws(EncryptionError) -> Data {
        do {
            let sealedBox = try AES.GCM.seal(data, using: key)
            guard let combined = sealedBox.combined else {
                throw EncryptionError.sealingFailed
            }
            return combined
        } catch {
            throw .sealingFailed
        }
    }
    
    public func decrypt(_ data: Data) throws(EncryptionError) -> Data {
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            return try AES.GCM.open(sealedBox, using: key)
        } catch {
            throw .unsealingFailed
        }
    }
}
