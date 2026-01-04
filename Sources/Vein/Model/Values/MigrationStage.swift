public enum MigrationStage {
    case lightweight(
        fromVersion: any VersionedSchema.Type,
        toVersion: any VersionedSchema.Type
    )
    case custom(
        fromVersion: any VersionedSchema.Type,
        toVersion: any VersionedSchema.Type,
        willMigrate: ((ManagedObjectContext) throws -> Void)?,
        didMigrate: ((ManagedObjectContext) throws -> Void)?
    )
}
