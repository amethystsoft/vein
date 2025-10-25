import SQLite
@MainActor
public protocol Persistable: ColumnType {
    associatedtype PersistentRepresentation: ColumnType
    var asPersistentRepresentation: PersistentRepresentation { get }
    init?(fromPersistent representation: PersistentRepresentation)
}
