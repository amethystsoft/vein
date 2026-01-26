import SQLite
import Foundation
import ULID

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
            try self.connection.execute("PRAGMA journal_mode=WAL;")
        } catch let error as SQLite.Result {
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
        } catch let error as SQLite.Result {
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
}


