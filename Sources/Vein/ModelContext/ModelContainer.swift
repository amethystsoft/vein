// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import SQLiteDB

/// The primary entry point for managing database schema and storage.
///
/// `ModelContainer` coordinates the connection between your `VersionedSchema`,
/// the migration lifecycle, and the underlying `ManagedObjectContext`.
public final class ModelContainer: @unchecked Sendable {
    /// The migration plan used to evolve the database schema.
    public let migration: SchemaMigrationPlan.Type

    /// Physical path to the SQLite database file. Returns `nil` for in-memory stores.
    public let path: String?

    /// The internal context used for database operations.
    /// - Note: This is initialized during container creation and remains available for the container’s lifetime.
    public private(set) var context: ManagedObjectContext!

    /// The current ``VersionedSchema`` active for this container.
    public let versionedSchema: VersionedSchema.Type

    private var identifierCache = Mutex([ObjectIdentifier: any PersistentModel.Type]())

    private var currentMigration = Mutex((any VersionedSchema.Type, any VersionedSchema.Type)?.none)

    /// Unique identifier for the database instance, used for keyring service namespacing.
    public let appID: String

    /// Indicates if database-level (SQLCipher) encryption is active.
    public let encryptionEnabled: Bool

    /// The logging verbosity for database operations.
    public let logConfiguration: LogConfiguration

