/// A type arased QueryObserver. Just an implementation detail.
@MainActor
public protocol AnyQueryObserver: AnyObject {
    func appendAny(_ models: [AnyObject])
    func handleUpdate(_ model: any PersistentModel, matchedBeforeChange: Bool)
    nonisolated func doesMatch(_ model: any PersistentModel) -> Bool
    func remove(_ model: any PersistentModel)
    nonisolated var usedPredicate: any AnyPredicateBuilder { get }
}
/// A type erased PredicateBuilder, an implementation detail.
public protocol AnyPredicateBuilder: Hashable {}

struct WeakQueryObserver {
    weak var query: (any AnyQueryObserver)?
}
