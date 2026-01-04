import Foundation
public protocol PersistentIdentifier {
    var uuid: UUID { get }
}
extension UUID: PersistentIdentifier {
    public var uuid: UUID { self }
}
