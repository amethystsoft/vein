import ULID
import SQLiteDB
import Foundation

public typealias VeinObserver = (id: ULID, block: () -> Void)

extension ManagedObjectContext {
    public nonisolated func getModel<T: PersistentModel>(id: ULID, type: T.Type) throws(MOCError) -> T? {
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
    
    public nonisolated func getModels<T: PersistentModel>(ids: [ULID], type: T.Type, observer: VeinObserver) throws(MOCError) -> [T] {
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
        for id in ids {
            if let model = models[id] {
                model._observers.value[observer.id] = observer.block
                sortedModels.append(model)
            } else {
                Self.logger.warning("""
                    Mismatch between Relationship IDs and existing models. \
                    Potential data corruption.
                """)
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
            var fieldsToLoad = eagerLoadedFields.map { $0.expressible }
            fieldsToLoad.append(SQLExpression<String>("id"))
            let select = table.select(distinct: fieldsToLoad)
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
