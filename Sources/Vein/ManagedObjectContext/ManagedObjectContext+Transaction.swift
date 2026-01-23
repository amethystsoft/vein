import SQLite
import Foundation
#if !os(Android) && !os(Windows) && !os(Linux)
import SQLite3
#else
import SwiftToolchainCSQLite
#endif

extension ManagedObjectContext {
    public nonisolated func transaction(_ block: @escaping () throws -> Void) throws {
        try connection.safeTransaction(block)
    }
}

extension Connection {
    func safeTransaction(_ block: () throws -> Void) throws {
        if isInTransaction {
            let spName = "sp_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
            try execute("SAVEPOINT \(spName)")
            do {
                try block()
                try execute("RELEASE SAVEPOINT \(spName)")
            } catch {
                try execute("ROLLBACK TO SAVEPOINT \(spName)")
                throw error
            }
        } else {
            // Standard top-level transaction
            try transaction {
                try block()
            }
        }
    }
    
    var isInTransaction: Bool {
        sqlite3_get_autocommit(handle) == 0
    }
}

extension Connection: @unchecked @retroactive Sendable {}
