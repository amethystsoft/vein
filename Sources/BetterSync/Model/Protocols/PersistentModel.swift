import Foundation

public protocol PersistentModel: class, Sendable {
    associatedtype SchemaMigration: ModelSchemaMigration
    
    static var schema: String { get }
    var id: UUID? { get set }
    var context: ManagedObjectContext? { get set }
    
    func getSchema() -> String
    var fields: [PersistedField] { get }
    static var fieldInformation: [FieldInformation] { get }
    
    init(id: UUID, fields: [String: SqliteValue])
}

struct AnyPersistentModelType: Hashable {
    let type: PersistentModel.Type
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
    nonisolated func prepare(in context: ManagedObjectContext)
    init()
}

public protocol VersionedSchema {
    static var version: ModelVersion { get }
    
    static var models: [any PersistentModel.Type] { get }
}

public protocol SchemaMigrationPlan {
    static var stages: [MigrationStage] { get }
    
    static var schemas: [VersionedSchema.Type] { get }
}
