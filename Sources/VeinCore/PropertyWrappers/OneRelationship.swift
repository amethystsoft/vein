import Foundation
import Vein
import Logging

@propertyWrapper
public final class _OneRelationship<T: PersistentModel>: OneRelationship, @unchecked Sendable {
    static var logger: Logger { .init(label: "Vein.OneRelationship") }
    
    public let isLazy: Bool = false
    public typealias Value = T?
    public typealias WrappedType = ULID?
    
    private let lock = NSLock()
    private var idStore: ULID?
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
                guard let context = model?.context else { return nil }
                guard let id = idStore else { return nil }
                do {
                    let result = try context.getModel(id: id, type: T.self)
                    return result
                } catch let error as ManagedObjectContextError {
                    if case .noSuchTable = error {
                        return nil
                    }
                    if case .unexpectedlyEmptyResult = error {
                        Self.logger.warning("Unexpectedly empty result for \(T.self)")
                        return nil
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
        }
    }
    
    public init(
        inverse: String? = nil,
        deleteRule: DeleteRule = .nullify
    ) {
        self.key = nil
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
            idStore = newID
        }
        
        if isDifferent {
            // Connect to the new relation now that wrappedValue points to it.
            updateOtherSide(isRemoving: false)
        }
        
        model?.notifyOfChanges()
        
        wasTouched = true
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
            target.notifyOfChanges()
        }
        
        if var manyField = matchingField as? (any ManyRelationship) {
            if isRemoving {
                manyField.persistableValue.removeAll { $0 == model.id }
            } else if !manyField.persistableValue.contains(model.id) {
                manyField.persistableValue.append(model.id)
            }
            manyField.wasTouched = true
        } else if var oneField = matchingField as? (any OneRelationship) {
            oneField.persistableValue = isRemoving ? nil : model.id
            oneField.wasTouched = true
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
            self.idStore = value.id
            self._wasTouched = false
        }
    }
    
    public var persistableValue: WrappedType {
        get { idStore }
        set { idStore = newValue }
    }
    
    /// Internal use only.
    ///
    /// Called by `context.delete(_:)`.
    public func _handleModelDeletion() {
        guard
            let model,
            let context = model.context,
            let inverseKey,
            let target = wrappedValue
        else { return }
        
        switch deleteRule {
            case .nullify:
                let predicateMatches = context._prepareForChange(of: target)
                defer {
                    target.notifyOfChanges()
                }
                
                let inverse = target._fields.first { $0.key == inverseKey }
                
                if var manyField = inverse as? (any ManyRelationship) {
                    manyField.persistableValue.removeAll(where: { $0 == model.id })
                } else if var oneField = inverse as? (any OneRelationship) {
                    oneField.persistableValue = nil
                }
                
                context._markTouched(target, previouslyMatching: predicateMatches)
            case .cascade:
                guard !target._isPreparedForDeletion else { return }
                do {
                    try context.delete(target)
                } catch {
                    Self.logger.error("An error occured while cascading deletion: \(error)")
                }
        }
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
