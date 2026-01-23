@MainActor
public protocol AnyQueryObserver: AnyObject {
    func appendAny(_ models: [AnyObject])
    func handleUpdate(_ model: any PersistentModel, matchedBeforeChange: Bool)
    nonisolated func doesMatch(_ model: any PersistentModel) -> Bool
    func remove(_ model: any PersistentModel) -> Void
    nonisolated var usedPredicate: AnyPredicateBuilder { get }
}

public protocol AnyPredicateBuilder {
    var hashValue: Int { get }
}

struct WeakQueryObserver {
    weak var query: (any AnyQueryObserver)?
}
