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
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif !TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct FieldSpecificTests {
    @Test
    func testLazyFieldReturnsStoreWithoutContext() async throws {
        let field = LazyField(wrappedValue: "Test")
        #expect(field.wrappedValue == "Test")
    }

    @Test
    func `@LazyField doesn't get fetched initially`() async throws {
        let expectedText = "Wow, what a beautiful text that is"
        let connection = try await prepareContainer()
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.tests.fieldSpecific",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        guard let model = try container.context.fetchAll(V0_0_1.Test.self).first else {
            Issue.record("Unexpectedly didn't find model")
            return
        }

        let lazyField = model.getLazyField()

        #expect(lazyField.testingStoreSnapshot.isNil)
        #expect(model.text == expectedText)
        #expect(lazyField.testingStoreSnapshot == expectedText)

        func prepareContainer() async throws -> Connection {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.fieldSpecific",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "Test")
            model.text = expectedText
            try container.context.insert(model)
            try container.context.save()

            return container.getConnection()
        }
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
