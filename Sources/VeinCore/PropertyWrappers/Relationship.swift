import Foundation
import Vein

@propertyWrapper
public final class _OneRelationship<T: PersistentModel>: PersistedRelationship, @unchecked Sendable {
    public typealias Value = T?
    public typealias PersistableRepresentation = ULID?
    
    private let lock = NSLock()
    private var store: Value
    private var idStore: ULID?
    public var inverse: AnyKeyPath?
    public var deleteRule: DeleteRule
    
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
    
    // Pre insert: read from store
    // Post insert: read from idStore
    public var wrappedValue: Value {
        get {
            return lock.withLock { () -> Value in
                guard let context = model?.context else { return store }
                guard let id = idStore else { return nil }
                do {
                    let result = try context.getModel(id: id, type: T.self)
                    if inverse.isNil {
                        store = result
                    }
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
    
    public init(
        inverse: AnyKeyPath? = nil,
        deleteRule: DeleteRule = .nullify
    ) {
        self.key = nil
        self.store = nil
        self.idStore = nil
        self.inverse = inverse
        self.deleteRule = deleteRule
    }
    
    private func setAndNotify(_ newValue: Value) {
        lock.withLock {
            store = newValue
        }
        model?.notifyOfChanges()
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? T else {
                //fatalError(ManagedObjectContextError.capturedStateApplicationFailed(WrappedType.self, instanceKey).localizedDescription)
                return
            }
            self.store = value
            self.idStore = value.id
            self._wasTouched = false
        }
    }
    
    public var persistentRepresentation: PersistableRepresentation {
        get { idStore }
        set { idStore = newValue }
    }
}

@propertyWrapper
public final class _ManyRelationship<T: PersistentModel>: PersistedRelationship, @unchecked Sendable {
    public typealias Value = [T]
    public typealias PersistableRepresentation = [ULID]
    
    private let lock = NSLock()
    private var store: Value
    private var idStore: [ULID]
    public var inverse: AnyKeyPath?
    public var deleteRule: DeleteRule
    
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
    
    // Pre insert: read from store
    // Post insert: read from idStore
    public var wrappedValue: Value {
        get {
            return lock.withLock { () -> Value in
                guard let context = model?.context else { return store }
                guard !idStore.isEmpty else { return [] }
                do {
                    /*let result = try context.getModel(id: id, type: T.self)
                    if inverse.isNil {
                        store = result
                    }
                    return result*/return []
                } catch let error as ManagedObjectContextError {
                    if case .noSuchTable = error {
                        return []
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
    
    public init(
        inverse: AnyKeyPath? = nil,
        deleteRule: DeleteRule = .nullify
    ) {
        self.key = nil
        self.store = []
        self.idStore = []
        self.inverse = inverse
        self.deleteRule = deleteRule
    }
    
    private func setAndNotify(_ newValue: Value) {
        lock.withLock {
            store = newValue
        }
        model?.notifyOfChanges()
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? Value else {
                //fatalError(ManagedObjectContextError.capturedStateApplicationFailed(WrappedType.self, instanceKey).localizedDescription)
                return
            }
            self.store = value
            self.idStore = value.map(\.id)
            self._wasTouched = false
        }
    }
    
    public var persistentRepresentation: PersistableRepresentation {
        get { idStore }
        set { idStore = newValue }
    }
}

public enum DeleteRule {
    case nullify
    case cascade
}
