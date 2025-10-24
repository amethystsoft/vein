import Foundation

@MainActor
public final class EncryptionManager {
    public static var shared: EncryptionProvider?
    
    public static var instance: EncryptionProvider {
        guard let shared else {
            fatalError("EncryptionManager.shared not set")
        }
        return shared
    }
}
