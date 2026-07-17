// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import SQLiteDB
import Foundation

enum UnderlayingFieldType {
    case uuid(required: Bool = false)
    case string(required: Bool = false)
    case int(required: Bool = false)
    case double(required: Bool = false)
    case bool(required: Bool = false)
    case data(required: Bool = false)
    case date(required: Bool = false)
    case url(required: Bool = false)
}

extension UnderlayingFieldType {
    func addColumn(to table: inout SQLiteDB.TableBuilder, withName name: String) {
        switch self {
            case .uuid(let required), .string(let required), .date(let required),
                 .url(let required):
                if required {
                    table.column(SQLExpression<String>(name))
                } else {
                    table.column(SQLExpression<String?>(name))
                }
            case .double(let required):
                if required {
                    table.column(SQLExpression<Double>(name))
                } else {
                    table.column(SQLExpression<Double?>(name))
                }
            case .bool(let required):
                if required {
                    table.column(SQLExpression<Bool>(name))
                } else {
                    table.column(SQLExpression<Bool?>(name))
                }
            case .int(let required):
                if required {
                    table.column(SQLExpression<Int64>(name))
                } else {
                    table.column(SQLExpression<Int64?>(name))
                }
            case .data(let required):
                if required {
                    table.column(SQLExpression<Data>(name))
                } else {
                    table.column(SQLExpression<Data?>(name))
                }
        }
    }
}
