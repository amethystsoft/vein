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
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct RealDatabaseSortDescriptorTests {
    func prepareContainerLocation(name: String) throws -> String {
        let containerPath = FileManager.default.temporaryDirectory

        let dbDir = containerPath.relativePath.appending("/veinTests/\(testID.uuidString)")

        let dbPath = dbDir.appending("/\(name).sqlite3")

        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )

        if !FileManager.default.fileExists(atPath: dbPath) {
            FileManager.default.createFile(
                atPath: dbPath,
                contents: nil
            )
        }

        return dbPath
    }

    private func makeContainer(name: String) throws -> ModelContainer {
        let dbPath = try prepareContainerLocation(name: name)
        try makeTestData(name: name)

        var logConfig = LogConfiguration.debug
        logConfig.sqlQueries = true

        return try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RealDatabaseSortDescriptorTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption,
            logConfiguration: logConfig
        )
    }

    // Helper to spin up a container and seed test users
    private func makeTestData(name: String) throws {
        let dbPath = try prepareContainerLocation(name: name)

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: dbPath,
            appID: "de.amethystsoft.vein.RealDatabaseSortDescriptorTests",
            encryptionEnabled: ProcessInfo.shouldEnableEncryption
        )
        // Seed users
        let user1 = V0_0_1.User(name: "Mia", email: "mia@example.com", birthday: Date())
        user1.balance = 500.0
        user1.pendingTransactionValue = 50.0
        user1.somethingOptional = "has_value"

        // Name matches email exactly
        let user2 = V0_0_1.User(name: "matching", email: "matching", birthday: Date())
        user2.balance = -10.0
        user2.pendingTransactionValue = 100.0
        user2.somethingOptional = nil

        let user3 = V0_0_1.User(name: "Charlie", email: "charlie@mia.com", birthday: Date())
        user3.balance = 0.0
        user3.pendingTransactionValue = 0.0
        user3.somethingOptional = nil

        try container.context.insert(user1)
        try container.context.insert(user2)
        try container.context.insert(user3)
        try container.context.save()
    }

    @Test
    func testDoubleAscending() async throws {
        let container = try makeContainer(name: "DoubleAscending")

        let results = try container.context.fetchAll(
            V0_0_1.User.self,
            sortBy: [SortDescriptor<V0_0_1.User>(\.balance)]
        )

        #expect(results.count == 3)
        #expect(results[0].balance < results[1].balance)
        #expect(results[1].balance < results[2].balance)
    }

    @Test
    func testDoubleDescending() async throws {
        let container = try makeContainer(name: "DoubleDescending")

        let results = try container.context.fetchAll(
            V0_0_1.User.self,
            sortBy: [SortDescriptor(\.balance, order: .reverse)]
        )

        #expect(results.count == 3)
        #expect(results[0].balance > results[1].balance)
        #expect(results[1].balance > results[2].balance)
    }

    @Test
    func testStringAscending() async throws {
        let container = try makeContainer(name: "StringAscending")

        let results = try container.context.fetchAll(
            V0_0_1.User.self,
            sortBy: [SortDescriptor<V0_0_1.User>(\.name, comparator: .lexical)]
        )

        #expect(results.count == 3)
        #expect(results[0].name < results[1].name)
        #expect(results[1].name < results[2].name)
    }

    @Test
    func testStringDescending() async throws {
        let container = try makeContainer(name: "StringDescending")

        let results = try container.context.fetchAll(
            V0_0_1.User.self,
            sortBy: [SortDescriptor(\.name, comparator: .lexical, order: .reverse)]
        )

        #expect(results.count == 3)
        #expect(results[0].name > results[1].name)
        #expect(results[1].name > results[2].name)
    }

    @Test
    func testOptionalAscending() async throws {
        let container = try makeContainer(name: "OptionalAscending")

        let results = try container.context.fetchAll(
            V0_0_1.User.self,
            sortBy: [SortDescriptor<V0_0_1.User>(\.somethingOptional)]
        )

        #expect(results.count == 3)
        #expect(results[0].somethingOptional == nil)
        #expect(results[1].somethingOptional == nil)
        #expect(results[2].somethingOptional == "has_value")
    }

    @Test
    func testOptionalDescending() async throws {
        let container = try makeContainer(name: "OptionalDescending")

        let results = try container.context.fetchAll(
            V0_0_1.User.self,
            sortBy: [SortDescriptor(\.somethingOptional, order: .reverse)]
        )

        #expect(results.count == 3)
        #expect(results[0].somethingOptional == "has_value")
        #expect(results[1].somethingOptional == nil)
        #expect(results[2].somethingOptional == nil)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [User.self]

    @Model
    final class User: Identifiable {
        @Field
        var name: String

        @Field
        var email: String

        @Field
        var birthday: Date

        @Field
        var balance: Double

        @Field
        var pendingTransactionValue: Double

        @Field
        var somethingOptional: String?

        init(name: String, email: String, birthday: Date) {
            self.name = name
            self.email = email
            self.birthday = birthday
            self.balance = 0
            self.pendingTransactionValue = 0
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] { [] }
}
