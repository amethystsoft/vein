import SQLiteDB

struct TableBuilder {
    private let context: ManagedObjectContext
    private let schemaName: String
    private var schema: (SQLiteDB.TableBuilder) -> Void

    init(_ context: ManagedObjectContext, named schemaName: String) {
        self.context = context
        self.schemaName = schemaName
        self.schema = { _ in }
    }

    @discardableResult
    func id() -> Self {
        var copy = self
        copy.schema = { t in
            t.column(SQLExpression<String>("id"), primaryKey: true)
        }
        return copy
    }

    @discardableResult
    func field(
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

    func run() throws(ManagedObjectContextError) {
        try context.run(Table(schemaName).create (ifNotExists: true) { t in
            schema(t)
        })
    }
}
