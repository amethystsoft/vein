import Foundation
import SQLite

public enum SQLiteTypeName: Sendable, Hashable {
    case integer, real, text, blob
    indirect case null(SQLiteTypeName)
    
    var isNull: Bool {
        return switch self {
            case .null: true
            default: false
        }
    }
    
    public static func notNull(_ type: SQLiteTypeName) -> SQLiteTypeName {
        if case .null(let inner) = type {
            return .notNull(inner)
        } else {
            return type
        }
    }
    
    var castTypeString: String {
        switch self {
            case .integer:
                return "INTEGER"
            case .real:
                return "REAL"
            case .text:
                return "TEXT"
            case .blob:
                return "BLOB"
            case .null(let inner):
                return inner.castTypeString
        }
    }
}

public enum SQLiteValue: Sendable, Hashable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
    
    package init(typeName: SQLiteTypeName, key: String, row: SQLite.Row) {
        if typeName.isNull {
            switch SQLiteTypeName.notNull(typeName) {
                case .integer:
                    if let value = row[Expression<Int64?>(key)] {
                        self = .integer(value)
                    }
                    self = .null
                case .real:
                    if let value = row[Expression<Double?>(key)] {
                        self = .real(value)
                    }
                    self = .null
                case .text:
                    if let value = row[Expression<String?>(key)] {
                        self = .text(value)
                    }
                    self = .null
                case .blob:
                    if let value = row[Expression<Data?>(key)] {
                        self = .blob(value)
                    }
                    self = .null
                case .null:
                    self = .null
            }
            return
        }
        switch typeName {
            case .integer:
                self = .integer(row[Expression<Int64>(key)])
            case .real:
                self = .real(row[Expression<Double>(key)])
            case .text:
                self = .text(row[Expression<String>(key)])
            case .blob:
                self = .blob(row[Expression<Data>(key)])
            case .null:
                fatalError("unexpectedly found SQLiteTypeName.null in SQLiteValue.init")
        }
    }
}

extension SQLiteValue {
    func setter(withKey key: String, andTypeName typeName: SQLiteTypeName) -> SQLite.Setter {
        return switch self {
            case .integer(let int):
                Expression<Int64>(key) <- Expression<Int64>(value: int)
            case .real(let double):
                Expression<Double>(key) <- Expression<Double>(value: double)
            case .text(let string):
                Expression<String>(key) <- Expression<String>(value: string)
            case .blob(let data):
                Expression<Data>(key) <- Expression<Data>(value: data)
            case .null:
                switch SQLiteTypeName.notNull(typeName) {
                    case .integer:
                        Expression<Int64?>(key) <- Expression<Int64?>(value: nil)
                    case .real:
                        Expression<Double?>(key) <- Expression<Double?>(value: nil)
                    case .text:
                        Expression<String?>(key) <- Expression<String?>(value: nil)
                    case .blob:
                        Expression<Data?>(key) <- Expression<Data?>(value: nil)
                    default:
                        fatalError("unexpectedly recieved SQLiteTypeName of null")
                }
        }
    }
}
