import Foundation
import SQLiteDB

public enum SortDescriptorConversionError: Error {
    case invalidKeyPath
    case noFieldInformation
}

extension SortDescriptor where Compared: PersistentModel {
    var expressible: (any Expressible) {
        get throws(SortDescriptorConversionError) {
            guard let keyPath else { throw .invalidKeyPath }
            guard let information = Compared._predicateInformation(for: keyPath) else {
                throw .noFieldInformation
            }
            
            if order == .forward {
                return information.fetchExpressible.expression.asc
            }
            
            return information.fetchExpressible.expression.desc
        }
    }
}
