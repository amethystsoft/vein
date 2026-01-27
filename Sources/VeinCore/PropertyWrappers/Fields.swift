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
    
    private var _wasTouched: Bool = false
    public private(set) var wasTouched: Bool {
        get {
            lock.withLock {
                _wasTouched
            }
        }
        set {
            lock.withLock {
                _wasTouched = newValue
            }
        }
    }
    
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
                } catch let error as ManagedObjectContextError {
                    if case .noSuchTable = error {
                        return nil
                    }
                    if case .unexpectedlyEmptyResult = error {
                        return store
                    }
                    fatalError(error.localizedDescription)
                } catch { fatalError(error.localizedDescription) }
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
            
            wasTouched = true
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
    
    private func setAndNotify(_ newValue: WrappedType) {
        lock.withLock {
            store = newValue
            readFromStore = true
        }
        model?.notifyOfChanges()
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? WrappedType else {
                fatalError(ManagedObjectContextError.capturedStateApplicationFailed(WrappedType.self, instanceKey).localizedDescription)
            }
            self.store = value
            self.readFromStore = false
            self._wasTouched = false
        }
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
    
    private var _wasTouched: Bool = false
    public private(set) var wasTouched: Bool {
        get {
            lock.withLock {
                _wasTouched
            }
        }
        set {
            lock.withLock {
                _wasTouched = newValue
            }
        }
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
            self.wasTouched = true
        }
    }
    
    public init(wrappedValue: T) {
        self.store = wrappedValue
        self.key = nil
    }
    
    // only called from inside setter during lock
    private func setAndNotify(_ newValue: WrappedType) {
        lock.withLock {
            store = newValue
        }
        model?.notifyOfChanges()
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? WrappedType else {
                fatalError(ManagedObjectContextError.capturedStateApplicationFailed(WrappedType.self, instanceKey).localizedDescription)
            }
            self.store = value
            self._wasTouched = false
        }
    }
}
