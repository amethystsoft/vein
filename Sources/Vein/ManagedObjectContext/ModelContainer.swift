import Foundation
import SQLite

public final class ModelContainer: Sendable {
    private let migration: SchemaMigrationPlan.Type
    private let managedModels: Set<AnyPersistentModelType>
    private let path: String
    public let context: ManagedObjectContext
    
    public convenience init(
        models: any PersistentModel.Type...,
        migration: SchemaMigrationPlan.Type,
        at path: String
    ) throws(ManagedObjectContextError) {
        try self.init(models: Array(models), migration: migration, at: path)
    }
    
    public init(
        models: [any PersistentModel.Type],
        migration: SchemaMigrationPlan.Type,
        at path: String
    ) throws(ManagedObjectContextError) {
        self.context = try ManagedObjectContext(path: path)
        self.managedModels = Set(models.map { AnyPersistentModelType($0)})
        self.migration = migration
        self.path = path
        
        do {
            try context.createMigrationsTable()
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    @MainActor
    public func migrate() throws {
        defer {
            context.isInActiveMigration = false
        }
        context.isInActiveMigration = true
        
        try context.transaction { [self] in
            while case let .complex(
                originVersion,
                destinationVersion,
                migrationBlock,
                didFinishMigration
            ) = try determineMigrationStage() {
                
                try migrationBlock?(context)
                
                let unmigratedSchemas = try unmigratedSchemas(from: originVersion)
                
                guard unmigratedSchemas.isEmpty else {
                    throw ManagedObjectContextError.modelsUnhandledAfterMigration(
                        originVersion,
                        destinationVersion,
                        unmigratedSchemas
                    )
                }
                
                try context.cleanupOldSchema(originVersion)
                
                try didFinishMigration?(context)
            }
        }
    }
    
    @MainActor
    private func unmigratedSchemas(from version: VersionedSchema.Type) throws -> [String] {
        let tables = try context.getNonEmptySchemas()
        
        var unhandledSchemas = tables.filter { table in
            version.models.contains(where: { $0.schema == table })
        }
        
        return unhandledSchemas
    }
    
    @MainActor
    private func determineMigrationStage() throws -> MigrationStage? {
        let version = try context.getLatestMigrationVersion()
        guard let latestRegisteredSchema = migration.schemas.sorted(by: {
            $0.version < $1.version
        }).last else {
            throw ManagedObjectContextError.emptySchemaMigrationPlan(migration)
        }
        
        // If no current version is found the database is treated as empty and
        // no migration is required
        guard let version else { return nil }
        
        // Already up to date, no migration is necessary
        if
            version == latestRegisteredSchema.version
        {
            return nil
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
}
