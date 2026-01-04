import Foundation

public final class EncryptionManager: @unchecked Sendable {
    public static let shared = EncryptionManager()
    public var provider: EncryptionProvider?
    
    public var instance: EncryptionProvider {
        guard let provider else {
            fatalError("EncryptionManager.shared not set")
        }
        return provider
    }
}
