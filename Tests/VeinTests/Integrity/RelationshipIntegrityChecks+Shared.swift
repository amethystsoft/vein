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

extension RelationshipIntegrityChecks {
    @Test
    func `corrupted primaryULID`() async throws {
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
        let query = Table(Owner.schema)
            .where(SQLExpression<String>("id") == owner.id.ulidString)
            .update(SQLExpression<String>("id") <- "notAValidULID")
        _ = try connection.run(query)
        
        let reports = try container.context.checkRelationshipIntegrity()
        
        let ownerReport = reports.first { $0.schema == Owner.schema }!
        let targetReport = reports.first { $0.schema == Target.schema }!
        
        #expect(targetReport.models.count == 1)
        #expect(ownerReport.models.count == 1)
        
        guard
            let ownerReport = ownerReport.models.first,
            let targetReport = targetReport.models.first
        else {
            return
        }
        
        #expect(ownerReport.idString == "notAValidULID")
        #expect(ownerReport.inverseMismatches.isEmpty)
        #expect(ownerReport.localMismatches.count == 1)
        #expect(ownerReport.localMismatches["id"] == .corruptedData)
        
        #expect(targetReport.id == target.id)
        #expect(targetReport.localMismatches.isEmpty)
        #expect(targetReport.inverseMismatches.count == 1)
        #expect(targetReport.inverseMismatches["owner"]?[owner.id.ulidString] == .missingInInverse)
    }
    
    @Test
    func `Corrupted one-relationship data`() async throws {
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
        let query = Table(Owner.schema)
            .where(SQLExpression<String>("id") == owner.id.ulidString)
            .update(SQLExpression<String>("target") <- "notAValidULID")
        _ = try connection.run(query)
        
        let reports = try container.context.checkRelationshipIntegrity()
        
        let ownerReport = reports.first { $0.schema == Owner.schema }!
        let targetReport = reports.first { $0.schema == Target.schema }!
        
        #expect(targetReport.models.count == 1)
        #expect(ownerReport.models.count == 1)
        
        guard
            let ownerReport = ownerReport.models.first,
            let targetReport = targetReport.models.first
        else { return }
        
        #expect(ownerReport.idString == owner.id.ulidString)
        #expect(ownerReport.inverseMismatches.isEmpty)
        #expect(ownerReport.localMismatches.count == 1)
        #expect(ownerReport.localMismatches["target"] == .corruptedData)
        
        #expect(targetReport.idString == target.id.ulidString)
        #expect(targetReport.inverseMismatches.count == 1)
        #expect(targetReport.localMismatches.isEmpty)
        #expect(targetReport.inverseMismatches["owner"]?[owner.id.ulidString] == .corruptedData)
    }
    
    @Test
    func `Corrupted many-relationship data`() async throws {
        let container = try ModelContainer(
            V0_0_2.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.test.relationship-integrity-check.manytoone",
            encryptionEnabled: false
        )
        
        let owner = V0_0_2.Owner(name: "Mia")
        let target = V0_0_2.Target(name: "Coral")
        
        try container.context.insert(owner)
        owner.targets.append(target)
        try container.context.save()
        
        let connection = container.getConnection()
        
        let query = Table(V0_0_2.Owner.schema)
            .where(SQLExpression<String>("id") == owner.id.ulidString)
            .update(SQLExpression<Data>("targets") <- SQLExpression<Data>("jsonb(?)", ["{\"id\": 1234}"]))
        _ = try connection.run(query)
        
        let reports = try container.context.checkRelationshipIntegrity()
        
        let ownerReport = reports.first { $0.schema == V0_0_2.Owner.schema }!
        let targetReport = reports.first { $0.schema == V0_0_2.Target.schema }!
        
        #expect(targetReport.models.count == 1)
        #expect(ownerReport.models.count == 1)
        
        guard
            let ownerReport = ownerReport.models.first,
            let targetReport = targetReport.models.first
                else { return }
        
        #expect(ownerReport.idString == owner.id.ulidString)
        #expect(ownerReport.inverseMismatches.isEmpty)
        #expect(ownerReport.localMismatches.count == 1)
        #expect(ownerReport.localMismatches["targets"] == .corruptedData)
        
        #expect(targetReport.idString == target.id.ulidString)
        #expect(targetReport.inverseMismatches.count == 1)
        #expect(targetReport.localMismatches.isEmpty)
        #expect(targetReport.inverseMismatches["owner"]?[owner.id.ulidString] == .corruptedData)
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

fileprivate enum V0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]
    
    @Model
    final class Owner: Identifiable {
        var name: String
        
        @Relationship(inverse: \Target.owner)
        var targets: [Target]
        
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
        [V0_0_1.self, V0_0_2.self]
    }
    
    static var stages: [MigrationStage] {
        []
    }
}
