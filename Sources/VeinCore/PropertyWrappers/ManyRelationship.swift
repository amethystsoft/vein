import Foundation
import Vein
import Logging

@propertyWrapper
public final class _ManyRelationship<T: PersistentModel>: ManyRelationship, @unchecked Sendable {
    static var logger: Logger { .init(label: "Vein.ManyRelationship") }
    
    public typealias Value = [T]
    public typealias PersistableRepresentation = [ULID]
    
    public let isLazy: Bool = false
    private let lock = NSLock()
    var idStore: [ULID]
    public var inverseKey: String?
    public var deleteRule: DeleteRule
    
    /// ONLY LET MACRO SET
    public var key: String?
    /// ONLY LET MACRO SET
    public weak var model: (any PersistentModel)?
    
    private var _wasTouched: Bool = false
    public var wasTouched: Bool {
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
                guard let context = model?.context else { return [] }
                guard !idStore.isEmpty else { return [] }
                do {
                    let result = try context.getModels(ids: idStore, type: T.self)
                    return result
                } catch let error as ManagedObjectContextError {
                    if case .noSuchTable = error {
                        return []
                    }
                    if case .unexpectedlyEmptyResult = error {
                        Self.logger.warning("Unexpectedly empty result for \(T.self)")
                        return []
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
            
            let predicateMatches = context._prepareForChange(of: model)
            setAndNotify(newValue)
            context._markTouched(model, previouslyMatching: predicateMatches)
        }
    }
    
    public init(
        inverse: String? = nil,
        deleteRule: DeleteRule = .nullify
    ) {
        self.key = nil
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
            idStore = newValue.map(\.id)
        }
        
        updateOtherSide(removed: removed, added: added)
        model?.notifyOfChanges()
        
        wasTouched = true
    }
    
    private func updateOtherSide(removed: [T], added: [T]) {
        guard let model, let context = model.context, let inverseKey else { return }
        
        for target in removed {
            target._setupFields()
            let predicateMatches = context._prepareForChange(of: target)
            
            let matchingField = target._fields.first { $0.key == inverseKey }
            defer { matchingField?.model?.notifyOfChanges() }
            
            if var manyField = matchingField as? (any ManyRelationship) {
                manyField.persistableValue.removeAll { $0 == model.id }
                manyField.wasTouched = true
            } else if var oneField = matchingField as? (any OneRelationship) {
                if oneField.persistableValue == model.id {
                    oneField.persistableValue = nil
                }
                oneField.wasTouched = true
            }
            
            context._markTouched(target, previouslyMatching: predicateMatches)
        }
        
        for target in added {
            target._setupFields()
            let predicateMatches = context._prepareForChange(of: target)
            
            let matchingField = target._fields.first { $0.key == inverseKey }
            defer { target.notifyOfChanges() }
            
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
            
            if var manyField = matchingField as? (any ManyRelationship) {
                if !manyField.persistableValue.contains(model.id) {
                    manyField.persistableValue.append(model.id)
                }
                manyField.wasTouched = true
            } else if var oneField = matchingField as? (any OneRelationship) {
                oneField.persistableValue = model.id
                oneField.wasTouched = true
            }
            
            context._markTouched(target, previouslyMatching: predicateMatches)
        }
    }
    
    public func setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? [ULID] else {
                fatalError(
                    ManagedObjectContextError
                        .capturedStateApplicationFailed(
                            [ULID].self,
                            instanceKey
                        )
                        .localizedDescription
                )
            }
            self.idStore = value
            self._wasTouched = false
        }
    }
    
    public var persistableValue: PersistableRepresentation {
        get {
            lock.withLock {
                idStore
            }
        }
        set {
            lock.withLock {
                idStore = newValue
            }
        }
    }
    
    /// Internal use only.
    ///
    /// Called by `context.delete(_:)`.
    public func _handleModelDeletion() {
        guard
            let model,
            let context = model.context,
            let inverseKey
        else { return }
        
        for target in wrappedValue {
            switch deleteRule {
                case .nullify:
                    let predicateMatches = context._prepareForChange(of: target)
                    defer {
                        target.notifyOfChanges()
                    }
                    
                    let inverse = target._fields.first { $0.key == inverseKey }
                    
                    if var manyField = inverse as? (any ManyRelationship) {
                        manyField.persistableValue.removeAll(where: { $0 == model.id })
                        manyField.wasTouched = true
                    } else if var oneField = inverse as? (any OneRelationship) {
                        oneField.persistableValue = nil
                        oneField.wasTouched = true
                    }
                    
                    context._markTouched(target, previouslyMatching: predicateMatches)
                case .cascade:
                    guard !target._isPreparedForDeletion else { continue }
                    do {
                        try context.delete(target)
                    } catch {
                        Self.logger.error("An error occurred while cascading deletion: \(error)")
                    }
            }
        }
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
