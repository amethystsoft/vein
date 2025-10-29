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
    
    func fieldIsEqualToExpression(key: String, value: SQLite.Value?) -> SQLite.Expression<Bool?> {
        switch self {
            case .integer:
                Expression<Bool?>(Expression<Int64>(key) == value as! Int64)
            case .real:
                Expression<Bool?>(Expression<Double>(key) == value as! Double)
            case .text:
                Expression<Bool?>(Expression<String>(key) == value as! String)
            case .blob:
                Expression<Bool?>(Expression<Data>(key) == value as! Data)
            case .null(let typeName):
                switch Self.notNull(typeName) {
                    case .integer:
                        Expression<Bool?>(Expression<Int64?>(key) == value as! Int64?)
                    case .real:
                        Expression<Bool?>(Expression<Double?>(key) == value as! Double?)
                    case .text:
                        Expression<Bool?>(Expression<String?>(key) == value as! String?)
                    case .blob:
                        Expression<Bool?>(Expression<Data?>(key) == value as! Data?)
                    default:
                        Expression<Bool?>(value: true)
                }
        }
    }
    
    func fieldIsNotEqualToExpression(key: String, value: SQLite.Value?) -> SQLite.Expression<Bool?> {
        switch self {
            case .integer:
                Expression<Bool?>(Expression<Int64>(key) != value as! Int64)
            case .real:
                Expression<Bool?>(Expression<Double>(key) != value as! Double)
            case .text:
                Expression<Bool?>(Expression<String>(key) != value as! String)
            case .blob:
                Expression<Bool?>(Expression<Data>(key) != value as! Data)
            case .null(let typeName):
                switch Self.notNull(typeName) {
                    case .integer:
                        Expression<Bool?>(Expression<Int64?>(key) != value as! Int64?)
                    case .real:
                        Expression<Bool?>(Expression<Double?>(key) != value as! Double?)
                    case .text:
                        Expression<Bool?>(Expression<String?>(key) != value as! String?)
                    case .blob:
                        Expression<Bool?>(Expression<Data?>(key) != value as! Data?)
                    default:
                        Expression<Bool?>(value: nil)
                }
        }
    }
    
    func fieldIsBiggerToExpression(key: String, value: SQLite.Value?) -> SQLite.Expression<Bool?> {
        switch self {
            case .integer:
                Expression<Bool?>(Expression<Int64>(key) > value as! Int64)
            case .real:
                Expression<Bool?>(Expression<Double>(key) > value as! Double)
            case .text:
                Expression<Bool?>(Expression<String>(key) > value as! String)
            case .blob:
                Expression<Bool?>(value: nil)
            case .null(let typeName):
                Expression<Bool?>(value: nil)
        }
    }
    
    func fieldIsSmallerToExpression(key: String, value: SQLite.Value?) -> SQLite.Expression<Bool?> {
        switch self {
            case .integer:
                Expression<Bool?>(Expression<Int64>(key) < value as! Int64)
            case .real:
                Expression<Bool?>(Expression<Double>(key) < value as! Double)
            case .text:
                Expression<Bool?>(Expression<String>(key) < value as! String)
            case .blob:
                Expression<Bool?>(value: nil)
            case .null(let typeName):
                Expression<Bool?>(value: nil)
        }
    }
    
    func fieldIsSmallerOrEqualToExpression(key: String, value: SQLite.Value?) -> SQLite.Expression<Bool?> {
        switch self {
            case .integer:
                Expression<Bool?>(Expression<Int64>(key) <= value as! Int64)
            case .real:
                Expression<Bool?>(Expression<Double>(key) <= value as! Double)
            case .text:
                Expression<Bool?>(Expression<String>(key) <= value as! String)
            case .blob:
                Expression<Bool?>(value: nil)
            case .null(let typeName):
                Expression<Bool?>(value: nil)
        }
    }
    
    func fieldIsBiggerOrEqualToExpression(key: String, value: SQLite.Value?) -> SQLite.Expression<Bool?> {
        switch self {
            case .integer:
                Expression<Bool?>(Expression<Int64>(key) >= value as! Int64)
            case .real:
                Expression<Bool?>(Expression<Double>(key) >= value as! Double)
            case .text:
                Expression<Bool?>(Expression<String>(key) >= value as! String)
            case .blob:
                Expression<Bool?>(value: nil)
            case .null(let typeName):
                Expression<Bool?>(value: nil)
        }
    }
}

public enum SQLiteValue: Sendable, Hashable {
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
    case null
    
