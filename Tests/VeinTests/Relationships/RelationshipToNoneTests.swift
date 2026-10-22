import Foundation
import Testing
import Logging
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite struct `Relationship to none` {
    @Test func `many to none inserts new models`() async throws {
        let container = try ModelContainer(
            V1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.relationship-to-none",
            encryptionEnabled: false
        )
        
        let parent = V1.Parent()
        let child = V1.Child()
        
        try container.context.insert(parent)
        
        parent.children = [child]
        
        #expect(child.isManaged)
    }
    
    @Test func `one to none inserts new models`() async throws {
        let container = try ModelContainer(
            V2.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.relationship-to-none",
            encryptionEnabled: false
        )
        
        let parent = V2.Parent()
        let child = V2.Child()
        
        try container.context.insert(child)
        
        child.parent = parent
        
        #expect(parent.isManaged)
    }
}

fileprivate enum V1: VersionedSchema {
    static let version: Vein.ModelVersion = .init(1, 0, 0)
    
    static let models: [any Vein.PersistentModel.Type] = [Parent.self, Child.self]
    
    @Model
    final class Parent {
        @Relationship
        var children: [Child]
        
        init() {}
    }
    
    @Model
    final class Child {
        init() {}
    }
}

fileprivate enum V2: VersionedSchema {
    static let version: Vein.ModelVersion = .init(2, 0, 0)
    
    static let models: [any Vein.PersistentModel.Type] = [Parent.self, Child.self]
    
    @Model
    final class Parent {
        
        init() {}
    }
    
    @Model
    final class Child {
        @Relationship
        var parent: Parent?
        
        init() {}
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static let stages: [Vein.MigrationStage] = []
    
    static let schemas: [any Vein.VersionedSchema.Type] = [
        V1.self, V2.self
    ]
}
