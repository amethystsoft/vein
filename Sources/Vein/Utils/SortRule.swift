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
import SQLiteDB

public enum SortRuleConversionError: Error {
    case noFieldInformation(String)
}

extension SortRuleConversionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
            case .noFieldInformation(let keyPath):
                return "No field information for key path: \(keyPath)"
        }
    }
}

public struct SortRule<Compared: PersistentModel>: Sendable {
    let keyPath: PartialKeyPath<Compared> & Sendable
    let stringComparator: StringComparator?
    let order: Order
    let comparator: @Sendable (Compared, Compared) -> ComparisonResult

    public init<F: Persistable & Comparable>(
        _ keyPath: any KeyPath<Compared, F> & Sendable,
        order: Order = .ascending
    ) {
        self.keyPath = keyPath
        self.order = order
        self.stringComparator = nil
        self.comparator = { lhs, rhs in
            let lVal = lhs[keyPath: keyPath]
            let rVal = rhs[keyPath: keyPath]
            if lVal < rVal { return .orderedAscending.with(order: order) }
            if lVal > rVal { return .orderedDescending.with(order: order) }
            return .orderedSame
        }
    }

    public init<F: Persistable & Comparable>(
        _ keyPath: any KeyPath<Compared, F?> & Sendable,
        order: Order = .ascending
    ) {
        self.keyPath = keyPath
        self.order = order
        self.stringComparator = nil

        self.comparator = { lhs, rhs in
            let lVal = lhs[keyPath: keyPath]
            let rVal = rhs[keyPath: keyPath]

            if lVal == nil && rVal == nil { return .orderedSame }
            if lVal == nil && rVal != nil { return .orderedAscending.with(order: order) }
            if lVal != nil && rVal == nil { return .orderedDescending.with(order: order) }

            guard let lVal, let rVal else {
                // unreachable (in theory)
                fatalError("Unexpectedly found nil value in \(#file):\(#line)")
            }

            if lVal < rVal { return .orderedAscending.with(order: order) }
            if lVal > rVal { return .orderedDescending.with(order: order) }
            return .orderedSame
        }
    }

    public init(
        _ keyPath: KeyPath<Compared, String> & Sendable,
        comparator: StringComparator = .caseInsensitive,
        order: Order = .ascending,
    ) {
        self.keyPath = keyPath
        self.order = order
        self.stringComparator = comparator

        self.comparator = { lhs, rhs in
            let lVal = lhs[keyPath: keyPath]
            let rVal = rhs[keyPath: keyPath]

            if comparator.kind == .caseInsensitive {
                return lVal.caseInsensitiveCompare(rVal).with(order: order)
            }

            if lVal < rVal { return .orderedAscending.with(order: order) }
            if lVal > rVal { return .orderedDescending.with(order: order) }
            return .orderedSame
        }
    }

    public init(
        _ keyPath: KeyPath<Compared, String?> & Sendable,
        comparator: StringComparator = .caseInsensitive,
        order: Order = .ascending
    ) {
        self.keyPath = keyPath
        self.order = order
        self.stringComparator = comparator

        self.comparator = { lhs, rhs in
            let lVal = lhs[keyPath: keyPath]
            let rVal = rhs[keyPath: keyPath]

            if lVal == nil && rVal == nil { return .orderedSame }
            if lVal == nil && rVal != nil { return .orderedAscending.with(order: order) }
            if lVal != nil && rVal == nil { return .orderedDescending.with(order: order) }

            guard let lVal, let rVal else {
                // unreachable (in theory)
                fatalError("Unexpectedly found nil value in \(#file):\(#line)")
            }

            if comparator.kind == .caseInsensitive {
                return lVal.caseInsensitiveCompare(rVal).with(order: order)
            }

            if lVal < rVal { return .orderedAscending.with(order: order) }
            if lVal > rVal { return .orderedDescending.with(order: order) }
            return .orderedSame
        }
    }

    public func compare(lhs: Compared, rhs: Compared) -> ComparisonResult {
        comparator(lhs, rhs)
    }

    public struct StringComparator: Equatable, Sendable {
        enum Kind: Sendable {
            case lexical
            case caseInsensitive
        }

        var kind: Kind

        public static var lexical: Self { Self(kind: .lexical)}
        public static var caseInsensitive: Self { Self(kind: .caseInsensitive)}
    }
}

public enum Order: Sendable {
    case ascending
    case descending
}

extension SortRule {
    var expressible: (any Expressible) {
        get throws(SortRuleConversionError) {
            guard let information = Compared._predicateInformation(for: keyPath) else {
                throw .noFieldInformation("\(keyPath)")
            }

            var expressible: any Expressible

            if let stringComparator {
                expressible = switch stringComparator.kind {
                    case .lexical:
                        information.fetchExpressible(collatedBy: .binary)
                    case .caseInsensitive:
                        information.fetchExpressible(collatedBy: .nocase)
                }
            } else {
                expressible = information.fetchExpressible
            }

            if order == .ascending {
                return expressible.expression.asc
            }

            return expressible.expression.desc
        }
    }
}

extension Sequence where Element: PersistentModel {
    public func sorted(using descriptors: [SortRule<Element>]) -> [Element] {
        return sorted { lhs, rhs in
            for descriptor in descriptors {
                let result = descriptor.compare(lhs: lhs, rhs: rhs)

                if result != .orderedSame {
                    return result == .orderedAscending
                }
            }
            return false
        }
    }
}

extension ComparisonResult {
    func with(order: Order) -> ComparisonResult {
        if order == .ascending || self == .orderedSame {
            return self
        }
        return switch self {
            case .orderedAscending:
                .orderedDescending
            case .orderedDescending:
                .orderedAscending
            case .orderedSame:
                .orderedSame
        }
    }
}
