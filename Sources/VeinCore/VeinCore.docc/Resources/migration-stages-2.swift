import VeinCore

enum Migration: SchemaMigrationPlan {
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
            // 1. Unchanged models must still be carried over
            try V0_0_1.Post.unchangedMigration(
                to: V0_0_2.Post.self,
                on: context
            )
            
            // 2. Safely introduce the newly added optional fields
            try V0_0_1.Attachment.fieldsAddedMigration(
                to: V0_0_2.Attachment.self,
                on: context
            )
            
            // 3. Drop tables/data you no longer require
            try V0_0_1.Unused.deleteMigration(on: context)
        },
        didMigrate: nil
    )
}
