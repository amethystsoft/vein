import Foundation
import Testing
import OSLog
@testable import Vein
@testable import VeinCore

let testID = UUID()

@MainActor
struct MigrationTests {
    let logger = Logger(subsystem: "VeinSwiftUITests", category: "Migration")
    
    @Test
    func complexMigration() async throws {
        let containerPath = FileManager.default.temporaryDirectory
        
        let dbDir = containerPath.relativePath.appending("/\(testID.uuidString)")
        
        let dbPath = dbDir.appending("/complexMigration.sqlite3")
        
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
        
        let model = TestSchemaV0_0_1.Test(
            flag: true,
            someValue: "very secret message",
            randomValue: 27
        )
        
        logger.info(
            "Complex migration test started with db location: \(dbPath)"
        )
        
        try await prepareOrigin()
        
        let newContainer = try ModelContainer(models: TestSchemaV0_0_2.Test.self, migration: TestMigration.self, at: dbPath)
        try newContainer.migrate()
        
        let first = try newContainer.context.fetchAll(TestSchemaV0_0_2.Test._PredicateHelper()._builder()).first
        
        #expect(first?.flag == model.flag)
        #expect(first?.someValue == model.someValue)
        #expect(first?.securityCode == "SEC-\(model.randomValue)")
        
        
        func prepareOrigin() async throws {
            let container = try ModelContainer(models: TestSchemaV0_0_1.Test.self, migration: TestMigration.self, at: dbPath)
            
            try container.context.insert(model)
        }
    }
}



enum TestSchemaV0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
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
}

enum TestSchemaV0_0_2: VersionedSchema {
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

enum TestMigration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [TestSchemaV0_0_1.self, TestSchemaV0_0_2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: TestSchemaV0_0_1.self,
        toVersion: TestSchemaV0_0_2.self,
        willMigrate: { context in
            // Fetch V1 models
            let tests = try context.fetchAll(TestSchemaV0_0_1.Test._PredicateHelper()._builder())
            
            // Perform manual transformation logic if needed before schema change
            for test in tests {
                if test.randomValue < 0 {
                    test.randomValue = 0
                }
                let new = TestSchemaV0_0_2.Test(flag: test.flag, someValue: test.someValue, securityCode: "SEC-\(test.randomValue)")
                try context.insert(new)
                try context.delete(test)
            }
        },
        didMigrate: nil
    )
}
