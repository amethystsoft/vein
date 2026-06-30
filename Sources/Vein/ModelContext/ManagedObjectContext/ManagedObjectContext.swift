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

@_spi(VeinSurface)
@_spi(VeinTesting)
public typealias Connection = SQLiteDB.Connection

public actor ManagedObjectContext {
    @_spi(VeinSurface)
    public static nonisolated let callBeforeChange = ManagedAtomic<Bool>(false)
    public static let logger = Logger(label: "ManagedObjectContext")
    package nonisolated let connection: SQLiteDB.Connection
    public nonisolated unowned let modelContainer: ModelContainer
    
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
            
#if canImport(AppKit) || canImport(UIKit) || os(Linux)
            if modelContainer.encryptionEnabled {
                guard
                    let key = Self.getKeyForDatabase(
                        at: path,
                        appID: modelContainer.appID
                    ) else {
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
    
    /// Retrieve the key encrypting the database, if applicable.
    ///
    /// Do not keep the key in memory or on screen for extended periods of time in production apps.
    /// It should only be displayed as long as absolutely needed.
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
    
    public static func getKeyForDatabase(at path: String, appID: String, createIfMissing: Bool = true) -> String? {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        
#if canImport(AppKit) || canImport(UIKit)
        let keychain = Keychain(service: "com.amethyst.vein.sqlcipher.\(appID)")
        
        if let key = keychain[fileName] {
            return key
        } else if createIfMissing {
            let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            let hexKey = keyData.map { String(format: "%02hhx", $0) }.joined()
            
            guard let _ = try? keychain.set(hexKey, key: fileName) else {
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
            
            guard let _ = try? keyring.set(hexKey, for: fileName) else {
                return nil
            }
            return hexKey
        }
#endif
        return nil
    }
}

extension ManagedObjectContext {
    nonisolated public var identifier: ObjectIdentifier { ObjectIdentifier(self) }
}
