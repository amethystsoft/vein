import Foundation
import Logging
// swiftlint:disable multiple_closures_with_trailing_closure
@propertyWrapper
public final class _ManyRelationship<T: PersistentModel>: ManyRelationship, @unchecked Sendable {
    static var logger: Logger { .init(label: "Vein.ManyRelationship") }
    
    public typealias Value = [T]
    public typealias PersistableRepresentation = [ULID]
    
    public var isLazy: Bool { false }
    private let lock = NSLock()
    @_spi(VeinTesting) public var idStore = [ULID]()
    private let inverseKeyStore = Mutex<String?>(nil)
    public var _inverseKey: String? {
        get {
            inverseKeyStore.value
        }
        set {
            inverseKeyStore.value = newValue
        }
    }
    public let deleteRule: DeleteRule
    
    /// ONLY LET MACRO SET
    /// it is not protected from other threads,
    /// because proper use cannot change it to something wrong
    public var _key: String?
    /// ONLY LET MACRO SET
    /// it is not protected from other threads,
    /// because proper use cannot change it to something wrong
    public weak var _model: (any PersistentModel)?
    
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
            get(for: lock.withLock { idStore })
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
        self.inverseKeyStore.value = inverse
        self.deleteRule = deleteRule
    }
    
    private func get(for ids: [ULID]) -> Value {
        guard let model, let context = model.context else { return [] }
        guard !ids.isEmpty else { return [] }
        
        if _inverseKey.isNil {
            _inverseKey = T._inverseFields[model.typeIdentifier]?[instanceKey]
        }
        
        do {
            let result = try context.getModels(ids: ids, type: T.self, requestingModel: model, fieldKey: instanceKey, inverseKey: _inverseKey)
            return result
        } catch {
            if case .noSuchTable = error {
                return []
            }
            if case .unexpectedlyEmptyResult = error {
                if context.modelContainer.logConfiguration.unexpectedlyEmptyResults {
                    Self.logger.warning("Unexpectedly empty result for \(T.self)")
                }
                return []
            }
            
            fatalError(error.localizedDescription)
        }
    }
    
    private func setAndNotify(_ newValue: Value) {
        var oldIDs = [ULID]()
        let newIDs = newValue.map(\.id)
        
        _withObservationNotification {
            if !VeinNotificationGuard.isProcessing {
                VeinNotificationGuard.$isProcessing.withValue(true) {
                    model?.notifyOfChanges()
                }
            }
        } block: {
            lock.withLock {
                oldIDs = idStore
                idStore = newIDs
            }
            
            let oldValue = get(for: oldIDs)
            
            let removed = oldValue.filter { !newIDs.contains($0.id) }
            let added = newValue.filter { !oldIDs.contains($0.id) }
            
            updateOtherSide(removed: removed, added: added)
            
            wasTouched = true
        }
    }
    
    private func updateOtherSide(removed: [T], added: [T]) {
        guard let model, let context = model.context else { return }
        
        if _inverseKey.isNil {
            _inverseKey = T._inverseFields[model.typeIdentifier]?[instanceKey]
        }
        
        for target in removed {
            target._observers.value.removeObserver(id: model.id, key: instanceKey)

            guard let _inverseKey else {
                continue
            }
            model._observers.value.removeObserver(id: target.id, key: _inverseKey)
            
            target._setupFields()
            let predicateMatches = context._prepareForChange(of: target)
            
            let matchingField = target._fields.first { $0.key == _inverseKey }
            
            _withObservationNotification({ matchingField?.model?.notifyOfChanges() }) {
                if var manyField = matchingField as? (any ManyRelationship) {
                    manyField._persistableValue.removeAll { $0 == model.id }
                    manyField.wasTouched = true
                } else if var oneField = matchingField as? (any OneRelationship) {
                    if oneField._persistableValue == model.id {
                        oneField._persistableValue = nil
                    }
                    oneField.wasTouched = true
                }
                
                context._markTouched(target, previouslyMatching: predicateMatches)
            }
        }
        
        for target in added {
            setObservers(on: target, id: target.id)
            
            guard let _inverseKey else {
                continue
            }
            
            target._setupFields()
            let predicateMatches = context._prepareForChange(of: target)
            
            let matchingField = target._fields.first { $0.key == _inverseKey }
            
            _withObservationNotification {
                if !VeinNotificationGuard.isProcessing {
                    VeinNotificationGuard.$isProcessing.withValue(true) {
                        target.notifyOfChanges()
                    }
                }
            } block: {
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
                    if !manyField._persistableValue.contains(model.id) {
                        manyField._persistableValue.append(model.id)
                    }
                    manyField.wasTouched = true
                } else if var oneField = matchingField as? (any OneRelationship) {
                    oneField._persistableValue = model.id
                    oneField.wasTouched = true
                }
                
                context._markTouched(target, previouslyMatching: predicateMatches)
            }
        }
    }
    
    private func setObservers(on target: T?, id: ULID) {
        guard let model else { return }
        lock.withLock {
            if _inverseKey == nil {
                _inverseKey = T._inverseFields[model.typeIdentifier]?[instanceKey]
            }
        }
        
        target?._observers.value.addObserver(id: model.id, key: instanceKey, observer: { [weak model] in
            guard !VeinNotificationGuard.isProcessing else { return }
            VeinNotificationGuard.$isProcessing.withValue(true) {
                model?.notifyOfChanges()
            }
        })
        
        if let _inverseKey {
            model._observers.value.addObserver(id: id, key: _inverseKey, observer: { [weak target] in
                guard !VeinNotificationGuard.isProcessing else { return }
                VeinNotificationGuard.$isProcessing.withValue(true) {
                    target?.notifyOfChanges()
                }
            })
        }
    }
    
    public func _setStoreToCapturedState(_ state: Any) {
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
    
    public var _persistableValue: PersistableRepresentation {
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
            let _inverseKey
        else { return }
        
        for target in wrappedValue {
            _withObservationNotification({ target.notifyOfChanges() }) {
                switch deleteRule {
                    case .nullify:
                        let predicateMatches = context._prepareForChange(of: target)
                        
                        let inverse = target._fields.first { $0.key == _inverseKey }
                        
                        if var manyField = inverse as? (any ManyRelationship) {
                            manyField._persistableValue.removeAll(where: { $0 == model.id })
                            manyField.wasTouched = true
                        } else if var oneField = inverse as? (any OneRelationship) {
                            oneField._persistableValue = nil
                            oneField.wasTouched = true
                        }
                        
                        context._markTouched(target, previouslyMatching: predicateMatches)
                    case .cascade:
                        guard !target._isPreparedForDeletion else { return }
                        do {
                            try context.delete(target)
                        } catch {
                            if context.modelContainer.logConfiguration.errorWhileCascadeDeletion {
                                Self.logger.error("An error occurred while cascading deletion: \(error)")
                            }
                        }
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
            var storage = observed[keyPath: storageKeyPath]
            storage.lock.withLock {
                if storage.model == nil {
                    storage.model = observed
                }
            }
            return storage.wrappedValue
        }
        set {
            var storage = observed[keyPath: storageKeyPath]
            storage.lock.withLock {
                if storage.model == nil {
                    storage.model = observed
                }
            }
            storage.wrappedValue = newValue
        }
    }
}
