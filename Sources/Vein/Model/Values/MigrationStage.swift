@MainActor
public enum MigrationStage {
    case complex(
        fromVersion: any VersionedSchema.Type,
        toVersion: any VersionedSchema.Type,
        willMigrate: (@MainActor (ManagedObjectContext) throws -> Void)?,
        didMigrate: (@MainActor (ManagedObjectContext) throws -> Void)?
    )
}
