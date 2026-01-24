import Foundation

package typealias WriteCacheDictionary = [ObjectIdentifier: [ULID: any PersistentModel]]

extension ManagedObjectContext {
    /// A Boolean value that indicates whether the context has uncommitted changes.
    public var hasChanges: Bool {
        return writeCache.mutate { inserts, touches, deletes,_ in
            return !inserts.isEmpty || !touches.isEmpty || !deletes.isEmpty
        }
    }
    
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
    
    public nonisolated func insert<M: PersistentModel>(_ model: M) throws(ManagedObjectContextError) {
        guard model.context == nil else {
            throw MOCError.insertManagedModel(message: "raised by model of type '\(M.self)' with id \(model.id.ulidString)")
        }
        
        guard let _ = modelContainer.getSchema(for: model.typeIdentifier) else {
            throw MOCError.inactiveModelType(model)
        }
        
        model._setupFields()
        
        // An insert invalidates existing deletes and touches
        writeCache.mutate { inserts, touches, deletes,_ in
            inserts[
                model.typeIdentifier,
                default: [:]
            ][model.id] = model
            
            touches[
                model.typeIdentifier,
                default: [:]
            ][model.id] = nil
            
            deletes[
                model.typeIdentifier,
                default: [:]
            ][model.id] = nil
        }
        model.context = self
        
        identityMap.startTracking(model)
        
        scheduleNotification(model)
    }
    
