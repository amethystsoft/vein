import Foundation
import Testing
@testable import Vein
@testable import VeinCore

@MainActor
struct ModelContainerTests {
    private func setupContainer() throws -> ModelContainer {
        let container = try ModelContainer(V0_0_1.self, migration: Migration.self, at: nil)
        return container
    }
    
    @Test("DB newer version than container throws")
    func dbNewerThanContainer() throws {
        let container = try ModelContainer(V0_0_2.self, migration: Migration.self, at: nil)
        let model = V0_0_2.Test(flag: false, someValue: "xyz", securityCode: "zyx")
        try container.context.insert(model)
        try container.context.save()
        
        let newContainer = try ModelContainer(V0_0_1.self, migration: Migration.self, connection: container.getConnection())
        
        do {
            try newContainer.migrate()
        } catch let error as ManagedObjectContextError{
            switch error {
                case .dbNewerThanCode(let db, let container):
                    #expect(db == V0_0_2.version)
                    #expect(container == V0_0_1.version)
                default:
                    Issue.record("Unexpected error thrown")
            }
            return
        } catch {
            Issue.record("Unexpected error thrown")
            return
        }
        Issue.record("Unexpectedly no error was thrown")
    }
}

fileprivate enum V0_0_1: VersionedSchema {
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

fileprivate enum V0_0_2: VersionedSchema {
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

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self, V0_0_2.self]
    }
    
    static var stages: [MigrationStage] {
        [
            migrateV1toV2
        ]
    }
    
    static let migrateV1toV2 = MigrationStage.complex(
        fromVersion: V0_0_1.self,
        toVersion: V0_0_2.self,
        willMigrate: { context in
            // Fetch V1 models
            let tests = try context.fetchAll(V0_0_1.Test.self)
            
            for test in tests {
                if test.randomValue < 0 {
                    test.randomValue = 0
                }
                let new = V0_0_2.Test(flag: test.flag, someValue: test.someValue, securityCode: "SEC-\(test.randomValue)")
                try context.insert(new)
                try context.delete(test)
            }
        },
        didMigrate: nil
    )
}
