import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension MigrationTests {
    @Test func versionedSchemaIsNotPartOfSchemaMigrationPlan() async throws {
        let path = try prepareContainerLocation(name: "ModelContainerErrors")
        
        do {
            let _ = try ModelContainer(
                Version0_0_2.self,
                migration: MigrationPlan.self,
                at: path
            )
        } catch {
            if
                case let .schemaNotRegisteredOnMigrationPlan(
                    schema,
                    migration
                ) = error
            {
                #expect("\(schema)" == "\(Version0_0_2.self)")
                #expect("\(migration)" == "\(MigrationPlan.self)")
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        }
        
        Issue.record("Unexpectedly no error was thrown")
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


fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [
            Version0_0_1.self
        ]
    }
    
    static var stages: [Vein.MigrationStage] { [] }
}

