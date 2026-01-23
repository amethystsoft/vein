import Foundation

extension ManagedObjectContext {
    /// Returns all models matching the predicate.
    /// Returns [] if table doesn't exist
    public nonisolated func fetchAll<T: PersistentModel>(_ predicate: PredicateBuilder<T>) throws(MOCError) -> [T] {
        do {
            return try _fetchAll(predicate)
        } catch {
            switch error {
                case .noSuchTable:
                    return []
                default: throw error
            }
        }
    }
    
    /// Returns all models matching the predicate.
    /// Returns [] if table doesn't exist
    public nonisolated func fetchAll<T: PersistentModel>(_ modelType: T.Type) throws(MOCError) -> [T] {
        try fetchAll(modelType._PredicateHelper()._builder())
    }
    
    /// Registers an object to be inserted in the context’s persistent store the next time changes are saved.
    public nonisolated func insert<M: PersistentModel>(_ model: M) throws(ManagedObjectContextError) {
        guard model.context == nil else {
            throw MOCError.insertManagedModel(message: "raised by model of type '\(M.self)' with id \(model.id.ulidString)")
        }
        model._setupFields()
        model.context = self
        
        inserts.mutate { inserts in
            inserts[
                model.typeIdentifier,
                default: [:]
            ][model.id] = model
        }
        
        identityMap.startTracking(model, type: M.self, id: model.id)
        
        scheduleNotification(model)
    }
    
    /// Captures state of fields to make rollbacks possible
    /// Only intended to be called by Fields
    /// - Returns: hashes of Predicates matching the model before the change
    public nonisolated func _prepareForChange(of model: any PersistentModel) -> [Int] {
        primitiveState.mutate { states in
            if states[model.typeIdentifier, default: [:]][model.id] == nil {
                states[
                    model.typeIdentifier,
                    default: [:]
                ][model.id] = model.extractPrimitiveState()
            }
        }
        
        guard
            let observers = registeredQueries.value[model.typeIdentifier],
            !observers.isEmpty
        else { return [] }
        
        return observers.values
            .compactMap({ $0.query })
            .compactMap {
                $0.doesMatch(model) ? $0.usedPredicate.hashValue: nil
            }
    }
    
    /// Registers the change on the context and updates Queries if necessary
    /// Only intended to be called by Fields
    public nonisolated func _markTouched(
        _ model: any PersistentModel,
        previouslyMatching predicateHashes: [Int]
    ) {
        touches.mutate { touches in
            touches[
                model.typeIdentifier,
                default: [:]
            ][model.id] = model
        }
        
        guard
            let observers = registeredQueries.value[model.typeIdentifier],
            !observers.isEmpty
        else { return }
        
        Task { @MainActor in
            for query in observers.values.compactMap({ $0.query }) {
                query.handleUpdate(
                    model,
                    matchedBeforeChange: predicateHashes.contains(query.usedPredicate.hashValue)
                )
            }
        }
    }
    
    /// Specifies an object that should be removed from its persistent store when changes are committed.
    public nonisolated func delete(_ model: any PersistentModel) {
        guard model.context != nil else { return }
        
        deletes.mutate { deletes in
            deletes[
                model.typeIdentifier,
                default: [:]
            ][model.id] = model
        }
        
        guard
            let observers = registeredQueries.value[model.typeIdentifier],
            !observers.isEmpty
        else { return }
        
        let matchedBefore = observers.values
            .compactMap({ $0.query })
            .compactMap {
                $0.doesMatch(model) ? $0: nil
            }
        Task { @MainActor in
            for query in matchedBefore {
                query.remove(model)
            }
        }
    }
    
    public nonisolated func batchDelete<M: PersistentModel>(_ models: [M]) {
        let managedModels = models.compactMap { $0.context != nil ? $0: nil }
        
        deletes.mutate { deletes in
            for model in managedModels {
                deletes[
                    model.typeIdentifier,
                    default: [:]
                ][model.id] = model
            }
        }
        
        guard
            let observers = registeredQueries.value[ObjectIdentifier(M.self)],
            !observers.isEmpty
        else { return }
        
        var matchedBefore = [Int: [M]]()
        
        let queries = observers.values.compactMap({ $0.query })
        
        for observer in queries {
            matchedBefore[
                observer.usedPredicate.hashValue,
                default: []
            ] = managedModels.filter {
                observer.doesMatch($0)
            }
        }
        
        Task { @MainActor in
            for query in queries {
                for model in matchedBefore[query.usedPredicate.hashValue] ?? [] {
                    query.remove(model)
                }
            }
        }
    }
}
