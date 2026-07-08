// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import SQLiteDB

/// Represents the supported SQLite storage classes, including specialized types like `jsonb`.
public enum SQLiteTypeName: Sendable, Hashable {
    case integer
    case real
    case text
    case blob
    case jsonb
    /// Represents a nullable version of the base type.
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
            case .blob, .jsonb:
                return "BLOB"
            case .null(let inner):
                return inner.castTypeString
        }
    }
}

/// A container for values transported to and from the SQLite database driver.
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
                6
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
                    } else { self = .null }
                case .real:
                    if let value = row[SQLExpression<Double?>(key)] {
                        self = .real(value)
                    } else { self = .null }
                case .text:
                    if let value = row[SQLExpression<String?>(key)] {
                        self = .text(value)
                    } else { self = .null }
                case .blob:
                    if let value = row[SQLExpression<Data?>(key)] {
                        self = .blob(value)
                    } else { self = .null }
                case .jsonb:
                    if let value = row[SQLExpression<String?>(literal: "json(\"\(key)\")")] {
                        self = .text(value)
                    } else { self = .null }
                case .null:
                    self = .null
            }
            return
        }
        switch typeName {
            case .integer: self = .integer(row[SQLExpression<Int64>(key)])
            case .real: self = .real(row[SQLExpression<Double>(key)])
            case .text: self = .text(row[SQLExpression<String>(key)])
            case .blob: self = .blob(row[SQLExpression<Data>(key)])
            case .jsonb: self = .text(row[SQLExpression<String>(literal: "json(\"\(key)\")")])
            case .null:
                fatalError("unexpectedly found SQLiteTypeName.null in SQLiteValue.init")
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
                    case .blob, .jsonb:
                        SQLExpression<Data?>(key) <- SQLExpression<Data?>(value: nil)
                    default:
                        fatalError("unexpectedly recieved SQLiteTypeName of null")
                }
        }
    }
}
