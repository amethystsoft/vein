import Foundation
import SQLiteDB

public enum SortDescriptorConversionError: Error {
    case invalidKeyPath
    case noFieldInformation
}

extension SortDescriptor where Compared: PersistentModel {
    func expandQuery(_ query: Table) throws(SortDescriptorConversionError) -> Table {
        guard let keyPath else { throw .invalidKeyPath }
        guard let information = Compared._predicateInformation(for: keyPath) else {
            throw .noFieldInformation
        }
        
        if order == .forward {
            return query.order(information.fetchExpressible.expression.asc)
        }
        
        return query.order(information.fetchExpressible.expression.desc)
    }
}
