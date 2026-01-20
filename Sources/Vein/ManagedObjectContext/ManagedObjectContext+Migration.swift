import SQLite
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
        let query = MigrationTable.migrationsTable
            .insert([
                Expression<String>(MigrationTable.tableName) <- Expression<String>(value: schema),
                Expression<Int64>(MigrationTable.major) <- Expression<Int64>(value: Int64(version.major)),
                Expression<Int64>(MigrationTable.minor) <- Expression<Int64>(value: Int64(version.minor)),
                Expression<Int64>(MigrationTable.patch) <- Expression<Int64>(value: Int64(version.patch)),
                Expression<Int64>(MigrationTable.appliedAt) <- Expression<Int64>(value: Int64(Date().timeIntervalSince1970))
            ])
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
    public func cleanupOldSchema(_ schema: any VersionedSchema.Type) throws {
        guard isInActiveMigration else {
            throw ManagedObjectContextError
                .notInsideMigration("ManagedObjectContext/cleanupOldSchema")
        }
        for model in schema.models {
            try deleteTable(model.schema)
        }
    }
}

enum MigrationTable {
    static let schema = "_vein_migrations"
    static let migrationsTable = Table(schema)
    static let id = Expression<Int64>("id")
    static let tableName = Expression<String>("table_name")
    static let major = Expression<Int64>("major")
    static let minor = Expression<Int64>("minor")
    static let patch = Expression<Int64>("patch")
    static let appliedAt = Expression<Int64>("applied_at")
}
