import Foundation

public final class ModelContainer: Sendable {
    private let migration: SchemaMigrationPlan.Type
    private let managedModels: Set<AnyPersistentModelType>
    private let path: String
    public let context: ManagedObjectContext
    
    public init(
        models: any PersistentModel.Type...,
        migration: SchemaMigrationPlan.Type,
        at path: String
    ) throws(ManagedObjectContextError) {
        self.context = try ManagedObjectContext(path: path)
        self.managedModels = Set(models.map { AnyPersistentModelType($0)})
        self.migration = migration
        self.path = path
    }
    
    public func migrate() async throws {
        try context.createMigrationsTable()
        
        guard case let .custom(
            originVersion,
            destinationVersion,
            migrate,
            didFinishMigration
        ) = try determineMigrationStage() else { return }
        
        try await migrate?(context)
        
        // TODO: Automatically upgrade table name if unchanged
        // TODO: Automatically delete old tables
    }
    
    private func determineMigrationStage() throws -> MigrationStage? {
        let version = try context.getLatestMigrationVersion()
        guard let latestRegisteredSchema = migration.schemas.sorted(by: {
            $0.version < $1.version
        }).last else {
            fatalError("SchemaMigrationPlan must have one or more managed VersionedSchemas.")
        }
        
        // Already up to date, no migration is necessary
        if version == latestRegisteredSchema.version {
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
            fatalError("No schema matching current model version")
        }
        
        for stage in migration.stages.reversed() {
            if case let .custom(schema,_,_,_) = stage, schema.version == currentSchema.version {
                return stage
            }
        }
        
        fatalError("No migration for current outdated model version: \(version)")
    }
}
