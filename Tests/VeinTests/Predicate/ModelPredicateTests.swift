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
struct ModelPredicateTests {
    @Test
    func `equality check`() throws {
        let predicate1 = try ModelPredicate(#Predicate<V1.Test> { test in
            test.test.contains("a")
        })

        let predicate2 = try ModelPredicate(#Predicate<V1.Test> { test in
            test.test.contains("a")
        })

        let unmatching = try ModelPredicate(#Predicate<V1.Test> { test in
            test.test.contains("f")
        })

        #expect(predicate1 == predicate2)
        #expect(predicate1.hashValue == predicate2.hashValue)
        #expect(predicate1 != unmatching)
        #expect(predicate1.hashValue != unmatching.hashValue)
    }
}

fileprivate enum V1: VersionedSchema {
    static let version: Vein.ModelVersion = .init(1, 0, 0)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]

    @Model
    final class Test {
        var test: String

        init(test: String) {
            self.test = test
        }
    }
}
