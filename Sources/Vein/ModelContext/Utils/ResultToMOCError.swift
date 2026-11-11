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
import SQLCipher

package extension SQLiteDB.Result {
    func parse() -> ManagedObjectContextError {
        return switch self {
            case .error(let message, let code, _):
                mapCode(code, msg: message)
            default:
                .other(message: self.localizedDescription)
        }
    }

    private func mapCode(_ code: Int32, msg: String) -> ManagedObjectContextError {
        return switch code {
            case SQLITE_OK: .operationCouldNotBeCompleted(message: msg)
            case SQLITE_ERROR:
                // Technically no such table is not always no such table
                // but as vein abstracts syntax errors, non-existing fields,...
                // it's pretty much guaranteed to be no such table.
                .noSuchTable(message: msg)
            case SQLITE_PERM:
                .insufficientPermissions(message: msg)
            case SQLITE_READONLY:
                .writeInReadonly(message: msg)
            case SQLITE_IOERR:
                .io(message: msg, code: code)
            case SQLITE_NOTADB:
                .notADatabase
            case SQLITE_BUSY:
                .dbLocked
            case SQLITE_LOCKED:
                .tableLocked(message: msg)
            case SQLITE_FULL:
                .dbFull(message: msg)
            case SQLITE_TOOBIG:
                .sqliteTooBig(message: msg)
            default:
                .unknownSQLite(message: msg, code: code)
        }
    }
}
