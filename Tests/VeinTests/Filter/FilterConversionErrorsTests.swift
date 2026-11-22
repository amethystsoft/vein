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

#if VeinFilter
    import Foundation
    import Testing
    import Logging
    @testable import Vein
    #if TEST_SWIFTUI
        @_spi(VeinTesting) @testable import VeinSwiftUI
    #elseif TEST_SCUI
        @_spi(VeinTesting) @testable import VeinSCUI
    #else
        @_spi(VeinTesting) @testable import VeinCore
    #endif

    @Suite
    struct FilterConversionErrorTests {
        @Test
        func `relationship throws`() async throws {
            do {
                _ = try ModelPredicate(#Filter<Test> { $0.test != nil })
                Issue.record("Unexpectedly didn't throw")
            } catch let error as PredicateConversionError {
                let expected = "Test.test is a relationship. Filtering by relationships is currently unsupported."
                if case .unexpectedUnsupportedRelationship(let info) = error {
                    #expect(info == expected)
                    return
                } else if case .incompatiblePredicate = error {
                    return
                }
                throw error
            }
        }

        @Test
        func `mssing field information throws`() async throws {
            do {
                _ = try ModelPredicate(#Filter<Test> { $0.noFieldInformationAboutThisProperty })
                Issue.record("Unexpectedly didn't throw")
            } catch let error as PredicateConversionError {
                if case .missingFieldInformation(let info) = error {
                    #expect(info == "\(\Test.noFieldInformationAboutThisProperty)")
                    return
                }
                throw error
            }
        }

        @Test
        func `incompatible throws incompatible`() async throws {
            do {
                _ = try ModelPredicate(#Filter<Test> { $0.bar.nonzeroBitCount == 1 })
                Issue.record("Unexpectedly didn't throw")
            } catch let error as PredicateConversionError {
                if case .incompatiblePredicate = error {
                    return
                }
                throw error
            }
        }
    }

    fileprivate enum V1: VersionedSchema {
        static let version: Vein.ModelVersion = .init(1, 0, 0)

        static let models: [any Vein.PersistentModel.Type] = [Test.self]

        @Model
        final class Test: Equatable {
            var foo: String?
            var bar: Int = 1
            @Relationship
            var test: Test?
            static func == (lhs: borrowing V1.Test, rhs: borrowing V1.Test) -> Bool {
                lhs.id == rhs.id
            }
        }
    }

    fileprivate typealias Test = V1.Test

    extension Test {
        var noFieldInformationAboutThisProperty: Bool { true }
    }
#endif
