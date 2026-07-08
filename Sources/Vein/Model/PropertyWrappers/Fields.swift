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
// swiftlint:disable multiple_closures_with_trailing_closure

/// A lazy loaded field of a ``PersistentModel``.
///
/// Fetches the data on first use, then holds it. Good for bigger data like images or long strings.
@propertyWrapper
public final class LazyField<T: Persistable>: PersistedField, @unchecked Sendable {
    public typealias WrappedType = T?

    private let lock = NSLock()
    private var store: WrappedType
    @_spi(VeinTesting) public var testingStoreSnapshot: WrappedType {
        lock.withLock { store }
    }
    private var readFromStore = false

    /// ONLY LET MACRO SET
    public var _key: String?
    /// ONLY LET MACRO SET
    public weak var _model: (any PersistentModel)?

    @_spi(VeinTesting) public let suppressUIUpdates: Bool

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
            // Fast path: already loaded
            let (alreadyRead, cachedValue) = lock.withLock { (readFromStore, store) }
            if alreadyRead {
                return cachedValue
            }

            guard let context = model?.context else {
                return lock.withLock { store }
            }
            do {
                let result = try context._fetchSingleProperty(field: self)
                lock.withLock {
                    store = result
                    readFromStore = true
                }
                return result
            } catch {
                return lock.withLock {
                    readFromStore = false
                    if case .noSuchTable = error {
                        return nil
                    }
                    if case .unexpectedlyEmptyResult = error {
                        return store
                    }
                    fatalError(error.localizedDescription)
                }
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

    public init(wrappedValue: T? = nil, suppressUIUpdates: Bool = false) {
        self.store = wrappedValue
        self.suppressUIUpdates = suppressUIUpdates
    }

    private func setAndNotify(_ newValue: WrappedType) {
        _withObservationNotification {
            if !suppressUIUpdates {
                model?.notifyOfChanges()
            }
        } block: {
            lock.withLock {
                store = newValue
                readFromStore = true
            }
        }
    }

    public func _setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? WrappedType else {
                fatalError(ManagedObjectContextError.capturedStateApplicationFailed(
                    WrappedType.self,
                    instanceKey
                ).localizedDescription)
            }
            self.store = value
            self.readFromStore = false
            self._wasTouched = false
        }
    }

    public var _persistableValue: T? {
        get { wrappedValue }
        set { wrappedValue = newValue }
    }

    // Connect model instance to wrapper.
    public static subscript<OuterSelf: PersistentModel>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, T?>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, LazyField<T>>
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

/// An eager loaded field of a ``PersistentModel``.
///
/// Gets automatically applied by the `@Model` macro to all stored vars without a different Field.
/// You can also apply it yourself for explicitness.
@propertyWrapper
public final class Field<T: Persistable>: PersistedField, @unchecked Sendable {
    public typealias WrappedType = T

    public var _key: String?
    public weak var _model: (any PersistentModel)?
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
    }

    // Notifies before or after the locked store mutation depending on `callBeforeChange`;
    // notification always runs outside the lock to avoid callback deadlocks.
    private func setAndNotify(_ newValue: WrappedType) {
        _withObservationNotification({ model?.notifyOfChanges() }) {
            lock.withLock {
                store = newValue
            }
        }
    }

    public func _setStoreToCapturedState(_ state: Any) {
        lock.withLock {
            guard let value = state as? WrappedType else {
                fatalError(ManagedObjectContextError.capturedStateApplicationFailed(
                    WrappedType.self,
                    instanceKey
                ).localizedDescription)
            }
            self.store = value
            self._wasTouched = false
        }
    }

    public var _persistableValue: T {
        get { wrappedValue }
        set { wrappedValue = newValue }
    }

    // Connect model instance to wrapper.
    public static subscript<OuterSelf: PersistentModel>(
        _enclosingInstance observed: OuterSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<OuterSelf, T>,
        storage storageKeyPath: ReferenceWritableKeyPath<OuterSelf, Field<T>>
    ) -> T {
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
