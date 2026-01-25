import SQLite
import ULID

extension ManagedObjectContext {
    /// Returns all models matching the predicate.
    public nonisolated func _fetchAll<T: PersistentModel>(_ predicate: PredicateBuilder<T>) throws(MOCError) -> [T] {
        do {
            let table = Table(T.schema).filter(predicate.finalize())
            let eagerLoadedFields = T._fieldInformation.eagerLoaded
            var fieldsToLoad = eagerLoadedFields.map { $0.expressible }
            fieldsToLoad.append(Expression<String>("id"))
            let select = table.select(distinct: fieldsToLoad)
            var models = [T]()
            
            var currentlyDeleted = [ULID: any PersistentModel]()
            
            writeCache.mutate { _,_, deleted,_ in
                currentlyDeleted = deleted[T.typeIdentifier] ?? [:]
            }
            
            let results = try connection.prepare(select)
            var resultIDs = Set<ULID>()
            
            identityMap.batched { getTracked, startTracking in
                for row in results {
                    let id = ULID(ulidString: row[Expression<String>("id")])!
                    
                    if let _ = currentlyDeleted[id] { continue }
                    
                    if let alreadyTrackedModel = getTracked(T.self, id) {
                        models.append(alreadyTrackedModel)
                        resultIDs.insert(alreadyTrackedModel.id)
                        continue
                    }
                    var fields = [String: SQLiteValue]()
                    
                    for field in eagerLoadedFields {
                        fields[field.key] = SQLiteValue(typeName: field.typeName, key: field.key, row: row)
                    }
                    
                    let model = T(id: id, fields: fields)
                    model.context = self
                    models.append(model)
                    resultIDs.insert(model.id)
                    startTracking(model)
                }
            }
            
            var currentlyInserted = [ULID: any PersistentModel]()
            
            writeCache.mutate { inserted,_,_,_ in
                currentlyInserted = inserted[T.typeIdentifier] ?? [:]
            }
            
            for (_, insert) in currentlyInserted {
                if
                    !resultIDs.contains(insert.id),
                    let model = insert as? T,
                    predicate.doesMatch(model)
                {
                    models.append(model)
                }
            }
            
            return models
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func _fetchSingleProperty<Field: PersistedField>(field: Field) throws(MOCError) -> Field.WrappedType.PersistentRepresentation {
        typealias T = Field.WrappedType
        guard let key = field.key else {
            if let model = field.model {
                throw MOCError.keyMissing(message: "raised by schema \(model._getSchema()) on property of type '\(T.self)'")
            } else {
                throw MOCError.keyMissing(message: "raised by unknown schema on property of type '\(T.self)'")
            }
        }
        guard let model = field.model else { throw MOCError.modelReference(message: "raised by field with property name '\(key)'")}
        
        let table = Table(model._getSchema()).filter(Expression<String>("id") == model.id.ulidString)
        let select = table.select(distinct: [field.expressible]).limit(1)
        
        do {
            for row in try connection.prepare(select) {
                return field.decode(row)
            }
            throw MOCError.unexpectedlyEmptyResult(message: "raised by field with property name '\(key)' of Model '\(T.self)' with id \(model.id.ulidString)")
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func getAllStoredSchemas() throws -> [String] {
        let tables = try connection.schema.objectDefinitions(type: .table)
        return tables.map { $0.name }.filter {
            [
                MigrationTable.schema
            ].contains($0) == false &&
            !$0.starts(with: "sqlite_")
        }
    }
    
    public nonisolated func getNonEmptySchemas() throws -> [String] {
        let tables = try connection.schema.objectDefinitions(type: .table)
        let filtered = tables.map { $0.name }.filter {
            [
                MigrationTable.schema
            ].contains($0) == false &&
            !$0.starts(with: "sqlite_")
        }
        
        var nonEmpty = [String]()
        for table in filtered {
            if try connection.scalar(Table(table).count) > 0 {
                nonEmpty.append(table)
            }
        }
        
        return nonEmpty
    }
}
