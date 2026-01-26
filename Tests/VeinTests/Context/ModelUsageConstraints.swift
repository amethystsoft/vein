import Foundation
import Testing
@testable import Vein
@testable import VeinCore

@MainActor
struct ModelUsageConstraints {
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
    
    @Test("Fetch unpermitted model during migration")
    func fetchUnpermittedModelDuringMigration() throws {
        let path = try prepareContainerLocation(name: "unpermittedDuringMigration")
        let container = try ModelContainer(V0_0_2.self, migration: Migration.self, at: path)
        let model = V0_0_2.Test(flag: true, someValue: "blubb", securityCode: "very secure code")
        try container.context.insert(model)
        try container.context.save()
        
        let newContainer = try ModelContainer(V0_0_3.self, migration: Migration.self, at: path)
        
        do {
            try newContainer.migrate()
        } catch let error as ManagedObjectContextError {
            switch error {
                case .inactiveModelTypeFetched(let type):
                    #expect(type.schema == V0_0_1.Test.schema)
                default:
                    Issue.record("Unexpected error: \(error.localizedDescription)")
            }
            return
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
            return
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test("Fetch unpermitted model")
    func fetchUnpermittedModel() throws {
        let container = try ModelContainer(V0_0_2.self, migration: Migration.self, at: nil)
        
        do {
            let _ = try container.context.fetchAll(V0_0_1.Test.self)
        } catch{
            switch error {
                case .inactiveModelTypeFetched(let type):
                    #expect(type.schema == V0_0_1.Test.schema)
                default:
                    Issue.record("Unexpected error: \(error.localizedDescription)")
            }
            return
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test("Persist touch unpermitted model")
    func persistTouchUnpermittedModel() throws {
        let container = try ModelContainer(V0_0_2.self, migration: Migration.self, at: nil)
        let model = V0_0_1.Test(flag: true, someValue: "xyz", randomValue: 122)
        model.context = container.context
        model._setupFields()
        
        do {
            model.flag.toggle()
            try container.context.save()
        } catch let error as ManagedObjectContextError {
            switch error {
                case .inactiveModelType(let errorCausingModel):
                    #expect(errorCausingModel.id == model.id)
                default:
                    Issue.record("Unexpected error: \(error.localizedDescription)")
            }
            return
        } catch {
            Issue.record("Unexpected error: \(error.localizedDescription)")
            return
        }
        Issue.record("Unexpectedly no error was thrown")
    }
    
    @Test("Delete unpermitted model")
    func deleteUnpermittedModel() throws {
        let container = try ModelContainer(V0_0_2.self, migration: Migration.self, at: nil)
        let model = V0_0_1.Test(flag: true, someValue: "xyz", randomValue: 122)
        model.context = container.context
        model._setupFields()
        
        do {
            try container.context.delete(model)
        } catch {
            switch error {
                case .inactiveModelType(let errorCausingModel):
                    #expect(errorCausingModel.id == model.id)
                default:
                    Issue.record("Unexpected error: \(error.localizedDescription)")
            }
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

fileprivate enum V0_0_3: VersionedSchema {
    static let version = ModelVersion(0, 0, 3)
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
        [V0_0_1.self, V0_0_2.self, V0_0_3.self]
    }
    
    static var stages: [MigrationStage] {
        [
            migrateV1toV2,
            migrateV2toV3
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
    
    static let migrateV2toV3 = MigrationStage.complex(
        fromVersion: V0_0_2.self,
        toVersion: V0_0_3.self,
        willMigrate: { context in
            let tests = try context.fetchAll(V0_0_1.Test.self)
            
            try V0_0_2.Test.unchangedMigration(to: V0_0_3.Test.self, on: context)
        },
        didMigrate: nil
    )
}
