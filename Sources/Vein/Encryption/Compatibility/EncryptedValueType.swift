import Foundation

public protocol EncryptedValueType {
    associatedtype WrappedType: Codable
    var wrappedValue: WrappedType { get set }
}
