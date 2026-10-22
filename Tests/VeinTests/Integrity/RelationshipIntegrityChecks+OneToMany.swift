// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

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

@Suite("Relationship Integrity Check Tests One to Many")
struct RelationshipIntegrityChecksOneToMany: RelationshipIntegrityCheckHelper {
    @Test
    func `one side doesn't have table`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.targets.append(target)
        } corrupt: { connection in
            _ = try connection.execute("DROP TABLE IF EXISTS '\(Target.schema)';")
        } validate: { reports in
            expectInverseMissing(
                reports: reports,
                ownerID: owner.id,
                targetID: target.id
            )
        }
    }

    @Test
    func `one side doesn't have model`() async throws {
        let owner = Owner(name: "Mia")
        let owner2 = Owner(name: "amogus")
        let target = Target(name: "Coral")
        let target2 = Target(name: "sugoma")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            try context.insert(owner2)
            owner.targets = [target, target2]
        } corrupt: { connection in
            let query = Table(Target.schema)
                .where(SQLExpression<String>("id") == target.id.ulidString)
                .delete()
            _ = try connection.run(query)
        } validate: { reports in
            expectInverseMissing(
                reports: reports,
                ownerID: owner.id,
                targetID: target.id
            )
        }
    }

    @Test
    func `inverse is nil`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.targets.append(target)
        } corrupt: { connection in
            let query = Table(Target.schema)
                .where(SQLExpression<String>("id") == target.id.ulidString)
                .update(SQLExpression<String?>("owner") <- nil)
            try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == Owner.schema }!
            let targetReport = reports.first { $0.schema == Target.schema }!

            #expect(targetReport.models.count == 0)
            #expect(ownerReport.models.count == 1)

            guard let ownerReport = ownerReport.models.first else { return }

            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.count == 1)
            #expect(ownerReport.localMismatches.isEmpty)
            #expect(ownerReport
                .inverseMismatches["targets"]?[target.id.ulidString] == .inverseMismatch(
                    found: nil,
                    expected: owner.id.ulidString
                ))
        }
    }

    @Test
    func `inverse is different (missingInInverse covered too)`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")
        let ulid = ULID()

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.targets.append(target)
        } corrupt: { connection in
            let query = Table(Target.schema)
                .where(SQLExpression<String>("id") == target.id.ulidString)
                .update(SQLExpression<String?>("owner") <- ulid.ulidString)
            try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == Owner.schema }!
            let targetReport = reports.first { $0.schema == Target.schema }!

            #expect(targetReport.models.count == 1)
            #expect(ownerReport.models.count == 1)

            guard
                let ownerReport = ownerReport.models.first,
                let targetReport = targetReport.models.first
            else { return }

            #expect(ownerReport.idString == owner.id.ulidString)
            #expect(ownerReport.inverseMismatches.count == 1)
            #expect(ownerReport.localMismatches.isEmpty)
            #expect(ownerReport
                .inverseMismatches["targets"]?[target.id.ulidString] == .inverseMismatch(
                    found: ulid.ulidString,
                    expected: owner.id.ulidString
                )
            )

            #expect(targetReport.idString == target.id.ulidString)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport.localMismatches.isEmpty)
            // used a fake ulid
            #expect(targetReport.inverseMismatches["owner"]?[ulid.ulidString] == .missingInInverse)
        }
    }

    @Test
    func `many side doesn't contain reference`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            try context.insert(target)
        } corrupt: { connection in
            let query = Table(Target.schema)
                .where(SQLExpression<String>("id") == target.id.ulidString)
                .update(SQLExpression<String?>("owner") <- owner.id.ulidString)
            try connection.run(query)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == Owner.schema }!
            let targetReport = reports.first { $0.schema == Target.schema }!

            #expect(targetReport.models.count == 1)
            #expect(ownerReport.models.count == 0)

            guard let targetReport = targetReport.models.first else { return }

            #expect(targetReport.idString == target.id.ulidString)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport.localMismatches.isEmpty)
            #expect(
                targetReport.inverseMismatches["owner"]?[owner.id.ulidString]
                    == .inverseCountMismatch(found: 0, expected: 1)
            )
        }
    }
    
    @Test
    func `catches everything wrong`() async throws {
        let inverseMissingOwner = V0_0_2.Owner(name: "Mia")
        let inverseFoundNilOwner = V0_0_2.Owner(name: "Nil, wie der Fluss?")
        let owner = V0_0_2.Owner(name: "boring")
        let bothWrongOwner = V0_0_2.Owner(name: "Emotional Damage")
        let target1 = V0_0_2.Target(name: "Coral")
        let target2 = V0_0_2.Target(name: "Coral")
        let unexpectedCountZeroTarget = V0_0_2.Target(name: "Coral")
        let trollTarget = V0_0_2.Target(name: "Troll")
        
        try check(V0_0_2.self, Migration.self) { context in
            try context.insert(inverseMissingOwner)
            try context.insert(inverseFoundNilOwner)
            try context.insert(owner)
            try context.insert(bothWrongOwner)
            
            inverseMissingOwner.targets = [target1]
            inverseFoundNilOwner.targets = [target2]
            owner.targets = [unexpectedCountZeroTarget]
            bothWrongOwner.targets = [trollTarget]
            bothWrongOwner.target = trollTarget
        } corrupt: { connection in
            let query = Table(V0_0_2.Target.schema)
                .where(SQLExpression<String>("id") == target1.id.ulidString)
                .delete()
            _ = try connection.run(query)
            
            let query2 = Table(V0_0_2.Target.schema)
                .where(SQLExpression<String>("id") == target2.id.ulidString)
                .update(SQLExpression<String?>("owner") <- nil)
            _ = try connection.run(query2)
            
            let query3 = Table(V0_0_2.Owner.schema)
                .where(SQLExpression<String>("id") == owner.id.ulidString)
                .update(SQLExpression<Data>("targets") <- SQLExpression(
                    "jsonb(?)",
                    ["[]"]
                ))
            _ = try connection.run(query3)
            
            let query4 = Table(V0_0_2.Target.schema)
                .where(SQLExpression<String>("id") == trollTarget.id.ulidString)
                .update([
                    SQLExpression<Data>("owners") <- SQLExpression(
                        "jsonb(?)",
                        ["[\"\(owner.id.ulidString)\"]"]
                    ),
                    SQLExpression<String?>("owner") <- owner.id.ulidString
                ])
            _ = try connection.run(query4)
        } validate: { reports in
            let ownerReport = reports.first { $0.schema == V0_0_2.Owner.schema }!
            let targetReport = reports.first { $0.schema == V0_0_2.Target.schema }!
            
            #expect(targetReport.models.count == 2)
            #expect(ownerReport.models.count == 3)
            
            guard
                let targetReport1 = targetReport.models.first(where: {
                    $0.idString == unexpectedCountZeroTarget.id.ulidString
                }),
                let targetReport2 = targetReport.models.first(where: {
                    $0.idString == trollTarget.id.ulidString
                }),
                let ownerReport1 = ownerReport.models.first(where: {
                    $0.idString == inverseMissingOwner.id.ulidString
                }),
                let ownerReport2 = ownerReport.models.first(where: {
                    $0.idString == inverseFoundNilOwner.id.ulidString
                }),
                let ownerReport3 = ownerReport.models.first(where: {
                    $0.idString == bothWrongOwner.id.ulidString
                })
            else {
                Issue.record("One or more reports were missing")
                return
            }
            
            #expect(targetReport1.inverseMismatches.count == 1)
            #expect(targetReport1.localMismatches.isEmpty)
            #expect(
                targetReport1.inverseMismatches["owner"]?[owner.id.ulidString]
                == .inverseCountMismatch(found: 0, expected: 1)
            )
            
            #expect(targetReport2.inverseMismatches.count == 2)
            #expect(targetReport2.localMismatches.isEmpty)
            #expect(
                targetReport2.inverseMismatches["owner"]?[owner.id.ulidString]
                == .inverseCountMismatch(found: 0, expected: 1)
            )
            #expect(
                targetReport2.inverseMismatches["owners"]?[owner.id.ulidString]
                == .inverseMismatch(found: nil, expected: trollTarget.id.ulidString)
            )
            
            #expect(ownerReport1.inverseMismatches.count == 1)
            #expect(ownerReport1.localMismatches.isEmpty)
            #expect(
                ownerReport1.inverseMismatches["targets"]?[target1.id.ulidString]
                == .missingInInverse
            )
            
            #expect(ownerReport2.inverseMismatches.count == 1)
            #expect(ownerReport2.localMismatches.isEmpty)
            #expect(
                ownerReport2.inverseMismatches["targets"]?[target2.id.ulidString]
                == .inverseMismatch(found: nil, expected: inverseFoundNilOwner.id.ulidString)
            )
            
            #expect(ownerReport3.inverseMismatches.count == 2)
            #expect(ownerReport3.localMismatches.isEmpty)
            #expect(
                ownerReport3.inverseMismatches["targets"]?[trollTarget.id.ulidString]
                == .inverseMismatch(found: owner.id.ulidString, expected: bothWrongOwner.id.ulidString)
            )
            #expect(
                ownerReport3.inverseMismatches["target"]?[trollTarget.id.ulidString]
                == .inverseCountMismatch(found: 0, expected: 1)
            )
        }
    }

    func expectInverseMissing(
        reports: [RelationshipIntegrityReport],
        ownerID: ULID,
        targetID: ULID
    ) {
        let ownerReport = reports.first { $0.schema == Owner.schema }!
        let targetReport = reports.first { $0.schema == Target.schema }!

        #expect(targetReport.models.isEmpty == true)
        #expect(ownerReport.models.count == 1)

        guard let report = ownerReport.models.first else {
            return
        }

        #expect(report.id == ownerID)
        #expect(report.localMismatches.isEmpty)

        #expect(report.inverseMismatches["targets"]?[targetID.ulidString] == .missingInInverse)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
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

fileprivate enum V0_0_2: VersionedSchema {
    static let version = ModelVersion(0, 0, 2)
    static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]
    
    @Model
    final class Owner: Identifiable {
        var name: String
        
        @Relationship(inverse: \Target.owner)
        var targets: [Target]
        
        @Relationship
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
        
        @Relationship(inverse: \Owner.target)
        var owners: [Owner]
        
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
