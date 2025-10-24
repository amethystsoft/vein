import Foundation
import SQLite

public enum ManagedObjectContextError: Error {
    case connect(message: String)
    case writeInReadonly(message: String)
    case insufficientPermissions(message: String)
    case io(message: String, code: Int32)
    case unknownSQLite(message: String, code: Int32)
    case other(String)
}

