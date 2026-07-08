// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
// Licensed under Mozilla Public License v2.0
//
// See LICENSE.txt for license information
//
// ===----------------------------------------------------------------------===

@preconcurrency import SQLiteDB
import ULID
import Foundation

/// A predicate for fetching models.
///
/// Can either be created by using a FoundationMacros.Predicate or by providing your own SQL Query and runtime filter.
public struct ModelPredicate<T: PersistentModel>: Sendable, Hashable, AnyPredicateBuilder {
    public let runtimeFilter: @Sendable (T) -> Bool
    public let sql: SQLExpression<Bool>
    private let id = ULID()

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public init(runtimeFilter: @Sendable @escaping (T) -> Bool, sql: SQLExpression<Bool>) {
        self.runtimeFilter = runtimeFilter
        self.sql = sql
    }

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
    }

    public static func == (
        lhs: borrowing ModelPredicate<T>,
        rhs: borrowing ModelPredicate<T>
    ) -> Bool {
        lhs.id == rhs.id
    }

    public static var all: Self {
        ModelPredicate(runtimeFilter: { _ in true }, sql: SQLExpression(value: true))
    }
}
