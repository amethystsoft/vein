import Foundation
import Testing
@testable import Vein
@testable import VeinCore

@MainActor
struct WriteCache {
    
    private func setupContainer() throws -> ModelContainer {
        let container = try ModelContainer(V0_0_1.self, migration: Migration.self, at: nil)
        return container
    }
    
    @Test("Test Insert tracking")
    func testInsertTracking() throws {
        let container = try setupContainer()
        let model = V0_0_1.Test(flag: true, someValue: "Hello", randomValue: 42)
        
        try container.context.insert(model)
        
        #expect(container.context.hasChanges == true)
        #expect(model.context === container.context)
        
        container.context.writeCache.mutate { inserts, touches, deletes, _ in
            let typedInserts = inserts[V0_0_1.Test.typeIdentifier]
            #expect(typedInserts?.count == 1)
            #expect(typedInserts?[model.id] === model)
            #expect(touches.isEmpty)
            #expect(deletes.isEmpty)
        }
    }
    
    @Test("Test Mark Touched (Update) tracking")
    func testUpdateTracking() throws {
        let container = try setupContainer()
        let model = V0_0_1.Test(flag: true, someValue: "Initial", randomValue: 1)
        
        // Mocking a persisted state: context is set, but not in current write cache
        model.context = container.context
        model._setupFields()
        
        model.someValue = "Updated"
        
        #expect(container.context.hasChanges == true)
        container.context.writeCache.mutate { inserts, touches, deletes, states in
            let typedTouches = touches[V0_0_1.Test.typeIdentifier]
            #expect(typedTouches?[model.id] === model)
            
            // Check primitive state was captured for rollback
            let state = states[V0_0_1.Test.typeIdentifier]?[model.id]
            #expect(state != nil)
        }
    }
    
    @Test("Test Delete tracking")
    func testDeleteTracking() throws {
        let container = try setupContainer()
        let model = V0_0_1.Test(flag: true, someValue: "DeleteMe", randomValue: 10)
        model.context = container.context
        
        try container.context.delete(model)
        
        #expect(container.context.hasChanges == true)
        #expect(model.context == nil)
        
        container.context.writeCache.mutate { _, _, deletes, _ in
            let typedDeletes = deletes[V0_0_1.Test.typeIdentifier]
            #expect(typedDeletes?[model.id] === model)
        }
    }
    
    @Test("Test State Transition: Delete after Insert")
    func testDeleteAfterInsert() throws {
        let container = try setupContainer()
        let model = V0_0_1.Test(flag: true, someValue: "New", randomValue: 5)
        
        try container.context.insert(model)
        try container.context.delete(model)
        
        container.context.writeCache.mutate { inserts, touches, deletes, _ in
            let typeID = V0_0_1.Test.typeIdentifier
            // Deleting a new object should nullify the insert and just place it in deletes
            #expect(inserts[typeID]?[model.id] == nil)
            #expect(touches[typeID]?[model.id] == nil)
            #expect(deletes[typeID]?[model.id] === model)
        }
    }
    
    @Test("Test Rollback restores state")
    func testRollback() throws {
        let container = try setupContainer()
        
        // Test Insert Rollback
        let newModel = V0_0_1.Test(flag: true, someValue: "New", randomValue: 5)
        try container.context.insert(newModel)
        container.context.rollback()
        #expect(newModel.context == nil)
        #expect(container.context.hasChanges == false)
        
        // Test Update Rollback
        let existingModel = V0_0_1.Test(flag: false, someValue: "Original", randomValue: 100)
        existingModel.context = container.context
        existingModel._setupFields()

        existingModel.someValue = "Changed"
        
        container.context.rollback()
        #expect(existingModel.someValue == "Original")
        #expect(container.context.hasChanges == false)
        
        // Test Delete Rollback
        let deleteModel = V0_0_1.Test(flag: true, someValue: "New", randomValue: 5)
        deleteModel.context = container.context
        deleteModel._setupFields()
        
        try container.context.delete(deleteModel)
        #expect(deleteModel.context == nil)
        
        container.context.rollback()
        #expect(deleteModel.context != nil)
        #expect(container.context.hasChanges == false)
    }
    
