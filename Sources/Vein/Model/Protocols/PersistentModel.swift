import Foundation

public protocol PersistentModel: AnyObject, Sendable {
    associatedtype _PredicateHelper: PredicateConstructor where _PredicateHelper.Model == Self

    var notifyOfChanges: () -> Void { get }
    
    static var schema: String { get }
    var id: Int64? { get set }
    var context: ManagedObjectContext? { get set }
    
    var _fields: [any PersistedField] { get }
    static var _fieldInformation: [FieldInformation] { get }
    
    func _setupFields() -> Void
    
    init(id: Int64, fields: [String: SQLiteValue])
}

extension PersistentModel {
    public static var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    public var typeIdentifier: ObjectIdentifier { ObjectIdentifier(Self.self) }
    func _getSchema() -> String { Self.schema }
    
    public func migrate(in context: Vein.ManagedObjectContext) throws(ManagedObjectContextError) {
        var builder = context.createSchema(Self.schema)
            .id()
        
        // dropping first to not create `id` twice
        for field in _fields.dropFirst() {
            field.migrate(on: &builder)
        }
        
        try builder.run()
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

public protocol VersionedSchema {
    static var version: ModelVersion { get }
    
    static var models: [any PersistentModel.Type] { get }
}

public protocol SchemaMigrationPlan: Sendable {
    static var stages: [MigrationStage] { get }
    
    static var schemas: [VersionedSchema.Type] { get }
}
