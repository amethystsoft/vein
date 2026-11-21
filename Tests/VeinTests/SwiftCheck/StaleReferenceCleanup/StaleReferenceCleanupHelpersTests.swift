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

#if canImport(SwiftCheck)
    import SQLiteDB
    @testable import Vein

    extension Connection {
        func removeWhereIDMatches(idsToRemove: [String], schema: String) throws -> [String] {
            let idExpr = SQLExpression<String>("id")
            let query = Table(schema)
                .filter(idsToRemove.contains(idExpr))
                .select(idExpr)
            var ids = [String]()
            do {
                let rows = try prepare(query)
                ids = rows.map {
                    $0[idExpr]
                }

                let deleteQuery = Table(schema)
                    .filter(ids.contains(idExpr))
                    .delete()
                try run(deleteQuery)
            } catch let error as SQLiteDB.Result {
                if case .noSuchTable = error.parse() {}
            }

            return ids
        }
    }

#endif