    /// Manages the schema and storage for a Vein database.
    ///
    /// - Parameters:
    ///   - versionedSchema: The VersionedSchema you want to use models of.
    ///   - migration: The MigrationPlan to use if migrations are necessary.
    ///   - path: The path of the database file or nil for in memory.
    ///   - appID: A unique identifier used per-database to construct the keyring
    ///   service string: `"com.amethyst.vein.sqlcipher.\(appID)"`.
    ///   - encryptionEnabled: Whether to apply DB-level encryption.
    ///   - logConfiguration: What information to log.
    ///
    /// - Note: `Keyring.appIdentifier` is a global, one-time configuration for the
    ///   underlying `KeyringAccess` library, typically set once per process or environment.
    ///   It should represent the application bundle or organization identity.
    ///
    ///   `Keyring.appIdentifier` does not need to match the `appID` parameter. If they
    ///   differ, `KeyringAccess` uses the global identifier for internal namespacing while
    ///   continuing to store and retrieve items using the service string derived from `appID`.
    ///
    /// On Linux, set `Keyring.appIdentifier` before creating any `ModelContainer` instances:
    /// ```swift
    /// #if os(Linux)
    ///     import Vein
    ///
    ///     Keyring.appIdentifier.withLock { identifier in
    ///         identifier = "com.example.yourapp"
    ///     }
    /// #endif
    /// ```
    ///
    /// Do not set `_notifyBeforeChange` yourself, you might break UI updates and/or animations doing so.
    @_spi(VeinSurface) public init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        at path: String?,
        appID: String,
        encryptionEnabled: Bool,
        logConfiguration: LogConfiguration?,
        _notifyBeforeChange: Bool
    ) throws(ManagedObjectContextError) {
        if ManagedObjectContext.callBeforeChange.load(ordering: .acquiring) == 3 {
            ManagedObjectContext.callBeforeChange.store(
                _notifyBeforeChange ? 1: 0,
                ordering: .releasing
            )
        }
        if let logConfiguration {
            self.logConfiguration = logConfiguration
        } else {
            #if DEBUG
                self.logConfiguration = .debug
            #else
                self.logConfiguration = .release
            #endif
        }
        self.encryptionEnabled = encryptionEnabled
        self.appID = appID

        guard migration.schemas.contains(where: { $0.self == versionedSchema }) else {
            throw ManagedObjectContextError.schemaNotRegisteredOnMigrationPlan(
                versionedSchema,
                migration
            )
        }

        self.migration = migration
        if let path {
            guard let decodedPath = path.removingPercentEncoding else {
                throw ManagedObjectContextError.other(
                    message: "Invalid percent-encoded database path: \(path)"
                )
            }
            self.path = decodedPath
        } else { self.path = nil }
        self.versionedSchema = versionedSchema
        if let path = self.path {
            if !FileManager.default.fileExists(atPath: path) {
                let created = FileManager.default.createFile(
                    atPath: path,
                    contents: nil
                )
                if !created {
                    throw ManagedObjectContextError.other(
                        message: "Failed to create database file at path: \(path)"
                    )
                }
            }
            self.context = try ManagedObjectContext(
                path: path,
                modelContainer: self
            )
        } else {
            self.context = try ManagedObjectContext(modelContainer: self)
        }

        do {
            try context.createMigrationsTable()
        } catch let error as ManagedObjectContextError {
            throw error
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }

    /// Manages the schema and storage for a Vein database.
    ///
    /// - Parameters:
    ///   - versionedSchema: The VersionedSchema you want to use models of.
    ///   - migration: The MigrationPlan to use if migrations are necessary.
    ///   - connection: The existing connection to the database.
    ///   - appID: A unique identifier used per-database to construct the keyring
    ///   service string: `"com.amethyst.vein.sqlcipher.\(appID)"`.
    ///   - encryptionEnabled: Whether to apply DB-level encryption.
    ///   - logConfiguration: What information to log.
    ///
    /// - Note: `Keyring.appIdentifier` is a global, one-time configuration for the
    ///   underlying `KeyringAccess` library, typically set once per process or environment.
    ///   It should represent the application bundle or organization identity.
    ///
    ///   `Keyring.appIdentifier` does not need to match the `appID` parameter. If they
    ///   differ, `KeyringAccess` uses the global identifier for internal namespacing while
    ///   continuing to store and retrieve items using the service string derived from `appID`.
    ///
    /// On Linux, set `Keyring.appIdentifier` before creating any `ModelContainer` instances:
    /// ```swift
    /// #if os(Linux)
    ///     import Vein
    ///
    ///     Keyring.appIdentifier.withLock { identifier in
    ///         identifier = "com.example.yourapp"
    ///     }
    /// #endif
    /// ```
    ///
    /// Do not set `_notifyBeforeChange` yourself, you might break UI updates and/or animations doing so.
    @_spi(VeinSurface) public init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        connection: Connection,
        appID: String,
        encryptionEnabled: Bool,
        logConfiguration: LogConfiguration?,
        _notifyBeforeChange: Bool
    ) throws(ManagedObjectContextError) {
        if ManagedObjectContext.callBeforeChange.load(ordering: .acquiring) == 3 {
            ManagedObjectContext.callBeforeChange.store(
                _notifyBeforeChange ? 1: 0,
                ordering: .releasing
            )
        }
        if let logConfiguration {
            self.logConfiguration = logConfiguration
        } else {
            #if DEBUG
                self.logConfiguration = .debug
            #else
                self.logConfiguration = .release
            #endif
        }

        self.encryptionEnabled = encryptionEnabled
        self.appID = appID

        guard migration.schemas.contains(where: { $0.self == versionedSchema }) else {
            throw ManagedObjectContextError.schemaNotRegisteredOnMigrationPlan(
                versionedSchema,
                migration
            )
        }

        self.migration = migration
        self.path = nil
        self.versionedSchema = versionedSchema
        self.context = ManagedObjectContext(
            connection: connection,
            modelContainer: self
        )

        do {
            try context.createMigrationsTable()
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }

    /// Executes the migration logic assigned in the `SchemaMigrationPlan`.
    ///
    /// This method must be called from the Main Actor to ensure thread-safe schema evolution.
    @MainActor
    public func migrate() throws {
        defer {
            context.isInActiveMigration.value = false
            currentMigration.value = nil
            identifierCache.mutate { identifierCache in
                identifierCache.removeAll()
            }
        }
        context.isInActiveMigration.value = true

        try context.transaction { [self] in
            while case .complex(
                let originVersion,
                let destinationVersion,
                let migrationBlock,
                let didFinishMigration
            ) = try determineMigrationStage() {
                self.currentMigration.value = (originVersion, destinationVersion)

                identifierCache.mutate { identifierCache in
                    identifierCache.removeAll()
                }
                try migrationBlock?(context)

                try context.save()

                let unmigratedSchemas = try unmigratedSchemas(from: originVersion)

                guard unmigratedSchemas.isEmpty else {
                    context.removeModelsFromContext(for: originVersion)
                    if destinationVersion != versionedSchema {
                        context.removeModelsFromContext(for: destinationVersion)
                    }
                    throw ManagedObjectContextError.modelsUnhandledAfterMigration(
                        originVersion,
                        destinationVersion,
                        unmigratedSchemas
                    )
                }

                try context.cleanupOldSchema(originVersion)
                context.removeModelsFromContext(for: originVersion)
                if destinationVersion != versionedSchema {
                    context.removeModelsFromContext(for: destinationVersion)
                }

                try didFinishMigration?(context)
            }
        }
    }

    func getConnection() -> Connection {
        return context.connection
    }

    @MainActor
    private func unmigratedSchemas(from version: VersionedSchema.Type) throws -> [String] {
        let tables = try context.getNonEmptySchemas()

        return tables.filter { table in
            version.models.contains(where: { $0.schema == table })
        }
    }

    @MainActor
    private func determineMigrationStage() throws -> MigrationStage? {
        let version = try context.getLatestMigrationVersion()

        // If no current version is found the database is treated as empty and
        // no migration is required
        guard let version else { return nil }

        // Already up to date, no migration is necessary
        if version == versionedSchema.version {
            return nil
        }

        if version > versionedSchema.version {
            throw MOCError.dbNewerThanCode(version, versionedSchema.version)
        }

        var currentSchema: VersionedSchema.Type? = nil

        for versionedSchema in migration.schemas.reversed() {
            if versionedSchema.version == version {
                currentSchema = versionedSchema
                break
            }
        }

        guard let currentSchema else {
            throw ManagedObjectContextError.noSchemaMatchingVersion(migration, version)
        }

        for stage in migration.stages.reversed() {
            if case .complex(let schema,_,_,_) = stage, schema.version == currentSchema.version {
                return stage
            }
        }

        throw ManagedObjectContextError.noMigrationForOutdatedModelVersion(migration, version)
    }

    nonisolated func getSchema(for identifier: ObjectIdentifier) -> (any PersistentModel.Type)? {
        if
            let cached = identifierCache.mutate ({ identifierCache in
                return identifierCache[identifier]
            })
        {
            return cached
        }

        var potentialModelTypes: [any PersistentModel.Type]

        if let (origin, destination) = currentMigration.value {
            potentialModelTypes = origin.models + destination.models
        } else {
            potentialModelTypes = versionedSchema.models
        }

        for type in potentialModelTypes where type.typeIdentifier == identifier {
            identifierCache.mutate { identifierCache in
                identifierCache[identifier] = type
            }
            return type
        }

        return nil
    }
}
