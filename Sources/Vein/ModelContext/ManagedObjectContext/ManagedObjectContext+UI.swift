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

    nonisolated func scheduleNotification<M: PersistentModel>(_ model: M) {
        pendingNotifications.mutate { notifications in
            notifications[M.typeIdentifier, default: []].append(model)
        }

        notificationTask.mutate { task in
            task?.cancel()
            task = Task {
                try? await Task.sleep(for: .milliseconds(50))
                await flushNotifications()
            }
        }
    }

    nonisolated func flushNotifications() async {
        await MainActor.run {
            pendingNotifications.mutate({ notifications in
                for (identifier, models) in notifications {
                    let observers = registeredQueries.value[identifier]

                    if let observers {
                        for (_, query) in observers {
                            if let query = query.query {
                                query.appendAny(models)
                            }
                        }
                    }
                }

                notifications.removeAll()
            })
        }
    }

    public func updateAfterCompletion(with block: () async -> Void) async {
        await block()
        await flushNotifications()
    }
}
