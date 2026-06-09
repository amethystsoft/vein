import Foundation
import Vein

@propertyWrapper
public final class _OneRelationship<T: PersistentModel>: PersistedRelationship, @unchecked Sendable {
    public typealias WrappedType = T
    public typealias PersistableRepresentation = ULID?
    
    private let lock = NSLock()
    private var store: WrappedType?
    private var idStore: ULID?
    private var inverse: String?
    
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
    public var wrappedValue: WrappedType? {
        get {
            return lock.withLock { () -> WrappedType? in
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
    
    public init(wrappedValue: T?) {
        self.key = nil
        self.store = wrappedValue
    }
    
    private func setAndNotify(_ newValue: WrappedType?) {
        lock.withLock {
            store = newValue
        }
        model?.notifyOfChanges()
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? WrappedType else {
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

