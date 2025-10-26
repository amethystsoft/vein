import SQLite
import Foundation

extension Connection: @unchecked Sendable {}

public actor ManagedObjectContext {
    public static nonisolated(unsafe) var shared: ManagedObjectContext?
    public static nonisolated(unsafe) var instance: ManagedObjectContext {
        guard let shared else {
            fatalError("ManagedObjectContext.shared not set")
        }
        return shared
    }
    package nonisolated let connection: Connection
    
    /// Connects to database at `path`, creates a new one if it doesn't exist
    init(path: String) throws(ManagedObjectContextError) {
        do {
            self.connection = try Connection(path)
        } catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    /// In memory only
    init() throws(ManagedObjectContextError) {
        do {
            self.connection = try Connection(.inMemory)
        } catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func createSchema(_ name: String) -> TableBuilder {
        return BetterSync.TableBuilder(self, named: name)
    }
    
    public func insert<M: PersistentModel>(_ model: M) throws(MOCError) {
        do {
            guard model.context == nil else {
                if let id = model.id {
                    throw MOCError.insertManagedModel(message: "raised by model of type '\(M.self)' with id \(id.uuidString)")
                } else {
                    throw MOCError.idMissing(message: "raised by model of Type '\(M.self)'")
                }
            }
            
            let table = Table(model.getSchema())
            try connection.transaction {
                try connection.run(table.insert(model.fields.map {
                    return $0.wrappedValue.asPersistentRepresentation.sqliteValue.setter(withKey: $0.instanceKey, andTypeName: $0.wrappedValue.sqliteTypeName)
                }))
                
                if
                    let row = try connection.pluck(table.order(Expression<Int64>("rowid").desc).limit(1)),
                    let id = UUID(uuidString: row[Expression<String>("id")])
                {
                    model.id = id
                    model.context = self
                } else {
                    throw MOCError.idAfterCreation(message: "raised by Model of Type '\(M.self)'")
                }
            }
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public func update(field: PersistedFieldDTO, newValue: SqliteValue) throws(ManagedObjectContextError) {
        do {
            let filtered = Table(field.schema).filter(Expression<String>("id") == field.id.uuidString)
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
    
    public nonisolated func fetchAll<T: PersistentModel>(_ modelType: T.Type) throws(MOCError) -> [T] {
        do {
            let table = Table(modelType.schema)
            let eagerLoadedFields = modelType.fieldInformation.eagerLoaded
            var fieldsToLoad = eagerLoadedFields.map { $0.expressible }
            fieldsToLoad.append(Expression<String>("id"))
            let select = table.select(distinct: fieldsToLoad)
            
            var models = [T]()
            
            for row in try connection.prepare(select) {
                var id = UUID(uuidString: row[Expression<String>("id")])!
                var fields = [String: SqliteValue]()
                
                for field in eagerLoadedFields {
                    fields[field.key] = SqliteValue(typeName: field.typeName, key: field.key, row: row)
                }
                
                let model = T(id: id, fields: fields)
                model.context = self
                models.append(model)
            }
            return models
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func fetchSingleProperty<T: Persistable>(field: LazyField<T>) throws(MOCError) -> T? {
        guard let key = field.key else {
            if let model = field.model {
                throw MOCError.keyMissing(message: "raised by schema \(model.getSchema()) on property of type '\(T.self)'")
            } else {
                throw MOCError.keyMissing(message: "raised by unknown schema on property of type '\(T.self)'")
            }
        }
        guard let model = field.model else { throw MOCError.modelReference(message: "raised by field with property name '\(key)'")}
        guard let id = model.id else {
            throw MOCError.idMissing(message: "raised by model of Type '\(model.self)'")
        }
        
        let table = Table(model.getSchema()).filter(Expression<String>("id") == id.uuidString)
        let select = table.select(distinct: [field.expressible]).limit(1)
        
        do {
            for row in try connection.prepare(select) {
                return try field.decode(row)
            }
            throw MOCError.unexpectedlyEmptyResult(message: "raised by field with property name '\(key)' of Model '\(T.self)' with id \(id.uuidString)")
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func updateDetached(field: PersistedField, newValue: Persistable) {
        let fieldDTO = field.asDTO()
        let valueDTO = newValue.sqliteValue
        Task {
            do {
                try await self.update(field: fieldDTO, newValue: valueDTO)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    package func run(_ query: String) throws {
        try connection.run(query)
    }
    
    package nonisolated func runDetached(_ query: String) {
        Task {
            do {
                await try self.run(query)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
}
