import SQLite
import Foundation

extension Connection: @unchecked @retroactive Sendable {}

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
            try self.connection.execute("PRAGMA journal_mode=WAL;")
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
            
            let table = Table(model._getSchema())
            try connection.transaction {
                try connection.run(table.insert(model._fields.map {
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
            
            let table = Table(model._getSchema())
            try connection.transaction {
                try connection.run(table.insert(model._fields.map {
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
    
    public nonisolated func fetchAll<T: PersistentModel>(_ predicate: PredicateBuilder<T>) throws(MOCError) -> [T] {
        do {
            let table = Table(T.schema).filter(predicate.finalize())
            let eagerLoadedFields = T._fieldInformation.eagerLoaded
            var fieldsToLoad = eagerLoadedFields.map { $0.expressible }
            fieldsToLoad.append(Expression<String>("id"))
            let select = table.select(distinct: fieldsToLoad)
            var models = [T]()
            let results = try connection.prepare(select)
            identityMap.batched { getTracked, startTracking in
                for row in results {
                    let id = row[Expression<Int64>("id")]
                    
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
                throw MOCError.keyMissing(message: "raised by schema \(model._getSchema()) on property of type '\(T.self)'")
            } else {
                throw MOCError.keyMissing(message: "raised by unknown schema on property of type '\(T.self)'")
            }
        }
        guard let model = field.model else { throw MOCError.modelReference(message: "raised by field with property name '\(key)'")}
        guard let id = model.id else {
            throw MOCError.idMissing(message: "raised by model of Type '\(model.self)'")
        }
        
        let table = Table(model._getSchema()).filter(Expression<Int64>("id") == id)
        let select = table.select(distinct: [field.expressible]).limit(1)
        
        do {
            for row in try connection.prepare(select) {
                return field.decode(row)
            }
            throw MOCError.unexpectedlyEmptyResult(message: "raised by field with property name '\(key)' of Model '\(T.self)' with id \(id)")
        } catch let error as ManagedObjectContextError { throw error }
        catch let error as SQLite.Result {
            throw error.parse()
        } catch {
            throw .other(message: error.localizedDescription)
        }
    }
    
    public nonisolated func updateDetached<F: PersistedField>(field: F, newValue: F.WrappedType) {
        let fieldDTO = field.asDTO()
        let valueDTO = newValue.asPersistentRepresentation.sqliteValue
        
        Task {
            do {
                // 1. Persist to SQLite (Actor-isolated)
                try await self.update(field: fieldDTO, newValue: valueDTO)
                
                // 2. get copy of registered queries in a threadsafe way
                let observers = registeredQueries.value[fieldDTO.enclosingObjectID]
                
                // 3. If no one is watching, just update the model reference and exit
                guard let observers, !observers.isEmpty else {
                    field.setValue(to: newValue)
                    return
                }
                
                // 4. If there are observers, move to MainActor for both
                // the state change AND the UI notification to ensure consistency.
                await MainActor.run {
                    guard let model = field.model else { return }
                    
                    // Determine matches BEFORE updating the value
                    var matchedBefore = Set<Int>()
                    for query in observers.values.compactMap({ $0.query }) {
                        if query.doesMatch(model) {
                            matchedBefore.insert(query.usedPredicate.hashValue)
                        }
                    }
                    
                    // Update the actual model value on the Main Thread
                    // to prevent races with the UI/SwiftUI.
                    field.setValue(to: newValue)
                    
                    // Notify observers
                    for query in observers.values.compactMap({ $0.query }) {
                        query.handleUpdate(
                            model,
                            matchedBeforeChange: matchedBefore.contains(query.usedPredicate.hashValue)
                        )
                    }
                }
            } catch {
                fatalError("Database update failed: \(error.localizedDescription)")
            }
        }
    }
    
    public nonisolated func delete(_ model: any PersistentModel) throws(MOCError) {
        guard
            let _ = model.context,
            let id = model.id
        else { return }
        let filter = Table(model._getSchema()).filter(Expression<Int64>("id") == id)
        do {
            try connection.run(filter.delete())
            model.context = nil
            model.id = nil
            
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

    
    package func run(_ query: String) throws {
        try connection.run(query)
    }
    
    package nonisolated func runDetached(_ query: String) {
        Task {
            do {
                try await self.run(query)
            } catch {
                fatalError(error.localizedDescription)
            }
        }
    }
    
    private nonisolated(unsafe) var registeredQueries = {
        Atomic([ObjectIdentifier: [Int: WeakQueryObserver]]())
    }()
    
    @MainActor
    public func getOrCreateQueryObserver(for identifier: ObjectIdentifier, _ key: Int, createWith block: @escaping () -> AnyQueryObserver) -> AnyQueryObserver {
        if let observer = registeredQueries.value[identifier]?[key]?.query {
            return observer
        }
        let newObserver = block()
        registeredQueries.mutate { queries in
            queries[identifier, default: [:]][key] = WeakQueryObserver(query: newObserver)
        }
        return newObserver
    }
    
    @MainActor
    private var pendingNotifications: [ObjectIdentifier: [AnyObject]] = [:]
    
    @MainActor
    private var notificationTask: Task<Void, Never>?
    
    private nonisolated(unsafe) var pendingActorNotifications = Atomic([ObjectIdentifier: [AnyObject]]())
    private var actorNotificationTask: Task<Void, Never>?
    
    private func scheduleActorNotification<M: PersistentModel>(_ model: M) {
        pendingActorNotifications.mutate { pending in
            pending[
                M.typeIdentifier,
                default: []
            ]
                .append(model)
        }
        
        actorNotificationTask?.cancel()
        actorNotificationTask = Task {
            try? await Task.sleep(for: .milliseconds(50))
            Task { @MainActor in
                flushActorNotifications()
            }
        }
    }
    
    @MainActor
    private func flushActorNotifications() {
        let notifications = pendingActorNotifications.mutate { pending in
            let copy = pending
            pending.removeAll()
            return copy
        }
        
        for (identifier, models) in notifications {
            let observers = registeredQueries.value[identifier]
            
            if let observers {
                for (_, query) in observers {
                    if let query = query.query {
                        query.appendAny(models)
                    }
                }
            }
        }
    }
    
    @MainActor
    private func scheduleNotification<M: PersistentModel>(_ model: M) {
        pendingNotifications[
            M.typeIdentifier,
            default: []
        ]
            .append(model)
        
        notificationTask?.cancel()
        notificationTask = Task {
            try? await Task.sleep(for: .milliseconds(50))
            flushNotifications()
        }
    }
    
    @MainActor
    private func flushNotifications() {
        let notifications = pendingNotifications
        pendingNotifications.removeAll()
        
        for (identifier, models) in notifications {
            let observers = registeredQueries.value[identifier]
            
            if let observers {
                for (_, query) in observers {
                    if let query = query.query {
                        query.appendAny(models)
                    }
                }
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
    
    public nonisolated func compactIdentityMap() {
        identityMap.compact()
    }
}

private nonisolated final class ThreadSafeIdentityMap {
    private var cache = Atomic([ObjectIdentifier: [Int64: WeakModel]]())
    
    func getTracked<T: PersistentModel>(_ type: T.Type, id: Int64) -> T? {
        get(type, id: id)
    }
    
    func getTrackedCount() -> Int {
        cache.value.reduce(0, { $0 + $1.value.count })
    }
    
    func startTracking<T: PersistentModel>(_ object: T, type: T.Type, id: Int64) {
        track(object, type: type, id: id)
    }
    
    func batched<T: PersistentModel>(
        _ block: (
            (T.Type, Int64) -> T?,
            (T, T.Type, Int64) -> Void
        ) -> Void
    ) {
        block(get, track)
    }
    
    @inline(__always)
    private func track<T: PersistentModel>(_ object: T, type: T.Type, id: Int64) {
        cache.mutate { cache in
            cache[Self.key(type), default: [:]][id] = WeakModel(wrappedValue: object)
        }
    }
    
    @inline(__always)
    private func get<T: PersistentModel>(_ type: T.Type, id: Int64) -> T? {
        cache.value[Self.key(type)]?[id]?.wrappedValue as? T
    }
    
    func remove<T: PersistentModel>(_ type: T.Type, id: Int64) {
        cache.mutate { contents in
            _ = contents[Self.key(type)]?.removeValue(forKey: id)
        }
    }
    
    @inline(__always)
    private static func key<T: PersistentModel>(_ type: T.Type) -> ObjectIdentifier {
        ObjectIdentifier(type)
    }
    
    func compact() {
        cache.mutate { cache in
            for (type, var references) in cache {
                references = references.filter { _, box in !box.isDeallocated }
                if references.isEmpty {
                    cache.removeValue(forKey: type)
                } else {
                    cache[type] = references
                }
            }
        }
    }
}

private struct WeakModel {
    weak var wrappedValue: AnyObject?
    var isDeallocated: Bool { wrappedValue.isNil }
    
    init(wrappedValue: AnyObject? = nil) {
        self.wrappedValue = wrappedValue
    }
}
