import Foundation

@propertyWrapper
public nonisolated struct PrimaryKey: PersistedField, @unchecked Sendable {
    public typealias WrappedType = UUID?
    
    public let key: String? = "id"
    
    private let lock = NSLock()
    
    private var store: UUID?
    
    public var wrappedValue: UUID? {
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
    
    public init(wrappedValue: UUID?) {
        self.wrappedValue = wrappedValue
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
