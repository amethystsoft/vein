import Foundation
import SQLite

public final class ModelContainer: @unchecked Sendable {
    private let migration: SchemaMigrationPlan.Type
    private let path: String?
    
    // Only force unwrapped to count as initialized,
    // so ManagedObjectContex.init can recieve the function
    //
    // Do never mutate anywhere else, only safe under the above circumstances
    public private(set) var context: ManagedObjectContext!
    public let versionedSchema: VersionedSchema.Type
    
    private var identifierCache = [ObjectIdentifier: any PersistentModel.Type]()
    
    private var currentMigration: (any VersionedSchema.Type, any VersionedSchema.Type)?
    
    public init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        at path: String?
    ) throws(ManagedObjectContextError) {
        guard migration.schemas.contains(where: { $0.self == versionedSchema }) else {
            throw ManagedObjectContextError.schemaNotRegisteredOnMigrationPlan(versionedSchema, migration)
        }
        
        self.migration = migration
        self.path = path
        self.versionedSchema = versionedSchema
        if let path {
            self.context = try ManagedObjectContext(
                path: path,
                modelContainer: self
            )
        } else {
            self.context = try ManagedObjectContext(modelContainer: self)
        }
        
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
            currentMigration = nil
            identifierCache.removeAll()
        }
        context.isInActiveMigration.value = true
        
        try context.transaction { [self] in
            while case let .complex(
                originVersion,
                destinationVersion,
                migrationBlock,
                didFinishMigration
            ) = try determineMigrationStage() {
                self.currentMigration = (originVersion, destinationVersion)
                
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
    
    nonisolated func getSchema(for identifier: ObjectIdentifier) -> (any PersistentModel.Type)? {
        if let cached = identifierCache[identifier] {
            return cached
        }
        
        var potentialModelTypes: [any PersistentModel.Type]
        
        if let (origin, destination) = currentMigration {
            potentialModelTypes = origin.models + destination.models
        } else {
            potentialModelTypes = versionedSchema.models
        }
            
        for type in potentialModelTypes {
            if type.typeIdentifier == identifier {
                identifierCache[identifier] = type
                return type
            }
        }
        
        return nil
    }
}
