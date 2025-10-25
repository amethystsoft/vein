import SQLite
import Foundation
extension Bool: Persistable {
    public typealias PersistentRepresentation = Int64
    public var asPersistentRepresentation: PersistentRepresentation {
        self ? 1 : 0
    }
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation >= 1 ? true: false
    }
}
extension Data: Persistable {
    public typealias PersistentRepresentation = Data
    public var asPersistentRepresentation: PersistentRepresentation {
        self
    }
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
}
extension String: Persistable {
    public typealias PersistentRepresentation = String
    public var asPersistentRepresentation: PersistentRepresentation {
        self
    }
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
}
extension UUID: Persistable {
    public typealias PersistentRepresentation = String
    public var asPersistentRepresentation: PersistentRepresentation {
        self.uuidString
    }
    public init?(fromPersistent representation: PersistentRepresentation) {
        guard let uuid = UUID(uuidString: representation) else { return nil }
        self = uuid
    }
}
extension Optional: Persistable where Wrapped: Persistable {
    public typealias PersistentRepresentation = Wrapped?
    public var asPersistentRepresentation: PersistentRepresentation {
        switch self {
            case .none:
                return nil
            case .some(let wrapped):
                return wrapped
        }
    }
    public init?(fromPersistent representation: PersistentRepresentation) {
        guard let uuid = Optional(fromPersistent: representation) else { return nil }
        self = uuid
    }
}
