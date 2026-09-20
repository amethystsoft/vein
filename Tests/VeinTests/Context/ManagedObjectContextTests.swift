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
import SQLiteDB
import SQLCipher
@testable import Vein
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct ManagedObjectContextTests {
    @Test("Context without changes doesn't attempt transaction")
    func contextWithoutChangesIsNotAttemptingWrites() async throws {
        let connection = try Connection()

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        #expect(!container.context.hasChanges)

        let handle = connection.handle

        sqlite3_set_authorizer(handle, { _, action, _, _, _, _ in
            // Deny everything to confirm nothing is ran.
            return SQLITE_DENY
        }, nil)

        try container.context.save()
    }

    @Test("Save restores changes after failing")
    func saveRestoresChangesAfterFailing() async throws {
        let connection = try Connection()

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let toDelete = V0_0_1.Test(flag: true)
        let toUpdate = V0_0_1.Test(flag: false)
        let toInsert = V0_0_1.Test(flag: true)

        try container.context.insert(toDelete)
        try container.context.insert(toUpdate)
        try container.context.save()

        try container.context.insert(toInsert)
        try container.context.delete(toDelete)
        toUpdate.flag = true

        let identifier = ObjectIdentifier(V0_0_1.Test.self)

        container.context.writeCache.mutate { inserts, updates, deletes, states in
            verify(
                inserts: inserts,
                updates: updates,
                deletes: deletes,
                states: states
            )
        }

        let handle = connection.handle

        sqlite3_set_authorizer(handle, { _, action, _, _, _, _ in
            // Deny everything to make save fail.
            return SQLITE_DENY
        }, nil)

        do {
            try container.context.save()
            Issue.record("Should've thrown.")
        } catch let error as SQLiteDB.Result {
            #expect(error.description == "not authorized (code: 23)")
        }

        container.context.writeCache.mutate { inserts, updates, deletes, states in
            verify(
                inserts: inserts,
                updates: updates,
                deletes: deletes,
                states: states
            )
        }

        func verify(
            inserts: WriteCacheDictionary,
            updates: WriteCacheDictionary,
            deletes: WriteCacheDictionary,
            states: [ObjectIdentifier: [ULID: PrimitiveState]]
        ) {
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == toInsert.id })

            #expect(updates[identifier, default: [:]].count == 1)
            #expect(updates[identifier, default: [:]].keys.contains { $0 == toUpdate.id })

            #expect(deletes[identifier, default: [:]].count == 1)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toDelete.id })

            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }
    }

    @Test("Save clears write cache")
    func saveClearsWriteCache() async throws {
        let connection = try Connection()

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let toDelete = V0_0_1.Test(flag: true)
        let toUpdate = V0_0_1.Test(flag: false)
        let toInsert = V0_0_1.Test(flag: true)

        try container.context.insert(toDelete)
        try container.context.insert(toUpdate)
        try container.context.save()

        try container.context.insert(toInsert)
        try container.context.delete(toDelete)
        toUpdate.flag = true

        let identifier = ObjectIdentifier(V0_0_1.Test.self)

        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == toInsert.id })

            #expect(updates[identifier, default: [:]].count == 1)
            #expect(updates[identifier, default: [:]].keys.contains { $0 == toUpdate.id })

            #expect(deletes[identifier, default: [:]].count == 1)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toDelete.id })

            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }

        try container.context.save()

        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts.isEmpty)
            #expect(updates.isEmpty)
            #expect(deletes.isEmpty)
            #expect(states.isEmpty)
        }
    }

    @Test("Deletion removes insertion and update of same model")
    func deletionRemovesInsertionAndUpdateOfSameModel() throws {
        let connection = try Connection()

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let toUpdate = V0_0_1.Test(flag: false)
        let toInsert = V0_0_1.Test(flag: true)

        try container.context.insert(toUpdate)
        try container.context.save()

        try container.context.insert(toInsert)
        toUpdate.flag = true

        let identifier = ObjectIdentifier(V0_0_1.Test.self)

        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == toInsert.id })

            #expect(updates[identifier, default: [:]].count == 1)
            #expect(updates[identifier, default: [:]].keys.contains { $0 == toUpdate.id })

            #expect(deletes[identifier, default: [:]].count == 0)

            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }

        try container.context.delete(toUpdate)
        try container.context.delete(toInsert)

        container.context.writeCache.mutate { inserts, updates, deletes, states in
            #expect(inserts.isEmpty)
            #expect(updates.isEmpty)
            #expect(deletes[identifier, default: [:]].count == 2)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toInsert.id })
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
            #expect(states[identifier, default: [:]].count == 1)
            #expect(states[identifier, default: [:]].keys.contains { $0 == toUpdate.id })
        }

        #expect(!toUpdate.isManaged)
        #expect(!toInsert.isManaged)
    }

    @Test("Insertion removes deletes of same model")
    func insertionRemovesDeleteOfSameModel() throws {
        let connection = try Connection()

        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let model = V0_0_1.Test(flag: false)

        try container.context.insert(model)
        try container.context.save()

        let identifier = ObjectIdentifier(V0_0_1.Test.self)

        #expect(model.isManaged)

        try container.context.delete(model)
        #expect(!model.isManaged)

        container.context.writeCache.mutate { inserts, updates, deletes, _ in
            #expect(inserts[identifier, default: [:]].count == 0)

            #expect(updates[identifier, default: [:]].count == 0)

            #expect(deletes[identifier, default: [:]].count == 1)
            #expect(deletes[identifier, default: [:]].keys.contains { $0 == model.id })
        }

        try container.context.insert(model)
        #expect(model.isManaged)

        container.context.writeCache.mutate { inserts, updates, deletes, _ in
            #expect(inserts[identifier, default: [:]].count == 1)
            #expect(inserts[identifier, default: [:]].keys.contains { $0 == model.id })
            #expect(updates.isEmpty)
            #expect(deletes.isEmpty)
        }
    }

    @Test("Deletion of unmanaged model silently returns")
    func deletionOfUnmanagedModelSilentlyReturns() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        try container.context.delete(V0_0_1.Test(flag: false))

        #expect(!container.context.hasChanges)
    }

    @Test("Insertion of managed model throws")
    func insertionOfManagedModelThrows() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let model = V0_0_1.Test(flag: true)

        let expectedErrorMessage =
            "raised by model of type '\(V0_0_1.Test.self)' with id \(model.id.ulidString)"

        do {
            try container.context.insert(model)
            #expect(model.isManaged)
            try container.context.insert(model)
        } catch {
            switch error {
                case .insertManagedModel(let message):
                    #expect(message == expectedErrorMessage)
                default:
                    throw error
            }
        }
    }

    @Test("fetchAll with empty table returns []")
    func fetchAllWithEmptyTableReturnsEmptyArray() throws {
        let connection = try Connection()
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )
        let model = V0_0_1.Test(flag: true)
        model._setupFields()

        try model.migrate(in: container.context)

        let query = Table("sqlite_master")
            .select([SQLExpression<String>("name")])
            .where(
                SQLExpression<String>("type") == "table" &&
                    SQLExpression<String>("name") == V0_0_1.Test.schema
            )

        let results = try connection.prepare(query)

        let mapped = try results.map { row in try row.get(SQLExpression<String>("name")) }

        let name = try #require(mapped.first)
        #expect(name == V0_0_1.Test.schema)

        let result = try container.context.fetchAll(V0_0_1.Test.self)
        #expect(result.isEmpty)
    }

    @Test("fetchCount with noSuchTable returns 0")
    func fetchCountWithNoSuchTableReturnsZero() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let descriptor = FetchDescriptor(model: V0_0_1.Test.self)

        let fetchCount = try container.context.fetchCount(descriptor)
        #expect(fetchCount == 0)
    }

    @Test("_fetchSingleProperty without result throws unexpectedlyEmptyResult")
    func LazyFieldWithoutResultReturnsNil() throws {
        let connection = try Connection()
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let model = V0_0_1.Test(flag: true)
        try container.context.insert(model)
        try container.context.save()

        let table = Table(V0_0_1.Test.schema)
            .filter(SQLExpression<String>("id") == model.id.ulidString)
            .delete()

        try connection.run(table)

        let field = model.getLazy()
        do {
            let _ = try container.context._fetchSingleProperty(field: field)
            Issue.record("Unexpectedly didn't throw")
        } catch {
            if case .unexpectedlyEmptyResult(let message) = error {
                #expect(message ==
                    "raised by field with property name 'lazy' of Model '\(V0_0_1.Test.schema)' with id \(model.id.ulidString)")
            } else {
                throw error
            }
        }

        #expect(field.wrappedValue == nil)
    }

    // This is currently not used outside of test, but since it might be in the future
    // I'm adding this test to make sure it doesn't break.
    @Test("getAllStoredSchemas exclueds system tables")
    func getAllStoredSchemasExcludesSystemTables() throws {
        let connection = try Connection()
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let model = V0_0_1.Test(flag: true)
        try container.context.insert(model)
        try container.context.save()

        let tables = try connection.schema.objectDefinitions(type: .table)
        #expect(tables.count == 4)

        let schemas = try container.context.getAllStoredSchemas()
        #expect(schemas == [V0_0_1.Test.schema])
    }

    @Test("getNonEmptySchemas excludes empty tables")
    func getNonEmptySchemasExcludesEmptyTables() throws {
        let connection = try Connection()
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            connection: connection,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let model = V0_0_1.Test(flag: true)
        try container.context.insert(model)
        try container.context.save()

        let nonEmptySchemas = try container.context.getNonEmptySchemas()
        #expect(nonEmptySchemas == [V0_0_1.Test.schema])

        try container.context.delete(model)
        try container.context.save()

        let nonEmptySchemas2 = try container.context.getNonEmptySchemas()
        #expect(nonEmptySchemas2.isEmpty)
    }

    @Test("nested transaction inner rollbacks outer saves")
    func nestedTransactionInnerRollbacksOuterSaves() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        try container.context.transaction {
            do {
                try container.context.transaction {
                    try container.context.insert(V0_0_1.Test(flag: true))
                    try container.context.save()

                    let results = try container.context.fetchAll(V0_0_1.Test.self)
                    #expect(results.count == 1)

                    throw MOCError.other(message: "throwing from nested transaction")
                }
                Issue.record("unexpectedly didn't throw.")
            } catch {
                if case ManagedObjectContextError.other(let message) = error {
                    #expect(message == "throwing from nested transaction")
                } else {
                    Issue.record("threw unexpected error")
                }

                let results = try container.context.fetchAll(V0_0_1.Test.self)
                #expect(results.count == 0)
            }

            try container.context.insert(V0_0_1.Test(flag: true))
            try container.context.save()
        }

        var fetchDescriptor = FetchDescriptor(model: V0_0_1.Test.self)
        fetchDescriptor.includePendingChanges = false
        let results = try container.context.fetch(fetchDescriptor)
        #expect(results.count == 1)
    }

    @Test("nested transaction inner saves outer rollbacks both")
    func nestedTransactionInnerSavesOuterRollbacksBoths() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        do {
            try container.context.transaction {
                try container.context.transaction {
                    try container.context.insert(V0_0_1.Test(flag: true))
                    try container.context.save()
                }

                let results = try container.context.fetchAll(V0_0_1.Test.self)
                #expect(results.count == 1)

                try container.context.insert(V0_0_1.Test(flag: true))
                try container.context.save()
                throw MOCError.other(message: "throwing from outer transaction")
            }
        } catch {
            if case ManagedObjectContextError.other(let message) = error {
                #expect(message == "throwing from outer transaction")
            } else {
                Issue.record("threw unexpected error")
            }

            let results = try container.context.fetchAll(V0_0_1.Test.self)
            #expect(results.count == 0)
        }

        var fetchDescriptor = FetchDescriptor(model: V0_0_1.Test.self)
        fetchDescriptor.includePendingChanges = false
        let results = try container.context.fetch(fetchDescriptor)
        #expect(results.count == 0)
    }

    @Test("Model is rolled back to original state correctly")
    func modelRollback() throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ManagedObjectContextTests",
            encryptionEnabled: false
        )

        let model = V0_0_1.Test(flag: true)

        try container.context.insert(model)
        try container.context.save()

        model.flag = false

        try container.context.delete(model)

        container.context.rollback()

        #expect(model.flag)
    }
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]

    @Model
    final class Test: Identifiable {
        @Field
        var flag: Bool

        @LazyField
        var lazy: Bool?

        init(flag: Bool) {
            self.flag = flag
        }

        func getLazy() -> LazyField<Bool> {
            _lazy
        }
    }
}

fileprivate enum Migration: SchemaMigrationPlan {
    static var schemas: [any Vein.VersionedSchema.Type] {
        [V0_0_1.self]
    }

    static var stages: [MigrationStage] { [] }
}
