import Foundation
import SQLiteDB
@_exported import ULID

public protocol PersistentModel: AnyObject, Sendable {
    var notifyOfChanges: () -> Void { get }
    
    static var schema: String { get }
    /// The primary ID of the object.
    /// Gets  used to reference models in relationships.
    /// Immutable after insertion into the context.
    var id: ULID { get set }
    
    /// Whether a model is prepared to be deleted.
    ///
    /// Reading this variable is safe, but it should never be set outside of Vein.
    var _isPreparedForDeletion: Bool { get set }
    
    var _fields: [any FieldBase] { get }
    var _relationships: [any PersistedRelationship] { get }
    static var _fieldInformation: [FieldInformation] { get }
    
    func _setupFields() -> Void
    
    static var version: ModelVersion { get }
    
    nonisolated var _observers: Atomic<ReferenceCountedObservers> { get }
    
    static var _inverseFields: [ObjectIdentifier: [String: String]] { get }
    
    func extractPrimitiveState() -> PrimitiveState
    func applyPrimitiveState(_ state: PrimitiveState)
    
    static func _predicateInformation(for keyPath: PartialKeyPath<Self>) -> FieldInformation?
    
    var _updatedAt: Foundation.Date? { get set }
    
    var _clientID: String? { get set }
    
    var _isDeleted: Bool? { get set }
    
    var _context: Vein.Atomic<Vein.ManagedObjectContext?> { get }
    
    init(id: ULID, fields: [String: SQLiteValue])
}

extension PersistentModel {
    public static var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    public var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    public func _getSchema() -> String { Self.schema }
    
    public var context: ManagedObjectContext? {
        get {
            _context.value
        }
        set {
            _context.value = newValue
        }
    }
    
    public func extractPrimitiveState() -> PrimitiveState {
        var data = [String: Any]()
        
        for field in _fields {
            data[field.instanceKey] = field.persistableValue
        }
        
        return PrimitiveState(values: data)
    }
    
    public func applyPrimitiveState(_ state: PrimitiveState) {
        for field in _fields {
            field.setStoreToCapturedState(state.values[field.instanceKey]!)
        }
    }
    
    internal func migrate(in context: Vein.ManagedObjectContext) throws(ManagedObjectContextError) {
        var builder = context._createSchema(Self.schema)
            .id()
        
        // dropping first to not create `id` twice
        for field in _fields.dropFirst() {
            field.migrate(on: &builder)
        }
        
        do {
            try builder.run()
            try context.registerMigration(schema: _getSchema(), version: Self.version)
        } catch let error as ManagedObjectContextError {
            throw error
        } catch let error as SQLiteDB.Result {
            throw error.parse()
        } catch { throw .other(message: error.localizedDescription) }
        
    }
    
    @MainActor
    public static func unchangedMigration(
        to newModel: any PersistentModel.Type,
        on context: ManagedObjectContext
    ) throws {
        guard context.isInActiveMigration.value else {
            throw ManagedObjectContextError
                .notInsideMigration("PersistentModel/unchangedMigration")
        }
        
        guard version < newModel.version else {
            throw ManagedObjectContextError
                .baseNotOlderThanDestination(Self.self, newModel)
        }
        
        guard Set(Self._fieldInformation) == Set(newModel._fieldInformation) else {
            throw ManagedObjectContextError.fieldMismatch(Self.self, newModel)
        }
        
        do {
            try context.renameSchema(schema, to: newModel.schema)
            try context.registerMigration(schema: newModel.schema, version: newModel.version)
        } catch let error as SQLiteDB.Result {
            let parsed = error.parse()
            switch parsed {
                case .noSuchTable: return
                default: throw parsed
            }
        }
    }
    
    @MainActor
    public static func deleteMigration(
        on context: ManagedObjectContext
    ) throws {
        guard context.isInActiveMigration.value else {
            throw ManagedObjectContextError
                .notInsideMigration("PersistentModel/deleteMigration")
        }
        
        try context.deleteTable(schema)
    }
    
    @MainActor
    public static func fieldsAddedMigration(
        to newModel: any PersistentModel.Type,
        on context: ManagedObjectContext
    ) throws {
        guard context.isInActiveMigration.value else {
            throw ManagedObjectContextError
                .notInsideMigration("PersistentModel/fieldsAddedMigration")
        }
        
        guard version < newModel.version else {
            throw ManagedObjectContextError
                .baseNotOlderThanDestination(Self.self, newModel)
        }
        
        let oldInformationSet = Set(Self._fieldInformation)
        let newInformationSet = Set(newModel._fieldInformation)
        
        let toAddInformation = newInformationSet.subtracting(oldInformationSet)
        
        guard
            Self._fieldInformation.count < newModel._fieldInformation.count,
            toAddInformation.count
            ==
            newInformationSet.count - oldInformationSet.count
        else {
            throw ManagedObjectContextError
                .destinationMustHaveOnlyAddedFields(Self.self, newModel)
        }
        
        guard
            !toAddInformation.contains(where: {
                !$0.typeName.isNull
            })
        else {
            throw ManagedObjectContextError
                .automaticMigrationRequiresOnlyOptionalFieldsAdded(Self.self, newModel)
        }
        
        do {
            try context.renameSchema(schema, to: newModel.schema)
            
            for information in toAddInformation {
                try information.addRetroactively(to: newModel.schema, on: context)
            }
            try context.registerMigration(schema: newModel.schema, version: newModel.version)
        } catch let error as SQLiteDB.Result {
            let parsed = error.parse()
            switch parsed {
                    // Returning, because schema will be created on first Model insert
                    // Therefore noSuchTable is acceptable here
                case .noSuchTable: return
                default: throw parsed
            }
        }
    }
}

struct AnyPersistentModelType: Hashable {
    let type: any PersistentModel.Type
    
    init<M: PersistentModel>(_ type: M.Type) {
        self.type = type
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(type))
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        ObjectIdentifier(lhs.type) == ObjectIdentifier(rhs.type)
    }
}

public protocol ModelSchemaMigration: Sendable {
    nonisolated func prepare(in context: ManagedObjectContext) async throws -> Void
    init()
}

public protocol VersionedSchema: Sendable {
    static var version: ModelVersion { get }
    
    static var models: [any PersistentModel.Type] { get }
}

public protocol SchemaMigrationPlan: Sendable {
    @MainActor
    static var stages: [MigrationStage] { get }
    
    static var schemas: [VersionedSchema.Type] { get }
}
