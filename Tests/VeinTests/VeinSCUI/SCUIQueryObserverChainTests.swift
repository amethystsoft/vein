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
    @testable import VeinSCUI
    import SwiftCrossUI
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

            let query = Query(#Predicate<V0_0_1.Test>{ model in
                model.flag == true
            })

            let query2 = Query(#Predicate<V0_0_1.Test>{ model in
                model.flag == true
            })

            let query3 = Query(#Predicate<V0_0_1.Test>{ model in
                model.flag == true
            })

            query.context = container.context
            query2.context = container.context
            query3.context = container.context

            /// Only on first access does a query register on the context
            _ = query.wrappedValue
            _ = query2.wrappedValue
            _ = query3.wrappedValue

            guard
                let primaryOf2 = query2.queryObserver.primaryObserver,
                let primaryOf3 = query3.queryObserver.primaryObserver
            else {
                Issue.record("""
                        Query 2 and 3 should have primary observers as as they are created \
                        after the first one.
                    """)
                return
            }

            #expect(ObjectIdentifier(query.queryObserver) == ObjectIdentifier(primaryOf2))
            #expect(ObjectIdentifier(query.queryObserver) == ObjectIdentifier(primaryOf3))

            await confirmation(
                "Confirm didChange was signaled",
                expectedCount: 2
            ) { confirmed in
                let cancellable = query2.didChange.observe {
                    confirmed()
                }
                let cancellable2 = query3.didChange.observe {
                    confirmed()
                }

                query.queryObserver.publishToEnclosingObserver()

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
