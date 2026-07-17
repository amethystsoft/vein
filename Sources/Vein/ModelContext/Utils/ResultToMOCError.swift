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
        switch code {
            case 1:
                .noSuchTable(message: msg)
            case 3: // PERM
                .insufficientPermissions(message: msg)
            case 8: // READONLY
                .writeInReadonly(message: msg)
            case 10: // IOERR
                .io(message: msg, code: code)
            case 26:
                .notADatabase
            default:
                .unknownSQLite(message: msg, code: code)
        }
    }
}
