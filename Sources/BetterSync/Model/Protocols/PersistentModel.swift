import Foundation

public protocol PersistentModel: AnyObject, Sendable {
    associatedtype SchemaMigration: ModelSchemaMigration
    associatedtype _PredicateHelper: PredicateConstructor where _PredicateHelper.Model == Self

    var notifyOfChanges: () -> Void { get }
    
    static var schema: String { get }
    var id: Int64? { get set }
    var context: ManagedObjectContext? { get set }
    
    func _getSchema() -> String
    var _fields: [any PersistedField] { get }
    static var _fieldInformation: [FieldInformation] { get }
    
    init(id: Int64, fields: [String: SQLiteValue])
}

extension PersistentModel {
    public static var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    public var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
}

struct AnyPersistentModelType: Hashable {
    let type: any PersistentModel.Type
    let createMigration: () -> ModelSchemaMigration
    
    init<M: PersistentModel>(_ type: M.Type) {
        self.type = type
        self.createMigration = { type.SchemaMigration() }
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

public protocol VersionedSchema {
    static var version: ModelVersion { get }
    
    static var models: [any PersistentModel.Type] { get }
}

public protocol SchemaMigrationPlan: Sendable {
    static var stages: [MigrationStage] { get }
    
    static var schemas: [VersionedSchema.Type] { get }
}
