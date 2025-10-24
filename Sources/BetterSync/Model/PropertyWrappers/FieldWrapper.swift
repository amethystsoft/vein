import Foundation

@MainActor
@propertyWrapper
public class LazyField<T: Persistable>: PersistedField {
    public typealias WrappedType = T
    
    public var key: String?
    public weak var context: ManagedObjectContext?
    public weak var model: PersistentModel?
    
    package var store: T
    
    public var wrappedValue: T {
        get {
            if let context {
                return store
            } else {
                return store
            }
        }
        set {
            if let context {
                
            } else {
                store = newValue
            }
        }
    }
    
    public init(wrappedValue: T, context: ManagedObjectContext? = nil) {
        self.context = context
        self.store = wrappedValue
        self.key = nil
    }
}
