import Foundation
import ULID

@propertyWrapper
public struct PrimaryKey: PersistedField, @unchecked Sendable {
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
            lock.withLock({
                store = newValue
            })
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
    
    public func setValue(to newValue: WrappedType) {}
    
    public func setStoreToCapturedState(_ state: Any) {}
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
