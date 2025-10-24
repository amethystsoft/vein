import Foundation

enum EncryptedWrapperError: Error {
    case encoding(EncodingError)
    case decoding(DecodingError)
    case encryption(EncryptionError)
}

extension EncryptedWrapperError {
    var description: String {
        switch self {
        case .encoding(let error):
            "Encoding failed with: \(error.localizedDescription)"
        case .decoding(let error):
            "Decoding failed with: \(error.localizedDescription)"
        case .encryption(let encryptionError):
            encryptionError.description
        }
    }
}
