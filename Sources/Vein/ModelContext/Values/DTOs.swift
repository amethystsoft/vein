import Foundation
import SQLite

public struct PersistedFieldDTO: Sendable {
    let key: String
    let id: ULID
    let schema: String
    let sqliteType: SQLiteTypeName
    let enclosingObjectID: ObjectIdentifier
    
    public init(key: String, id: ULID, schema: String, sqliteType: SQLiteTypeName, enclosingObjectID: ObjectIdentifier) {
        self.key = key
        self.id = id
        self.schema = schema
        self.sqliteType = sqliteType
        self.enclosingObjectID = enclosingObjectID
    }
}

public struct FieldInformation: Sendable {
    let typeName: SQLiteTypeName
    let key: String
    let eagerLoaded: Bool
    
    public nonisolated init(_ typeName: SQLiteTypeName, _ key: String, _ eagerLoaded: Bool) {
        self.typeName = typeName
        self.key = key
        self.eagerLoaded = eagerLoaded
    }
}

extension FieldInformation: Hashable {
    public static func == (lhs: FieldInformation, rhs: FieldInformation) -> Bool {
        lhs.typeName == rhs.typeName && lhs.key == rhs.key
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(typeName)
        hasher.combine(key)
    }
}

extension [FieldInformation] {
    var eagerLoaded: [FieldInformation] {
        self.filter { $0.eagerLoaded }
    }
}

extension FieldInformation {
    package var expressible: Expressible {
        return switch typeName.isNull {
            case true:
                switch SQLiteTypeName.notNull(typeName) {
                    case .integer: Expression<Int64?>(key)
                    case .real: Expression<Double?>(key)
                    case .text: Expression<String?>(key)
                    case .blob: Expression<Data?>(key)
                    default:
                        fatalError(
                            "Unexpectedly found null. Check SQLiteTypeName.notNull() for logic errors"
                        )
                }
            case false:
                switch typeName {
                    case .integer: Expression<Int64>(key)
                    case .real: Expression<Double>(key)
                    case .text: Expression<String>(key)
                    case .blob: Expression<Data>(key)
                    default:
                        fatalError(
                            "Unexpectedly found null. Check SQLiteTypeName.notNull() for logic errors"
                        )
                }
        }
    }
    
    package func addRetroactively(to schema: String, on context: ManagedObjectContext) throws {
        switch SQLiteTypeName.notNull(typeName) {
            case .integer:
                try context.run(
                    Table(schema).addColumn(Expression<Int64?>(key))
                )
            case .real:
                try context.run(
                    Table(schema).addColumn(Expression<Double?>(key))
                )
            case .text:
                try context.run(
                    Table(schema).addColumn(Expression<String?>(key))
                )
            case .blob:
                try context.run(
                    Table(schema).addColumn(Expression<Data?>(key))
                )
            case .null:
                fatalError(
                    "Unexpectedly found null. Check SQLiteTypeName.notNull() for logic errors"
                )
        }
    }
}
