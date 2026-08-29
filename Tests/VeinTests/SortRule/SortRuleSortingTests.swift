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
struct SortRuleSortingTests {
    @Test("Comparable non-optional property - Ascending")
    func testNonOptionalComparableAscending() {
        let rule = SortRule(\MockItem.intVal, order: .ascending)
        let item1 = MockItem(intVal: 1, strVal: "")
        let item2 = MockItem(intVal: 2, strVal: "")

        #expect(rule.compare(lhs: item1, rhs: item2) == .orderedAscending)
        #expect(rule.compare(lhs: item2, rhs: item1) == .orderedDescending)
        #expect(rule.compare(lhs: item1, rhs: item1) == .orderedSame)
    }

    @Test("Comparable non-optional property - Descending")
    func testNonOptionalComparableDescending() {
        let rule = SortRule(\MockItem.intVal, order: .descending)
        let item1 = MockItem(intVal: 1, strVal: "")
        let item2 = MockItem(intVal: 2, strVal: "")

        #expect(rule.compare(lhs: item1, rhs: item2) == .orderedDescending)
        #expect(rule.compare(lhs: item2, rhs: item1) == .orderedAscending)
    }

    @Test("Comparable optional property - Ascending")
    func testOptionalComparableAscending() {
        let rule = SortRule(\MockItem.optInt, order: .ascending)
        let itemNil1 = MockItem(intVal: 0, optInt: nil, strVal: "")
        let itemNil2 = MockItem(intVal: 0, optInt: nil, strVal: "")
        let itemVal1 = MockItem(intVal: 0, optInt: 5, strVal: "")
        let itemVal2 = MockItem(intVal: 0, optInt: 10, strVal: "")

        // Both nil
        #expect(rule.compare(lhs: itemNil1, rhs: itemNil2) == .orderedSame)
        // LHS nil, RHS non-nil
        #expect(rule.compare(lhs: itemNil1, rhs: itemVal1) == .orderedAscending)
        // LHS non-nil, RHS nil
        #expect(rule.compare(lhs: itemVal1, rhs: itemNil1) == .orderedDescending)
        // Both non-nil
        #expect(rule.compare(lhs: itemVal1, rhs: itemVal2) == .orderedAscending)
        #expect(rule.compare(lhs: itemVal2, rhs: itemVal1) == .orderedDescending)
    }

    @Test("String property - Case Insensitive")
    func testStringCaseInsensitive() {
        let rule = SortRule(
            \MockItem.strVal,
            comparator: .caseInsensitive,
            order: .ascending
        )
        let item1 = MockItem(intVal: 0, strVal: "apple")
        let item2 = MockItem(intVal: 0, strVal: "Apple")
        let item3 = MockItem(intVal: 0, strVal: "banana")

        #expect(rule.compare(lhs: item1, rhs: item2) == .orderedSame)
        #expect(rule.compare(lhs: item1, rhs: item3) == .orderedAscending)
    }

    @Test("String property - Lexical")
    func testStringLexical() {
        let rule = SortRule(
            \MockItem.strVal,
            comparator: .lexical,
            order: .ascending
        )
        // "Apple" (uppercase) comes before "apple" lexically in standard comparison
        let item1 = MockItem(intVal: 0, strVal: "apple")
        let item2 = MockItem(intVal: 0, strVal: "Apple")

        #expect(rule.compare(lhs: item2, rhs: item1) == .orderedAscending)
        #expect(rule.compare(lhs: item1, rhs: item1) == .orderedSame)
    }

    @Test("Optional String property")
    func testOptionalString() {
        let rule = SortRule(
            \MockItem.optStr,
            comparator: .caseInsensitive,
            order: .ascending
        )
        let itemNil1 = MockItem(intVal: 0, strVal: "", optStr: nil)
        let itemNil2 = MockItem(intVal: 0, strVal: "", optStr: nil)
        let itemVal1 = MockItem(intVal: 0, strVal: "", optStr: "apple")
        let itemVal2 = MockItem(intVal: 0, strVal: "", optStr: "Apple")

        // Nil checks
        #expect(rule.compare(lhs: itemNil1, rhs: itemNil2) == .orderedSame)
        #expect(rule.compare(lhs: itemNil1, rhs: itemVal1) == .orderedAscending)
        #expect(rule.compare(lhs: itemVal1, rhs: itemNil1) == .orderedDescending)

        // Case insensitive evaluation
        #expect(rule.compare(lhs: itemVal1, rhs: itemVal2) == .orderedSame)

        // Lexical fallback check on optional
        let lexicalRule = SortRule(
            \MockItem.optStr,
            comparator: .lexical,
            order: .ascending
        )
        #expect(
            lexicalRule.compare(lhs: itemVal2, rhs: itemVal1)
                == .orderedAscending
        )
    }

    @Test("Sequence sorting with primary and secondary rules")
    func testSequenceSorting() {
        let items = [
            MockItem(intVal: 2, strVal: "banana"),
            MockItem(intVal: 1, strVal: "apple"),
            MockItem(intVal: 1, strVal: "apricot"),
        ]

        let rules = [
            SortRule<MockItem>(\.intVal, order: .ascending),
            SortRule<MockItem>(\.strVal, order: .ascending),
        ]

        let sorted = items.sorted(using: rules)

        #expect(sorted[0].intVal == 1 && sorted[0].strVal == "apple")
        #expect(sorted[1].intVal == 1 && sorted[1].strVal == "apricot")
        #expect(sorted[2].intVal == 2 && sorted[2].strVal == "banana")
    }
}

fileprivate typealias MockItem = Version1.MockItem

fileprivate enum Version1: VersionedSchema {
    static let version: Vein.ModelVersion = .init(0, 0, 1)

    static let models: [any Vein.PersistentModel.Type] = [ MockItem.self ]

    @Model
    fileprivate final class MockItem {
        var intVal: Int
        var optInt: Int?
        var strVal: String
        var optStr: String?

        init(
            intVal: Int,
            optInt: Int? = nil,
            strVal: String,
            optStr: String? = nil
        ) {
            self.intVal = intVal
            self.optInt = optInt
            self.strVal = strVal
            self.optStr = optStr
        }
    }
}
