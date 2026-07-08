import Foundation
import ULID

extension ManagedObjectContext {
    public nonisolated var trackedObjectCount: Int {
        identityMap.getTrackedCount()
    }

    public nonisolated func compactIdentityMap() {
        identityMap.compact()
    }
}

nonisolated final class ThreadSafeIdentityMap {
    private let lock = NSLock()
    private var cache = [ObjectIdentifier: [ULID: WeakModel]]()

    func getAll<T: PersistentModel>(of type: T.Type) -> [T] {
        return lock.withLock {
            cache[type.typeIdentifier]?
                .values
                .compactMap { $0.wrappedValue as? T } ?? []
        }
    }

    func removeAll<T: PersistentModel>(of type: T.Type) {
        lock.withLock {
            cache[type.typeIdentifier] = nil
        }
    }

    func getTracked<T: PersistentModel>(_ type: T.Type, id: ULID) -> T? {
        lock.withLock {
            get(type.typeIdentifier, id: id)
        }
    }

    func getTracked<T: PersistentModel>(_ type: ObjectIdentifier, id: ULID) -> T? {
        lock.withLock {
            get(type, id: id)
        }
    }

    func getTrackedCount() -> Int {
        lock.withLock {
            cache.reduce(0, {
                $0 + $1.value.count(where: { _, value in
                    !value.isDeallocated
                })
            })
        }
    }

    func startTracking<T: PersistentModel>(_ object: T) {
        lock.withLock {
            cache[object.typeIdentifier, default: [:]][object.id] = WeakModel(wrappedValue: object)
        }
    }

    func batched<T: PersistentModel>(
        _ block: (
            (T.Type, ULID) -> T?,
            (T) -> Void
        ) throws -> Void
    ) rethrows {
        try lock.withLock {
            try block(
                { type, id in self.get(type.typeIdentifier, id: id) },
                { object in self.track(object) }
            )
        }
    }

    private func track<T: PersistentModel>(_ object: T) {
        cache[object.typeIdentifier, default: [:]][object.id] = WeakModel(wrappedValue: object)
    }

    private func get<T: PersistentModel>(_ type: ObjectIdentifier, id: ULID) -> T? {
        cache[type]?[id]?.wrappedValue as? T
    }

    func remove<T: PersistentModel>(_ type: T.Type, id: ULID) {
        remove(T.typeIdentifier, id: id)
    }

    func remove(_ type: ObjectIdentifier, id: ULID) {
        lock.withLock {
            _ = cache[type]?.removeValue(forKey: id)
        }
    }

    func compact() {
        lock.withLock {
            for (type, var references) in cache {
                references = references.filter { _, box in !box.isDeallocated }
                if references.isEmpty {
                    cache.removeValue(forKey: type)
                } else {
                    cache[type] = references
                }
            }
        }
    }
}

private struct WeakModel {
    weak var wrappedValue: AnyObject?
    var isDeallocated: Bool { wrappedValue.isNil }

    init(wrappedValue: AnyObject? = nil) {
        self.wrappedValue = wrappedValue
    }
}
