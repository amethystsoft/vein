//
//  AnyQueryObserver.swift
//  BetterSync
//
//  Created by Mia Koring on 27.10.25.
//
@MainActor
public protocol AnyQueryObserver: AnyObject {
    func appendAny(_ models: [AnyObject])
    func handleUpdate(_ model: PersistentModel, matchedBeforeChange: Bool)
    func doesMatch(_ model: any PersistentModel) -> Bool
    func remove(_ model: any PersistentModel) -> Void
    var usedPredicate: AnyPredicateBuilder { get }
}

public protocol AnyPredicateBuilder {
    var hashValue: Int { get }
}

struct WeakQueryObserver {
    weak var query: AnyQueryObserver?
}
