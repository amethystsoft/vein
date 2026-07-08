import VeinCore

enum ComplexMigration: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [V0_0_1.self, V0_0_2.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: V0_0_1.self,
        toVersion: V0_0_2.self,
        willMigrate: { context in
            // Custom mapping logic will go here
        },
        didMigrate: nil
    )
}
