import SQLite
public protocol Persistable: Codable, ColumnType {
    associatedtype PersistentRepresentation: ColumnType
    var asPersistentRepresentation: PersistentRepresentation { get }
    init?(fromPersistent representation: PersistentRepresentation)
}
