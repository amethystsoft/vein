import SQLite
import Foundation

@MainActor
public protocol PersistedField {
    associatedtype WrappedType: Persistable
    var key: String? { get }
    var wrappedValue: WrappedType { get }
    var isLazy: Bool { get }
    
    static var sqliteTypeName: SQLiteTypeName { get }
}

extension PersistedField {
    var instanceKey: String {
        guard let key else {
            fatalError(MOCError.keyMissing(message: "raised by Field property of Type '\(WrappedType.self)'").localizedDescription)
        }
        return key
    }
    
    var expressible: Expressible {
        return switch Self.sqliteTypeName.isNull {
            case true:
                switch Self.sqliteTypeName {
                    case .integer: Expression<Int64?>(instanceKey)
                    case .real: Expression<Double?>(instanceKey)
                    case .text: Expression<String?>(instanceKey)
                    case .blob: Expression<Data?>(instanceKey)
                    default: fatalError()
                }
            case false:
                switch Self.sqliteTypeName {
                    case .integer: Expression<Int64>(instanceKey)
                    case .real: Expression<Double>(instanceKey)
                    case .text: Expression<String>(instanceKey)
                    case .blob: Expression<Data>(instanceKey)
                    default: fatalError()
                }
        }
    }
    
    public func decode(_ row: SQLite.Row) -> WrappedType {
        do {
            let typeName = WrappedType.sqliteTypeName
            
            switch typeName {
                case .integer:
                    let value = row[Expression<Int64>(instanceKey)]
                    return try WrappedType.decode(sqliteValue: .integer(value))
                case .real:
                    let value = row[Expression<Double>(instanceKey)]
                    return try WrappedType.decode(sqliteValue: .real(value))
                case .text:
                    let value = row[Expression<String>(instanceKey)]
                    return try WrappedType.decode(sqliteValue: .text(value))
                case .blob:
                    let value = row[Expression<Data>(instanceKey)]
                    return try WrappedType.decode(sqliteValue: .blob(value))
                case .null:
                    switch SQLiteTypeName.notNull(typeName) {
                        case .integer:
                            let value = row[Expression<Int64?>(instanceKey)]
                            if let value {
                                return try WrappedType.decode(sqliteValue: .integer(value))
                            }
                            return try WrappedType.decode(sqliteValue: .null)
                        case .real:
                            let value = row[Expression<Double?>(instanceKey)]
                            if let value {
                                return try WrappedType.decode(sqliteValue: .real(value))
                            }
                            return try WrappedType.decode(sqliteValue: .null)
                        case .text:
                            let value = row[Expression<String?>(instanceKey)]
                            if let value {
                                return try WrappedType.decode(sqliteValue: .text(value))
                            }
                            return try WrappedType.decode(sqliteValue: .null)
                        case .blob:
                            let value = row[Expression<Data?>(instanceKey)]
                            if let value {
                                return try WrappedType.decode(sqliteValue: .blob(value))
                            }
                            return try WrappedType.decode(sqliteValue: .null)
                        default:
                            fatalError("unexpectedly received SQLiteTypeName of null")
                    }
            }
        } catch {
            fatalError(error.localizedDescription)
        }
    }
}
