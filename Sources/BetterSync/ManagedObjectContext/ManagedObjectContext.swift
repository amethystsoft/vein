import SQLite
import Foundation

@MainActor
public class ManagedObjectContext {
    public static var shared: ManagedObjectContext?
    public static var instance: ManagedObjectContext {
        guard let shared else {
            fatalError("ManagedObjectContext.shared not set")
        }
        return shared
    }
    package var connection: Connection
    
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
    
    public func createSchema(_ name: String) -> TableBuilder {
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
                    return switch $0.wrappedValue.asPersistentRepresentation.sqliteValue {
                        case .integer(let int):
                            Expression<Int64>($0.instanceKey) <- Expression<Int64>(value: int)
                        case .real(let double):
                            Expression<Double>($0.instanceKey) <- Expression<Double>(value: double)
                        case .text(let string):
                            Expression<String>($0.instanceKey) <- Expression<String>(value: string)
                        case .blob(let data):
                            Expression<Data>($0.instanceKey) <- Expression<Data>(value: data)
                        case .null:
                            switch SQLiteTypeName.notNull($0.wrappedValue.sqliteTypeName) {
                                case .integer:
                                    Expression<Int64?>($0.instanceKey) <- Expression<Int64?>(value: nil)
                                case .real:
                                    Expression<Double?>($0.instanceKey) <- Expression<Double?>(value: nil)
                                case .text:
                                    Expression<String?>($0.instanceKey) <- Expression<String?>(value: nil)
                                case .blob:
                                    Expression<Data?>($0.instanceKey) <- Expression<Data?>(value: nil)
                                default:
                                    fatalError("unexpectedly recieved SQLiteTypeName of null")
                            }
                    }
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
    
    public func update<T: Persistable>(field: LazyField<T>, newValue: T?) throws(ManagedObjectContextError) {
        do {
            guard let key = field.key else {
                if let model = field.model {
                    throw MOCError.keyMissing(message: "raised by schema \(model.getSchema()) on property of type '\(T.self)'")
                } else {
                    throw MOCError.keyMissing(message: "raised by unknown schema on property of type '\(T.self)'")
                }
            }
            guard let model = field.model else {
                throw ManagedObjectContextError.modelReference(message: "raised by field with property name '\(key)'")
            }
            guard let id = model.id else {
                throw MOCError.idMissing(message: "raised by model of Type '\(model.self)'")
            }
            let filtered = Table(model.getSchema()).filter(Expression<String>("id") == id.uuidString)
            
            if
                field.wrappedValue.asPersistentRepresentation is Int64,
                let representation = newValue.asPersistentRepresentation as? Int64
            {
                try connection.run(
                    filtered
                        .update(Expression<Int64>(key) <- representation)
                )
            }
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public func fetchAll<T: PersistentModel>(_ modelType: T.Type) throws(MOCError) -> [T] {
        do {
            let table = Table(modelType.schema)
            let helperModel = T()
            let eagerLoadedFields = helperModel.fields.eagerLoaded
            let select = table.select(distinct: eagerLoadedFields.map { $0.expressible })
            
            var models = [T]()
            
            for instance in try connection.prepare(select) {
                let model = T()
                for field in eagerLoadedFields {
                    if field.key == "id" {
                        let uuidString = instance[Expression<String>("id")]
                        model.id = UUID(uuidString: uuidString)!
                    }
                    model.context = self
                }
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
    
    public func fetchSingleProperty<T: Persistable>(field: LazyField<T>) throws(MOCError) -> T? {
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
}
