extension ManagedObjectContext {
    @MainActor
    public func getOrCreateQueryObserver(for identifier: ObjectIdentifier, _ key: Int, createWith block: @escaping () -> AnyQueryObserver) -> AnyQueryObserver {
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
                flushNotifications()
            }
        }
    }
    
    nonisolated func flushNotifications() {
        Task { @MainActor in
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
        flushNotifications()
    }
}
