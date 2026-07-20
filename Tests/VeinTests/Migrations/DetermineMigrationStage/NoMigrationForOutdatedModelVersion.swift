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
import Logging
@testable import Vein
#if TEST_SWIFTUI
@_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
@_spi(VeinTesting) @testable import VeinSCUI
#else
@_spi(VeinTesting) @testable import VeinCore
#endif

extension MigrationTests {
    @Test func noMigrationForOutdatedModelVersion() async throws {
        let path = try prepareContainerLocation(name: "determineSchemaVersion")
        let container = try ModelContainer(
            Version0_0_1.self,
            migration: MigrationPlan.self,
            at: path,
            appID: "de.amethystsoft.vein.MigrationTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        let originModel = Version0_0_1.BasicModel(field: "very important content")
        try container.context.insert(originModel)
        try container.context.save()

        let newContainer = try ModelContainer(
            Version0_0_2.self,
            migration: MigrationPlan.self,
            at: path,
            appID: "de.amethystsoft.vein.MigrationTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        do {
            try newContainer.migrate()
        } catch let error as ManagedObjectContextError {
            if
                case .noMigrationForOutdatedModelVersion(
                    let migration,
                    let version
                ) = error
            {
                #expect("\(migration)" == "MigrationPlan")
                #expect(version == Version0_0_1.version)
                return
            }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        } catch {
            Issue.record("Thrown error does not match expectations: \(error.localizedDescription)")
            return
        }

        Issue.record("Unexpectedly no error was thrown")
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
        @Field
        var field: String

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

    static var stages: [Vein.MigrationStage] { [] }
}
