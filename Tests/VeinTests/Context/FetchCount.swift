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
struct FetchCount {
    @Test
    func fetchCountIsCorrect() async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.FetchCount",
            encryptionEnabled: false
        )

        for i in 0..<100 {
            let model = V0_0_1.Test(flag: i % 2 == 0)
            try container.context.insert(model)
        }
        try container.context.save()

        let descriptor = try FetchDescriptor(
            predicate: #Predicate<V0_0_1.Test> { model in model.flag }
        )

        let count = try container.context.fetchCount(descriptor)

        #expect(count == 50)

        for i in 0..<100 {
            let model = V0_0_1.Test(flag: i % 2 == 0)
            try container.context.insert(model)
        }

        let count2 = try container.context.fetchCount(descriptor)
        #expect(count2 == 50)

        try container.context.save()

        let count3 = try container.context.fetchCount(descriptor)
        #expect(count3 == 100)

        let count4 = try container.context.fetchCount(FetchDescriptor(model: V0_0_1.Test.self))
        #expect(count4 == 200)
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
