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

#if TEST_SCUI
    import Foundation
    import Testing
    import SQLiteDB
    @testable import Vein
    @_spi(VeinTesting) @testable import VeinSCUI

    @Suite
    @MainActor
    struct SCUIObserverChain {
        @Test
        func `parent publishes child change`() async throws {
            let container = try ModelContainer(
                V1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.SCUIObserverChain",
                encryptionEnabled: false
            )

            let parent = Parent()
            let child = Child()
            try container.context.insert(parent)
            parent.child = child

            _ = parent.child

            print(parent.id.ulidString)

            let observersOnChild = child._observers.value
            #expect(observersOnChild.observers[parent.id] != nil)
            #expect(observersOnChild.references[parent.id]?.contains("child") == true)

            let observersOnParent = parent._observers.value
            #expect(observersOnParent.observers[child.id] != nil)
            #expect(observersOnParent.references[child.id]?.contains("parent") == true)

            await confirmation(
                "Confirm didChange was signaled on parent",
                expectedCount: 1
            ) { confirmed in
                let cancellable = parent.didChange.observe {
                    confirmed()
                }

                child.value.toggle()

                _ = cancellable
            }
        }
    }

    fileprivate enum V1: VersionedSchema {
        static let version = ModelVersion(1, 0, 0)
        static let models: [any Vein.PersistentModel.Type] = [Parent.self, Child.self]

        @Model
        final class Parent {
            @Relationship(inverse: \Child.parent)
            var child: Child?

            init() {}
        }

        @Model
        final class Child {
            var value: Bool = false
            @Relationship
            var parent: Parent?

            init() {}
        }
    }

    fileprivate typealias Parent = V1.Parent
    fileprivate typealias Child = V1.Child

    fileprivate enum Migration: SchemaMigrationPlan {
        static var schemas: [any Vein.VersionedSchema.Type] {
            [V1.self]
        }

        static var stages: [MigrationStage] {
            []
        }
    }
#endif
