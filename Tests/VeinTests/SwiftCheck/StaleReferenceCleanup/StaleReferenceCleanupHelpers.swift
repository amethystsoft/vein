#if canImport(SwiftCheck)
import SQLiteDB
@testable import Vein

extension Connection {
    func removeWhereIDMatches(idsToRemove: [String], schema: String) throws -> [String] {
        let idExpr = SQLExpression<String>("id")
        let query = Table(schema)
            .filter(idsToRemove.contains(idExpr))
            .select(idExpr)
        var ids = [String]()
        do {
            let rows = try prepare(query)
            ids = rows.map {
                $0[idExpr]
            }
            
            let deleteQuery = Table(schema)
                .filter(ids.contains(idExpr))
                .delete()
            try run(deleteQuery)
        } catch let error as SQLiteDB.Result {
            if case .noSuchTable = error.parse() {}
        }
        
        return ids
    }
}

#endif
