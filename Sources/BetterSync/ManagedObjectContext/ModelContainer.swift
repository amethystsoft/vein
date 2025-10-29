import SwiftUI

public final class ModelContainer: Sendable {
    private let migration: SchemaMigrationPlan.Type
    private let managedModels: Set<AnyPersistentModelType>
    private let path: String
    public let context: ManagedObjectContext
    
    public init(
        models: PersistentModel.Type...,
        migration: SchemaMigrationPlan.Type,
        at path: String
    ) throws(ManagedObjectContextError) {
        self.context = try ManagedObjectContext(path: path)
        self.managedModels = Set(models.map { AnyPersistentModelType($0)})
        self.migration = migration
        self.path = path
    }
    
    public func migrate() async throws {
        guard
            let latestSchema = migration.schemas.sorted(by: {
                $0.version > $1.version
            }).first
        else {
            fatalError("SchemaMigrationPlan must have one or more managed VersionedSchemas.")
        }
        guard !managedModels.isEmpty else {
            fatalError("ModelContainer must have one or more managed Models.")
        }
        for model in latestSchema.models.map { AnyPersistentModelType($0) } {
            guard managedModels.contains(model) else {
                continue
            }
            let migration: ModelSchemaMigration = model.createMigration()
            try await migration.prepare(in: context)
        }
    }
}
