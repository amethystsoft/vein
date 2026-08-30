// ===----------------------------------------------------------------------===
//
// This source file is part of the Amethyst Vein open source project
//
// Copyright (c) 2026 Mia Koring.
//
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.
//
// ===----------------------------------------------------------------------===

extension ManagedObjectContext {
    /// This is an implementation detail to support compatibility with arbitrary UI frameworks like SwiftUI or SwiftCrossUI with `@Query`.
    @MainActor
    public func getOrCreateQueryObserver(
        for identifier: ObjectIdentifier,
        _ key: String,
        createWith block: @escaping () -> AnyQueryObserver
    ) -> AnyQueryObserver {
        if let observer = registeredQueries.value[identifier]?[key]?.query {
            return observer
        }
        let newObserver = block()
        registeredQueries.mutate { queries in
            queries[identifier, default: [:]][key] = WeakQueryObserver(query: newObserver)
        }
        return newObserver
    }
}
