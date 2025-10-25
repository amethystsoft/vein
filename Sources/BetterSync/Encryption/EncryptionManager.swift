import Foundation

public final class EncryptionManager {
    @MainActor
    public static var shared: EncryptionProvider?
    
    @MainActor
    public static var instance: EncryptionProvider {
        guard let shared else {
            fatalError("EncryptionManager.shared not set")
        }
        return shared
    }
}