    var intval: Int {
        switch self {
            case .integer(let int64):
                1
            case .real(let double):
                2
            case .text(let string):
                3
            case .blob(let data):
                4
            case .null:
                5
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.intval)
        switch self {
            case .integer(let int64):
                hasher.combine(int64.hashValue)
            case .real(let double):
                hasher.combine(double.hashValue)
            case .text(let string):
                hasher.combine(string.hashValue)
            case .blob(let data):
                hasher.combine(data.hashValue)
            case .null:
                hasher.combine("NULL".hashValue)
        }
    }
    
    init(typeName: SQLiteTypeName, key: String, row: SQLite.Row) {
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
    
    func underlyingValue(withTypeName typeName: SQLiteTypeName) -> SQLite.Value? {
        if typeName.isNull {
            switch self {
                case .integer(let int64):
                    return int64 as Int64?
                case .real(let double):
                    return double as Double?
                case .text(let string):
                    return string as String?
                case .blob(let data):
                    return data as Data?
                case .null:
                    switch SQLiteTypeName.notNull(typeName) {
                        case .integer:
                            return Int64?.none
                        case .real:
                            return Double?.none
                        case .text:
                            return String?.none
                        case .blob:
                            return Data?.none
                        case .null:
                            fatalError("found null while expecting not null")
                    }
            }
        }
        switch self {
            case .integer(let int64):
                return int64
            case .real(let double):
                return double
            case .text(let string):
                return string
            case .blob(let data):
                return data
            case .null:
                fatalError("found null while expecting not null")
        }
    }
    
    func fieldIsEqualTo(_ value: SQLite.Value?, withTypeName typeName: SQLiteTypeName) -> Bool {
        if typeName.isNull {
            switch self {
                case .integer(let int64):
                    return int64 == value as! Int64?
                case .real(let double):
                    return double == value as! Double?
                case .text(let string):
                    return string == value as! String?
                case .blob(let data):
                    return data == value as! Data?
                case .null:
                    return value.isNil
            }
        }
        switch self {
            case .integer(let int64):
                return int64 == value as! Int64
            case .real(let double):
                return double == value as! Double
            case .text(let string):
                return string == value as! String
            case .blob(let data):
                return data == value as! Data
            case .null:
                return false
        }
    }
    
    func fieldIsNotEqualTo(_ value: SQLite.Value?, withTypeName typeName: SQLiteTypeName) -> Bool {
        if typeName.isNull {
            switch self {
                case .integer(let int64):
                    return int64 != value as! Int64?
                case .real(let double):
                    return double != value as! Double?
                case .text(let string):
                    return string != value as! String?
                case .blob(let data):
                    return data != value as! Data?
                case .null:
                    return value.isNil
            }
        }
        switch self {
            case .integer(let int64):
                return int64 != value as! Int64
            case .real(let double):
                return double != value as! Double
            case .text(let string):
                return string != value as! String
            case .blob(let data):
                return data != value as! Data
            case .null:
                return false
        }
    }
    
    func fieldIsBiggerThan(_ value: SQLite.Value?, withTypeName typeName: SQLiteTypeName) -> Bool {
        guard let value else { return false }
        switch self {
            case .integer(let int64):
                return int64 > value as! Int64
            case .real(let double):
                return double > value as! Double
            case .text(let string):
                return string > value as! String
            case .blob(let data):
                return false
            case .null:
                return false
        }
    }
    
    func fieldIsSmallerThan(_ value: SQLite.Value?, withTypeName typeName: SQLiteTypeName) -> Bool {
        guard let value else { return false }
        switch self {
            case .integer(let int64):
                return int64 < value as! Int64
            case .real(let double):
                return double < value as! Double
            case .text(let string):
                return string < value as! String
            case .blob(let data):
                return false
            case .null:
                return false
        }
    }
    
    func fieldIsSmallerOrEqual(_ value: SQLite.Value?, withTypeName typeName: SQLiteTypeName) -> Bool {
        guard let value else { return self == .null }
        switch self {
            case .integer(let int64):
                return int64 <= value as! Int64
            case .real(let double):
                return double <= value as! Double
            case .text(let string):
                return string <= value as! String
            case .blob(let data):
                return data == value as! Data
            case .null:
                return false
        }
    }
    
    func fieldIsBiggerOrEqual(_ value: SQLite.Value?, withTypeName typeName: SQLiteTypeName) -> Bool {
        guard let value else { return self == .null }
        switch self {
            case .integer(let int64):
                return int64 >= value as! Int64
            case .real(let double):
                return double >= value as! Double
            case .text(let string):
                return string >= value as! String
            case .blob(let data):
                return data == value as! Data
            case .null:
                return false
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
