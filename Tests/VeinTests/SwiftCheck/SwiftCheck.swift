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
    final class SwiftCheckSuite: XCTestCase {
        func testIdempotentSave() {
            property("Save is idempotent") <- forAll { (test: Test) in
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: nil,
                    appID: "de.amethystsoft.vein.tests.SwiftCheck",
                    encryptionEnabled: false
                )

                let context = container.context!

                try context.insert(test)
                try! context.save()
                let firstCount = try! context.fetchAll(Test.self).count

                do {
                    try context.insert(test) // Attempted re-insert or update
                    throw MOCError.other(message: "Didn't throw for inserting managed model.")
                } catch let error as MOCError {
                    switch error {
                        case .insertManagedModel: break
                        default: throw error
                    }
                }
                try! context.save()
                let secondCount = try! context.fetchAll(Test.self).count

                return firstCount == secondCount
            }
        }

        func testRoundTripPersistence() {
            property("Round-trip persistence") <- forAll { (test: Test) in
                let connection = try createTest(test: test)
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    connection: connection,
                    appID: "de.amethystsoft.vein.tests.SwiftCheck",
                    encryptionEnabled: false
                )

                let fetchedTest = try! container.context.fetchAll(Test.self).first

                return fetchedTest?.id == test.id &&
                    fetchedTest?.someValue == test.someValue &&
                    fetchedTest?.text == test.text

                func createTest(test: Test) throws -> Connection {
                    let container = try ModelContainer(
                        V0_0_1.self,
                        migration: Migration.self,
                        at: nil,
                        appID: "de.amethystsoft.vein.tests.SwiftCheck",
                        encryptionEnabled: false
                    )

                    try container.context.insert(test)
                    try container.context.save()

                    return container.getConnection()
                }
            }
        }

        func testFilterReturnsCorrectSubset() {
            property("Filter by someValue returns correct subset") <- forAll { (tests: [Test]) in
                let container = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: nil,
                    appID: "de.amethystsoft.vein.tests.SwiftCheck",
                    encryptionEnabled: false
                )

                let context = container.context!

                try tests.forEach { try context.insert($0) }
                try context.save()

                let targetLetter = "A"
                let expectedCount = tests.filter { $0.someValue.contains(targetLetter) }.count
                let predicate = #Predicate<Test> { test in
                    test.someValue.contains(targetLetter)
                }
                let fetchedCount = try context.fetchAll(predicate).count

                return fetchedCount == expectedCount
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
