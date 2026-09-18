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
#if TEST_SWIFTUI
    @_spi(VeinTesting) @testable import VeinSwiftUI
#elseif TEST_SCUI
    @_spi(VeinTesting) @testable import VeinSCUI
#else
    @_spi(VeinTesting) @testable import VeinCore
#endif

@Suite
struct EncryptionTest {
    func prepareContainerLocation(name: String) throws -> String {
        let containerPath = FileManager.default.temporaryDirectory

        let dbDir = containerPath.relativePath.appending("/veinTests/\(testID.uuidString)")

        let dbPath = dbDir.appending("/\(name).sqlite3")

        try FileManager.default.createDirectory(
            atPath: dbDir,
            withIntermediateDirectories: true
        )

        return dbPath
    }

    @Test
    func testEncryption() async throws {
        #if os(Linux)
            Keyring.appIdentifier.withLock { identifier in
                identifier = "de.amethystsoft.vein.tests"
            }
        #endif
        let path = try prepareContainerLocation(name: "encryptionTest")

        #if !os(Android)
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: path,
                appID: "de.amethystsoft.vein.tests.encryption"
            )
        #else
            let container = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: path,
                appID: "de.amethystsoft.vein.tests.encryption",
                keyProvider: StubKeyProvider.self
            )
        #endif

        let model = V0_0_1.Test(someValue: "test")
        try container.context.insert(model)
        try container.context.save()

        #if !os(Android)
            let newContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: path,
                appID: "de.amethystsoft.vein.tests.encryption"
            )
        #else
            let newContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: path,
                appID: "de.amethystsoft.vein.tests.encryption",
                keyProvider: StubKeyProvider.self
            )
        #endif

        let first = try newContainer.context.fetchAll(V0_0_1.Test.self).first

        #expect(first?.someValue == "test")

        do {
            let unencryptedContainer = try ModelContainer(
                V0_0_1.self,
                migration: Migration.self,
                at: path,
                appID: "de.amethystsoft.vein.tests.encryption",
                encryptionEnabled: false
            )

            _ = try unencryptedContainer.context.fetchAll(V0_0_1.Test.self)
            Issue.record("Didn't throw an error, db might not be encrypted")
        } catch {
            if case .notADatabase = error { return }
            Issue.record("Thrown error does not match expectations: \(error.errorDescription)")
            return
        }
    }
    
    @Test("getDatabaseKey matches key used for encryption")
    func getDatabaseKeyMatchesKeyUsedForEncryption() async throws {
        let path = try prepareContainerLocation(name: "getDatabaseKeyMatches")
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: path,
            appID: "de.amethystsoft.vein.ModelContainerTests"
        )
        
        let key = try #require(container.context.getDatabaseKey())
        
        let hexKeyRegex = /^[0-9a-f]{64}$/
        #expect(key.wholeMatch(of: hexKeyRegex) != nil)
        
        let connection = try Connection(path)
        try connection.key(key)
        
        do {
            let connection = try Connection(path)
            try connection.key("abc")
            Issue.record("Should have thrown")
        } catch let error as SQLiteDB.Result {
            #expect(error.description == "file is not a database (code: 26)")
        }
    }
    
    @Test("getDatabaseKey returns nil for unencrypted db")
    func getDatabaseKeyReturnsNilForUnencryptedDb() async throws {
        let path = try prepareContainerLocation(name: "getDatabaseKeyIsNil")
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: path,
            appID: "de.amethystsoft.vein.ModelContainerTests",
            encryptionEnabled: false
        )
        
        #expect(container.context.getDatabaseKey() == nil)
    }
    
    @Test("getDatabaseKey returns nil for in memory db")
    func getDatabaseKeyReturnsNilForInMemoryDb() async throws {
        let container = try ModelContainer(
            V0_0_1.self,
            migration: Migration.self,
            at: nil,
            appID: "de.amethystsoft.vein.ModelContainerTests",
            encryptionEnabled: true
        )
        
        #expect(container.context.getDatabaseKey() == nil)
    }

    #if os(Android)
        @Test
        func encryptionEnabledDBWithoutKeyProviderThrows() async throws {
            let path = try prepareContainerLocation(name: "androidEncryptionTest")
            do {
                _ = try ModelContainer(
                    V0_0_1.self,
                    migration: Migration.self,
                    at: path,
                    appID: "de.amethystsoft.vein.tests.encryption"
                )
            } catch let error as ManagedObjectContextError {
                #expect(error.localizedDescription
                    .hasSuffix("Failed to retrieve/save key to encrypt Database.")
                )
                return
            }
            Issue.record("Unexpectedly didn't throw.")
        }
    #endif
}

fileprivate enum V0_0_1: VersionedSchema {
    static let version = ModelVersion(0, 0, 1)
    static let models: [any Vein.PersistentModel.Type] = [Test.self]

    @Model
    final class Test: Identifiable {
        var someValue: String

        @LazyField
        var text: String?

        init(someValue: String) {
            self.someValue = someValue
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

#if os(Android)
    struct StubKeyProvider: DatabaseKeyProvider {
        static nonisolated(unsafe) var keys = [String: String]()
        static func getKey(
            fileName: String,
            service: String,
            generate: (() -> String)?
        ) throws(KeyProviderError) -> String {
            let ressource = "\(service)+\(fileName)"

            if let key = Self.keys[ressource] {
                return key
            } else if let generate {
                let key = generate()

                Self.keys[ressource] = key
                return key
            }

            throw .noSuchKey
        }
    }
#endif
