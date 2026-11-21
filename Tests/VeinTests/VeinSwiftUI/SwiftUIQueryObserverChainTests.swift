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
    @testable import VeinSwiftUI
    @testable import Vein
    import Testing

    @Suite @MainActor
    struct QueryObserverChain {
        @Test(.timeLimit(.minutes(1)))
        func publishingWorks() async throws {
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.test.scuiqueryobserver"
            )

            let query = try QueryObserver(ModelPredicate(#Predicate<V0_0_1.Test>{ model in
                model.flag == true
            }))

            let query2 = try QueryObserver(ModelPredicate(#Predicate<V0_0_1.Test>{ model in
                model.flag == true
            }))

            let query3 = try QueryObserver(ModelPredicate(#Predicate<V0_0_1.Test>{ model in
                model.flag == true
            }))

            query.initialize(with: container.context)
            query2.initialize(with: container.context)
            query3.initialize(with: container.context)

            guard
                let primaryOf2 = query2.primaryObserver,
                let primaryOf3 = query3.primaryObserver
            else {
                Issue.record("""
                        Query 2 and 3 should have primary observers as as they are created \
                        after the first one. 2: \(query2.primaryObserver) \
                        3: \(query3.primaryObserver)
                    """)
                return
            }

            #expect(ObjectIdentifier(query) == ObjectIdentifier(primaryOf2))
            #expect(ObjectIdentifier(query) == ObjectIdentifier(primaryOf3))

            await confirmation(
                "Confirm didChange was signaled",
                expectedCount: 2
            ) { confirmed in
                let cancellable = query2.objectWillChange.sink {
                    confirmed()
                }
                let cancellable2 = query3.objectWillChange.sink {
                    confirmed()
                }

                query.publishToEnclosingObserver()

                _ = cancellable
                _ = cancellable2
            }
        }
    }

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Test.self]

        @Model
        final class Test: Identifiable {
            @Field
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
#endif
