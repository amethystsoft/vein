import Foundation
import Vein
import Logging

@propertyWrapper
public final class _OneRelationship<T: PersistentModel>: PersistedRelationship, OneRelationship, @unchecked Sendable {
    public let isLazy: Bool = false
    public typealias Value = T?
    public typealias WrappedType = ULID?
    
    private let lock = NSLock()
    private var store: Value {
        didSet {
            idStore = store?.id
        }
    }
    private var idStore: ULID? {
        didSet {
            _wasTouched = true
        }
    }
    public var inverseKey: String?
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
            else {
                fatalError("""
                Relationships require a context for setting. \
                Insert the model before adding relationships.
                """)
            }
            
            do {
                if
                    let newValue,
                    newValue.context.isNil
                {
                    try context.insert(newValue)
                } else if
                    let newValue,
                    newValue.context?.identifier != context.identifier
                {
                    fatalError("""
                Tried set model from different context as relationship. \
                Schema: \(model._getSchema())
                """)
                }
            } catch {
                fatalError(error.localizedDescription)
            }
            
            let predicateMatches = context._prepareForChange(of: model)
            setAndNotify(newValue)
            context._markTouched(model, previouslyMatching: predicateMatches)
            
            wasTouched = true
        }
    }
    
    public init(
        inverse: String? = nil,
        deleteRule: DeleteRule = .nullify
    ) {
        self.key = nil
        self.store = nil
        self.idStore = nil
        self.inverseKey = inverse
        self.deleteRule = deleteRule
    }
    
    private func setAndNotify(_ newValue: Value) {
        let newID = newValue?.id
        let isDifferent = idStore != newID
        
        if isDifferent {
            // Disconnect from the old relation first while wrappedValue points to it.
            updateOtherSide(isRemoving: true)
        }
        
        lock.withLock {
            if (model?.context).isNil {
                store = newValue
            } else {
                idStore = newID
            }
        }
        
        if isDifferent {
            // Connect to the new relation now that wrappedValue points to it.
            updateOtherSide(isRemoving: false)
        }
        
        model?.notifyOfChanges()
    }
    
    private func updateOtherSide(isRemoving: Bool) {
        guard
            let model,
            let context = model.context,
            let inverseKey,
            let target = wrappedValue
        else { return }
        
        target._setupFields()
        
        let predicateMatches = context._prepareForChange(of: target)
        
        let matchingField = target._fields.first { $0.key == inverseKey }
        
        defer {
            matchingField?.model?.notifyOfChanges()
        }
        
        if var manyField = matchingField as? ManyRelationship {
            if isRemoving {
                manyField.persistableValue.removeAll { $0 == model.id }
            } else if !manyField.persistableValue.contains(model.id) {
                manyField.persistableValue.append(model.id)
            }
        } else if var oneField = matchingField as? OneRelationship {
            oneField.persistableValue = isRemoving ? nil : model.id
        }
        
        context._markTouched(target, previouslyMatching: predicateMatches)
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? T else {
                fatalError(
                    ManagedObjectContextError
                        .capturedStateApplicationFailed(
                            ULID.self,
                            instanceKey
                        )
                        .localizedDescription
                )
            }
            self.store = value
            self.idStore = value.id
            self._wasTouched = false
        }
    }
    
    public var persistableValue: WrappedType {
        get { idStore }
        set { idStore = newValue }
    }
    
    // Connect model instance to wrapper.
    public static subscript<OuterSelf: PersistentModel>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, T?>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, _OneRelationship<T>>
    ) -> T? {
        get {
            let storage = observed[keyPath: storageKeyPath]
            if storage.model == nil {
                storage.model = observed
            }
            return storage.wrappedValue
        }
        set {
            let storage = observed[keyPath: storageKeyPath]
            if storage.model == nil {
                storage.model = observed
            }
            storage.wrappedValue = newValue
        }
    }
}

@propertyWrapper
public final class _ManyRelationship<T: PersistentModel>: PersistedRelationship, ManyRelationship, @unchecked Sendable {
    public typealias Value = [T]
    public typealias PersistableRepresentation = [ULID]
    
