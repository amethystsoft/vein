import Foundation
import SQLite

public typealias MOCError = ManagedObjectContextError

public enum ManagedObjectContextError: Error {
    case connect(message: String)
    case writeInReadonly(message: String)
    case insufficientPermissions(message: String)
    case modelReference(message: String)
    case idMissing(message: String)
    case keyMissing(message: String)
    case insertManagedModel(message: String)
    case io(message: String, code: Int32)
    case unknownSQLite(message: String, code: Int32)
    case other(message: String)
}

extension ManagedObjectContextError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .connect(let message):
                return "Connection failed: \(message)"
            case .writeInReadonly(let message):
                return "Attempted to write in readonly mode: \(message)"
            case .insufficientPermissions(let message):
                return "Missing permissions: \(message)"
            case .modelReference(let message):
                return "Unexpectedly missing model reference: \(message)"
            case .keyMissing(let message):
                return "Unexpectedly missing key: \(message)"
            case .idMissing(let message):
                return "Unexpectedly missing id on managed Model: \(message)"
            case .insertManagedModel(let message):
                return "Tried to insert already managed Model into ManagedObjectContext: \(message)"
            case .io(let message, let code):
                return "IOError: \(message)"
            case .unknownSQLite(let message, let code):
                return "SQLite raised an error with code \(code): \(message)"
            case .other(let message):
                return "Unexpected: \(message)"
        }
    }
    
    public var failureReason: String? {
        switch self {
            case .connect:
                return "Unable to establish database connection"
            case .writeInReadonly:
                return "Database is in read-only mode"
            case .insufficientPermissions:
                return "The app lacks necessary file permissions"
            case .modelReference:
                return "A Field is missing a reference to its parent Model"
            case .keyMissing:
                return "A Field is missing its key"
            case .idMissing:
                return "An already managed Model Instance is missing its id"
            case .io:
                return "An I/O operation failed"
            case .insertManagedModel:
                return "Attempted to insert managed Model into ManagedObjectContext"
            case .unknownSQLite:
                return "SQLite encountered an internal error"
            case .other:
                return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
            case .connect:
                return "Check your database connection settings and try again."
            case .writeInReadonly:
                return "Ensure the database file has write permissions."
            case .insufficientPermissions:
                return "Grant the app file system access in System Settings."
            case .modelReference, .idMissing, .keyMissing:
                return "Create an issue with the code that raised the error."
            case .io:
                return "Check disk space and file permissions."
            case .insertManagedModel:
                return "Only insert unmanaged models."
            case .unknownSQLite:
                return "Try restarting the app."
            case .other:
                return nil
        }
    }
}
