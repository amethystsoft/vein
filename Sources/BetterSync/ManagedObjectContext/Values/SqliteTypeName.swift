import Foundation

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

public enum SqliteValue: Sendable, Hashable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
}

@MainActor
public protocol ColumnType {
    static var sqliteTypeName: SQLiteTypeName { get }
    var sqliteValue: SqliteValue { get }
    static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Self
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Int16 {
        if
            case .integer(let value) = sqliteValue,
            let value = Int16(exactly: value)
        {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Int32: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SqliteValue {
        .integer(Int64(self))
    }
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Int32 {
        if
            case .integer(let value) = sqliteValue,
            let value = Int32(exactly: value)
        {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Int64: ColumnType {
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SqliteValue {
        .integer(self)
    }
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Int64 {
        if case .integer(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Double {
        if case .real(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Float {
        if case .real(let value) = sqliteValue {
            return Float(value)
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Bool {
        switch sqliteValue {
            case .integer(0):
                return false
            case .integer(1):
                return true
            default:
                throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> URL {
        if
            case .text(let value) = sqliteValue,
            let value = URL(string: value)
        {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> String {
        if case .text(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Data {
        if case .blob(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Date {
        switch sqliteValue {
            case .text(let string):
                do {
                    return try sqliteFormatStyle.parse(string)
                } catch {
                    throw MOCError.propertyDecode(message: "recieved data couldn't be converted to 'Date'")
                }
            default:
                throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> UUID {
        switch sqliteValue {
            case .text(let string):
                if let uuid = UUID(uuidString: string) {
                    return uuid
                }
                throw MOCError.propertyDecode(message: "'\(string)' not compatible with UUID.uuidString")
            default:
                throw MOCError.propertyDecode(message: "\(Self.self)")
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
    
    public static func decode(sqliteValue: SqliteValue) throws(MOCError) -> Wrapped? {
        if case .null = sqliteValue {
            return .none
        } else if let wrapped = try? Wrapped.decode(sqliteValue: sqliteValue) {
            return .some(wrapped)
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}
