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

#if TEST_SWIFTUI
    import Foundation
    import Testing
    @testable import Vein
    @_spi(VeinTesting) @testable import VeinSwiftUI

    // For the "fetched" tests:
//
    // Accessing the relationship property ensures that, if this model is being observed by a
    // SwiftUI view via a parent (e.g. parent.child.text), the observer is registered on this
    // instance through the identity map. Since the identity map guarantees a single instance
    // per row, any observer registered during a view's traversal of the relationship chain will
    // be the same instance mutated here — meaning objectWillChange fires correctly up the chain.
    // If no view has traversed to this instance via a parent, no observer exists and no redraw
    // is needed, so skipping the scan is correct rather than a bug.
    @Suite
    @MainActor
    struct VeinSwiftUITests {
        @Test(.timeLimit(.minutes(1)))
        func fieldUpdatesUIWithContext() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            try container.context.insert(model)

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                model.someValue = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func fieldUpdatesUIWithoutContext() async throws {
            let model = V0_0_1.Test(someValue: "test")

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                model.someValue = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func lazyFieldUpdatesUIWithContext() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            try container.context.insert(model)

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                model.text = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func lazyFieldUpdatesUIWithoutContext() async throws {
            let model = V0_0_1.Test(someValue: "test")

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                model.text = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func oneRelationshipUpdatesUI() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Child()
            try container.context.insert(model)

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                model.parent = V0_0_1.Test(someValue: "test")

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func manyRelationshipUpdatesUI() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            try container.context.insert(model)

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                model.children.append(V0_0_1.Child())

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToChildUpdatesParent parent set on child`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(child)
            child.parent = model

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                child.text = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToParentUpdatesChild child set on parent`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(model)
            model.children.append(child)

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = child.objectWillChange.sink {
                    confirmed()
                }

                model.text = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToChildUpdatesParent child set on parent`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(model)
            model.children.append(child)

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                child.text = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToParentUpdatesChild parent set on child`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(child)
            child.parent = model

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = child.objectWillChange.sink {
                    confirmed()
                }

                model.text = "ioi"

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToFetchedChildUpdatesParent parent accessed via child`() async throws {
            let connection = try prepareContainer()
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            guard let child = try container.context.fetchAll(V0_0_1.Child.self).first else {
                Issue.record("Unexpectedly no child found.")
                return
            }
            guard let parent = try container.context.fetchAll(V0_0_1.Test.self).first else {
                Issue.record("Unexpectedly no parent found.")
                return
            }

            _ = child.parent

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = parent.objectWillChange.sink {
                    confirmed()
                }

                child.text = "ioi"

                _ = cancellable
            }

            func prepareContainer() throws -> Connection {
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: nil,
                    appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                    encryptionEnabled: ProcessInfo.shouldEnableEncryption
                )
                let model = V0_0_1.Test(someValue: "test")
                let child = V0_0_1.Child()
                try container.context.insert(model)
                model.children.append(child)

                try container.context.save()

                return container.getConnection()
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToFetchedParentUpdatesChild parent accessed via child`() async throws {
            let connection = try prepareContainer()
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            guard let child = try container.context.fetchAll(V0_0_1.Child.self).first else {
                Issue.record("Unexpectedly no child found.")
                return
            }
            guard let parent = try container.context.fetchAll(V0_0_1.Test.self).first else {
                Issue.record("Unexpectedly no parent found.")
                return
            }

            _ = child.parent

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = child.objectWillChange.sink {
                    confirmed()
                }

                parent.text = "ioi"

                _ = cancellable
            }

            func prepareContainer() throws -> Connection {
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: nil,
                    appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                    encryptionEnabled: ProcessInfo.shouldEnableEncryption
                )
                let model = V0_0_1.Test(someValue: "test")
                let child = V0_0_1.Child()
                try container.context.insert(model)
                model.children.append(child)

                try container.context.save()

                return container.getConnection()
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToFetchedChildUpdatesParent child accessed via parent`() async throws {
            let connection = try prepareContainer()
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            guard let child = try container.context.fetchAll(V0_0_1.Child.self).first else {
                Issue.record("Unexpectedly no child found.")
                return
            }
            guard let parent = try container.context.fetchAll(V0_0_1.Test.self).first else {
                Issue.record("Unexpectedly no parent found.")
                return
            }

            _ = parent.children

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = parent.objectWillChange.sink {
                    confirmed()
                }

                child.text = "ioi"

                _ = cancellable
            }

            func prepareContainer() throws -> Connection {
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: nil,
                    appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                    encryptionEnabled: ProcessInfo.shouldEnableEncryption
                )
                let model = V0_0_1.Test(someValue: "test")
                let child = V0_0_1.Child()
                try container.context.insert(model)
                model.children.append(child)

                try container.context.save()

                return container.getConnection()
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `updateToFetchedParentUpdatesChild child accessed via parent`() async throws {
            let connection = try prepareContainer()
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                connection: connection,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            guard let child = try container.context.fetchAll(V0_0_1.Child.self).first else {
                Issue.record("Unexpectedly no child found.")
                return
            }
            guard let parent = try container.context.fetchAll(V0_0_1.Test.self).first else {
                Issue.record("Unexpectedly no parent found.")
                return
            }

            _ = parent.children

            await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = child.objectWillChange.sink {
                    confirmed()
                }

                parent.text = "ioi"

                _ = cancellable
            }

            func prepareContainer() throws -> Connection {
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: nil,
                    appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                    encryptionEnabled: ProcessInfo.shouldEnableEncryption
                )
                let model = V0_0_1.Test(someValue: "test")
                let child = V0_0_1.Child()
                try container.context.insert(model)
                model.children.append(child)

                try container.context.save()

                return container.getConnection()
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `deleteChildUpdatesParent parent set on child`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(child)
            child.parent = model

            try await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                try container.context.delete(child)

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `deleteParentUpdatesChild child set on parent`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(model)
            model.children.append(child)

            try await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = child.objectWillChange.sink {
                    confirmed()
                }

                try container.context.delete(model)

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `deleteChildUpdatesParent child set on parent`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(model)
            model.children.append(child)

            try await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = model.objectWillChange.sink {
                    confirmed()
                }

                try container.context.delete(child)

                _ = cancellable
            }
        }

        @Test(.timeLimit(.minutes(1)))
        func `deleteParentUpdatesChild parent set on child`() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.veinswiftui.fields-update-model",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption
            )
            let model = V0_0_1.Test(someValue: "test")
            let child = V0_0_1.Child()
            try container.context.insert(child)
            child.parent = model

            try await confirmation(
                "Confirm objectWillChange was signaled",
                expectedCount: 1
            ) { confirmed in
                let cancellable = child.objectWillChange.sink {
                    confirmed()
                }

                try container.context.delete(model)

                _ = cancellable
            }
        }
    }

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Test.self, Child.self]

        @Model
        final class Test {
            var someValue: String

            @LazyField
            var text: String?

            @Relationship(inverse: \Child.parent)
            var children: [Child]

            init(someValue: String) {
                self.someValue = someValue
            }
        }

        @Model
        final class Child {
            @Relationship
            var parent: Test?

            @LazyField
            var text: String?

            init() {}
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
#endif
