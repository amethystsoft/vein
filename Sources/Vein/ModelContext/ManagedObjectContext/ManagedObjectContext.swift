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

import SQLiteDB
import Foundation
import ULID
import Crypto
import Logging
import Atomics
#if canImport(AppKit) || canImport(UIKit)
    import KeychainAccess
#elseif os(Linux)
    @_exported import KeyringAccess
#endif

public typealias Connection = SQLiteDB.Connection

/// The central object for managing the persistence lifecycle of your models.
///
/// `ManagedObjectContext` provides a thread-safe interface for fetching, inserting,
/// and deleting data. It coordinates between the in-memory identity map,
/// write-through caches, and the underlying SQLite storage.
///
/// Although declared as an actor, the API is designed for high-concurrency
/// access through internal synchronization.
public actor ManagedObjectContext {
    @_spi(VeinSurface)
    public static nonisolated let callBeforeChange = ManagedAtomic<UInt8>(3)
    public static let logger = Logger(label: "ManagedObjectContext")
    package nonisolated let connection: SQLiteDB.Connection
    public nonisolated unowned let modelContainer: ModelContainer
    public static let keyLock = NSLock()

    @TaskLocal static var isSettingInternalMetdata = false

    nonisolated let _clientID = Mutex<String?>(nil)
    nonisolated var clientID: String {
        _clientID.mutate { clientID in
            if let clientID {
                return clientID
            }

            let key = "de.amethystsoft.vein-database.clientID"
            if let stored = UserDefaults.standard.string(forKey: key) {
                clientID = stored
                return stored
            }
            let id = UUID().uuidString
            UserDefaults.standard.set(id, forKey: key)

            clientID = id
            return id
        }
    }

    // MARK: - Migrations
    package nonisolated let isInActiveMigration = Mutex(false)

    // MARK: - In memory write caching and rollback
    package nonisolated let writeCache = WriteCache()

    package nonisolated let stagingCache = WriteCache()

    // Used in `ManagedObjectContext/save` to
    // make sure only one save is running at a time
    nonisolated let saveLock = NSLock()

    // MARK: - Ensure single row - single instance
    nonisolated(unsafe) let identityMap = ThreadSafeIdentityMap()

    // MARK: - UI change notification
    nonisolated let registeredQueries = Mutex(
        [ObjectIdentifier: [Int: WeakQueryObserver]]()
    )
    nonisolated let pendingNotifications = Mutex(
        [ObjectIdentifier: [AnyObject]]()
    )
    nonisolated let notificationTask = Mutex(Task<Void, Never>?.none)

    // MARK: - Initializers
    /// Connects to database at `path`, creates a new one if it doesn't exist
    init(
        path: String,
        modelContainer: ModelContainer
    ) throws(ManagedObjectContextError) {
        self.modelContainer = modelContainer
        do {
            self.connection = try Connection(path)
            // That stuff can take 15s with TSAN enabled and compiled with Onone.
            // I confirmed its only an issue with TSAN.
            #if canImport(AppKit) || canImport(UIKit) || os(Linux) || canImport(WinSDK)
                if modelContainer.encryptionEnabled {
                    guard
                        let key = Self.getKeyForDatabase(
                            at: path,
                            appID: modelContainer.appID
                        )
                    else {
                        fatalError("Vein: Failed to retrieve/save key to encrypt Database.")
                    }
                    try self.connection.key(key)
                }
            #endif

            try self.connection.execute("PRAGMA journal_mode=WAL;")
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }

    /// In memory only
    init(
        modelContainer: ModelContainer
    ) throws(ManagedObjectContextError) {
        self.modelContainer = modelContainer
        do {
            self.connection = try Connection(.inMemory)
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }

    init(
        connection: Connection,
        modelContainer: ModelContainer
    ) {
        self.modelContainer = modelContainer
        self.connection = connection
    }

    /// Retrieves the hex-encoded encryption key used to secure the database.
    ///
    /// Use this method to provide users with a manual backup of their encryption
    /// key or to facilitate database migration/recovery scenarios.
    ///
    /// - Important: The key is sensitive information. Ensure it is only displayed
    ///   briefly in a secure UI and never logged or stored in insecure locations.
    /// - Returns: The hex-encoded 256-bit encryption key, or `nil` if encryption
    ///   is disabled or the key cannot be retrieved.
    public nonisolated func getDatabaseKey() -> String? {
        guard
            let path = modelContainer.path,
            modelContainer.encryptionEnabled
        else {
            return nil
        }
        return Self.getKeyForDatabase(
            at: path,
            appID: modelContainer.appID,
            createIfMissing: false
        )
    }

    /// Accesses the encryption key for a specific database file without requiring an active database connection.
    ///
    /// This static method allows you to retrieve or generate encryption keys by providing the file path
    /// and application identifier. While the instance method `getDatabaseKey()` is preferred for
    /// active contexts, this method is useful for utility tasks or pre-initialization checks.
    ///
    /// - Parameters:
    ///   - path: The absolute file path to the database. The filename is used as the key identifier in the secure store.
    ///   - appID: The unique application identifier used to namespace the Keychain or Keyring service.
    ///   - createIfMissing: If `true`, a new 256-bit AES key will be generated and persisted if one
    ///     does not already exist. Set this to `false` if you only want to verify the existence of a key.
    ///
    /// - Note: On Apple platforms, this utilizes the System Keychain. On Linux, it utilizes the
    ///   system Keyring.
    ///
    /// - Returns: A hex-encoded 256-bit key string if found or successfully created; otherwise, `nil`.
    public static func getKeyForDatabase(
        at path: String,
        appID: String,
        createIfMissing: Bool = true
    ) -> String? {
        return keyLock.withLock {
            let url = URL(fileURLWithPath: path)
            let fileName = url.lastPathComponent

            #if canImport(AppKit) || canImport(UIKit)
                let keychain = Keychain(service: "com.amethyst.vein.sqlcipher.\(appID)")

                if let key = keychain[fileName] {
                    return key
                } else if createIfMissing {
                    let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
                    let hexKey = keyData.map { String(format: "%02hhx", $0) }.joined()

                    guard (try? keychain.set(hexKey, key: fileName)) != nil else {
                        return nil
                    }
                    return hexKey
                }
            #elseif os(Linux)
                let keyring = Keyring(service: "com.amethyst.vein.sqlcipher.\(appID)")

                if let key = keyring[fileName] {
                    return key
                } else if createIfMissing {
                    let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
                    let hexKey = keyData.map { String(format: "%02hhx", $0) }.joined()

                    guard (try? keyring.set(hexKey, for: fileName)) != nil else {
                        return nil
                    }
                    return hexKey
                }
            #elseif canImport(WinSDK)
                let ressource = "com.amethyst.vein.sqlcipher.\(appID)+\(fileName)"
                if let key = WinCredential.retrieve(resource: ressource) {
                    return key
                } else if createIfMissing {
                    let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
                    let hexKey = keyData.map { String(format: "%02hhx", $0) }.joined()

                    guard WinCredential.store(
                        resource: ressource,
                        username: "veindbsecret",
                        secret: hexKey
                    ) else {
                        return nil
                    }
                    return hexKey
                }
            #endif
            return nil
        }
    }
}

extension ManagedObjectContext {
    nonisolated public var identifier: ObjectIdentifier { ObjectIdentifier(self) }
}
