import Foundation

@propertyWrapper
public struct PrimaryKey: PersistedField, @unchecked Sendable {
    public typealias WrappedType = Int64?
    
    public let key: String? = "id"
    
    private let lock = NSLock()
    
    private var store: Int64?
    
    public var wrappedValue: Int64? {
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
    
    public weak var model: PersistentModel?
    
    public var projectedValue: PersistanceChecker {
        PersistanceChecker {
            self.model?.context != nil
        }
    }
    
    public init(wrappedValue: Int64?) {
        self.wrappedValue = wrappedValue
    }
    
    public func setValue(to newValue: WrappedType) {}
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
