import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension MigrationTests {
    @Test func testMigrationStoppingAtPassedVersion() async throws {
        let path = try prepareContainerLocation(name: "testMigrationStoppingAtPassedVersion")
        let container = try ModelContainer(
            Version0_0_1.self,
            migration: MigrationPlan.self,
            at: path
        )
        
        let initial = Version0_0_1.BasicModel(field: "how did we get here")
        try container.context.insert(initial)
        
        let schemas = try container.context.getAllStoredSchemas()
        
        #expect(schemas == [Version0_0_1.BasicModel.schema])
        
        let version = try container.context.getLatestMigrationVersion()
        #expect(version == Version0_0_1.version)
        
        let newContainer = try ModelContainer(
            Version0_0_2.self,
            migration: MigrationPlan.self,
            at: path
        )
        
        try newContainer.migrate()
        
        let newSchemas = try newContainer.context.getAllStoredSchemas()
        #expect(newSchemas == [Version0_0_2.BasicModel.schema])
        
        let newVersion = try newContainer.context.getLatestMigrationVersion()
        #expect(newVersion == Version0_0_2.version)
    }
}

fileprivate enum Version0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    
    static var models: [any Vein.PersistentModel.Type] {[
        BasicModel.self
    ]}
    
    
    @Model
    final class BasicModel {
        @Field
        var field: String
        
        init(field: String) {
            self.field = field
        }
    }
}

fileprivate enum Version0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    
    static var models: [any Vein.PersistentModel.Type] {[
        BasicModel.self
    ]}
    
    
    @Model
    final class BasicModel {
        @Field
        var field: String
        
        init(field: String) {
            self.field = field
        }
    }
}

fileprivate enum Version0_0_3: VersionedSchema {
    static let version = ModelVersion(0, 0, 3)
    
    static var models: [any Vein.PersistentModel.Type] {[
        BasicModel.self
    ]}
    
    
    @Model
    final class BasicModel {
        @Field
        var field: String
        
        init(field: String) {
            self.field = field
        }
    }
}


fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [
            Version0_0_1.self,
            Version0_0_2.self,
            Version0_0_3.self
        ]
    }
    
    static var stages: [Vein.MigrationStage] { [
        v1ToV2,
        v2ToV3
    ] }
    
    static let v1ToV2 = MigrationStage.complex(
        fromVersion: Version0_0_1.self,
        toVersion: Version0_0_2.self,
        willMigrate: { context in
            try Version0_0_1.BasicModel
                .unchangedMigration(
                    to: Version0_0_2.BasicModel.self,
                    on: context
                )
        },
        didMigrate: nil
    )
    
    static let v2ToV3 = MigrationStage.complex(
        fromVersion: Version0_0_2.self,
        toVersion: Version0_0_3.self,
        willMigrate: { context in
            try Version0_0_2.BasicModel
                .unchangedMigration(
                    to: Version0_0_3.BasicModel.self,
                    on: context
                )
        },
        didMigrate: nil
    )
}

