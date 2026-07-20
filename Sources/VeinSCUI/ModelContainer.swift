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

@_spi(VeinSurface) import Vein

extension ModelContainer {
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
    public convenience init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        at path: String?,
        appID: String,
        encryptionEnabled: Bool = true,
        logConfiguration: LogConfiguration? = nil
    ) throws(ManagedObjectContextError) {
        try self.init(
            versionedSchema,
            migration: migration,
            at: path,
            appID: appID,
            encryptionEnabled: encryptionEnabled,
            logConfiguration: logConfiguration,
            _notifyBeforeChange: false
        )
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
    public convenience init(
        _ versionedSchema: VersionedSchema.Type,
        migration: SchemaMigrationPlan.Type,
        connection: Connection,
        appID: String,
        encryptionEnabled: Bool = true,
        logConfiguration: LogConfiguration? = nil
    ) throws(ManagedObjectContextError) {
        try self.init(
            versionedSchema,
            migration: migration,
            connection: connection,
            appID: appID,
            encryptionEnabled: encryptionEnabled,
            logConfiguration: logConfiguration,
            _notifyBeforeChange: false
        )
    }
}
