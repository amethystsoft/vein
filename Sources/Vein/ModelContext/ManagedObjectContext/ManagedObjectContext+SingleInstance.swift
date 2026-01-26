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
    private var cache = Atomic([ObjectIdentifier: [ULID: WeakModel]]())
    
    func getAll<T: PersistentModel>(of type: T.Type) -> [T] {
        return
            cache
            .value[type.typeIdentifier]?
            .values
            .compactMap { $0.wrappedValue as? T } ?? []
    }
    
    func removeAll<T: PersistentModel>(of type: T.Type) {
        cache.mutate { value in
            value[type.typeIdentifier] = nil
        }
    }
    
    func getTracked<T: PersistentModel>(_ type: T.Type, id: ULID) -> T? {
        get(type.typeIdentifier, id: id)
    }
    
    func getTracked<T: PersistentModel>(_ type: ObjectIdentifier, id: ULID) -> T? {
        get(type, id: id)
    }
    
    func getTrackedCount() -> Int {
        cache.value.reduce(0, {
            $0 + $1.value.count(where: { _, value in
                !value.isDeallocated
            })
        })
    }
    
    func startTracking<T: PersistentModel>(_ object: T) {
        track(object)
    }
    
    func batched<T: PersistentModel>(
        _ block: (
            (T.Type, ULID) -> T?,
            (T) -> Void
        ) -> Void
    ) {
        block(getTracked, track)
    }
    
    @inline(__always)
    private func track<T: PersistentModel>(_ object: T) {
        cache.mutate { cache in
            cache[object.typeIdentifier, default: [:]][object.id] = WeakModel(wrappedValue: object)
        }
    }
    
    @inline(__always)
    private func get<T: PersistentModel>(_ type: ObjectIdentifier, id: ULID) -> T? {
        cache.value[type]?[id]?.wrappedValue as? T
    }
    
    func remove<T: PersistentModel>(_ type: T.Type, id: ULID) {
        remove(T.typeIdentifier, id: id)
    }
    
    func remove(_ type: ObjectIdentifier, id: ULID) {
        cache.mutate { contents in
            _ = contents[type]?.removeValue(forKey: id)
        }
    }
    
    func compact() {
        cache.mutate { cache in
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
