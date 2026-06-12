import Foundation
import ULID
import Logging

@propertyWrapper
public class PrimaryKey: PersistedField, @unchecked Sendable {
    static let logger = Logger(label: "Vein PrimaryKey")
    public typealias WrappedType = ULID
    
    public let key: String? = "id"
    
    private let lock = NSLock()
    
    private var store: ULID
    
    public var wasTouched = false
    
    /// Only set during migrations to preserve old ID
    /// Must be set before inserting new Model into context
    public var wrappedValue: ULID {
        get {
            lock.withLock({
                return store
            })
        }
        set {
            lock.withLock {
                if model?.context == nil {
                    store = newValue
                } else {
                    PrimaryKey.logger.warning("""
                    Attempted to mutate ID of inserted model with ID: \(store). \
                    This is not supported.
                    """)
                }
            }
        }
    }
    
    public var isLazy: Bool {
        false
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        UUID.sqliteTypeName
    }
    
    public weak var model: (any PersistentModel)?
    
    public var projectedValue: PersistanceChecker {
        PersistanceChecker {
            self.model?.context != nil
        }
    }
    
    public init(wrappedValue: ULID = ULID()) {
        self.store = wrappedValue
    }
    
    /// No-op: Primary key is immutable after insertion and doesn't participate in rollback.
    public func setStoreToCapturedState(_ state: Any) {}
    
    public var persistableValue: ULID {
        get { self.wrappedValue }
        set { self.wrappedValue = newValue }
    }
    
    // Connect model instance to wrapper.
    public static subscript<OuterSelf: PersistentModel>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, ULID>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, PrimaryKey>
    ) -> ULID {
        get {
            let storage = observed[keyPath: storageKeyPath]
            storage.lock.withLock {
                if storage.model == nil {
                    storage.model = observed
                }
            }
            return storage.wrappedValue
        }
        set {
            let storage = observed[keyPath: storageKeyPath]
            storage.lock.withLock {
                if storage.model == nil {
                    storage.model = observed
                }
            }
            storage.wrappedValue = newValue
        }
    }
}


public struct PersistanceChecker {
    private let getPersistanceState: () -> Bool
    package init(getPersistanceState: @escaping () -> Bool) {
        self.getPersistanceState = getPersistanceState
    }
    public var isPersisted: Bool {
        getPersistanceState()
    }
}
