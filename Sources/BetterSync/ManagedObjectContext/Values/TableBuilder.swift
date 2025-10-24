import SQLite

@MainActor
public struct TableBuilder {
    private let context: ManagedObjectContext
    private let schemaName: String
    private var schema: (SQLite.TableBuilder) -> Void
    
    init(_ context: ManagedObjectContext, named schemaName: String) {
        self.context = context
        self.schemaName = schemaName
        self.schema = { _ in }
    }
    
    @discardableResult
    public func id() -> Self {
        var copy = self
        let previous = copy.schema
        copy.schema = { t in
            t.column(Expression<String>("id"), primaryKey: true)
        }
        return copy
    }
    
    @discardableResult
    public func field(
        _ key: String,
        type: UnderlayingFieldType,
        unique: Bool = false
    ) -> Self {
        var copy = self
        let previous = copy.schema
        copy.schema = { t in
            var t = t
            previous(t)
            type.addColumn(to: &t, withName: key)
        }
        return copy
    }
    
    @discardableResult
    public func run() throws {
        try context.connection.run(Table(schemaName).create{ t in
            guard let t = t as? SQLite.TableBuilder else {
                fatalError("Error while trying to create table \(schemaName): closure passed Type is not conform to SQLite.TableBuilder")
            }
            schema(t)
        })
    }
}
