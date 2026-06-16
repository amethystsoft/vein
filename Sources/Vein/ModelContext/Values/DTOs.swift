import Foundation
import SQLiteDB

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
    let relationshipToType: (any PersistentModel.Type)?
    
    public nonisolated init(
        _ typeName: SQLiteTypeName,
        _ key: String,
        _ eagerLoaded: Bool,
        _ relationshipToType: (any PersistentModel.Type)? = nil
    ) {
        self.typeName = typeName
        self.key = key
        self.eagerLoaded = eagerLoaded
        self.relationshipToType = relationshipToType
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
                    case .integer: SQLExpression<Int64?>(key)
                    case .real: SQLExpression<Double?>(key)
                    case .text: SQLExpression<String?>(key)
                    case .blob: SQLExpression<Data?>(key)
                    default:
                        fatalError(
                            "Unexpectedly found null. Check SQLiteTypeName.notNull() for logic errors"
                        )
                }
            case false:
                switch typeName {
                    case .integer: SQLExpression<Int64>(key)
                    case .real: SQLExpression<Double>(key)
                    case .text: SQLExpression<String>(key)
                    case .blob: SQLExpression<Data>(key)
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
                    Table(schema).addColumn(SQLExpression<Int64?>(key))
                )
            case .real:
                try context.run(
                    Table(schema).addColumn(SQLExpression<Double?>(key))
                )
            case .text:
                try context.run(
                    Table(schema).addColumn(SQLExpression<String?>(key))
                )
            case .blob:
                try context.run(
                    Table(schema).addColumn(SQLExpression<Data?>(key))
                )
            case .null:
                fatalError(
                    "Unexpectedly found null. Check SQLiteTypeName.notNull() for logic errors"
                )
        }
    }
}
