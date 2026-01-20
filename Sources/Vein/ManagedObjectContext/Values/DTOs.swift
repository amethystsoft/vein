import Foundation
import SQLite

public struct PersistedFieldDTO: Sendable {
    let key: String
    let id: Int64
    let schema: String
    let sqliteType: SQLiteTypeName
    let enclosingObjectID: ObjectIdentifier
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
                switch typeName {
                    case .integer: Expression<Int64?>(key)
                    case .real: Expression<Double?>(key)
                    case .text: Expression<String?>(key)
                    case .blob: Expression<Data?>(key)
                    default: fatalError()
                }
            case false:
                switch typeName {
                    case .integer: Expression<Int64>(key)
                    case .real: Expression<Double>(key)
                    case .text: Expression<String>(key)
                    case .blob: Expression<Data>(key)
                    default: fatalError()
                }
        }
    }
}
