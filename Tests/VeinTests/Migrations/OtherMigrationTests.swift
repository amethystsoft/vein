import Foundation
import Testing
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct OtherMigrationTests {
    func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            Version0_0_1.self,
            migration: MigrationPlan.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.OtherMigrationTests",
            encryptionEnabled: false
        )
    }
    
    @Test
    @MainActor
    func `didMigrate gets called`() async throws {
        let container = try makeContainer()
        let model = Version0_0_1.BasicModel(field: "test")
        try container.context.insert(model)
        try container.context.save()
        
        let newContainer = try ModelContainer(
            Version0_0_2.self,
            migration: MigrationPlan.self,
            connection: container.getConnection(),
            appID: "de.amethystsoft.vein.tests.OtherMigrationTests",
            encryptionEnabled: false
        )
        try newContainer.migrate()
        
        let result = try newContainer.context.fetchAll(Version0_0_2.BasicModel.self)
        guard let first = result.first else {
            Issue.record("Unexpectedly empty result")
            return
        }
        #expect(first.field == "didMigrate was called")
        #expect(newContainer.context.hasChanges)
    }
    
    @Test
    func `empty db doesn't require migration`() async throws {
        let container = try makeContainer()
        let version = try container.context.getLatestMigrationVersion()
        #expect(version == nil)
    }
    
    @Test
    @MainActor
    func `cleanup old schema without migration throws`() async throws {
        let container = try makeContainer()
        do {
            try container.context.cleanupOldSchema(Version0_0_1.self)
            Issue.record("Unexpectedly no error was thrown")
        } catch let error as ManagedObjectContextError {
            if case .notInsideMigration(let string) = error {
                #expect(string == "ManagedObjectContext/cleanupOldSchema")
                return
            }
            throw error
        }
    }
    
    @Test
    @MainActor
    func `unchangedMigration outside of migration throws`() async throws {
        let container = try makeContainer()
        do {
            try Version0_0_1.BasicModel.unchangedMigration(
                to: Version0_0_2.BasicModel.self,
                on: container.context
            )
            Issue.record("Unexpectedly no error was thrown")
        } catch let error as ManagedObjectContextError {
            if case .notInsideMigration(let string) = error {
                #expect(string == "PersistentModel/unchangedMigration")
                return
            }
            throw error
        }
    }
    
    @Test
    @MainActor
    func `deleteMigration outside of migration throws`() async throws {
        let container = try makeContainer()
        do {
            try Version0_0_1.BasicModel.deleteMigration(on: container.context)
            Issue.record("Unexpectedly no error was thrown")
        } catch let error as ManagedObjectContextError {
            if case .notInsideMigration(let string) = error {
                #expect(string == "PersistentModel/deleteMigration")
                return
            }
            throw error
        }
    }
    
    @Test
    @MainActor
    func `fieldsAddedMigration outside of migration throws`() async throws {
        let container = try makeContainer()
        do {
            try Version0_0_1.BasicModel.fieldsAddedMigration(
                to: Version0_0_2.BasicModel.self,
                on: container.context
            )
            Issue.record("Unexpectedly no error was thrown")
        } catch let error as ManagedObjectContextError {
            if case .notInsideMigration(let string) = error {
                #expect(string == "PersistentModel/fieldsAddedMigration")
                return
            }
            throw error
        }
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
        var field: String
        var field1: String?
        
        init(field: String) {
            self.field = field
        }
    }
}

fileprivate enum MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [
            Version0_0_1.self,
            Version0_0_2.self
        ]
    }
    
    static var stages: [Vein.MigrationStage] { [v1ToV2] }
    
    static let v1ToV2 = Vein.MigrationStage.complex(
        fromVersion: Version0_0_1.self,
        toVersion: Version0_0_2.self,
        willMigrate: { context in
            try Version0_0_1.BasicModel.unchangedMigration(
                to: Version0_0_2.BasicModel.self,
                on: context
            )
        },
        didMigrate: { context in
            let all = try context.fetchAll(Version0_0_2.BasicModel.self)
            for model in all {
                model.field = "didMigrate was called"
            }
        }
    )
}
