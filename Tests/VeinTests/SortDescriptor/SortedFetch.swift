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

fileprivate typealias Test = V0_0_1.Test
@Suite
struct SortedFetch {
    @Test
    func testIsSortedAscendingIncludingUnpersisted() async throws {
        for i in 0...100 {
            var generator = SplitMix64(seed: UInt64(i))

            var tests: [Test] = []
            for _ in 0...100 {
                tests.append(Test.random(generator: &generator))
            }

            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: nil,
                appID: "de.amethystsoft.vein.tests.SwiftCheck",
                encryptionEnabled: false
            )
            let pivot = tests.count / 2

            let firstHalf = tests.prefix(upTo: pivot)
            let secondHalf = tests.suffix(from: pivot)

            for item in firstHalf {
                try container.context.insert(item)
            }

            try container.context.save()

            for item in secondHalf {
                try container.context.insert(item)
            }

            let results = try container.context.fetchAll(
                Test.self,
                sortBy: [SortDescriptor<Test>(\.someValue)]
            )

            #expect(results.isSortedBy(\.someValue))
        }
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]

    @Model
    final class Test: Identifiable {
        var someValue: Int

        init(someValue: Int) {
            self.someValue = someValue
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

extension V0_0_1.Test {
    static fileprivate func random(generator: inout SplitMix64) -> Test {
        Test(
            someValue: Int(clamping: generator.nextInt()),
        )
    }
}

extension Array where Element == V0_0_1.Test {
    fileprivate func isSortedBy<T: Comparable>(_ keyPath: KeyPath<Element, T>) -> Bool {
        var current = self.first

        for element in self.suffix(from: 1) {
            if element[keyPath: keyPath] < current![keyPath: keyPath] {
                return false
            }
            current = element
        }

        return true
    }
}

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return z ^ (z >> 31)
    }

    mutating func nextInt() -> Int {
        return Int(bitPattern: UInt(truncatingIfNeeded: self.next()))
    }
}
