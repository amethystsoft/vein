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

#if TEST_SWIFTUI
    import Foundation
    import Testing
    import SQLiteDB
    import SwiftUI
    @testable import Vein
    @_spi(VeinTesting) @testable import VeinSwiftUI

    fileprivate typealias Test = V0_0_1.Test

    @Suite
    @MainActor
    struct QueryTests {
        @Test(.timeLimit(.minutes(1)))
        func queryIntegrationWithSwiftUI() async throws {
            let (container, models) = try seed()

            let modelPredicate = try ModelPredicate(#Predicate<Test> {_ in true })
            let queryObserver = QueryObserver<Test>(modelPredicate)

            await Task.yield()

            queryObserver.initialize(with: container.context)

            #expect(
                container
                    .context
                    .registeredQueries
                    .value[ObjectIdentifier(Test.self)]?
                    .count
                    == 1
            )

            await Task.yield()

            #expect(queryObserver.results == models)

            try container.context.delete(models.first!)

            await Task.yield()

            #expect(queryObserver.results == Array(models[1...]))

            try container.context.insert(models.first!)

            await Task.yield()

            // We need the sortrule here, as the stuff is sorted on the query level, not queryObserver.
            #expect(queryObserver.results?.sorted(using: [SortRule(\.id)]) == models)
        }

        @Test(.timeLimit(.minutes(1)))
        func filteredQueryIntegrationWithSwiftUI() async throws {
            let (container, initialModels) = try seed()
            let models = initialModels.filter { $0.someValue.contains("i")}

            let modelPredicate = try ModelPredicate(#Predicate<Test> { model in
                model.someValue.contains("i")
            })
            let queryObserver = QueryObserver<Test>(modelPredicate)

            await Task.yield()

            queryObserver.initialize(with: container.context)

            #expect(queryObserver.results == models)

            try container.context.delete(models.first!)

            await Task.yield()

            #expect(queryObserver.results == Array(models[1...]))

            try container.context.insert(models.first!)

            await Task.yield()

            // We need the sortrule here, as the stuff is sorted on the query level, not queryObserver.
            #expect(queryObserver.results?.sorted(using: [SortRule(\.id)]) == models)

            models.first!.someValue = "no letter you're look'n for here"

            await Task.yield()

            #expect(queryObserver.results == Array(models[1...]))
        }

        private func seed() throws -> (ModelContainer, [Test]) {
            var logConfiguration = LogConfiguration.debug
            logConfiguration.modelContextErrors = true
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.swiftui.query",
                encryptionEnabled: ProcessInfo.shouldEnableEncryption,
                // logConfiguration: logConfiguration
            )

            let context = container.context!

            let names = [
                "Mia Koring",
                "John Doe",
                "Alice Johnson",
                "Robert Smith",
                "Elena Rodriguez",
                "Liam Chen",
                "Sophia Müller",
                "David Park",
                "Amara Okafor",
                "Lucas Bernard",
                "Isabella Rossi",
                "Yuki Tanaka"
            ]

            let models = names.map(Test.init)

            for model in models {
                try context.insert(model)
            }

            return (container, models.sorted(by: { $0.id < $1.id }))
        }
    }

    extension Array where Element == Test {
        fileprivate var ids: [ULID] {
            map(\.id)
        }
    }

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Test.self]

        @Model
        final class Test: Identifiable, Equatable {
            var someValue: String

            init(someValue: String) {
                self.someValue = someValue
            }

            static func == (lhs: V0_0_1.Test, rhs: V0_0_1.Test) -> Bool {
                lhs.someValue == rhs.someValue
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
#endif
