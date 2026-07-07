import SQLiteDB
import Foundation
import SQLCipher

extension ManagedObjectContext {
    /// Wraps a sequence of operations in an atomic database transaction.
    ///
    /// This provides a scope where you can perform intermediate saves to flush the
    /// write cache and release memory without losing atomicity. If the block
    /// throws, all changes within the transaction are rolled back.
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
