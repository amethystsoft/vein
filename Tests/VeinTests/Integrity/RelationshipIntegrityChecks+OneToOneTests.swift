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

@Suite("Relationship Integrity Check Tests One to One")
struct RelationshipIntegrityChecksOneToOne: RelationshipIntegrityCheckHelper {
    @Test
    func `one side doesn't have table`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.target = target
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
            owner.target = target
            owner2.target = target2
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
            owner.target = target
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
            #expect(
                ownerReport.inverseMismatches["target"]?[target.id.ulidString]
                    == .inverseMismatch(found: nil, expected: owner.id.ulidString)
            )
        }
    }

    @Test
    func `inverse is different (missingInInverse covered too)`() async throws {
        let owner = Owner(name: "Mia")
        let target = Target(name: "Coral")
        let ulid = ULID()

        try check(V0_0_1.self, Migration.self) { context in
            try context.insert(owner)
            owner.target = target
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
            #expect(
                ownerReport.inverseMismatches["target"]?[target.id.ulidString]
                    == .inverseMismatch(found: ulid.ulidString, expected: owner.id.ulidString)
            )

            #expect(targetReport.idString == target.id.ulidString)
            #expect(targetReport.inverseMismatches.count == 1)
            #expect(targetReport.localMismatches.isEmpty)
            // used a fake ulid
            #expect(targetReport.inverseMismatches["owner"]?[ulid.ulidString] == .missingInInverse)
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
