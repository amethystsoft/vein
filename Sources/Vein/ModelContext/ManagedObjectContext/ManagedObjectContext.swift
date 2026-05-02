import SQLiteDB
import Foundation
import ULID
import Crypto
#if canImport(AppKit) || canImport(UIKit)
import KeychainAccess
#endif

public actor ManagedObjectContext {
    public static nonisolated(unsafe) var shared: ManagedObjectContext?
    public static nonisolated(unsafe) var instance: ManagedObjectContext {
        guard let shared else {
            fatalError("ManagedObjectContext.shared not set")
        }
        return shared
    }
    package nonisolated let connection: Connection
    nonisolated unowned let modelContainer: ModelContainer
    
    // MARK: - Migrations
    package nonisolated let isInActiveMigration = Atomic(false)
    
    // MARK: - In memory write caching and rollback
    package nonisolated let writeCache = WriteCache()
    
    package nonisolated let stagingCache = WriteCache()
    
    // Used in `ManagedObjectContext/save` to
    // make sure only one save is running at a time
    nonisolated let saveLock = NSLock()
    
    // MARK: - Ensure single row - single instance
    nonisolated(unsafe) let identityMap = ThreadSafeIdentityMap()
    
    // MARK: - UI change notification
    nonisolated let registeredQueries = Atomic(
        [ObjectIdentifier: [Int: WeakQueryObserver]]()
    )
    nonisolated let pendingNotifications = Atomic(
        [ObjectIdentifier: [AnyObject]]()
    )
    nonisolated let notificationTask = Atomic(Task<Void, Never>?.none)
    
    // MARK: - Initializers
    /// Connects to database at `path`, creates a new one if it doesn't exist
    init(
        path: String,
        modelContainer: ModelContainer
    ) throws(ManagedObjectContextError) {
        self.modelContainer = modelContainer
        do {
            self.connection = try Connection(path)
            
            #if canImport(AppKit) || canImport(UIKit)
            guard let key = Self.getKeyForDatabase(
                at: path,
                appID: modelContainer.appID
            ) else {
                fatalError("Vein: Failed to retrieve/save key to encrypt Database.")
            }
            try self.connection.key(key)
                
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
    
    public static func getKeyForDatabase(at path: String, appID: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        
        #if canImport(AppKit) || canImport(UIKit)
        let keychain = Keychain(service: "com.amethyst.vein.sqlcipher.\(appID)")
        
        if let key = keychain[fileName] {
            return key
        } else {
            let keyData = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
            let hexKey = keyData.map { String(format: "%02hhx", $0) }.joined()
            
            guard let _ = try? keychain.set(hexKey, key: fileName) else {
                return nil
            }
            return hexKey
        }
        #else
        return nil
        #endif
    }
}


