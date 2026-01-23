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
    
    func getTracked<T: PersistentModel>(_ type: T.Type, id: ULID) -> T? {
        get(type, id: id)
    }
    
    func getTrackedCount() -> Int {
        cache.value.reduce(0, { $0 + $1.value.count })
    }
    
    func startTracking<T: PersistentModel>(_ object: T, type: T.Type, id: ULID) {
        track(object, type: type, id: id)
    }
    
    func batched<T: PersistentModel>(
        _ block: (
            (T.Type, ULID) -> T?,
            (T, T.Type, ULID) -> Void
        ) -> Void
    ) {
        block(get, track)
    }
    
    @inline(__always)
    private func track<T: PersistentModel>(_ object: T, type: T.Type, id: ULID) {
        cache.mutate { cache in
            cache[Self.key(type), default: [:]][id] = WeakModel(wrappedValue: object)
        }
    }
    
    @inline(__always)
    private func get<T: PersistentModel>(_ type: T.Type, id: ULID) -> T? {
        cache.value[Self.key(type)]?[id]?.wrappedValue as? T
    }
    
    func remove<T: PersistentModel>(_ type: T.Type, id: ULID) {
        cache.mutate { contents in
            _ = contents[Self.key(type)]?.removeValue(forKey: id)
        }
    }
    
    @inline(__always)
    private static func key<T: PersistentModel>(_ type: T.Type) -> ObjectIdentifier {
        ObjectIdentifier(type)
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
