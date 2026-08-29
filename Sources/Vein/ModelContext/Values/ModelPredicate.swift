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

@preconcurrency import SQLiteDB
import ULID
import Foundation
#if VeinFilter
    import VeinFilter
#endif

/// A predicate for fetching models.
///
/// Can either be created by using a FoundationMacros.Predicate or by providing your own SQL Query and runtime filter.
public struct ModelPredicate<T: PersistentModel>: Sendable, Hashable, AnyPredicateBuilder {
    public let runtimeFilter: @Sendable (T) -> Bool
    public let sql: SQLExpression<Bool>
    public let identity: String

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }

    public init(runtimeFilter: @Sendable @escaping (T) -> Bool, sql: SQLExpression<Bool>) {
        self.runtimeFilter = runtimeFilter
        self.sql = sql
        self.identity = sql.template + sql.bindings.description
    }

    @available(macOS 14, iOS 17, tvOS 17, macCatalyst 17, *)
    public init(_ predicate: Foundation.Predicate<T>) throws {
        runtimeFilter = { model in
            do {
                return try predicate.evaluate(model)
            } catch {
                fatalError(
                    "Filtering models of type \(T.self) failed: \(error.localizedDescription)"
                )
            }
        }
        sql = try predicate.toSQLiteFilter()
        self.identity = sql.template + sql.bindings.description
    }

    #if VeinFilter
        public init(_ filter: VeinFilter.Filter1<T>) throws {
            runtimeFilter = { model in
                do {
                    return try filter.evaluate(model)
                } catch {
                    fatalError(
                        "Filtering models of type \(T.self) failed: \(error.localizedDescription)"
                    )
                }
            }
            sql = try filter.toSQLiteFilter()
            self.identity = sql.template + sql.bindings.description
        }
    #endif

    public static func == (
        lhs: borrowing ModelPredicate<T>,
        rhs: borrowing ModelPredicate<T>
    ) -> Bool {
        lhs.identity == rhs.identity
    }

    public static var all: Self {
        ModelPredicate(runtimeFilter: { _ in true }, sql: SQLExpression(value: true))
    }
}
