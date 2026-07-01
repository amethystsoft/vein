import Foundation
import Testing
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct PersistableTests {
    @Test
    func testRawRepresentablePersistable() async throws {
        let (connection, objectID) = try setupContainer()
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.tests.persistable",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        guard
            let model = try container.context.fetchAll(V0_0_1.Account.self).first
        else {
            Issue.record("Unexpectedly found no model.")
            return
        }
        
        #expect(model.accountType == .admin)
        // Confirm the fetched model is really fetched from the db,
        // not just from an identity map.
        #expect(ObjectIdentifier(model) != objectID)
    }
    
    @Test
    func testRawRepresentablePersistableUpdate() async throws {
        let (connection, objectID) = try setupContainer()
        let newObjectID = try runUpdate()
        
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.tests.persistable",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        guard
            let model = try container.context.fetchAll(V0_0_1.Account.self).first
        else {
            Issue.record("Unexpectedly found no model.")
            return
        }
        
        #expect(model.accountType == .user)
        // Confirm the fetched model is really fetched from the db,
        // not just from an identity map.
        #expect(ObjectIdentifier(model) != objectID)
        #expect(ObjectIdentifier(model) != newObjectID)
        
        func runUpdate() throws -> ObjectIdentifier? {
            let updateContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.tests.persistable",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            
            guard
                let model = try updateContainer.context.fetchAll(V0_0_1.Account.self).first
            else {
                Issue.record("Unexpectedly found no model.")
                return nil
            }
            
            #expect(model.accountType == .admin)
            // Confirm the fetched model is really fetched from the db,
            // not just from an identity map.
            #expect(ObjectIdentifier(model) != objectID)
            
            model.accountType = .user
            
            #expect(updateContainer.context.hasChanges)
            
            try updateContainer.context.save()
            
            return ObjectIdentifier(model)
        }
    }
    
    private func setupContainer() throws -> (Connection, ObjectIdentifier) {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.persistable",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        
        let model = V0_0_1.Account(accountType: .admin)
        try container.context.insert(model)
        try container.context.save()
        
        return (
            container.getConnection(),
            ObjectIdentifier(model)
        )
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Account.self]
    
    @Model
    final class Account: Identifiable {
        var accountType: AccountType
        
        init(accountType: AccountType) {
            self.accountType = accountType
        }
        
        enum AccountType: String, RawRepresentablePersistable {
            case user
            case admin
            case moderator
        }
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
