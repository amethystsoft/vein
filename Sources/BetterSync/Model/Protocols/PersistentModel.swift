import Foundation

public protocol PersistentModel: class, Identifiable {
    associatedtype SchemaMigration: ModelSchemaMigration
    
    static var schema: String { get }
    var id: UUID? { get set }
    var context: ManagedObjectContext? { get set }
}

public protocol ModelSchemaMigration {
    func prepare(in context: ManagedObjectContext) throws
    func revert(in context: ManagedObjectContext) throws
}

public protocol VersionedSchema {
    static var version: ModelVersion { get }
    
    static var models: [any PersistentModel.Type] { get }
}

public protocol SchemaMigrationPlan {
    static var stages: [MigrationStage] { get }
    
    static var schemas: [VersionedSchema] { get }
}
