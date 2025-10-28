//
//  AnyQueryObserver.swift
//  BetterSync
//
//  Created by Mia Koring on 27.10.25.
//
@MainActor
package protocol AnyQueryObserver: AnyObject {
    func appendAny(_ models: [AnyObject])
}

struct WeakQueryObserver {
    weak var query: AnyQueryObserver?
}
