import Foundation

@MainActor
@propertyWrapper
public class LazyField<T: Persistable>: PersistedField {
    public typealias WrappedType = T?
    
    public var key: String?
    public weak var model: PersistentModel?
    
    package var store: T?
    
    public var isLazy: Bool {
        true
    }
    
    public static var sqliteTypeName: SQLiteTypeName {
        T.sqliteTypeName
    }
    
    public var wrappedValue: T? {
        get {
            if let store {
                return store
            }
            if let context = model?.context {
                do {
                    let result = try context.fetchSingleProperty(field: self)
                    store = result
                    return result
                } catch { fatalError(error.localizedDescription) }
            }
            return nil
        }
        set {
            if let context = model?.context {
                do {
                    try context.update(field: self, newValue: newValue)
                } catch {
                    fatalError(error.localizedDescription)
                }
                store = newValue
            } else {
                store = newValue
            }
        }
    }
    
    public init(wrappedValue: T?) {
        self.store = wrappedValue
        self.key = nil
    }
}
