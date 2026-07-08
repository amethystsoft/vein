import Foundation
import SQLiteDB
@_exported import ULID

/// A protocol that defines the structure and behavior of a class as a persistable entity.
///
/// It's recommended to not conform to this yourself, the `@Model` macro will generate conformance.
public protocol PersistentModel: AnyObject, Sendable {
    /// The name of the SQLite table associated with this model.
    static var schema: String { get }

    /// The unique 128-bit identifier for this instance.
    ///
    /// - Important: This ID is used to resolve relationships and is immutable
    /// once the object is inserted into a context.
    var id: ULID { get set }

    /// The current schema version of this model.
    /// Used by the migration system to determine if the database matches the code.
    static var version: ModelVersion { get }

    /// Internal flag used by the context during the deletion lifecycle.
    var _isPreparedForDeletion: Bool { get set }

    /// A closure invoked whenever a field value changes, used to trigger UI updates.
    var notifyOfChanges: () -> Void { get }

    var _fields: [any FieldBase] { get }
    var _relationships: [any PersistedRelationship] { get }
    static var _fieldInformation: [FieldInformation] { get }

    func _setupFields() -> Void

    nonisolated var _observers: Mutex<_ReferenceCountedObservers> { get }

    static var _inverseFields: [ObjectIdentifier: [String: String]] { get }

    static func _predicateInformation(for keyPath: PartialKeyPath<Self>) -> FieldInformation?

    var _updatedAt: Foundation.Date? { get set }

    var _clientID: String? { get set }

    var _isDeleted: Bool? { get set }

    var _context: Mutex<Vein.ManagedObjectContext?> { get }

    init(id: ULID, fields: [String: SQLiteValue])
}

extension PersistentModel {
    /// Convenience access to the ObjectIdentifier of the model's type.
    public static var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    /// Convenience access to the ObjectIdentifier of the model's type.
    public var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    public func _getSchema() -> String { Self.schema }

    /// The context the model instance is managed by.
    public var context: ManagedObjectContext? {
        get {
            _context.value
        }
        set {
            _context.value = newValue
        }
    }

    func extractPrimitiveState() -> PrimitiveState {
        var data = [String: Any]()

        for field in _fields {
            data[field.instanceKey] = field._persistableValue
        }

        return PrimitiveState(values: data)
    }

    func applyPrimitiveState(_ state: PrimitiveState) {
        for field in _fields {
            field._setStoreToCapturedState(state.values[field.instanceKey]!)
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

    /// Performs an automatic migration for scenarios where nothing changed on this model.
    ///
    /// This method renames the table.
    /// - Throws: `ManagedObjectContextError.notInsideMigration` if called outside an active migration,
    ///   `.baseNotOlderThanDestination` if the destination model isn't newer, or
    ///   `.fieldMismatch` if the field sets differ, or any other error propagated while
    ///   renaming the schema or registering the migration.
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

    /// Performs a drop of the table without replacement. Use when a model is no longer required.
    ///
    /// - Throws: `ManagedObjectContextError.notInsideMigration` if called outside an active migration,
    ///   or any error propagated from deleting the table.
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

    /// Performs an automatic migration for scenarios where only optional fields were added.
    ///
    /// This method renames the table and injects new columns into the existing SQLite schema.
    /// - Throws: `ManagedObjectContextError.notInsideMigration` if called outside an active migration,
    ///   `.baseNotOlderThanDestination` if the destination model isn't newer,
    ///   `.destinationMustHaveOnlyAddedFields` if fields were removed or changed rather than only added,
    ///   `.automaticMigrationRequiresOnlyOptionalFieldsAdded` if any of the new fields are non-optional,
    ///   or any other error propagated while renaming the schema, adding columns, or registering the migration.
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

/// An interface for describing a specific version of a schema, including the models it contains.
public protocol VersionedSchema: Sendable {
    /// The version identifier for this specific schema snapshot.
    static var version: ModelVersion { get }

    /// The list of models included in this version.
    static var models: [any PersistentModel.Type] { get }
}

/// An interface for describing the evolution of a schema and how to migrate between specific versions.
public protocol SchemaMigrationPlan: Sendable {
    /// The migration stages, ordered chronologically from oldest to newest schema version.
    @MainActor
    static var stages: [MigrationStage] { get }

    /// The historical schemas, ordered chronologically from oldest to newest version.
    static var schemas: [VersionedSchema.Type] { get }
}
