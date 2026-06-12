import Foundation
import SQLiteDB

public final class ModelContainer: @unchecked Sendable {
    private let migration: SchemaMigrationPlan.Type
    private let path: String?
    
    // Only force unwrapped to count as initialized,
    // so ManagedObjectContex.init can recieve the function
    //
    // Do never mutate anywhere else, only safe under the above circumstances
    public private(set) var context: ManagedObjectContext!
    public let versionedSchema: VersionedSchema.Type
    
    private var identifierCache = Atomic([ObjectIdentifier: any PersistentModel.Type]())
    
    private var currentMigration = Atomic((any VersionedSchema.Type, any VersionedSchema.Type)?.none)
    
    public let appID: String
    
    public let encryptionEnabled: Bool
    
    
    /// Manages the schema and storage for a Vein database.
    ///
    /// - Parameter appID: A unique identifier used per-database to construct the keyring
    ///   service string: `"com.amethyst.vein.sqlcipher.\(appID)"`.
    ///
    /// - Note: `Keyring.appIdentifier` is a global, one-time configuration for the
    ///   underlying `KeyringAccess` library, typically set once per process or environment.
    ///   It should represent the application bundle or organization identity.
    ///
    ///   `Keyring.appIdentifier` does not need to match the `appID` parameter. If they
    ///   differ, `KeyringAccess` uses the global identifier for internal namespacing while
    ///   continuing to store and retrieve items using the service string derived from `appID`.
    ///
    /// On Linux, set `Keyring.appIdentifier` before creating any `ModelContainer` instances:
    /// ```swift
    /// #if os(Linux)
    ///     import Vein
    ///
    ///     Keyring.appIdentifier.withLock { identifier in
    ///         identifier = "com.example.yourapp"
    ///     }
    /// #endif
    /// ```
    public init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        at path: String?,
        appID: String,
        encryptionEnabled: Bool = true
    ) throws(ManagedObjectContextError) {
        self.encryptionEnabled = encryptionEnabled
        self.appID = appID
        
        guard migration.schemas.contains(where: { $0.self == versionedSchema }) else {
            throw ManagedObjectContextError.schemaNotRegisteredOnMigrationPlan(versionedSchema, migration)
        }
        
        self.migration = migration
        self.path = path?.removingPercentEncoding
        self.versionedSchema = versionedSchema
        if let path = self.path {
            if !FileManager.default.fileExists(atPath: path) {
                let created = FileManager.default.createFile(
                    atPath: path,
                    contents: nil
                )
                if !created {
                    throw ManagedObjectContextError.other(
                        message: "Failed to create database file at path: \(path)"
                    )
                }
            }
            self.context = try ManagedObjectContext(
                path: path,
                modelContainer: self
            )
        } else {
            self.context = try ManagedObjectContext(modelContainer: self)
        }
        
        do {
            try context.createMigrationsTable()
        } catch let error as ManagedObjectContextError {
            throw error
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    /// Manages the schema and storage for a Vein database.
    ///
    /// - Parameter appID: A unique identifier used per-database to construct the keyring
    ///   service string: `"com.amethyst.vein.sqlcipher.\(appID)"`.
    ///
    /// - Note: `Keyring.appIdentifier` is a global, one-time configuration for the
    ///   underlying `KeyringAccess` library, typically set once per process or environment.
    ///   It should represent the application bundle or organization identity.
    ///
    ///   `Keyring.appIdentifier` does not need to match the `appID` parameter. If they
    ///   differ, `KeyringAccess` uses the global identifier for internal namespacing while
    ///   continuing to store and retrieve items using the service string derived from `appID`.
    ///
    /// On Linux, set `Keyring.appIdentifier` before creating any `ModelContainer` instances:
    /// ```swift
    /// #if os(Linux)
    ///     import Vein
    ///
    ///     Keyring.appIdentifier.withLock { identifier in
    ///         identifier = "com.example.yourapp"
    ///     }
    /// #endif
    /// ```
    init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        connection: Connection,
        appID: String,
        encryptionEnabled: Bool = true
    ) throws(ManagedObjectContextError) {
        self.encryptionEnabled = encryptionEnabled
        self.appID = appID
        
        guard migration.schemas.contains(where: { $0.self == versionedSchema }) else {
            throw ManagedObjectContextError.schemaNotRegisteredOnMigrationPlan(versionedSchema, migration)
        }
        
        self.migration = migration
        self.path = nil
        self.versionedSchema = versionedSchema
        self.context = ManagedObjectContext(
            connection: connection, modelContainer: self
        )
        
        do {
            try context.createMigrationsTable()
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    @MainActor
    public func migrate() throws {
        defer {
            context.isInActiveMigration.value = false
            currentMigration.value = nil
            identifierCache.mutate { identifierCache in
                identifierCache.removeAll()
            }
        }
        context.isInActiveMigration.value = true
        
        try context.transaction { [self] in
            while case let .complex(
                originVersion,
                destinationVersion,
                migrationBlock,
                didFinishMigration
            ) = try determineMigrationStage() {
                self.currentMigration.value = (originVersion, destinationVersion)
                
                identifierCache.mutate { identifierCache in
                    identifierCache.removeAll()
                }
                try migrationBlock?(context)
                
                try context.save()
                
                let unmigratedSchemas = try unmigratedSchemas(from: originVersion)
                
                guard unmigratedSchemas.isEmpty else {
                    context.removeModelsFromContext(for: originVersion)
                    if destinationVersion != versionedSchema {
                        context.removeModelsFromContext(for: destinationVersion)
                    }
                    throw ManagedObjectContextError.modelsUnhandledAfterMigration(
                        originVersion,
                        destinationVersion,
                        unmigratedSchemas
                    )
                }
                
                try context.cleanupOldSchema(originVersion)
                context.removeModelsFromContext(for: originVersion)
                if destinationVersion != versionedSchema {
                    context.removeModelsFromContext(for: destinationVersion)
                }
                
                try didFinishMigration?(context)
            }
        }
    }
    
    func getConnection() -> Connection {
        return context.connection
    }
    
    @MainActor
    private func unmigratedSchemas(from version: VersionedSchema.Type) throws -> [String] {
        let tables = try context.getNonEmptySchemas()

        return tables.filter { table in
            version.models.contains(where: { $0.schema == table })
        }
    }
    
    @MainActor
    private func determineMigrationStage() throws -> MigrationStage? {
        let version = try context.getLatestMigrationVersion()
        
        // If no current version is found the database is treated as empty and
        // no migration is required
        guard let version else { return nil }
        
        // Already up to date, no migration is necessary
        if version == versionedSchema.version {
            return nil
        }
        
        if version > versionedSchema.version {
            throw MOCError.dbNewerThanCode(version, versionedSchema.version)
        }
        
        var currentSchema: VersionedSchema.Type? = nil
        
        for versionedSchema in migration.schemas.reversed() {
            if versionedSchema.version == version {
                currentSchema = versionedSchema
                break
            }
        }
        
        guard let currentSchema else {
            throw ManagedObjectContextError.noSchemaMatchingVersion(migration, version)
        }
        
        for stage in migration.stages.reversed() {
            if case let .complex(schema,_,_,_) = stage, schema.version == currentSchema.version {
                return stage
            }
        }
        
        throw ManagedObjectContextError.noMigrationForOutdatedModelVersion(migration, version)
    }
    
    nonisolated func getSchema(for identifier: ObjectIdentifier) -> (any PersistentModel.Type)? {
        if
            let cached = identifierCache.mutate ({ identifierCache in
                return identifierCache[identifier]
            })
        {
            return cached
        }
        
        var potentialModelTypes: [any PersistentModel.Type]
        
        if let (origin, destination) = currentMigration.value {
            potentialModelTypes = origin.models + destination.models
        } else {
            potentialModelTypes = versionedSchema.models
        }
            
        for type in potentialModelTypes where type.typeIdentifier == identifier {
            identifierCache.mutate { identifierCache in
                identifierCache[identifier] = type
            }
            return type
        }
        
        return nil
    }
}
