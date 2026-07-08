// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
// Licensed under Mozilla Public License v2.0
//
// See LICENSE.txt for license information
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
            default:
                .unknownSQLite(message: msg, code: code)
        }
    }
}
