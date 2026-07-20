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
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct PersistableTests {
    @Test
    func testRawRepresentablePersistable() async throws {
        let connection = try setupContainer()

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
    }

    @Test
    func testRawRepresentablePersistableUpdate() async throws {
        let connection = try setupContainer()
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

            model.accountType = .user

            #expect(updateContainer.context.hasChanges)

            try updateContainer.context.save()

            return ObjectIdentifier(model)
        }
    }

    private func setupContainer() throws -> Connection {
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

        return container.getConnection()
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
