import SQLite
import ULID

extension ManagedObjectContext {
    private nonisolated func _writeInsert<M: PersistentModel>(_ model: M) throws(ManagedObjectContextError) {
        do {
            let table = Table(model._getSchema())
            try connection.safeTransaction {
                try connection.run(table.insert(model._fields.map {
                    return $0.wrappedValue.asPersistentRepresentation.sqliteValue.setter(withKey: $0.instanceKey, andTypeName: $0.wrappedValue.asPersistentRepresentation.sqliteTypeName)
                }))
            }
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
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
    
    private nonisolated func _writeUpdate(field: PersistedFieldDTO, newValue: SQLiteValue) throws(ManagedObjectContextError) {
        do {
            let filtered = Table(field.schema).filter(Expression<String>("id") == field.id.ulidString)
            try connection.run(
                filtered
                    .update(newValue.setter(withKey: field.key, andTypeName: field.sqliteType))
            )
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func _createSchema(_ name: String) -> TableBuilder {
        return Vein.TableBuilder(self, named: name)
    }
    
    private nonisolated func _writeDelete(_ model: any PersistentModel) throws(MOCError) {
        guard
            let _ = model.context
        else { return }
        let filter = Table(model._getSchema()).filter(Expression<String>("id") == model.id.ulidString)
        do {
            try connection.run(filter.delete())
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
        } catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    package nonisolated func run(_ query: String) throws(ManagedObjectContextError) {
        do {
            try connection.run(query)
        } catch let error as SQLite.Result {
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
