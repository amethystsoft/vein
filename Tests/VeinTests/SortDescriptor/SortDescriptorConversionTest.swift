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
import Logging
import SQLiteDB
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct SortDescriptorTests {
    @Test
    func ascending() async throws {
        let table = Table(V0_0_1.User.schema)
        let baseQuery = table.select(["*"])

        let descriptor = SortDescriptor<V0_0_1.User>(\.balance)

        let sortedQuery = try baseQuery.order(descriptor.expressible)

        let expectedTemplate = """
            SELECT ? FROM "V0_0_1.User" ORDER BY "balance" ASC
            """

        #expect(sortedQuery.expression.template == expectedTemplate)
    }

    @Test
    func descending() async throws {
        let table = Table(V0_0_1.User.schema)
        let baseQuery = table.select(["*"])

        let descriptor = SortDescriptor<V0_0_1.User>(\.balance, order: .reverse)

        let sortedQuery = try baseQuery.order(descriptor.expressible)

        let expectedTemplate = """
            SELECT ? FROM "V0_0_1.User" ORDER BY "balance" DESC
            """

        #expect(sortedQuery.expression.template == expectedTemplate)
    }

    @Test
    func ascendingOptional() async throws {
        let table = Table(V0_0_1.User.schema)
        let baseQuery = table.select(["*"])

        let descriptor = SortDescriptor<V0_0_1.User>(\.email)

        let sortedQuery = try baseQuery.order(descriptor.expressible)

        let expectedTemplate = """
            SELECT ? FROM "V0_0_1.User" ORDER BY "email" ASC
            """

        #expect(sortedQuery.expression.template == expectedTemplate)
    }

    @Test
    func descendingOptional() async throws {
        let table = Table(V0_0_1.User.schema)
        let baseQuery = table.select(["*"])

        let descriptor = SortDescriptor<V0_0_1.User>(\.email, order: .reverse)

        let sortedQuery = try baseQuery.order(descriptor.expressible)

        let expectedTemplate = """
            SELECT ? FROM "V0_0_1.User" ORDER BY "email" DESC
            """

        #expect(sortedQuery.expression.template == expectedTemplate)
    }

    @Test
    func multiple() async throws {
        let table = Table(V0_0_1.User.schema)
        let baseQuery = table.select(["*"])

        let descriptors = try [
            SortDescriptor<V0_0_1.User>(\.email, order: .reverse),
            SortDescriptor<V0_0_1.User>(\.balance)
        ].map { try $0.expressible }

        let sortedQuery = baseQuery.order(descriptors)

        let expectedTemplate = """
            SELECT ? FROM "V0_0_1.User" ORDER BY "email" DESC, "balance" ASC
            """

        #expect(sortedQuery.expression.template == expectedTemplate)
    }

    @Test
    func empty() async throws {
        let table = Table(V0_0_1.User.schema)
        let baseQuery = table.select(["*"])

        let sortedQuery = baseQuery.order([])

        let expectedTemplate = "SELECT ? FROM \"V0_0_1.User\""

        #expect(sortedQuery.expression.template == expectedTemplate)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self]

    @Model
    final class User: Identifiable {
        @Field
        var email: String?

        @Field
        var balance: Double

        init(email: String?) {
            self.email = email
            self.balance = 0
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] {[]}
}
