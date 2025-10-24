import Foundation

public enum SQLiteTypeName: Sendable, Hashable {
    case integer, real, text, blob
    indirect case null(SQLiteTypeName)
    
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

public enum SqliteValue: Sendable, Hashable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

public protocol ColumnType: Sendable {
    static var sqliteTypeName: SQLiteTypeName { get }
    var sqliteValue: SqliteValue { get }
    static func decode(sqliteValue: SqliteValue) -> Self?
}

extension ColumnType {
    var sqliteTypeName: SQLiteTypeName {
        Self.sqliteTypeName
    }
}

extension Int16: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SqliteValue {
        .integer(Int64(self))
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Int16? {
        if case .integer(let value) = sqliteValue {
            return Int16(exactly: value)
        } else {
            return nil
        }
    }
}

extension Int32: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SqliteValue {
        .integer(Int64(self))
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Int32? {
        if case .integer(let value) = sqliteValue {
            return Int32(exactly: value)
        } else {
            return nil
        }
    }
}

extension Int64: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SqliteValue {
        .integer(self)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Int64? {
        if case .integer(let value) = sqliteValue {
            return value
        } else {
            return nil
        }
    }
}

extension Double: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .real
    }
    
    public var sqliteValue: SqliteValue {
        .real(self)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Double? {
        if case .real(let value) = sqliteValue {
            return value
        } else {
            return nil
        }
    }
}

extension Float: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .real
    }
    
    public var sqliteValue: SqliteValue {
        .real(Double(self))
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Float? {
        if case .real(let value) = sqliteValue {
            return Float(value)
        } else {
            return nil
        }
    }
}

extension Bool: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .integer
    }
    
    public var sqliteValue: SqliteValue {
        .integer(self ? 1 : 0)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Bool? {
        switch sqliteValue {
            case .integer(0):
                return false
            case .integer(1):
                return true
            default:
                return nil
        }
    }
}

extension URL: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SqliteValue {
        .text(absoluteString)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> URL? {
        if case .text(let value) = sqliteValue {
            return URL(string: value)
        } else {
            return nil
        }
    }
}

extension String: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SqliteValue {
        .text(self)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> String? {
        if case .text(let value) = sqliteValue {
            return value
        } else {
            return nil
        }
    }
}

extension Data: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .blob
    }
    
    public var sqliteValue: SqliteValue {
        .blob(self)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Data? {
        if case .blob(let value) = sqliteValue {
            return value
        } else {
            return nil
        }
    }
}

extension Date: ColumnType {
    private static var sqliteFormatStyle: ISO8601FormatStyle {
        .iso8601(timeZone: .gmt, includingFractionalSeconds: true, dateTimeSeparator: .space)
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SqliteValue {
        .text(self.ISO8601Format(Date.sqliteFormatStyle))
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Date? {
        switch sqliteValue {
            case .text(let string):
                try? sqliteFormatStyle.parse(string)
            default:
                nil
        }
    }
}

extension UUID: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SqliteValue {
        .text(uuidString)
    }
    
    public static func decode(sqliteValue: SqliteValue) -> UUID? {
        switch sqliteValue {
            case .text(let string):
                UUID(uuidString: string)
            default:
                nil
        }
    }
}

extension Optional: ColumnType where Wrapped: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName {
        .null(Wrapped.sqliteTypeName)
    }
    
    public var sqliteValue: SqliteValue {
        switch self {
            case .none:
                    .null
            case .some(let value):
                value.sqliteValue
        }
    }
    
    public static func decode(sqliteValue: SqliteValue) -> Wrapped?? {
        if case .null = sqliteValue {
            return .some(.none)
        } else if let wrapped = Wrapped.decode(sqliteValue: sqliteValue) {
            return .some(.some(wrapped))
        } else {
            return .none
        }
    }
}
