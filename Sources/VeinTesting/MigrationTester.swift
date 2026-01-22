import Foundation
import Vein

@MainActor
public struct MigrationTester {
    private let migrationPlan: any SchemaMigrationPlan.Type
    private let id = UUID()
    public let containerPath: String
    
    init(migrationPlan: any SchemaMigrationPlan.Type) throws {
        self.migrationPlan = migrationPlan
        self.containerPath = try Self.prepareContainerLocation(
            plan: migrationPlan,
            id: id
        )
    }
    
    func seed(
        version: VersionedSchema.Type,
        with block: (ManagedObjectContext) throws -> Void
    ) throws {
        let container = try ModelContainer(
            version,
            migration: migrationPlan,
            at: containerPath
        )
        try block(container.context)
    }
    
    func migrateAndCheck(
        version: VersionedSchema.Type,
        with block: (ManagedObjectContext) throws -> Void
    ) throws {
        let container = try ModelContainer(
            version,
            migration: migrationPlan,
            at: containerPath
        )
        try container.migrate()
        try block(container.context)
    }
    
    func testCompleteChain (
        initialData: (ManagedObjectContext) throws -> Void,
        validations: [ModelVersion: (ManagedObjectContext) throws -> Void]
    ) throws {
        let sortedSchemas = migrationPlan.schemas
            .sorted(by: { $0.version < $1.version})
        guard
            let startingVersion = sortedSchemas.first
        else {
            throw ManagedObjectContextError.other(message: "\(migrationPlan) doesn't have any schemas")
        }
        
        let container = try ModelContainer(
            startingVersion,
            migration: migrationPlan,
            at: containerPath
        )
        
        try initialData(container.context)
        
        let modelVersions = validations.keys.sorted()
        
        for schema in sortedSchemas.dropFirst() {
            let currentContainer = try ModelContainer(
                schema,
                migration: migrationPlan,
                at: containerPath
            )
            
            try currentContainer.migrate()
            try validations[schema.version]?(currentContainer.context)
        }
    }
    
    private static func prepareContainerLocation(
        plan: any SchemaMigrationPlan.Type,
        id: UUID
    ) throws -> String {
        let containerPath = FileManager.default.temporaryDirectory
        
        let dbDir = containerPath.relativePath.appending("/vein-migrationTests/\(plan)/\(id.uuidString)")
        
        let dbPath = dbDir.appending("/db.sqlite3")
        
        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )
        
        if !FileManager.default.fileExists(atPath: dbPath) {
            FileManager.default.createFile(
                atPath: dbPath,
                contents: nil
            )
        }
        
        return dbPath
    }
}
