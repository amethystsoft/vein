import Foundation
import Testing
import Logging
@testable import Vein
@testable import VeinCore

extension MigrationTests {
    @Test func throwsNoMatchingSchemaVersion() async throws {
        let path = try prepareContainerLocation(name: "determineSchemaVersion")
        let container = try ModelContainer(
            Version0_0_1.self,
            migration: SetupMigrationPlan.self,
            at: path
        )
        let originModel = Version0_0_1.BasicModel(field: "very important content")
        try container.context.insert(originModel)
        try container.context.save()
        
        let newContainer = try ModelContainer(
            Version0_0_2.self,
            migration: MigrationPlan.self,
            at: path
        )
        do {
            try newContainer.migrate()
        } catch let error as ManagedObjectContextError {
            if
                case let .noSchemaMatchingVersion(
                    migration,
                    version
                ) = error
            {
                #expect("\(migration)" == "\(MigrationPlan.self)")
                #expect(version == Version0_0_1.version)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
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
        [Version0_0_2.self]
    }
    
    static var stages: [Vein.MigrationStage] {[
        v1ToV2,
    ]}
    
    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version0_0_1.self,
        toVersion: Version0_0_2.self,
        willMigrate: nil,
        didMigrate: nil
    )
}

// NEVER POINT DIFFERENT SCHEMAMIGRATIONPLANS TO THE SAME DATABASE
// only done here to easily test an error case
fileprivate enum SetupMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [Version0_0_1.self]
    }
    
    static var stages: [Vein.MigrationStage] {[]}
}

