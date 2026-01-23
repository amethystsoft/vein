import Foundation
import SQLite
@_exported import ULID

public protocol PersistentModel: AnyObject, Sendable {
    associatedtype _PredicateHelper: PredicateConstructor where _PredicateHelper.Model == Self

    var notifyOfChanges: () -> Void { get }
    
    static var schema: String { get }
    var id: ULID { get set }
    var context: ManagedObjectContext? { get set }
    
    var _fields: [any PersistedField] { get }
    static var _fieldInformation: [FieldInformation] { get }
    
    func _setupFields() -> Void
    
    static var version: ModelVersion { get }
    
    func extractPrimitiveState() -> PrimitiveState
    func applyPrimitiveState(_ state: PrimitiveState)
    
    init(id: ULID, fields: [String: SQLiteValue])
}

extension PersistentModel {
    public static var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    public var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    func _getSchema() -> String { Self.schema }
    
    public func extractPrimitiveState() -> PrimitiveState {
        var data = [String: Any]()
        
        for field in _fields {
            data[field.instanceKey] = field.wrappedValue
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
        } catch let error as SQLite.Result {
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
        
        try context.renameSchema(schema, to: newModel.schema)
        try context.registerMigration(schema: newModel.schema, version: newModel.version)
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
        } catch let error as SQLite.Result {
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
