import Foundation
import SQLiteDB

/// A descriptor for sorting models in SQLite.
///
/// Can either be created by using a **Foundation.SortDescriptor** or by providing your own SQL and runtime sorter.
public struct ModelSortDescriptor<M: PersistentModel>: Expressible {
    /// The SQL representation of the descriptor.
    public let expression: SQLiteDB.SQLExpression<Void>
    
    /// The sorter for sorting in memory.
    public let sort: @Sendable (M, M) -> ComparisonResult
    
    /// Creates a model sort descriptor using a SQLExpression and a closure for runtime sorting.
    init(
        expression: SQLiteDB.SQLExpression<Void>,
        sort: @Sendable @escaping (M, M) -> ComparisonResult
    ) {
        self.expression = expression
        self.sort = sort
    }
    
    /// Creates a model sort descriptor using a **Foundation.SortDescriptor**.
    init(
        _ descriptor: Foundation.SortDescriptor<M>
    ) throws (SortDescriptorConversionError) {
        self.expression = try descriptor.expressible.expression
        self.sort = descriptor.compare
    }
}
