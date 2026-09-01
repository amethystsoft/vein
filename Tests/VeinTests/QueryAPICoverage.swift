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

#if (TEST_SCUI || TEST_SWIFTUI) && VeinFilter
    import Foundation
    #if TEST_SCUI
        @testable import VeinSCUI
        import SwiftCrossUI
    #elseif TEST_SWIFTUI
        import SwiftUI
        @testable import VeinSwiftUI
    #endif

    @MainActor
    fileprivate func apiCoverage() {
        let _ = Query(#Predicate<Test> { test in test.flag == 0 })
        let _ = Query(
            #Predicate<Test> { test in test.flag == 0 },
            sortBy: [SortRule(\.flag)]
        )

        let _ = Query(#Filter<Test> { test in test.flag == 0})
        let _ = Query(
            #Filter<Test> { test in test.flag == 0 },
            sortBy: [SortRule(\.flag)]
        )
    }

    fileprivate typealias Test = V0_0_1.Test

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Test.self]

        @Model
        final class Test: Identifiable {
            @Field
            var flag: Int

            init(flag: Int) {
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
