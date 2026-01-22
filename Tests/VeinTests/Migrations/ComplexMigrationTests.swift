import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

let testID = UUID()

@MainActor
struct MigrationTests {
    let logger = Logger(label: "de.amethystsoft.vein.test.migration")
    
    @Test
    func complexMigration() async throws {
        let dbPath = try prepareContainerLocation(name: "complexMigration")
        
        logger.info(
            "Complex migration test started with db location: \(dbPath)"
        )
        
        let container = try ModelContainer(ComplexSchemaV0_0_1.self, migration: ComplexMigrationSuccess.self, at: dbPath)
        
        // Create initial models
        let model = ComplexSchemaV0_0_1.Test(
            flag: true,
            someValue: "very secret message",
            randomValue: 27
        )
        let unused = ComplexSchemaV0_0_1.Unused(content: "useless")
        
        try container.context.insert(model)
        try container.context.insert(unused)
        
        // Check both tables exist under the expected name
        let storedSchemas = try container.context.getAllStoredSchemas()
        
        #expect(
            storedSchemas.sorted() == [
                ComplexSchemaV0_0_1.Test.schema,
                ComplexSchemaV0_0_1.Unused.schema
            ].sorted()
        )
        
        // Create new container & trigger migration
        let newContainer = try ModelContainer(ComplexSchemaV0_0_2.self, migration: ComplexMigrationSuccess.self, at: dbPath)
        try newContainer.migrate()
        
        // Check new model was migrated correctly
        let first = try newContainer.context.fetchAll(ComplexSchemaV0_0_2.Test._PredicateHelper()._builder()).first
        
        #expect(first?.flag == model.flag)
        #expect(first?.someValue == model.someValue)
        #expect(first?.securityCode == "SEC-\(model.randomValue)")
        
        // Check if tables got updated/deleted like expected
        let newStoredSchemas = try newContainer.context.getAllStoredSchemas()
        #expect(newStoredSchemas == [ComplexSchemaV0_0_2.Test.schema])
    }
    
    func prepareContainerLocation(name: String) throws -> String {
        let containerPath = FileManager.default.temporaryDirectory
        
        let dbDir = containerPath.relativePath.appending("/veinTests/\(testID.uuidString)")
        
        let dbPath = dbDir.appending("/\(name).sqlite3")
        
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



fileprivate enum ComplexSchemaV0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    
    static let models: [any Vein.PersistentModel.Type] = [
        Test.self,
        Unused.self
    ]
    
    @Model
    final class Test: Identifiable {
        @Field
        var flag: Bool
        
        @Field
        var someValue: String
        
        @Field
        var randomValue: Int
        
        init(flag: Bool, someValue: String, randomValue: Int) {
            self.flag = flag
            self.someValue = someValue
            self.randomValue = randomValue
        }
    }
    
    @Model
    final class Unused {
        @Field
        var content: String
        
        init(content: String) {
            self.content = content
        }
    }
}

fileprivate enum ComplexSchemaV0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable {
        @Field
        var flag: Bool
        
        @Field
        var someValue: String
        
        // Renamed and transformed from randomValue
        @Field
        var securityCode: String
        
        init(flag: Bool, someValue: String, securityCode: String) {
            self.flag = flag
            self.someValue = someValue
            self.securityCode = securityCode
        }
    }
}

fileprivate enum ComplexMigrationSuccess: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [ComplexSchemaV0_0_1.self, ComplexSchemaV0_0_2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: ComplexSchemaV0_0_1.self,
        toVersion: ComplexSchemaV0_0_2.self,
        willMigrate: { context in
            // Fetch V1 models
            let tests = try context.fetchAll(ComplexSchemaV0_0_1.Test._PredicateHelper()._builder())
            
            for test in tests {
                if test.randomValue < 0 {
                    test.randomValue = 0
                }
                let new = ComplexSchemaV0_0_2.Test(flag: test.flag, someValue: test.someValue, securityCode: "SEC-\(test.randomValue)")
                try context.insert(new)
                try context.delete(test)
            }
            
            try context.cleanupOldSchema(ComplexSchemaV0_0_1.self)
        },
        didMigrate: nil
    )
}
