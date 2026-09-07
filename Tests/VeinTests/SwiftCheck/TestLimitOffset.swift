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

#if canImport(SwiftCheck)
    import SwiftCheck
    import Foundation
    import XCTest
    @testable import Vein
    #if TEST_SWIFTUI
        @_spi(VeinTesting) @testable import VeinSwiftUI
    #elseif TEST_SCUI
        @_spi(VeinTesting) @testable import VeinSCUI
    #else
        @_spi(VeinTesting) @testable import VeinCore
    #endif

    fileprivate typealias Test = V0_0_1.Test
    final class TestLimitOffsetSuite: XCTestCase {
        func testPaginatedFetchIgnoresUnsavedInserts() {
            property("Paginated fetch ignores unsaved inserts") <-
                forAll { (saved: [Test], unsaved: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.PaginatedFetchIgnoresUnsaved"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in saved {
                        try container.context.insert(test)
                    }
                    try container.context.save()
                    for test in unsaved {
                        try container.context.insert(test)
                    }
                    let descriptor = try PaginatedFetchDescriptor(
                        model: Test.self,
                        sortBy: [SortRule(\.id)],
                        limit: saved.count + unsaved.count,
                        offset: 0
                    )

                    let results = try container.context.fetch(descriptor)
                    return Set(results.map(\.id)) == Set(saved.map(\.id))
                }
        }

        func testPaginatedFetchReflectsPendingDeletes() {
            property("Paginated fetch reflects pending deletes") <-
                forAll { (tests: [Test]) in
                    guard !tests.isEmpty else { return true }

                    let appID = "de.amethystsoft.vein.tests.PaginatedFetchReflectsDeletes"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in tests {
                        try container.context.insert(test)
                    }
                    try container.context.save()

                    let first = tests.first!
                    let firstID = first.id
                    let predicate = #Predicate<V0_0_1.Test> { $0.id == firstID }
                    if let object = try container.context.fetchAll(predicate).first {
                        try container.context.delete(object)
                    }

                    let descriptor = try PaginatedFetchDescriptor(
                        model: Test.self,
                        sortBy: [SortRule(\.id)],
                        limit: tests.count,
                        offset: 0
                    )

                    let remaining = tests[1...]

                    let results = try container.context.fetch(descriptor)
                    return Set(results.map(\.id)) == Set(remaining.map(\.id))
                }
        }

        func testFetchDescriptorIncludePendingChangesTrueIncludesUnsavedInserts() {
            property("FetchDescriptor includePendingChanges=true includes unsaved inserts") <-
                forAll { (saved: [Test], unsaved: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.FetchDescriptorIncludePendingChangesInserts"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in saved {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    for test in unsaved {
                        try container.context.insert(test)
                    }

                    var descriptor = try FetchDescriptor(model: Test.self)
                    descriptor.includePendingChanges = true

                    let results = try container.context.fetch(descriptor)
                    return Set(results.map(\.id)) == Set((saved + unsaved).map(\.id))
                }
        }

        func testFetchDescriptorIncludePendingChangesFalseExcludesUnsavedInserts() {
            property("FetchDescriptor includePendingChanges=false excludes unsaved inserts") <-
                forAll { (saved: [Test], unsaved: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.FetchDescriptorExcludePendingChangesInserts"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in saved {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    for test in unsaved {
                        try container.context.insert(test)
                    }

                    var descriptor = try FetchDescriptor(model: Test.self)
                    descriptor.includePendingChanges = false

                    let results = try container.context.fetch(descriptor)
                    return Set(results.map(\.id)) == Set(saved.map(\.id))
                }
        }

        func testFetchDescriptorIncludePendingChangesTrueIncludesPendingUpdates() {
            property("FetchDescriptor includePendingChanges=true includes pending updates") <-
                forAll { (saved: [Test]) in
                    guard !saved.isEmpty else { return true }

                    let appID = "de.amethystsoft.vein.tests.FetchDescriptorIncludePendingChangesUpdates"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in saved {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    let first = saved.first!
                    let firstID = first.id
                    let predicate = #Predicate<V0_0_1.Test> { $0.id == firstID }
                    if let object = try container.context.fetchAll(predicate).first {
                        object.someValue = "updated"
                    }

                    var descriptor = try FetchDescriptor(
                        predicate: #Predicate<Test> { test in test.someValue == "updated" }
                    )
                    descriptor.includePendingChanges = true

                    let results = try container.context.fetch(descriptor)

                    guard let updated = results.first(where: { $0.id == first.id }) else {
                        return false
                    }
                    return updated.someValue == "updated"
                }
        }

        func testFetchDescriptorIncludePendingChangesFalseExcludesPendingUpdates() {
            property("FetchDescriptor includePendingChanges=false excludes pending updates") <-
                forAll { (saved: [Test]) in
                    guard !saved.isEmpty else { return true }

                    let appID = "de.amethystsoft.vein.tests.FetchDescriptorIncludePendingChangesUpdatesFalse"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in saved {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    let first = saved.first!
                    let firstID = first.id
                    let predicate = #Predicate<V0_0_1.Test> { $0.id == firstID }
                    if let object = try container.context.fetchAll(predicate).first {
                        object.someValue = "updated"
                    }

                    var descriptor = try FetchDescriptor(
                        predicate: #Predicate<Test> { test in test.someValue == "updated" }
                    )
                    descriptor.includePendingChanges = false

                    let results = try container.context.fetch(descriptor)

                    guard let _ = results.first(where: { $0.id == first.id }) else {
                        return true
                    }
                    return false
                }
        }

        func testPaginatedLimitReturnsCorrectCount() {
            property("Paginated limit returns correct count") <-
                forAll { (tests: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.PaginatedLimitReturnsCorrectCount"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in tests {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    let descriptor = try PaginatedFetchDescriptor(
                        model: Test.self,
                        sortBy: [SortRule(\.id)],
                        limit: tests.count,
                        offset: 0
                    )

                    let results = try container.context.fetch(descriptor)
                    return results.count == tests.count
                }
        }

        func testPaginatedOffsetSkipsCorrectCount() {
            property("Paginated offset skips correct count") <-
                forAll { (tests: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.PaginatedOffsetSkipsCorrectCount"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in tests {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    let descriptor = try PaginatedFetchDescriptor(
                        model: Test.self,
                        sortBy: [SortRule(\.id)],
                        limit: 1_000_000,
                        offset: tests.count
                    )

                    let results = try container.context.fetch(descriptor)
                    return results.count == 0
                }
        }

        func testPaginatedLimitAndOffsetCombined() {
            property("Paginated limit and offset combined") <-
                forAll { (tests: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.PaginatedLimitAndOffsetCombined"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in tests {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    let offset = max(0, tests.count / 2)
                    let limit = max(1, tests.count - offset)

                    let descriptor = try PaginatedFetchDescriptor(
                        model: Test.self,
                        sortBy: [SortRule(\.id)],
                        limit: limit,
                        offset: offset
                    )

                    let results = try container.context.fetch(descriptor)
                    let expectedCount = max(0, tests.count - offset)

                    guard results.count == expectedCount else { return false }

                    if expectedCount > 0 {
                        let sortedResults = results.sorted { $0.id < $1.id }
                        let sortedAll = tests.sorted { $0.id < $1.id }
                        let expectedIDs = Set(sortedAll[offset...].map(\.id))
                        return Set(sortedResults.map(\.id)) == expectedIDs
                    }

                    return true
                }
        }

        func testPaginatedFetchPreservesSortOrderWithLimitOffset() {
            property("Paginated fetch preserves sort order with limit/offset") <-
                forAll { (tests: [Test]) in
                    let appID = "de.amethystsoft.vein.tests.PaginatedFetchPreservesSortOrder"

                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: appID,
                        encryptionEnabled: false
                    )

                    for test in tests {
                        try container.context.insert(test)
                    }
                    try! container.context.save()

                    guard tests.count >= 2 else { return true }

                    let offset = max(0, tests.count / 2)
                    let limit = max(1, tests.count - offset)

                    let descriptor = try PaginatedFetchDescriptor(
                        model: Test.self,
                        sortBy: [SortRule(\.id)],
                        limit: limit,
                        offset: offset
                    )

                    let results = try container.context.fetch(descriptor)
                    let expectedCount = max(0, tests.count - offset)
                    guard results.count == expectedCount else { return false }

                    let sortedResults = results.map(\.id)
                    return sortedResults == sortedResults.sorted()
                }
        }
    }

    fileprivate enum V0_0_1: VersionedSchema {
        static let version = ModelVersion(0, 0, 1)
        static let models: [any Vein.PersistentModel.Type] = [Test.self]

        @Model
        final class Test: Identifiable {
            var someValue: String

            @LazyField
            var text: String?

            init(someValue: String, text: String?) {
                self.someValue = someValue
                self.text = text
            }

            func getLazyField() -> LazyField<String> {
                _text
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

    extension V0_0_1.Test: Arbitrary {
        static fileprivate var arbitrary: SwiftCheck.Gen<Test> {
            return Gen<Test>.compose { dg in
                Test(
                    someValue: dg.generate(),
                    text: dg.generate()
                )
            }
        }
    }
#endif
