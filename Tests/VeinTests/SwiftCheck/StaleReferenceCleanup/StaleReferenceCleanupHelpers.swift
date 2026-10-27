#if canImport(SwiftCheck)
import SQLiteDB
@testable import Vein

extension Connection {
    func removeWhereNameMatches(names: [String], schema: String) throws -> [String] {
        let query = Table(schema)
            .filter(names.contains(SQLExpression<String>("name")))
            .select(SQLExpression<String>("id"))
        var ids = [String]()
        do {
            let rows = try prepare(query)
            ids = rows.map {
                $0[SQLExpression<String>("id")]
            }
            
            let deleteQuery = Table(schema)
                .filter(ids.contains(SQLExpression<String>("id")))
                .delete()
            try run(deleteQuery)
        } catch let error as SQLiteDB.Result {
            if case .noSuchTable = error.parse() {}
        }
        
        return ids
    }
}

#endif
