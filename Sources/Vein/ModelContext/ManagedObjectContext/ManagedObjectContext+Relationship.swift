import ULID
import SQLiteDB
import Foundation

extension ManagedObjectContext {
    nonisolated func getModel<T: PersistentModel>(id: ULID, type: T.Type) throws(MOCError) -> T? {
        if let model = identityMap.getTracked(type, id: id) {
            return model
        }
        return try self.fetchAll(
            ModelPredicate<T>(
                runtimeFilter: { model in model.id == id },
                sql: SQLExpression<String>("id") == SQLExpression(value: id.ulidString)
            )
        ).first
    }
    
    nonisolated func getModels<T: PersistentModel>(
        ids: [ULID],
        type: T.Type,
        requestingModel: any PersistentModel,
        fieldKey: String,
        inverseKey: String?
    ) throws(MOCError) -> [T] {
        var models = [ULID: T]()
        
        var identityMapMisses: [ULID] = []
        for id in ids {
            guard let model = identityMap.getTracked(type, id: id) else {
                identityMapMisses.append(id)
                continue
            }
            models[id] = model
        }
        
        if !identityMapMisses.isEmpty {
            let dbFetchedModels: [ULID: T] = try _fetchAllMatchingIDs(ids: identityMapMisses)
            models.merge(dbFetchedModels, uniquingKeysWith: { lhs, _ in lhs})
        }
        
        var sortedModels: [T] = []
        let isInMigration = isInActiveMigration.value
        for id in ids {
            if let target = models[id] {
                target._observers.value.addObserver(id: requestingModel.id, key: fieldKey, observer: {
                    guard !VeinNotificationGuard.isProcessing else { return }
                    VeinNotificationGuard.$isProcessing.withValue(true) {
                        requestingModel.notifyOfChanges()
                    }
                })
                if let inverseKey {
                    requestingModel._observers.value.addObserver(id: target.id, key: inverseKey, observer: { [weak target] in
                        guard !VeinNotificationGuard.isProcessing else { return }
                        VeinNotificationGuard.$isProcessing.withValue(true) {
                            target?.notifyOfChanges()
                        }
                    })
                }
                sortedModels.append(target)
            } else {
                if !isInMigration {
                    if modelContainer.logConfiguration.potentialDataCorruption {
                        Self.logger.warning(
                            "Relationship ID mismatch for \(T.self). Potential data corruption."
                        )
                    }
                } else {
                    if modelContainer.logConfiguration.potentialDataCorruptionInMigration {
                        Self.logger.info(
                            "[Migration] Relationship ID mismatch for \(T.self). Verify migration integrity if unexpected."
                        )
                    }
                }
            }
        }
        
        return sortedModels
    }
    
    private nonisolated func _fetchAllMatchingIDs<T: PersistentModel>(ids: [ULID]) throws(MOCError) -> [ULID: T] {
        do {
            let stringIDs = ids.map(\.ulidString)
            let table = Table(T.schema).filter(
                SQLExpression<Bool>(stringIDs.contains(SQLExpression<String>("id")))
            )
            let eagerLoadedFields = T._fieldInformation.eagerLoaded
            var fieldsToLoad = eagerLoadedFields.map { $0.fetchExpressible }
            fieldsToLoad.append(SQLExpression<String>("id"))
            let select = table.select(distinct: fieldsToLoad)
            
            if modelContainer.logConfiguration.sqlQueries {
                Self.logger.info(
                    "Fetching \(T.self) with \nQuery: \(select.expression.template)\nBindings:\(select.expression.bindings)"
                )
            }
            
            var models = [ULID: T]()
            
            var currentlyDeleted = [ULID: any PersistentModel]()
            var currentlyInserted = [ULID: any PersistentModel]()
            var currentlyTouched = [ULID: any PersistentModel]()
            
            writeCache.mutate { inserted, touched, deleted,_ in
                currentlyInserted = inserted[T.typeIdentifier] ?? [:]
                currentlyTouched = touched[T.typeIdentifier] ?? [:]
                currentlyDeleted = deleted[T.typeIdentifier] ?? [:]
            }
            
            let results = try connection.prepare(select)
            var resultIDs = Set<ULID>()
            
            try identityMap.batched { getTracked, startTracking in
                for row in results {
                    guard let id = ULID(ulidString: row[SQLExpression<String>("id")]) else {
                        throw MOCError.propertyDecode(message: """
                            Failed to decode id from row. DB may be corrupt.
                        """)
                    }
                    
                    if currentlyDeleted[id] != nil { continue }
                    
                    if let alreadyTrackedModel = getTracked(T.self, id) {
                        if ids.contains(alreadyTrackedModel.id) {
                            models[alreadyTrackedModel.id] = alreadyTrackedModel
                            resultIDs.insert(alreadyTrackedModel.id)
                        }
                        continue
                    }
                    var fields = [String: SQLiteValue]()
                    
                    for field in eagerLoadedFields {
                        fields[field.key] = SQLiteValue(typeName: field.typeName, key: field.key, row: row)
                    }
                    
                    let model = T(id: id, fields: fields)
                    model.context = self
                    models[model.id] = model
                    resultIDs.insert(model.id)
                    startTracking(model)
                }
            }
            
            for (_, insert) in currentlyInserted {
                if
                    !resultIDs.contains(insert.id),
                    let model = insert as? T,
                    ids.contains(model.id)
                { models[model.id] = model }
            }
            
            for (_, touch) in currentlyTouched {
                if
                    !resultIDs.contains(touch.id),
                    let model = touch as? T,
                    ids.contains(model.id)
                { models[model.id] = model }
            }
            
            return models
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
}
