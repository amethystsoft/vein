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

extension RelationshipTest {
    @Test(.timeLimit(.minutes(1)))
    func testSelfReferentialTree() async throws {
        let dbPath = try prepareContainerLocation(name: "SelfReferentialTree")

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RelationshipTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )

        let root = V0_0_1.Category(name: "Root")
        let child = V0_0_1.Category(name: "Child")

        try container.context.insert(root)
        root.children.append(child)
        try container.context.save()

        #expect(child.parent?.id == root.id)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Category.self]

    @Model
    final class Category: Identifiable {
        @Field
        var name: String

        @Relationship(inverse: \Category.children)
        var parent: Category?

        @Relationship
        var children: [Category]

        init(name: String) {
            self.name = name
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] {[]}
}
