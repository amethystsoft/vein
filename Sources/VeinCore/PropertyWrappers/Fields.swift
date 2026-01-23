import Foundation
@_exported import Vein

@propertyWrapper
public final class LazyField<T: Persistable>: PersistedField, @unchecked Sendable {
    public typealias WrappedType = T?
    
    private let lock = NSLock()
    private var store: WrappedType
    private var readFromStore = false
    
    /// ONLY LET MACRO SET
    public var key: String?
    /// ONLY LET MACRO SET
    public weak var model: (any PersistentModel)?
    
    public var isLazy: Bool {
        true
    }
    
    public var wrappedValue: WrappedType {
        get {
            return lock.withLock { () -> WrappedType in
                if readFromStore {
                    return store
                }
                guard let context = model?.context else {
                    return store
                }
                do {
                    let result = try context._fetchSingleProperty(field: self)
                    store = result
                    readFromStore = true
                    return result
                } catch { fatalError(error.localizedDescription) }
            }
        }
        set {
            readFromStore = true
            
            guard
                let model = model,
                let context = model.context
            else { return setAndNotify(newValue) }
            
            let predicateMatches = context._prepareForChange(of: model)
            setAndNotify(newValue)
            context._markTouched(model, previouslyMatching: predicateMatches)
        }
    }
    
    /* TODO: add async fetch
    public func readAsynchronously() async throws -> T? {
        guard let context = model?.context else {
            return store
        }
        return try await context.fetchSingleProperty(field: self)
    }
    */
    
    public init(wrappedValue: T?) {
        self.key = nil
        self.store = wrappedValue
    }
    
    public func setValue(to newValue: T?) {
        self.store = newValue
        model?.notifyOfChanges()
    }
    
    public func setAndNotify(_ newValue: WrappedType) {
        lock.withLock {
            store = newValue
            model?.notifyOfChanges()
        }
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        guard let value = state as? WrappedType else {
            fatalError(ManagedObjectContextError.capturedStateApplicationFailed(WrappedType.self, instanceKey).localizedDescription)
        }
        self.store = value
    }
}

@propertyWrapper
public final class Field<T: Persistable>: PersistedField, @unchecked Sendable {
    public typealias WrappedType = T
    
    public var key: String?
    public weak var model: (any PersistentModel)?
    private let lock = NSLock()
    
    package var store: T
    
    public var isLazy: Bool {
        false
    }
    
    public var wrappedValue: T {
        get {
            return lock.withLock {
                return store
            }
        }
        set {
            guard
                let model = model,
                let context = model.context
            else { return setAndNotify(newValue) }
            
            let predicateMatches = context._prepareForChange(of: model)
            setAndNotify(newValue)
            context._markTouched(model, previouslyMatching: predicateMatches)
        }
    }
    
    public init(wrappedValue: T) {
        self.store = wrappedValue
        self.key = nil
    }
    
    public func setValue(to newValue: T) {
        self.store = newValue
        model?.notifyOfChanges()
    }
    
    public func setAndNotify(_ newValue: WrappedType) {
        lock.withLock {
            store = newValue
            model?.notifyOfChanges()
        }
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        guard let value = state as? WrappedType else {
            fatalError(ManagedObjectContextError.capturedStateApplicationFailed(WrappedType.self, instanceKey).localizedDescription)
        }
        self.store = value
    }
}
