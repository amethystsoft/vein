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

@Suite
struct FieldBehaviorTests {
    @Test(arguments: [true, false])
    func `read does't change _updatedAt`(_ save: Bool) throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.tests.FieldBehaviorTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let model = V0_0_1.Test(someValue: "")

        try container.context.insert(model)
        model.someValue = "a"

        let updatedAt = model._updatedAt

        if save {
            try container.context.save()
            #expect(updatedAt == model._updatedAt)
        }

        _ = model.text
        #expect(updatedAt == model._updatedAt)

        _ = model.someValue
        #expect(updatedAt == model._updatedAt)

        _ = model.id
        #expect(updatedAt == model._updatedAt)
    }

    @Test
    func `Writes don't change updatedAt while uninserted`() async throws {
        let model = V0_0_1.Test(someValue: "")
        #expect(model._updatedAt == nil)
        model.someValue = "a"
        #expect(model._updatedAt == nil)
        model.text = "b"
        #expect(model._updatedAt == nil)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]

    @Model
    final class Test: Identifiable {
        var someValue: String

        @LazyField
        var text: String?

        init(someValue: String) {
            self.someValue = someValue
        }

        func getLazyField() -> LazyField<String> {
            _text
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
