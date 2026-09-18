import Foundation
import Testing
import SQLiteDB
import SQLCipher
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct ManagedObjectContextTests {
    @Test("Context without changes doesn't attempt transaction")
    func contextWithoutChangesIsNotAttemptingWrites() async throws {
        let connection = try Connection()
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )
        
        #expect(!container.context.hasChanges)
        
        let handle = connection.handle
        
        sqlite3_set_authorizer(handle, { _, action, _, _, _, _ in
            // Deny everything to confirm nothing is ran.
            return SQLITE_DENY
        }, nil)
        
        try container.context.save()
    }
    
    @Test("Save restores changes after failing")
    func saveRestoresChangesAfterFailing() async throws {
        let connection = try Connection()
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )
        
        let toDelete = V0_0_1.Test(flag: true)
        let toUpdate = V0_0_1.Test(flag: false)
        let toInsert = V0_0_1.Test(flag: true)
        
        try container.context.insert(toDelete)
        try container.context.insert(toUpdate)
        try container.context.save()
        
        try container.context.insert(toInsert)
        try container.context.delete(toDelete)
        toUpdate.flag = true
        
        let identifier = ObjectIdentifier(V0_0_1.Test.self)
        
        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == toInsert.id })
            
            #expect(updates[identifier, default: [:]].count == 1)
            #expect(updates[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
            
            #expect(deletes[identifier, default: [:]].count == 1)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toDelete.id })
            
            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }
        
        let handle = connection.handle
        
        sqlite3_set_authorizer(handle, { _, action, _, _, _, _ in
            // Deny everything to make save fail.
            return SQLITE_DENY
        }, nil)
        
        do {
            try container.context.save()
            Issue.record("Should've thrown.")
        } catch let error as SQLiteDB.Result {
            #expect(error.description == "not authorized (code: 23)")
        }
        
        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == toInsert.id })
            
            #expect(updates[identifier, default: [:]].count == 1)
            #expect(updates[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
            
            #expect(deletes[identifier, default: [:]].count == 1)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toDelete.id })
            
            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }
    }
    
    @Test("Save clears write cache")
    func saveClearsWriteCache() async throws {
        let connection = try Connection()
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )
        
        let toDelete = V0_0_1.Test(flag: true)
        let toUpdate = V0_0_1.Test(flag: false)
        let toInsert = V0_0_1.Test(flag: true)
        
        try container.context.insert(toDelete)
        try container.context.insert(toUpdate)
        try container.context.save()
        
        try container.context.insert(toInsert)
        try container.context.delete(toDelete)
        toUpdate.flag = true
        
        let identifier = ObjectIdentifier(V0_0_1.Test.self)
        
        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == toInsert.id })
            
            #expect(updates[identifier, default: [:]].count == 1)
            #expect(updates[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
            
            #expect(deletes[identifier, default: [:]].count == 1)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toDelete.id })
            
            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }
        
        try container.context.save()
        
        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts.isEmpty)
            #expect(updates.isEmpty)
            #expect(deletes.isEmpty)
            #expect(states.isEmpty)
        }
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]
    
    @Model
    final class Test: Identifiable {
        @Field
        var flag: Bool
        
        init(flag: Bool) {
            self.flag = flag
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] { [] }
}
