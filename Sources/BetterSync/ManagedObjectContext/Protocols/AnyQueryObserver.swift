//
//  AnyQueryObserver.swift
//  BetterSync
//
//  Created by Mia Koring on 27.10.25.
//
@MainActor
package protocol AnyQueryObserver: AnyObject {
    func appendAny(_ models: [AnyObject])
    func handleUpdate(_ model: PersistentModel, matchedBeforeChange: Bool)
    func doesMatch(_ model: any PersistentModel) -> Bool
    var usedPredicate: AnyPredicateBuilder { get }
}

package protocol AnyPredicateBuilder {
    var hashValue: Int { get }
}

struct WeakQueryObserver {
    weak var query: AnyQueryObserver?
}
