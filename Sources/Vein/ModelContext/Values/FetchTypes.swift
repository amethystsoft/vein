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
#if VeinFilter
    import VeinFilter
#endif

/// A structure describing a paginated fetch request.
/// Paginated requests ignore in memory changes during the query.
/// Models pending deletion will still be removed from the results.
public struct PaginatedFetchDescriptor<T: PersistentModel>: Sendable {
    public let modelPredicate: ModelPredicate<T>
    /// The sort rules that tell the fetch how to order its results.
    public var sortRules: [SortRule<T>]
    /// The maximum number of models the fetch can return.
    public var fetchLimit: Int
    /// The offset of the first matching model to fetch.
    public var fetchOffset: Int

    /// Creates a paginated fetch descriptor with the specified ``ModelPredicate`` that,
    /// optionally, arranges the fetched models in a particular order.
    public init(
        predicate: ModelPredicate<T>,
        sortBy sortRules: [SortRule<T>] = [],
        limit: Int,
        offset: Int
    ) {
        self.modelPredicate = predicate
        self.sortRules = sortRules
        self.fetchLimit = limit
        self.fetchOffset = offset
    }

    /// Creates a paginated fetch descriptor with the specified predicate that,
    /// optionally, arranges the fetched models in a particular order.
    @available(macOS 14, iOS 17, tvOS 17, macCatalyst 17, *)
    public init(
        predicate: Predicate<T>,
        sortBy sortRules: [SortRule<T>] = [],
        limit: Int,
        offset: Int
    ) throws {
        self.modelPredicate = try ModelPredicate(predicate)
        self.sortRules = sortRules
        self.fetchLimit = limit
        self.fetchOffset = offset
    }

    /// Creates a paginated fetch descriptor with the specified type that,
    /// optionally, arranges the fetched models in a particular order.
    public init(
        model: T.Type,
        sortBy sortRules: [SortRule<T>] = [],
        limit: Int,
        offset: Int
    ) {
        self.modelPredicate = ModelPredicate<T>(
            runtimeFilter: { _ in true },
            sql: SQLExpression<Bool>(value: true)
        )
        self.sortRules = sortRules
        self.fetchLimit = limit
        self.fetchOffset = offset
    }

    /// Creates a paginated fetch descriptor with the specified filter that,
    /// optionally, arranges the fetched models in a particular order.
    #if VeinFilter
        public init(
            _ filter: VeinFilter.Filter1<T>,
            sortBy sortRules: [SortRule<T>] = [],
            limit: Int,
            offset: Int
        ) throws {
            self.modelPredicate = try ModelPredicate(filter)
            self.sortRules = sortRules
            self.fetchLimit = limit
            self.fetchOffset = offset
        }
    #endif
}

/// A structure describing a fetch request.
public struct FetchDescriptor<T: PersistentModel> {
    public let modelPredicate: ModelPredicate<T>

    /// The sort rules that tell the fetch how to order its results.
    public var sortRules: [SortRule<T>]

    /// A Boolean value that indicates whether, when the fetch runs,
    /// it matches against currently unsaved changes in the model context.
    /// Models pending deletion will still be removed from the results.
    public var includePendingChanges = true

    /// Creates a fetch descriptor with the specified ``ModelPredicate`` that,
    /// optionally, arranges the fetched models in a particular order.
    public init(
        predicate: ModelPredicate<T>,
        sortBy sortRules: [SortRule<T>] = []
    ) {
        self.modelPredicate = predicate
        self.sortRules = sortRules
    }

    /// Creates a fetch descriptor with the specified predicate that,
    /// optionally, arranges the fetched models in a particular order.
    @available(macOS 14, iOS 17, tvOS 17, macCatalyst 17, *)
    public init(
        predicate: Predicate<T>,
        sortBy sortRules: [SortRule<T>] = []
    ) throws {
        self.modelPredicate = try ModelPredicate(predicate)
        self.sortRules = sortRules
    }

    /// Creates a fetch descriptor with the specified type that,
    /// optionally, arranges the fetched models in a particular order.
    public init(
        model: T.Type,
        sortBy sortRules: [SortRule<T>] = []
    ) {
        self.modelPredicate = ModelPredicate<T>(
            runtimeFilter: { _ in true },
            sql: SQLExpression<Bool>(value: true)
        )
        self.sortRules = sortRules
    }

    /// Creates a fetch descriptor with the specified filter that,
    /// optionally, arranges the fetched models in a particular order.
    #if VeinFilter
        public init(
            filter: VeinFilter.Filter1<T>,
            sortBy sortRules: [SortRule<T>] = []
        ) throws {
            self.modelPredicate = try ModelPredicate(filter)
            self.sortRules = sortRules
        }
    #endif
}
