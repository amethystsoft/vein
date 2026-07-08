import SQLiteDB
import Foundation

extension ManagedObjectContext {
    internal nonisolated func createMigrationsTable() throws {
        try connection.run(MigrationTable.migrationsTable.create(ifNotExists: true) { t in
            t.column(MigrationTable.id, primaryKey: .autoincrement)
            t.column(MigrationTable.tableName)
            t.column(MigrationTable.major)
            t.column(MigrationTable.minor)
            t.column(MigrationTable.patch)
            t.column(MigrationTable.appliedAt)
        })
    }

    internal nonisolated func registerMigration(
        schema: String,
        version: ModelVersion
    ) throws {
        // swiftformat:disable wrap, wrapArguments
        let query = MigrationTable.migrationsTable
            .insert([
                SQLExpression<String>(MigrationTable.tableName) <- SQLExpression<String>(value: schema),
                SQLExpression<Int64>(MigrationTable.major) <- SQLExpression<Int64>(value: Int64(version.major)),
                SQLExpression<Int64>(MigrationTable.minor) <- SQLExpression<Int64>(value: Int64(version.minor)),
                SQLExpression<Int64>(MigrationTable.patch) <- SQLExpression<Int64>(value: Int64(version.patch)),
                SQLExpression<Int64>(MigrationTable.appliedAt) <- SQLExpression<Int64>(value: Int64(Date().timeIntervalSince1970))
            ])
        // swiftformat:enable wrap, wrapArguments
        try connection.run(query)
    }
    
    internal nonisolated func deleteTable(_ schema: String) throws {
        let query = Table(schema).drop(ifExists: true)
        try connection.run(query)
    }

    internal nonisolated func getLatestMigrationVersion() throws -> ModelVersion? {
        let query = MigrationTable.migrationsTable
            .select(MigrationTable.major, MigrationTable.minor, MigrationTable.patch)
            .order(MigrationTable.major.desc, MigrationTable.minor.desc, MigrationTable.patch.desc)
            .limit(1)

        guard let row = try connection.pluck(query) else {
            return nil
        }

        return ModelVersion(
            UInt32(row[MigrationTable.major]),
            UInt32(row[MigrationTable.minor]),
            UInt32(row[MigrationTable.patch])
        )
    }

    internal nonisolated func renameSchema(_ schema: String, to newName: String) throws {
        let query = Table(schema)
            .rename(Table(newName))
        try connection.run(query)
    }

    @MainActor
    package func cleanupOldSchema(_ schema: any VersionedSchema.Type) throws {
        guard isInActiveMigration.value else {
            throw ManagedObjectContextError
                .notInsideMigration("ManagedObjectContext/cleanupOldSchema")
        }
        for model in schema.models {
            try deleteTable(model.schema)
        }
    }

    @MainActor
    package func removeModelsFromContext(for schema: any VersionedSchema.Type) {
        for modelType in schema.models {
            let models = identityMap.getAll(of: modelType)
            models.forEach {
                $0.context = nil
            }
            identityMap.removeAll(of: modelType)
        }
    }
}

enum MigrationTable {
    static let schema = "_vein_migrations"
    static let migrationsTable = Table(schema)
    static let id = SQLExpression<Int64>("id")
    static let tableName = SQLExpression<String>("table_name")
    static let major = SQLExpression<Int64>("major")
    static let minor = SQLExpression<Int64>("minor")
    static let patch = SQLExpression<Int64>("patch")
    static let appliedAt = SQLExpression<Int64>("applied_at")
}
