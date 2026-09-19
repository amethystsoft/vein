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
struct IdentityMapClearing {
    @Test func cleanUpOnSave() async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.IdentityMapClearing",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        try await assertIdentityMapCleanup(container: container) { map, id1, id2, count in
            #expect(count == 2)
            #expect(map[V0_0_1.Test.typeIdentifier]?[id1]?.wrappedValue != nil)
            #expect(map[V0_0_1.Test.typeIdentifier]?[id2]?.wrappedValue != nil)
        } performChange: { context, _ in
            try context.save()
        } validateResult: { map, id1, id2, count in
            #expect(count == 1)
            #expect(map[id1] == nil)
            #expect(map[id2]?.wrappedValue != nil)
        }
    }

    @Test func cleanUpAfterTimeout() async throws {
        var config = ModelConfiguration.default
        config.cleanStaleIdentityMapEntriesTimeoutSeconds = 1

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.IdentityMapClearing",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption,
            modelConfiguration: config
        )

        try await assertIdentityMapCleanup(container: container) { map, id1, id2, count in
            #expect(count == 2)
            #expect(map[V0_0_1.Test.typeIdentifier]?[id1]?.wrappedValue != nil)
            #expect(map[V0_0_1.Test.typeIdentifier]?[id2]?.wrappedValue != nil)
        } performChange: { context, id in
            let timeout = Date().addingTimeInterval(5)
            while context.identityMap.dump()[V0_0_1.Test.typeIdentifier]?[id] != nil {
                if Date() > timeout {
                    Issue.record("Timed out waiting for identity map key to be purged.")
                    return
                }
                await Task.yield()
                try await Task.sleep(for: .milliseconds(50))
            }
        } validateResult: { map, id1, id2, count in
            #expect(count == 1)
            #expect(map[id1] == nil)
            #expect(map[id2]?.wrappedValue != nil)
        }
    }

    @Test
    func manualCleanup() async throws {
        var config = ModelConfiguration.default
        config.cleanStaleIdentityMapEntriesTimeoutSeconds = nil
        config.cleanStaleIdentityMapEntriesOnSave = false

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.IdentityMapClearing",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption,
            modelConfiguration: config
        )

        try await assertIdentityMapCleanup(container: container) { map, id1, id2, count in
            #expect(count == 2)
            #expect(map[V0_0_1.Test.typeIdentifier]?[id1]?.wrappedValue != nil)
            #expect(map[V0_0_1.Test.typeIdentifier]?[id2]?.wrappedValue != nil)
        } performChange: { context, _ in
            try container.context.save()
            container.context.compactIdentityMap()
        } validateResult: { map, id1, id2, count in
            #expect(count == 1)
            #expect(map[id1] == nil)
            #expect(map[id2]?.wrappedValue != nil)
        }
    }

    private func assertIdentityMapCleanup(
        container: ModelContainer,
        validate: ([ObjectIdentifier : [ULID : WeakModel]], ULID, ULID, Int) -> Void,
        performChange: (ManagedObjectContext, ULID) async throws -> Void,
        validateResult: ([ULID : WeakModel], ULID, ULID, Int) -> Void
    ) async throws {
        let test = V0_0_1.Test(flag: true)
        let test2 = V0_0_1.Test(flag: false)

        try container.context.insert(test)
        try container.context.insert(test2)

        let identityMap = container.context.identityMap
        let mapPreSave = identityMap.dump()

        validate(mapPreSave, test.id, test2.id, identityMap.getTrackedCount())

        identityMap.setToNil(type: V0_0_1.Test.typeIdentifier, id: test.id)

        guard let wrapperPostMutation = identityMap.dump()[V0_0_1.Test.typeIdentifier]?[test.id]
        else {
            Issue.record("Unexpectedly didn't find the test object in the map.")
            return
        }

        #expect(wrapperPostMutation.isDeallocated)

        try await performChange(container.context, test.id)

        guard let mapPostSave = identityMap.dump()[V0_0_1.Test.typeIdentifier] else {
            Issue.record("Unexpectedly didn't find type in identity map.")
            return
        }

        validateResult(mapPostSave, test.id, test2.id, identityMap.getTrackedCount())
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]

    @Model
    final class Test: Identifiable {
        var flag: Bool

        init(flag: Bool) {
            self.flag = flag
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
