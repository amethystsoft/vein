// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
// Licensed under Mozilla Public License v2.0
//
// See LICENSE.txt for license information
//
// ===----------------------------------------------------------------------===

import Foundation
import Testing
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinCore
#endif

extension PersistableTests {
    @Test
    func testCodablePersistable() async throws {
        let metadataDate = Date(timeIntervalSince1970: 1782830817.0)
        let (connection, objectID) = try setupContainer(date: metadataDate)

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

        #expect(model.metadata.createdAt == metadataDate)
        #expect(model.metadata.createdInCity == "Berlin")
        // Confirm the fetched model is really fetched from the db,
        // not just from an identity map.
        #expect(ObjectIdentifier(model) != objectID)
    }

    @Test
    func testCodablePersistableUpdate() async throws {
        let metadataDate = Date(timeIntervalSince1970: 1782830817.0)
        let (connection, objectID) = try setupContainer(date: metadataDate)
        // TODO: Silence unused _keepaliveContainer once we use Swift 6.4
        let (newObjectID, _keepaliveContainer) = try runUpdate()

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

        #expect(model.metadata.createdAt == metadataDate)
        #expect(model.metadata.createdInCity == "Cologne")
        // Confirm the fetched model is really fetched from the db,
        // not just from an identity map.
        #expect(ObjectIdentifier(model) != objectID)
        #expect(ObjectIdentifier(model) != newObjectID)

        func runUpdate() throws -> (ObjectIdentifier?, ModelContainer) {
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
                return (nil, updateContainer)
            }

            #expect(model.metadata.createdAt == metadataDate)
            #expect(model.metadata.createdInCity == "Berlin")
            // Confirm the fetched model is really fetched from the db,
            // not just from an identity map.
            #expect(ObjectIdentifier(model) != objectID)

            model.metadata = .init(
                createdAt: metadataDate,
                createdInCity: "Cologne"
            )

            #expect(updateContainer.context.hasChanges)

            try updateContainer.context.save()

            return (ObjectIdentifier(model), updateContainer)
        }
    }

    func setupContainer(date: Date) throws -> (Connection, ObjectIdentifier) {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.persistable",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let metadata = V0_0_1.Account.Metadata(createdAt: date, createdInCity: "Berlin")
        let model = V0_0_1.Account(metadata: metadata)
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
        var metadata: Metadata

        init(metadata: Metadata) {
            self.metadata = metadata
        }

        struct Metadata: CodablePersistable {
            let createdAt: Date
            let createdInCity: String
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
