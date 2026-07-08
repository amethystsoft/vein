// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

import Foundation
import Logging
// swiftling:disable multiple_closures_with_trailing_closure
@propertyWrapper
public final class _OneRelationship<T: PersistentModel>: OneRelationship, @unchecked Sendable {
    static var logger: Logger { .init(label: "Vein.OneRelationship") }

    public var isLazy: Bool { false }
    public typealias Value = T?
    public typealias WrappedType = ULID?

    private let lock = NSLock()
    private var idStore: ULID?
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
    /// It is not protected from other threads,
    /// because proper use cannot change it to something wrong
    public var _key: String?
    /// ONLY LET MACRO SET
    /// It is not protected from other threads,
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
        self.inverseKeyStore.value = inverse
        self.deleteRule = deleteRule
    }

    private func get(for id: ULID?) -> Value {
        guard let model, let context = model.context else { return nil }
        guard let id else { return nil }

        do {
            let result = try context.getModel(id: id, type: T.self)

            setObservers(on: result, id: id)

            return result
        } catch {
            if case .noSuchTable = error {
                return nil
            }
            if case .unexpectedlyEmptyResult = error {
                if context.modelContainer.logConfiguration.unexpectedlyEmptyResults {
                    Self.logger.warning("Unexpectedly empty result for \(T.self)")
                }
                return nil
            }
            fatalError(error.localizedDescription)
        }
    }

    private func setAndNotify(_ newValue: Value) {
        let newID = newValue?.id
        var previousID: ULID?

        VeinNotificationGuard.$isProcessing.withValue(true) {
            _withObservationNotification({ model?.notifyOfChanges() }) {
                lock.withLock {
                    previousID = idStore
                    idStore = newID
                }

                let isDifferent = previousID != newID

                if isDifferent {
                    // Disconnect from the old relation first while wrappedValue points to it.
                    updateOtherSide(isRemoving: true, id: previousID)
                }

                if isDifferent {
                    // Connect to the new relation now that wrappedValue points to it.
                    updateOtherSide(isRemoving: false, id: newID)
                }
            }
        }

        wasTouched = true
    }

    private func updateOtherSide(isRemoving: Bool, id: ULID?) {
        guard let model, let context = model.context else { return }

        lock.withLock {
            if _inverseKey == nil {
                _inverseKey = T._inverseFields[model.typeIdentifier]?[instanceKey]
            }
        }

        guard let target = get(for: id) else { return }
        target._observers.value.removeObserver(id: model.id, key: instanceKey)

        guard let _inverseKey else { return }
        if isRemoving {
            model._observers.value.removeObserver(id: target.id, key: _inverseKey)
        } else {
            setObservers(on: target, id: target.id)
        }

        target._setupFields()

        let predicateMatches = context._prepareForChange(of: target)

        let matchingField = target._fields.first { $0.key == _inverseKey }

        _withObservationNotification({ target.notifyOfChanges()}) {

            if var manyField = matchingField as? (any ManyRelationship) {
                if isRemoving {
                    manyField._persistableValue.removeAll { $0 == model.id }
                } else if !manyField._persistableValue.contains(model.id) {
                    manyField._persistableValue.append(model.id)
                }
                manyField.wasTouched = true
            } else if var oneField = matchingField as? (any OneRelationship) {
                oneField._persistableValue = isRemoving ? nil : model.id
                oneField.wasTouched = true
            }

            context._markTouched(target, previouslyMatching: predicateMatches)
        }
    }

    private func setObservers(on target: T?, id: ULID) {
        guard let model else { return }
        lock.withLock {
            if _inverseKey == nil {
                _inverseKey = T._inverseFields[model.typeIdentifier]?[instanceKey]
            }
        }

        target?._observers.value.addObserver(
            id: model.id,
            key: instanceKey,
            observer: { [weak model] in
                guard !VeinNotificationGuard.isProcessing else { return }
                VeinNotificationGuard.$isProcessing.withValue(true) {
                    model?.notifyOfChanges()
                }
            }
        )

        if let _inverseKey {
            model._observers.value.addObserver(
                id: id,
                key: _inverseKey,
                observer: { [weak target] in
                    guard !VeinNotificationGuard.isProcessing else { return }
                    VeinNotificationGuard.$isProcessing.withValue(true) {
                        target?.notifyOfChanges()
                    }
                }
            )
        }
    }

    public func _setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? ULID? else {
                fatalError(
                    ManagedObjectContextError
                        .capturedStateApplicationFailed(
                            ULID.self,
                            instanceKey
                        )
                        .localizedDescription
                )
            }
            self.idStore = value
            self._wasTouched = false
        }
    }

    public var _persistableValue: ULID? {
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
            let context = model.context
        else { return }

        lock.withLock {
            if _inverseKey == nil {
                _inverseKey = T._inverseFields[model.typeIdentifier]?[instanceKey]
            }
        }

        guard
            let _inverseKey,
            let target = wrappedValue
        else { return }

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
                            Self.logger
                                .error("An error occurred while cascading deletion: \(error)")
                        }
                    }
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