    public nonisolated func _prepareForChange(of model: any PersistentModel) -> [Int] {
        writeCache.mutate { _,_,_, states in
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
            .compactMap {
                guard let query = $0.query else { return nil }
                return query.doesMatch(model) ? query.usedPredicate.hashValue: nil
            }
    }
    
    /// Registers the change on the context and updates Queries if necessary
    /// Only intended to be called by Fields
    public nonisolated func _markTouched(
        _ model: any PersistentModel,
        previouslyMatching predicateHashes: [Int]
    ) {
        writeCache.mutate { _, touches,_,_ in
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
    public nonisolated func delete<M: PersistentModel>(_ model: M) throws(ManagedObjectContextError) {
        guard model.context != nil else { return }
        guard let _ = modelContainer.getSchema(for: model.typeIdentifier) else {
            throw ManagedObjectContextError.inactiveModelType(model)
        }
        
        // Deletes automatically invalidate a touch or insert
        writeCache.mutate { inserts, touches, deletes,_ in
            deletes[
                model.typeIdentifier,
                default: [:]
            ][model.id] = model
            
            inserts[
                model.typeIdentifier,
                default: [:]
            ][model.id] = nil
            
            touches[
                model.typeIdentifier,
                default: [:]
            ][model.id] = nil
        }
        model.context = nil
        identityMap.remove(M.self, id: model.id)
        
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
    
    public nonisolated func batchDelete<M: PersistentModel>(_ models: [M]) throws(ManagedObjectContextError) {
        let managedModels = models.compactMap { $0.context != nil ? $0: nil }
        
        if let first = managedModels.first {
            guard let _ = modelContainer.getSchema(for: first.typeIdentifier) else {
                throw ManagedObjectContextError.inactiveModelType(first)
            }
        } else { return }
        
        // Deletes automatically invalidate a touch or insert
        writeCache.mutate { inserts, touches, deletes,_ in
            for model in managedModels {
                deletes[
                    model.typeIdentifier,
                    default: [:]
                ][model.id] = model
                
                inserts[
                    model.typeIdentifier,
                    default: [:]
                ][model.id] = nil
                
                touches[
                    model.typeIdentifier,
                    default: [:]
                ][model.id] = nil
                
                model.context = nil
                identityMap.remove(M.self, id: model.id)
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
    
    public nonisolated func save() throws {
        // Copies and clears the main storages
        // to enable background threads to keep making changes
        var insertsCopy = WriteCacheDictionary()
        var touchesCopy = WriteCacheDictionary()
        var deletesCopy = WriteCacheDictionary()
        
        writeCache.mutate { inserts, touches, deletes,_ in
            insertsCopy = inserts
            inserts.removeAll()
            
            touchesCopy = touches
            touches.removeAll()
            
            deletesCopy = deletes
            deletes.removeAll()
        }
        
        print(insertsCopy)
        print(touchesCopy)
        print(deletesCopy)
        
        try saveLock.withLock {
            stagingCache.mutate { inserts, touches, deletes,_ in
                inserts = insertsCopy
                touches = touchesCopy
                deletes = deletesCopy
            }
            
            do {
                try connection.safeTransaction {
                    // Delete first to avoid theoretically possible uniqueness problems
                    for (identifier, models) in deletesCopy {
                        guard let _ = modelContainer.getSchema(for: identifier) else {
                            throw ManagedObjectContextError.inactiveModelType(models.values.first!)
                        }
                        
                        for model in models.values {
                            try _writeDelete(model)
                        }
                    }
                    
                    for (identifier, models) in insertsCopy {
                        guard let _ = modelContainer.getSchema(for: identifier) else {
                            throw ManagedObjectContextError.inactiveModelType(models.values.first!)
                        }
                        
                        for model in models.values {
                            try _writeInsert(model)
                        }
                    }
                    
                    for (identifier, models) in touchesCopy {
                        guard let _ = modelContainer.getSchema(for: identifier) else {
                            throw ManagedObjectContextError.inactiveModelType(models.values.first!)
                        }
                        
                        for model in models.values {
                            try _writeUpdate(model)
                        }
                    }
                    
                }
            } catch {
                // Re-add changes in case of rollback
                writeCache.mutate { inserts, touches, deletes,_ in
                    insertsCopy.merge(into: &inserts)
                    touchesCopy.merge(into: &touches)
                    deletesCopy.merge(into: &deletes)
                }
                
                // Reset staging cache
                stagingCache.mutate { inserts, touches, deletes,_ in
                    inserts.removeAll()
                    touches.removeAll()
                    deletes.removeAll()
                }
                
                throw error
            }
            
            // Reset staging cache
            stagingCache.mutate { inserts, touches, deletes, primitiveStages in
                inserts.removeAll()
                touches.removeAll()
                deletes.removeAll()
                primitiveStages.removeAll()
            }
        }
    }
    
    /// Discards pending inserts and deletes, restores changed models to \
    /// their most recent committed state, and empties the undo stack.
    public nonisolated func rollback() {
        saveLock.withLock {
            stagingCache.mutate { inserts, touches, deletes,_ in
                inserts.removeAll()
                touches.removeAll()
                deletes.removeAll()
            }
            
            writeCache.mutate { inserts, touches, deletes, primitiveStates in
                for (identifier, models) in inserts {
                    for (_, model) in models {
                        model.context = nil
                        identityMap.remove(identifier, id: model.id)
                    }
                }
                
                for (identifier, models) in touches {
                    for (_, model) in models {
                        if let state = primitiveStates[
                            identifier,
                            default: [:]
                        ][model.id] {
                            model.applyPrimitiveState(state)
                        }
                    }
                }
                
                for (_, models) in deletes {
                    for (_, model) in models {
                        model.context = self
                        identityMap.startTracking(model)
                    }
                }
                
                primitiveStates.removeAll()
                inserts.removeAll()
                touches.removeAll()
                deletes.removeAll()
            }
        }
    }
}

extension WriteCacheDictionary {
    @inline(__always)
    nonisolated func merge(
        into source: inout WriteCacheDictionary
    ) {
        for (typeIdentifier, models) in self {
            source[typeIdentifier, default: [:]]
                .merge(models) { (current, new) in new }
        }
    }
}

package final class WriteCache: Sendable {
    private nonisolated(unsafe) var inserts = WriteCacheDictionary()
    private nonisolated(unsafe) var touches = WriteCacheDictionary()
    private nonisolated(unsafe) var deletes = WriteCacheDictionary()
    private nonisolated(unsafe) var primitiveState = [ObjectIdentifier: [ULID: PrimitiveState]]()
    
    private nonisolated let lock = NSLock()
    
    package nonisolated func mutate<R>(
        _ block: (
            _ inserts: inout WriteCacheDictionary,
            _ touches: inout WriteCacheDictionary,
            _ deletes: inout WriteCacheDictionary,
            _ primitiveState: inout [ObjectIdentifier: [ULID: PrimitiveState]]
        ) -> R
    ) -> R {
        lock.withLock {
            block(&inserts, &touches, &deletes, &primitiveState)
        }
    }
}
