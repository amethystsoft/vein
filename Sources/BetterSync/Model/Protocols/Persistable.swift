import SQLite

public nonisolated protocol Persistable: ColumnType {
    associatedtype PersistentRepresentation: ColumnType
    var asPersistentRepresentation: PersistentRepresentation { get }
    init?(fromPersistent representation: PersistentRepresentation)
}
