import SQLiteDB
import Foundation
import Logging
import ULID

/// Helper type to store values in JSONB format.
public struct SQLiteJSONB: ColumnType, Persistable {
    public typealias SQLiteType = Data
    public typealias PersistentRepresentation = Self
    public let jsonString: String

    public init(jsonString: String) {
        self.jsonString = jsonString
    }

    public static var sqliteTypeName: SQLiteTypeName { .jsonb }

    public var sqliteValue: SQLiteValue { .text(jsonString) }

    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> SQLiteJSONB {
        if case .text(let rawString) = sqliteValue {
            return SQLiteJSONB(jsonString: rawString)
        }
        throw MOCError.propertyDecode(message: "\(Self.self)")
    }

    public var asPersistentRepresentation: Self { self }
    public init?(fromPersistent representation: Self) { self = representation }
}

/// To make your types persistable, conform to ``Persistable``!
public nonisolated protocol Persistable: Sendable {
    associatedtype PersistentRepresentation: ColumnType
    var asPersistentRepresentation: PersistentRepresentation { get }
    init?(fromPersistent representation: PersistentRepresentation)
}

extension Persistable {
    public static var sqliteTypeName: SQLiteTypeName { PersistentRepresentation.sqliteTypeName }
    public static var logger: Logger { Logger(label: "Persistable") }
}

extension SQLiteValue {
    public var bindingValue: (any Binding)? {
        switch self {
            case .integer(let value): return value
            case .real(let value): return value
            case .text(let value): return value
            case .blob(let value): return Blob(bytes: [UInt8](value))
            case .null: return nil
        }
    }
}

public protocol ColumnType {
    associatedtype SQLiteType
    static var sqliteTypeName: SQLiteTypeName { get }
    var sqliteValue: SQLiteValue { get }
    static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> Self
}

extension ColumnType {
    var sqliteTypeName: SQLiteTypeName {
        Self.sqliteTypeName
    }

    public var sqlExpression: SQLExpression<SQLiteType> {
        switch sqliteValue {
            case .null:
                SQLExpression<SQLiteType>(literal: "NULL")
            default:
                SQLExpression<SQLiteType>("?", [sqliteValue.bindingValue])
        }
    }

    /// Only use to store values.
    ///
    /// Columns of type JSONB convert it to the JSONB format from a JSON string.
    public func sqliteSetter(key: String) -> SQLiteDB.Setter {
        if SQLiteTypeName.notNull(Self.sqliteTypeName) == .jsonb {
            switch self.sqliteValue {
                case .text(let jsonString):
                    // Binds the string value and wraps it via the native database function: jsonb(?)
                    let jsonbExpr = SQLExpression<Data>("jsonb(?)", [jsonString])
                    return SQLExpression<Data>(key) <- jsonbExpr
                case .null:
                    return SQLExpression<Data?>(key) <- SQLExpression<Data?>(value: nil)
                default:
                    fatalError("Unexpected value structure for JSONB serialization context")
            }
        }
        return self.sqliteValue.setter(withKey: key, andTypeName: Self.sqliteTypeName)
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
    public var sqliteTypeRepresentation: Double { self }

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
    public var sqliteTypeRepresentation: Double { Double(self) }

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
    public var sqliteTypeRepresentation: Bool { self }

    public typealias SQLiteType = Bool

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

extension Date: Persistable {
    public typealias PersistentRepresentation = Double

    public var asPersistentRepresentation: Double { self.timeIntervalSince1970 }

    public init?(fromPersistent representation: PersistentRepresentation) {
        self = Date(timeIntervalSince1970: representation)
    }
}

extension UUID: Persistable, ColumnType {
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
        .text(uuidString)
    }

    public static func decode(sqliteValue: SQLiteValue) throws(MOCError) -> UUID {
        switch sqliteValue {
            case .text(let string):
                if let uuid = UUID(uuidString: string) {
                    return uuid
                }
                throw MOCError
                    .propertyDecode(message: "'\(string)' not compatible with UUID.uuidString")
            default:
                throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

extension Optional: Persistable, ColumnType where Wrapped: Persistable {
    public typealias SQLiteType = Wrapped.PersistentRepresentation.SQLiteType?

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
        } else if let representation = try? Wrapped.PersistentRepresentation
            .decode(sqliteValue: sqliteValue)
        {
            return Wrapped(fromPersistent: representation)
        } else {
            throw MOCError.propertyDecode(message: "\(Self.self)")
        }
    }
}

// An Array of ULID is persisted as JSONB.
// The optimized JSONB format means less overhead when using json_each for filtering.
// Vein doesn't use join tables to keep everything simpler.
// I currently consider the performance to complexity tradeoff viable,
// since Vein is a Framework intended to be used in apps,
// where datasets a lot smaller than on a server are expected.
extension Array: Persistable where Element == ULID {
    public typealias PersistentRepresentation = SQLiteJSONB

    public init?(fromPersistent representation: SQLiteJSONB) {
        guard let data = representation.jsonString.data(using: .utf8),
              let strings = try? JSONDecoder().decode([String].self, from: data)
        else {
            return nil
        }
        self = strings.map {
            guard let ulid = ULID(ulidString: $0) else {
                fatalError("Found invalid ulid string in ULID array. Likely data corruption.")
            }
            return ulid
        }
    }

    public var asPersistentRepresentation: SQLiteJSONB {
        let serialized = "[" + self.map { "\"\($0.ulidString)\"" }.joined(separator: ",") + "]"
        return SQLiteJSONB(jsonString: serialized)
    }
}

/// Conform to this protocol as an easy way to make your RawRepresentable type ``Persistable``.
///
/// It will be stored as the RawValue's `PersistentRepresentation` in SQLite.
/// Please note that changing the RawRepresentable implementation within one version might break decoding.
/// It is recommended to only change it during Schema Version bumps.
public protocol RawRepresentablePersistable: RawRepresentable, Persistable where
    RawValue: Persistable,
    PersistentRepresentation == RawValue.PersistentRepresentation
{}
extension RawRepresentablePersistable {
    public init?(fromPersistent representation: RawValue.PersistentRepresentation) {
        guard let rawValue = RawValue.init(fromPersistent: representation) else {
            return nil
        }
        self.init(rawValue: rawValue)
    }

    public var asPersistentRepresentation: RawValue.PersistentRepresentation {
        self.rawValue.asPersistentRepresentation
    }
}

/// Conform to this protocol as an easy way to make your custom codable struct ``Persistable``.
///
/// It will be stored as JSONB in SQLite, allowing for performant custom filtering.
/// Please note that changing the Codable implementation within one version might break decoding.
/// It is recommended to only change it during Schema Version bumps.
public protocol CodablePersistable: Codable,
    Persistable where PersistentRepresentation == SQLiteJSONB {}
extension CodablePersistable {
    public init?(fromPersistent representation: SQLiteJSONB) {
        guard
            let data = representation.jsonString.data(using: .utf8),
            let instance = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }

        self = instance
    }

    public var asPersistentRepresentation: SQLiteJSONB {
        do {
            let serialized = try JSONEncoder().encode(self)
            guard let jsonString = String(data: serialized, encoding: .utf8) else {
                fatalError("Failed to convert JSON data for \(Self.self) to string.")
            }
            return SQLiteJSONB(jsonString: jsonString)
        } catch {
            fatalError(
                "Failed to JSON-encode data for \(Self.self). Error: \(error), Description: \(error.localizedDescription)"
            )
        }
    }
}
