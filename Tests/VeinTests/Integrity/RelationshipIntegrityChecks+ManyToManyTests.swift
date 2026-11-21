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

@Suite("Relationship Integrity Check Tests Many to Many")
struct RelationshipIntegrityChecksManyToMany: RelationshipIntegrityCheckHelper {
    @Test
    func `one side doesn't have table`() async throws {
        let owner = Owner(name: "Mia")
        let owner2 = Owner(name: "Mia")
        let target = Target(name: "Coral")
        let target2 = Target(name: "Coral")
        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            try context.insert(owner2)
            owner.targets.append(target)
            owner2.targets.append(target2)
        } corrupt: { connection in
            _ = try connection.execute("DROP TABLE IF EXISTS '\(Target.schema)';")
        } validate: { reports in
            expectInverseMissing(
                reports: reports,
                ownerID: owner.id,
                owner2ID: owner2.id,
                targetID: target.id,
                target2ID: target2.id
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
            owner.targets = [target]
            owner2.targets = [target2]
        } corrupt: { connection in
            let query = Table(Target.schema)
                .where(
                    SQLExpression<String>("id") == target.id.ulidString
                        || SQLExpression<String>("id") == target2.id.ulidString
                )
                .delete()
            _ = try connection.run(query)
        } validate: { reports in
            expectInverseMissing(
                reports: reports,
                ownerID: owner.id,
                owner2ID: owner2.id,
                targetID: target.id,
                target2ID: target2.id
            )
        }
    }

    @Test
    func `inverse is different`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.targets = [target, target]
        } corrupt: { connection in
            let query = Table(Target.schema)
                .where(SQLExpression<String>("id") == target.id.ulidString)
                .update(SQLExpression<Data>("owners") <- SQLExpression(
                    "jsonb(?)",
                    ["[\"\(owner.id.ulidString)\"]"]
                ))
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
            #expect(
                ownerReport.inverseMismatches["targets"]?[target.id.ulidString]
                    == .inverseCountMismatch(found: 1, expected: 2)
            )

            #expect(targetReport.idString == target.id.ulidString)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport.localMismatches.isEmpty)
            #expect(
                targetReport.inverseMismatches["owners"]?[owner.id.ulidString]
                    == .inverseCountMismatch(found: 2, expected: 1)
            )
        }
    }

    func expectInverseMissing(
        reports: [RelationshipIntegrityReport],
        ownerID: ULID,
        owner2ID: ULID,
        targetID: ULID,
        target2ID: ULID
    ) {
        let ownerReport = reports.first { $0.schema == Owner.schema }!
        let targetReport = reports.first { $0.schema == Target.schema }!

        #expect(targetReport.models.isEmpty)
        #expect(ownerReport.models.count == 2)

        guard
            let report = ownerReport.models.first(where: { $0.id == ownerID }),
            let report2 = ownerReport.models.first(where: { $0.id == owner2ID })
        else { return }

        #expect(report.id == ownerID)
        #expect(report.localMismatches.isEmpty)
        #expect(report.inverseMismatches["targets"]?[targetID.ulidString] == .missingInInverse)

        #expect(report2.id == owner2ID)
        #expect(report2.localMismatches.isEmpty)
        #expect(report2.inverseMismatches["targets"]?[target2ID.ulidString] == .missingInInverse)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Owner.self, Target.self]

    @Model
    final class Owner: Identifiable {
        var name: String

        @Relationship(inverse: \Target.owners)
        var targets: [Target]

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class Target: Identifiable {
        var name: String

        @Relationship
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
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}
