import Foundation

public protocol EncryptionProvider {
    func encrypt(_ data: Data) throws(EncryptionError) -> Data
    func decrypt(_ data: Data) throws(EncryptionError) -> Data
}