    @Test("Test Save clears cache")
    func testSaveClearsCache() throws {
        let container = try setupContainer()
        let model = V0_0_1.Test(flag: true, someValue: "SaveMe", randomValue: 7)
        
        try container.context.insert(model)
        #expect(container.context.hasChanges == true)
        
        try container.context.save()
        
        #expect(container.context.hasChanges == false)
        container.context.writeCache.mutate { inserts, touches, deletes, _ in
            #expect(inserts.isEmpty)
            #expect(touches.isEmpty)
            #expect(deletes.isEmpty)
        }
    }
    
    @Test("Test Batch Delete")
    func testBatchDelete() throws {
        let container = try setupContainer()
        let m1 = V0_0_1.Test(flag: true, someValue: "1", randomValue: 1)
        let m2 = V0_0_1.Test(flag: true, someValue: "2", randomValue: 2)
        m1.context = container.context
        m2.context = container.context
        
        try container.context.batchDelete([m1, m2])
        
        container.context.writeCache.mutate { _, _, deletes, _ in
            let typedDeletes = deletes[V0_0_1.Test.typeIdentifier]
            #expect(typedDeletes?.count == 2)
            #expect(m1.context == nil)
            #expect(m2.context == nil)
        }
    }
    
    @Test("Fetch includes unwritten inserts")
    func fetchIncludesUnwrittenInserts() throws {
        let container = try setupContainer()
        let m1 = V0_0_1.Test(flag: true, someValue: "1", randomValue: 1)
        let m2 = V0_0_1.Test(flag: true, someValue: "2", randomValue: 2)
        
        try container.context.insert(m1)
        try container.context.save()
        
        try container.context.insert(m2)
        
        let results = try container.context.fetchAll(V0_0_1.Test.self)
        
        #expect(results.count == 2)
        #expect(results.contains { $0.id == m1.id })
        #expect(results.contains { $0.id == m2.id })
    }
    
    @Test("Fetch includes unwritten touches")
    func fetchIncludesUnwrittenTouches() throws {
        let container = try setupContainer()
        let m1 = V0_0_1.Test(flag: true, someValue: "1", randomValue: 1)
        let m2 = V0_0_1.Test(flag: true, someValue: "2", randomValue: 2)
        
        try container.context.insert(m1)
        try container.context.insert(m2)
        try container.context.save()
        
        m1.someValue = "2"
        
        let results = try container.context.fetchAll(
            V0_0_1.Test._PredicateHelper()
            .someValue(.isEqualTo, "2")
            ._builder()
        )
        
        #expect(results.count == 2)
        #expect(results.contains { $0.id == m1.id })
        #expect(results.contains { $0.id == m2.id })
        
        m2.someValue = "1"
        
        let secondResults = try container.context.fetchAll(
            V0_0_1.Test._PredicateHelper()
                .someValue(.isEqualTo, "2")
                ._builder()
        )
        
        #expect(secondResults.count == 1)
        #expect(secondResults.contains { $0.id == m1.id })
    }
    
    @Test("Fetch excludes unwritten deletes")
    func fetchExcludesUnwrittenDeletes() throws {
        let container = try setupContainer()
        let m1 = V0_0_1.Test(flag: true, someValue: "1", randomValue: 1)
        let m2 = V0_0_1.Test(flag: true, someValue: "2", randomValue: 2)
        
        try container.context.insert(m1)
        try container.context.insert(m2)
        try container.context.save()
        
        try container.context.delete(m1)
        
        let results = try container.context.fetchAll(V0_0_1.Test.self)
        
        #expect(results.count == 1)
        #expect(results.contains { $0.id == m2.id })
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
        [migrateV1toV2]
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
