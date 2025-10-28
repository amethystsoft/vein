import SQLite
import Foundation

extension Connection: @unchecked Sendable {}

public typealias ModelContext = ManagedObjectContext
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
    
    public func insertInBackground<M: PersistentModel>(_ model: M) throws(MOCError) {
        do {
            guard model.context == nil else {
                if let id = model.id {
                    throw MOCError.insertManagedModel(message: "raised by model of type '\(M.self)' with id \(id)")
                } else {
                    throw MOCError.idMissing(message: "raised by model of Type '\(M.self)'")
                }
            }
            
            let table = Table(model.getSchema())
            try connection.transaction {
                try connection.run(table.insert(model.fields.map {
                    return $0.wrappedValue.asPersistentRepresentation.sqliteValue.setter(withKey: $0.instanceKey, andTypeName: $0.wrappedValue.asPersistentRepresentation.sqliteTypeName)
                }))
                
                if
                    let row = try connection.pluck(table.order(Expression<Int64>("rowid").desc).limit(1))
                {
                    model.id = row[Expression<Int64>("id")]
                    model.context = self
                } else {
                    throw MOCError.idAfterCreation(message: "raised by Model of Type '\(M.self)'")
                }
                identityMap.startTracking(model, type: M.self, id: model.id!)
            }
            scheduleActorNotification(model)
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    @MainActor
    public func insert<M: PersistentModel>(_ model: M) throws(MOCError) {
        do {
            guard model.context == nil else {
                if let id = model.id {
                    throw MOCError.insertManagedModel(message: "raised by model of type '\(M.self)' with id \(id)")
                } else {
                    throw MOCError.idMissing(message: "raised by model of Type '\(M.self)'")
                }
            }
            
            let table = Table(model.getSchema())
            try connection.transaction {
                try connection.run(table.insert(model.fields.map {
                    return $0.wrappedValue.asPersistentRepresentation.sqliteValue.setter(withKey: $0.instanceKey, andTypeName: $0.wrappedValue.asPersistentRepresentation.sqliteTypeName)
                }))
                
                if
                    let row = try connection.pluck(table.order(Expression<Int64>("rowid").desc).limit(1))
                {
                    model.id = row[Expression<Int64>("id")]
                    model.context = self
                } else {
                    throw MOCError.idAfterCreation(message: "raised by Model of Type '\(M.self)'")
                }
                identityMap.startTracking(model, type: M.self, id: model.id!)
            }
            scheduleNotification(model)
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public func update(field: PersistedFieldDTO, newValue: SQLiteValue) throws(ManagedObjectContextError) {
        do {
            let filtered = Table(field.schema).filter(Expression<Int64>("id") == field.id)
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
            let results = try connection.prepare(select)
            identityMap.batched { getTracked, startTracking in
                for row in results {
                    var id = row[Expression<Int64>("id")]
                    
                    if let alreadyTrackedModel = getTracked(T.self, id) {
                        models.append(alreadyTrackedModel)
                        continue
                    }
                    var fields = [String: SQLiteValue]()
                    
                    for field in eagerLoadedFields {
                        fields[field.key] = SQLiteValue(typeName: field.typeName, key: field.key, row: row)
                    }
                    
                    let model = T(id: id, fields: fields)
                    model.context = self
                    models.append(model)
                    startTracking(model, T.self, id)
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
    
    public nonisolated func fetchSingleProperty<Field: PersistedField>(field: Field) throws(MOCError) -> Field.WrappedType.PersistentRepresentation {
        typealias T = Field.WrappedType
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
        
        let table = Table(model.getSchema()).filter(Expression<Int64>("id") == id)
        let select = table.select(distinct: [field.expressible]).limit(1)
        
        do {
            for row in try connection.prepare(select) {
                return try field.decode(row)
            }
            throw MOCError.unexpectedlyEmptyResult(message: "raised by field with property name '\(key)' of Model '\(T.self)' with id \(id)")
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func updateDetached(field: PersistedField, newValue: Persistable) {
        let fieldDTO = field.asDTO()
        let valueDTO = newValue.asPersistentRepresentation.sqliteValue
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
    
    @MainActor
    private var registeredQueries = [String: AnyQueryObserver]()
    
    @MainActor
    public func getOrCreateQueryObserver(_ key: String, createWith block: @escaping () -> AnyQueryObserver) -> AnyQueryObserver {
        if let observer = registeredQueries[key] {
            return observer
        }
        let newObserver = block()
        registeredQueries[key] = newObserver
        print("registered new observer")
        return newObserver
    }
    
    @MainActor
    private var pendingNotifications: [String: [AnyObject]] = [:]
    
    @MainActor
    private var notificationTask: Task<Void, Never>?
    
    private nonisolated(unsafe) var pendingActorNotifications: [String: [AnyObject]] = [:]
    private var actorNotificationTask: Task<Void, Never>?
    
    private func scheduleActorNotification<M: PersistentModel>(_ model: M) {
        let key = "\(M.self)"
        pendingActorNotifications[key, default: []].append(model)
    }
    
    @MainActor
    private func flushActorNotifications() async {
        let notifications = await pendingActorNotifications
        pendingActorNotifications.removeAll()
        for (key, models) in notifications {
            if let query = registeredQueries[key] as? AnyQueryObserver {
                query.appendAny(models)
            }
        }
    }
    
    @MainActor
    private func scheduleNotification<M: PersistentModel>(_ model: M) {
        let key = "\(M.self)"
        pendingNotifications[key, default: []].append(model)
        notificationTask?.cancel()
        notificationTask = Task {
            try? await Task.sleep(for: .milliseconds(10))
            flushNotifications()
        }
    }
    
    @MainActor
    private func flushNotifications() {
        let notifications = pendingNotifications
        pendingNotifications.removeAll()
        for (key, models) in notifications {
            if let query = registeredQueries[key] as? AnyQueryObserver {
                query.appendAny(models)
            }
        }
    }
    
    private nonisolated(unsafe) var identityMap = ThreadSafeIdentityMap()
    
    public func updateAfterCompletion(with block: () async -> Void) async {
        await block()
        await flushActorNotifications()
    }
    
    public func batchInsert<M: PersistentModel>(_ models: [M]) async throws {
        for model in models {
            try insertInBackground(model)
        }
        await flushActorNotifications()
    }
    
    public func insertAndFlush<M: PersistentModel>(_ model: M) async throws {
        try insertInBackground(model)
        await flushActorNotifications()
    }
    
    public nonisolated var trackedObjectCount: Int {
        identityMap.getTrackedCount()
    }
}

private nonisolated final class ThreadSafeIdentityMap {
    private let lock = NSLock()
    private var cache: [ObjectIdentifier: [Int64: WeakModel]] = [:]
    
    func getTracked<T: PersistentModel>(_ type: T.Type, id: Int64) -> T? {
        lock.withLock {
            get(type, id: id)
        }
    }
    
    func getTrackedCount() -> Int {
        lock.withLock {
            cache.reduce(0, { $0 + $1.value.count })
        }
    }
    
    func startTracking<T: PersistentModel>(_ object: T, type: T.Type, id: Int64) {
        lock.withLock {
            track(object, type: type, id: id)
        }
    }
    
    func batched<T: PersistentModel>(
        _ block: (
            (T.Type, Int64) -> T?,
            (T, T.Type, Int64) -> Void
        ) -> Void
    ) {
        lock.withLock {
            block(get, track)
        }
    }
    
    @inline(__always)
    private func track<T: PersistentModel>(_ object: T, type: T.Type, id: Int64) {
        cache[Self.key(type), default: [:]][id] = WeakModel(wrappedValue: object)
    }
    
    @inline(__always)
    private func get<T: PersistentModel>(_ type: T.Type, id: Int64) -> T? {
        cache[Self.key(type)]?[id] as? T
    }
    
    func remove<T: PersistentModel>(_ type: T.Type, id: Int64) {
        lock.withLock {
            cache[Self.key(type)]?.removeValue(forKey: id)
        }
    }
    
    @inline(__always)
    private static func key<T: PersistentModel>(_ type: T.Type) -> ObjectIdentifier {
        ObjectIdentifier(type)
    }
}

private struct WeakModel {
    private weak var wrappedValue: AnyObject?
    
    init(wrappedValue: AnyObject? = nil) {
        self.wrappedValue = wrappedValue
    }
}
