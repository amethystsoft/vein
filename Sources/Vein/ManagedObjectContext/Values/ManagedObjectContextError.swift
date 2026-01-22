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
    case idAfterCreation(message: String)
    case io(message: String, code: Int32)
    case propertyDecode(message: String)
    case unexpectedlyEmptyResult(message: String)
    case unknownSQLite(message: String, code: Int32)
    case noSuchTable(message: String)
    case baseNotOlderThanDestination(any PersistentModel.Type, any PersistentModel.Type)
    case fieldMismatch(any PersistentModel.Type, any PersistentModel.Type)
    case notInsideMigration(String)
    case destinationMustHaveOnlyAddedFields(any PersistentModel.Type, any PersistentModel.Type)
    case automaticMigrationRequiresOnlyOptionalFieldsAdded(any PersistentModel.Type, any PersistentModel.Type)
    case modelsUnhandledAfterMigration(any VersionedSchema.Type, any VersionedSchema.Type, [String])
    case emptySchemaMigrationPlan(SchemaMigrationPlan.Type)
    case noSchemaMatchingVersion(SchemaMigrationPlan.Type, ModelVersion)
    case noMigrationForOutdatedModelVersion(SchemaMigrationPlan.Type, ModelVersion)
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
            case .idAfterCreation(let message):
                return "Failed to retrieve generated id after insertion: \(message)"
            case .propertyDecode(let message):
                return "Database Scheme doesn't match expected: \(message)"
            case .unexpectedlyEmptyResult(let message):
                return "Unexpectedly recieved empty result: \(message)"
            case .io(let message, let code):
                return "IOError \(code): \(message)"
            case .unknownSQLite(let message, let code):
                return "SQLite raised an error with code \(code): \(message)"
            case .noSuchTable(message: let message):
                return message
            case .baseNotOlderThanDestination(let origin, let destination):
                return "Version of \(origin.schema) not lower than \(destination.schema)"
            case .fieldMismatch(let origin, let destination):
                return "Fields of \(origin.schema) don't match fields of \(destination.schema)"
            case .notInsideMigration(let message):
                return "Function is only available during a migration: \(message)"
            case .destinationMustHaveOnlyAddedFields(let origin, let destination):
                return
                    """
                    PersistentModel/fieldsAddedMigration requires only adding Fields. \
                    Migration between \(origin.schema) and \(destination.schema)
                    """
            case .automaticMigrationRequiresOnlyOptionalFieldsAdded(let origin, let destination):
                return
                    """
                    PersistentModel/fieldsAddedMigration requires added fields to have nullable SQLiteValue. \
                    Migration between \(origin.schema) and \(destination.schema)
                    """
            case .modelsUnhandledAfterMigration(let origin, let destination, let models):
                return
                    """
                    Migration from \(origin) to \(destination) left behind \
                    unhandled rows for schemas \(models)
                    """
            case .emptySchemaMigrationPlan(let plan):
                return "\(plan) must have one or more managed VersionedSchemas."
            case .noSchemaMatchingVersion(let plan, let version):
                return "\(plan) is missing a versioned schema matching version \(version)"
            case .noMigrationForOutdatedModelVersion(let plan, let version):
                return "\(plan) doesn't have a migration stage starting with outdated \(version)"
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
            case .idAfterCreation:
                return "Failed to get id after attempt to insert Model"
            case .propertyDecode:
                return "Failed to decode Property, Type mismatch"
            case .unexpectedlyEmptyResult:
                return "Unexpectedly recieved empty result"
            case .io:
                return "An I/O operation failed"
            case .insertManagedModel:
                return "Attempted to insert managed Model into ManagedObjectContext"
            case .unknownSQLite:
                return "SQLite encountered an internal error"
            case .noSuchTable:
                return "Attempted to do work on a table that doesn't exist"
            case .baseNotOlderThanDestination:
                return "Migration base version number must be lower"
            case .fieldMismatch:
                return "PersistentModel/unchangedMigration requires fields of origin and destination to have unchanged underlying types and names"
            case .notInsideMigration:
                return "Certain functions are only available during migrations to ensure stability"
            case .destinationMustHaveOnlyAddedFields:
                return "Destination model doesn't have the same fields as the origin model plus new ones"
            case .automaticMigrationRequiresOnlyOptionalFieldsAdded:
                return "New schema adds non-optional Fields."
            case .modelsUnhandledAfterMigration:
                return "Every row of the old schema must be handled for a migration to succeed"
            case .emptySchemaMigrationPlan:
                return "SchemaMigrationPlan cannot be used without managed VersionedSchemas"
            case .noSchemaMatchingVersion:
                return "Database is on the state of a version not managed by VersionedSchema"
            case .noMigrationForOutdatedModelVersion:
                return "Migration chain is incomplete. No migration stage found for outdated VersionedSchema."
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
            case .modelReference, .idMissing, .keyMissing, .idAfterCreation:
                return "Create an issue with the code that raised the error."
            case .io:
                return "Check disk space and file permissions."
            case .insertManagedModel:
                return "Only insert unmanaged models."
            case .propertyDecode:
                return "Check if the database scheme matches the expected one."
            case .unexpectedlyEmptyResult:
                return "Make sure not to refresh a property of a deleted Model"
            case .unknownSQLite:
                return "Try restarting the app."
            case .noSuchTable:
                return "Create the table or talk to your admin."
            case .baseNotOlderThanDestination:
                return "Switch the model versions to match OldModel.unchangedMigrate(to: NewModel.self, on: context)"
            case .fieldMismatch:
                return "Make sure the fields of both versions haven't changed or migrate manually"
            case .notInsideMigration:
                return "Make sure to only call the function during an active migration"
            case .destinationMustHaveOnlyAddedFields:
                return
                    """
                    Use PersistentModel/unchangedMigration if the Field names and \
                    underlying SQLite Values didn't change or migrate manually.
                    """
            case .automaticMigrationRequiresOnlyOptionalFieldsAdded:
                return "Only add Fields with nullable SQLiteValue or migrate manually."
            case .modelsUnhandledAfterMigration:
                return
                    """
                    Make sure to migrate every model of every schema of the old version. \
                    For manual migration delete an old model once migrated to the new schema. \
                    Make sure to handle every schema with one of the supported migrations.
                    """
            case .emptySchemaMigrationPlan:
                return "Add your VersionedSchemas to the static var schemas protocol requirement."
            case .noSchemaMatchingVersion:
                return
                    """
                    Add all VersionedSchemas to the static var schemas protocol requirement \
                    and make sure there is an uninterrupted migration chain.
                    Every destination version must be the origin version of a newer migration, \
                    unless it is the latest one.
                    """
            case .noMigrationForOutdatedModelVersion:
                return
                    """
                    Make sure there is an uninterrupted chain of migration stages.
                    """
            case .other:
                return nil
        }
    }
}
