import Foundation
import SQLiteDB

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
    
    func fieldIsEqualToExpression(key: String, value: (any SQLiteDB.Value)?) -> SQLiteDB.SQLExpression<Bool?> {
        switch self {
            case .integer:
                SQLExpression<Bool?>(SQLExpression<Int64>(key) == value as! Int64)
            case .real:
                SQLExpression<Bool?>(SQLExpression<Double>(key) == value as! Double)
            case .text:
                SQLExpression<Bool?>(SQLExpression<String>(key) == value as! String)
            case .blob:
                SQLExpression<Bool?>(SQLExpression<Data>(key) == value as! Data)
            case .null(let typeName):
                switch Self.notNull(typeName) {
                    case .integer:
                        SQLExpression<Bool?>(SQLExpression<Int64?>(key) == value as! Int64?)
                    case .real:
                        SQLExpression<Bool?>(SQLExpression<Double?>(key) == value as! Double?)
                    case .text:
                        SQLExpression<Bool?>(SQLExpression<String?>(key) == value as! String?)
                    case .blob:
                        SQLExpression<Bool?>(SQLExpression<Data?>(key) == value as! Data?)
                    default:
                        SQLExpression<Bool?>(value: true)
                }
        }
    }
    
    func fieldIsNotEqualToExpression(key: String, value: (any SQLiteDB.Value)?) -> SQLiteDB.SQLExpression<Bool?> {
        switch self {
            case .integer:
                SQLExpression<Bool?>(SQLExpression<Int64>(key) != value as! Int64)
            case .real:
                SQLExpression<Bool?>(SQLExpression<Double>(key) != value as! Double)
            case .text:
                SQLExpression<Bool?>(SQLExpression<String>(key) != value as! String)
            case .blob:
                SQLExpression<Bool?>(SQLExpression<Data>(key) != value as! Data)
            case .null(let typeName):
                switch Self.notNull(typeName) {
                    case .integer:
                        SQLExpression<Bool?>(SQLExpression<Int64?>(key) != value as! Int64?)
                    case .real:
                        SQLExpression<Bool?>(SQLExpression<Double?>(key) != value as! Double?)
                    case .text:
                        SQLExpression<Bool?>(SQLExpression<String?>(key) != value as! String?)
                    case .blob:
                        SQLExpression<Bool?>(SQLExpression<Data?>(key) != value as! Data?)
                    default:
                        SQLExpression<Bool?>(value: nil)
                }
        }
    }
    
    func fieldIsBiggerToExpression(key: String, value: (any SQLiteDB.Value)?) -> SQLiteDB.SQLExpression<Bool?> {
        switch self {
            case .integer:
                SQLExpression<Bool?>(SQLExpression<Int64>(key) > value as! Int64)
            case .real:
                SQLExpression<Bool?>(SQLExpression<Double>(key) > value as! Double)
            case .text:
                SQLExpression<Bool?>(SQLExpression<String>(key) > value as! String)
            case .blob:
                SQLExpression<Bool?>(value: nil)
            case .null:
                SQLExpression<Bool?>(value: nil)
        }
    }
    
    func fieldIsSmallerToExpression(key: String, value: (any SQLiteDB.Value)?) -> SQLiteDB.SQLExpression<Bool?> {
        switch self {
            case .integer:
                SQLExpression<Bool?>(SQLExpression<Int64>(key) < value as! Int64)
            case .real:
                SQLExpression<Bool?>(SQLExpression<Double>(key) < value as! Double)
            case .text:
                SQLExpression<Bool?>(SQLExpression<String>(key) < value as! String)
            case .blob:
                SQLExpression<Bool?>(value: nil)
            case .null:
                SQLExpression<Bool?>(value: nil)
        }
    }
    
    func fieldIsSmallerOrEqualToExpression(key: String, value: (any SQLiteDB.Value)?) -> SQLiteDB.SQLExpression<Bool?> {
        switch self {
            case .integer:
                SQLExpression<Bool?>(SQLExpression<Int64>(key) <= value as! Int64)
            case .real:
                SQLExpression<Bool?>(SQLExpression<Double>(key) <= value as! Double)
            case .text:
                SQLExpression<Bool?>(SQLExpression<String>(key) <= value as! String)
            case .blob:
                SQLExpression<Bool?>(value: nil)
            case .null:
                SQLExpression<Bool?>(value: nil)
        }
    }
    
    func fieldIsBiggerOrEqualToExpression(key: String, value: (any SQLiteDB.Value)?) -> SQLiteDB.SQLExpression<Bool?> {
        switch self {
            case .integer:
                SQLExpression<Bool?>(SQLExpression<Int64>(key) >= value as! Int64)
            case .real:
                SQLExpression<Bool?>(SQLExpression<Double>(key) >= value as! Double)
            case .text:
                SQLExpression<Bool?>(SQLExpression<String>(key) >= value as! String)
            case .blob:
                SQLExpression<Bool?>(value: nil)
            case .null:
                SQLExpression<Bool?>(value: nil)
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
            case .integer:
                1
            case .real:
                2
            case .text:
                3
            case .blob:
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
    
    init(typeName: SQLiteTypeName, key: String, row: SQLiteDB.Row) {
        if typeName.isNull {
            switch SQLiteTypeName.notNull(typeName) {
                case .integer:
                    if let value = row[SQLExpression<Int64?>(key)] {
                        self = .integer(value)
                    }
                    self = .null
                case .real:
                    if let value = row[SQLExpression<Double?>(key)] {
                        self = .real(value)
                    }
                    self = .null
                case .text:
                    if let value = row[SQLExpression<String?>(key)] {
                        self = .text(value)
                    }
                    self = .null
                case .blob:
                    if let value = row[SQLExpression<Data?>(key)] {
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
                self = .integer(row[SQLExpression<Int64>(key)])
            case .real:
                self = .real(row[SQLExpression<Double>(key)])
            case .text:
                self = .text(row[SQLExpression<String>(key)])
            case .blob:
                self = .blob(row[SQLExpression<Data>(key)])
            case .null:
                fatalError("unexpectedly found SQLiteTypeName.null in SQLiteValue.init")
        }
    }
    
    func underlyingValue(withTypeName typeName: SQLiteTypeName) -> (any SQLiteDB.Value)? {
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
    
    func fieldIsEqualTo(_ value: (any SQLiteDB.Value)?, withTypeName typeName: SQLiteTypeName) -> Bool {
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
    
    func fieldIsNotEqualTo(_ value: (any SQLiteDB.Value)?, withTypeName typeName: SQLiteTypeName) -> Bool {
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
    
    func fieldIsBiggerThan(_ value: (any SQLiteDB.Value)?, withTypeName typeName: SQLiteTypeName) -> Bool {
        guard let value else { return false }
        switch self {
            case .integer(let int64):
                return int64 > value as! Int64
            case .real(let double):
                return double > value as! Double
            case .text(let string):
                return string > value as! String
            case .blob:
                return false
            case .null:
                return false
        }
    }
    
    func fieldIsSmallerThan(_ value: (any SQLiteDB.Value)?, withTypeName typeName: SQLiteTypeName) -> Bool {
        guard let value else { return false }
        switch self {
            case .integer(let int64):
                return int64 < value as! Int64
            case .real(let double):
                return double < value as! Double
            case .text(let string):
                return string < value as! String
            case .blob:
                return false
            case .null:
                return false
        }
    }
    
    func fieldIsSmallerOrEqual(_ value: (any SQLiteDB.Value)?, withTypeName typeName: SQLiteTypeName) -> Bool {
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
    
    func fieldIsBiggerOrEqual(_ value: (any SQLiteDB.Value)?, withTypeName typeName: SQLiteTypeName) -> Bool {
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
    func setter(withKey key: String, andTypeName typeName: SQLiteTypeName) -> SQLiteDB.Setter {
        return switch self {
            case .integer(let int):
                SQLExpression<Int64>(key) <- SQLExpression<Int64>(value: int)
            case .real(let double):
                SQLExpression<Double>(key) <- SQLExpression<Double>(value: double)
            case .text(let string):
                SQLExpression<String>(key) <- SQLExpression<String>(value: string)
            case .blob(let data):
                SQLExpression<Data>(key) <- SQLExpression<Data>(value: data)
            case .null:
                switch SQLiteTypeName.notNull(typeName) {
                    case .integer:
                        SQLExpression<Int64?>(key) <- SQLExpression<Int64?>(value: nil)
                    case .real:
                        SQLExpression<Double?>(key) <- SQLExpression<Double?>(value: nil)
                    case .text:
                        SQLExpression<String?>(key) <- SQLExpression<String?>(value: nil)
                    case .blob:
                        SQLExpression<Data?>(key) <- SQLExpression<Data?>(value: nil)
                    default:
                        fatalError("unexpectedly recieved SQLiteTypeName of null")
                }
        }
    }
}
