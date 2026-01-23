import SQLite
import Foundation
import ULID

public nonisolated protocol Persistable: Sendable {
    associatedtype PersistentRepresentation: ColumnType
    var asPersistentRepresentation: PersistentRepresentation { get }
    init?(fromPersistent representation: PersistentRepresentation)
}

extension Persistable {
    public static var sqliteTypeName: SQLiteTypeName { PersistentRepresentation.sqliteTypeName }
}

public protocol ColumnType {
    static var sqliteTypeName: SQLiteTypeName { get }
    var sqliteValue: SQLiteValue { get }
    static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Self
}

extension ColumnType {
    var sqliteTypeName: SQLiteTypeName {
        Self.sqliteTypeName
    }
}

extension ULID: Persistable {
    public typealias PersistentRepresentation = String
    
    public var asPersistentRepresentation: String { ulidString }
    
    public init?(fromPersistent representation: String) {
        self.init(ulidString: representation)
    }
}

extension Int16: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Int64 { Int64(self) }
    
    public typealias SQLiteType = Int64
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SQLiteValue {
        .integer(Int64(self))
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Int16 {
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

extension Int32: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Int64 { Int64(self) }
    
    public typealias SQLiteType = Int64
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SQLiteValue {
        .integer(Int64(self))
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Int32 {
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

extension Int64: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Int64 { self }
    
    public typealias SQLiteType = Int64
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName { .integer }
    
    public var sqliteValue: SQLiteValue {
        .integer(self)
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Int64 {
        if case .integer(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Int: Persistable {
    public typealias PersistentRepresentation = Int64
    
    public static var sqliteTypeName: SQLiteTypeName {
        .integer
    }
    
    public var asPersistentRepresentation: Int64 { Int64(self) }
    
    public init?(fromPersistent representation: Int64) {
        self = Int(representation)
    }
}

extension Double: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Double  { self }
    
    public typealias SQLiteType = Double
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .real
    }
    
    public var sqliteValue: SQLiteValue {
        .real(self)
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Double {
        if case .real(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Float: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Double  { Double(self) }
    
    public typealias SQLiteType = Double
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .real
    }
    
    public var sqliteValue: SQLiteValue {
        .real(Double(self))
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Float {
        if case .real(let value) = sqliteValue {
            return Float(value)
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Bool: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Int64 { self ? 1: 0 }
    
    public typealias SQLiteType = Int64
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .integer
    }
    
    public var sqliteValue: SQLiteValue {
        .integer(self ? 1 : 0)
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Bool {
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

extension String: Persistable, ColumnType {
    public var sqliteTypeRepresentation: String { self }
    public typealias SQLiteType = String
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SQLiteValue {
        .text(self)
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> String {
        if case .text(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension URL: Persistable {
    public var sqliteTypeRepresentation: String { absoluteString }
    
    public typealias SQLiteType = String
    
    public typealias PersistentRepresentation = String
    
    public var asPersistentRepresentation: String { absoluteString }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        guard let url = URL(string: representation) else { return nil }
        self = url
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
}

extension Data: Persistable, ColumnType {
    public var sqliteTypeRepresentation: Data { self }
    
    public typealias SQLiteType = Data
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .blob
    }
    
    public var sqliteValue: SQLiteValue {
        .blob(self)
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Data {
        if case .blob(let value) = sqliteValue {
            return value
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Date: Persistable, ColumnType {
    public var sqliteTypeRepresentation: String { ISO8601Format(Date.sqliteFormatStyle) }
    
    public typealias SQLiteType = String
    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteFormatStyle: ISO8601FormatStyle {
        .iso8601(timeZone: .gmt, includingFractionalSeconds: true, dateTimeSeparator: .space)
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SQLiteValue {
        .text(self.ISO8601Format(Date.sqliteFormatStyle))
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Date {
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

extension UUID: Persistable, ColumnType {
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .text
    }
    
    public var sqliteValue: SQLiteValue {
        .text(uuidString)
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> UUID {
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

extension Optional: Persistable, ColumnType where Wrapped: Persistable {    
    public typealias PersistentRepresentation = Self
    
    public var asPersistentRepresentation: Self { self }
    
    public init?(fromPersistent representation: PersistentRepresentation) {
        self = representation
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        .null(Wrapped.sqliteTypeName)
    }
    
    public var sqliteValue: SQLiteValue {
        switch self {
            case .none:
                    .null
            case .some(let value):
                value.asPersistentRepresentation.sqliteValue
        }
    }
    
    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Wrapped? {
        if case .null = sqliteValue {
            return .none
        } else if let representation = try? Wrapped.PersistentRepresentation.decode(sqliteValue: sqliteValue) {
            return Wrapped(fromPersistent: representation)
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}
