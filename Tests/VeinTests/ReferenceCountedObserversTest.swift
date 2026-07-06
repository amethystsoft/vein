import Foundation
import Testing
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct ReferenceCountedObserversTest {
    @Test("Observer is retained until all registered keys are removed")
    mutating func observerRetaining() {
        var tracker = _ReferenceCountedObservers()
        let targetID = ULID()
        var notificationCount = 0
        let observer = { notificationCount += 1 }
        
        // 1. Add first relationship field
        tracker.addObserver(id: targetID, key: "parent", observer: observer)
        #expect(tracker.references[targetID] == ["parent"])
        #expect(tracker.observers[targetID] != nil)
        
        // 2. Add second relationship field
        tracker.addObserver(id: targetID, key: "test", observer: observer)
        #expect(tracker.references[targetID] == ["parent", "test"])
        
        // 3. Remove first key; observer persists
        tracker.removeObserver(id: targetID, key: "parent")
        #expect(tracker.references[targetID] == ["test"])
        #expect(tracker.observers[targetID] != nil)
        
        // Verify notification still triggers
        tracker.notifyAll()
        #expect(notificationCount == 1)
        
        // 4. Remove final key; observer is cleaned up
        tracker.removeObserver(id: targetID, key: "test")
        #expect(tracker.references[targetID] == nil)
        #expect(tracker.observers[targetID] == nil)
    }
    
    @Test("Observers persist and clean up across multiple relationships (OneRelationship)")
    func observerPersistanceAndCleanupOneRelationship() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.observers",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let parent = V0_0_1.Test()
        let child = V0_0_1.Child()
        
        try container.context.insert(parent)
        try container.context.insert(child)
        
        let childID = child.id
        let parentID = parent.id
        
        // 1. Act & Assert: Connect first relationship
        child.parent = parent
        #expect(parent._observers.value.references[childID]?.contains("parent") == true)
        #expect(child._observers.value.references[parentID]?.contains("children") == true)
        
        // 2. Act & Assert: Connect second relationship
        child.test = parent
        #expect(parent._observers.value.references[childID] == ["parent", "test"])
        #expect(parent._observers.value.observers[childID] != nil)
        
        #expect(child._observers.value.references[parentID] == ["children", "otherChildren"])
        #expect(child._observers.value.observers[parentID] != nil)
        
        // 3. Act & Assert: Disconnect first relationship
        child.parent = nil
        #expect(parent._observers.value.references[childID] == ["test"])
        #expect(parent._observers.value.observers[childID] != nil)
        
        #expect(child._observers.value.references[parentID] == ["otherChildren"])
        #expect(child._observers.value.observers[parentID] != nil)
        
        // 4. Act & Assert: Disconnect second relationship
        child.test = nil
        #expect(parent._observers.value.references[childID] == nil)
        #expect(parent._observers.value.observers[childID] == nil)
        
        #expect(parent._observers.value.references[parentID] == nil)
        #expect(parent._observers.value.observers[parentID] == nil)
    }
    
    @Test("Observers persist and clean up across multiple relationships (ManyRelationship)")
    func observerPersistanceAndCleanupManyRelationship() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.observers",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let parent = V0_0_1.Test()
        let child = V0_0_1.Child()
        
        try container.context.insert(parent)
        try container.context.insert(child)
        
        let childID = child.id
        let parentID = parent.id
        
        // 1. Act & Assert: Connect first relationship
        parent.children.append(child)
        #expect(parent._observers.value.references[childID]?.contains("parent") == true)
        #expect(child._observers.value.references[parentID]?.contains("children") == true)
        
        // 2. Act & Assert: Connect second relationship
        parent.otherChildren.append(child)
        #expect(parent._observers.value.references[childID] == ["parent", "test"])
        #expect(parent._observers.value.observers[childID] != nil)
        
        #expect(child._observers.value.references[parentID] == ["children", "otherChildren"])
        #expect(child._observers.value.observers[parentID] != nil)
        
        // 3. Act & Assert: Disconnect first relationship
        parent.children = []
        #expect(parent._observers.value.references[childID] == ["test"])
        #expect(parent._observers.value.observers[childID] != nil)
        
        #expect(child._observers.value.references[parentID] == ["otherChildren"])
        #expect(child._observers.value.observers[parentID] != nil)
        
        // 4. Act & Assert: Disconnect second relationship
        parent.otherChildren = []
        #expect(parent._observers.value.references[childID] == nil)
        #expect(parent._observers.value.observers[childID] == nil)
        
        #expect(parent._observers.value.references[parentID] == nil)
        #expect(parent._observers.value.observers[parentID] == nil)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self, Child.self]
    
    @Model
    final class Test {
        @Relationship(inverse: \Child.parent)
        var children: [Child]
        
        @Relationship(inverse: \Child.test)
        var otherChildren: [Child]
        
        init() {}
    }
    
    @Model
    final class Child {
        @Relationship
        var parent: Test?
        
        @Relationship
        var test: Test?
        
        init() {}
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
}
