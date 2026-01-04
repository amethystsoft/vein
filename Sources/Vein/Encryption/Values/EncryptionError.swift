import Foundation

public enum EncryptionError: Error {
    case invalidPasswordFormatting
    case sealingFailed
    case unsealingFailed
}

extension EncryptionError {
    var description: String {
        switch self {
        case .invalidPasswordFormatting:
            "Password isn't valid UTF-8"
        case .sealingFailed:
            "Failed to seal data"
        case .unsealingFailed:
            "Failed to unseal data"
        }
    }
}
