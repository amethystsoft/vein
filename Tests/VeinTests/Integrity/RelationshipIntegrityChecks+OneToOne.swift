import Foundation
import Testing
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite("Relationship Integrity Check Tests")
struct RelationshipIntegrityChecks {
    @Test
    func `one side doesn't have table`() async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.test.relationship-integrity-check.onetoone",
            encryptionEnabled: false
        )
        
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")
        
        try container.context.insert(owner)
        owner.target = target
        try container.context.save()
        
        let connection = container.getConnection()
        _ = try connection.execute("DROP TABLE IF EXISTS '\(Target.schema)';")
        
        let tables = try container.context.getAllStoredSchemas()
        #expect(!tables.contains(Target.schema))
        
        try expectInverseMissing(
            container,
            ownerID: owner.id,
            targetID: target.id
        )
    }
    
    @Test
    func `one side doesn't have model`() async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.test.relationship-integrity-check.onetoone",
            encryptionEnabled: false
        )
        
        let owner = Owner(name: "Mia")
        let owner2 = Owner(name: "amogus")
        let target = Target(name: "Coral")
        let target2 = Target(name: "sugoma")
        
        try container.context.insert(owner)
        try container.context.insert(owner2)
        owner.target = target
        owner2.target = target2
        try container.context.save()
        
        let connection = container.getConnection()
        let query = Table(Target.schema)
            .where(SQLExpression<String>("id") == target.id.ulidString)
            .delete()
        _ = try connection.run(query)
        
        let fetchedTargets = try container.context.fetchAll(Target.self)
        #expect(fetchedTargets.count == 1)
        
        try expectInverseMissing(
            container,
            ownerID: owner.id,
            targetID: target.id
        )
    }
    
    func expectInverseMissing(_ container: ModelContainer, ownerID: ULID, targetID: ULID) throws {
        let reports = try container.context.checkRelationshipIntegrity()
        let ownerReport = reports.first { $0.schema == Owner.schema }!
        let targetReport = reports.first { $0.schema == Target.schema }!
        
        #expect(targetReport.models.isEmpty == true)
        #expect(ownerReport.models.count == 1)
        
        guard let report = ownerReport.models.first else {
            return
        }
        
        #expect(report.id == ownerID)
        #expect(report.localMismatches.isEmpty)
        
        #expect(report.inverseMismatches["target"] != nil)
        #expect(report.inverseMismatches["target"]?[targetID.ulidString] == .missingInInverse)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]
    
    @Model
    final class Owner: Identifiable {
        var name: String
        
        @Relationship(inverse: \Target.owner)
        var target: Target?
        
        init(name: String) {
            self.name = name
        }
    }
    
    @Model
    final class Target: Identifiable {
        var name: String
        
        @Relationship
        var owner: Owner?
        
        init(name: String) {
            self.name = name
        }
    }
}

fileprivate typealias Owner = V0_0_1.Owner
fileprivate typealias Target = V0_0_1.Target

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
}
