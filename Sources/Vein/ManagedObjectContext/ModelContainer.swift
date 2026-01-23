import Foundation
import SQLite

public final class ModelContainer: Sendable {
    private let migration: SchemaMigrationPlan.Type
    private let path: String
    public let context: ManagedObjectContext
    public let versionedSchema: VersionedSchema.Type
    
    public init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        at path: String
    ) throws(ManagedObjectContextError) {
        guard migration.schemas.contains(where: { $0.self == versionedSchema }) else {
            throw ManagedObjectContextError.schemaNotRegisteredOnMigrationPlan(versionedSchema, migration)
        }
        
        // TODO: make ManagedObjectContext only accept models from the versionedSchema or its predecessors(in migration)
        self.context = try ManagedObjectContext(path: path)
        self.migration = migration
        self.path = path
        self.versionedSchema = versionedSchema
        
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
            context.isInActiveMigration.value = false
        }
        context.isInActiveMigration.value = true
        
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
        
        // TODO: add handling of latest table version being larger than the one context was initialized with
        
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
