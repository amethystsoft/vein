import SQLiteDB
import ULID

extension ManagedObjectContext {
    nonisolated func _writeInsert<M: PersistentModel>(_ model: M) throws(ManagedObjectContextError) {
        do {
            let table = Table(model._getSchema())
            let values = model._fields.map {
                return $0
                    .persistableValue
                    .asPersistentRepresentation
                    .sqliteSetter(key: $0.instanceKey)
            }
            
            let insert = table.insert(values)
            
            if modelContainer.logConfiguration.sqlQueries {
                Self.logger.info(
                    "Inserting \(M.self) with \nQuery: '\(insert.expression.template)'\nBindings:\(insert.expression.bindings)"
                )
            }
            
            try connection.run(insert)
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            let parsed = error.parse()
            switch parsed {
                case .noSuchTable:
                    try model.migrate(in: self)
                    
                    // Safe under the assumtion that migrate would throw
                    // if it failed to create the table.
                    // Every other error thrown by insert would break the loop
                    try _writeInsert(model)
                default: throw parsed
            }
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    nonisolated func _writeUpdate<M: PersistentModel>(_ model: M) throws(ManagedObjectContextError) {
        do {
            let filtered = Table(model._getSchema()).filter(SQLExpression<String>("id") == model.id.ulidString)
            
            let query = filtered
                .update(
                    model._fields
                        .filter { $0.wasTouched }
                        .map {
                            $0.persistableValue
                                .asPersistentRepresentation
                                .sqliteSetter(key: $0.instanceKey)
                        }
                )
            
            if modelContainer.logConfiguration.sqlQueries {
                Self.logger.info(
                    "Updating \(M.self) with \nQuery: '\(query.expression.template)'\nBindings:\(query.expression.bindings)"
                )
            }
            
            try connection.run(
                query
            )
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    nonisolated func _createSchema(_ name: String) -> TableBuilder {
        return Vein.TableBuilder(self, named: name)
    }
    
    nonisolated func _writeDelete(_ model: any PersistentModel) throws(MOCError) {
        let filter = Table(model._getSchema()).filter(SQLExpression<String>("id") == model.id.ulidString)
        let query = filter.delete()
        
        if modelContainer.logConfiguration.sqlQueries {
            Self.logger.info(
                "Deleting \(model._getSchema()) with \nQuery: '\(query.expression.template)'\nBindings:\(query.expression.bindings)"
            )
        }
        
        do {
            try connection.run(query)
            model.context = nil
            
            Task { @MainActor in
                let observers = registeredQueries.value[model.typeIdentifier]
                
                guard let observers else { return }
                
                var matchedBefore = [AnyQueryObserver]()
                
                for (_, query) in observers {
                    guard let query = query.query else { continue }
                    
                    if query.doesMatch(model) {
                        matchedBefore.append(query)
                    }
                }
                
                for query in matchedBefore {
                    query.remove(model)
                }
            }
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    package nonisolated func run(_ query: String) throws(ManagedObjectContextError) {
        if modelContainer.logConfiguration.sqlQueries {
            Self.logger.info(
                "Running query '\(query)'"
            )
        }
        do {
            try connection.run(query)
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    package nonisolated func runDetached(_ query: String) {
        Task {
            do {
                try self.run(query)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
}
