// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import Testing
import Logging
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
    @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
    @testable import VeinCore
#endif

extension BugTests {
    @Test
    func singlePropertyJSONBWorks() async throws {
        let ulids = [ULID(), ULID(), ULID()]
        let newULIDS = [ULID(), ULID()]

        let connection = try makeBase()
        try validateInsertAndUpdate(on: connection)
        try validateUpdate(on: connection)

        func makeBase() throws -> Connection {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.BugTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )

            let user = V0_0_1.User()
            user.ulids = ulids

            try container.context.insert(user)
            try container.context.save()

            return container.getConnection()
        }

        func validateInsertAndUpdate(on connection: Connection) throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.BugTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )

            let user = try container.context.fetchAll(V0_0_1.User.self).first

            #expect(user?.ulids == ulids)

            user?.ulids = newULIDS

            try container.context.save()
        }

        func validateUpdate(on connection: Connection) throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.BugTests",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )

            let user = try container.context.fetchAll(V0_0_1.User.self).first

            #expect(user?.ulids == newULIDS)
        }
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self]

    @Model
    final class User: Identifiable {
        @LazyField
        var ulids: [ULID]?

        init() {}
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] {[]}
}
