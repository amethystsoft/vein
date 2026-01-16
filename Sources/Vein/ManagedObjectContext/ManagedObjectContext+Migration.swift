import SQLite

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
        
        try connection.run(
            MigrationTable.migrationsTable.createIndex(
                MigrationTable.tableName,
                MigrationTable.major,
                MigrationTable.minor,
                MigrationTable.patch,
                unique: true,
                ifNotExists: true
            )
        )
    }
    
    internal nonisolated func getLatestMigrationVersion() throws -> ModelVersion {
        let query = MigrationTable.migrationsTable
            .select(MigrationTable.major, MigrationTable.minor, MigrationTable.patch)
            .order(MigrationTable.major.desc, MigrationTable.minor.desc, MigrationTable.patch.desc)
            .limit(1)
        
        guard let row = try connection.pluck(query) else {
            return ModelVersion(0, 0, 0)
        }
        
        return ModelVersion(
            UInt32(row[MigrationTable.major]),
            UInt32(row[MigrationTable.minor]),
            UInt32(row[MigrationTable.patch])
        )
    }
}

private enum MigrationTable {
    static let migrationsTable = Table("_vein_migrations")
    static let id = Expression<Int64>("id")
    static let tableName = Expression<String>("table_name")
    static let major = Expression<Int64>("major")
    static let minor = Expression<Int64>("minor")
    static let patch = Expression<Int64>("patch")
    static let appliedAt = Expression<Int64>("applied_at")
}
