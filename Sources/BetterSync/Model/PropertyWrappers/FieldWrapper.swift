import Foundation

@MainActor
@propertyWrapper
public struct Field<T: Persistable> {
    public typealias WrappedType = T
    
    public var key: String?
    public weak var context: ManagedObjectContext?
    public weak var model: PersistentModel?
    
    private var store: T
    
    public var wrappedValue: T {
        get {
            store
        }
        set {
            store = newValue
        }
    }
    
    public init(wrappedValue: T, context: ManagedObjectContext? = nil) {
        self.context = context
        self.store = wrappedValue
        self.key = nil
    }
}