    public let isLazy: Bool = false
    private let lock = NSLock()
    private var store: Value {
        didSet {
            idStore = store.map(\.id)
        }
    }
    var idStore: [ULID] {
        didSet {
            _wasTouched = true
        }
    }
    public var inverseKey: String?
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
                    let result = try context.getModels(ids: idStore, type: T.self)
                    return result
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
            else {
                print("many: model: \(String(describing: model)), context: \(String(describing: model?.context))")
                fatalError("""
                Relationships require a context for setting. \
                Insert the model before adding relationships.
                """)
            }
            
            let predicateMatches = context._prepareForChange(of: model)
            setAndNotify(newValue)
            context._markTouched(model, previouslyMatching: predicateMatches)
            
            wasTouched = true
        }
    }
    
    public init(
        inverse: String? = nil,
        deleteRule: DeleteRule = .nullify
    ) {
        self.key = nil
        self.store = []
        self.idStore = []
        self.inverseKey = inverse
        self.deleteRule = deleteRule
    }
    
    private func setAndNotify(_ newValue: Value) {
        let oldValue = wrappedValue
        
        let oldIDs = Set(oldValue.map(\.id))
        let newIDs = Set(newValue.map(\.id))
        
        let removed = oldValue.filter { !newIDs.contains($0.id) }
        let added = newValue.filter { !oldIDs.contains($0.id) }
        
        lock.withLock {
            if (model?.context).isNil {
                store = newValue
            } else {
                idStore = newValue.map(\.id)
            }
        }
        
        updateOtherSide(removed: removed, added: added)
        model?.notifyOfChanges()
    }
    
    private func updateOtherSide(removed: [T], added: [T]) {
        guard let model, let context = model.context, let inverseKey else { return }
        
        for target in removed {
            target._setupFields()
            let predicateMatches = context._prepareForChange(of: target)
            
            let matchingField = target._fields.first { $0.key == inverseKey }
            defer { matchingField?.model?.notifyOfChanges() }
            
            if var manyField = matchingField as? ManyRelationship {
                manyField.persistableValue.removeAll { $0 == model.id }
            } else if var oneField = matchingField as? OneRelationship {
                if oneField.persistableValue == model.id {
                    oneField.persistableValue = nil
                }
            }
            
            context._markTouched(target, previouslyMatching: predicateMatches)
        }
        
        for target in added {
            target._setupFields()
            let predicateMatches = context._prepareForChange(of: target)
            
            let matchingField = target._fields.first { $0.key == inverseKey }
            defer { matchingField?.model?.notifyOfChanges() }
            
            do {
                if target.context.isNil {
                    try context.insert(target)
                } else if target.context?.identifier != context.identifier {
                    fatalError("""
                Tried set model from different context as relationship. \
                Schema: \(model._getSchema())
                """)
                }
            } catch {
                fatalError(error.localizedDescription)
            }
            
            if var manyField = matchingField as? ManyRelationship {
                if !manyField.persistableValue.contains(model.id) {
                    manyField.persistableValue.append(model.id)
                }
            } else if var oneField = matchingField as? OneRelationship {
                oneField.persistableValue = model.id
            }
            
            context._markTouched(target, previouslyMatching: predicateMatches)
        }
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? Value else {
                fatalError(
                    ManagedObjectContextError
                        .capturedStateApplicationFailed(
                            [ULID].self,
                            instanceKey
                        )
                        .localizedDescription
                )
            }
            self.store = value
            self.idStore = value.map(\.id)
            self._wasTouched = false
        }
    }
    
    public var persistableValue: PersistableRepresentation {
        get { idStore }
        set { idStore = newValue }
    }
    
    // Connect model instance to wrapper.
    public static subscript<OuterSelf: PersistentModel>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, [T]>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, _ManyRelationship<T>>
    ) -> [T] {
        get {
            let storage = observed[keyPath: storageKeyPath]
            if storage.model == nil {
                storage.model = observed
            }
            return storage.wrappedValue
        }
        set {
            let storage = observed[keyPath: storageKeyPath]
            if storage.model == nil {
                storage.model = observed
            }
            storage.wrappedValue = newValue
        }
    }
}

public enum DeleteRule {
    case nullify
    case cascade
}
