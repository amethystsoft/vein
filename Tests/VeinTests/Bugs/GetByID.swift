import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein

#if TEST_SWIFTUI
@testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
@testable import VeinCore
#endif

@Suite
struct BugTests {
    @Test
    func getByID() async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.BugTests"
        )
        
        let model1 = V0_0_1.User(name: "Test")
        let model2 = V0_0_1.User(name: "Test2")
        
        try container.context.insert(model1)
        try container.context.insert(model2)
        try container.context.save()
        
        let connection = container.getConnection()
        
        let newContainer = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.BugTests"
        )
            
        let result = try newContainer.context.getModel(id: model1.id, type: V0_0_1.User.self)
        #expect(result?.name == model1.name)
        
        let result2 = try newContainer.context.getModel(id: model2.id, type: V0_0_1.User.self)
        #expect(result2?.name == model2.name)
    }
}


fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self]
    
    @Model
    final class User: Identifiable {
        @Field
        var name: String
        
        init(name: String) {
            self.name = name
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {[]}
}
